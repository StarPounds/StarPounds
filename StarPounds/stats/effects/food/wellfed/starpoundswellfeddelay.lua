require "/scripts/messageutil.lua"

function init()
  -- Cross script voodoo witch magic.
  starPounds = getmetatable ''.starPounds
end

function update(dt)
  local delay = starPounds.moduleFunc("stomach", "getFullnessDelay")
  local maxDelay = starPounds.getStat("gorgingDuration")

  if (delay == 0) or (maxDelay == 0) or not starPounds.isEnabled() then
    effect.expire()
    return
  end

  local progress = 1 - (delay / maxDelay)
  if progress == 1 then effect.expire() return end

  if effect.duration() > 0 then
    -- "Center" the animation.
    effect.modifyDuration(progress + dt - effect.duration())
  end
end
