function init()
  script.setUpdateDelta(5)
  self.progressStep = effect.getParameter("progressStep", 0.01) * effect.duration()

  animator.setSoundVolume("digest", 0.75)
  animator.setSoundPitch("digest", 1)

  starPounds = getmetatable ''.starPounds
  local entityType = world.entityType(entity.id())
  if entityType == "npc" then
    increaseWeightProgress(world.callScriptedEntity(entity.id(), "starPounds.moduleFunc", "data", "get", "weight"), self.progressStep)
  elseif starPounds and starPounds.isEnabled() and entityType == "player"  then
    increaseWeightProgress(starPounds.moduleFunc("data", "get", "weight"), self.progressStep)
  end
  effect.expire()
end
