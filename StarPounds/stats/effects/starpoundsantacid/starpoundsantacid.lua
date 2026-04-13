function init()
  world.sendEntityMessage(entity.id(), "starPounds.addEffect", "antacid")
  for _, effectName in ipairs(effect.getParameter("removeEffects", {})) do
    status.removeEphemeralEffect(effectName)
  end
  effect.expire()
end
