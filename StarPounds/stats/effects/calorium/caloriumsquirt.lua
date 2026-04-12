function init()
  script.setUpdateDelta(5)
  self.progressStep = effect.getParameter("progressStep", 0.01) * effect.duration()

  animator.setSoundVolume("digest", 0.75)
  animator.setSoundPitch("digest", 1)

  starPounds = getmetatable ''.starPounds
  if world.entityType(entity.id()) == "npc" or (starPounds and starPounds.isEnabled()) then
    if starPounds and starPounds.isEnabled() then
      increaseWeightProgress(starPounds.moduleFunc("data", "get", "weight"), self.progressStep)
    else
      increaseWeightProgress(world.callScriptedEntity(entity.id(), "starPounds.moduleFunc", "data", "get", "weight"), self.progressStep)
    end
  end
  effect.expire()
end
