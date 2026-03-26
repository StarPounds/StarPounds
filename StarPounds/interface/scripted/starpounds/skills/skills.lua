require "/scripts/messageutil.lua"
require "/scripts/util.lua"

starPounds = getmetatable ''.starPounds

function init()
  local buttonIcon = string.format("%s.png", starPounds.isEnabled() and "enabled" or "disabled")
  enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
  skills = root.assetJson("/scripts/starpounds/modules/skills.config:skills")
  tabs = root.assetJson("/scripts/starpounds/modules/skills.config:tabs")
  traits = root.assetJson("/scripts/starpounds/modules/traits.config")

  availableTraitCache = {}
  for _, trait in ipairs(traits.selectableTraits) do
    availableTraitCache[trait] = true
  end

  activeTraitCache = {}
  traitTagCache = {}
  traitPoints = math.floor(starPounds.getStat("traitPoints"))

  tabNames = {}

  traitColours = {
    species = "",
    positive = "^green;",
    neutral = "^lightgray;",
    negative = "^red;",
    unique = "^yellow;"
  }

  if metagui.inputData.tabs then
    local filteredTabs = jarray()
    local filteredSkills = {}

    for _, tab in ipairs(tabs) do
      if contains(metagui.inputData.tabs, tab.id) then
        filteredTabs[#filteredTabs + 1] = tab
      end
    end

    for skillName, skill in pairs(skills) do
      if contains(metagui.inputData.tabs, skill.tab) then
        filteredSkills[skillName] = skill
      end
    end

    tabs = filteredTabs
    skills = filteredSkills
  end

  descriptionFunctions = {}

  isAdmin = admin()

  weightDecrease:setVisible(isAdmin)
  weightIncrease:setVisible(isAdmin)
  unlockAll:setVisible(isAdmin)
  barPadding:setVisible(not isAdmin)
  enableUpgrades = metagui.inputData.isObject or isAdmin
  selectedSkill = nil
  setProgress(starPounds.experience or starPounds.moduleFunc("data", "get", "experience"), starPounds.level or starPounds.moduleFunc("data", "get", "level"))
  populateSkillTree()
  populateTraitTab()
  resetInfoPanel()
  checkSkills()

  if starPounds.getSpeciesData().robotic then
    availableTraitIcon:setFile("traitAvailable_robotic.png")
    activeTraitIcon:setFile("traitActive_robotic.png")
    traitPointsImage:setImage("traitAvailable_robotic.png", "traitAvailable_robotic.png", "traitAvailable_robotic.png")
  end

  function traitSort_positive:onClick() updateAvailableTraits() end
  function traitSort_neutral:onClick() updateAvailableTraits() end
  function traitSort_negative:onClick() updateAvailableTraits() end
  function traitSort_unique:onClick() updateAvailableTraits() end
end

function update()
  -- Pane title and icon don't update properly in init() >:(
  if not titleFix then
    titleFix = true

    if metagui.inputData.title then
      metagui.setTitle(metagui.inputData.title)
      metagui.queueFrameRedraw()
    end
    if metagui.inputData.iconSuffix then
      metagui.setIcon(string.format("icon%s.png", metagui.inputData.iconSuffix or ""))
      metagui.queueFrameRedraw()
    end
    if currentTab.id ~= "traitSelection" then
      _ENV[currentTab.id.."_skillTree"]:scrollTo(currentTab.offset)
    end
  end

  if isAdmin ~= admin() then
    isAdmin = admin()
    enableUpgrades = metagui.inputData.isObject or isAdmin
    weightDecrease:setVisible(isAdmin)
    weightIncrease:setVisible(isAdmin)
    unlockAll:setVisible(isAdmin)
    barPadding:setVisible(not isAdmin)

    checkSkills()
    if selectedSkill then
      _ENV[string.format("%sSkill", selectedSkill.name)].onClick()
    end

    updateTraitInfo()
  end

  if experience ~= starPounds.experience or level ~= starPounds.level then
    setProgress(starPounds.experience, starPounds.level)

    if level ~= starPounds.level then
      checkSkills()
      if selectedSkill then
        _ENV[string.format("%sSkill", selectedSkill.name)].onClick()
      end

      updateTraitInfo()
    end
  end

  -- Check promises.
  promises:update()
  level = starPounds.level
  experience = starPounds.experience
end

function uninit()
end

function enable:onClick()
  local buttonIcon = string.format("%s.png", starPounds.toggleEnable() and "enabled" or "disabled")
  enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
end

function reset:onClick()
  local confirmLayout = sb.jsonMerge(root.assetJson("/interface/confirmation/resetstarpoundsconfirmation.config"), {
    title = metagui.inputData.title or "Skills",
    icon = string.format("/interface/scripted/starpounds/skills/icon%s.png", metagui.inputData.iconSuffix or ""),
    images = {
      portrait = world.entityPortrait(player.id(), "full")
    }
  })
  promises:add(player.confirm(confirmLayout), function(response)
    if response then
      world.sendEntityMessage(player.id(), "starPounds.reset")
      -- Rather just force close the pane than add spaghetti to reset everything.
      pane.dismiss()
    end
  end)
end

function unlockAll:onClick()
  for skillName, skill in pairs(skills) do
    if not (skill.internal or skill.hidden) then
      starPounds.moduleFunc("skills", "forceUnlock", skillName, skill.levels or 1)
    end
  end
  checkSkills()
end

function populateSkillTree()
  for _, tab in ipairs(tabs) do
    tab.title = " "
    tab.icon = string.format("icons/tabs/%s.png", tab.id)
    tab.contents = copy(tabField.data.tabTemplate)
    tab.contents[1].children[1].id = tab.id.."_skillTree"
    tab.contents[1].children[1].children[3].id = tab.id.."_skillCanvas"
    tab.contents[1].children[1].children[4].id = tab.id.."_skillWidgets"

    local newTab = tabField:newTab(tab)
    newTab.pretty = tab.pretty
    newTab.description = tab.description
    newTab.offset = tab.offset

    if not currentTab then
      currentTab = newTab
    end
  end

  for _, tab in ipairs(tabs) do
    _ENV[tab.id.."_skillCanvasBind"] = widget.bindCanvas(_ENV[tab.id.."_skillCanvas"].backingWidget)
    tabNames[tab.id] = tab.pretty
  end

  currentTab:select()

  local offset = {240, 160}
  local iconOffset = {-24, -24}

  local function adjustLinePosition(pos)
    return vec2.add(vec2.add({0, 320}, {24, -20}), vec2.mul(pos, {1, -1}))
  end

  -- First loop just edits all the positions values beforehand, and adds default data
  for skillName, skill in pairs(skills) do
    if not skill.internal then
      skill.position = vec2.add(vec2.add(vec2.mul(skill.position, 24), offset), iconOffset)
      skill.name = skillName
      skill.levels = skill.levels or 1
    end
  end

  for skillName, skill in pairs(skills) do
    if not skill.internal then
      local lineColour1 = {152, 133, 99, 255}
      local lineColour2 = {165, 147, 122, 255}

      if skill.connect then
        if skill.connect[2] then
          lineColour1 = skill.connect[2][1]
          lineColour2 = skill.connect[2][2]
        end
        for _, skillName in pairs(skill.connect[1]) do
          _ENV[skill.tab.."_skillCanvasBind"]:drawLine(adjustLinePosition(skill.position), adjustLinePosition(skills[skillName].position), lineColour1, 5)
          _ENV[skill.tab.."_skillCanvasBind"]:drawLine(adjustLinePosition(skill.position), adjustLinePosition(skills[skillName].position), lineColour2, 3)
        end
      end
      _ENV[skill.tab.."_skillWidgets"]:addChild(makeSkillWidget(skill))
      -- Make the button callback
      _ENV[string.format("%sSkill", skill.name)].onClick = function() selectSkill(skill) end
      _ENV[string.format("%sSkill_locked", skill.name)].onClick = function() widget.playSound("/sfx/interface/clickon_error.ogg") end
    end
  end
end

function buildTraitTab()
  traitSelection = tabField:newTab(tabField.data.traitTab)
  traitSelection.pretty = "Traits"
  traitSelection.description = "This menu allows you to modify traits!\n\nTraits can affect stats, unlocked skills, and more! \n\nYou begin with limited ^#ccbbff;Trait Points^reset;, but can earn more through progression or selecting negative traits.\nChoose wisely!"

  updateTraitInfo()

  function traitSelect:onClick()
    -- Make sure we have enough trait points (or we're admin).
    local experienceCost = traitExperienceCost()
    local hasExperience = starPounds.level >= experienceCost
    local canSelect = hasExperience and enableUpgrades and (isAdmin or (traitPoints >= 0)) and hasEditedTraits()
    if not canSelect then
      widget.playSound("/sfx/interface/clickon_error.ogg")
      return
    end
    -- Remove any traits not in the active list.
    for trait in pairs(starPounds.moduleFunc("traits", "get")) do
      if not activeTraitCache[trait] then
        starPounds.moduleFunc("traits", "remove", trait)
      end
    end
    -- Add any traits we don't have from the active list.
    for trait in pairs(activeTraitCache) do
      if not starPounds.moduleFunc("traits", "has", trait) then
        starPounds.moduleFunc("traits", "add", trait, true)
      end
    end

    starPounds.moduleFunc("experience", "removeLevel", experienceCost)

    updateAvailableTraits()
    updateActiveTraits()
    updateTraitInfo()

    widget.playSound("/sfx/interface/crafting_medical.ogg")
  end

  function traitReset:onClick()
    if not hasEditedTraits() then
      widget.playSound("/sfx/interface/clickon_error.ogg")
      return
    end

    availableTraitCache = {}
    for _, trait in ipairs(traits.selectableTraits) do
      availableTraitCache[trait] = true
    end

    activeTraitCache = {}
    traitTagCache = {}
    traitPoints = math.floor(starPounds.getStat("traitPoints"))

    for trait in pairs(starPounds.moduleFunc("traits", "get")) do
      selectTrait(trait, false)
    end

    updateAvailableTraits()
    updateActiveTraits()
    updateTraitInfo()
  end

  if not currentTab then
    currentTab = traitSelection
  end
end

function populateTraitTab()
  buildTraitTab()
  updateAvailableTraits()
  updateActiveTraits()
  speciesTrait:addChild(buildSpeciesTraitItem())

  for trait in pairs(starPounds.moduleFunc("traits", "get")) do
    selectTrait(trait, false)
  end
end

function updateAvailableTraits()
  availableTraits:clearChildren()

  local sortBy = {}

  if traitSort_positive.checked then sortBy[#sortBy + 1] = "positive" end
  if traitSort_neutral.checked then sortBy[#sortBy + 1] = "neutral" end
  if traitSort_negative.checked then sortBy[#sortBy + 1] = "negative" end
  if traitSort_unique.checked then sortBy[#sortBy + 1] = "unique" end

  for _, trait in ipairs(traits.selectableTraits) do
    local hasTag = false

    for _, tag in ipairs(traits.traits[trait].tags or {}) do
      if traitTagCache[tag] then hasTag = true break end
    end

    if availableTraitCache[trait] and not hasTag then
      local traitConfig = sb.jsonMerge(traits.traits.default, traits.traits[trait])
      if #sortBy == 0 or contains(sortBy, traitConfig.type or "") then
        availableTraits:addChild(buildTraitItem(trait, false))
        _ENV[string.format("%sTraitButton_%s", trait, "available")].onClick = function() selectTrait(trait, false) end
      end
    end
  end
end

function updateActiveTraits()
  activeTraits:clearChildren()
  local newList = {}
  for _, trait in ipairs(traits.selectableTraits) do
    if activeTraitCache[trait] then
      newList[#newList + 1] = trait
    end
  end
  for _, trait in ipairs(newList) do
    activeTraits:addChild(buildTraitItem(trait, true))
    _ENV[string.format("%sTraitButton_%s", trait, "active")].onClick = function() selectTrait(trait, true) end
  end
end

function buildTraitItem(trait, active)
  local panel = active and "active" or "available"
  local traitConfig = traits.traits[trait]
  local points = (traitConfig.points or 0) * (active and -1 or 1)
  local pointColour = points > 0 and (traitColours.positive .. "+") or (points < 0 and traitColours.negative or "")

  local statString = generateStatString(traitConfig.stats)
  local effectString = ""
  local skillString = ""

  if traitConfig.effects then
    effectString = ""
    for _, effect in ipairs(traitConfig.effects) do
      local effectName = starPounds.moduleFunc("effects", "getConfig", effect).pretty
      effectString = string.format("%s\n^green;+ ^lightgray;%s", effectString, effectName)
    end
  end

  if traitConfig.skills then
    skillString = string.format("%s^green;Unlocks skill%s:", (statString..effectString) ~= "" and "\n\n" or "", #traitConfig.skills > 1 and "s" or "")
    for _, skill in ipairs(traitConfig.skills) do
      local skillName = skill[1]
      local skillLevel = skill[2]
      local skill = skills[skillName]
      local levelString = ""
      if skill.levels and skill.levels > 1 then
        levelString = string.format(" (%s)", skillLevel)
      end
      -- Skill name greyed out if we already have it.
      local colour = string.format("^#%s;", skill.colour) or "^lightgray;"
      local prefix = "^green; +"
      -- If we have the trait but it didn't unlock the skill, gray out the skill name.
      if starPounds.moduleFunc("traits", "has", trait) and not starPounds.moduleFunc("traits", "unlockedSkills", trait)[skillName] then
        prefix = "^darkgray; +"
        colour = "^darkgray;"
      end
      -- If we have the skill but not the trait, gray out the skill name.
      if starPounds.moduleFunc("skills", "has", skillName, skillLevel) and not starPounds.moduleFunc("traits", "has", trait) then
        prefix = "^darkgray; +"
        colour = "^darkgray;"
      end

      skillString = string.format("%s\n%s %s%s^gray;%s", skillString, prefix, colour, skill.pretty, levelString)
    end
  end

  local buttonToolTip = statString..effectString..skillString

  -- "Changed" traits buttons are red coloured until locked in.
  local pending = false
  if active and not starPounds.moduleFunc("traits", "has", trait) then
    pending = true
  end

  if not active and starPounds.moduleFunc("traits", "has", trait) then
    pending = true
  end

  -- Add extra context to the tooltip showing the XP cost increase if it unlocked skills.
  if starPounds.moduleFunc("traits", "has", trait) then
    local cost = starPounds.moduleFunc("traits", "removeCost", trait)
    if cost > 0 then
      buttonToolTip = string.format("%s\n\n^gray;This trait unlocked skills.\nRemoving it costs ^#b8eb00;%s XP^gray;, \nbut the skills are kept.", buttonToolTip, cost)
    end
  end

  local image = string.format("trait%s%s.png", active and "Remove" or "Add", pending and "Pending" or "")

  local buttonWidget = {id = string.format("%sTraitButton_%s", trait, panel), type = "iconButton", position = {105, 3}, toolTip = buttonToolTip,
    image = image,
    hoverImage = image,
    pressImage = image.."?border=2;00000000;00000000?crop=2;3;13;15"
  }

  local traitImage = "traitActive.png"
  if starPounds.getSpeciesData().robotic then
    traitImage = "traitActive_robotic.png"
  end

  return {
    id = string.format("%sTrait_%s", trait, panel), type = "panel", style = "concave", expandMode = {1, 0}, children = {
      {type = "layout", mode = "manual", size = {118, 18}, children = {
        {type = "image", position = {1, 1}, noAutoCrop = true, file = string.format("icons/traits/%s.png", trait)},
        {type = "label", position = {20, 5}, size = {98, 8}, fontSize = 7, align = "left", text = (traitColours[traitConfig.type] or "")..traitConfig.pretty},
        buttonWidget,
        {type = "label", position = {96, 5}, size = {8, 8}, fontSize = 7, align = "right", text = pointColour .. points}
      }}
    }
  }
end

function buildSpeciesTraitItem()
  local species = starPounds.getSpecies()
  local speciesTraits = starPounds.moduleFunc("traits", "getSpeciesTraitList")
  local traitConfig = sb.jsonMerge(traits.traits.default, traits.traits[speciesTrait])

  local buttonTooltip = ""

  for i, trait in ipairs(starPounds.moduleFunc("traits", "speciesTraits")) do
    local traitConfig = speciesTraits[trait]
    if traitConfig then
      local spacerString = "^#00000000;-^reset; "
      local statString = generateStatString(traitConfig.stats):gsub("\n", "\n"..spacerString)
      local effectString = ""
      local skillString = ""

      if traitConfig.effects then
        effectString = ""
        for _, effect in ipairs(traitConfig.effects) do
          local effectName = starPounds.moduleFunc("effects", "getConfig", effect).pretty
          effectString = string.format("%s\n%s^green;+ ^lightgray;%s", effectString, spacerString, effectName)
        end
      end

      if traitConfig.skills then
        skillString = string.format("\n%s^green;Unlocks skill%s:", spacerString, #traitConfig.skills > 1 and "s" or "")
        for _, skill in ipairs(traitConfig.skills) do
          local skillName = skill[1]
          local skillLevel = skill[2]
          local skill = skills[skillName]
          local levelString = ""
          if skill.levels and skill.levels > 1 then
            levelString = string.format(" (%s)", skillLevel)
          end

          skillString = string.format("%s\n%s^green;+ %s%s^gray;%s", skillString, spacerString, string.format("^#%s;", skill.colour) or "^lightgray;", skill.pretty, levelString)
        end
      end

      buttonTooltip = string.format("%s^reset;%s^gray;- %s^reset;%s%s%s", buttonTooltip, (i > 1) and "\n" or "", traitConfig.pretty, statString, effectString, skillString)
    end
  end

  local buttonWidget = {type = "iconButton", position = {105, 3}, toolTip = buttonTooltip,
    image = "statInfo.png",
    hoverImage = "statInfo.png",
    pressImage = "statInfo.png"
  }

  local traitImage = "traitActive.png"
  if starPounds.getSpeciesData().robotic then
    traitImage = "traitActive_robotic.png"
  end

  return {
    type = "panel", style = "concave", expandMode = {1, 0}, children = {
      {type = "layout", mode = "manual", size = {118, 18}, children = {
        {type = "image", position = {1, 1}, noAutoCrop = true, file = traitImage},
        {type = "label", position = {20, 5}, size = {98, 8}, fontSize = 7, align = "left", text = traitColours.species..starPounds.getSpeciesData().pretty},
        buttonWidget
      }}
    }
  }
end

function selectTrait(trait, active)
  availableTraitCache[trait] = active and true or nil
  activeTraitCache[trait] = not active and true or nil

  local points = traits.traits[trait].points
  if active then
    points = points * -1
  end
  traitPoints = traitPoints + points

  for _, tag in ipairs(traits.traits[trait].tags or {}) do
    traitTagCache[tag] = not active and true or nil
  end

  updateAvailableTraits()
  updateActiveTraits()
  updateTraitInfo()
end

function hasEditedTraits()
  local edited = false
  for trait in pairs(activeTraitCache) do
    if not starPounds.moduleFunc("traits", "has", trait) then
      edited = true
      break
    end
  end
  for trait in pairs(availableTraitCache) do
    if starPounds.moduleFunc("traits", "has", trait) then
      edited = true
      break
    end
  end

  return edited
end

function traitExperienceCost()
  if isAdmin then return 0 end

  local cost = starPounds.getStat("traitExperienceCost")
  -- Cycle through non-active traits.
  for trait in pairs(availableTraitCache) do
    -- If we removed them, check if they've unlocked a skill and add that to the cost.
    if starPounds.moduleFunc("traits", "has", trait) then
      cost = cost + starPounds.moduleFunc("traits", "removeCost", trait)
    end
  end

  return math.floor(cost)
end

function updateTraitInfo()
  local colour = traitPoints > 0 and traitColours.positive or (traitPoints < 0 and traitColours.negative or "")
  traitPointsLabel:setText(string.format("%s%s", colour, traitPoints))

  local edited = hasEditedTraits()
  local experienceCost = traitExperienceCost()
  local hasExperience = starPounds.level >= experienceCost
  local hasPoints = isAdmin or (traitPoints >= 0)
  local canSelect = enableUpgrades and hasPoints and hasExperience and edited

  traitSelect:setImage(
    string.format("traitSelect%s.png", canSelect and "" or "Disabled"),
    string.format("traitSelect%s.png", canSelect and "" or "Disabled"),
    string.format("traitSelect%s.png?border=1;00000000;00000000?crop=1;2;23;18", canSelect and "" or "Disabled")
  )

  traitReset:setImage(
    string.format("traitReset%s.png", edited and "" or "Disabled"),
    string.format("traitReset%s.png", edited and "" or "Disabled"),
    string.format("traitReset%s.png?border=1;00000000;00000000?crop=1;2;17;18", edited and "" or "Disabled")
  )

  local colour = edited and (hasExperience and "^green;" or "^red;") or "^darkgray;"
  traitExperienceLabel:setText(string.format("%s%s XP", colour, edited and experienceCost or "-"))

  local colour = canSelect and "^green;" or "^red;"
  traitSelect.toolTip = string.format("%sModification %s^reset;", colour, canSelect and "enabled" or "disabled")

  if canSelect then
    traitSelect.toolTip = string.format(traitSelect.toolTip.."\n^gray;Requires ^#b8eb00;%s XP^reset;", experienceCost)
  else
    -- Only show unmodified message by itself.
    if not edited then
      traitSelect.toolTip = traitSelect.toolTip.."\n^gray;No traits modified."
    else
      -- List anything missing.
      if not enableUpgrades then
        local objectName = root.itemConfig("starpoundsinfusiontable").config.shortdescription
        local useAn = string.find(objectName:gsub("%^.-;", ""):sub(1, 1), "[AEIOUaeiou]")
        traitSelect.toolTip = string.format(traitSelect.toolTip.."\n^gray;Requires %s %s^reset;", useAn and "an" or "a", objectName)
      end
      if not hasPoints then
        traitSelect.toolTip = string.format(traitSelect.toolTip.."\n^gray;Requires ^#ccbbff;%s Trait Point%s^reset;", traitPoints * -1, (traitPoints * -1 > 1) and "s" or "")
      end
      if not hasExperience then
        traitSelect.toolTip = string.format(traitSelect.toolTip.."\n^gray;Requires ^#b8eb00;%s XP^reset;", experienceCost)
      end
    end
  end
end

function generateStatString(stats)
  local stringCache = jarray()
  local statString = ""

  if stats then
    for _, stat in ipairs(stats) do
      local statString = ""
      local modStat = starPounds.moduleFunc("stats", "getRaw", stat[1])
      local op = stat[2]
      local amount = stat[3]
      if op == "mult" then
        local negative = (modStat.negative and amount > 1) or (not modStat.negative and amount < 1)
        statString = string.format("%sx%s", negative and "^red;" or "^green;", string.format("%.2f", (modStat.invertDescriptor and (1/amount) or amount)):gsub("%.?0+$", ""))
      else
        local negative = (modStat.negative and amount > 0) or (not modStat.negative and amount < 0)
        if op == "sub" then negative = not negative end
        statString = string.format("%s%s%s", negative and "^red;" or "^green;", ((not modStat.invertDescriptor and op == "add") or (modStat.invertDescriptor and op == "sub")) and "+" or "-", string.format("%.2f", modStat.flat and amount or (amount * 100)):gsub("%.?0+$", "")..(modStat.flat and "" or "%"))
      end
      local statColour = modStat.colour and ("^#"..modStat.colour..";") or ""
      stringCache[#stringCache + 1] = string.format("%s %s%s", statString, statColour, modStat.pretty)
    end
  end

  for _, str in ipairs(stringCache) do
    statString = statString.."\n"..str
  end

  return statString
end

function makeSkillWidget(skill)
  local toolTip = string.format("%s%s", skill.pretty:gsub("%^.-;", ""), skill.shortDescription and "\n^gray;"..skill.shortDescription or "")
  local skillWidget = {
    type = "layout", position = skill.position, size = {48, 48}, mode = "manual", children = {
      {id = string.format("%sSkill_back", skill.name), type = "image", noAutoCrop = true, position = {12, 8}, file = string.format("back.png?multiply=%s", skill.colour)},
      {id = string.format("%sSkill", skill.name), toolTip = toolTip, position = {16, 12}, type = "iconButton", image = string.format("icons/skills/%s.png", skill.icon or skill.name), hoverImage = string.format("icons/skills/%s.png", skill.icon or skill.name), pressImage = string.format("icons/skills/%s.png", skill.icon or skill.name).."?border=1;00000000;00000000?crop=1;2;17;18"},
      {id = string.format("%sSkill_locked", skill.name), toolTip = toolTip, visible = false, type = "iconButton", position = {12, 8}, image = "locked.png", hoverImage = "locked.png", pressImage = "locked.png"},
      {id = string.format("%sSkill_check", skill.name), visible = false, type = "image", noAutoCrop = true, position = {28, 20}, file = "check.png"}
    }
  }
  -- Under skill level for multilevel skills.
  if skill.levels > 1 then
    local level = starPounds.moduleFunc("skills", "unlockedLevel", skill.name)
    local currentLevel = starPounds.moduleFunc("skills", "level", skill.name)
    if currentLevel < level then
      level = string.format("^#ffaaaa;%s^reset;", currentLevel)
    end
    table.insert(skillWidget.children, {id = string.format("%sSkill_backLevel", skill.name), type = "image", position = {14, 29}, file = "backLevel.png"})
    table.insert(skillWidget.children, {id = string.format("%sSkill_backLevelText", skill.name), type = "label", position = {14, 32}, size = {20, 10}, fontSize = 5, align = "center", text = string.format("%s/%s", level, skill.levels)})
  end

  if skill.hidden then
    skillWidget.children[2] = {id = string.format("%sSkill", skill.name), position = {16, 12}, type = "iconButton", image = string.format("icons/skills/%s.png", skill.hiddenIcon), hoverImage = string.format("icons/skills/%s.png", skill.hiddenIcon), pressImage = string.format("icons/skills/%s.png", skill.hiddenIcon).."?border=1;00000000;00000000?crop=1;2;17;18"}
    skillWidget.children[4].file = "check.png?multiply=00000000"
  elseif isAdmin and starPounds.hasOption("showDebug") then
    skillWidget.children[2].toolTip = skillWidget.children[2].toolTip..string.format("\n\n^#665599;Skill Id: ^gray;%s\n^#665599;Total Cost: ^gray;%s XP", skill.name, starPounds.moduleFunc("skills", "upgradeCost", skill.name, 0, skill.levels))
    skillWidget.children[4].toolTip = skillWidget.children[2].toolTip
  end

  return skillWidget
end

function selectSkill(skill)
  unlockPanel:setVisible(true)
  infoPanel:setVisible(false)
  local canIncrease = false
  local canDecrease = false
  local canUpgrade = false
  local useToggle = false
  local skillMaxed = false
  local experienceCost = 0
  descriptionWidget:clearChildren()
  if selectedSkill and (not skill or selectedSkill.name ~= skill.name) then
    _ENV[string.format("%sSkill_back", selectedSkill.name)]:setFile(string.format("back.png?multiply=%s", selectedSkill.colour))
    _ENV[string.format("%sSkill_back", selectedSkill.name)]:queueRedraw()
    _ENV[string.format("%sSkill", selectedSkill.name)]:setImage(
      string.format("icons/skills/%s.png", selectedSkill.icon or selectedSkill.name),
      string.format("icons/skills/%s.png", selectedSkill.icon or selectedSkill.name),
      string.format("icons/skills/%s.png", selectedSkill.icon or selectedSkill.name)
    )
    if selectedSkill.hidden then
      _ENV[string.format("%sSkill", selectedSkill.name)]:setImage(
        string.format("icons/skills/%s.png", selectedSkill.hiddenIcon),
        string.format("icons/skills/%s.png", selectedSkill.hiddenIcon),
        string.format("icons/skills/%s.png", selectedSkill.hiddenIcon)
      )
    end
  end
  if skill then
    _ENV[string.format("%sSkill_back", skill.name)]:setFile(string.format("back.png?multiply=%s?brightness=50?saturation=-15", skill.colour))
    _ENV[string.format("%sSkill_back", skill.name)]:queueRedraw()
    _ENV[string.format("%sSkill", skill.name)]:setImage(
      string.format("icons/skills/%s.png?border=1;ffffffaa;00000000", skill.icon or skill.name),
      string.format("icons/skills/%s.png?border=1;ffffffaa;00000000", skill.icon or skill.name),
      string.format("icons/skills/%s.png?border=1;ffffffaa;00000000", skill.icon or skill.name)
    )

    descriptionTitle:setText("^shadow;"..skill.pretty)
    descriptionIcon:setFile(string.format("icons/skills/%s.png", skill.icon or skill.name))
    descriptionIcon:queueRedraw()
    descriptionText:setText(skill.description:gsub("<activationSize>", starPounds.sizes[starPounds.moduleFunc("size", "activationSize")].size:gsub("^%l", string.upper)))

    local currentLevel = starPounds.moduleFunc("skills", "level", skill.name)
    local unlockedLevel = starPounds.moduleFunc("skills", "unlockedLevel", skill.name)
    local skillItems = getSkillItems(skill)
    local hasItems = hasSkillItems(skill)
    -- Clear the slots.
    local slotCount = math.min(#skillItems, 5)
    unlockItems.columns = slotCount
    unlockItems:setNumSlots(slotCount)
    -- Set the slots, and check player items.
    for i, item in ipairs(skillItems) do
      unlockItems.children[i].hideRarity = true
      if i <= slotCount then
        unlockItems:setItem(i, {name = item[1], count = item[2], parameters = {}})
      end
    end

    itemPanel:setVisible(slotCount > 0)

    if skill.type == "addStat" or skill.type == "subtractStat" then
      infoPanel:setVisible(true)
      local stat = starPounds.moduleFunc("stats", "getRaw", skill.stat)
      local baseAmount = stat.base
      local textColour = stat.colour or skill.colour

      local nextAmount = baseAmount + skill.amount * (skill.type == "addStat" and 1 or -1)
      local nextIncrease = math.floor(0.5 + ((stat.flat and 1 or 100) * (nextAmount - baseAmount)) * 100)/100
      local nextAmount = (stat.invertDescriptor and (nextIncrease * -1) or nextIncrease)
      local nextString = currentLevel == skill.levels and "" or string.format("%s%.2f", nextAmount > 0 and "+" or "", nextAmount):gsub("%.?0+$", "")..(stat.flat and "" or "%")

      local bonus = starPounds.moduleFunc("stats", "skillBonus", skill.stat)
      local totalAmount = (bonus ~= 0 and (stat.invertDescriptor and (bonus * -1) or bonus) or 0) + stat.base
      local totalIncrease = math.floor(0.5 + ((stat.flat and 1 or 100) * totalAmount) * 100)/100
      local amount = totalIncrease
      local amountString = string.format("%.2f", amount):gsub("%.?0+$", "")..(stat.flat and "" or "%")

      if stat.normalizeBase then
        nextAmount = baseAmount + skill.amount * (skill.type == "addStat" and 1 or -1)
        nextIncrease = math.floor(0.5 + ((stat.flat and 1 or 100) * (nextAmount - baseAmount)/(baseAmount > 0 and baseAmount or 1)) * 100)/100
        nextAmount = (stat.invertDescriptor and (nextIncrease * -1) or nextIncrease)
        nextString = currentLevel == skill.levels and "" or string.format("%s%.2f", nextAmount > 0 and "+" or "", nextAmount):gsub("%.?0+$", "")..(stat.flat and "" or "%")


        totalIncrease = math.floor(0.5 + ((stat.flat and 1 or 100) * totalAmount/(baseAmount > 0 and baseAmount or 1)) * 100)/100
        amount = totalIncrease ~= 0 and (stat.invertDescriptor and (totalIncrease * -1) or totalIncrease) or 0
        amountString = string.format("%.2f", amount):gsub("%.?0+$", "")..(stat.flat and "" or "%")
      end

      local function tchelper(first, rest)
         return first:upper()..rest:lower()
      end

      infoCurrent:setText(
        string.format("^#%s;%s^reset; \n^clear;%s^reset; %s ^gray;%s", textColour, stat.pretty:gsub("(%a)([%w_']*)", tchelper), nextString, amountString, nextString)
      )
      statInfo.toolTip = stat.description
      if stat.scaling then
        statInfo.toolTip = statInfo.toolTip.."\n^gray,set;This stat scales until ^#00ebce;"..starPounds.sizes[starPounds.moduleFunc("size", "scalingSize")].size:gsub("^%l", string.upper).."^reset;."
      end
    end

    experienceCost = isAdmin and 0 or starPounds.moduleFunc("skills", "upgradeCost", skill.name, unlockedLevel, unlockedLevel + 1)
    canDecrease = currentLevel > 0
    canIncrease = currentLevel < unlockedLevel
    useToggle = skill.levels == 1
    skillMaxed = unlockedLevel == skill.levels
    canUpgrade = (isAdmin or ((starPounds.level >= experienceCost) and hasItems)) and not skillMaxed
    unlockText:setText(useToggle and (currentLevel > 0 and "On" or "Off") or string.format("%s/%s", currentLevel, unlockedLevel))

    unlockExperience:setText(string.format("^%s;%s XP", skillMaxed and "darkgray" or ((enableUpgrades and canUpgrade) and "green" or "red"), (skillMaxed or not enableUpgrades) and "-" or math.floor(experienceCost)))

    unlockToggle:setVisible(useToggle)
    unlockIncrease:setVisible(not useToggle)
    unlockDecrease:setVisible(not useToggle)

    unlockButton.toolTip = nil
    if not (enableUpgrades and canUpgrade) then
      unlockButton.toolTip = "^red;Upgrading disabled"
    end

    if skillMaxed then
      unlockButton.toolTip = string.format(unlockButton.toolTip.."\n^gray;Skill fully upgraded!"):gsub("red", "green")
    elseif skill.tab and not enableUpgrades then
      local tab
      local objectConfig
      for _, tab in ipairs(tabs) do
        if skill.tab == tab.id then
          objectConfig = root.itemConfig(tab.defaultObject)
          break
        end
      end
      if objectConfig then
        local objectName = objectConfig.config.shortdescription
        local useAn = string.find(objectName:gsub("%^.-;", ""):sub(1, 1), "[AEIOUaeiou]")
        unlockButton.toolTip = string.format(unlockButton.toolTip.."\n^gray;Requires %s %s^reset;", useAn and "an" or "a", objectName)
      end
    elseif not canUpgrade then
      unlockButton.toolTip = unlockButton.toolTip.."\n^gray;Requires"
      if starPounds.level < experienceCost then
        unlockButton.toolTip = string.format(unlockButton.toolTip.." ^#b8eb00;%s XP^reset;", math.floor(experienceCost))
      end
      if not hasItems then
        for _, item in ipairs(skillItems) do
          local itemCount = player.hasCountOfItem(item[1])
          local itemName = root.itemConfig(item[1]).config.shortdescription
          if root.itemType(item[1]) == "currency" then
            itemCount = player.currency(item[1])
          end
          local hasItem = itemCount >= item[2]
          unlockButton.toolTip = unlockButton.toolTip..string.format("\n^gray;%s ^%s;%s/%s", itemName, hasItem and "green" or "red", itemCount, item[2])
        end
      end
    end

    unlockToggle:setImage(
      string.format("unlockToggle.png:%s.%s", (canIncrease or not skillMaxed) and "off" or "on", skillMaxed and "enabled" or "disabled"),
      string.format("unlockToggle.png:%s.%s", (canIncrease or not skillMaxed) and "off" or "on", skillMaxed and "enabled" or "disabled"),
      string.format("unlockToggle.png:%s.%s?border=1;00000000;00000000?crop=1;2;13;27", (canIncrease or not skillMaxed) and "off" or "on", skillMaxed and "enabled" or "disabled")
    )
    unlockButton:setImage(
      string.format("unlock%s.png", enableUpgrades and (canUpgrade and "" or "Disabled") or "Locked"),
      string.format("unlock%s.png", enableUpgrades and (canUpgrade and "" or "Disabled") or "Locked"),
      string.format("unlock%s.png?border=1;00000000;00000000?crop=1;2;25;27", enableUpgrades and (canUpgrade and "" or "Disabled") or "Locked")
    )
    unlockIncrease:setImage(
      string.format("unlockIncrease%s.png", canIncrease and "" or "Disabled"),
      string.format("unlockIncrease%s.png", canIncrease and "" or "Disabled"),
      string.format("unlockIncrease%s.png?border=1;00000000;00000000?crop=1;2;13;15", canIncrease and "" or "Disabled")
    )
    unlockDecrease:setImage(
      string.format("unlockDecrease%s.png", canDecrease and "" or "Disabled"),
      string.format("unlockDecrease%s.png", canDecrease and "" or "Disabled"),
      string.format("unlockDecrease%s.png?border=1;00000000;00000000?crop=1;2;13;15", canDecrease and "" or "Disabled")
    )
    if skill.widget and (skill.forceWidget or unlockedLevel > 0) then
      require(string.format("/interface/scripted/starpounds/skills/descriptionWidgets/%s.lua", skill.widget.id))
      descriptionFunctions[skill.widget.id](descriptionWidget:addChild(skill.widget))
    end
  end

  selectedSkill = skill
end

function checkSkills()
  for skillName, skill in pairs(skills) do
    if not skill.internal then
      _ENV[string.format("%sSkill_locked", skill.name)]:setVisible(false)
      -- Under skill level for multilevel skills.
      if skill.levels > 1 then
        local level = starPounds.moduleFunc("skills", "unlockedLevel", skill.name)
        local currentLevel = starPounds.moduleFunc("skills", "level", skill.name)
        if currentLevel < level then
          level = string.format("^#ffaaaa;%s^reset;", currentLevel)
        end
        _ENV[string.format("%sSkill_backLevelText", skill.name)]:setText(string.format("%s/%s", level, skill.levels))
      end
      if skill.requirements then
        local requirements = "Requires"
        local hasRequirements = true

        if not enableUpgrades then
          local tab
          local objectConfig
          for _, tab in ipairs(tabs) do
            if skill.tab == tab.id then
              objectConfig = root.itemConfig(tab.defaultObject)
              break
            end
          end

          if objectConfig then
            local objectName = objectConfig.config.shortdescription
            requirements = string.format(requirements.."\n^gray;Object: %s^reset;", objectName)
          end
        end

        for requirement, requirementLevel in pairs(skill.requirements) do
          local hasRequirement = starPounds.moduleFunc("skills", "unlockedLevel", requirement) >= requirementLevel
          local name = skills[requirement].pretty:gsub("%^.-;", "")
          local requirementTab = ""

          if skills[requirement].tab ~= skill.tab and not hasRequirement then
            requirementTab = " ^darkgray;- "..tabNames[skills[requirement].tab].."^reset;"
          end

          if starPounds.moduleFunc("skills", "unlockedLevel", requirement) == 0 then
            for requirement, requirementLevel in pairs(skills[requirement].requirements or {}) do
              if not (starPounds.moduleFunc("skills", "unlockedLevel", requirement) >= requirementLevel) then
                name = name:lower():gsub("[a-z]",
                  {a="", b="", c="", d="", e="", f="", g="", h="", i="", j="", k="", l="", m="", n="", o="", p="", q="", r="", s="", t="", u="", v="", w="", x="", y="", z=""}
                )
              end
            end
          end
          hasRequirements = hasRequirements and hasRequirement
          requirements = string.format("%s\n^%s;%s%s",
            requirements,
            hasRequirement and "green" or "red",
            name..((skills[requirement].levels or 1) > 1 and ": "..requirementLevel or ""),
            requirementTab
          )
        end

        if selectedSkill and selectedSkill.name == skill.name then
          if not (hasRequirements or isAdmin or starPounds.moduleFunc("skills", "has", skill.name)) then
            resetInfoPanel()
          end
        end
        _ENV[string.format("%sSkill_locked", skill.name)]:setVisible(not ((enableUpgrades and hasRequirements) or isAdmin or starPounds.moduleFunc("skills", "unlockedLevel", skill.name) > 0))
        _ENV[string.format("%sSkill_locked", skill.name)].toolTip = requirements
      end
      _ENV[string.format("%sSkill_check", skill.name)]:setVisible(starPounds.moduleFunc("skills", "unlockedLevel", skill.name) == skill.levels)
    end
  end
end

function tabField:onTabChanged(tab, previous)
  if currentTab then
    currentTab = tab
    resetInfoPanel()
    if currentTab.id ~= "traitSelection" then
      _ENV[currentTab.id.."_skillTree"]:scrollTo(currentTab.offset)
    end
  end
end

function resetInfoPanel()
  selectSkill()
  local icon = string.format("icons/tabs/%s.png", currentTab.id)
  infoPanel:setVisible(false)
  unlockPanel:setVisible(false)
  descriptionTitle:setText(currentTab.pretty)
  descriptionText:setText(currentTab.description)
  descriptionIcon:setFile(icon)
  descriptionIcon:queueRedraw()
end

function unlockButton:onClick()
  local unlockedLevel = starPounds.moduleFunc("skills", "unlockedLevel", selectedSkill.name)
  local experienceCost = starPounds.moduleFunc("skills", "upgradeCost", selectedSkill.name, unlockedLevel, unlockedLevel + 1)
  local canUpgrade = isAdmin or (hasSkillItems(selectedSkill) and starPounds.level >= experienceCost)
  selectSkill(selectedSkill)
  if starPounds.moduleFunc("skills", "unlockedLevel", selectedSkill.name) == selectedSkill.levels or not canUpgrade or not enableUpgrades then
    widget.playSound("/sfx/interface/clickon_error.ogg")
    return
  end
  if not isAdmin then
    for _, item in ipairs(getSkillItems(selectedSkill)) do
      if root.itemType(item[1]) == "currency" then
        player.consumeCurrency(item[1], item[2])
      else
        player.consumeItem({name = item[1], count = item[2]})
      end
    end
  end

  starPounds.moduleFunc("skills", "upgrade", selectedSkill.name)
  starPounds.moduleFunc("experience", "removeLevel", isAdmin and 0 or experienceCost)

  local level = starPounds.moduleFunc("skills", "unlockedLevel", selectedSkill.name)
  local currentLevel = starPounds.moduleFunc("skills", "level", selectedSkill.name)
  if currentLevel < level then
    level = string.format("^#ffaaaa;%s^reset;", currentLevel)
  end
  if selectedSkill.levels > 1 then
    _ENV[string.format("%sSkill_backLevelText", selectedSkill.name)]:setText(string.format("%s/%s", level, selectedSkill.levels))
  end
  checkSkills()
  selectSkill(selectedSkill)
  -- Refresh traits list to gray out skill names.
  updateAvailableTraits()
  updateActiveTraits()
  widget.playSound("/sfx/interface/crafting_medical.ogg")
end

function getSkillItems(skill)
  local unlockedLevel = starPounds.moduleFunc("skills", "unlockedLevel", skill.name)
  local nextLevel = math.min(unlockedLevel + 1, skill.levels)
  local skillItems = jarray()

  for _, requiredItems in ipairs(skill.upgradeItems or jarray()) do
    if nextLevel >= requiredItems[1] then
      skillItems = requiredItems[2]
    else
      break
    end
  end
  return skillItems
end

function hasSkillItems(skill)
  local skillItems = getSkillItems(skill)
  local hasItems = true
  -- Clear the slots.
  for i, item in ipairs(skillItems) do
    local itemCount = player.hasCountOfItem(item[1])
    if root.itemType(item[1]) == "currency" then
      itemCount = player.currency(item[1])
    end
    if itemCount < item[2] then
      hasItems = false
    end
  end
  return hasItems
end

function unlockIncrease:onClick()
  starPounds.moduleFunc("skills", "set", selectedSkill.name, metagui.checkShift() and starPounds.moduleFunc("skills", "unlockedLevel", selectedSkill.name) or (starPounds.moduleFunc("skills", "level", selectedSkill.name) + 1))
  local level = starPounds.moduleFunc("skills", "unlockedLevel", selectedSkill.name)
  local currentLevel = starPounds.moduleFunc("skills", "level", selectedSkill.name)
  if currentLevel < level then
    level = string.format("^#ffaaaa;%s^reset;", currentLevel)
  end

  selectSkill(selectedSkill)
  _ENV[string.format("%sSkill_backLevelText", selectedSkill.name)]:setText(string.format("%s/%s", level, selectedSkill.levels))
end

function unlockDecrease:onClick()
  starPounds.moduleFunc("skills", "set", selectedSkill.name, metagui.checkShift() and 0 or (starPounds.moduleFunc("skills", "level", selectedSkill.name) - 1))
  local level = starPounds.moduleFunc("skills", "unlockedLevel", selectedSkill.name)
  local currentLevel = starPounds.moduleFunc("skills", "level", selectedSkill.name)
  if currentLevel < level then
    level = string.format("^#ffaaaa;%s^reset;", currentLevel)
  end
  selectSkill(selectedSkill)
  _ENV[string.format("%sSkill_backLevelText", selectedSkill.name)]:setText(string.format("%s/%s", level, selectedSkill.levels))
end

function unlockToggle:onClick()
  if starPounds.moduleFunc("skills", "unlockedLevel", selectedSkill.name) > 0 then
    starPounds.moduleFunc("skills", "set", selectedSkill.name, (starPounds.moduleFunc("skills", "level", selectedSkill.name) == 0) and 1 or 0)
    selectSkill(selectedSkill)
  end
end

function statInfo:onClick()
  statInfoCount = (statInfoCount or 0) + 1
  if statInfoCount == 50 then
    player.radioMessage({important = true, unique = false, messageId = "BUT_WHY", text = "You know this isn't an actual button right? It doesn't do anything. It will never do anything. It's just the only easy way to get tooltips to work here."})
  elseif statInfoCount == 100 then
    player.radioMessage({important = true, unique = false, messageId = "BUT_WHY", text = "Since you decided you would click this 100 times you're probably expecting a reward, so have a single pixel. You're welcome."})
    player.giveItem("money")
  elseif statInfoCount == 250 then
    player.radioMessage({important = true, unique = false, messageId = "BUT_WHY", text = "Whatever." })
    player.giveItem("gracecupcake")
    widget.playSound("/sfx/objects/colonydeed_partyhorn.ogg", nil, 0.75)
  end
end

function setProgress(experience, level)
  local experienceConfig = starPounds.moduleFunc("experience", "config")
  local progress = experience/(experienceConfig.experienceAmount * (1 + level * experienceConfig.experienceIncrement))
  experienceText:setText(string.format("%s XP", level))
  experienceBar:setFile(string.format("bar.png?crop;0;0;%s;14", math.floor(70 * (progress or 0) + 0.5)))
  experienceBar:queueRedraw()
  experienceBar:queueGeometryUpdate()
  experienceLayout:queueRedraw()
  experienceLayout:queueGeometryUpdate()
end

function weightDecrease:onClick()
  local progress = (starPounds.weight - starPounds.currentSize.weight)/((starPounds.sizes[starPounds.currentSizeIndex + 1] and starPounds.sizes[starPounds.currentSizeIndex + 1].weight or starPounds.settings.maxWeight) - starPounds.currentSize.weight)
  local targetWeight = starPounds.sizes[math.max(starPounds.currentSizeIndex - 1, 1)].weight
  local targetWeight2 = starPounds.sizes[starPounds.currentSizeIndex].weight
  starPounds.moduleFunc("size", "setWeight", metagui.checkShift() and 0 or (targetWeight + (targetWeight2 - targetWeight) * progress))
end

function weightIncrease:onClick()
  local progress = math.max(0.01, (starPounds.weight - starPounds.currentSize.weight)/((starPounds.sizes[starPounds.currentSizeIndex + 1] and starPounds.sizes[starPounds.currentSizeIndex + 1].weight or starPounds.settings.maxWeight) - starPounds.currentSize.weight))
  local targetWeight = starPounds.sizes[starPounds.currentSizeIndex + 1] and starPounds.sizes[starPounds.currentSizeIndex + 1].weight or starPounds.settings.maxWeight
  local targetWeight2 = starPounds.sizes[starPounds.currentSizeIndex + 2] and starPounds.sizes[starPounds.currentSizeIndex + 2].weight or starPounds.settings.maxWeight
  starPounds.moduleFunc("size", "setWeight", metagui.checkShift() and starPounds.settings.maxWeight or (targetWeight + (targetWeight2 - targetWeight) * progress))
end

function admin()
  return (player.isAdmin() or starPounds.hasOption("admin")) or false
end
