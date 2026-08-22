require "/scripts/rails.lua"
require "/scripts/util.lua"
require "/scripts/messageutil.lua"

function init()
  message.setHandler("positionTileDamaged", function()
      if not world.isTileProtected(mcontroller.position()) then
        popVehicle()
      end
    end)

  mcontroller.setRotation(0)

  local railConfig = config.getParameter("railConfig", {})
  railConfig.facing = config.getParameter("initialFacing", 1)

  self.railRider = Rails.createRider(railConfig)
  self.railRider:init(storage.railStateData)
  self.sizes = root.assetJson("/scripts/starpounds/size/humanoid.config:sizes")

  self.driver = nil
end

function update(dt)
 promises:update()
  
  if mcontroller.atWorldLimit() then
    vehicle.destroy()
    return
  end

  local driver = vehicle.entityLoungingIn("seat")
  if driver then
	 
    if not self.driver then
      animator.setAnimationState("gate", "closing")
	  supersizeCheck(driver) --Check if the driver is supersize
	end
	
    local upHeld = vehicle.controlHeld("seat", "up")
    local downHeld = vehicle.controlHeld("seat", "down")
    local leftHeld = vehicle.controlHeld("seat", "left")
    local rightHeld = vehicle.controlHeld("seat", "right")

    if not self.railRider.moving then
      if upHeld then
        resume(Rails.dirs.n)
      elseif downHeld then
        resume(Rails.dirs.s)
      elseif leftHeld then
        resume(Rails.dirs.w)
      elseif rightHeld then
        resume(Rails.dirs.e)
      end
    end

    if upHeld then
      animator.setAnimationState("controls", "up")
    elseif downHeld then
      animator.setAnimationState("controls", "down")
    elseif leftHeld then
      animator.setAnimationState("controls", "left")
    elseif rightHeld then
      animator.setAnimationState("controls", "right")
    else
      animator.setAnimationState("controls", "idle")
    end
    vehicle.setInteractive(false)
  else
    if self.driver then
      animator.setAnimationState("gate", "opening")
	  animator.resetTransformationGroup("seat") -- reset any seat adjustments when driver leaves
    end
    animator.setAnimationState("controls", "idle")
    vehicle.setInteractive(true)
  end
  self.driver = driver

  if mcontroller.isColliding() then
    popVehicle()
  else
    self.railRider:update(dt)
    storage.railStateData = self.railRider:stateData()
  end

  if self.railRider.onRailType and self.railRider.moving then
    animator.setAnimationState("rail", "on")
  else
    animator.setAnimationState("rail", "off")
  end
end

function resume(direction)
  self.railRider:railResume(self.railRider:position(), nil, direction)
  animator.playSound("activate")
end

function uninit()
  self.railRider:uninit()
end

function popVehicle()
  local popItem = config.getParameter("popItem")
  if popItem then
    world.spawnItem(popItem, entity.position(), 1)
  end
  vehicle.destroy()
end

function isRailTramAt(nodePos)
  if nodePos and vec2.eq(nodePos, self.railRider:position()) then
    return true
  end
end


--Apple, I dont know where you came from or how you do it, but holy shit you're saving my ass... TWICE
function supersizeCheck(entityId)
  promises:add(world.sendEntityMessage(entityId, "starPounds.getData"), function(data)
    local size = getSize(data.weight, data.options.disableSupersize)
    animator.resetTransformationGroup("seat")
    if size.yOffset then
      animator.translateTransformationGroup("seat", {0, -size.yOffset})
    end
  end)
end

function getSize(weight, supersizeDisabled)
    local sizeIndex = 0
    -- Go through all self.sizes (smallest to largest) to find which size.
    for i in ipairs(self.sizes) do
        local isSupersize = self.sizes[i].yOffset
        local skipSize = isSupersize and supersizeDisabled
        if weight >= self.sizes[i].weight and not skipSize then
			sizeIndex = i
        end
    end

    return self.sizes[sizeIndex]
end