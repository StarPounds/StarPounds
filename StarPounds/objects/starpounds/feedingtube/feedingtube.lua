require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"

function init()
  self.collectTimer = 0
  self.liquidAmount = 1
  self.capacity = config.getParameter("capacity", 1000)
  self.liquids = root.assetJson("/scripts/starpounds/modules/liquid.config:liquids")
  self.pickupBounds = rect.pad(object.boundBox(), -1)

  self.feedAmount = 0 -- Tracker for when to apply the diluted effect.

  self.statusBlacklist = {
    "wet", "swimming", "slimeslow", "tarslow",
    "starpoundschocolateslow", "starpoundshoneyslow", "caloriumliquid"
  }

  local liquidName, liquidAmount = table.unpack(config.getParameter("defaultLiquid", jarray()))
  if liquidName then
    defaultLiquid = {
      name = liquidName,
      statusEffects = root.liquidConfig(liquidName).config.statusEffects or jarray(),
      item = root.liquidConfig(liquidName).config.itemDrop
    }
  end

  object.setConfigParameter("defaultLiquid", nil)

  storage = sb.jsonMerge({
    liquid = defaultLiquid,
    amount = liquidAmount or 0,
  }, storage)

  if storage.liquid then
    setLiquidType(storage.liquid.name)
  end

  self.liquidLevel = storage.amount
  animator.setGlobalTag("liquidLevel", math.max(0, math.min(math.ceil(self.liquidLevel * 39/self.capacity), 39)))
end


function update(dt)
  promises:update()
  -- Player/NPC detection. Resets the target if nobody lounging.
  if self.feedTarget and not self.startedLounging then
    if not world.loungeableOccupied(entity.id()) then
      self.feedTarget = nil
      self.feedAmount = 0
    end
  else
    self.startedLounging = false
  end
  -- Main loop.
  if self.feedTarget then
    object.setInteractive(false)
    if canFeed() then
      if animator.animationState("feedState") == "default" then
        -- Remove stored liquid.
        local amount = math.min(storage.amount, self.liquidAmount)
        storage.amount = math.max(0, storage.amount - amount)
        -- Give food.
        for foodType, foodAmount in pairs((self.liquids[storage.liquid.name] or self.liquids.default).food) do
          world.sendEntityMessage(self.feedTarget, "starPounds.stomach.feed", foodAmount * amount, foodType)
        end
        -- Give status effects.
        for _, statusEffect in pairs(storage.liquid.statusEffects) do
          if not contains(self.statusBlacklist, statusEffect) then
            world.sendEntityMessage(self.feedTarget, "applyStatusEffect", statusEffect)
          end
        end
        -- Prevent belches, and spawn drinking particles.
        world.sendEntityMessage(self.feedTarget, "starPounds.drinking.spawnParticles", storage.liquid.name)
        world.sendEntityMessage(self.feedTarget, "applyStatusEffect", "starpoundsdrinking")
        -- Swallow sound.
        world.sendEntityMessage(self.feedTarget, "starPounds.sound.play", "swallow", math.min(0.3 + 0.06 * amount, 0.6)) -- 30% -> 60% volume.
        -- Play sound. Pitch decreases by 7.5% per liquid amount, volume increases by 7.5%.
        animator.setSoundVolume("drink", math.min(1 + 0.075 * (amount - 1), 1.3)) -- 100% -> 130% volume.
        animator.setSoundPitch("drink", math.max(1 - 0.075 * (amount - 1), 0.7)) -- 100% -> 70% pitch.
        animator.playSound("drink")
        -- Connected to mouth, animated.
        animator.setAnimationState("feedState", "feeding")
        -- Set the amount/speed again in case the skill changes.
        setDrinkSpeed()

        self.feedAmount = self.feedAmount + amount
        if self.feedAmount >= 10 then
          world.sendEntityMessage(self.feedTarget, "starPounds.effects.add", "feedingTube", 10)
          self.feedAmount = self.feedAmount - 10
        end
      end
    else
      -- Connected to mouth, static.
      animator.setAnimationState("feedState", "default")
    end
  else
    object.setInteractive(true)
    -- Disconnected.
    animator.setAnimationState("feedState", "idle")
  end
  -- Reset the liquid if we're empty.
  if storage.amount <= 0 then
    setLiquidType()
  end
  -- Set the displayed liquid amount.
  self.liquidLevel = math.round(util.lerp(dt * 2, self.liquidLevel, storage.amount), 4)
  animator.setGlobalTag("liquidLevel", math.max(0, math.min(math.ceil(self.liquidLevel * 39/self.capacity), 39)))
  -- Grab nearby liquid items.
  self.collectTimer = math.max(self.collectTimer - dt, 0)
  if self.collectTimer == 0 then
    collectLiquid()
    self.collectTimer = 1
  end
end

function canFeed()
  return storage.amount > 0
end

function onInteraction(args)
  if not self.feedTarget then
    self.feedTarget = args.sourceId
    self.feedAmount = 0
    self.startedLounging = true
    animator.setAnimationRate(1)
    setDrinkSpeed()
    -- Connect.
    animator.setAnimationState("feedState", canFeed() and "feeding" or "default")
  end
end

function npcToy.isOccupied()
  return (npcToy.getMaxNpcs() ~= nil and npcToy.npcCount >= npcToy.getMaxNpcs()) or self.feedTarget
end

function npcToy.isAvailable()
  return canFeed() and not npcToy.isOccupied()
end

function die()
  if storage.liquid then
    world.spawnItem(storage.liquid.item, entity.position(), storage.amount)
  end
end

function collectLiquid()
  if storage.amount < self.capacity then
    local items = world.itemDropQuery(rect.ll(self.pickupBounds), rect.ur(self.pickupBounds))
    for _, itemId in pairs(items) do
      local item = world.itemDropItem(itemId)
      if root.itemType(item.name) == "liquid" then
        local liquidName = root.itemConfig(item.name).config.liquid
        if not storage.liquid or liquidName == storage.liquid.name then
          local itemDrop = world.takeItemDrop(itemId, entity.id())
          if itemDrop then
            storage.liquid = {
              name = liquidName,
              statusEffects = root.liquidConfig(liquidName).config.statusEffects or jarray(),
              item = item.name
            }
            storage.amount = storage.amount + itemDrop.count
            setLiquidType(liquidName)
            if storage.amount > self.capacity then
              local excess = storage.amount - self.capacity
              world.spawnItem(storage.liquid.item, entity.position(), excess)
              storage.amount = self.capacity
            end
          end
        end
      end
    end
  end
end

function setDrinkSpeed()
  self.liquidAmount = 1
  if self.feedTarget then
    promises:add(world.sendEntityMessage(self.feedTarget, "starPounds.stats.get", "drinkStrength"), function(level)
      self.liquidAmount = math.max(level, 1)
      animator.setAnimationRate(1 + (level - 1) * 0.125)
    end)
  end
end

function setLiquidType(liquidName)
  if liquidName then
    local liquidConfig = root.liquidConfig(liquidName).config
    local rgb = liquidConfig.color
    animator.setGlobalTag("liquidImage", string.format("%s?multiply=%s", liquidConfig.texture, string.format("%02X%02X%02X%02X", rgb[1], rgb[2], rgb[3], rgb[4])))
    object.setLightColor(liquidConfig.radiantLight or {0, 0, 0})
  else
    storage.liquid = nil
    animator.setGlobalTag("liquidImage", "")
    object.setLightColor({0, 0, 0})
  end
end

function math.round(num, numDecimalPlaces)
  local format = string.format("%%.%df", numDecimalPlaces or 0)
  return tonumber(string.format(format, num))
end
