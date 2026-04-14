require "/scripts/messageutil.lua"

function init()
  message.setHandler("starPounds.handler_playSound", localHandler(animator.playSound))
  message.setHandler("starPounds.handler_stopSound", localHandler(animator.stopAllSounds))
  message.setHandler("starPounds.handler_setSoundVolume", localHandler(animator.setSoundVolume))
  message.setHandler("starPounds.handler_setSoundPitch", localHandler(animator.setSoundPitch))
  message.setHandler("starPounds.handler_setSoundPool", localHandler(animator.setSoundPool))
  message.setHandler("starPounds.expireEffects", localHandler(effect.expire))
end

function update(dt)
  effect.modifyDuration(dt)
end
