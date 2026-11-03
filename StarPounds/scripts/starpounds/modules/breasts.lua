local breasts = starPounds.module:new("breasts")

function breasts:init()
  self.lactationTimer = 0
  self.leakTimer = 0
  self.leakCooldown = 0
  self.particleCache = {}
  self:get()
  self.defaultContents = {
    capacity = self.data.breastCapacity,
    maxCapacity = self.data.breastCapacity,
    type = "milk",
    contents = 0,
    fullness = 0
  }

  message.setHandler("starPounds.breasts.get", function(_, _, ...) return self:get(...) end)
  message.setHandler("starPounds.breasts.setMilkType", function(_, _, ...) return self:setMilkType(...) end)
  message.setHandler("starPounds.breasts.setMilk", function(_, _, ...) return self:setMilk(...) end)
  message.setHandler("starPounds.breasts.gainMilk", function(_, _, ...) return self:gainMilk(...) end)
  message.setHandler("starPounds.breasts.loseMilk", function(_, _, ...) return self:loseMilk(...) end)
  message.setHandler("starPounds.breasts.lactate", function(_, _, ...) return self:lactate(...) end)
  message.setHandler("starPounds.breasts.reset", localHandler(self.reset))
end

function breasts:update(dt)
  self.breasts = nil
  self:get()
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if eaten.
  if storage.starPounds.pred then return end
  -- Visual leaking after lactation.
  if self.leakTimer > 0 then
    self.leakTimer = math.max(0, self.leakTimer - dt)
    self.leakCooldown = math.max(0, self.leakCooldown - dt)
    if self.leakCooldown == 0 and self.breasts.contents > 0 then
      local timerMultiplier = self.leakTimer / self.data.lactationLeakTime
      self.leakCooldown = self.data.lactationLeakInterval[2] - (self.data.lactationLeakInterval[2] - self.data.lactationLeakInterval[1]) * timerMultiplier
      self:lactate(0.1, true, 0, {particles = timerMultiplier, velocity = self.data.lactationLeakVelocity * timerMultiplier}, true)
    end
  end
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
      local amount = math.min(math.round(self.breasts.fullness * 0.5, 1), self.data.lactationAmount, self.breasts.contents - self.breasts.capacity)
      -- Lactate away excess.
      self:lactate(amount)
      self.lactationTimer = math.round(util.randomInRange({self.data.lactationTimeMinimum, (self.data.lactationTime * 2) - self.data.lactationTimeMinimum}))
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

function breasts:lactate(amount, noConsume, aimAngle, multipliers, sprayOnly)
  -- Don't do anything if the mod is disabled or eaten.
  if not storage.starPounds.enabled or storage.starPounds.pred then return end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  if amount == 0 or self.breasts.contents == 0 then return end
  -- Don't spawn milk automatically if leaking is disabled, gain it instead.
  if starPounds.hasOption("disableLeaking") and noConsume then
    self:gainMilk(amount)
    return
  end
  amount = math.min(math.round(amount, 4), self.breasts.contents)
  multipliers = multipliers or {}
  -- Grab nipple positions, or just slightly below and in front of the head.
  local nipplePositions = starPounds.moduleFunc("size", "nipplePositions") or {
    {position = vec2.add(world.entityMouthPosition(starPounds.entityId), {starPounds.mcontroller.facingDirection, -1})}
  }
  local nipple = nipplePositions[math.random(1, #nipplePositions)]
  local existingLiquid = (world.liquidAt(nipple.position) or {})[1]
  local lactationLiquid = root.liquidId(self.breasts.type)
  -- Only spawn particles outside of liquids.
  if not existingLiquid then
    self:spawnLactationProjectiles(nipple, nipplePositions, amount, aimAngle, multipliers, sprayOnly)
    if not sprayOnly and not noConsume then
      self:loseMilk(amount)
    end
  elseif (lactationLiquid == existingLiquid) and world.spawnLiquid(nipple.position, lactationLiquid, amount) and not noConsume then
    -- Only remove the milk if it actually spawns.
    self:loseMilk(amount)
  end
end

function breasts:spawnLactationProjectiles(nipple, nipplePositions, amount, aimAngle, multipliers, sprayOnly)
  local physics = self:lactationPhysics(nipple.position, amount, aimAngle, multipliers)
  local particles = self:getParticles(self.breasts.type)
  local parameters = {
    speed = physics.speed,
    actionOnReap = physics.gravity ~= 0 and {{action = "liquid", liquid = self.breasts.type, quantity = amount}} or nil
  }

  if particles then
    if not sprayOnly then
      local mainParticle = copy(particles.main)
      mainParticle.size = mainParticle.size * physics.particleScale
      mainParticle.variance.size = mainParticle.variance.size * physics.particleScale
      mainParticle.initialVelocity = physics.velocity
      mainParticle.finalVelocity = {0, -physics.gravity}
      mainParticle.approach = {0, physics.gravity * physics.gravityMult}
      mainParticle.layer = nipple.behind and "back" or "middle"
      parameters.periodicActions = {{
        time = 0,
        ["repeat"] = false,
        action = "particle",
        specification = mainParticle
      }}
    end

    local sprayParticle = copy(particles.spray)
    sprayParticle.size = sprayParticle.size * physics.particleScale
    sprayParticle.variance.size = sprayParticle.variance.size * physics.particleScale
    sprayParticle.initialVelocity = physics.velocity
    sprayParticle.finalVelocity = {0, -physics.gravity}
    sprayParticle.approach = {5, physics.gravity * physics.gravityMult}

    local countMultiplier = (multipliers.particles or 1) * (physics.particleScale / self.data.lactationParticleScaleMaximum)
    local particleCount = math.round((self.data.lactationSprayParticleCount or 0) * math.max(countMultiplier, 1))
    local action = {time = 0, ["repeat"] = false, action = "particle", specification = sprayParticle}
    local periodicActions = jarray()
    for i = 1, particleCount do
      periodicActions[i] = action
    end

    local sprayParameters = {
      speed = physics.speed,
      timeToLive = 5 / 60,
      periodicActions = periodicActions
    }
    for _, nipple in ipairs(nipplePositions) do
      sprayParticle.layer = nipple.behind and "back" or "middle"
      world.spawnProjectile(self.data.lactationProjectile, nipple.position, starPounds.entityId, physics.direction, false, sprayParameters)
    end

    if not sprayOnly then
      self.leakTimer = self.data.lactationLeakTime
      self.leakCooldown = self.data.lactationLeakInterval[1] + (self.data.scriptDelta / 60)
    end
  end

  if not sprayOnly then
    -- Spawn main projectile.
    world.spawnProjectile(self.data.lactationProjectile, nipple.position, starPounds.entityId, physics.direction, false, parameters)
    -- Add momentum in zero g, because why not.
    if starPounds.type == "player" and physics.gravity == 0 then
      local recoilDir = vec2.rotate(vec2.norm(physics.baseVelocity), aimAngle or 0)
      local recoilStrength = -0.25 * (0.5 + starPounds.weightMultiplier * 0.5) * physics.velocityScale * physics.particleScale
      mcontroller.addMomentum(vec2.mul(recoilDir, recoilStrength))
    end
  end
end

function breasts:lactationPhysics(position, amount, aimAngle, multipliers)
  local facing = starPounds.mcontroller.facingDirection
  local gravity = world.gravity(position)
  -- Only boost velocity when using ability.
  local velocityScale = 1
  if aimAngle then
    velocityScale = self.data.lactationVelocityScale[1] + (self.data.lactationVelocityScale[2] - self.data.lactationVelocityScale[1]) * math.min(self.breasts.fullness, 1) * (multipliers.velocity or 1)
  end
  local particleScale = math.min(
    self.data.lactationParticleScale[1] + (self.data.lactationParticleScale[2] - self.data.lactationParticleScale[1]) * math.min(amount, 1),
    self.data.lactationParticleScaleMaximum
  )
  local baseVelocity = {
    self.data.lactationVelocity[1] * facing * velocityScale,
    self.data.lactationVelocity[2] * gravity / 80 * velocityScale
  }

  local spread = (math.random() - 0.5) * math.rad(self.data.lactationSpread) * (multipliers.spread or 1) + (aimAngle or 0)
  local velocity = vec2.rotate({
    baseVelocity[1] + (math.random() - 0.5) * self.data.lactationVelocityVariance[1] * facing * velocityScale,
    baseVelocity[2] + (math.random() - 0.5) * self.data.lactationVelocityVariance[2] * gravity / 80 * velocityScale
  }, spread)
  velocity = vec2.add(velocity, starPounds.mcontroller.velocity)

  return {
    gravity = gravity,
    gravityMult = 0.5, -- Update /projectiles/unsorted/milkprojectile/starpoundsmilkspawner.projectile:gravityMultiplier if you change this.
    velocityScale = velocityScale,
    particleScale = particleScale,
    baseVelocity = baseVelocity,
    velocity = velocity,
    speed = vec2.mag(velocity),
    direction = vec2.norm(velocity)
  }
end

-- Forces the lactation timer to zero to trigger passive leaking. (i.e. when moving around)
function breasts:triggerLeak()
  self.lactationTimer = 0
end

function breasts:getParticles(liquidType)
  if self.particleCache[liquidType] == nil then
    local base = starPounds.moduleFunc("liquid", "getParticles", liquidType)
    if base then
      local main = sb.jsonMerge(base, self.data.lactationParticleConfig)
      local spray = sb.jsonMerge(base, self.data.lactationSprayParticleConfig)
      main.variance = copy(self.data.lactationParticleConfig.variance)
      spray.variance = copy(self.data.lactationSprayParticleConfig.variance)
      self.particleCache[liquidType] = {main = main, spray = spray}
    else
      self.particleCache[liquidType] = false
    end
  end
  return self.particleCache[liquidType]
end

function breasts:setMilkType(liquidType)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  liquidType = tostring(liquidType)
  -- Skip if it's the same type of milk.
  if liquidType == storage.starPounds.breasts.type then return end
  -- Only allow edible liquids.
  if not starPounds.moduleFunc("liquid", "edible", liquidType) then return end
  -- Convert liquid amounts.
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
