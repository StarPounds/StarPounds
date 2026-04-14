local breasts = starPounds.module:new("breasts")

function breasts:init()
  self.lactationTimer = 0
  self:get()

  self.defaultContents = {
    capacity = self.data.breastCapacity,
    maxCapacity = self.data.breastCapacity,
    type = "milk",
    contents = 0,
    fullness = 0
  }

  message.setHandler("starPounds.breasts.get", function(_, _, ...) return self:get(...) end)
  message.setHandler("starPounds.setMilkType", function(_, _, ...) return self:setMilkType(...) end)
  message.setHandler("starPounds.setMilk", function(_, _, ...) return self:setMilk(...) end)
  message.setHandler("starPounds.gainMilk", function(_, _, ...) return self:gainMilk(...) end)
  message.setHandler("starPounds.loseMilk", function(_, _, ...) return self:loseMilk(...) end)
  message.setHandler("starPounds.lactate", function(_, _, ...) return self:lactate(...) end)
  message.setHandler("starPounds.resetBreasts", localHandler(self.reset))
end

function breasts:update(dt)
  self.breasts = nil
  self:get()
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if eaten.
  if storage.starPounds.pred then return end
  -- Check if breast capacity is exceeded.
  if self.breasts.contents > self.breasts.capacity then
    if starPounds.hasOption("disableLeaking") then
      if not starPounds.hasOption("disableMilkGain") then
        storage.starPounds.breasts.amount = self.breasts.capacity
      end
      return
    end
    self.lactationTimer = math.max(self.lactationTimer - dt, 0)
    if self.lactationTimer == 0 then
      local amount = math.min(math.round(self.breasts.fullness * 0.5, 1), 1, self.breasts.contents - self.breasts.capacity)
      -- Lactate away excess
      self:lactate(amount)
      self.lactationTimer = math.round(util.randomInRange({self.data.minimumLactationTime, (self.data.lactationTime * 2) - self.data.minimumLactationTime}))
    end
  end
end

function breasts:get()
  -- Return default if the mod is disabled.
  if not storage.starPounds.enabled then return self.defaultContents end
  -- Don't recalculate multiple times a tick.
  if self.breasts then return self.breasts end
  local breastCapacity = (starPounds.moduleFunc("size", "breastCapacity") or self.data.breastCapacity) * starPounds.getStat("breastCapacity")
  if starPounds.hasOption("disableLeaking") then
    storage.starPounds.breasts.amount = math.min(storage.starPounds.breasts.amount, breastCapacity)
  end
  local breastContents = storage.starPounds.breasts.amount

  self.breasts = {
    capacity = breastCapacity,
    maxCapacity = breastCapacity * (starPounds.hasOption("disableLeaking") and 1 or self.data.milkGenerationCap),
    type = storage.starPounds.breasts.type or "milk",
    contents = math.round(breastContents, 4),
    fullness = math.round(breastContents/breastCapacity, 4)
  }

  return self.breasts
end

function breasts:lactate(amount, noConsume)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if eaten.
  if storage.starPounds.pred then return end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  -- Skip if no milk.
  if amount == 0 then return end
  if self.breasts.contents == 0 then return end
  -- Don't spawn milk automatically if leaking is disabled, gain it instead.
  if starPounds.hasOption("disableLeaking") and noConsume then self:gainMilk(amount) return end
  amount = math.min(math.round(amount, 4), self.breasts.contents)
  -- Slightly below and in front the head.
  local spawnPosition = vec2.add(world.entityMouthPosition(starPounds.entityId), {starPounds.mcontroller.facingDirection, -1})
  local existingLiquid = world.liquidAt(spawnPosition) and world.liquidAt(spawnPosition)[1] or nil
  local lactationLiquid = root.liquidId(self.breasts.type)
  local doLactation = not existingLiquid or (lactationLiquid == existingLiquid)
  -- Only remove the milk if it actually spawns.
  if doLactation and world.spawnLiquid(spawnPosition, lactationLiquid, amount) and not noConsume then
    self:loseMilk(amount)
  end
end

function breasts:setMilkType(liquidType)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  liquidType = tostring(liquidType)
  -- Skip if it's the same type of milk.
  if liquidType == storage.starPounds.breasts.type then return end
  -- Only allow liquids we have values for.
  local currentFood = starPounds.moduleFunc("liquid", "getFood", self.breasts.type)
  local newFood = starPounds.moduleFunc("liquid", "getFood", liquidType)
  local convertRatio = currentFood/newFood
  storage.starPounds.breasts.type = liquidType
  self:setMilk(self.breasts.contents * convertRatio)
end

function breasts:milkProduction(food)
  local milkCost = 0
  local milkProduced = 0
  local breastEfficiency = starPounds.getStat("breastEfficiency")
  if (food > 0) and (breastEfficiency > 0) and not starPounds.hasOption("disableMilkGain") then
    local milkValue = starPounds.moduleFunc("liquid", "getFood", self.breasts.type)
    if self.breasts.contents < self.breasts.maxCapacity then
      local productionMultiplier = math.min(1, breastEfficiency) -- More milk produced per food, up to 1:1 for the food value of the milk.
      local costMultiplier = 1/math.max(1, breastEfficiency) -- Excess breast efficiency stat reduces the cost of milk in terms of food, but not milk produced. (i.e. you'd gain weight, even with 100% production)
      milkCost = food * costMultiplier
      milkProduced = math.round((food/milkValue) * productionMultiplier, 4)
      if (self.breasts.capacity - self.breasts.contents) < milkProduced then
        -- Free after you've maxed out capacity, but you only gain a third as much.
        milkProduced = util.clamp(self.breasts.capacity - self.breasts.contents, milkProduced/3, self.breasts.maxCapacity - self.breasts.contents)
        milkCost = math.max(0, self.breasts.capacity - self.breasts.contents) * milkValue * costMultiplier
      end
    end
  end
  return milkProduced, milkCost
end

function breasts:setMilk(amount)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  amount = math.round(math.max(tonumber(amount) or 0, 0), 4)
  storage.starPounds.breasts.amount = amount
end

function breasts:gainMilk(amount)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return 0 end
  -- Don't do anyhting if milk gain is disabled.
  if starPounds.hasOption("disableMilkGain") then return 0 end
  -- Argument sanitisation.
  amount = util.clamp(tonumber(amount) or 0, 0, self.breasts.maxCapacity - self.breasts.contents)
  self:setMilk(storage.starPounds.breasts.amount + amount)
  return amount
end

function breasts:loseMilk(amount)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return 0 end
  -- Argument sanitisation.
  amount = util.clamp(tonumber(amount) or 0, 0, storage.starPounds.breasts.amount)
  self:setMilk(storage.starPounds.breasts.amount - amount)
  return amount
end

function breasts.reset()
  storage.starPounds.breasts.amount = 0
  return true
end

starPounds.modules.breasts = breasts
