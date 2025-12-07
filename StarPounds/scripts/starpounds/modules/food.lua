local food = starPounds.module:new("food")

function food:init()
  -- Caches.
  self.foodTypeCache = {}
  self.fatCache = copy(self.data.fatCache)
end

function food:foodType(foodType)
  if not self:isFoodType(foodType) then
    return self.data.foods.default, "default"
  end

  if self.foodTypeCache[foodType] then
    return self.foodTypeCache[foodType], foodType
  end

  self.foodTypeCache[foodType] = sb.jsonMerge(self.data.foods.default, self.data.foods[foodType])
  setmetatable(self.foodTypeCache[foodType], nil)

  return self.foodTypeCache[foodType], foodType
end

function food:isFoodType(foodType)
  return self.data.foods[foodType] ~= nil
end

function food:getFatValue(itemName, recursionCache)
  -- Don't parse again if we've already seen this item.
  recursionCache = recursionCache or {}
  if recursionCache[itemName] then
    return 0
  end

  if self.fatCache[itemName] then
    return self.fatCache[itemName]
  end

  local itemConfig = root.itemConfig(itemName)
  if not itemConfig then return 0 end

  if itemConfig.config.fatValue then
    self.fatCache[itemName] = itemConfig.config.fatValue
    return itemConfig.config.fatValue
  end

  recursionCache[itemName] = true

  local fatValue = 0
  local recipes = root.recipesForItem(itemName)

  for _, recipe in ipairs(recipes) do
    local recipeFatValue = 0

    for _, input in ipairs(recipe.input) do
      local inputFatValue = self:getFatValue(input.name, shallowCopy(recursionCache))
      if inputFatValue > 0 then
        recipeFatValue = recipeFatValue + (input.count * inputFatValue) / (recipe.output.count or 1)
      end
    end

    fatValue = math.max(fatValue, recipeFatValue)
  end

  self.fatCache[itemName] = fatValue
  return fatValue
end

function food:updateItem(item)
  local foodValue = configParameter(item, "foodValue", 0)
  local fatValue = configParameter(item, "fatValue", self:getFatValue(item.name))

  if (foodValue + fatValue) > 0 and not configParameter(item, "starpounds_effectApplied", false) then
    local effects = configParameter(item, "effects", jarray())

    if not effects[1] then
      table.insert(effects, jarray())
    end
    -- Get the specific food type for the item category.
    local category = configParameter(item, "category", ""):lower()
    local foodType = self.data.categoryTypes[category:lower()] or self.data.categoryTypes.food
    -- Add food.
    if foodValue > 0 then
      table.insert(effects[1], { effect = foodType.food..(disableExperience and "_noexperience" or ""), duration = foodValue })
      -- Reset the item's vanilla food value.
      item.parameters.starpounds_foodValue = foodValue
      item.parameters.foodValue = configParameter(item, "foodValue") and 0 or nil
    end
    -- Add fat.
    if fatValue > 0 then
      table.insert(effects[1], { effect = foodType.fat, duration = fatValue })
    end
    -- Add experience.
    local rarity = configParameter(item, "rarity", "common"):lower()
    local disableExperience = configParameter(item, "starpounds_disableExperience", false)
    if (foodValue > 0) and self.data.experienceBonus[rarity] and not disableExperience then
      bonusExperience = foodValue * self.data.experienceBonus[rarity]
      table.insert(effects[1], { effect = "starpoundsfood_bonusexperience", duration = bonusExperience })
    end

    item.parameters.starpounds_effectApplied = true
    item.parameters.effects = effects

    return item
  end
  return false
end

starPounds.modules.food = food
