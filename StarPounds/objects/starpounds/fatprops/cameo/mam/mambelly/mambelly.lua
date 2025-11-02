function init()
  object.setInteractive(true)
  animations = {
    "smack1",
    "smack2",
    "bounce"
  }
  dialog = {
    interact = {
      "O-oh!",
      "Ooo~",
      "Mmph~",
      "Woah!",
      "Keep it up~",
      "Faster!",
      "Soft, isn't it?~",
      "It's just gonna get bigger from here~",
      "Keep wobbling, cutie~",
      "Feel free to stick your face in~",
      "That felt kind of nice~."
    },
    stop = {
      "I want more!",
      "I didn't say to stop!",
      "C-can you keep going?",
      "Stopping so soon?~",
      "How about a goodbye slap before you go?",
      "Done already?",
      "Oh that's it?",
      "You know you want to keep going.",
      "Aww, what a shame.",
      "Call me~",
      "C'mon, we're not done over here~",
      "Intimidated by my squish?~",
      "Come back, It'll be worth your while~"
    }
  }
  animator.setSoundPitch("talk", 1.25)
  
  animator.setSoundVolume("smack", 0.75)
  animator.setSoundPitch("smack", 1.25)
  
  animator.setSoundVolume("bounce", 1.75)
  animator.setSoundPitch("bounce", 1.25)
  animator.setSoundVolume("gurgle", 0.5)
  animator.setSoundPitch("gurgle", 2)
  
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
      animator.playSound("gurgle")
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