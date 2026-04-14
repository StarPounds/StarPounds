require "/scripts/messageutil.lua"

function init()
  self.chatOptions = config.getParameter("chatOptions", {})
  self.chatTimer = 0

  self.activationTime = config.getParameter("activationTime") or 60

  if storage.active == nil then activate() end

  animator.setAnimationState("state", storage.active and "active" or "expire")
end

function onInteraction(args)
  if storage.active then
      use(args)
  end
end

function update(dt)
  promises:update()
  if isTimeToActivate() and not world.isVisibleToPlayer(object.boundBox()) then
    activate()
  end
end

function isTimeToActivate()
  return storage.lastActive and world.time() - storage.lastActive > self.activationTime
end

function use(args)
  if storage.active then
    promises:add(world.sendEntityMessage(args.sourceId, "starPounds.stomach.feed", 50, "liquid"), function()
      animator.playSound("use")
      deactivate()
    end)
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
