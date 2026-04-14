require "/scripts/vec2.lua"
require "/scripts/messageutil.lua"

function init()

  self.fireOffset = config.getParameter("fireOffset")

  self.active = false
  storage.fireTimer = storage.fireTimer or 0
  updateAim()
end

function update(dt, fireMode, shiftHeld)
  promises:update()
  updateAim()

  storage.fireTimer = math.max(storage.fireTimer - dt, 0)
  if self.active and not storage.firing and storage.fireTimer <= 0 then
    if animator.animationState("firing") == "off" then
      animator.setAnimationState("firing", "fire")
    end
    storage.fireTimer = config.getParameter("fireTime", 1.0)
    storage.firing = true
    activeItem.setFrontArmFrame("swim.2")
    activeItem.setBackArmFrame("swim.2")
  end

  self.active = false

  if storage.firing and animator.animationState("firing") == "off" then
    promises:add(world.sendEntityMessage(activeItem.ownerEntityId(), "starPounds.breasts.get"), function(breasts)
      local liquidConfig = root.liquidConfig(breasts.type).config
      promises:add(world.sendEntityMessage(activeItem.ownerEntityId(), "starPounds.breasts.loseMilk", 10), function(amount)
        if player and liquidConfig.itemDrop then
          player.giveItem({name = liquidConfig.itemDrop, count = amount})
        end
      end)
    end)
    storage.firing = false
    return
  end
end

function activate(fireMode, shiftHeld)
  if not storage.firing then
    self.active = true
  end
end

function updateAim()
  self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(self.fireOffset[2], activeItem.ownerAimPosition())
  activeItem.setFacingDirection(self.aimDirection)
  activeItem.setArmAngle(self.aimAngle)
  if storage.fireTimer <= 0 then
    activeItem.setFrontArmFrame()
    activeItem.setBackArmFrame()
  end
end
