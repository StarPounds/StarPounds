function init()
  world.sendEntityMessage(entity.id(), "queueRadioMessage", "starpounds_liquor")

  animator.setParticleEmitterActive("effects", true)
  expireStatus = effect.getParameter("expireStatus")
  expireStatusDuration = effect.getParameter("expireStatusDuration", 1)

  baseDuration = effect.duration()
end

function onExpire()
  if expireStatus then
    status.addEphemeralEffect(expireStatus, baseDuration * expireStatusDuration)
  end
end
