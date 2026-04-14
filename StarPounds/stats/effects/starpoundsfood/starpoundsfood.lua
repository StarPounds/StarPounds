function init()
  local duration = effect.duration() or 0
  local foodType = effect.getParameter("type", "default")
  if duration > 0 then
    world.sendEntityMessage(entity.id(), "starPounds.stomach.feed", duration, foodType)
  end
end

function update()
  effect.expire()
end
