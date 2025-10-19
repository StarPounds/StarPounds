function init()
  -- Cross script voodoo witch magic.
  starPounds = getmetatable ''.starPounds
  -- Kill status if we're not a player.
  isPlayer = starPounds and (starPounds.type == "player")
  if not isPlayer then
    update = function() end
    effect.expire()
    return
  end

  effectName = effect.getParameter("effect")
  local effectConfig = starPounds.moduleFunc("effects", "getConfig", effect.getParameter("effect"))
  if effectConfig then
    baseDuration = effectConfig.duration
  else
    effect.expire()
  end
end

function update(dt)
  local effectData = starPounds.moduleFunc("effects", "get", effectName)
  if starPounds.isEnabled() and effectData then
    local percent = math.min(effectData.duration / baseDuration, 1)
    effect.modifyDuration(percent + dt - effect.duration())
  else
    effect.expire()
  end
end
