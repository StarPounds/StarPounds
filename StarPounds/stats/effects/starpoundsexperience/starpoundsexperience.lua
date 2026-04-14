function init()
  if effect.duration() > 0 then
    world.sendEntityMessage(entity.id(), "starPounds.experience.add", effect.duration(), config.getParameter("multiplier"), config.getParameter("isLevel"))
  end
end

function update()
  effect.expire()
end
