require "/scripts/messageutil.lua"
require "/vehicles/railtram/railtram.lua"
local init_old = init
function init()
  init_old()
  self.sizes = root.assetJson("/scripts/starpounds/size/humanoid.config:sizes")
  self.entityOffsets = {}
  self.entityPromises = {}
end

local update_old = update
function update(dt)
  local driver = vehicle.entityLoungingIn("seat")
  if driver then
    superSizeOffset(driver)
    if self.entityOffsets[driver] then
      animator.resetTransformationGroup("seat")
      animator.translateTransformationGroup("seat", self.entityOffsets[driver])
    end
  elseif self.driver and not driver then
    animator.resetTransformationGroup("seat")
  end

  promises:update()
  update_old(dt)
end

function superSizeOffset(entityId)
  if not self.entityPromises[entityId] then
    local promise = world.sendEntityMessage(entityId, "starPounds.size.offset")
    self.entityPromises[entityId] = promise
    promises:add(promise, function(offset)
      self.entityOffsets[entityId] = offset and vec2.mul(offset, {1, -1}) or nil
      self.entityPromises[entityId] = nil
    end)
  end
end
