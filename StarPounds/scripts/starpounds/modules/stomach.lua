local stomach = starPounds.module:new("stomach")

function stomach:init()
  message.setHandler("starPounds.getStomach", function(_, _, ...) return self:get(...) end)
  message.setHandler("starPounds.feed", function(_, _, ...) return self:feed(...) end)
  message.setHandler("starPounds.eat", function(_, _, ...) return self:eat(...) end)
  message.setHandler("starPounds.digest", function(_, _, ...) return self:digest(...) end)
  message.setHandler("starPounds.gurgle", function(_, _, ...) return self:gurgle(...) end)
  message.setHandler("starPounds.rumble", function(_, _, ...) return self:rumble(...) end)
  message.setHandler("starPounds.resetStomach", localHandler(self.reset))
  -- Timers.
  self.digestTimer = 0
  self.gurgleTimer = nil
  self.rumbleTimer = nil
  self.belchTimer = nil
  self.stretchCooldown = nil
  -- Sloshing.
  self.sloshTimer = 0
  self.sloshDeactivateTimer = 0
  self.sloshActivations = 0

  self.squelchVolume = 0

  self.preySquelching = false

  self.digestionExperience = 0

  self.defaultContents = {
    capacity = self.data.stomachCapacity,
    amount = 0,
    contents = 0,
    food = 0,
    belchable = 0,

    fullness = 0,
    baseFullness = 0,
    interpolatedFullness = 0,
    interpolatedContents = 0
  }

  starPounds.stomach = self:get()
  -- Assume the lerp is the same as the contents on load (if the mod is enabled).
  self.stomachLerp = storage.starPounds.enabled and self.stomach.contents or 0
  -- Delete json metadata so we don't store nils.
  setmetatable(storage.starPounds.stomach, nil)

  self:squelchEvents()
end

function stomach:update(dt)
  self:set()
  self:digest(dt)
  self:sloshing(dt)
  self:squelching(dt)
  self:interpolateContents(dt)

  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Stretch effect cooldown.
  if self.stretchCooldown then
    self.stretchCooldown = math.max(self.stretchCooldown - dt, 0)
    if self.stretchCooldown == 0 then
      self.stretchCooldown = nil
    end
  end
end

function stomach:feed(amount, foodType)
  -- Runs eat, but adapts for player food.
  -- Use this rather than eat() unless we don't care about the hunger bar for some reason.

  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  -- Don't do anything if there's no food.
  if amount == 0 then return end
  if not storage.starPounds.enabled then
    -- Modify food recieved by the config.
    local foodConfig, foodType = starPounds.moduleFunc("food", "foodType", foodType)
    if status.isResource("food") then
      status.giveResource("food", amount * foodConfig.multipliers.food)
    end
  else
    self:eat(amount, foodType)
  end
end

function stomach:eat(amount, foodType)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
    -- Modify food recieved by the config.
  local foodConfig, foodType = starPounds.moduleFunc("food", "foodType", foodType)
  -- Don't do anything if there's no food.
  if amount == 0 then return end
  -- Food type capacity cap.
  local maxCapacity = math.huge
  if foodConfig.maxCapacity then
    maxCapacity = self.stomach.capacity * (foodConfig.maxCapacity / foodConfig.multipliers.capacity)
  end
  -- Stats that affect the amount gained.
  if foodConfig.amountStats then
    for _, stat in pairs(foodConfig.amountStats) do
      amount = math.max(amount * starPounds.getStat(stat), 0)
    end
  end
  -- Insert food into stomach.
  amount = math.round(amount, 3)
  storage.starPounds.stomach[foodType] = math.min((storage.starPounds.stomach[foodType] or 0) + amount, maxCapacity)
  -- Effects triggered by eating. Don't continue if none apply.
  if not (foodConfig.triggersStretching or foodConfig.triggersSquelch or foodConfig.stuffingDamage) then return end
  -- Calculate difference in 'fullness' past 300%.
  local lastFullness = math.max(self.stomach.fullness, self.data.stuffingFullnessThreshold)
  self:set()
  local diff = math.max(self.stomach.fullness - lastFullness, 0)

  -- Apply the stomach stretch effect. Chance is based on fullness increase.
  if foodConfig.triggersStretching and math.random() < diff then
    -- Apply effect if not on cooldown.
    if foodConfig.stuffingDamage and not self.stretchCooldown then
      local stretchLevel = math.max(math.random() * diff, 1)
      starPounds.moduleFunc("effects", "add", "stomachStretch", nil, stretchLevel)
      self.stretchCooldown = math.round(util.randomInRange({self.data.minimumStretchCooldown, (self.data.stretchCooldown * 2) - self.data.minimumStretchCooldown}))
    end
    -- Stretch Sound.
    if not starPounds.hasOption("disableStretchSounds") then
      -- Pitch gets lower/volume gets higher if the difference is up to 200% capacity.
      local volumeMod = math.min(diff * 0.2, 0.4)
      local pitchMod = math.max(-diff * 0.1, -0.2)

      starPounds.moduleFunc("sound", "play", "stretch", 0.8 + volumeMod, 1.2 + pitchMod)
    end
  end
  -- Squelch and belch. (Sounds like a band name)
  if diff > 0 then
    if foodConfig.triggersSquelch and not starPounds.hasOption("disableSquelchSounds") then
      starPounds.moduleFunc("sound", "play", "squelch", 0.75, 1.2)
    end
    -- Belch.
    if foodConfig.triggersBelch then
      self:startBelch()
    end
  end
  -- Manually eaten foods cause over-stuffing damage. (Player only)
  if foodConfig.stuffingDamage and starPounds.type == "player" and not starPounds.hasOption("disableStuffingDamage") then
    local damage = diff * foodConfig.stuffingDamage * self.data.stuffingDamage * starPounds.getStat("stuffingDamage")
    damage = math.min(math.floor(damage / self.data.stuffingDamageStep) * self.data.stuffingDamageStep, status.resource("health") - 1, status.resourceMax("health") * self.data.stuffingDamageCap) -- Round down.

    if damage > 0 then
      status.applySelfDamageRequest({
        damageType = "IgnoresDef",
        damage = damage,
        damageSourceKind = "starpoundsstuffing",
        sourceEntityId = entity.id()
      })
    end
  end
end

function stomach:set()
  self.stomach = nil
  starPounds.stomach = self:get()
end

function stomach:get()
  -- Return default if the mod is disabled.
  if not storage.starPounds.enabled then return self.defaultContents end
  -- Don't recalculate multiple times a tick.
  if self.stomach then return self.stomach end

  local baseCapacity = self.data.stomachCapacity
  -- Multiply based on size.
  if starPounds.currentSize then
    baseCapacity = baseCapacity * starPounds.currentSize.stomachMultiplier
  end

  local capacity = baseCapacity * starPounds.getStat("capacity")

  local totalAmount = 0
  local contents = 0
  local food = 0
  local belchable = 0

  for foodType, amount in pairs(storage.starPounds.stomach) do
    if starPounds.moduleFunc("food", "isFoodType", foodType) and (amount > 0) then
      local foodConfig = starPounds.moduleFunc("food", "foodType", foodType)
      totalAmount = totalAmount + amount
      contents = contents + amount * foodConfig.multipliers.capacity
      food = food + amount * foodConfig.multipliers.food
      if foodConfig.belchable then
        belchable = belchable + amount * foodConfig.multipliers.capacity
      end
    else
      storage.starPounds.stomach[foodType] = nil
    end
  end

  -- Add how heavy every entity in the stomach is to the counter.
  for _, v in pairs(storage.starPounds.stomachEntities) do
    local foodConfig = starPounds.moduleFunc("food", "foodType", v.foodType)
    contents = contents + (v.base * foodConfig.multipliers.capacity) + v.weight
    totalAmount = totalAmount + v.base + v.weight
  end

  self.stomach = {
    capacity = capacity,
    baseCapacity = baseCapacity,
    amount = math.round(totalAmount, 3),
    contents = math.round(contents, 3),
    food = math.round(food, 3),
    belchable = math.round(belchable, 3),

    fullness = math.round(contents/capacity, 2),
    baseFullness = math.round(contents/baseCapacity, 2),
    interpolatedFullness = math.round((self.stomachLerp or contents)/capacity, 2),
    interpolatedContents = math.round((self.stomachLerp or contents), 3)
  }

  return self.stomach
end

function stomach:getDefault()
  return self.defaultContents
end

function stomach:interpolateContents(dt)
  if storage.starPounds.enabled and (self.stomach.contents + self.stomachLerp) > 0 then
    if self.stomach.contents > self.stomachLerp and (self.stomach.contents - self.stomachLerp) > 1 then
      self.stomachLerp = math.round(util.lerp(5 * dt, self.stomachLerp, self.stomach.contents), 4)
    else
      self.stomachLerp = math.round(util.lerp(10 * dt, self.stomachLerp, self.stomach.contents), 4)
    end
    if math.abs(self.stomach.contents - self.stomachLerp) < 1 then
      self.stomachLerp = self.stomach.contents
    end
  else
    self.stomachLerp = 0
  end
end

function stomach:digest(dt, isGurgle, isBelch)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  dt = math.max(tonumber(dt) or 0, 0)
  if dt == 0 then return end
  -- A bit silly.
  isBelch = isGurgle and isBelch
  -- Rumbles. (Outside of the other block, because we still want them to happen without food if the rumble rate is above 0)
  if not starPounds.hasOption("disableRumbles") then
    if (self.stomach.contents + starPounds.getStat("baseRumbleRate")) > 0 then
      if self.rumbleTimer and self.rumbleTimer > 0 then
        -- If the gurgle rate is greater than the rumble rate (and we have food), use that.
        local gurgleRate = self.stomach.contents > 0 and starPounds.getStat("gurgleRate") or 0
        local rumbleRate = self.stomach.contents > 0 and starPounds.getStat("rumbleRate") or 0
        rumbleRate = math.max(starPounds.getStat("baseRumbleRate"), rumbleRate, gurgleRate)
        self.rumbleTimer = math.max(self.rumbleTimer - (dt * rumbleRate), 0)
      else
        if self.rumbleTimer then self:rumble() end
        self.rumbleTimer = math.round(util.randomInRange({self.data.minimumRumbleTime, (self.data.rumbleTime * 2) - self.data.minimumRumbleTime}))
      end
    end
  end

  -- Delayed belch.
  if self.belchTimer and self.belchTimer > 0 then
    self.belchTimer = math.max(self.belchTimer - dt, 0)
  elseif self.belchTimer == 0 then
    self:belch()
    self.belchTimer = nil
  end

  -- Don't do anything if stomach is empty.
  if self.stomach.amount == 0 then
    self.digestTimer = 0
    self.voreDigestTimer = 0
    self.gurgleTimer = nil
    if starPounds.getStat("baseRumbleRate") == 0 then self.rumbleTimer = nil end
    return
  end

  if not isGurgle then
    -- Vore stuff.
    if not starPounds.hasOption("disablePredDigestion") then
      -- Timer overrun incase function is called directly with multiple seconds.
      local diff = math.abs(math.min((self.voreDigestTimer or 0) - dt, 0))
      self.voreDigestTimer = math.max((self.voreDigestTimer or 0) - dt, 0)
      if self.voreDigestTimer == 0 then
        self.voreDigestTimer = self.data.voreDigestTimer
        starPounds.moduleFunc("pred", "digest", self.data.voreDigestTimer + diff)
      end
    end
    -- Gurgle stuff.
    if not starPounds.hasOption("disableGurgles") then
      if self.gurgleTimer and self.gurgleTimer > 0 then
        self.gurgleTimer = math.max(self.gurgleTimer - (dt * starPounds.getStat("gurgleRate")), 0)
      else
        -- gurgleTime (default 30) is the average, minimumGurgleTime (default 5) is the minimum, so (5 + (60 - 5))/2 = 30
        if self.gurgleTimer then self:gurgle() end
        self.gurgleTimer = math.round(util.randomInRange({self.data.minimumGurgleTime, (self.data.gurgleTime * 2) - self.data.minimumGurgleTime}))
      end
    end
  else
    if not starPounds.hasOption("disablePredDigestion") then
      -- 25% strength for vore digestion on gurgles.
      starPounds.moduleFunc("pred", "digest", dt * 0.25)
    end
  end

  -- Timer overrun incase function is called directly with multiple seconds.
  local diff = math.abs(math.min((self.digestTimer or 0) - dt, 0))
  self.digestTimer = math.max((self.digestTimer or 0) - dt, 0)
  if self.digestTimer == 0 then
    self.digestTimer = self.data.digestTimer
    local seconds = self.data.digestTimer + diff

    local absorption = starPounds.getStat("absorption")
    local foodValue = starPounds.getStat("foodValue")
    local healing = starPounds.getStat("healing")
    local digestionEnergy = starPounds.getStat("digestionEnergy")
    local breastEfficiency = starPounds.getStat("breastEfficiency")
    local belchAmount = starPounds.getStat("belchAmount")

    local maxHealth = status.resourceMax("health")
    local maxEnergy = status.isResource("energy") and status.resourceMax("energy") or 0
    local hasFood = status.isResource("food")
    local maxFood = hasFood and (status.resourceMax("food") - 0.01) or 0 -- Capped so the wellfed status doesn't apply automatically.
    local foodDelta = status.stat("foodDelta")

    local belchParticlesDisabled = starPounds.hasOption("disableBelchParticles")
    local hungerDisabled = starPounds.hasOption("disableHunger")

    local digestionStatCache = {}
    -- Iterate through food types
    for foodType, amount in pairs(storage.starPounds.stomach) do
      if starPounds.moduleFunc("food", "isFoodType", foodType) and (storage.starPounds.stomach[foodType] > 0) then
        local foodConfig = starPounds.moduleFunc("food", "foodType", foodType)
        local ratio = 1
        if self.stomach.contents > 0 and not foodConfig.ignoreCapacity then
          ratio = math.max(math.round((amount * foodConfig.multipliers.capacity) / self.stomach.contents, 2), 0.05)
        end
        -- Add up all the digestion stats.
        local digestionRate = foodConfig.baseDigestion
        for _, digestStat in ipairs(foodConfig.digestionStats) do
          -- Cache the stat for other food types
          if not digestionStatCache[digestStat[1]] then
            digestionStatCache[digestStat[1]] = starPounds.getStat(digestStat[1])
          end
          digestionRate = digestionRate + digestionStatCache[digestStat[1]] * digestStat[2]
        end
        -- Bonus digestion for belches.
        if isBelch and foodConfig.multipliers.belch > 0 then
          digestionRate = digestionRate + digestionRate * foodConfig.multipliers.belch * belchAmount
        end
        if isBelch and foodConfig.belchParticles and not belchParticlesDisabled then
          self:spawnBelchParticles(foodConfig.belchParticles, foodConfig.belchParticleCount)
        end
        local digestAmount = math.min(amount, math.round(digestionRate * ratio * seconds * (foodConfig.digestionRate + amount * foodConfig.percentDigestionRate), 4))
        self.digestionExperience = self.digestionExperience + digestAmount * foodConfig.multipliers.experience
        storage.starPounds.stomach[foodType] = math.round(math.max(amount - digestAmount, 0), 3)
        -- Add food.
        if hasFood and not hungerDisabled and (foodConfig.multipliers.food > 0) then
          local foodAmount = math.min(maxFood - status.resource("food"), digestAmount)
          -- Stops the player losing hunger while they digest food.
          local foodDeltaDiff = not isGurgle and math.abs(math.min(foodDelta * seconds, 0)) or 0
          local food = foodAmount * foodValue * foodConfig.multipliers.food + foodDeltaDiff
          status.giveResource("food", foodAmount * foodValue * foodConfig.multipliers.food + foodDeltaDiff)
        end

        if isGurgle and foodConfig.ignoreGurgles then digestAmount = 0 end

        local milkProduced, milkCost = starPounds.moduleFunc("breasts", "milkProduction", digestAmount * absorption * foodConfig.multipliers.food)
        starPounds.moduleFunc("breasts", "gainMilk", milkProduced)
        -- Gain weight based on amount digested, milk production, and digestion efficiency.
        starPounds.moduleFunc("size", "gainWeight", (digestAmount * (foodConfig.ignoreAbsorption and 1 or absorption) * foodConfig.multipliers.weight) - ((milkCost or 0)/math.max(1, breastEfficiency)))
        -- Don't heal if eaten.
        if not storage.starPounds.pred then
          -- Base amount 1 health (100 food would restore 100 health, modified by healing and absorption)
          if status.resourcePositive("health") then
            local healBaseAmount = digestAmount * foodConfig.multipliers.healing
            local healAmount = math.min(healBaseAmount * healing * self.data.healingRatio, maxHealth * self.data.healingCap * seconds)
            status.modifyResource("health", healAmount)
            -- Energy regenerates faster than health, and energy lock time gets reduced.
            if not starPounds.moduleFunc("strain", "straining") and not isGurgle and status.isResource("energy") and status.resourcePercentage("energy") < 1 and digestionEnergy > 0 then
              local energyAmount = math.min(healBaseAmount * digestionEnergy * self.data.energyRatio, maxEnergy * self.data.energyCap * seconds)
              if not status.resourcePositive("energyRegenBlock") and status.resourcePercentage("energy") < 1 then
                status.modifyResource("energy", energyAmount)
              end
              -- Energy regen block is capped at 2x the speed (decreases by the delta)
              status.modifyResource("energyRegenBlock", -math.min(digestAmount * absorption * digestionEnergy, seconds))
            end
          end
        end
      end
    end

    self.digestionExperience = self.digestionExperience or 0
    local gainedExperience = math.floor(self.digestionExperience)
    self.digestionExperience = self.digestionExperience - gainedExperience
    starPounds.moduleFunc("experience", "add", gainedExperience)
  end
end

function stomach:gurgle(noDigest)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if gurgles are disabled.
  if starPounds.hasOption("disableGurgles") and not noDigest then return end
  -- Instantly digest 1 - 3 seconds worth of food.
  local seconds = starPounds.getStat("gurgleAmount") * math.random(100, 300)/100
  if not noDigest then
    -- Chance to belch.
    local isBelch = starPounds.getStat("belchChance") > math.random() and self.stomach.belchable > 0
    if isBelch then self:belch("belchable") end
    self:digest(seconds, true, isBelch)
  end
  if not starPounds.hasOption("disableGurgleSounds") then
    starPounds.moduleFunc("sound", "play", "digest", 0.75, (2 - seconds/5) - storage.starPounds.weight/(starPounds.settings.maxWeight * 2))
  end
end

function stomach:rumble(volume)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  volume = tonumber(volume) or 1
  -- Don't do anything if rumbles are disabled.
  if starPounds.hasOption("disableRumbles") then return end
  -- Rumble sound.
  starPounds.moduleFunc("sound", "play", "rumble", util.clamp(volume, 0, 2) * 0.75, (math.random(90,110)/100))
end

-- Just runs the belch module function based on stomach contents.
function stomach:belch(stomachKey)
  self:stopBelch() -- Cancel queued belch.
  -- Every 100 pitches the sound down and volume up by 10%, max 25%.
  local belchMultiplier = math.min(self.stomach[self.stomach[stomachKey] and stomachKey or "contents"]/1000, 0.25)
  local belchVolume = 0.5 + belchMultiplier
  local belchPitch = 1 - belchMultiplier
  starPounds.moduleFunc("belch", "belch", belchVolume, belchPitch)
end

function stomach:startBelch(delay)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if disabled.
  if starPounds.hasOption("disableBelches") then return end
  -- Argument sanitisation.
  delay = math.max(tonumber(delay) or self.data.belchDelay, 0)
  self.belchTimer = delay
end

-- Cancels a belch.
function stomach:stopBelch()
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  self.belchTimer = nil
end

function stomach:sloshing(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Skip if nothing in stomach.
  if self.stomach.amount == 0 then return end
  -- Check for skill.
  if not starPounds.moduleFunc("skills", "has", "sloshing") then return end
  -- Only works with energy.
  if status.isResource("energy") and status.resourceLocked("energy") then return end
  self.sloshTimer = math.max(self.sloshTimer - dt, 0)
  self.sloshDeactivateTimer = math.max(self.sloshDeactivateTimer - dt, 0)
  if starPounds.mcontroller.crouching and not self.wasCrouching and self.sloshTimer < (self.data.sloshTimer - self.data.minimumSloshTimer) then
    local activationMultiplier = self.sloshActivations/self.data.sloshActivationCount
    local sloshEffectiveness = (1 - (self.sloshTimer/self.data.sloshTimer)) * activationMultiplier
    -- Sloshy sound, with volume increasing until activated.
    local soundMultiplier = 0.65 * (0.5 + 0.5 * math.min(self.stomach.contents/self.data.stomachCapacity, 1)) * activationMultiplier
    local pitchMultiplier = 1.25 - storage.starPounds.weight/(starPounds.settings.maxWeight * 2)
    starPounds.moduleFunc("sound", "play", "slosh", soundMultiplier, pitchMultiplier)
    if activationMultiplier > 0 then
      self:digest(self.data.sloshDigestion * sloshEffectiveness, true)
      local energyMultiplier = sloshEffectiveness * starPounds.getStat("sloshingEnergy")
      status.modifyResource("energyRegenBlock", status.stat("energyRegenBlockTime") * self.data.sloshEnergyLock * sloshEffectiveness)
      status.modifyResource("energy", -self.data.sloshEnergy * energyMultiplier)
      if self.gurgleTimer then
        self.gurgleTimer = math.max(self.gurgleTimer - (self.data.sloshPercent * self.data.gurgleTime), 0)
      end
      if self.rumbleTimer then
        self.rumbleTimer = math.max(self.rumbleTimer - (self.data.sloshPercent * self.data.rumbleTime), 0)
      end
      starPounds.events:fire("stomach:slosh", sloshEffectiveness)
    end
    self.sloshActivations = math.min(self.sloshActivations + 1, self.data.sloshActivationCount)
    self.sloshTimer = self.data.sloshTimer
    self.sloshDeactivateTimer = self.data.sloshDeactivateTimer
  end
  if self.sloshDeactivateTimer == 0 or (starPounds.mcontroller.walking or starPounds.mcontroller.running) then
    self.sloshActivations = 0
  end
  self.wasCrouching = starPounds.mcontroller.crouching
end

function stomach:squelching(dt)
  local hasPrey = storage.starPounds.enabled and (#storage.starPounds.stomachEntities > 0) and not starPounds.hasOption("disableSquelchSounds")
  -- Activate squelch loop.
  if hasPrey then
    starPounds.moduleFunc("sound", "setVolume", "squelchloop", self.squelchVolume)
    if not self.preySquelching then
      starPounds.moduleFunc("sound", "play", "squelchloop", 0, 1, -1) -- Zero volume if it's activating, ramps up slowly.
      self.preySquelching = true
      self.squelchDeactivateTimer = self.data.squelchRampTime
    end
  end
  -- Deactivate squelch loop.
  if not hasPrey and self.preySquelching then
    -- Fade out the sound initially.
    if self.squelchDeactivateTimer == self.data.squelchRampTime then
      starPounds.moduleFunc("sound", "setVolume", "squelchloop", 0, self.data.squelchRampTime)
    end
    -- Wait for the fade out to finish, and then deactivate the sound so it's not abrupt.
    self.squelchDeactivateTimer = math.max(self.squelchDeactivateTimer - dt, 0)
    if self.squelchDeactivateTimer == 0 then
      starPounds.moduleFunc("sound", "stop", "squelchloop")
      self.preySquelching = false
    end
  end

  if storage.starPounds.enabled then
    local fullness = math.max(self.stomach.baseFullness, self.stomach.fullness)
    local volume = math.max(self.data.squelchMinimumVolume, math.min(fullness / self.data.squelchMaxVolumeCapacity, 1))
    self.squelchVolume = math.round(volume * self.data.squelchVolume, 2)
  else
    self.squelchVolume = 0
  end
end

function stomach:squelch(volume, pitch)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  if not starPounds.hasOption("disableSquelchSounds") then
    volume = math.min(tonumber(volume) or 1, 1)
    pitch = math.min(tonumber(pitch) or 1, 1)
    starPounds.moduleFunc("sound", "play", "squelch", self.squelchVolume * volume, pitch)
  end
end

function stomach:squelchEvents()
  local struggleSquelch = function(volume, pitch)
    volume = (tonumber(volume) or 1) * self.data.squelchStruggleVolume
    if not starPounds.hasOption("disableStruggleSounds") then
      self:squelch(volume, pitch)
    end
  end

  local sloshSquelch = function(volume, pitch)
    volume = (tonumber(volume) or 1) * self.data.squelchSloshVolume
    if not starPounds.hasOption("disableMovementSounds") then
      self:squelch(volume, pitch)
    end
  end

  local landingSquelch = function(volume, pitch)
    volume = (tonumber(volume) or 1) * self.data.squelchLandingVolume
    if not starPounds.hasOption("disableMovementSounds") then
      self:squelch(volume, pitch)
    end
  end

  starPounds.events:on("pred:struggle", struggleSquelch)
  starPounds.events:on("stomach:slosh", sloshSquelch)
  starPounds.events:on("player:landing", landingSquelch)

  function self:uninit()
    starPounds.events:off("pred:struggle", struggleSquelch)
    starPounds.events:off("stomach:slosh", sloshSquelch)
    starPounds.events:off("player:landing", landingSquelch)
  end
end

function stomach:stepTimer(timer, dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  dt = math.max(tonumber(dt) or 0, 0)
  if dt == 0 then return end
  -- Rumble increment.
  if timer == "rumble" and self.rumbleTimer then
    self.rumbleTimer = math.max(self.rumbleTimer - dt, 0)
  end
  -- Gurgle increment.
  if timer == "gurgle" and self.gurgleTimer then
    self.gurgleTimer = math.max(self.gurgleTimer - dt, 0)
  end
end

function stomach:spawnBelchParticles(particles, count)
  local actions = {}
  for _, particle in pairs(particles) do
    actions[#actions + 1] = {action = "particle", specification = starPounds.moduleFunc("belch", "particle", particle)}
  end
  starPounds.spawnMouthProjectile(actions, count)
end

function stomach.reset()
  storage.starPounds.stomach = {}
  storage.starPounds.stomachEntities = jarray()
  return true
end

starPounds.modules.stomach = stomach
