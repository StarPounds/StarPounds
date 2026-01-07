require "/scripts/messageutil.lua"

function init()
  message.setHandler("starPounds.expire", localHandler(effect.expire))
  self.range = effect.getParameter("range", {0, 1})
  self.maxRangeExpire = effect.getParameter("maxRangeExpire", true)
  self.fillRange = effect.getParameter("fillRange", {1, 16})
  self.scale = ( self.fillRange[2] - (self.fillRange[1] - 1) ) / 16
  self.buffer = 100 * (self.fillRange[1] - 1) / 16
  -- Cross script voodoo witch magic.
  starPounds = getmetatable ''.starPounds
  -- Force these to reapply if they're active.
  if starPounds.isEnabled() then
    status.removeEphemeralEffect("wellfed")
    status.removeEphemeralEffect("starpoundswellfeddelay")
  end
end

function update(dt)
  local progress = math.min(math.max(starPounds.stomach.interpolatedFullness - self.range[1], 0) / (self.range[2] - self.range[1]), 1) * 100
  if effect.duration() > 0 then
    -- "Center" the animation.
    effect.modifyDuration((progress * self.scale) + self.buffer + dt - effect.duration())
  end

  if starPounds and (
    starPounds.hasOption("disableStomachMeter") or
    starPounds.hasOption("legacyMode") or
    starPounds.stomach.interpolatedFullness < self.range[1] or
    (self.maxRangeExpire and starPounds.stomach.interpolatedFullness > self.range[2])
  ) then
    effect.expire()
  end
end
