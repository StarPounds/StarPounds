function init()
  object.setInteractive(true)
  animations = {
    "smack1",
    "smack2",
    "bounce",
    "bounce"
  }
  dialog = {
    interact = {
      {text = "-ACK...", emote = "surprised"},
      {text = "-HEY...", emote = "surprised"},
      {text = "I could snuff you out in less than a second.", emote = "sad"},
      {text = "If you like it that much, why not add to it?", emote = "happy"},
      {text = "Careful! There could still be crew in there!", emote = "surprised"},
      {text = "Awefully brave for someone standing in range of two tonnes of fox.", emote = "happy"},
      {text = "Ah-... Hello again, <player>, was it?", emote = "happy"},
      {text = "Warau~", emote = "happy"},
      {text = "VALYN!!- Sorry... force of habit.", emote = "happy"},
      {text = "Whef-", emote = "surprised"},
      {text = "Erghf-", emote = "surprised"},
      {text = "Mhrpf-", emote = "surprised"}
    },
    stop = {
      {text = "You off-worlders have a funny way of saying hello.", emote = "confused"},
      {text = "... would the ship console complain if you grabbed the captain...?", emote = "confused"},
      {text = "My turn.", emote = "happy"},
      {text = "Whoof-...", emote = "happy"},
      {text = "So was there anything you actually wanted to talk about or...?", emote = "confused"},
      {text = "You uh...- didn't feel anything in there did you? No? Good! Forget I asked. I mean it.", emote = "confused"},
      {text = "I never know why this keeps happening to me... well maybe I do but...", emote = "happy"},
      {text = "Wait- did I sit on- Ah no, still just jiggling.", emote = "confused"},
      {text = "W-... OH! That's where they went! Hm? What? Nothing.", emote = "surprised"},
      {text = "Oh yeah... I should probably go cash in that bounty...", emote = "confused"},
      {text = "I have devoured entire outposts whole, felt the struggles of dozens wain and fade into one another. Legacies and legends turned into nothing but softness and warmth. <player>, where do you think you're going?", emote = "surprised"},
      {text = "I hope your bed is made out of tungsten.", emote = "happy"}
    }
  }
  animator.setSoundPitch("talk", 1.25)

  animator.setSoundVolume("smack", 0.75)
  animator.setSoundPitch("smack", 1.25)

  animator.setSoundVolume("bounce", 1.75)
  animator.setSoundPitch("bounce", 1.25)
  animator.setSoundVolume("gurgle", 0.5)
  animator.setSoundPitch("gurgle", 2)

  hasNipples = config.getParameter("animationParts", {}).jumpsuit == ""

  cooldown = 0

  if storage.state == nil then
    output(false)
  else
    output(storage.state)
  end
  if storage.timer == nil then
    storage.timer = 0
  end
  self.interval = config.getParameter("interval", 15)
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
      if hasNipples and math.random(1, 5) == 1 then
        animator.setParticleEmitterBurstCount("nippleLeft", math.random(3, 5))
        animator.setParticleEmitterBurstCount("nippleRight", math.random(3, 5))
        animator.burstParticleEmitter("nippleLeft")
        animator.burstParticleEmitter("nippleRight")
      end
    end

    if math.random(1, 5) == 1 then
      local selectedDialog = dialog.interact[math.random(1, #dialog.interact)]
      animator.playSound("talk")
      animator.burstParticleEmitter(selectedDialog.emote)
      object.say(tostring(selectedDialog.text:gsub("<player>", world.entityName(args.sourceId).."^reset;")))
    end

    animator.setAnimationState("interactState", animation)
    cooldown = 5
  end

  if storage.state == false then
    output(true)
  end

  storage.timer = self.interval
end

function update(dt)
  cooldown = math.max(cooldown - dt, 0)
  if cooldown == 0 and lastPlayer then
    if math.random(1, 2) == 1 then
      local selectedDialog = dialog.stop[math.random(1, #dialog.stop)]
      animator.playSound("talk")
      animator.burstParticleEmitter(selectedDialog.emote)
      object.say(tostring(selectedDialog.text:gsub("<player>", world.entityName(lastPlayer).."^reset;")))
    end
    lastPlayer = nil
  end

  if storage.timer > 0 then
    storage.timer = storage.timer - 1

    if storage.timer == 0 then
      output(false)
    end
  end
end

function output(state)
  if storage.state ~= state then
    storage.state = state
    object.setAllOutputNodes(state)
  end
end
