function init()
  local source = effect.sourceEntity()
  local options = effect.getParameter("options", {})
  if source ~= entity.id() then
    world.sendEntityMessage(entity.id(), "starPounds.eatEntity", source, options)
  end
  effect.expire()
end

function update()
  effect.expire()
end
