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
  if self.fatCache[itemName] then
    return self.fatCache[itemName]
  end

  recursionCache = recursionCache or {}
  if recursionCache[itemName] then
    return 0
  end

  local itemConfig = root.itemConfig(itemName)
  if not itemConfig then
    self.fatCache[itemName] = 0
    return 0
  end

  if itemConfig.config.fatValue then
    self.fatCache[itemName] = itemConfig.config.fatValue
    return itemConfig.config.fatValue
  end

  recursionCache[itemName] = true

  local fatValue = 0
  local recipes = root.recipesForItem(itemName)
  local ignoredGroups = self.data.ignoredRecipeGroups or {}

  for _, recipe in ipairs(recipes) do
    -- Check if the recipe is ignored.
    local isIgnored = false
    for _, group in ipairs(recipe.groups or {}) do
      if ignoredGroups[group] then
        isIgnored = true
        break
      end
    end

    if not isIgnored then
      local recipeFatValue = 0
      local outputCount = (recipe.output and recipe.output.count) or 1

      for _, input in ipairs(recipe.input) do
        local inputFatValue = self:getFatValue(input.name, recursionCache)
        if inputFatValue > 0 then
          recipeFatValue = recipeFatValue + (input.count * inputFatValue) / outputCount
        end
      end

      fatValue = math.max(fatValue, recipeFatValue)
    end
  end

  -- Clear this item from the active branch before returning.
  recursionCache[itemName] = nil
  self.fatCache[itemName] = fatValue

  return fatValue
end

function food:updateItem(item)
  local foodValue = configParameter(item, "foodValue", 0)
  local fatValue = configParameter(item, "fatValue") or self:getFatValue(item.name)
  if (foodValue + fatValue) > 0 and not configParameter(item, "starpounds_effectApplied", false) then
    item.parameters = item.parameters or {}
    local effects = configParameter(item, "effects", jarray())

    if not effects[1] then
      table.insert(effects, jarray())
    end
    -- Get the specific food type for the item category.
    local category = configParameter(item, "category", ""):lower()
    local foodType = self.data.categoryTypes[category] or self.data.categoryTypes.food
    local disableExperience = configParameter(item, "starpounds_disableExperience", false)
    -- Add food.
    if foodValue > 0 then
      table.insert(effects[1], {
        effect = foodType.food .. (disableExperience and "_noexperience" or ""),
        duration = foodValue
      })
      -- Reset the item's vanilla food value.
      item.parameters.starpounds_foodValue = foodValue
      if configParameter(item, "foodValue") then
        item.parameters.foodValue = 0
      end
    end
    -- Add fat.
    if fatValue > 0 then
      table.insert(effects[1], { effect = foodType.fat, duration = fatValue })
    end
    -- Add experience.
    local rarity = configParameter(item, "rarity", "common"):lower()
    if (foodValue > 0) and self.data.experienceBonus[rarity] and not disableExperience then
      local bonusExperience = foodValue * self.data.experienceBonus[rarity]
      table.insert(effects[1], { effect = "starpoundsfood_bonusexperience", duration = bonusExperience })
    end

    item.parameters.starpounds_effectApplied = true
    item.parameters.effects = effects

    return item
  end
  return false
end

starPounds.modules.food = food
