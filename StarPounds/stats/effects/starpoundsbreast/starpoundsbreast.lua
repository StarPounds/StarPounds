require "/scripts/messageutil.lua"

function init()
  message.setHandler("starPounds.expireEffects", localHandler(effect.expire))
  self.fillRange = effect.getParameter("fillRange", {1, 16})
  self.scale = ( self.fillRange[2] - (self.fillRange[1] - 1) ) / 16
  self.buffer = 100 * (self.fillRange[1] - 1) / 16
  -- Cross script voodoo witch magic.
  starPounds = getmetatable ''.starPounds
  isPlayer = starPounds and (starPounds.type == "player")
end

function update(dt)
  if isPlayer then
    local progress = math.min(starPounds.moduleFunc("breasts", "get").fullness, 1) * 100
    if effect.duration() and (effect.duration() > 0) then
      -- "Center" the animation.
      effect.modifyDuration((progress * self.scale) + self.buffer + dt - effect.duration())
    end

    if starPounds and (not starPounds.hasOption("breastMeter")) then
      effect.expire()
    end
  end
end
