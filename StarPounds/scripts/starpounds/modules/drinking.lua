local drinking = starPounds.module:new("drinking")

function drinking:init()
  message.setHandler("starPounds.spawnDrinkingParticles", function(_, _, ...) return self:spawnParticles(...) end)

  self.drinkTimer = 0
  self.drinkCounter = 0
  self.splashConfig = root.assetJson("/player.config:splashConfig")
  self.liquidCache = {}
end

function drinking:update(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Space out 'drinks', otherwise they'll happen every script update.
  self.drinkTimer = math.max(self.drinkTimer - dt, 0)
  -- Don't do anything if drinking is disabled.
  if starPounds.hasOption("disableDrinking") then return end
  -- Drink.
  self:drink()
end

function drinking:drink()
  -- Don't drink inside distortion spheres.
  if status.stat("activeMovementAbilities") > 1 then return end
  -- Don't bother if there's no liquid around us.
  if not (starPounds.mcontroller.liquidPercentage > 0) then return end
  -- Can only drink if you're below capacity.
  if not starPounds.moduleFunc("stomach", "canEat") then
    self.drinkCounter = 0
    return
  end
  -- Check if drinking isn't on cooldown.
  if not (self.drinkTimer == 0) then return end

  local liquidPositon = self:getValidLiquidPosition()
  local liquidAmount = self:consumeLiquidsAtPosition(liquidPositon)

  if liquidAmount > 0 then
    -- Increment counter up to 1 (10 times).
    self.drinkCounter = math.min(self.drinkCounter + 0.1, 1)
    -- Reset the drink cooldown.
    self.drinkTimer = 0.75
    -- Play drinking sound. Volume increased by amount of liquid consumed.
    starPounds.moduleFunc("sound", "play", "drink", math.min(0.5 + 0.5 * liquidAmount, 1), math.random(7, 11)/10)
    status.addEphemeralEffect("starpoundsdrinking")
  else
    -- Reset the drink counter if there is nothing to drink.
    if self.drinkCounter >= 1 then
      -- Gets up to 25% deeper depending on how many 'sips' over 10 were taken.
      local belchVolume = 0.75
      local belchPitch = 1 - (self.drinkCounter - 1) * 0.25
      starPounds.moduleFunc("belch", "belch", belchVolume, belchPitch)
    end
    self.drinkCounter = 0
  end
end

function drinking:getValidLiquidPosition()
  -- Check offset in case it's slightly lower.
  for _, pos in ipairs(self.data.checkPositions) do
    local checkPosition = vec2.add(starPounds.mcontroller.mouthPosition, pos)
    if world.isTileProtected(checkPosition) then return end
    local checkLiquid = world.liquidAt(checkPosition)
    if checkLiquid and self:canDrinkLiquid(checkLiquid[1]) then
      return checkPosition
    end
  end
end

function drinking:consumeLiquidsAtPosition(position)
  if not position then return 0 end

  local drinkConfig = self.data.levels[math.min(starPounds.getStat("drinkStrength"), #self.data.levels)]
  local query = world.entityQuery(starPounds.mcontroller.mouthPosition, drinkConfig[1], {includedTypes = {"player", "npc", "monster"}, withoutEntityId = entity.id()})
  local consumedLiquids = {}
  for _, pos in pairs(drinkConfig[3]) do
    local drinkPosition = vec2.add(pos, position)
    local collision = world.lineTileCollision(position, drinkPosition)
    if not collision then
      local liquid = world.liquidAt(drinkPosition)
      if liquid and self:canDrinkLiquid(liquid[1]) then
        -- Remove liquid at the entities's mouth, and store how much liquid was removed. Don't bother destroying the liquid if it's an ocean.
        local consumedLiquid = self:isOcean(drinkPosition) and liquid or world.destroyLiquid(drinkPosition)
        if consumedLiquid and consumedLiquid[1] and consumedLiquid[2] then
          local liquidName = root.liquidName(consumedLiquid[1])
          for foodType, foodAmount in pairs(starPounds.moduleFunc("liquid", "get", liquidName).food) do
            starPounds.moduleFunc("stomach", "feed", foodAmount * consumedLiquid[2], foodType)
          end
          -- Store amounts for particle spawning/sound.
          consumedLiquids[liquidName] = math.min((consumedLiquids[liquidName] or 0) + consumedLiquid[2])
        end
      end
    end
  end
  -- Entities can get shlorped up if they're too close.
  if not starPounds.hasOption("disableDrinkingVore") then
    -- 'Nudge' edible entities nearby.
    for _, entityId in pairs(query) do
      local direction = world.distance(starPounds.mcontroller.mouthPosition, world.entityPosition(entityId)) -- Vector towards player
      local distance = math.max(vec2.mag(direction), 1) -- Compute magnitude
      if distance < drinkConfig[1] then
        local incidence = math.min(1 - (distance - 1) / (drinkConfig[1] - 1), distance / 1)
        local angle = vec2.angle(direction)

        world.sendEntityMessage(entityId, "starPounds.prey.drinkVoreNudge", entity.id(), drinkConfig[2], {angle, 10, 750 * incidence, true})
      end
    end
    -- Spawn vore projectile at the player's mouth.
    -- Better than triggering vore multiple times for each entity while they're moving towards us.
    if #query > 0 then
      world.spawnProjectile("starpoundsdrinkvore", starPounds.mcontroller.mouthPosition, entity.id(), nil, true, {
        statusEffects = {{effect = "starpoundsvoretargetdrink", duration = drinkConfig[2]}}
      })
    end
  end

  local totalAmount = 0
  for liquid, amount in pairs(consumedLiquids) do
    totalAmount = totalAmount + amount
    self:spawnParticles(liquid)
  end

  return totalAmount
end

function drinking:canDrinkLiquid(liquidType)
  if starPounds.hasOption("universalDrinking") then return true end
  if type(liquidType) == "number" then liquidType = root.liquidName(liquidType) end
  -- We store false values too.
  if self.liquidCache[liquidType] == nil then
    self.liquidCache[liquidType] = starPounds.moduleFunc("liquid", "edible", liquidType)
  end

  return self.liquidCache[liquidType]
end

function drinking:spawnParticles(liquidType)
  local liquidConfig = root.liquidConfig(liquidType)
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

function drinking:isOcean(position)
  return (world.oceanLevel(position) > position[2]) and not world.material(position, "background")
end
-- Add the module.
starPounds.modules.drinking = drinking
