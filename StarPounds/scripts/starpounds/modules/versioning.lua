local versioning = starPounds.module:new("versioning")

-- Should probably split this up into several lua files, but it's whatever.
versioning.versions = {
  [1] = function(data)
    -- Slight increase to weight to preserve stage progress.
    local function convertWeight(weight)
      if weight >= 500 then return weight * 1.1013 end
      if weight <= 0 then return 0 end
      -- Old/new weight tiers in lb (roughly).
      local tiers = {{0, 0}, {25, 55}, {100, 165}, {500, 550}}
      for i = 1, #tiers - 1 do
        local t1, t2 = tiers[i], tiers[i+1]
        if weight >= t1[1] and weight <= t2[1] then
          local progress = (weight - t1[1]) / (t2[1] - t1[1])
          return t1[2] + progress * (t2[2] - t1[2])
        end
      end
    end
    -- lb -> kg
    data.weight = math.round(convertWeight(data.weight) * 0.45359237, 2)
    -- Rename stomach variable.
    local stomachContents = data.stomachContents
    data.stomachContents = nil
    data.stomachLerp = nil
    data.stomach = stomachContents or {}

    -- New milk format.
    local milkAmount = tonumber(data.breasts) or 0
    local milkType = data.breastType or "milk"
    data.breastType = nil
    data.breasts = {type = milkType, amount = milkAmount}

    -- New experience format.
    local level = tonumber(data.level) or 0
    local amount = tonumber(data.experience) or 0
    data.level = nil
    data.experience = {level = level, amount = amount}

    -- New effect format.
    local discoveredEffects = data.discoveredEffects or {}
    data.discoveredEffects = nil
    data.effects = {active = {}, discovered = discoveredEffects}
    -- Delete old trait value.
    data.trait = nil
    -- No more stat saving.
    data.stats = nil
    -- Other old values to prune.
    data.optionMultipliers = nil
    data.optionOverrides = nil
    data.traitStats = nil
    data.accessories = nil
    data.bloat = nil
    data.pizzaEmployeesEaten = nil

    -- Weight distribution options.
    for _, option in ipairs({{name = "extraBottomHeavy", value = -2}, {name = "bottomHeavy", value = -1}, {name = "topHeavy", value = 1}, {name = "extraTopHeavy", value = 2}}) do
      if data.options[option.name] then
        data.options.bodyShape = option.value
        break
      end
    end
    -- Stomach size.
    for i, option in ipairs({"stuffed", "filled", "gorged"}) do
      if data.options[option] then
        data.options.stomachSize = i
        break
      end
    end
    -- Breast size.
    for i, option in ipairs({"busty", "milky"}) do
      if data.options[option] then
        data.options.breastSize = i
        break
      end
    end
    -- Sound.
    if data.options.disableSound then
      data.options.volume = 0
    elseif data.options.quietSounds then
      data.options.volume = 0.5
    end
    -- Belch pitch.
    if data.options.higherBelches then
      data.options.belchPitch = 1.25
    elseif data.options.deeperBelches then
      data.options.deeperBelches = 0.75
    end
    -- Imperial unit option.
    if data.options.useImperial then
      data.options.weightUnit = "imperial"
    end
    -- Remove old option data.
    for _, option in ipairs({
      "extraBottomHeavy", "bottomHeavy", "topHeavy", "extraTopHeavy",
      "stuffed", "filled", "gorged",
      "busty", "milky",
      "disableSound", "quietSounds",
      "higherBelches", "deeperBelches",
      "useImperial"
    }) do
      data.options[option] = nil
    end

    return data
  end
}

function versioning:update(data)
  data.version = data.version or 0
  -- Can't use ipairs on a sparse list of versions.
  local versionKeys = {}
  for version in pairs(self.versions) do
    table.insert(versionKeys, version)
  end
  table.sort(versionKeys)
  -- Apply versioning.
  for _, version in ipairs(versionKeys) do
    if version > data.version then
      local versioningFunc = self.versions[version]
      if versioningFunc then
        data = versioningFunc(data)
        data.version = version
      end
    end
  end

  return data
end

starPounds.modules.versioning = versioning
