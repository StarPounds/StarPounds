function build(directory, config, parameters, level, seed)
  local skills = root.assetJson("/scripts/starpounds/modules/skills.config:skills")
  if skills[parameters.skill] then
    local skillName = parameters.skill
    local skillLevel = parameters.level or 1
    local skill = skills[skillName]
    config.inventoryIcon = string.format("/interface/scripted/starpounds/main/icons/skills/%s.png", skillName)
    config.largeImage = config.inventoryIcon
    config.description = skill.shortDescription
    config.category = skill.levels and string.format("Level: ^#%s;%s ^reset;/ ^#%s;%s", skill.colour, skillLevel, skill.colour, skill.levels) or "Ability"
    config.shortdescription = skill.pretty
    config.tooltipFields = {}
  end

  return config, parameters
end
