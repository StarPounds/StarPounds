require "/scripts/vec2.lua"
function init()
  starPounds = getmetatable ''.starPounds
  range = config.getParameter("range", 2.5)
  querySize = config.getParameter("querySize", 0.5)
  activeItem.setHoldingItem(false)
  script.setUpdateDelta(world.getProperty("nonCombat") and 0 or 1)
  cooldownFrames = 8
  cooldown = starPounds.moduleFunc("pred", "cooldown")
  lastCooldown = cooldown
  cursorType = "pred"
  checkUpdateTicks = 5
  updateCursor()
  readyEmote = config.getParameter("readyEmote", "Happy")
  starPounds.events:on("pred:eatEntity", updateCooldown)
  starPounds.events:on("pred:bite", updateCooldown)
end

function activate(fireMode, shiftHeld)
  if shiftHeld then
    starPounds.moduleFunc("pred", "release")
  elseif starPounds.moduleFunc("pred", "cooldown") == 0 then
    local mouthPosition = vec2.add(starPounds.mcontroller.mouthPosition, {0, (starPounds.currentSize.yOffset or 0)})
    local aimPosition = activeItem.ownerAimPosition()
    local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), range - querySize - (starPounds.currentSize.yOffset or 0))
    local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
    local valid = starPounds.moduleFunc("pred", "eatNearby", targetPosition, range - (starPounds.currentSize.yOffset or 0), querySize, {particles = true})
    if (valid and valid[1]) then
      starPounds.moduleFunc("pred", "cooldownStart")
      updateCursor()
    elseif not starPounds.hasOption("disablePredBite") then
      starPounds.moduleFunc("pred", "cooldownStart")
      starPounds.moduleFunc("pred", "bite", targetPosition, true)
      updateCursor()
    end
  end
end

function update(dt, _, shiftHeld)
  if cooldown > 0 then
    cooldown = math.max(cooldown - (dt / starPounds.getStat("voreCooldown")), 0)
  end

  local aimPosition = activeItem.ownerAimPosition()
  local aimAngle, aimDirection = activeItem.aimAngleAndDirection(0, aimPosition)
  activeItem.setFacingDirection(aimDirection)

  updateTick = ((updateTick or 0) % checkUpdateTicks) + 1
  if updateTick == 1 then
    local mouthPosition = starPounds.mcontroller.mouthPosition
    if starPounds.currentSize.yOffset then
      mouthPosition = vec2.add(mouthPosition, {0, starPounds.currentSize.yOffset})
    end
    local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), range - querySize - (starPounds.currentSize.yOffset or 0))
    local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
    -- Vore icon updater.
    local valid = starPounds.moduleFunc("pred", "eatNearby", targetPosition, range - (starPounds.currentSize.yOffset or 0), querySize, nil, true)
    local safe = (starPounds.moduleFunc("pred", "cooldown") == 0 and (valid and valid[3])) and "safe_" or ""
    cursorType = (valid and valid[1]) and (valid[2] and "pred_"..safe.."valid" or "pred_"..safe.."nearby") or "pred"
    if readyEmote ~= "none" then
      if cursorType == "pred_"..safe.."valid" and starPounds.moduleFunc("pred", "cooldown") == 0 then
        activeItem.emote(readyEmote)
        wasValid = true
      end
    end

    if wasValid and (cursorType ~= "pred_valid" and cursorType ~= "pred_safe_valid") then
      activeItem.emote("Idle")
      wasValid = false
    end
  end
  -- Mouth icon updater.
  updateCursor(shiftHeld)
end

function canRelease()
  local canRelease = false
  local stomachEntities = starPounds.moduleFunc("data", "get", "stomachEntities")
  for preyIndex = #stomachEntities, 1, -1 do
    local prey = stomachEntities[preyIndex]
    if not prey.noRelease then
      canRelease = true
      break
    end
  end
  return canRelease
end

function updateCooldown()
  cooldown = starPounds.moduleFunc("pred", "cooldown")
end

function updateCursor(shiftHeld)
  if shiftHeld then
    activeItem.setCursor(string.format("/cursors/starpoundsvore.cursor:release%s", canRelease() and "_valid" or ""))
  else
    local readyPercent = 1 - (cooldown/starPounds.moduleFunc("pred", "cooldownTime"))
    local frame = "_"..math.min(math.floor(readyPercent * (cooldownFrames)), cooldownFrames - 1)
    activeItem.setCursor(string.format("/cursors/starpoundsvore.cursor:%s%s", cursorType, cooldown > 0 and frame or ""))
  end
end

function uninit()
  starPounds.events:off("pred:eatEntity", updateCooldown)
  starPounds.events:off("pred:bite", updateCooldown)

  if wasValid then
    activeItem.emote("Idle")
  end
end
