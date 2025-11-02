function init()
  object.setInteractive(true)
  animations = {
    "smack1",
    "smack2",
    "bounce"
  }
  dialog = {
    interact = {
      "^#b11262;BITC)( did u just slap ma ass",
      "^#b11262;how DAR-E u",
      "^#b11262;u wanna fork shoved up dat ass of urs",
      "^#b11262;i will bitch smack u so hard",
      "^#b11262;u is settin up ur fish sleepin rights",
      "^#b11262;WTF",
      "^#b11262;YO",
      "^#b11262;ya betta start runnin",
      "^#b11262;u wanna fork shoved up dat ass of urs",
      "^#b11262;ya whaley should stop while ur ahead but ya not",
      "^#b11262;u motha fuck"
    },
    stop = {
      "^#b11262;u betta run",
      "^#b11262;coward",
      "^#b11262;get back here u",
      "^#b11262;u aint livin long enough to regret this",
      "^#b11262;im gonna make u into batter",
      "^#b11262;dont make me have to chase u",
      "^#b11262;bitch ass",
      "^#b11262;still behind me cause i need a seat"
    }
  }
  animator.setSoundPitch("talk", 1.25)
  
  animator.setSoundVolume("smack", 0.75)
  animator.setSoundPitch("smack", 1.25)
  
  animator.setSoundVolume("bounce", 1.75)
  animator.setSoundPitch("bounce", 1.25)
  
  cooldown = 0
end

function onInteraction(args)
  if cooldown < 4.3 then
    lastPlayer = args.sourceId
    
    animator.setAnimationState("interactState", "default")
    animation = animations[math.random(1, #animations)]
    
    if animation:find("smack") then
      animator.playSound("smack")
    end
    if animation:find("bounce") then
      animator.playSound("bounce")
    end
    
    if math.random(1, 5) == 1 then
      animator.playSound("talk")
      animator.burstParticleEmitter("emotehappy")
      object.say(tostring(dialog.interact[math.random(1, #dialog.interact)]:gsub("<player>", world.entityName(args.sourceId).."^reset;")))
    end
    
    animator.setAnimationState("interactState", animation)
    cooldown = 5
  end
end

function update(dt)
  cooldown = math.max(cooldown - dt, 0)
  if cooldown == 0 and lastPlayer then
    if math.random(1, 2) == 1 then
      animator.playSound("talk")
      animator.burstParticleEmitter("emotesad")
      object.say(tostring(dialog.stop[math.random(1, #dialog.stop)]:gsub("<player>", world.entityName(lastPlayer).."^reset;")))
    end
    lastPlayer = nil
  end
end