require "/scripts/messageutil.lua"
require "/scripts/vec2.lua"

function init()
  message.setHandler("starpounds.treadmill.init", simpleHandler(
    function(pos, direction, id)
      position = pos
      facing = direction
      target = id

      standPosition = vec2.add(position, world.entityPosition(target))

      world.sendEntityMessage(entity.id(), "queueRadioMessage", "starpounds_treadmill")
    end
  ))
  message.setHandler("starpounds.treadmill.uninit", simpleHandler(effect.expire))
  effectTimer = 10
  entityType = world.entityType(entity.id())

  outOfEnergyModifier = {movementSuppressed = true}
  runningModifier = {groundMovementModifier = 0, speedModifier = 0}
end

function update(dt)
  if target and world.entityExists(target) then
    -- Keep status alive and hold player in position.
    effect.modifyDuration(dt)
    local offset = supersizeOffset()
    if not (lastOffset and vec2.eq(offset, lastOffset)) then
      standPosition = vec2.sub(vec2.add(position, world.entityPosition(target)), offset)
      lastOffset = offset
    end

    mcontroller.setPosition(standPosition)
    -- Kick the player off the treadmill if they jump or run the other way.
    if mcontroller.jumping() or (mcontroller.movingDirection() ~= facing and (mcontroller.walking() or mcontroller.running())) then
      effect.expire()
      world.sendEntityMessage(target, "starpounds.treadmill.uninit")
    -- Disable movement when out of energy.
    elseif not status.resourcePositive("energy") or status.resourceLocked("energy") then
      mcontroller.controlModifiers(outOfEnergyModifier)
    -- Sweat and consume energy when running.
    elseif mcontroller.running() then
      mcontroller.controlModifiers(runningModifier)
      status.addEphemeralEffect("sweat")
      status.overConsumeResource("energy", status.resourceMax("energy") * 0.05 * dt)
      effectTimer = math.max(effectTimer - dt, 0)
    end

    if effectTimer == 0 then
      effectTimer = 10
      world.sendEntityMessage(entity.id(), "starPounds.effects.add", "treadmill")
    end

    -- Disable the treadmill for NPCs the moment they stop running.
    if entityType == "npc" then
      local moving = (mcontroller.walking() or mcontroller.running())
      if wasMoving and not moving then
        effect.expire()
        world.sendEntityMessage(target, "starpounds.treadmill.uninit")
      end
      wasMoving = moving
    end
  end
end

function supersizeOffset()
  local offset = 0

  if world.entityType(entity.id()) == "player" then
    starPounds = getmetatable ''.starPounds
    offset = starPounds and starPounds.moduleFunc("size", "offset") or 0
  end

  if world.entityType(entity.id()) == "npc" then
    offset = world.callScriptedEntity(entity.id(), "starPounds.moduleFunc", "size", "offset") or 0
  end

  return offset
end
