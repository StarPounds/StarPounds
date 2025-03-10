local drinking = starPounds.module:new("drinking")

function drinking:init()
  self.drinkTimer = 0
  self.drinkCounter = 0
  self.splashConfig = root.assetJson("/player.config:splashConfig")

  message.setHandler("starPounds.spawnDrinkingParticles", function(_, _, ...) return self:spawnParticles(...) end)
end

function drinking:update(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if drinking is disabled.
  if starPounds.hasOption("disableDrinking") then return end
  -- Don't drink inside distortion spheres.
  if status.stat("activeMovementAbilities") > 1 then return end
  -- Can only drink if you're below capacity.
  if starPounds.stomach.fullness >= 1 and not starPounds.hasSkill("wellfedProtection") then
    self.drinkCounter = 0
    return
  elseif starPounds.stomach.fullness >= starPounds.settings.thresholds.strain.starpoundsstomach3 then
    self.drinkCounter = 0
    return
  end
  local mouthPosition = starPounds.mcontroller.mouthPosition
  local mouthLiquid = world.liquidAt(mouthPosition) or world.liquidAt(vec2.add(mouthPosition, {0, 0.25}))
  -- Space out 'drinks', otherwise they'll happen every script update.
  self.drinkTimer = math.max(self.drinkTimer - dt, 0)
  -- Check if drinking isn't on cooldown.
  if not (self.drinkTimer == 0) then return end
  -- Check if there is liquid in front of the entities's mouth, and if it is drinkable.
  if mouthLiquid and ((starPounds.moduleFunc("liquid", "getFood", root.liquidName(mouthLiquid[1])) > 0) or starPounds.hasOption("universalDrinking")) then
    -- Remove liquid at the entities's mouth, and store how much liquid was removed.
    local consumedLiquid = world.destroyLiquid(mouthPosition) or world.destroyLiquid(vec2.add(mouthPosition, {0, 0.25}))
    if consumedLiquid and consumedLiquid[1] and consumedLiquid[2] then
      -- Increment counter up to 1 (10 times).
      self.drinkCounter = math.min(self.drinkCounter + 0.1, 1)
      -- Reset the drink cooldown, shorter based on how high drinkCounter is.
      self.drinkTimer = 1/(1 + self.drinkCounter)
      -- Add to entities's stomach based on liquid consumed.
      for foodType, foodAmount in pairs(starPounds.moduleFunc("liquid", "get", root.liquidName(consumedLiquid[1]))) do
        starPounds.feed(foodAmount * consumedLiquid[2], foodType)
      end
      -- Spawn drink particles.
      self:spawnParticles(consumedLiquid)
      -- Play drinking sound. Volume increased by amount of liquid consumed.
      starPounds.moduleFunc("sound", "play", "drink", 0.5 + 0.5 * consumedLiquid[2], math.random(8, 12)/10)
      status.addEphemeralEffect("starpoundsdrinking")
    end
  else
    -- Reset the drink counter if there is nothing to drink.
    if self.drinkCounter >= 1 then
      -- Gets up to 25% deeper depending on how many 'sips' over 10 were taken.
      local belchMultiplier = 1 - (self.drinkCounter - 1) * 0.25
      starPounds.belch(0.75, starPounds.belchPitch(belchMultiplier))
    end
    self.drinkCounter = 0
  end
end

function drinking:spawnParticles(consumedLiquid)
  local liquidConfig = root.liquidConfig(consumedLiquid[1])
  if not liquidConfig.config.color then return end

  local velocity = vec2.mul(self.splashConfig.splashParticleVariance.velocity, 0.1)
  local variance = sb.jsonMerge(self.splashConfig.splashParticleVariance, {
    velocity = velocity
  })

  local particle = sb.jsonMerge(self.splashConfig.splashParticle, {
    position = {0, 0},
    initialVelocity = vec2.add(vec2.mul(velocity, starPounds.mcontroller.facingDirection), {0, 3}),
    color = liquidConfig.config.color,
    variance = variance
  })
  starPounds.spawnMouthProjectile({{action = "particle", specification = particle}}, self.splashConfig.numSplashParticles / 2)
end
-- Add the module.
starPounds.modules.drinking = drinking
