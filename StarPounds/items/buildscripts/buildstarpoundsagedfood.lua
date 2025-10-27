function build(directory, config, parameters, level, seed)
  local ageTime = config.timeToAge or root.assetJson("/items/starpounds_aging.config:baseTimeToAge")

  config.tooltipFields = config.tooltipFields or {}

  if not parameters.aged and not parameters.timeToAge then
    parameters.timeToAge = ageTime
  end

  config.tooltipFields.rotTimeLabel = getAgeTimeDescription((parameters.timeToAge or 0) / ageTime)

  return config, parameters
end

function getAgeTimeDescription(ageProgress)
  local descList = root.assetJson("/items/starpounds_aging.config:ageTimeDescriptions")
  for i, desc in ipairs(descList) do
    if ageProgress <= desc[1] then return desc[2] end
  end
  return descList[#descList]
end
