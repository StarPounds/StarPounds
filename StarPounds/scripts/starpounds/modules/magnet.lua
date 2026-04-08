local magnet = starPounds.module:new("magnet")

function magnet:init()
  self.basePickupDistance = root.assetJson("/itemdrop.config:pickupDistance") * 2 -- 2x since it's actually the diameter for whatever reason.
  -- New hitbox is set after the event is fired, need to calculate afterwards.
  self.queueSizeUpdate = function()
    self.updateSizeDelay = 2 -- Defer by 2 ticks in case they line up.
  end

  self.width = 0
  self.queueSizeUpdate()

  starPounds.events:on("size:changed", self.queueSizeUpdate)
end

function magnet:update(dt)
  -- Create magnet if it's enabled, and doesn't exist/is not in the process of being created.
  if self:enabled() and ((self.magnetPromise and not self.magnetId) or not self:active()) then
    self:create()
  elseif self:active() and not self:enabled() then -- Remove magnet if exists and it's not enabled.
    self:remove()
  end
  -- Update the range of the magnet.
  if self:enabled() and self:active() then
    self:updateRange()
  end
  -- Update width.
  if self.updateSizeDelay then
    self.updateSizeDelay = self.updateSizeDelay - 1
    if self.updateSizeDelay == 0 then
      self:sizeUpdate()
      self.updateSizeDelay = nil
    end
  end
end

function magnet:uninit()
  self:remove()
  starPounds.events:off("size:changed", self.queueSizeUpdate)
end

function magnet:active()
  return not not (self.magnetId or self.magnetPromise)
end

function magnet:enabled()
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return false end
  -- Don't do anything inside morphballs.
  if status.stat("activeMovementAbilities") > 1 then return false end
  -- Only works when crouched.
  if not starPounds.mcontroller.crouching then return false end

  local range = starPounds.getStat("magnetRange") * starPounds.moduleFunc("size", "effectScaling")
  return range > 0
end

function magnet:create()
  -- Clear existing magnet.
  if self.magnetId then self:remove() end
  -- Try spawn magnet if we're not waiting.
  if not self.magnetPromise then
    self.magnetUuid = sb.makeUuid()
    world.spawnMonster("starpoundsmagnet", starPounds.mcontroller.position, {owner = starPounds.entityId, uniqueId = self.magnetUuid})
    self.magnetPromise = world.findUniqueEntity(self.magnetUuid)
    return
  end
  -- Wait for the promise.
  if not self.magnetPromise:finished() then return end
  -- Retry if the promise fails.
  if not self.magnetPromise:succeeded() then
    self.magnetPromise = nil
    return
  end
  -- Keep querying until we find the entity. (Max 60 tries)
  local position = self.magnetPromise:result()
  local query = world.monsterQuery(position, 1, {callScript = "entity.uniqueId", callScriptResult = self.magnetUuid})
  -- There should only ever be 1 with the UUID.
  if query[1] then
    self.magnetId = query[1]
    self.magnetPromise = nil
    self.magnetQueryCount = nil
    world.callScriptedEntity(self.magnetId, "mcontroller.setOwner", starPounds.entityId)
  end
  -- Try 12 times (1 second) to find the monster, otherwise restart.
  self.magnetQueryCount = (self.magnetQueryCount or 0) + 1
  if self.magnetQueryCount > 12 then
    self.magnetPromise = nil
    self.magnetQueryCount = nil
  end
end

function magnet:remove()
  if not self.magnetId then return end
  -- Remove the magnet if it exists.
  if world.entityExists(self.magnetId) then
    world.callScriptedEntity(self.magnetId, "status.setResource", "health", 0)
  end
  -- Remove stored id.
  self.magnetId = nil
end

function magnet:sizeUpdate()
  local width = {0, 0}
  for _, v in ipairs(starPounds.mcontroller.collisionPoly) do
    width[1] = math.min(width[1], v[1])
    width[2] = math.max(width[2], v[1])
  end

  local totalWidth = math.abs(width[1]) + math.abs(width[2])
  self.width = math.max(totalWidth * self.data.widthAdjustMult + self.data.widthAdjust, 0)
end

function magnet:updateRange()
  if not self.magnetId then return end
  if world.entityExists(self.magnetId) then
    local effectScaling = starPounds.moduleFunc("size", "effectScaling") * self.data.sizeScalingFactor + (1 - self.data.sizeScalingFactor)
    local statRange = starPounds.getStat("magnetRange") * effectScaling * 2 -- 2x since it's actually the diameter for whatever reason.
    world.callScriptedEntity(self.magnetId, "setRange", self.basePickupDistance + self.width + statRange)
  end
end

starPounds.modules.magnet = magnet
