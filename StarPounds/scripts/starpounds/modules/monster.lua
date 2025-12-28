-- Underscore here since the monster table exists.
local _monster = starPounds.module:new("monster")

function _monster:init()
  starPounds.isCritter = contains(root.assetJson("/scripts/starpounds/modules/pred.config:critterBehaviors"), config.getParameter("behavior", "monster")) ~= nil
  -- Set monster specific trait.
  if not starPounds.getTrait() then
    starPounds.setTrait(config.getParameter("starPounds_trait"))
  end
  -- Initial skills and options.
  storage.starPounds.options = sb.jsonMerge(storage.starPounds.options, config.getParameter("starPounds_options", {}))
  if not storage.starPounds.parsedInitialSkills then
    local skills = config.getParameter("starPounds_skills", {})
    for k, v in pairs(skills) do
      local level = 0
      if type(v) == "table" then
        level = math.random(v[1], v[2])
      elseif type(v) == "number" then
        level = v
      end
      if level > 0 then
        skills[k] = jarray()
        skills[k][1] = level
        skills[k][2] = level
      else
        skills[k] = nil
      end
    end
    storage.starPounds.skills = sb.jsonMerge(storage.starPounds.skills, skills)
    storage.starPounds.parsedInitialSkills = true
  end
  -- Triggers aggro.
  message.setHandler("starPounds.notifyDamage", simpleHandler(function(args)
    _ENV.self.damaged = true
    _ENV.self.board:setEntity("damageSource", args.sourceId)
  end))
  self:setup()
  starPounds.moduleFunc("skills", "parse")
end

function _monster:setup()
  -- Shortcuts to make functions work for monsters.
  entity.setDamageOnTouch = monster.setDamageOnTouch
  entity.setDamageTeam = monster.setDamageTeam
  -- Disable stuff monsters don't use
  starPounds.getDirectives = function() return "" end
  starPounds.getSpecies = function() return "" end
  -- Save default functions.
  openDoors_old = openDoors_old or openDoors
  closeDoors_old = closeDoors_old or closeDoors
  closeDoorsBehind_old = closeDoorsBehind_old or closeDoorsBehind
  -- Override default functions.
  closeDoorsBehind = function() if storage.starPounds.pred then closeDoorsBehind_old() end end
  openDoors = function(...) return storage.starPounds.pred and false or openDoors_old(...) end
  closeDoors = function(...) return storage.starPounds.pred and false or closeDoors_old(...) end
  -- Ignore things that have been eaten.
  entity.isValidTarget_old = entity.isValidTarget_old or entity.isValidTarget
  entity.isValidTarget = function(entityId)
    local eatenEntity = nil
    if not world.entityExists(entityId) then return false end
    for preyIndex, prey in ipairs(storage.starPounds.stomachEntities) do
      if prey.id == entityId then
        eatenEntity = prey
      end
    end
    if #world.monsterQuery(world.entityPosition(entityId), 1, {withoutEntityId = entity.id(), callScript = "hasEatenEntity", callScriptArgs = {{entity = entityId}}}) > 0 then
      return false
    end
    if #world.npcQuery(world.entityPosition(entityId), 1, {withoutEntityId = entity.id(), callScript = "hasEatenEntity", callScriptArgs = {{entity = entityId}}}) > 0 then
      return false
    end
    if eatenEntity then return false end
    return entity.isValidTarget_old(entityId)
  end
  -- Vore stuff.
  local boundBox = mcontroller.boundBox()
  local monsterArea = math.abs(boundBox[1]) + math.abs(boundBox[3]) * math.abs(boundBox[2]) + math.abs(boundBox[4])
  entity.weight = math.min(math.round(monsterArea * self.data.monsterFood), self.data.monsterFoodCap)
  local deathActions = config.getParameter("behaviorConfig.deathActions", {})
  -- Remove base weight if the monster is 'replaced'.
  for _, action in ipairs(deathActions) do
    if action.name == "action-spawnmonster" and action.parameters.replacement then
      entity.weight = 0
    end
  end
  for _, action in ipairs(deathActions) do
    if action.name == "action-spawnmonster" then
      local monsterPoly = root.monsterParameters(action.parameters.monsterType).movementSettings.collisionPoly
      local boundBox = util.boundBox(monsterPoly)
      local monsterArea = math.abs(boundBox[1]) + math.abs(boundBox[3]) * math.abs(boundBox[2]) + math.abs(boundBox[4])
      entity.weight = entity.weight + math.min(math.round(monsterArea * self.data.monsterFood), self.data.monsterFoodCap)
    end
  end
  -- Robotic monsters don't give food.
  entity.foodType = "preyMonster"
  if status.statusProperty("targetMaterialKind") == "robotic" then
    entity.foodType = "preyMonsterInedible"
  end

  --2038
  entity.foodMaterial = nil
  if status.statusProperty("targetMaterialKind") ~= nil then
      entity.foodMaterial = status.statusProperty("targetMaterialKind")
  end
  --2038

  -- Use the preset type if it exists.
  entity.foodType = config.getParameter("starPounds_foodType", entity.foodType)
  -- No XP if the monster is a pet (prevents infinite XP). Using configParameter instead of hasOption because default options aren't merged yet when this runs.
  if config.getParameter("starPounds_options.disableExperience") or (capturable and (capturable.tetherUniqueId() or capturable.ownerUuid())) then
    entity.foodType = entity.foodType.."_noExperience"
  end
end

starPounds.modules.monster = _monster
