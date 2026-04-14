function init()
  local effectType = effect.getParameter("type")
  local duration = effect.duration() or 0
  local level = math.max(effect.getParameter("level", 1), 1)

  if effectType and (duration > 0) then
    world.sendEntityMessage(entity.id(), "starPounds.effects.add", effectType, duration, level)
  end
end

function update()
  effect.expire()
end
