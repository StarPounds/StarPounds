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
      {text = "I never know why this keeps happening to me... well maybe I do but...", emote = "happy"},
      {text = "Wait- did I sit on- Ah no, still just jiggling.", emote = "confused"},
      {text = "I have devoured entire outposts whole, felt the struggles of dozens wain and fade into one another. Legacies and legends turned into nothing but softness and warmth. <player>, where do you think you're going?", emote = "surprised"},
      {text = "I hope your bed is made out of tungsten.", emote = "happy"}
    }
  }
  animator.setSoundPitch("talk", 1.25)

  animator.setSoundVolume("smack", 0.75)
  animator.setSoundPitch("smack", 1.25)

  animator.setSoundVolume("bounce", 1.75)
  animator.setSoundPitch("bounce", 1.25)

  cooldown = 0
  opacity = 1
  opacityDelay = 0

  if storage.state == nil then
    output(false)
  else
    output(storage.state)
  end
  if storage.timer == nil then
    storage.timer = 0
  end
  self.interval = config.getParameter("interval", 75)
end

function onInteraction(args)
  opacityDelay = 1

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

  opacityDelay = math.max(opacityDelay - dt, 0)
  if opacityDelay == 0 then
    if opacity < 1 then
      opacity = math.min(opacity + (2 * dt), 1)
      animator.setGlobalTag("tailOpacity", hexConverter(math.floor(255 * opacity + 0.5)))
    end
  else
    if opacity > 0 then
      opacity = math.max(opacity - (10 * dt), 0)
      animator.setGlobalTag("tailOpacity", hexConverter(math.floor(255 * opacity + 0.5)))
    end
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

function hexConverter(input)
  local hexCharacters = '0123456789abcdef'
  local output = ''
  while input > 0 do
      local mod = math.fmod(input, 16)
      output = string.sub(hexCharacters, mod+1, mod+1) .. output
      input = math.floor(input / 16)
  end
  if output == '' then output = '0' end
  if string.len(output) == 1 then output = '0'..output end
  return output
end
