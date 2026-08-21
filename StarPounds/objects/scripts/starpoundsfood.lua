require "/scripts/messageutil.lua"

function init()
  storage = config.getParameter("scriptStorage", storage)

  self.stages = config.getParameter("stages", 1)
  self.bitesPerStage = config.getParameter("bitesPerStage", 1)
  self.emptyFinalStage = config.getParameter("emptyFinalStage", false)
  self.smashOnConsume = config.getParameter("smashOnConsume", not self.emptyFinalStage)

  self.edibleStages = self.emptyFinalStage and math.max(1, self.stages - 1) or self.stages
  self.totalBites = self.bitesPerStage * self.edibleStages
  self.isHuge = self.totalBites > 1 -- Huge foods take more than one bite.

  self.price = config.getParameter("price", 0)
  self.basePrice = config.getParameter("basePrice", self.price)

  self.stage = storage.stage or config.getParameter("stage", 0)
  self.bites = storage.bites or config.getParameter("bites", 0)
  self.isConsumed = (self.stage >= self.edibleStages)

  self.food = {}
  local foodTable = config.getParameter("food", {default = 10})
  for foodType, amount in pairs(foodTable) do
    self.food[foodType] = amount / self.totalBites
  end
  -- Npc food table.
  local npcFoodTable = config.getParameter("npcFood")
  if npcFoodTable then
    self.npcFood = {}
    for foodType, amount in pairs(npcFoodTable) do
      self.npcFood[foodType] = amount / self.totalBites
    end
  end
  -- Regeneration.
  self.regenerate = config.getParameter("regenerate", false)
  self.regenerateTime = config.getParameter("regenerateTime", 60)
  self.regenerateTimer = self.regenerateTime
  self.npcRegenerateOnly = config.getParameter("npcRegenerateOnly", false)
  self.chefRefresh = config.getParameter("chefRefresh", false)

  self.statusEffects = config.getParameter("foodStatusEffects", {})
  self.eatDelay = config.getParameter("eatDelay", 0.35)
  self.eatDelayTracker = {}
  self.updateInventoryIcon = config.getParameter("updateInventoryIcon", false)
  self.baseInventoryIcon = config.getParameter("baseInventoryIcon", config.getParameter("inventoryIcon"))
  -- If NPCs should permanently alter the food.
  self.npcSaveState = config.getParameter("npcSaveState", self.isHuge)

  object.setInteractive(not self.isConsumed)
  updateObject(false)
end

function update(dt)
  promises:update()
  -- Track cooldown per entity,
  for id, delay in pairs(self.eatDelayTracker) do
    self.eatDelayTracker[id] = math.max(delay - dt, 0)
    if self.eatDelayTracker[id] == 0 then
      self.eatDelayTracker[id] = nil
    end
  end
  -- Regenerating foods.
  if self.regenerate then
    local canRegen = not (self.npcRegenerateOnly and storage.playerEaten)
    -- Check if there are missing bites and it can regenerate.
    if canRegen and (self.stage > 0 or self.bites > 0) then
      self.regenerateTimer = math.max(self.regenerateTimer - dt, 0)
      if self.regenerateTimer == 0 then
        self.regenerateTimer = self.regenerateTime
        -- Restore one bite
        if self.bites > 0 then
          self.bites = self.bites - 1
        elseif self.stage > 0 then
          self.stage = self.stage - 1
          self.bites = self.bitesPerStage - 1
        end

        self.isConsumed = false
        object.setInteractive(true)

        local shouldSave = storage.playerEaten or self.npcSaveState
        updateObject(shouldSave)
        if shouldSave then
          storage.stage = self.stage
          storage.bites = self.bites
          object.setConfigParameter("scriptStorage", storage)
        end
      end
    else
      self.regenerateTimer = self.regenerateTime
    end
  end
end

function onInteraction(args)
  -- Sanity check.
  if self.eatDelayTracker[args.sourceId] or self.isConsumed then return end
  promises:add(world.sendEntityMessage(args.sourceId, "starPounds.stomach.canEat"), function(canEat)
    -- Sanity check.
    if not canEat or self.isConsumed then return end
    local isPlayer = world.entityType(args.sourceId) == "player"
    if isPlayer then
      storage.playerEaten = true
    end
    -- Sound and particles.
    animator.burstParticleEmitter("bite")
    animator.playSound("bite")
    world.sendEntityMessage(args.sourceId, "starPounds.sound.play", "swallow", 0.75)
    -- Feed the entity.
    local activeFood = (not isPlayer and self.npcFood) and self.npcFood or self.food
    for foodType, amount in pairs(activeFood) do
      world.sendEntityMessage(args.sourceId, "starPounds.stomach.feed", amount, foodType)
    end
    -- Apply status effects.
    for _, statusEffect in ipairs(self.statusEffects) do
      local effect = type(statusEffect) == "table" and statusEffect.effect or statusEffect
      local duration = type(statusEffect) == "table" and statusEffect.duration or nil
      world.sendEntityMessage(args.sourceId, "applyStatusEffect", effect, duration, entity.id())
    end
    -- Set cooldown to nearby huge foods.
    setEatDelay(args.sourceId)
    if self.isHuge then
      local nearbyHugeFoods = world.objectQuery(world.entityPosition(args.sourceId), 10, {
        callScript = "isHugeFood",
        callScriptResult = true,
        withoutEntityId = entity.id()
      })
      for _, hugeFoodId in pairs(nearbyHugeFoods) do
        world.callScriptedEntity(hugeFoodId, "setEatDelay", args.sourceId)
      end
    end
    -- Update stage.
    self.bites = self.bites + 1
    if self.bites >= self.bitesPerStage then
      self.stage = self.stage + 1
      self.bites = 0
    end
    -- Check if food is finished.
    if self.stage >= self.edibleStages then
      self.isConsumed = true
      self.stage = self.edibleStages
      -- Destroy if finished.
      if self.smashOnConsume then
        object.smash(true)
        return
      else
        object.setInteractive(false)
      end
    end
    local shouldSave = isPlayer or self.npcSaveState
    -- Only modify storage if we are saving data.
    updateObject(shouldSave)
    if shouldSave then
      storage.stage = self.stage
      storage.bites = self.bites
      object.setConfigParameter("scriptStorage", storage)
      -- Make the object drop normally if it's unconsumed.
      object.setConfigParameter("retainObjectParametersInItem", (self.stage + self.bites) > 0)
    end
  end)
end

function updateObject(save)
  -- Set progress/stage.
  animator.setGlobalTag("stage", self.stage)
  -- Only edit the placement image/icon if we're saving.
  if save then
    local part = config.getParameter("animationParts.food")
    if part then
      object.setConfigParameter("placementImage", part..":"..self.stage)
    end
    if self.updateInventoryIcon and self.baseInventoryIcon then
      object.setConfigParameter("inventoryIcon", self.baseInventoryIcon..":"..self.stage)
    end
    -- Scale price based on how many bites taken.
    local bites = (self.stage * self.bitesPerStage) + self.bites
    local remainingRatio = 1 - (bites / self.totalBites)
    local price = self.basePrice + ((self.price - self.basePrice) * remainingRatio)

    object.setConfigParameter("price", math.floor(price))
  end
end

function setEatDelay(id)
  self.eatDelayTracker[id] = self.eatDelay
end

function isHugeFood()
  return self.isHuge
end

function isFattening()
  return true
end

function canEat()
  return not self.isConsumed
end

function canRefresh()
  return self.chefRefresh and self.isConsumed
end

function refresh()
  storage = {}
  self.stage = 0
  self.bites = 0
  self.isConsumed = (self.stage >= self.edibleStages)
  object.setInteractive(not self.isConsumed)
  object.setConfigParameter("scriptStorage", storage)
  -- Make the object drop normally if it's unconsumed.
  object.setConfigParameter("retainObjectParametersInItem", false)
  updateObject(true)
end

function npcToy.getInfluence()
  if self.chefRefresh and self.isConsumed then
    -- When empty, make chefs want to restock the object.
    return {"starpoundsemptyfood"}
  else
    return config.getParameter("npcToy.influence")
  end
end

function npcToy.isPriority()
  return (self.isConsumed and self.chefRefresh) or not self.isConsumed
end

function npcToy.isAvailable()
  return not (npcToy.isOccupied() or (self.isConsumed and not self.chefRefresh))
end

function npcToy.isOccupied()
  local remainingBites = self.totalBites - (self.stage * self.bitesPerStage + self.bites)
  return npcToy.npcCount >= math.max(remainingBites, 1)
end
