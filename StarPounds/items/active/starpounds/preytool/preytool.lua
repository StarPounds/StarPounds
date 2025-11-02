require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  range = config.getParameter("range", 2.5)
  querySize = config.getParameter("querySize", 0.5)
  activeItem.setHoldingItem(false)
  activeItem.setCursor("/cursors/starpoundsvore.cursor:prey")
  script.setUpdateDelta(world.getProperty("nonCombat") and 0 or 5)
  monsterBehaviors = root.assetJson("/scripts/starpounds/modules/pred.config:monsterBehaviors")

  starPounds = getmetatable ''.starPounds
end

function update(dt)
  local validTarget = false
  if starPounds.isEnabled() and not starPounds.hasOption("disablePrey") then
    local mouthPosition = starPounds.mcontroller.mouthPosition
    if starPounds.currentSize.yOffset then
      mouthPosition = vec2.add(mouthPosition, {0, starPounds.currentSize.yOffset})
    end
    local aimPosition = activeItem.ownerAimPosition()
    local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), range - querySize - (starPounds.currentSize.yOffset or 0))
    local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
    local entities = world.entityQuery(targetPosition, querySize, {order = "nearest", includedTypes = {"player", "npc", "monster"}, withoutEntityId = activeItem.ownerEntityId()}) or jarray()
    for _, target in ipairs(entities) do
      if isTargetValid(target) then
        validTarget = true
        break
      end
    end
  end
  activeItem.setCursor(validTarget and "/cursors/starpoundsvore.cursor:prey_valid" or "/cursors/starpoundsvore.cursor:prey")
end

function activate(fireMode, shiftHeld)
  local mouthPosition = starPounds.mcontroller.mouthPosition
  if starPounds.currentSize.yOffset then
    mouthPosition = vec2.add(mouthPosition, {0, starPounds.currentSize.yOffset})
  end
  local aimPosition = activeItem.ownerAimPosition()
  local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), range - querySize - (starPounds.currentSize.yOffset or 0))
  local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
  local entities = world.entityQuery(targetPosition, querySize, {order = "nearest", includedTypes = {"player", "npc", "monster"}, withoutEntityId = activeItem.ownerEntityId()}) or jarray()
  for _, target in ipairs(entities) do
    if isTargetValid(target) then
      world.sendEntityMessage(target, "starPounds.pred.eat", activeItem.ownerEntityId(), {ignoreSkills = true, ignoreCapacity = true, ignoreEnergyRequirement = true, energyMultiplier = 0})
      return
    end
  end
end

function isTargetValid(target)
  local targetType = world.entityTypeName(target)
  if world.entityType(target) == "monster" then
    local scriptCheck = contains(root.monsterParameters(targetType).scripts or jarray(), "/scripts/starpounds/loaders/monster.lua")
    local parameters = root.monsterParameters(targetType)
    local behaviorCheck = parameters.behavior and contains(monsterBehaviors, parameters.behavior) or false
    if parameters.starPounds_options and parameters.starPounds_options.disablePred then return false end
    if not (scriptCheck or behaviorCheck) then
      return false
    end
  end
  if world.entityType(target) == "npc" then
    if not contains(root.npcConfig(targetType).scripts or jarray(), "/scripts/starpounds/loaders/npc.lua") then return false end
    if world.getNpcScriptParameter(target, "starPounds_options", jarray()).disablePred then return false end
  end
  return not world.lineTileCollision(world.entityMouthPosition(target), world.entityPosition(activeItem.ownerEntityId()), {"Null", "Block", "Dynamic", "Slippery"})
end
