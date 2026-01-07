require "/scripts/messageutil.lua"
function init()
  storage.stage = storage.stage or config.getParameter("stage", 0)
  storage.bites = storage.bites or config.getParameter("bites", 0)

  self.stages = config.getParameter("stages", 5)
  self.bitesPerStage = config.getParameter("bitesPerStage", 4)
  self.food = config.getParameter("food", 1000)/(self.bitesPerStage * self.stages)
  self.fat = config.getParameter("fat", 0)/(self.bitesPerStage * self.stages)
  self.strainedThresholds = root.assetJson("/scripts/starpounds/starpounds.config:settings.thresholds.strain")

  self.experienceBonus = root.assetJson("/scripts/starpounds/modules/food.config:experienceBonus")
  self.rarity = config.getParameter("rarity", "common"):lower()
  self.bonusExperience = self.food * (self.experienceBonus[self.rarity] or 0)
  self.eatDelay = config.getParameter("eatDelay", 0.35)
  self.eatDelayTracker = {}
  object.setInteractive(true)

  animator.setGlobalTag("stage", storage.stage)
end

function update(dt)
  promises:update()

  -- Track delays per entity.
  for id, delay in pairs(self.eatDelayTracker) do
    self.eatDelayTracker[id] = math.max(delay - dt, 0)

    if self.eatDelayTracker[id] == 0 then
      self.eatDelayTracker[id] = nil
    end
  end
end

function onInteraction(args)
  -- Don't allow if they're on cooldown.
  if self.eatDelayTracker[args.sourceId] then return end
  promises:add(world.sendEntityMessage(args.sourceId, "starPounds.canEat"), function(canEat)
    if not canEat then return end

    animator.burstParticleEmitter("bite")
    animator.playSound("bite")

    world.sendEntityMessage(args.sourceId, "starPounds.feed", self.food, "hugeFood")
    world.sendEntityMessage(args.sourceId, "starPounds.feed", self.fat, "fatFood")
    world.sendEntityMessage(args.sourceId, "starPounds.feed", self.bonusExperience, "bonusExperience")
    world.sendEntityMessage(args.sourceId, "starPounds.playSound", "swallow", 0.75)

    setEatDelay(args.sourceId)

    -- Set the delay on all nearby huge foods within 10 blocks.
    local nearbyHugeFoods = world.objectQuery(world.entityPosition(args.sourceId), 10, {
      callScript = "isHugeFood",
      callScriptResult = true,
      withoutEntityId = entity.id()
    })

    for _, hugeFoodId in pairs(nearbyHugeFoods) do
      world.callScriptedEntity(hugeFoodId, "setEatDelay", args.sourceId)
    end

    storage.bites = storage.bites + 1
    if storage.bites >= self.bitesPerStage then
      storage.stage = storage.stage + 1
      storage.bites = 0
    end
    if storage.stage >= self.stages then
      object.smash()
    end

    animator.setGlobalTag("stage", storage.stage)
  end)
end

function onNpcPlay(npcId)
  onInteraction({sourceId = npcId})
end

function setEatDelay(id)
  self.eatDelayTracker[id] = self.eatDelay
end

function isHugeFood()
  return true
end

function die()
  if storage.stage < self.stages then
    world.spawnItem(config.getParameter("objectName"), entity.position(), 1, {stage = storage.stage, bites = storage.bites})
  end
end
