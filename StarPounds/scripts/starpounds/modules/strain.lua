local strain = starPounds.module:new("strain")

function strain:init()
  self.energyRegenBlockDelta = root.assetJson("/player.config:statusControllerSettings.resources.energyRegenBlock.deltaValue")
  self.effort = 0
  -- The funny strain tracking value.
  self.strain = 0
  self.strainCooldown = 0
  self.penalty = 0

  status.clearPersistentEffects("starpoundsstrained")
end

function strain:update(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  self.effort = starPounds.moduleFunc("movement", "getEffort")
  -- Store so we only calculate once.
  local strained = self:strained()
  local straining = self:straining()
  -- Cooldown before strain begins decreasing.
  self.strainCooldown = math.max(self.strainCooldown - dt, 0)
  -- Instantly reset cooldown when no longer strained.
  if not strained then self.strainCooldown = 0 end
  -- Strain reduction.
  if not straining and self.strain > 0 and self.strainCooldown == 0 then
    local strainReduction = self.data.decreaseAmount
    -- Bigger bonus if we're not strained.
    if not strained then strainReduction = self.data.largeDecreaseAmount end
    -- Rapidly reduce strain.
    self.strain = math.max(self.strain - (strainReduction * dt), 0)
  end
  -- Apply tracking effect.
  if strained and not starPounds.moduleFunc("oSB", "hasOpenStarbound") and not starPounds.hasOption("disableStrainedMeter") and not status.uniqueStatusEffectActive("starpoundsstrained") then
    status.addEphemeralEffect("starpoundsstrained")
  end
  -- Move speed stuffs.
  local penalty = math.round(self.data.energyPenalty * self.strain * starPounds.getStat("strainedPenalty"), 2)
  if self.strain > self.data.minimumAmount then
    -- Energy.
    if penalty ~= self.penalty then
      status.setPersistentEffects("starpoundsstrained", {
        {stat = "energyRegenPercentageRate", effectiveMultiplier = 1 - penalty}
      })
      self.penalty = penalty
    end
    -- Movement.
    local modifier = 1 - penalty
    mcontroller.controlModifiers({
      airJumpModifier = modifier,
      speedModifier = modifier,
      groundMovementModifier = modifier,
      liquidMovementModifier = modifier,
      speedModifier = modifier,
      airJumpModifier = modifier,
      liquidJumpModifier = modifier
    })
  elseif penalty ~= self.penalty then
    status.clearPersistentEffects("starpoundsstrained")
    self.penalty = penalty
  end
  -- Skip the rest if we're not moving.
  if self.effort == 0 then return end
  -- Skip the rest if we're in a sphere.
  if status.stat("activeMovementAbilities") > 1 then return end

  if strained then
    local energyPercent = status.resourcePercentage("energy")
    local energyLocked = status.resourceLocked("energy")
    -- Consume and lock energy when running.
    if straining then
      local min = self.data.scalingRange[1]
      local max = self.data.scalingRange[2]
      local strainFactor = util.clamp((starPounds.stomach.interpolatedFullness - min) / (max - min), self.data.minimumScalingFactor, 1) * self.data.scalingFactor
      self.strain = math.min(self.strain + (self.data.increaseAmount * self.effort * dt * strainFactor), 1)
      self.strainCooldown = self.data.decreaseDelay
      -- Stomach makes more rumble sounds while straining.
      starPounds.moduleFunc("stomach", "stepTimer", "rumble", self.data.rumbleBonus * strainFactor * dt)
      -- Sweat when strain is high.
      if self.strain >= self.data.sweatAmount then
        status.addEphemeralEffect("sweat")
      end
    end
  end
end

function strain:uninit()
  status.clearPersistentEffects("starpoundsstrained")
end

function strain:get()
  return self.strain
end

function strain:strained()
  return starPounds.stomach.interpolatedFullness > self.data.scalingRange[1]
end

function strain:straining()
  return self:strained() and (self.effort >= self.data.effortThreshold)
end

starPounds.modules.strain = strain
