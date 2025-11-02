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
      "H-hey!",
      "Faster!",
      "Your hands are so fast.",
      "It is kind of big, huh?",
      "If you keep this up I'll...",
      "What was that for?",
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
      "You know you want to keep going."
    }
  }
  animator.setSoundPitch("talk", 1.25)
  
  animator.setSoundVolume("smack", 0.75)
  animator.setSoundPitch("smack", 1.25)
  
  animator.setSoundVolume("bounce", 1.75)
  animator.setSoundPitch("bounce", 1.25)
  
  cooldown = 0
end

function sayNext()
  if self.dialog and #self.dialog > 0 then
    if #self.dialog > 0 then
      local options = {
        drawMoreIndicator = self.drawMoreIndicator
      }
      self.dialogTimer = self.dialogInterval
      if #self.dialog == 1 then
        options.drawMoreIndicator = false
        self.dialogTimer = 0.0
      end

      object.sayPortrait(self.dialog[1][1], self.dialog[1][2], nil, options)
      table.remove(self.dialog, 1)

      return true
    end
  else
    self.dialog = nil
    return false
  end
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