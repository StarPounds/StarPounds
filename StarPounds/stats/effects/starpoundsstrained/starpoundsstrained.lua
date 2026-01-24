function init()
  -- Cross script voodoo witch magic.
  starPounds = getmetatable ''.starPounds
end

function update(dt)

  if not starPounds.isEnabled() then
    effect.expire()
    return
  end

  if starPounds.hasOption("disableStrainedMeter") then
    effect.expire()
    return
  end

  local strain = starPounds.moduleFunc("strain", "get")
  if strain == 0 then effect.expire() return end

  if effect.duration() > 0 then
    effect.modifyDuration(strain + dt - effect.duration())
  end
end
