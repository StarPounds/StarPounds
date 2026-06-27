local size = starPounds.module:new("size")

function size:init()
  message.setHandler("starPounds.size.gainWeight", function(_, _, ...) return self:gainWeight(...) end)
  message.setHandler("starPounds.size.loseWeight", function(_, _, ...) return self:loseWeight(...) end)
  message.setHandler("starPounds.size.setWeight", function(_, _, ...) return self:setWeight(...) end)
  message.setHandler("starPounds.size.setSize", function(_, _, ...) return self:setSize(...) end)
  message.setHandler("starPounds.size.offsetSize", function(_, _, ...) return self:offsetSize(...) end)
  message.setHandler("starPounds.size.get", function(_, _, ...) return self:get(...) end)
  message.setHandler("starPounds.size.sizes", function(_, _, ...) return self:sizes(...) end)
  message.setHandler("starPounds.size.config", function(_, _, ...) return self:config(...) end)
  message.setHandler("starPounds.size.maximumWeight", function(_, _, ...) return self:maximumWeight(...) end)
  message.setHandler("starPounds.size.reset", localHandler(self.reset))

  -- Kinda gross, but deal with it.
  local speciesData = {}
  if starPounds.type == "player" then
    self.setEquippedItem = player.setEquippedItem
    self.equippedItem = player.equippedItem
    self.giveItem = player.giveItem
    speciesData = starPounds.getSpeciesData(player.species())
  elseif starPounds.type == "npc" then
    self.setEquippedItem = npc.setItemSlot
    self.equippedItem = npc.getItemSlot
    self.giveItem = function() end
    speciesData = starPounds.getSpeciesData(npc.species())
  end

  self.canGain = speciesData.weightGain
  self.sizeConfig = root.assetJson(speciesData.sizes)

  -- Pre-fetch and cache the supersize index.
  self.supersizeIndex = math.huge
  for i, size in ipairs(self.sizeConfig.sizes) do
    if size.yOffset then
      self.supersizeIndex = math.min(self.supersizeIndex, i)
    end
  end

  -- Shared hitbox cache for NPCs.
  local shared = getmetatable ""
  shared.starPounds = shared.starPounds or {}
  shared.starPounds.sizeCache = shared.starPounds.sizeCache or {}
  shared.starPounds.sizeCache.hitboxes = shared.starPounds.sizeCache.hitboxes or {}

  local visualSpecies = starPounds.getVisualSpecies()
  -- Create/grab hitboxes for this species.
  if not shared.starPounds.sizeCache.hitboxes[visualSpecies] then
    shared.starPounds.sizeCache.hitboxes[visualSpecies] = {}
    for i, size in ipairs(self.sizeConfig.sizes) do
      shared.starPounds.sizeCache.hitboxes[visualSpecies][i] = size.controlParameters[visualSpecies] or size.controlParameters.default or {}
    end
  end

  self.cachedHitboxes = shared.starPounds.sizeCache.hitboxes[visualSpecies]

  -- Scaled slots.
  -- Sucks this has to be an array but the oSB slots need to load first to cap the vanilla slot variant.
  self.slots = {}
  -- oSB check and slots.
  if root.assetData then
    for slot, itemType in pairs(self.data.oSBSlots) do
      self.slots[#self.slots + 1] = {slot, {itemType = itemType}}
    end
  end
  -- Default slots.
  self.slots[#self.slots + 1] = {"chestCosmetic", {itemType = "chest", default = true}}
  self.slots[#self.slots + 1] = {"legsCosmetic", {itemType = "legs", default = true}}
  self.equipConfigCache = {
    chest = "", chestVariant = "", chestIndex = 1,
    legs = "", legsIndex = 1
  }
  -- Need this ready for other modules.
  starPounds.currentSize, starPounds.currentSizeIndex = self:get(0)
  starPounds.weightMultiplier = 1
  -- Just in case the data is out of range.
  self:setWeight(storage.starPounds.weight)
  self:updateStats(true)
end

function size:update(dt)
  starPounds.currentSize, starPounds.currentSizeIndex = self:get(storage.starPounds.weight)
  starPounds.currentVariant = self:getVariant()
  starPounds.weight = storage.starPounds.weight
  starPounds.weightMultiplier = self:weightMultiplier()
  -- Only run progress math if the weight actually changed.
  if starPounds.weight ~= self.oldWeight then
    starPounds.progress = self:progress()
    self.oldWeight = starPounds.weight
  end

  local sizeChange = false
  local weightChange = false
  if starPounds.currentSizeIndex ~= self.oldSizeIndex then
    sizeChange = true
    -- Don't play the sound on the first load.
    if self.oldSizeIndex then
      -- Play sound to indicate size change.
      starPounds.moduleFunc("sound", "play", "digest", 0.75, math.random(10,15) * 0.1 - storage.starPounds.weight/(self.sizeConfig.maxWeight * 2))
    end
    -- Adjust position to center if going to/from a supersize.
    if not starPounds.mcontroller.zeroG and self.oldSizeIndex then
      local oldOffset = self.sizeConfig.sizes[(self.oldSizeIndex or 1)].yOffset or 0
      local offset = (starPounds.currentSize.yOffset or 0) - oldOffset
      if offset ~= 0 then
        mcontroller.translate({0, -offset})
      end
    end
    -- Update status effect tracker.
    starPounds.moduleFunc("trackers", "clearStatuses")
    starPounds.moduleFunc("trackers", "createStatuses")
  elseif starPounds.weightMultiplier ~= self.oldWeightMultiplier then
    weightChange = true
  end

  self:cursorCheck()
  self:trackVehicleCap()
  self:equip(self:equipmentConfig(starPounds.currentSizeIndex))
  self:updateStats()

  -- Fire events. (Size gets priority for stat event)
  if sizeChange then
    -- Force stat update.
    starPounds.events:fire("stats:calculate", "size:changed")
    starPounds.events:fire("size:changed", starPounds.currentSizeIndex - (self.oldSizeIndex or 0))
  elseif weightChange then
    -- Force stat update.
    starPounds.events:fire("stats:calculate", "size:weightMultChanged")
  end

  self.oldSizeIndex = starPounds.currentSizeIndex
  self.oldWeightMultiplier = starPounds.weightMultiplier
end

function size:isActive()
  return storage.starPounds.enabled and self.canGain
end

function size:gainWeight(amount, fullAmount)
  -- Don't do anything if the mod is disabled.
  if not self:isActive() then return 0 end
  -- Don't do anything if weight gain is disabled.
  if starPounds.hasOption("disableGain") then return 0 end
  -- Argument sanitisation.
  amount = tonumber(amount) or 0
  amount = util.clamp(amount * (fullAmount and 1 or starPounds.getStat("weightGain")), 0, self.sizeConfig.maxWeight - storage.starPounds.weight)
  self:setWeight(storage.starPounds.weight + amount)
  return amount
end

function size:loseWeight(amount, fullAmount)
  -- Don't do anything if the mod is disabled.
  if not self:isActive() then return 0 end
  -- Don't do anything if weight loss is disabled.
  if starPounds.hasOption("disableLoss") then return 0 end
  -- Argument sanitisation.
  amount = tonumber(amount) or 0
  amount = util.clamp(amount * (fullAmount and 1 or starPounds.getStat("weightLoss")), 0, storage.starPounds.weight - self:minimumWeight())
  self:setWeight(storage.starPounds.weight - amount)
  return amount
end

function size:setWeight(amount)
  -- Don't do anything if the mod is disabled.
  if not self:isActive() then return end
  -- Argument sanitisation.
  amount = math.round(tonumber(amount) or 0, 4)
  storage.starPounds.weight = util.clamp(amount, self:minimumWeight(), self.sizeConfig.maxWeight)
end

function size:offsetSize(offset)
  -- Don't do anything if the mod is disabled.
  if not self:isActive() then return end
  -- Argument sanitisation.
  offset = math.round(tonumber(offset) or 0)
  self:setSize(self:sizeIndex() + offset, self:progress())
end

function size:setSize(index, progress)
  -- Don't do anything if the mod is disabled.
  if not self:isActive() then return 0 end
  -- Argument sanitisation.
  index = math.floor(tonumber(index) or 1)
  progress = util.clamp(tonumber(progress) or 0, 0, 1)
  -- Just fill/reset the progress if we go past index values.
  if index > #self.sizeConfig.sizes then
    index = #self.sizeConfig.sizes
    progress = 1
  elseif index < 1 then
    index = 1
    progress = 0
  end

  local currentWeight = storage.starPounds.weight
  -- Weight bounds for this size tier
  local minWeight = self.sizeConfig.sizes[index].weight
  local nextSize = self.sizeConfig.sizes[index + 1]
  local maxWeight = nextSize and nextSize.weight or self:maximumWeight()
  -- Interpolate weight based on progress.
  local targetWeight = minWeight + (maxWeight - minWeight) * progress
  self:setWeight(targetWeight)
  -- Return difference.
  return math.round(storage.starPounds.weight - currentWeight, 4)
end

function size:get(weight)
  -- Default to base size if the mod is off.
  if not self:isActive() then
    return self.sizeConfig.sizes[1], 1
  end
  -- Argument sanitisation.
  weight = math.max(tonumber(weight) or 0, 0)
  -- Disable supersized stages with options, or on the tech missions so you can actually complete them.
  local supersizeDisabled = starPounds.hasOption("disableSupersize") or status.uniqueStatusEffectActive("starpoundstechmissionmobility")

  -- Just return the current size if the weight is still in the bounds of the current size.
  if self.oldSizeIndex then
    local currentSize = self.sizeConfig.sizes[self.oldSizeIndex]
    local nextSize = self.sizeConfig.sizes[self.oldSizeIndex + 1]

    local skipCurrent = currentSize.yOffset and supersizeDisabled
    local overMin = weight >= currentSize.weight
    local underMax = (not nextSize) or (weight < nextSize.weight)

    if overMin and underMax and not skipCurrent then
      return currentSize, self.oldSizeIndex
    end
  end

  local sizeIndex = 0
  -- Go through all starPounds.sizes (smallest to largest) to find which size.
  for i in ipairs(self.sizeConfig.sizes) do
    local skipSize = self.sizeConfig.sizes[i].yOffset and supersizeDisabled
    if weight >= self.sizeConfig.sizes[i].weight and not skipSize then
      sizeIndex = i
    else
      break
    end
  end

  return self.sizeConfig.sizes[sizeIndex], sizeIndex
end

function size:sizes()
  return self.sizeConfig.sizes
end

function size:config()
  return self.sizeConfig
end

function size:stomachCapacity()
  local capacity = self.sizeConfig.stomachCapacity
  if starPounds.currentSize and starPounds.currentSize.stomachCapacity then
    capacity = starPounds.currentSize.stomachCapacity
  end

  return capacity
end

function size:breastCapacity()
  local capacity = self.sizeConfig.breastCapacity
  if starPounds.currentSize and starPounds.currentSize.breastCapacity then
    capacity = starPounds.currentSize.breastCapacity
  end

  return capacity
end

function size:maximumWeight()
  return self.sizeConfig.maxWeight
end

function size:minimumWeight()
  return self.sizeConfig.sizes[((starPounds.moduleFunc("skills", "level", "minimumSize") or 0) + 1)].weight
end

function size:offset()
  -- Shorthand for other scripts to use.
  return starPounds.currentSize and {0, (starPounds.currentSize.yOffset or 0)} or {0, 0}
end

function size:sizeIndex()
  -- Shorthand for other scripts to use.
  return starPounds.currentSizeIndex or 1
end

function size:weightMultiplier()
  -- NPCs just use the base size weight so we don't screw up their movement every time the mult changes.
  local weight = starPounds.type == "player" and storage.starPounds.weight or starPounds.currentSize.weight
  return storage.starPounds.enabled and math.round(1 + weight/entity.weight, 1) or 1
end

function size:updateStats(forceUpdate)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then
    starPounds.movementMultiplier = 1
    starPounds.jumpMultiplier = 1
    starPounds.swimMultiplier = 1
    return
  end
  -- Give the entity hitbox, bonus stats, and effects based on fatness.
  local size = starPounds.currentSize
  local sizeIndex = starPounds.currentSizeIndex
  if forceUpdate then
    local sizeStats = jarray()
    local bonusEffectiveness = self:effectScaling()
    -- Max Health
    local healthMult = 1 + math.round((size.healthMultiplier - 1) * starPounds.getStat("health"), 2)
    if healthMult ~= 1 then
      sizeStats[#sizeStats + 1] = {stat = "maxHealth", baseMultiplier = healthMult}
    end
    -- Knockback.
    local gritReduction = status.stat("activeMovementAbilities") <= 1 and -((starPounds.weightMultiplier - 1) * math.max(0, 1 - starPounds.getStat("knockbackResistance"))) or 0
    if gritReduction ~= 0 then
      sizeStats[#sizeStats + 1] = {stat = "grit", amount = gritReduction}
      sizeStats[#sizeStats + 1] = {stat = "knockbackThreshold", effectiveMultiplier = 1 - gritReduction}
    end
    -- Shield health.
    local shieldMult = 1 + starPounds.getStat("shieldHealth") * bonusEffectiveness
    if shieldMult ~= 1 then
      sizeStats[#sizeStats + 1] = {stat = "shieldHealth", effectiveMultiplier = shieldMult}
    end
    -- Fall damage.
    local fallDamageMult = 1 + (size.healthMultiplier - 1) * math.min(1 - starPounds.getStat("fallDamageResistance"), 1)
    if fallDamageMult ~= 1 then
      sizeStats[#sizeStats + 1] = {stat = "fallDamageMultiplier", effectiveMultiplier = fallDamageMult}
    end
    -- Resistances.
    local resistances = {"physicalResistance", "iceResistance", "poisonResistance", "electricResistance", "fireResistance"}
    for _, resistance in ipairs(resistances) do
      local amount = starPounds.getStat(resistance) * bonusEffectiveness
      if amount ~= 0 then
        sizeStats[#sizeStats + 1] = {stat = resistance, amount = amount}
      end
    end

    status.setPersistentEffects("starpounds", sizeStats)
  end

  -- Check if the entity is using a morphball (Tech patch bumps this number for the morphball).
  if status.stat("activeMovementAbilities") > 1 then return end

  if not self.baseParameters then self.baseParameters = mcontroller.baseParameters() end
  local parameters = self.baseParameters

  if forceUpdate or not (self.controlModifiers and self.controlParameters) then
    local movement = starPounds.getStat("movement")
    local movementMultiplier = size.movementMultiplier
    -- If we have the anti-immobile skill, use double the movement penalty of blob instead.
    local isImmobileProtected = movementMultiplier == 0 and starPounds.moduleFunc("skills", "has", "preventImmobile")
    if isImmobileProtected then
      movementMultiplier = self.sizeConfig.sizes[sizeIndex - 1].movementMultiplier
    end
    -- Store the amount we'd be at without any stat changes.
    starPounds.baseMovementMultiplier = movementMultiplier
    starPounds.baseJumpMultiplier = math.max(self.data.minimumJumpMultiplier, movementMultiplier)
    -- Movement stat starts at 0.
    -- Every +1 halves the penalty, every -1 doubles it (multiplicatively).
    if movementMultiplier > 0 then
      local penalty = 1 - movementMultiplier
      penalty = penalty * (2 ^ -movement)
      movementMultiplier = 1 - penalty
    end
    -- Double immobile penalty.
    if isImmobileProtected then
      starPounds.baseMovementMultiplier = starPounds.baseMovementMultiplier ^ 2
      starPounds.baseJumpMultiplier = math.max(self.data.minimumJumpMultiplier, starPounds.baseMovementMultiplier)
      movementMultiplier = movementMultiplier ^ 2
    end
    -- Set global.
    starPounds.movementMultiplier = movementMultiplier
    -- Jump/Swim math applies after the movement stat calcuation.
    if starPounds.movementMultiplier <= 0 then
      starPounds.movementMultiplier = 0
      starPounds.jumpMultiplier = self.data.minimumJumpMultiplier
      starPounds.swimMultiplier = self.data.minimumSwimMultiplier
    else
      starPounds.jumpMultiplier = math.max(self.data.minimumJumpMultiplier, 1 - ((1 - starPounds.movementMultiplier) * starPounds.getStat("jumpPenalty")))
      starPounds.swimMultiplier = math.max(self.data.minimumSwimMultiplier, 1 - ((1 - starPounds.movementMultiplier) * starPounds.getStat("swimPenalty")))
    end


    local updateMultipliers = false
    for _, value in pairs({"movementMultiplier", "jumpMultiplier", "swimMultiplier"}) do
      if starPounds[value] ~= starPounds[value.."Old"] then
        starPounds[value.."Old"] = starPounds[value]
        updateMultipliers = true
      end
    end

    if updateMultipliers then
      self.controlModifiers = starPounds.weightMultiplier == 1 and {} or {
        groundMovementModifier = movementMultiplier,
        liquidMovementModifier = starPounds.swimMultiplier,
        speedModifier = movementMultiplier,
        airJumpModifier = starPounds.jumpMultiplier,
        liquidJumpModifier = starPounds.swimMultiplier
      }
      -- Silly, but better than updating modifiers every tick.
      self.controlModifiersAlt = (movementMultiplier < self.data.minimumAltSpeedMultiplier) and sb.jsonMerge(self.controlModifiers, {
        speedModifier = self.data.minimumAltSpeedMultiplier
      }) or nil
    end

    -- weightMultiplier gets set to 0 in tech missions so weight doesn't affect their completion.
    local weightMultiplier = 1 + (starPounds.weightMultiplier - 1) * starPounds.getStat("weightMultiplier")
    self.controlParameters = starPounds.weightMultiplier == 1 and {} or {
      mass = parameters.mass * weightMultiplier,
      airForce = parameters.airForce * weightMultiplier,
      groundForce = parameters.groundForce * weightMultiplier,
      airFriction = parameters.airFriction * weightMultiplier,
      liquidBuoyancy = parameters.liquidBuoyancy + math.min((weightMultiplier - 1) * 0.01, 0.95),
      liquidForce = parameters.liquidForce * weightMultiplier,
      liquidFriction = parameters.liquidFriction * weightMultiplier,
      normalGroundFriction = parameters.normalGroundFriction * weightMultiplier,
      ambulatingGroundFriction = parameters.ambulatingGroundFriction * weightMultiplier,
      airJumpProfile = {jumpControlForce = parameters.airJumpProfile.jumpControlForce * weightMultiplier},
      liquidJumpProfile = {jumpControlForce = parameters.liquidJumpProfile.jumpControlForce * weightMultiplier}
    }
    -- Apply hitbox if we don't have the disable option checked, or we're a size that modifies our height.
    if size.yOffset or not starPounds.hasOption("disableHitbox") then
      for k, v in pairs(self.cachedHitboxes[sizeIndex]) do
        self.controlParameters[k] = v
      end
    end
  end
  mcontroller.controlModifiers((not self.controlModifiersAlt or starPounds.mcontroller.groundMovement) and self.controlModifiers or self.controlModifiersAlt)
  mcontroller.controlParameters(self.controlParameters)
end

function size:scalingSize()
  return self.sizeConfig.scalingSize
end

function size:activationSize()
  return self.sizeConfig.activationSize
end

function size:effectScaling()
  return math.min(1, (self:sizeIndex() - 1) / (self.sizeConfig.scalingSize - 1))
end

function size:effectActivated()
  return self:sizeIndex() >= self.sizeConfig.activationSize
end

function size:getVariant(size)
  -- Fallback.
  if not starPounds.hasOption("combinedStageTest") then
    return self:getVariantOld(size)
  end
  -- Don't do anything if the mod is disabled.
  if not self:isActive() then return "" end
  local size = size or starPounds.currentSize

  local breastVariant = self:getBreastVariant(size)
  local stomachVariant = self:getStomachVariant(size)

  return breastVariant .. stomachVariant
end

function size:getStomachVariant(size)
  local isHyper = starPounds.hasOption("hyper") and not size.disableHyper
  -- Hyper uses base stomach thresholds.
  if isHyper then
    size = self.sizeConfig.sizes[1]
  end

  local thresholds = size.thresholds.stomach
  local stomachSize = (starPounds.hasOption("disableStomachGrowth") and 0 or (starPounds.moduleFunc("stomach", "get").interpolatedContents or 0))
  if size.stomachOptions then
    local additionalSize = 0
    for option, amount in pairs(size.stomachOptions) do
      additionalSize = math.max(additionalSize, starPounds.hasOption(option) and amount or 0)
    end

    stomachSize = stomachSize + additionalSize
  end

  local variant = ""
  for _, v in ipairs(thresholds) do
    if stomachSize >= v.amount then
      variant = v.name
    end
  end
  -- Returns the index increase if hyper is enabled.
  return variant
end

function size:getBreastVariant(size)
  local isHyper = starPounds.hasOption("hyper") and not size.disableHyper
  if isHyper then return "hyper" end

  local thresholds = size.thresholds.breasts
  local breastSize = (starPounds.hasOption("disableBreastGrowth") and 0 or (starPounds.moduleFunc("breasts", "get").contents or 0))

  if size.breastOptions then
    local additionalSize = 0
    for option, amount in pairs(size.breastOptions) do
      additionalSize = math.max(additionalSize, starPounds.hasOption(option) and amount or 0)
    end

    breastSize = breastSize + additionalSize
  end

  local variant = ""
  for _, v in ipairs(thresholds) do
    if breastSize >= v.amount then
      variant = v.name
    end
  end
  -- Returns the index increase if hyper is enabled.
  return variant
end

function size:getHyperOffset(size)
  local isHyper = starPounds.hasOption("hyper") and not size.disableHyper
  if not isHyper then return 0 end

  local thresholds = size.thresholds.breasts
  local breastSize = (starPounds.hasOption("disableBreastGrowth") and 0 or (starPounds.moduleFunc("breasts", "get").contents or 0))

  if size.breastOptions then
    local additionalSize = 0
    for option, amount in pairs(size.breastOptions) do
      additionalSize = math.max(additionalSize, starPounds.hasOption(option) and amount or 0)
    end

    breastSize = breastSize + additionalSize
  end

  local index = 0
  for i, v in ipairs(thresholds) do
    if breastSize >= v.amount then
      index = i
    end
  end

  return index
end

function size:equipmentConfig(sizeIndex)
  if not self:isActive() then
    self.equipConfigCache.chest = ""
    self.equipConfigCache.legs = ""
    self.equipConfigCache.chestVariant = ""
    self.equipConfigCache.sizeIndex = 1
    return self.equipConfigCache
  end
  -- Size cap based on occupied vehicle. Uses math.huge by default because
  -- math.min doesn't ignore nils and I'd rather not do 10 more if statements.
  local vehicleCap = self.vehicleCap or {chest = math.huge, legs = math.huge}
  -- These can be independent based on options.
  local chestIndex = math.min(sizeIndex, vehicleCap.chest)
  local legsIndex = math.min(sizeIndex, vehicleCap.legs)

  -- Don't do this for supersized stages.
  if not self.sizeConfig.sizes[sizeIndex].yOffset then
    -- Calculate the 'target' size based on options and vehicle caps.
    for option, amount in pairs(self.data.sizeOptions.chest) do
      if starPounds.hasOption(option) then
        chestIndex = math.min(sizeIndex + amount, self.supersizeIndex - 1, vehicleCap.chest)
      end
    end
    -- Hyper index shifting.
    local isHyper = starPounds.hasOption("hyper") and not self.sizeConfig.sizes[chestIndex].disableHyper
    if isHyper then
      chestIndex = math.min(chestIndex + self:getHyperOffset(self.sizeConfig.sizes[chestIndex]), self.supersizeIndex - 1, vehicleCap.chest)
    end
    -- Same for legs.
    for option, amount in pairs(self.data.sizeOptions.legs) do
      if starPounds.hasOption(option) then
        legsIndex = math.min(sizeIndex + amount, self.supersizeIndex - 1, vehicleCap.legs)
      end
    end
  end
  -- Variant based on the 'adjusted' chest size.
  local chestVariant = self:getVariant(self.sizeConfig.sizes[chestIndex])

  self.equipConfigCache.chest = self.sizeConfig.sizes[chestIndex].size
  self.equipConfigCache.chestVariant = chestVariant
  self.equipConfigCache.chestIndex = chestIndex
  self.equipConfigCache.legs = self.sizeConfig.sizes[legsIndex].size
  self.equipConfigCache.legsIndex = legsIndex

  return self.equipConfigCache
end

function size:equip(equipConfig)
  if not self.canGain then return end

  -- Immobile sizes looks like blob with the mobility skill.
  if starPounds.moduleFunc("skills", "has", "preventImmobile") then
    if equipConfig.chest == "immobile" then
      equipConfig.chest = "blob"
      equipConfig.legs = "blob"
    end
  end

  -- Hash the current state of equips.
  local targetConfigHash = equipConfig.chest .. "|" .. (equipConfig.chestVariant or "") .. "|" .. equipConfig.legs .. "|" .. (equipConfig.legsVariant or "")

  self.slotCache = self.slotCache or {}
  local playedSound = false

  for _, itemSlot in ipairs(self.slots) do
    local slot = itemSlot[1]
    local conf = itemSlot[2]
    local itemType = conf.itemType
    local item = self.equippedItem(slot)

    -- Check if the items have changed.
    local itemChanged = not compare(self.slotCache[slot], item)
    local sizeChanged = self.lastConfigHash ~= targetConfigHash

    -- Only run lookups if the size or item data has changed.
    if itemChanged or sizeChanged then
      -- Only check if it fits when there's a new item.
      if itemChanged then
        self.slotCache[slot.."_fits"] = item and (root.itemType(item.name):find(itemType) ~= nil)
      end
      local fitsSlot = self.slotCache[slot.."_fits"]
      local variant = equipConfig[itemType.."Variant"] or ""
      local targetSizeString = equipConfig[itemType] .. variant
      -- If we have a generated item, check if it's invalid.
      if item and item.parameters.size then
        if item.parameters.size ~= targetSizeString then
          self.setEquippedItem(slot, self:makeSizeItem(itemType, equipConfig))
        end
      -- If the item is not generated, try to update it. Otherwise, give it back and remove it.
      elseif item and not item.parameters.size then
        local needsUpdate = (equipConfig[itemType] == "" and item.parameters.scaledSize) or ((equipConfig[itemType] ~= "") and (equipConfig[itemType] ~= item.parameters.scaledSize))

        if needsUpdate then
          local updatedItem, canUpdate = self:updateClothing(item, itemType, equipConfig)
          -- Manual check for oSB cosmetic slots.
          if not fitsSlot then
            updatedItem = self:restoreClothing(item)
            canUpdate = false
          end
          -- Apply the item if it fits, otherwise return it.
          if canUpdate then
            self.setEquippedItem(slot, updatedItem)
          else
            self.setEquippedItem(slot)
            self.giveItem(updatedItem)
            item = nil -- Item is now nil!
            -- Play clothing rip sound.
            if not playedSound then
              starPounds.moduleFunc("sound", "play", "clothingrip", 0.75)
              playedSound = true
            end
          end
        end
        -- Disable all variants if a cosmetic is in the oSB chest slot.
        if item and (itemType == "chest") and not conf.default then
          equipConfig.chestVariant = ""
        end
      end
      -- Apply the base item if the slot is empty,
      if conf.default and not item then
        if targetSizeString ~= "" then
          self.setEquippedItem(slot, self:makeSizeItem(itemType, equipConfig))
        end
      end
      -- Cache the slot.
      self.slotCache[slot] = self.equippedItem(slot)
    end
  end

  self.lastConfigHash = targetConfigHash
end

function size:makeSizeItem(itemType, equipConfig)
  if not self.canGain then return end
  -- Get entity species.
  local species = starPounds.getVisualSpecies()
  -- Get entity directives
  local directives = starPounds.getDirectives()
  -- Get the variant if necessary.
  local variant = equipConfig[itemType.."Variant"] or ""
  -- Return nothing if we're base size with no variant.
  if (equipConfig[itemType]..variant) == "" then
    return
  end
  -- Generate the item.
  return {
    name = string.format("%s%s%s%s", equipConfig[itemType], variant, species:lower(), itemType),
    parameters = { directives = directives, price = 0, size = equipConfig[itemType]..variant, rarity = "essential" },
    count = 1
  }
end

function size:updateClothing(item, itemType, equipConfig)
  -- Just restore the item back at base size.
  if equipConfig[itemType] == "" then
    return self:restoreClothing(item), true
  end

  local itemName = item.parameters.baseName or item.name
  local newItemName = equipConfig[itemType] .. itemName
  -- This makes NPCs share their size caches too.
  local shared = getmetatable ""
  shared.starPounds = shared.starPounds or {}
  shared.starPounds.sizeCache = shared.starPounds.sizeCache or {}
  -- Initialize caches if they don't exist.
  shared.starPounds.sizeCache.validClothing = shared.starPounds.sizeCache.validClothing or {}
  shared.starPounds.sizeCache.hideBody = shared.starPounds.sizeCache.hideBody or {}
  -- Locals so code is neater below.
  local validClothingCache = shared.starPounds.sizeCache.validClothing
  local hideBodyCache = shared.starPounds.sizeCache.hideBody
  -- Cache item pcall lookups.
  if validClothingCache[newItemName] == nil then
    validClothingCache[newItemName] = pcall(root.itemType, newItemName)
  end
  if validClothingCache[newItemName] then
    -- If found, give the new item some parameters for easier checking.
    item.parameters.baseName = itemName
    item.parameters.scaledSize = equipConfig[itemType]
    item.name = newItemName
    return item, true
  end
  -- Cache root.itemConfig lookups globally.
  if hideBodyCache[itemName] == nil then
    local itemData = root.itemConfig(itemName)
    hideBodyCache[itemName] = (itemData and itemData.config and (itemData.config.hideBody or itemData.config.ignoreSize)) or false
  end
  -- Item config fallback.
  local ignoresSize = (item.parameters and item.parameters.ignoreSize) or hideBodyCache[itemName]
  -- Just give items that hide the body the tags so we ignore them.
  if equipConfig[itemType.."Index"] < self.supersizeIndex and ignoresSize then
    item.parameters.baseName = itemName
    item.parameters.scaledSize = equipConfig[itemType]
    return item, true
  end

  -- Return the old, restored item if a new one could not be found.
  return self:restoreClothing(item), false
end

function size:restoreClothing(item)
  -- Only run if it's actually a scaled up piece.
  if item.parameters.scaledSize and item.parameters.baseName then
    -- Restore the original item.
    item = {
      name = item.parameters.baseName,
      parameters = item.parameters,
      count = item.count
    }
    item.parameters.scaledSize = nil
    item.parameters.baseName = nil
    return item
  end
  -- Return the old one if we don't need to do anything.
  return item
end

function size:trackVehicleCap()
  -- Reset if the mod is disabled.
  if not self:isActive() then self.anchored = nil return end
  local anchored, index = mcontroller.anchorState()
  if self.anchored ~= anchored then
    self.vehicleCap = nil

    local anchorEntity = anchored and world.entityName(anchored) or nil
    if self.data.vehicleCap[anchorEntity] then
      self.vehicleCap = self.data.vehicleCap[anchorEntity][index + 1] or nil
    end
  end
  self.anchored = anchored
end

function size:progress()
  -- Default to 0 if the mod is off.
  if not self:isActive() then
    return 0
  end
  -- Progress to next stage.
  local currentSizeWeight = starPounds.currentSize.weight
  local nextSizeWeight = self.sizeConfig.sizes[starPounds.currentSizeIndex + 1] and self.sizeConfig.sizes[starPounds.currentSizeIndex + 1].weight or self.sizeConfig.maxWeight
  if nextSizeWeight ~= self.sizeConfig.maxWeight and self.sizeConfig.sizes[starPounds.currentSizeIndex + 1].yOffset and starPounds.hasOption("disableSupersize") then
    nextSizeWeight = self.sizeConfig.maxWeight
  end
  return math.round((storage.starPounds.weight - currentSizeWeight)/(nextSizeWeight - currentSizeWeight), 4)
end

function size:stomachMultiplier()
  if not storage.starPounds.enabled then return 1 end
  return self:stomachCapacity() / self.sizeConfig.stomachCapacity
end

function size:cursorCheck()
  -- Return if not a player.
  if starPounds.type ~= "player" then return end
  -- Check the item the player is holding.
  if starPounds.swapSlotItem then
    local item = starPounds.swapSlotItem
    item.parameters = item.parameters or {}
    -- Delete base size items.
    if starPounds.swapSlotItem.parameters.size then
      player.setSwapSlotItem(nil)
      return
    end
    -- Restore scaled up clothing items.
    if item.parameters.scaledSize and item.parameters.baseName then
      item = self:restoreClothing(item)
      player.setSwapSlotItem(item)
    end
  end
end

function size.reset()
  storage.starPounds.weight = size.sizeConfig.sizes[(starPounds.moduleFunc("skills", "level", "minimumSize") + 1)].weight
  return true
end

-- Delete eventually.
function size:getVariantOld(size)
  -- Don't do anything if the mod is disabled.
  if not self:isActive() then return "" end
  -- Argument sanitisation.
  local size = type(size) == "table" and size or starPounds.currentSize
  local variant = nil
  local thresholds = starPounds.currentSize.thresholds

  local breastSize = (starPounds.hasOption("disableBreastGrowth") and 0 or (starPounds.moduleFunc("breasts", "get").contents or 0))
  if starPounds.currentSize.breastOptions then
    local additionalSize = 0
    for option, amount in pairs(starPounds.currentSize.breastOptions) do
      additionalSize = math.max(additionalSize, starPounds.hasOption(option) and amount or 0)
    end

    breastSize = breastSize + additionalSize
  end


  local stomachSize = (starPounds.hasOption("disableStomachGrowth") and 0 or (starPounds.moduleFunc("stomach", "get").interpolatedContents or 0))
  if starPounds.currentSize.stomachOptions then
    local additionalSize = 0
    for option, amount in pairs(starPounds.currentSize.stomachOptions) do
      additionalSize = math.max(additionalSize, starPounds.hasOption(option) and amount or 0)
    end

    stomachSize = stomachSize + additionalSize
  end

  for _, v in ipairs(thresholds.breasts) do
    if breastSize >= v.amount then
      variant = v.name
    end
  end

  for _, v in ipairs(thresholds.stomach) do
    if stomachSize >= v.amount then
      variant = v.name
    end
  end

  if not starPounds.currentSize.disableHyper and starPounds.hasOption("hyper") then
    variant = "hyper"
  end

  return variant
end

starPounds.modules.size = size
