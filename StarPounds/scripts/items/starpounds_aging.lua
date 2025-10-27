function ageItem(baseItem, aging)
  if baseItem.parameters.timeToAge and not baseItem.parameters.aged then
    baseItem.parameters.timeToAge = baseItem.parameters.timeToAge - aging

    baseItem.parameters.tooltipFields = baseItem.parameters.tooltipFields or {}

    local itemConfig = root.itemConfig(baseItem.name)
    local ageTime = itemConfig.config.timeToAge or root.assetJson("/items/starpounds_aging.config:baseTimeToAge")

    baseItem.parameters.tooltipFields.ageTimeLabel = getAgeTimeDescription(baseItem.parameters.timeToAge / ageTime)

    if baseItem.parameters.timeToAge <= 0 then
      -- Reverse StarPounds overrides.
      if baseItem.parameters.starpounds_effectApplied then
        baseItem.parameters.foodValue = itemConfig.config.foodValue
        baseItem.parameters.effects = itemConfig.config.effects
        baseItem.parameters.starpounds_effectApplied = nil
      end
      -- Override parameters.
      for k, v in pairs(itemConfig.config.agedParameters or {}) do
        baseItem.parameters[k] = v
      end

      baseItem.parameters.aged = true
      baseItem.parameters.timeToAge = nil
    end
  end

  return baseItem
end

function getAgeTimeDescription(ageTime)
  local descList = root.assetJson("/items/starpounds_aging.config:ageTimeDescriptions")
  for i, desc in ipairs(descList) do
    if ageTime <= desc[1] then return desc[2] end
  end
  return descList[#descList]
end
