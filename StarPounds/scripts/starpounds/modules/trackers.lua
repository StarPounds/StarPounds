local trackers = starPounds.module:new("trackers")

function trackers:init()
  -- Just incase this gets used on an init.
  starPounds.progress = 0
end

function trackers:update(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- We don't need status effect trackers if we're running oSB.
  if starPounds.moduleFunc("oSB", "hasOpenStarbound") then return end
  -- Don't create if we can't add statuses anyway.
  if status.statPositive("statusImmunity") then return end
  -- Don't create if we're eaten.
  if storage.starPounds.pred then return end
  -- Check if statuses don't exist.
  if not (starPounds.hasOption("disableStomachMeter") or starPounds.hasOption("legacyMode")) then
    local stomachTracker = self:getStomachTracker()
    if not status.uniqueStatusEffectActive(stomachTracker) then
      self:createStatuses()
      return
    end
  end
  -- Size status.
  if not starPounds.hasOption("disableSizeMeter") then
    if not status.uniqueStatusEffectActive("starpounds"..starPounds.currentSize.size) then
      self:createStatuses()
      return
    end
  end
  -- Tiddy status.
  if starPounds.hasOption("breastMeter") then
    if not status.uniqueStatusEffectActive("starpoundsbreast") then
      self:createStatuses()
      return
    end
  end
end

function trackers:uninit()
  self:clearStatuses()
end

function trackers:createStatuses()
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Removing them just puts them back in order (Size tracker before stomach tracker)
  self:clearStatuses()
  -- No statuses if we're running oSB, we have a fancy interface.
  if starPounds.moduleFunc("oSB", "hasOpenStarbound") then return end

  local stomachTracker = self:getStomachTracker()
  local sizeTracker = "starpounds"..starPounds.currentSize.size
  if not starPounds.hasOption("disableSizeMeter") then
    status.addEphemeralEffect(sizeTracker)
  end
  if not (starPounds.hasOption("disableStomachMeter") or starPounds.hasOption("legacyMode")) then
    status.addEphemeralEffect(stomachTracker)
  end
  if starPounds.hasOption("breastMeter") then
    status.addEphemeralEffect("starpoundsbreast")
  end
  -- Try and keep the strain meter at the end of the others.
  if status.uniqueStatusEffectActive("starpoundsstrained") then
    status.removeEphemeralEffect("starpoundsstrained")
    status.addEphemeralEffect("starpoundsstrained")
  end
end

function trackers:clearStatuses()
  local sizeTracker = "starpounds"..starPounds.currentSize.size
  self:removeStomachTrackers()
  status.removeEphemeralEffect(sizeTracker)
  status.removeEphemeralEffect("starpoundsbreast")
  world.sendEntityMessage(entity.id(), "starPounds.expireSizeTracker")
end

function trackers:getStomachTracker()
  local fullness = starPounds.stomach.interpolatedFullness
  local stomachTracker = self.data.stomachThresholds[1].effect
  -- Reverse order. If we're larger than the last size then we don't need to iterate any further.
  for i = #self.data.stomachThresholds, 2, -1 do
    if self.data.stomachThresholds[i].fullness < fullness then
      stomachTracker = self.data.stomachThresholds[i].effect
      break
    end
  end

  return stomachTracker
end

function trackers:removeStomachTrackers()
  for _, tracker in ipairs(self.data.stomachThresholds) do
    status.removeEphemeralEffect(tracker.effect)
  end
end

starPounds.modules.trackers = trackers
