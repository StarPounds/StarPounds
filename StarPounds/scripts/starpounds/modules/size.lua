local size = starPounds.module:new("size")

function size:init()
  message.setHandler("starPounds.gainWeight", function(_, _, ...) return self:gainWeight(...) end)
  message.setHandler("starPounds.loseWeight", function(_, _, ...) return self:loseWeight(...) end)
  message.setHandler("starPounds.setWeight", function(_, _, ...) return self:setWeight(...) end)
  message.setHandler("starPounds.getSize", function(_, _, ...) return self:get(...) end)
  message.setHandler("starPounds.getChestVariant", function(_, _, ...) return self:getVariant(...) end)
  message.setHandler("starPounds.resetWeight", localHandler(self.reset))

  local function nullFunction() end
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
    self.giveItem = nullFunction
    speciesData = starPounds.getSpeciesData(npc.species())
  end

  self.canGain = speciesData.weightGain

  -- Fetch the first supersize index for future use.
  self.supersizeIndex = math.huge
  for i, size in ipairs(starPounds.sizes) do
    if size.yOffset then
      self.supersizeIndex = math.min(self.supersizeIndex, i)
    end
  end

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

  -- Need this ready for other modules.
  starPounds.currentSize, starPounds.currentSizeIndex = self:get(0)
  starPounds.weightMultiplier = 1
  -- Just in case the data is out of range.
  self:setWeight(storage.starPounds.weight)
end

function size:update(dt)
  starPounds.currentSize, starPounds.currentSizeIndex = self:get(storage.starPounds.weight)
  starPounds.currentVariant = self:getVariant(starPounds.currentSize)
  starPounds.weight = storage.starPounds.weight
  starPounds.weightMultiplier = self:weightMultiplier()

  if starPounds.currentSizeIndex ~= self.oldSizeIndex then
    starPounds.events:fire("sizes:changed", starPounds.currentSizeIndex - (self.oldSizeIndex or 0))
    -- Force stat update.
    starPounds.events:fire("stats:calculate", "sizes:changed")
    -- Don't play the sound on the first load.
    if self.oldSizeIndex then
      -- Play sound to indicate size change.
      starPounds.moduleFunc("sound", "play", "digest", 0.75, math.random(10,15) * 0.1 - storage.starPounds.weight/(starPounds.settings.maxWeight * 2))
    end
    -- Update status effect tracker.
    starPounds.moduleFunc("trackers", "clearStatuses")
    starPounds.moduleFunc("trackers", "createStatuses")
  elseif starPounds.weightMultiplier ~= self.oldWeightMultiplier then
    starPounds.events:fire("stats:calculate", "sizes:weightMultChanged")
  end

  self.oldSizeIndex = starPounds.currentSizeIndex
  self.oldWeightMultiplier = starPounds.weightMultiplier

  self:cursorCheck()
  self:trackVehicleCap()
  self:equip(self:equipmentConfig(starPounds.currentSizeIndex))

  self:updateStats()
end

function size:gainWeight(amount, fullAmount)
  -- Don't do anything if the mod is disabled.
  if not (storage.starPounds.enabled and self.canGain) then return 0 end
  -- Don't do anything if weight gain is disabled.
  if starPounds.hasOption("disableGain") then return 0 end
  -- Argument sanitisation.
  amount = tonumber(amount) or 0
  amount = util.clamp(amount * (fullAmount and 1 or starPounds.getStat("weightGain")), 0, starPounds.settings.maxWeight - storage.starPounds.weight)
  self:setWeight(storage.starPounds.weight + amount)
  return amount
end

function size:loseWeight(amount, fullAmount)
  -- Don't do anything if the mod is disabled.
  if not (storage.starPounds.enabled and self.canGain) then return 0 end
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
  if not (storage.starPounds.enabled and self.canGain) then return end
  -- Argument sanitisation.
  amount = math.round(tonumber(amount) or 0, 4)
  storage.starPounds.weight = util.clamp(amount, self:minimumWeight(), starPounds.settings.maxWeight)
end

function size:get(weight)
  -- Default to base size if the mod is off.
  if not (storage.starPounds.enabled and self.canGain) then
    return starPounds.sizes[1], 1
  end
  -- Argument sanitisation.
  weight = math.max(tonumber(weight) or 0, 0)

  local sizeIndex = 0
  -- Disable supersized stages with options, or on the tech missions so you can actually complete them.
  local supersizeDisabled = starPounds.hasOption("disableSupersize") or status.uniqueStatusEffectActive("starpoundstechmissionmobility")
  -- Go through all starPounds.sizes (smallest to largest) to find which size.
  for i in ipairs(starPounds.sizes) do
    local skipSize = starPounds.sizes[i].yOffset and supersizeDisabled
    if weight >= starPounds.sizes[i].weight and not skipSize then
      sizeIndex = i
    else
      break
    end
  end

  return starPounds.sizes[sizeIndex], sizeIndex
end

function size:minimumWeight()
  return starPounds.sizes[((starPounds.moduleFunc("skills", "level", "minimumSize") or 0) + 1)].weight
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
  if not storage.starPounds.enabled then return end
  -- Give the entity hitbox, bonus stats, and effects based on fatness.
  local size = starPounds.currentSize
  local sizeIndex = starPounds.currentSizeIndex
  if forceUpdate then
    -- Shouldn't activate at base size, so indexes are reduced by one.
    local bonusEffectiveness = self:effectScaling()
    local applyImmunity = self:effectActivated()
    local gritReduction = status.stat("activeMovementAbilities") <= 1 and -((starPounds.weightMultiplier - 1) * math.max(0, 1 - starPounds.getStat("knockbackResistance"))) or 0
    local persistentEffects = {
      {stat = "maxHealth", baseMultiplier = 1 + math.round((size.healthMultiplier - 1) * starPounds.getStat("health"), 2)},
      {stat = "foodDelta", effectiveMultiplier = ((starPounds.stomach.food > 0) or starPounds.hasOption("disableHunger")) and 0 or math.round(starPounds.getStat("hunger"), 2)},
      {stat = "grit", amount = gritReduction},
      {stat = "shieldHealth", effectiveMultiplier = 1 + starPounds.getStat("shieldHealth") * bonusEffectiveness},
      {stat = "knockbackThreshold", effectiveMultiplier = 1 - gritReduction},
      {stat = "fallDamageMultiplier", effectiveMultiplier = size.healthMultiplier * (1 - starPounds.getStat("fallDamageResistance"))},
      {stat = "iceResistance", amount = starPounds.getStat("iceResistance") * bonusEffectiveness},
      {stat = "poisonResistance", amount = starPounds.getStat("poisonResistance") * bonusEffectiveness}
    }
    -- Probably not optimal, but don't apply effects if they do nothing.
    local filteredPersistentEffects = jarray()
    for i, effect in ipairs(persistentEffects) do
      local skip = (
        effect.baseMultiplier and effect.baseMultiplier == 1) or (
        effect.effectiveMultiplier and effect.effectiveMultiplier == 1) or (
        effect.amount and effect.amount == 0
      )
      if not skip then filteredPersistentEffects[#filteredPersistentEffects + 1] = effect end
    end
    status.setPersistentEffects("starpounds", filteredPersistentEffects)
  end

  -- Check if the entity is using a morphball (Tech patch bumps this number for the morphball).
  if status.stat("activeMovementAbilities") > 1 then return end

  if not baseParameters then baseParameters = mcontroller.baseParameters() end
  local parameters = baseParameters

  if forceUpdate or not (self.controlModifiers and self.controlParameters) then
    local movement = starPounds.getStat("movement")
    starPounds.movementMultiplier = size.movementMultiplier
    -- If we have the anti-immobile skill, use double the movement penalty of blob instead.
    local isImmobile = starPounds.movementMultiplier == 0
    if isImmobile and starPounds.moduleFunc("skills", "has", "preventImmobile") then
      starPounds.movementMultiplier = starPounds.sizes[sizeIndex - 1].movementMultiplier ^ 2
    end
    -- Movement stat starts at 0.
    -- Every +1 halves the penalty, every -1 doubles it (multiplicatively).
    if starPounds.movementMultiplier > 0 then
      if movement <= 0 then
        starPounds.movementMultiplier = starPounds.movementMultiplier ^ (1 - movement)
      else
        starPounds.movementMultiplier = 1 - ((1 - starPounds.movementMultiplier) / (2 ^ movement))
      end
    end
    -- Jump/Swim math applies after the movement stat calcuation.
    if starPounds.movementMultiplier <= 0 then
      starPounds.movementMultiplier = 0
      starPounds.jumpModifier = self.data.minimumJumpMultiplier
      starPounds.swimModifier = self.data.minimumSwimMultiplier
    else
      starPounds.jumpModifier = math.max(self.data.minimumJumpMultiplier, 1 - ((1 - starPounds.movementMultiplier) * starPounds.getStat("jumpPenalty")))
      starPounds.swimModifier = math.max(self.data.minimumSwimMultiplier, 1 - ((1 - starPounds.movementMultiplier) * starPounds.getStat("swimPenalty")))
    end


    local updateModifiers = false
    for _, value in pairs({"movementMultiplier", "jumpModifier", "swimModifier"}) do
      if starPounds[value] ~= starPounds[value.."Old"] then
        starPounds[value.."Old"] = starPounds[value]
        updateModifiers = true
      end
    end

    local movementMultiplier = starPounds.movementMultiplier
    local weightMultiplier = starPounds.weightMultiplier

    if updateModifiers then
      self.controlModifiers = weightMultiplier == 1 and {} or {
        groundMovementModifier = movementMultiplier,
        liquidMovementModifier = starPounds.swimModifier,
        speedModifier = movementMultiplier,
        airJumpModifier = starPounds.jumpModifier,
        liquidJumpModifier = starPounds.swimModifier
      }
      -- Silly, but better than updating modifiers every tick.
      self.controlModifiersAlt = (movementMultiplier < self.data.minimumAltSpeedMultiplier) and sb.jsonMerge(self.controlModifiers, {
        speedModifier = self.data.minimumAltSpeedMultiplier
      }) or nil
    end

    self.controlParameters = weightMultiplier == 1 and {} or {
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
      self.controlParameters = sb.jsonMerge(self.controlParameters, (size.controlParameters[starPounds.getVisualSpecies()] or size.controlParameters.default))
    end
  end
  mcontroller.controlModifiers((not self.controlModifiersAlt or starPounds.mcontroller.groundMovement) and self.controlModifiers or self.controlModifiersAlt)
  mcontroller.controlParameters(self.controlParameters)
end

function size:scalingSize()
  return self.data.scalingSize
end

function size:activationSize()
  return self.data.activationSize
end

function size:effectScaling()
  return math.min(1, (self:sizeIndex() - 1) / (self.data.scalingSize - 1))
end

function size:effectActivated()
  return self:sizeIndex() >= self.data.activationSize
end

function size:getVariant(size)
  -- Don't do anything if the mod is disabled.
  if not (storage.starPounds.enabled and self.canGain) then return "" end
  -- Argument sanitisation.
  local size = type(size) == "table" and size or {}
  local variants = size.variants or jarray()
  local variant = nil
  local thresholdMultiplier = starPounds.currentSize.thresholdMultiplier
  local breastThresholds = starPounds.settings.thresholds.breasts
  local stomachThresholds = starPounds.settings.thresholds.stomach

  local breastSize = (starPounds.hasOption("disableBreastGrowth") and 0 or (starPounds.moduleFunc("breasts", "get").contents or 0)) + (
    starPounds.hasOption("busty") and breastThresholds[1].amount * thresholdMultiplier or (
    starPounds.hasOption("milky") and breastThresholds[2].amount * thresholdMultiplier or 0)
  )

  local stomachSize = (starPounds.hasOption("disableStomachGrowth") and 0 or (starPounds.moduleFunc("stomach", "get").interpolatedContents or 0)) + (
    starPounds.hasOption("stuffed") and stomachThresholds[2].amount * thresholdMultiplier or (
    starPounds.hasOption("filled") and stomachThresholds[4].amount * thresholdMultiplier or (
    starPounds.hasOption("gorged") and stomachThresholds[6].amount * thresholdMultiplier or 0))
  )

  -- Testing, remove later. ----------------------------------
  if starPounds.hasOption("combinedStageTest") then
    variant = ""

    if starPounds.hasOption("hyper") then
      if contains(variants, "hyper") then
        variant = variant .. "hyper"
      end
    end

    local breastVariant = ""
    for _, v in ipairs(breastThresholds) do
      if contains(variants, v.name) then
        if breastSize >= (v.amount * thresholdMultiplier) then
          breastVariant = v.name
        end
      end
    end
    variant = variant .. breastVariant

    local stomachVariant = ""
    for _, v in ipairs(stomachThresholds) do
      if contains(variants, v.name) then
        if stomachSize >= (v.amount * thresholdMultiplier) then
          stomachVariant = v.name
        end
      end
    end
    variant = variant .. stomachVariant

    return variant
  end
  -- Testing, remove later. ----------------------------------

  for _, v in ipairs(breastThresholds) do
    if contains(variants, v.name) then
      if breastSize >= (v.amount * thresholdMultiplier) then
        variant = v.name
      end
    end
  end

  for _, v in ipairs(stomachThresholds) do
    if contains(variants, v.name) then
      if stomachSize >= (v.amount * thresholdMultiplier) then
        variant = v.name
      end
    end
  end

  if starPounds.hasOption("hyper") then
    if contains(variants, "hyper") then
      variant = "hyper"
    end
  end

  return variant
end

function size:equipmentConfig(sizeIndex)
  if not (storage.starPounds.enabled and self.canGain) then
    return {
      chest = "",
      legs = "",
      chestVariant = "",
      sizeIndex = 1
    }
  end
  -- Size cap based on occupied vehicle. Uses math.huge by default because
  -- math.min doesn't ignore nils and I'd rather not do 10 more if statements.
  local vehicleCap = self.vehicleCap or {chest = math.huge, legs = math.huge}
  -- These can be independent based on options.
  local chestIndex = math.min(sizeIndex, vehicleCap.chest)
  local legsIndex = math.min(sizeIndex, vehicleCap.legs)

  -- Don't do this for supersized stages.
  if not starPounds.sizes[sizeIndex].yOffset then
    -- Calculate the 'target' size based on options and vehicle caps.
    for option, amount in pairs(self.data.sizeOptions.chest) do
      if starPounds.hasOption(option) then
        chestIndex = math.min(sizeIndex + amount, self.supersizeIndex - 1, vehicleCap.chest)
      end
    end
    -- Same for legs.
    for option, amount in pairs(self.data.sizeOptions.legs) do
      if starPounds.hasOption(option) then
        legsIndex = math.min(sizeIndex + amount, self.supersizeIndex - 1, vehicleCap.legs)
      end
    end
  end
  -- Variant based on the 'adjusted' chest size.
  local chestVariant = self:getVariant(starPounds.sizes[chestIndex])

  return {
    chest = starPounds.sizes[chestIndex].size,
    chestVariant = chestVariant,
    chestIndex = chestIndex,

    legs = starPounds.sizes[legsIndex].size,
    legsIndex = legsIndex
  }
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
  -- Only play the rip sound once per unequip.
  local playedSound
  for _, itemSlot in ipairs(self.slots) do
    local slot = itemSlot[1]
    local conf = itemSlot[2]
    local itemType = conf.itemType
    local item = self.equippedItem(slot)
    local fitsSlot = item and (root.itemType(item.name):find(itemType) ~= nil)
    -- If we have a generated item, check if it's invalid.
    if item and item.parameters.size then
      local variant = equipConfig[itemType.."Variant"] or ""
      if item.parameters.size ~= (equipConfig[itemType]..variant) then
        self.setEquippedItem(slot, size:makeSizeItem(itemType, equipConfig))
      end
    -- If the item is not generated, try to update it. Otherwise, give it back and remove it.
    elseif item and not item.parameters.size then
      -- Item only needs to be updated if we're at base size and it has a size tag, or the size tag does not match our current size.
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
          item = nil
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
    -- Otherwise, apply the base item.
    elseif conf.default and not item then
      local variant = equipConfig[itemType.."Variant"] or ""
      if (equipConfig[itemType]..variant) ~= "" then
        self.setEquippedItem(slot, size:makeSizeItem(itemType, equipConfig))
      end
    end
  end
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
  local newItemName = equipConfig[itemType]..itemName
  if pcall(root.itemType, newItemName) then
    -- If found, give the new item some parameters for easier checking.
    item.parameters.baseName = itemName
    item.parameters.scaledSize = equipConfig[itemType]
    item.name = newItemName
    return item, true
  end

  -- Just give items that hide the body the tags so we ignore them.
  if equipConfig[itemType.."Index"] < self.supersizeIndex and (root.itemConfig(item).config.hideBody or configParameter(item, "ignoreSize")) then
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
  if not (storage.starPounds.enabled and self.canGain) then self.anchored = nil return end
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

function size:cursorCheck()
  -- Return if not a player.
  if not starPounds.type == "player" then return end
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
  storage.starPounds.weight = starPounds.sizes[(starPounds.moduleFunc("skills", "level", "minimumSize") + 1)].weight
  return true
end

starPounds.modules.size = size
