function init()
  self.chatOptions = config.getParameter("chatOptions", {})
  self.chatTimer = 0
  self.activationTime = config.getParameter("activationTime") or 60

  if storage.active == nil then activate() end

  options = {
    -- Gain a size
    gainWeight = function()
      world.sendEntityMessage(targetId, "starPounds.offsetSize", 1)
      deactivate()
      animator.playSound("use")
    end,
    -- Gain bloat
    gainBloat = function()
      world.sendEntityMessage(targetId, "starPounds.feed", 50 + math.random(0, 150), "bloat")
      world.sendEntityMessage(targetId, "starPounds.playSound", "digest", 0.75)
      deactivate()
      animator.playSound("use")
    end,
    -- Activate, but do nothing
    crack = function()
      deactivate()
      animator.playSound("crack")
    end,
    -- Smash
    smash = function()
      animator.playSound("use")
      object.smash()
    end
  }

  animator.setAnimationState("state", storage.active and "active" or "expire")
end

function onInteraction(args)
  if storage.active then
      use(args)
  end
end

function update(dt)
  if isTimeToActivate() and not world.isVisibleToPlayer(object.boundBox()) then
    activate()
  end
  self.chatTimer = math.max(0, self.chatTimer - dt)
  if self.chatTimer == 0 and storage.active then
    local players = world.entityQuery(object.position(), config.getParameter("chatRadius"), {
      includedTypes = {"player"},
      boundMode = "CollisionArea"
    })

    if #players > 0 and #self.chatOptions > 0 then
      object.say(self.chatOptions[math.random(1, #self.chatOptions)])
      self.chatTimer = config.getParameter("chatCooldown")
    end
  end
end

function isTimeToActivate()
  return storage.lastActive and world.time() - storage.lastActive > self.activationTime
end

function use(args)
  if storage.active then
    targetId = args.sourceId
    local optionList = config.getParameter("activateOptions")
    local option = optionList[math.random(1, #optionList)]
    if options[option] then
      options[option]()
    else
      options[smash]()
    end
  end
end

function activate()
  animator.setAnimationState("state", "active")
  storage.active = true
  storage.lastActive = false
  object.setInteractive(true)
end

function deactivate()
  animator.setAnimationState("state", "expire")
  storage.active = false
  storage.lastActive = world.time()
  object.setInteractive(false)
end

function getSize(weight, sizes)
  local sizeIndex = 0
  -- Go through all sizes (smallest to largest) to find which size.
  for i in ipairs(sizes) do
    if weight >= sizes[i].weight then
      sizeIndex = i
    end
  end

  return sizes[sizeIndex], sizeIndex
end
