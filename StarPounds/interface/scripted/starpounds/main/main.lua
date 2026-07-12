require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/starpounds_metaguiSliderFix.lua"

local starPounds = getmetatable ''.starPounds
--metagui.debugFlags.showLayoutBoxes = true
-- Button helper.
local function setButtonImage(widget, baseImage, cropData)
  widget:setImage(baseImage, baseImage, baseImage .. (cropData or ""))
end

-- Level string helper for skills.
local function formatSkillLevel(skillName)
  local skill = skills[skillName]
  local unlockedLevel = starPounds.moduleFunc("skills", "unlockedLevel", skillName)
  local currentLevel = starPounds.moduleFunc("skills", "level", skillName)

  local displayLevel = tostring(unlockedLevel)
  if currentLevel < unlockedLevel then
    displayLevel = string.format("^#ffaaaa;%s^reset;", currentLevel)
  end

  return string.format("%s/%s", displayLevel, skill.levels)
end

-- Trait tooltip builder.
local function buildTraitTooltipText(traitConfig, traitName, spacer)
  spacer = spacer or ""
  local statString = generateStatString(traitConfig.stats):gsub("\n", "\n" .. spacer)
  local effectString = ""
  local skillString = ""

  if traitConfig.effects then
    for _, effect in ipairs(traitConfig.effects) do
      local effectName = starPounds.moduleFunc("effects", "getConfig", effect).pretty
      effectString = string.format("%s\n%s^green;+ ^lightgray;%s", effectString, spacer, effectName)
    end
  end

  if traitConfig.skills then
    local sectionPrefix = (statString..effectString) ~= "" and ("\n\n" .. spacer) or ("\n" .. spacer)
    skillString = string.format("%s^green;Unlocks skill%s:", sectionPrefix, #traitConfig.skills > 1 and "s" or "")

    for _, skillData in ipairs(traitConfig.skills) do
      local skillName, skillLevel = skillData[1], skillData[2]
      local skill = skills[skillName]
      local levelString = (skill.levels and skill.levels > 1) and string.format(" (%s)", skillLevel) or ""

      local colour = skill.colour and string.format("^#%s;", skill.colour) or "^lightgray;"
      local prefix = "^green; +"

      -- Apply locked/greyed out formatting if skill is already unlocked.
      if traitName then
        if starPounds.moduleFunc("traits", "has", traitName) and not starPounds.moduleFunc("traits", "unlockedSkills", traitName)[skillName] then
          prefix = "^darkgray; +"
          colour = "^darkgray;"
        elseif starPounds.moduleFunc("skills", "has", skillName, skillLevel) and not starPounds.moduleFunc("traits", "has", traitName) then
          prefix = "^darkgray; +"
          colour = "^darkgray;"
        end
      end

      skillString = string.format("%s\n%s%s %s%s^gray;%s", skillString, spacer, prefix, colour, skill.pretty, levelString)
    end
  end

  return statString .. effectString .. skillString
end

local function getSkillRequirementsTooltip(skill)
  local requirements = "Requires"
  local hasRequirements = true

  if not enableUpgrades then
    local objectConfig
    for _, tabData in ipairs(tabs) do
      if skill.tab == tabData.id then
        objectConfig = root.itemConfig(tabData.defaultObject)
        break
      end
    end
    if objectConfig then
      local objectName = objectConfig.config.shortdescription
      requirements = string.format(requirements.."\n^gray;Object: %s^reset;", objectName)
    end
  end

  for requiredSkill, requiredLevel in pairs(skill.requirements) do
    local hasRequirement = starPounds.moduleFunc("skills", "unlockedLevel", requiredSkill) >= requiredLevel
    local name = skills[requiredSkill].pretty:gsub("%^.-;", "")
    local requirementTab = ""

    if skills[requiredSkill].tab ~= skill.tab and not hasRequirement then
      requirementTab = " ^darkgray;- "..tabNames[skills[requiredSkill].tab].."^reset;"
    end

    if starPounds.moduleFunc("skills", "unlockedLevel", requiredSkill) == 0 then
      for subrequiredSkill, subRequiredLevel in pairs(skills[requiredSkill].requirements or {}) do
        if not (starPounds.moduleFunc("skills", "unlockedLevel", subrequiredSkill) >= subRequiredLevel) then
          name = name:lower():gsub("[a-z]", {a="", b="", c="", d="", e="", f="", g="", h="", i="", j="", k="", l="", m="", n="", o="", p="", q="", r="", s="", t="", u="", v="", w="", x="", y="", z=""})
        end
      end
    end

    hasRequirements = hasRequirements and hasRequirement
    requirements = string.format("%s\n^%s;%s%s", requirements, hasRequirement and "green" or "red", name..((skills[requiredSkill].levels or 1) > 1 and ": "..requiredLevel or ""), requirementTab)
  end

  return requirements, hasRequirements
end

function init()
  frame.children[1].children[2]:addChild({ id = "changelogButton", type = "iconButton", image = "changelog.png", hoverImage = "changeloghover.png", pressImage = "changelogpress.png", position = {329, -6} })
  frame.children[1].children[2]:addChild({ id = "optionsButton", type = "iconButton", image = "options.png", hoverImage = "optionshover.png", pressImage = "optionspress.png", position = {344, -6} })

  local buttonIcon = string.format("%s.png", starPounds.isEnabled() and "enabled" or "disabled")
  setButtonImage(enable, buttonIcon, "?border=2;00000000;00000000?crop=2;3;88;22")

  skills = root.assetJson("/scripts/starpounds/modules/skills.config:skills")
  tabs = root.assetJson("/scripts/starpounds/modules/skills.config:tabs")
  -- Funky names because the variable space is taken up by the tab id.
  trts = root.assetJson("/scripts/starpounds/modules/traits.config")
  optns = {}
  -- Changelogs.
  changelogs = root.assetJson("/scripts/starpounds/changelog.config")
  for _, option in ipairs(starPounds.options) do
    local isValid = (not option.oSBOnly and not option.retailOnly) or (option.oSBOnly and starPounds.openStarbound) or (option.retailOnly and not starPounds.openStarbound)

    if isValid then
      table.insert(optns, option)
    end
  end

  availableTraitCache = {}
  for _, trait in ipairs(trts.selectableTraits) do
    availableTraitCache[trait] = true
  end

  -- Effects setup.
  effectTabs = root.assetJson("/scripts/starpounds/modules/effects.config:tabs")
  starPoundsEffects = root.assetJson("/scripts/starpounds/modules/effects.config:effects")
  listTimer = 0.25
  glyphTimer = 2
  glyphIndex = 1
  glyphs = {"pendant", "ring", "trinket"}

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
        table.insert(filteredTabs, tab)
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
  tabField.tabScroll.children[1]:addChild({type = "spacer"})
  populateEffectsTab()
  populateTraitTab()
  populateOptionsTab()
  populateChangelogTab()
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

  -- Stat listener for swapping accessories outside of the gui.
  statListener = function()
    if accessory then
      accessory:setItem(starPounds.moduleFunc("accessories", "get"))
      accessoryChanged()
    end
  end

  starPounds.events:on("stats:calculate", statListener)
end

function uninit()
  if starPounds and starPounds.events then
    starPounds.events:off("stats:calculate", statListener)
  end
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
    if currentTab.skillTree then
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
    if currentTab and currentTab.id == "effects" then
      populateEffectsList()
    end
  end

  if level ~= starPounds.level then
    experience = (starPounds.experience + starPounds.modules.stomach.digestionExperience)
    setProgress(experience, starPounds.level)

    if level ~= starPounds.level then
      checkSkills()
      if selectedSkill then
        _ENV[string.format("%sSkill", selectedSkill.name)].onClick()
      end
      updateTraitInfo()
    end
  end

  -- Update the effects list only while it's open.
  listTimer = math.max(listTimer - script.updateDt(), 0)
  if listTimer == 0 and currentTab and currentTab.id == "effects" and currentEffectTab and currentEffectTab.id == "active" then
    listTimer = 0.25

    for effectKey, effect in pairs(starPoundsEffects) do
      local effectData = starPounds.moduleFunc("effects", "get", effectKey)
      local effectConfig = starPounds.moduleFunc("effects", "getConfig", effectKey)
      local widgetParent = _ENV[string.format("active_%sEffect_parent", effectKey)]
      local widgetDuration = _ENV[string.format("active_%sEffect_duration", effectKey)]
      local widgetLevels = _ENV[string.format("active_%sEffect_levels", effectKey)]

      if effectData and not effectConfig.hidden then
        if widgetParent then
          if widgetDuration then
            widgetDuration:setText((starPounds.isEnabled() and "^lightgray;" or "^darkgray;")..(effectData.duration and timeFormat(effectData.duration) or "--:--"))
          end
          if widgetLevels then
            local levels = effect.levels or 1
            if levels <= 10 then
              for i=1, effect.levels do
                local levelIcon = _ENV[string.format("active_%sEffect_level_%s", effectKey, i)]
                levelIcon:setFile(string.format("levels.png:%s.%s", effect.type or "default", (effectData.level >= i) and "on" or "off"))
                levelIcon:queueRedraw()
              end
            else
              local levelLabel = _ENV[string.format("active_%sEffect_level_label", effectKey)]
              levelLabel:setText(string.format("^gray;%s / %s", effectData.level, effect.levels))
            end
          end
        else
          populateEffectsList()
        end
        if selectedEffectKey == effectKey then setEffectStats(effectKey, effect) end
      else
        if widgetParent then widgetParent:delete() end
        if selectedEffectKey == effectKey then resetInfoPanel() end
      end
    end
  end

  glyphTimer = math.max(glyphTimer - script.updateDt(), 0)
  if glyphTimer == 0 then
    glyphTimer = 2
    glyphIndex = (glyphIndex % 3) + 1
    if updateAccessoryGlyph then updateAccessoryGlyph() end
  end

  if starPounds.optionChanged and accessoryChanged then
    accessory:setItem(starPounds.moduleFunc("accessories", "get"))
    accessoryChanged()
  end

  -- Check promises.
  promises:update()
  level = starPounds.level

  if experience ~= (starPounds.experience + starPounds.modules.stomach.digestionExperience) then
    experience = (starPounds.experience + starPounds.modules.stomach.digestionExperience)
    setProgress(experience, level)
  end
end

function enable:onClick()
  local buttonIcon = string.format("%s.png", starPounds.toggleEnable() and "enabled" or "disabled")
  setButtonImage(enable, buttonIcon, "?border=2;00000000;00000000?crop=2;3;88;22")
end

function reset:onClick()
  local confirmLayout = sb.jsonMerge(root.assetJson("/interface/confirmation/resetstarpoundsconfirmation.config"), {
    title = metagui.inputData.title or "Skills",
    icon = string.format("/interface/scripted/starpounds/main/icon%s.png", metagui.inputData.iconSuffix or ""),
    images = {
      portrait = world.entityPortrait(player.id(), "full")
    }
  })

  promises:add(player.confirm(confirmLayout), function(response)
    if response then
      world.sendEntityMessage(player.id(), "starPounds.reset")
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
    tab.icon = string.format("icons/tabs/skills_%s.png", tab.id)
    tab.contents = copy(tabField.data.tabTemplate)
    tab.contents[1].children[1].id = tab.id.."_skillTree"
    tab.contents[1].children[1].children[3].id = tab.id.."_skillCanvas"
    tab.contents[1].children[1].children[4].id = tab.id.."_skillWidgets"

    local newTab = tabField:newTab(tab)
    newTab.pretty = tab.pretty
    newTab.description = tab.description
    newTab.offset = tab.offset
    newTab.skillTree = true

    if not currentTab then
      currentTab = newTab
    end

    newTab.tabWidget.toolTip = tab.pretty
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
        for _, connectedSkillName in pairs(skill.connect[1]) do
          _ENV[skill.tab.."_skillCanvasBind"]:drawLine(adjustLinePosition(skill.position), adjustLinePosition(skills[connectedSkillName].position), lineColour1, 5)
          _ENV[skill.tab.."_skillCanvasBind"]:drawLine(adjustLinePosition(skill.position), adjustLinePosition(skills[connectedSkillName].position), lineColour2, 3)
        end
      end

      _ENV[skill.tab.."_skillWidgets"]:addChild(makeSkillWidget(skill))

      _ENV[string.format("%sSkill", skill.name)].onClick = function() selectSkill(skill) end
      _ENV[string.format("%sSkill_locked", skill.name)].onClick = function() widget.playSound("/sfx/interface/clickon_error.ogg") end
    end
  end
end

function buildTraitTab()
  traitSelection = tabField:newTab(tabField.data.traitTab)
  traitSelection.pretty = "Traits"
  traitSelection.description = "This menu allows you to modify traits!\n\nTraits can affect stats, unlocked skills, and more! \n\nYou begin with limited ^#ccbbff;Trait Points^reset;, but can earn more through progression or selecting negative traits.\nChoose wisely!"
  traitSelection.tabWidget.toolTip = "Traits"
  updateTraitInfo()

  function traitSelect:onClick()
    local experienceCost = traitExperienceCost()
    local hasExperience = starPounds.level >= experienceCost
    local canSelect = hasExperience and (enableUpgrades or starPounds.moduleFunc("effects", "get", "gracePeriod")) and (isAdmin or (traitPoints >= 0)) and hasEditedTraits()

    if not canSelect then
      widget.playSound("/sfx/interface/clickon_error.ogg")
      return
    end

    for trait in pairs(starPounds.moduleFunc("traits", "get")) do
      if not activeTraitCache[trait] then
        starPounds.moduleFunc("traits", "remove", trait)
      end
    end

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
    for _, trait in ipairs(trts.selectableTraits) do
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

  if traitSort_positive.checked then table.insert(sortBy, "positive") end
  if traitSort_neutral.checked then table.insert(sortBy, "neutral") end
  if traitSort_negative.checked then table.insert(sortBy, "negative") end
  if traitSort_unique.checked then table.insert(sortBy, "unique") end

  for _, trait in ipairs(trts.selectableTraits) do
    local hasTag = false

    for _, tag in ipairs(trts.traits[trait].tags or {}) do
      if traitTagCache[tag] then hasTag = true break end
    end

    if availableTraitCache[trait] and not hasTag then
      local traitConfig = sb.jsonMerge(trts.traits.default, trts.traits[trait])
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

  for _, trait in ipairs(trts.selectableTraits) do
    if activeTraitCache[trait] then
      table.insert(newList, trait)
    end
  end

  for _, trait in ipairs(newList) do
    activeTraits:addChild(buildTraitItem(trait, true))
    _ENV[string.format("%sTraitButton_%s", trait, "active")].onClick = function() selectTrait(trait, true) end
  end
end

function buildTraitItem(trait, active)
  local panel = active and "active" or "available"
  local traitConfig = trts.traits[trait]
  local points = (traitConfig.points or 0) * (active and -1 or 1)
  local pointColour = points > 0 and (traitColours.positive .. "+") or (points < 0 and traitColours.negative or "")

  local buttonToolTip = buildTraitTooltipText(traitConfig, trait)
  local pending = (active and not starPounds.moduleFunc("traits", "has", trait)) or (not active and starPounds.moduleFunc("traits", "has", trait))

  if starPounds.moduleFunc("traits", "has", trait) then
    local cost = starPounds.moduleFunc("traits", "removeCost", trait)
    if cost > 0 then
      buttonToolTip = string.format("%s\n\n^gray;This trait unlocked skills.\nRemoving it costs ^#b8eb00;%s XP^gray;, \nbut the skills are kept.", buttonToolTip, cost)
    end
  end

  local image = string.format("trait%s%s.png", active and "Remove" or "Add", pending and "Pending" or "")
  local buttonWidget = {
    id = string.format("%sTraitButton_%s", trait, panel),
    type = "iconButton",
    position = {105, 3},
    toolTip = buttonToolTip,
    image = image, hoverImage = image,
    pressImage = image.."?border=2;00000000;00000000?crop=2;3;13;15"
  }

  local traitImage = starPounds.getSpeciesData().robotic and "traitActive_robotic.png" or "traitActive.png"

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
  local speciesTraits = starPounds.moduleFunc("traits", "getSpeciesTraitList")
  local buttonTooltip = ""
  local spacerString = "^#00000000;-^reset; "

  for i, traitName in ipairs(starPounds.moduleFunc("traits", "speciesTraits")) do
    local spTraitConfig = speciesTraits[traitName]
    if spTraitConfig then
      local tooltipContent = buildTraitTooltipText(spTraitConfig, nil, spacerString)
      buttonTooltip = string.format("%s^reset;%s^gray;- %s^reset;%s", buttonTooltip, (i > 1) and "\n" or "", spTraitConfig.pretty, tooltipContent)
    end
  end

  local buttonWidget = {
    type = "iconButton", position = {105, 3}, toolTip = buttonTooltip,
    image = "info.png", hoverImage = "info.png", pressImage = "info.png"
  }

  local traitImage = starPounds.getSpeciesData().robotic and "traitActive_robotic.png" or "traitActive.png"

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

  local points = trts.traits[trait].points
  if active then points = points * -1 end
  traitPoints = traitPoints + points

  for _, tag in ipairs(trts.traits[trait].tags or {}) do
    traitTagCache[tag] = not active and true or nil
  end

  updateAvailableTraits()
  updateActiveTraits()
  updateTraitInfo()
end

function hasEditedTraits()
  for trait in pairs(activeTraitCache) do
    if not starPounds.moduleFunc("traits", "has", trait) then return true end
  end
  for trait in pairs(availableTraitCache) do
    if starPounds.moduleFunc("traits", "has", trait) then return true end
  end
  return false
end

function traitExperienceCost()
  if isAdmin then return 0 end

  local cost = starPounds.getStat("traitExperienceCost")
  for trait in pairs(availableTraitCache) do
    if starPounds.moduleFunc("traits", "has", trait) then
      cost = cost + starPounds.moduleFunc("traits", "removeCost", trait)
    end
  end
  return math.floor(cost)
end

function updateTraitInfo()
  local ptColour = traitPoints > 0 and traitColours.positive or (traitPoints < 0 and traitColours.negative or "")
  traitPointsLabel:setText(string.format("%s%s", ptColour, traitPoints))

  local edited = hasEditedTraits()
  local experienceCost = traitExperienceCost()
  local hasExperience = starPounds.level >= experienceCost
  local hasPoints = isAdmin or (traitPoints >= 0)
  local canSelect = (enableUpgrades or starPounds.moduleFunc("effects", "get", "gracePeriod")) and hasPoints and hasExperience and edited

  local selectImage = string.format("traitSelect%s.png", canSelect and "" or "Disabled")
  setButtonImage(traitSelect, selectImage, "?border=1;00000000;00000000?crop=1;2;23;18")

  local resetImage = string.format("traitReset%s.png", edited and "" or "Disabled")
  setButtonImage(traitReset, resetImage, "?border=1;00000000;00000000?crop=1;2;17;18")

  local expColour = edited and (hasExperience and "^green;" or "^red;") or "^darkgray;"
  traitExperienceLabel:setText(string.format("%s%s XP", expColour, edited and experienceCost or "-"))

  local selStateColour = canSelect and "^green;" or "^red;"
  traitSelect.toolTip = string.format("%sModification %s^reset;", selStateColour, canSelect and "enabled" or "disabled")

  if canSelect then
    if not enableUpgrades and starPounds.moduleFunc("effects", "get", "gracePeriod") then
      local objectName = root.itemConfig("starpoundsinfusiontable").config.shortdescription
      local useAn = string.find(objectName:gsub("%^.-;", ""):sub(1, 1), "[AEIOUaeiou]")
      traitSelect.toolTip = string.format(traitSelect.toolTip.."\n^yellow;Beginner's Grace\n^gray;Does not require ^#b8eb00;XP\n^gray;Does not require %s %s^gray;", useAn and "an" or "a", objectName)
    else
      traitSelect.toolTip = string.format(traitSelect.toolTip.."\n^gray;Requires ^#b8eb00;%s XP^gray;", experienceCost)
    end
  else
    if not edited then
      traitSelect.toolTip = traitSelect.toolTip.."\n^gray;No traits modified."
    else
      if not (enableUpgrades or starPounds.moduleFunc("effects", "get", "gracePeriod")) then
        local objectName = root.itemConfig("starpoundsinfusiontable").config.shortdescription
        local useAn = string.find(objectName:gsub("%^.-;", ""):sub(1, 1), "[AEIOUaeiou]")
        if not starPounds.moduleFunc("effects", "get", "gracePeriod") then
          traitSelect.toolTip = string.format(traitSelect.toolTip.."\n^gray;Requires %s %s^reset;", useAn and "an" or "a", objectName)
        end
      end
      if not hasPoints then
        traitSelect.toolTip = string.format(traitSelect.toolTip.."\n^gray;Requires ^#ccbbff;%s Trait Point%s^gray;", traitPoints * -1, (traitPoints * -1 > 1) and "s" or "")
      end
      if not hasExperience then
        traitSelect.toolTip = string.format(traitSelect.toolTip.."\n^gray;Requires ^#b8eb00;%s XP^gray;", experienceCost)
      end
    end
  end
end

function buildEffectsTab()
  effectsSelection = tabField:newTab(tabField.data.effectsTab)
  effectsSelection.pretty = "Effects"
  effectsSelection.description = "View your active effects, discovered effects, and equip accessories!"
  effectsSelection.tabWidget.toolTip = "Effects"

  firstEffectsTab = nil
  for _, tab in ipairs(effectTabs) do
    tab.title = " "
    local cropDirective = "?border=2;00000000;00000000?crop=0;2;17;20"
    tab.icon = string.format("icons/tabs/effects_%s.png%s", tab.id, cropDirective)
    tab.contents = copy(effectsTabField.data)
    replaceInData(tab.contents, "id", "<panel>", "panel_"..tab.id)
    replaceInData(tab.contents, "text", "<title>", tab.pretty)

    -- Accessory slot for the active tab.
    replaceInData(tab.contents, "id", "<accessory>", "accessory_"..tab.id)
    for _, v in ipairs(tab.contents) do
      if type(v) == "table" and v.id == "accessory_"..tab.id then
        if tab.id == "active" then
          table.insert(v.children, { type = "panel", style = "concave", children = {
            { type = "layout", size = {246, 20}, mode = "manual", children = {
              { id = "accessoryBack", type = "image", noAutoCrop = true, position = {0, 0}, file = "accessoryback.png:unselected" },
              { id = "accessoryLabel", type = "label", position = {24, 6}, size = {216, 9}, text = "" },
              { id = "accessoryButton", type = "iconButton", size = {246, 20} },
              { id = "accessory", type = "itemSlot", position = {1, 1}, glyph = "backingimagering.png", autoInteract = true}
            }}
          }})
        else
          v.visible = false
        end
      end
    end

    local newTab = effectsTabField:newTab(tab)
    if not firstEffectsTab then
      firstEffectsTab = newTab
      currentEffectTab = newTab
    end
    -- Save these for setting the description panel.
    newTab.pretty = tab.pretty
    newTab.description = tab.description

    newTab.iconWidget.noAutoCrop = true
    newTab.tabWidget.toolTip = tab.pretty
  end

  if firstEffectsTab then
    firstEffectsTab:select()
  end

  function effectsTabField:onTabChanged(tab, previous)
    if currentEffectTab and selectedEffectKey then
      local oldBack = _ENV[string.format("%s_%sEffect_back", currentEffectTab.id, selectedEffectKey)]
      if oldBack then
        oldBack:setFile(string.format("%s_effectback.png:%s.unselected", currentEffectTab.id, selectedEffect.type or "default"))
        oldBack:queueRedraw()
      end
    end
    currentEffectTab = tab
    listTimer = 0
    resetInfoPanel()
  end

  accessoryButton.onClick = function()
    local item = accessory:item()
    if item then
      selectEffect()
      local itemDirectory = root.itemConfig(item).directory
      local icon = string.format("%s%s", itemDirectory, configParameter(item, "inventoryIcon"))

      unlockPanel:setVisible(false)
      infoPanel:setVisible(false)
      effectsStatsPanel:setVisible(true)

      descriptionTitle:setText(configParameter(item, "shortdescription"))
      descriptionText:setText(configParameter(item, "description"))
      descriptionIcon:setFile(icon)
      accessoryBack:setFile("accessoryback.png:selected")
      accessorySelected = true

      setAccessoryStats(item)

      descriptionIcon:queueRedraw()
      accessoryBack:queueRedraw()
    end
  end

  -- Effect level spinner.
  codexEffectLevel = 1
  function effectLevelUp:onClick()
    if selectedEffect and codexEffectLevel < (selectedEffect.levels or 1) then
      codexEffectLevel = metagui.checkShift() and selectedEffect.levels or (codexEffectLevel + 1)
      effectLevelValue:setText(string.format("%s/%s", codexEffectLevel, selectedEffect.levels))
      setEffectStats(selectedEffectKey, selectedEffect)
    end
  end
  function effectLevelDown:onClick()
    if selectedEffect and codexEffectLevel > 1 then
      codexEffectLevel = metagui.checkShift() and 1 or (codexEffectLevel - 1)
      effectLevelValue:setText(string.format("%s/%s", codexEffectLevel, selectedEffect.levels))
      setEffectStats(selectedEffectKey, selectedEffect)
    end
  end
end

function populateEffectsTab()
  buildEffectsTab()
  buildAccessoryFunctions()
end

function populateEffectsList()
  if not panel_active or not panel_codex then return end
  panel_active:clearChildren()
  panel_codex:clearChildren()

  local sortedEffectKeys = {}
  local sort = function(a, b)
    local typePriority = {negative = -1, neutral = 0, positive = 1, special = 2}
    local aType = starPoundsEffects[a].type or "neutral"
    local bType = starPoundsEffects[b].type or "neutral"
    if aType ~= bType then
      return typePriority[aType] > typePriority[bType]
    else
      return starPoundsEffects[a].pretty:lower() < starPoundsEffects[b].pretty:lower()
    end
  end

  for effectKey, effect in pairs(starPoundsEffects) do
    if not effect.hidden then
      table.insert(sortedEffectKeys, effectKey)
    end
  end
  table.sort(sortedEffectKeys, sort)

  for _, effectKey in ipairs(sortedEffectKeys) do
    local effect = starPoundsEffects[effectKey]
    if starPounds.moduleFunc("effects", "get", effectKey) then
      panel_active:addChild(makeEffectWidget("active", effectKey, effect))
      _ENV[string.format("active_%sEffect", effectKey)].onClick = function() selectEffect(effectKey, effect) end
    end
    if isAdmin or starPounds.moduleFunc("effects", "hasDiscovered", effectKey) then
      panel_codex:addChild(makeEffectWidget("codex", effectKey, effect))
      _ENV[string.format("codex_%sEffect", effectKey)].onClick = function() selectEffect(effectKey, effect) end
    end
  end
end

function makeEffectWidget(tab, effectKey, effect)
  local height = root.imageSize(metagui.path(string.format("%s_effectback.png:default.selected", tab)))[2]
  local effectWidget = { id = string.format("%s_%sEffect_parent", tab, effectKey), type = "layout", size = {246, height}, mode = "manual", children = {
    { id = string.format("%s_%sEffect_back", tab, effectKey), type = "image", noAutoCrop = true, position = {0, 0}, file = string.format("%s_effectback.png:%s.%s", tab, effect.type or "default", selectedEffectKey == effectKey and "selected" or "unselected") },
    { id = string.format("%s_%sEffect_name", tab, effectKey), type = "label", position = {15, 6}, size = {216, 9}, align = "center", text = effect.pretty },
    { id = string.format("%s_%sEffect_icon", tab, effectKey), type = "image", noAutoCrop = true, position = {1, 1}, file = string.format("icons/effects/%s.png", effectKey) },
    { id = string.format("%s_%sEffect", tab, effectKey), type = "iconButton", size = {246, 20} }
  }}

  if tab == "active" then
    local effectData = starPounds.moduleFunc("effects", "get", effectKey)
    table.insert(effectWidget.children, 3, {
      id = string.format("%s_%sEffect_duration", tab, effectKey),
      type = "label", position = {22, 6}, size = {216, 9},
      align = "right",
      text = (starPounds.isEnabled() and "^lightgray;" or "^darkgray;")..(effectData.duration and timeFormat(effectData.duration) or "--:--")
    })

    local levelWidget = { id = string.format("%s_%sEffect_levels", tab, effectKey), type = "layout", position = {59, 21}, size = {128, 5}, spacing = 5, mode = "horizontal", children = {"spacer"}}
    local levels = effect.levels or 1
    if levels <= 10 then
      for i=1, effect.levels do
        levelWidget.children[i + 1] = { id = string.format("%s_%sEffect_level_%s", tab, effectKey, i), type = "image", noAutoCrop = true, file = string.format("levels.png:%s.%s", effect.type or "default", (effectData.level >= i) and "on" or "off") }
      end
    else
      levelWidget.children[#levelWidget.children + 1] = { id = string.format("%s_%sEffect_level_label", tab, effectKey), type = "label", fontSize = 6, align = "center", text = string.format("^gray;%s / %s", effectData.level, effect.levels) }
    end
    levelWidget.children[#levelWidget.children + 1] = "spacer"

    table.insert(effectWidget.children, 3, levelWidget)
  end
  return effectWidget
end

function selectEffect(effectKey, effect)
  unlockPanel:setVisible(false)
  infoPanel:setVisible(false)
  effectsStatsPanel:setVisible(true)
  descriptionWidget:clearChildren()

  if selectedEffectKey and currentEffectTab and (not effectKey or selectedEffectKey ~= effectKey) then
    local oldBack = _ENV[string.format("%s_%sEffect_back", currentEffectTab.id, selectedEffectKey)]
    if oldBack then
      oldBack:setFile(string.format("%s_effectback.png:%s.unselected", currentEffectTab.id, selectedEffect.type or "default"))
      oldBack:queueRedraw()
    end
  end

  if effectKey and currentEffectTab then
    local newBack = _ENV[string.format("%s_%sEffect_back", currentEffectTab.id, effectKey)]
    if newBack then
      newBack:setFile(string.format("%s_effectback.png:%s.selected", currentEffectTab.id, effect.type or "default"))
      newBack:queueRedraw()
    end

    local icon = string.format("icons/effects/%s.png", effectKey)
    descriptionTitle:setText(effect.pretty)
    descriptionText:setText(effect.description)
    descriptionIcon:setFile(icon)
    descriptionIcon:queueRedraw()
  end

  if accessorySelected and accessoryBack then
    accessoryBack:setFile("accessoryback.png:unselected")
    accessoryBack:queueRedraw()
  end

  selectedEffectKey = effectKey
  selectedEffect = effect
  accessorySelected = false

  -- Show spinner in codex tab.
  if currentEffectTab and currentEffectTab.id == "codex" and (effect.levels or 1) > 1  then
    codexEffectLevel = 1
    effectLevelValue:setText(string.format("%s/%s", codexEffectLevel, effect.levels))
    effectLevelSpinner:setVisible(true)
  else
    effectLevelSpinner:setVisible(false)
  end

  setEffectStats(effectKey, effect)
end

function setEffectStats(effectKey, effect, level, duration)
  if not effect then return end

  local effectStats = jarray()
  local effectStatString = ""
  local effectStatValues = jarray()
  local effectStatValueString = ""

  local effectData = starPounds.moduleFunc("effects", "get", effectKey)

    if effect.stats then
    -- Use the effects spinner level if it's set.
    local lvl = effect.levels or 1
    if currentEffectTab and currentEffectTab.id == "codex" then
      lvl = codexEffectLevel or 1
    elseif effectData then
      lvl = effectData.level
    end

    for _, stat in ipairs(effect.stats) do
      local statString = ""
      local modStat = starPounds.moduleFunc("stats", "getRaw", stat[1])
      local amount = stat[3] + (stat[4] or 0) * (lvl - 1)
      if stat[2] == "mult" then
        local negative = (modStat.negative and amount > 1) or (not modStat.negative and amount < 1)
        statString = string.format("%s%sx", negative and "^red;" or "^green;", string.format("%.2f", (modStat.invertDescriptor and (1/amount) or amount)):gsub("%.?0+$", ""))
      else
        local negative = (modStat.negative and amount > 0) or (not modStat.negative and amount < 0)
        if stat[2] == "sub" then negative = not negative end
        statString = string.format("%s%s%s", negative and "^red;" or "^green;", ((not modStat.invertDescriptor and stat[2] == "add") or (modStat.invertDescriptor and stat[2] == "sub")) and "+" or "-", string.format("%.2f", modStat.flat and amount or (amount * 100)):gsub("%.?0+$", "")..(modStat.flat and "" or "%"))
      end
      local statColour = modStat.colour and ("^#"..modStat.colour..";") or ""
      effectStats[#effectStats + 1] = string.format("%s%s:^reset;", statColour, modStat.pretty)
      effectStatValues[#effectStatValues + 1] = statString
    end

    if starPounds.hasOption("showDebug") then
      effectStats[#effectStats + 1] = ""
      effectStatValues[#effectStatValues + 1] = ""
      local weight = 0
      for _, stat in ipairs(effect.stats) do
        local modStat = starPounds.moduleFunc("stats", "getRaw", stat[1])
        local negative = modStat.negative
        local amount = stat[3] + (stat[4] or 0) * (lvl - 1)
        if stat[2] == "sub" then negative = not negative end
        if stat[2] == "mult" then amount = amount - 1 end
        amount = amount * modStat.weight
        weight = weight + amount * (negative and -1 or 1)
      end
      effectStats[#effectStats + 1] = "^#665599;Stat Weight:"
      effectStatValues[#effectStatValues + 1] = string.format("%s%s", weight > 0 and "^green;" or (weight < 0 and "^red;" or ""), weight)
    end
  end

  for i in ipairs(effectStats) do
    if i > 1 then
      effectStatString = effectStatString.."\n^reset;"
      effectStatValueString = effectStatValueString.."\n^reset;"
    end
    effectStatString = effectStatString..effectStats[i]
    effectStatValueString = effectStatValueString..effectStatValues[i]
  end

  _ENV["effectStats"]:setText(effectStatString)
  _ENV["effectStatValues"]:setText(effectStatValueString)
end

function setAccessoryStats(item)
  if not item then return end

  local effectStats = jarray()
  local effectStatString = ""
  local effectStatValues = jarray()
  local effectStatValueString = ""

  if item.parameters.stats then
    for _, stat in ipairs(item.parameters.stats) do
      local statString = ""
      local modStat = starPounds.moduleFunc("stats", "getRaw", stat.name)
      local amount = stat.modifier or 0
      local negative = (modStat.negative and amount > 0) or (not modStat.negative and amount < 0)
      statString = string.format("%s%s%s", negative and "^red;" or "^green;", ((not modStat.invertDescriptor and amount >= 0) or (modStat.invertDescriptor and amount < 0)) and "+" or "-", string.format("%.2f", math.abs(modStat.flat and amount or (amount * 100))):gsub("%.?0+$", "")..(modStat.flat and "" or "%"))

      local statColour = modStat.colour and ("^#"..modStat.colour..";") or ""
      effectStats[#effectStats + 1] = string.format("%s%s:^reset;", statColour, modStat.pretty)
      effectStatValues[#effectStatValues + 1] = statString
    end

    if starPounds.hasOption("showDebug") then
      effectStats[#effectStats + 1] = ""
      effectStatValues[#effectStatValues + 1] = ""
      local weight = 0
      for _, stat in ipairs(item.parameters.stats) do
        local modStat = starPounds.moduleFunc("stats", "getRaw", stat.name)
        local amount = stat.modifier or 0
        local negative = modStat.negative
        amount = amount * modStat.weight
        weight = weight + amount * (negative and -1 or 1)
      end
      effectStats[#effectStats + 1] = "^#665599;Stat Weight:"
      effectStatValues[#effectStatValues + 1] = string.format("%s%s", weight > 0 and "^green;" or (weight < 0 and "^red;" or ""), weight)
    end
  end

  for i in ipairs(effectStats) do
    if i > 1 then
      effectStatString = effectStatString.."\n^reset;"
      effectStatValueString = effectStatValueString.."\n^reset;"
    end
    effectStatString = effectStatString..effectStats[i]
    effectStatValueString = effectStatValueString..effectStatValues[i]
  end

  _ENV["effectStats"]:setText(effectStatString)
  _ENV["effectStatValues"]:setText(effectStatValueString)
end

function buildAccessoryFunctions()
  local item = starPounds.moduleFunc("accessories", "get") and root.createItem(starPounds.moduleFunc("accessories", "get")) or nil
  if item and accessory and not accessory:acceptsItem(item) then
    starPounds.moduleFunc("accessories", "set", nil)
    player.giveItem(item)
  end

  function accessory:acceptsItem(item)
    local accessoryType = configParameter(item, "accessoryType")
    if accessoryType == "pendant" then return true end
    if accessoryType == "ring" then return true end
    if accessoryType == "trinket" then return true end
    return false
  end

  function accessory:onItemModified()
    starPounds.moduleFunc("accessories", "set", accessory:item())
    accessoryChanged()
  end

  function accessoryChanged()
    local item = accessory:item()
    accessoryLabel:setText(item and configParameter(root.createItem(item), "shortdescription", "") or "^lightgray;NO ACCESSORY EQUIPPED")
    updateAccessoryGlyph()

    if accessorySelected then
      if item then
        -- If an accessory is equipped, just refresh its stats and icon.
        local itemDirectory = root.itemConfig(item).directory
        local icon = string.format("%s%s", itemDirectory, configParameter(item, "inventoryIcon"))

        descriptionTitle:setText(configParameter(item, "shortdescription"))
        descriptionText:setText(configParameter(item, "description"))
        descriptionIcon:setFile(icon)
        setAccessoryStats(item)
        descriptionIcon:queueRedraw()
      else
        -- Only close the panel if the item was removed.
        resetInfoPanel()
      end
    end
  end

  function updateAccessoryGlyph()
    local currentAccessory = starPounds.moduleFunc("accessories", "get")
    if currentAccessory then
      local accessoryType = configParameter(currentAccessory, "accessoryType")
      for index, glyphType in ipairs(glyphs) do
        glyphIndex = glyphType == accessoryType and index or glyphIndex
      end
    end
    glyphTimer = 2
    local glyph = glyphs[glyphIndex]
    if accessory then
      accessory.glyph = metagui.path(string.format("backingimage%s.png", glyph))
      accessory:queueRedraw()
    end
  end

  if accessory then
    accessory:setItem(starPounds.moduleFunc("accessories", "get"))
    accessoryChanged()
  end
end

configParameter = function(item, keyName, defaultValue)
  if item.parameters[keyName] ~= nil then
    return item.parameters[keyName]
  elseif root.itemConfig(item).config[keyName] ~= nil then
    return root.itemConfig(item).config[keyName]
  else
    return defaultValue
  end
end

function timeFormat(seconds)
  local minutes = math.floor(math.ceil(seconds)/60)
  local seconds = math.ceil(seconds) % 60
  if (minutes < 10) then
    minutes = tostring(minutes)
  end
  if (seconds < 10) then
    seconds = "0" .. tostring(seconds)
  end
  return minutes..':'..seconds
end

function buildOptionsTab()
  local tabLayout = tabField.tabScroll.children[1]
  optionsSelection = tabField:newTab(tabField.data.optionsTab)
  optionsSelection.pretty = "Options"
  optionsSelection.description = "This menu allows you to set options for ^#ccbbff;StarPounds^reset;!\n\nOptions can be used to toggle some gameplay effects, visuals, sounds, and more!"
  optionsSelection:setVisible(false)

  function optionsButton:onClick()
    optionsSelection:select()
  end
end

function populateOptionsTab()
  buildOptionsTab()
  local optionsTabs = root.assetJson("/scripts/starpounds/options.config:tabs")
  optionsTabs[#optionsTabs + 1] = {
    id = "miscellaneous",
    description = "Miscellaneous Options"
  }
  local cropDirective = "?border=2;00000000;00000000?crop=0;2;18;19"
  for i, tab in ipairs(optionsTabs) do
    tab.title = ""
    tab.icon = string.format("icons/tabs/options_%s.png%s", tab.id, cropDirective)
    tab.contents = copy(optionsTabField.data)
    replaceInData(tab.contents, "id", "<panel>", "panel_"..tab.id)
    replaceInData(tab.contents, "text", "<title>", tab.description)
    if i == #optionsTabs then
      local tabLayout = optionsTabField.tabScroll.children[1]
      tabLayout:addChild({type = "spacer"})
    end

    local newTab = optionsTabField:newTab(tab)
    if not firstOptionsTab then
      firstOptionsTab = newTab
    end

    newTab.iconWidget.noAutoCrop = true
    newTab.tabWidget.toolTip = tab.description
  end

  firstOptionsTab:select()

  for _, option in ipairs(optns) do
    local selectionWidget
    local labelWidget
    local infoWidget
    local resetWidget
    local radioWidgets

    local optionStats = {}
    local optionStatString = ""
    if option.stats and not option.hideStats then
      for _, stat in ipairs(option.stats) do
        local statString = ""
        local modStat = starPounds.moduleFunc("stats", "getRaw", stat[1])
        local amount = stat[3]
        if stat[2] == "mult" then
          local negative = (modStat.negative and amount > 1) or (not modStat.negative and amount < 1)
          statString = string.format("%s%s %sx", amount > 1 and "increased to" or "decreased to", negative and "^red;" or "^green;", string.format("%.2f", (modStat.invertDescriptor and (1/amount) or amount)):gsub("%.?0+$", ""))
        elseif stat[2] ~= "override" then
          local negative = (modStat.negative and amount > 0) or (not modStat.negative and amount < 0)
          if stat[2] == "sub" then negative = not negative end
          statString = string.format("%s%s %s", ((not modStat.invertDescriptor and stat[2] == "add") or (modStat.invertDescriptor and stat[2] == "sub")) and "increased by" or "decreased by", negative and "^red;" or "^green;", string.format("%.2f", modStat.flat and amount or (amount * 100)):gsub("%.?0+$", "")..(modStat.flat and "" or "%"))
        end
        local statColour = modStat.colour and ("^#"..modStat.colour.."aa;") or ""
        optionStats[#optionStats + 1] = string.format("%s%s ^gray;%s", statColour, modStat.pretty, statString)
      end
    end

    for i in ipairs(optionStats) do
      optionStatString = optionStatString.."\n"..optionStats[i]
    end

    local isGlobal = starPounds.moduleFunc("options", "isGlobal", option.name)

    labelWidget = {
      type = "label",
      position = {17, 6},
      size = {229, 9},
      align = "left",
      text = option.pretty
    }

    if option.type == "slider" then
      selectionWidget = {
        id = string.format("%sOption", option.name),
        type = "slider", position = {128, 2}, size = {100, 16},
        min = option.min or 0,
        max = option.max or 100,
        granularity = option.step or 1,
        showThumbText = not option.hideThumbNumbers,
        showRangeText = not option.hideRangeNumbers,
        numberFormat = option.numberFormat
      }

      local infoIcon = isGlobal and "infoGlobal.png" or "info.png"
      local tooltipPrefix = isGlobal and "^green;Option globally enabled.^reset;\n" or ""

      infoWidget = {
        type = "iconButton", position = {4, 5}, size = {9, 9},
        image = infoIcon, hoverImage = infoIcon, pressImage = infoIcon,
        toolTip = tooltipPrefix..option.description..optionStatString..(option.footer and "\n"..option.footer or "")
      }

      if not isGlobal then
        resetWidget = {
          id = string.format("optionReset_%s", option.name),
          type = "iconButton", position = {230, 3}, size = {12, 14},
          image = "optionReset.png",
          hoverImage = "optionResetHover.png",
          pressImage = "optionResetHover.png?border=2;00000000;00000000?crop=2;2;14;16",
          toolTip = "Set to default."
        }
      end

      labelWidget.size = {114, 9}

    elseif option.type == "radio" then
      local infoIcon = isGlobal and "infoGlobal.png" or "info.png"
      local tooltipPrefix = isGlobal and "^green;Option globally enabled.^reset;\n" or ""

      infoWidget = {
        type = "iconButton", position = {4, 5}, size = {9, 9},
        image = infoIcon, hoverImage = infoIcon, pressImage = infoIcon,
        toolTip = tooltipPrefix..option.description..optionStatString..(option.footer and "\n"..option.footer or "")
      }

      radioWidgets = {}
      local spacing = 35
      for i = #option.options, 1, -1 do
        local radioOption = option.options[i]
        local radioX = 245 - ((#option.options - (i - 1)) * spacing)
        table.insert(radioWidgets, {
          id = string.format("%sOption_%s", option.name, tostring(radioOption.value)),
          type = "checkBox", position = {radioX, 9}, size = {9, 9},
          radioGroup = option.name,
          toolTip = radioOption.description or radioOption.name
        })
        local isGlobalValue = isGlobal and (starPounds.moduleFunc("options", "get", option.name) == radioOption.value)
        table.insert(radioWidgets, {
          type = "label", position = {radioX + 5 - spacing / 2, 1}, size = {spacing, 8},
          align = "center",
          text = string.format("%s%s", isGlobalValue and "^green;" or "", radioOption.name)
        })
      end

      if not isGlobal then
        resetWidget = {
          id = string.format("optionReset_%s", option.name),
          type = "iconButton", position = {230, 3}, size = {12, 14},
          image = "optionReset.png",
          hoverImage = "optionResetHover.png",
          pressImage = "optionResetHover.png?border=2;00000000;00000000?crop=2;2;14;16",
          toolTip = "Set to default."
        }
      end

    elseif isGlobal then
      selectionWidget = {
        id = string.format("%sOption", option.name),
        type = "iconButton", position = {4, 5}, size = {9, 9},
        toolTip = "^green;Option globally enabled.^reset;\n"..option.description..optionStatString..(option.footer and "\n"..option.footer or ""),
        image = "/interface/scripted/starpounds/options/check.png",
        hoverImage = "/interface/scripted/starpounds/options/check.png",
        pressImage = "/interface/scripted/starpounds/options/check.png"
      }
    else
      selectionWidget = {
        id = string.format("%sOption", option.name),
        type = "checkBox", position = {4, 5}, size = {9, 9},
        toolTip = option.description..optionStatString..(option.footer and "\n"..option.footer or ""),
        radioGroup = option.group and option.name or nil
      }
    end

    local panelChildren = { labelWidget }
    if selectionWidget then table.insert(panelChildren, selectionWidget) end
    if infoWidget then table.insert(panelChildren, infoWidget) end
    if resetWidget then table.insert(panelChildren, resetWidget) end
    if radioWidgets then
      for _, w in ipairs(radioWidgets) do
        table.insert(panelChildren, w)
      end
    end

    local optionWidget = {
      type = "panel", style = "concave", expandMode = {1, 0}, children = {
        {type = "layout", mode = "manual", size = {246, 20}, children = panelChildren}
      }
    }

    local targetPanel = string.format("panel_%s", option.tab)
    if _ENV[targetPanel] then
      _ENV[targetPanel]:addChild(optionWidget)
      if option.type == "slider" then
        local widgetId = string.format("%sOption", option.name)
        local widget = _ENV[widgetId]
        local defaultValue = option.default or option.min or 0
        local savedValue = starPounds.getOption and starPounds.getOption(option.name) or defaultValue
        if type(savedValue) ~= "number" then savedValue = defaultValue end

        widget:setValue(savedValue)

        widget.onValueChanged = function(self)
          if isGlobal then
            self:setValue(savedValue)
            return
          end
          starPounds.setOption(option.name, self.value)
        end

        if not isGlobal then
          local resetId = string.format("optionReset_%s", option.name)
          local resetButton = _ENV[resetId]
          if resetButton then
            resetButton.onClick = function()
              widget:setValue(defaultValue)
              starPounds.setOption(option.name, defaultValue)
            end
          end
        end
      elseif option.type == "radio" then
        local defaultValue = option.default or (option.options and option.options[1].value)
        local savedValue = starPounds.getOption and starPounds.getOption(option.name)
        if savedValue == nil then savedValue = defaultValue end

        for i, radioOption in ipairs(option.options or {}) do
          local widgetId = string.format("%sOption_%s", option.name, tostring(radioOption.value))
          local radioWidget = _ENV[widgetId]

          if radioWidget then
            radioWidget:setChecked(savedValue == radioOption.value)
            radioWidget.onClick = function(self)
              if isGlobal then
                for _, resetOption in ipairs(option.options or {}) do
                  local widgetId = string.format("%sOption_%s", option.name, tostring(resetOption.value))
                  if _ENV[widgetId] then
                    _ENV[widgetId]:setChecked(savedValue == resetOption.value)
                  end
                end
              end
              starPounds.setOption(option.name, radioOption.value)
            end
          end
        end
        if not isGlobal then
          local resetId = string.format("optionReset_%s", option.name)
          local resetButton = _ENV[resetId]
          if resetButton then
            resetButton.onClick = function()
              starPounds.setOption(option.name, defaultValue)
              for _, radioOption in ipairs(option.options or {}) do
                local widgetId = string.format("%sOption_%s", option.name, tostring(radioOption.value))
                if _ENV[widgetId] then
                  _ENV[widgetId]:setChecked(defaultValue == radioOption.value)
                end
              end
            end
          end
        end
      elseif not isGlobal then
        local widgetId = string.format("%sOption", option.name)
        local widget = _ENV[widgetId]
        widget.onClick = function() toggleOption(option) end
        widget:setChecked(starPounds.hasOption(option.name))
      end
    end
  end
end

function toggleOption(option)
  local enabled = starPounds.setOption(option.name, not starPounds.hasOption(option.name))
  if option.group then
    for _, disableOption in ipairs(optns) do
      if (disableOption.name ~= option.name) and (disableOption.group == option.group) then
        _ENV[string.format("%sOption", disableOption.name)]:setChecked(starPounds.setOption(disableOption.name, false))
      end
    end
  end
  _ENV[string.format("%sOption", option.name)]:setChecked(enabled)
end

function buildChangelogTab()
  changelogSelection = tabField:newTab(tabField.data.changelogTab)
  changelogSelection.pretty = "Changelog"
  changelogSelection.description = "Use this menu to view updates and changes to ^#ccbbff;StarPounds^reset;!"
  changelogSelection:setVisible(false)

  function changelogButton:onClick()
    changelogSelection:select()
  end
end

function populateChangelogTab()
  buildChangelogTab()

  function changelogTabField:onTabChanged(tab, previous)
    if selectedChangelogNode and _ENV[selectedChangelogNode.id] then
      local oldImage = selectedChangelogNode.image.."?border=1;ffffff00;00000000"
      _ENV[selectedChangelogNode.id]:setImage(oldImage, oldImage.."?brightness=20", oldImage.."?brightness=-20")
      selectedChangelogNode = nil
    end
    resetInfoPanel()
  end

  firstChangelogTab = nil
  for i = #changelogs, 1, -1 do
    local entry = changelogs[i]
    local tabData = {
      id = "changelog_" .. i,
      title = " "..entry.version,
      contents = copy(changelogTabField.data)
    }

    replaceInData(tabData.contents, "text", "<title>", "v"..entry.version)

    local textWidgets = {}
    local nodeIds = {}
    for groupIndex, group in ipairs(entry.groups or {}) do
      if group.name then
        table.insert(textWidgets, {1, { type = "label", align = "center", fontSize = 10, text = "^shadow;" .. group.name}, 1})
      else
        if textWidgets[#textWidgets] == 1 then
          textWidgets[#textWidgets] = nil
        end
      end
      local currentRow = {type = "layout", mode = "horizontal", children = {"spacer"}}
      for nodeIndex, node in ipairs(group.nodes or {}) do
        local nodeId = string.format("changelogNode_%s_%s_%s", i, groupIndex, nodeIndex)

        table.insert(currentRow.children, {
          id = nodeId,
          type = "iconButton",
          image = node.image.."?border=1;ffffff00;00000000",
          hoverImage = node.image.."?border=1;ffffff00;00000000?brightness=20",
          pressImage = node.image.."?border=1;ffffff00;00000000?brightness=-20",
          toolTip = node.toolTip
        })
        table.insert(nodeIds, {id = nodeId, text = node.text, image = node.image, title = node.title or node.toolTip})

        if nodeIndex % 8 == 0 then
          table.insert(currentRow.children, "spacer")
          table.insert(textWidgets, currentRow)
          if nodeIndex ~= #group.nodes then
            currentRow = {type = "layout", mode = "horizontal", children = {"spacer"}}
          end
        elseif nodeIndex ~= #group.nodes then
          table.insert(currentRow.children, 4)
        end
      end
      if #group.nodes % 8 ~= 0 then
        table.insert(currentRow.children, "spacer")
        table.insert(textWidgets, currentRow)
      end
      table.insert(textWidgets, 1)
    end

    if textWidgets[#textWidgets] == 1 then
      textWidgets[#textWidgets] = nil
    end

    replaceInData(tabData.contents, "children", "<textWidgets>", textWidgets)

    local newTab = changelogTabField:newTab(tabData)
    if not firstChangelogTab then
      firstChangelogTab = newTab
    end

    for _, node in ipairs(nodeIds) do
      if _ENV[node.id] then
        _ENV[node.id].onClick = function()
          if selectedChangelogNode and selectedChangelogNode.id == node.id then
            _ENV[node.id]:setImage(node.image.."?border=1;ffffff00;00000000", node.image.."?border=1;ffffff00;00000000?brightness=20", node.image.."?border=1;ffffff00;00000000?brightness=-20")
            selectedChangelogNode = nil
            resetInfoPanel()
          else
            if selectedChangelogNode and _ENV[selectedChangelogNode.id] then
              local oldImage = selectedChangelogNode.image.."?border=1;ffffff00;00000000"
              _ENV[selectedChangelogNode.id]:setImage(oldImage, oldImage.."?brightness=20", oldImage.."?brightness=-20")
            end
            selectedChangelogNode = {id = node.id, image = node.image}

            local selectedImage = node.image.."?border=1;ffffffaa;00000000"
            _ENV[node.id]:setImage(selectedImage, selectedImage.."?brightness=20", selectedImage.."?brightness=-20")
            selectedSkill = nil

            unlockPanel:setVisible(false)
            infoPanel:setVisible(false)
            if effectsStatsPanel then effectsStatsPanel:setVisible(false) end

            descriptionTitle:setText("^shadow;"..node.title)
            descriptionIcon:setFile(node.image)
            descriptionIcon:queueRedraw()
            descriptionText:setText(node.text)

            descriptionWidget:clearChildren()
          end
        end
      end
    end
  end

  if firstChangelogTab then
    firstChangelogTab:select()
  end
end

function generateStatString(stats)
  local stringCache = jarray()
  local finalString = ""

  if stats then
    for _, stat in ipairs(stats) do
      local currentStatString = ""
      local modStat = starPounds.moduleFunc("stats", "getRaw", stat[1])
      local op = stat[2]
      local amount = stat[3]

      if op == "mult" then
        local isNegative = (modStat.negative and amount > 1) or (not modStat.negative and amount < 1)
        local formattedAmount = string.format("%.2f", (modStat.invertDescriptor and (1/amount) or amount)):gsub("%.?0+$", "")
        currentStatString = string.format("%s%sx", isNegative and "^red;" or "^green;", formattedAmount)
      else
        local isNegative = (modStat.negative and amount > 0) or (not modStat.negative and amount < 0)
        if op == "sub" then isNegative = not isNegative end
        local sign = ((not modStat.invertDescriptor and op == "add") or (modStat.invertDescriptor and op == "sub")) and "+" or "-"
        local formattedAmount = string.format("%.2f", modStat.flat and amount or (amount * 100)):gsub("%.?0+$", "")..(modStat.flat and "" or "%")
        currentStatString = string.format("%s%s%s", isNegative and "^red;" or "^green;", sign, formattedAmount)
      end

      local statColour = modStat.colour and ("^#"..modStat.colour..";") or ""
      table.insert(stringCache, string.format("%s %s%s", currentStatString, statColour, modStat.pretty))
    end
  end

  for _, str in ipairs(stringCache) do
    finalString = finalString.."\n"..str
  end

  return finalString
end

function makeSkillWidget(skill)
  local toolTip = string.format("%s%s", skill.pretty:gsub("%^.-;", ""), skill.shortDescription and "\n^gray;"..skill.shortDescription or "")
  local skillIconPath = string.format("icons/skills/%s.png", skill.icon or skill.name)

  local skillWidget = {
    type = "layout", position = skill.position, size = {48, 48}, mode = "manual", children = {
      {id = string.format("%sSkill_back", skill.name), type = "image", noAutoCrop = true, position = {12, 8}, file = string.format("back.png?multiply=%s", skill.colour)},
      {id = string.format("%sSkill", skill.name), toolTip = toolTip, position = {16, 12}, type = "iconButton", image = skillIconPath, hoverImage = skillIconPath, pressImage = skillIconPath.."?border=1;00000000;00000000?crop=1;2;17;18"},
      {id = string.format("%sSkill_locked", skill.name), toolTip = toolTip, visible = false, type = "iconButton", position = {12, 8}, image = "locked.png", hoverImage = "locked.png", pressImage = "locked.png"},
      {id = string.format("%sSkill_check", skill.name), visible = false, type = "image", noAutoCrop = true, position = {28, 20}, file = "check.png"}
    }
  }

  if skill.levels > 1 then
    table.insert(skillWidget.children, {id = string.format("%sSkill_backLevel", skill.name), type = "image", position = {14, 29}, file = "backLevel.png"})
    table.insert(skillWidget.children, {id = string.format("%sSkill_backLevelText", skill.name), type = "label", position = {14, 32}, size = {20, 10}, fontSize = 5, align = "center", text = formatSkillLevel(skill.name)})
  end

  if skill.hidden then
    local hiddenIconPath = string.format("icons/skills/%s.png", skill.hiddenIcon)
    skillWidget.children[2] = {id = string.format("%sSkill", skill.name), position = {16, 12}, type = "iconButton", image = hiddenIconPath, hoverImage = hiddenIconPath, pressImage = hiddenIconPath.."?border=1;00000000;00000000?crop=1;2;17;18"}
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
  if effectsStatsPanel then effectsStatsPanel:setVisible(false) end
  descriptionWidget:clearChildren()

  local canIncrease, canDecrease, canUpgrade, useToggle, skillMaxed = false, false, false, false, false
  local experienceCost = 0

  if selectedSkill and (not skill or selectedSkill.name ~= skill.name) then
    local oldSkillIconPath = string.format("icons/skills/%s.png", selectedSkill.hidden and selectedSkill.hiddenIcon or (selectedSkill.icon or selectedSkill.name))
    _ENV[string.format("%sSkill_back", selectedSkill.name)]:setFile(string.format("back.png?multiply=%s", selectedSkill.colour))
    _ENV[string.format("%sSkill_back", selectedSkill.name)]:queueRedraw()
    _ENV[string.format("%sSkill", selectedSkill.name)]:setImage(oldSkillIconPath, oldSkillIconPath, oldSkillIconPath)
  end

  if skill then
    local skillIconPath = string.format("icons/skills/%s.png?border=1;ffffffaa;00000000", skill.icon or skill.name)
    _ENV[string.format("%sSkill_back", skill.name)]:setFile(string.format("back.png?multiply=%s?brightness=50?saturation=-15", skill.colour))
    _ENV[string.format("%sSkill_back", skill.name)]:queueRedraw()
    _ENV[string.format("%sSkill", skill.name)]:setImage(skillIconPath, skillIconPath, skillIconPath)

    descriptionTitle:setText("^shadow;"..skill.pretty)
    descriptionIcon:setFile(string.format("icons/skills/%s.png", skill.icon or skill.name))
    descriptionIcon:queueRedraw()
    descriptionText:setText(skill.description:gsub("<activationSize>", starPounds.moduleFunc("size", "sizes")[starPounds.moduleFunc("size", "activationSize")].size:gsub("^%l", string.upper)))

    local currentLevel = starPounds.moduleFunc("skills", "level", skill.name)
    local unlockedLevel = starPounds.moduleFunc("skills", "unlockedLevel", skill.name)
    local skillItems = getSkillItems(skill)
    local hasItems = hasSkillItems(skill)

    local slotCount = math.min(#skillItems, 5)
    unlockItems.columns = slotCount
    unlockItems:setNumSlots(slotCount)

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
      local nextIncrease = math.floor(0.5 + ((stat.flat and 1 or 100) * (nextAmount - baseAmount)) * 100) / 100
      nextAmount = stat.invertDescriptor and (nextIncrease * -1) or nextIncrease
      local nextString = currentLevel == skill.levels and "" or string.format("%s%.2f", nextAmount > 0 and "+" or "", nextAmount):gsub("%.?0+$", "")..(stat.flat and "" or "%")

      local bonus = starPounds.moduleFunc("stats", "skillBonus", skill.stat)
      local totalAmount = (bonus ~= 0 and (stat.invertDescriptor and (bonus * -1) or bonus) or 0) + stat.base
      local totalIncrease = math.floor(0.5 + ((stat.flat and 1 or 100) * totalAmount) * 100) / 100
      local amount = totalIncrease
      local amountString = string.format("%.2f", amount):gsub("%.?0+$", "")..(stat.flat and "" or "%")

      if stat.normalizeBase then
        nextAmount = baseAmount + skill.amount * (skill.type == "addStat" and 1 or -1)
        nextIncrease = math.floor(0.5 + ((stat.flat and 1 or 100) * (nextAmount - baseAmount) / (baseAmount > 0 and baseAmount or 1)) * 100) / 100
        nextAmount = stat.invertDescriptor and (nextIncrease * -1) or nextIncrease
        nextString = currentLevel == skill.levels and "" or string.format("%s%.2f", nextAmount > 0 and "+" or "", nextAmount):gsub("%.?0+$", "")..(stat.flat and "" or "%")

        totalIncrease = math.floor(0.5 + ((stat.flat and 1 or 100) * totalAmount / (baseAmount > 0 and baseAmount or 1)) * 100) / 100
        amount = totalIncrease ~= 0 and (stat.invertDescriptor and (totalIncrease * -1) or totalIncrease) or 0
        amountString = string.format("%.2f", amount):gsub("%.?0+$", "")..(stat.flat and "" or "%")
      end

      local function tchelper(first, rest)
         return first:upper()..rest:lower()
      end

      infoCurrent:setText(string.format("^#%s;%s^reset; \n^clear;%s^reset; %s ^gray;%s", textColour, stat.pretty:gsub("(%a)([%w_']*)", tchelper), nextString, amountString, nextString))
      statInfo.toolTip = stat.description
      if stat.scaling then
        statInfo.toolTip = statInfo.toolTip.."\n^gray,set;This stat scales until ^#00ebce;"..starPounds.moduleFunc("size", "sizes")[starPounds.moduleFunc("size", "scalingSize")].size:gsub("^%l", string.upper).."^reset;."
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
      local objectConfig
      for _, tabData in ipairs(tabs) do
        if skill.tab == tabData.id then
          objectConfig = root.itemConfig(tabData.defaultObject)
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

    local toggleImage = string.format("unlockToggle.png:%s.%s", (canIncrease or not skillMaxed) and "off" or "on", skillMaxed and "enabled" or "disabled")
    setButtonImage(unlockToggle, toggleImage, "?border=1;00000000;00000000?crop=1;2;13;27")

    local unlockImage = string.format("unlock%s.png", enableUpgrades and (canUpgrade and "" or "Disabled") or "Locked")
    setButtonImage(unlockButton, unlockImage, "?border=1;00000000;00000000?crop=1;2;25;27")

    local increaseImage = string.format("unlockIncrease%s.png", canIncrease and "" or "Disabled")
    setButtonImage(unlockIncrease, increaseImage, "?border=1;00000000;00000000?crop=1;2;13;15")

    local decreaseImage = string.format("unlockDecrease%s.png", canDecrease and "" or "Disabled")
    setButtonImage(unlockDecrease, decreaseImage, "?border=1;00000000;00000000?crop=1;2;13;15")

    if skill.widget and (skill.forceWidget or unlockedLevel > 0) then
      require(string.format("/interface/scripted/starpounds/main/descriptionWidgets/%s.lua", skill.widget.id))
      descriptionFunctions[skill.widget.id](descriptionWidget:addChild(skill.widget))
    end
  end

  selectedSkill = skill
end

function checkSkills()
  for skillName, skill in pairs(skills) do
    if not skill.internal then
      _ENV[string.format("%sSkill_locked", skill.name)]:setVisible(false)

      if skill.levels > 1 then
        _ENV[string.format("%sSkill_backLevelText", skill.name)]:setText(formatSkillLevel(skill.name))
      end

      if skill.requirements then
        local requirements, hasRequirements = getSkillRequirementsTooltip(skill)

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
    if currentTab.skillTree then
      _ENV[currentTab.id.."_skillTree"]:scrollTo(currentTab.offset)
    end
    if currentTab.id == "options" then
      firstOptionsTab:select()
      firstOptionsTab.contents:setVisible(true)
    end
    if currentTab.id == "changelog" then
      firstChangelogTab:select()
      firstChangelogTab.contents:setVisible(true)
    end
    if currentTab.id == "effects" then
      firstEffectsTab:select()
      firstEffectsTab.contents:setVisible(true)
      -- Force a list refresh.
      populateEffectsList()
    end
  end
end

function resetInfoPanel()
  selectSkill()
  selectedEffectKey = nil
  selectedEffect = nil

  -- Default to the primary tab's info.
  local titleText = currentTab.pretty
  local descText = currentTab.description
  local icon = string.format("icons/tabs/%s.png", currentTab.id)

  if currentTab.skillTree then
    icon = string.format("icons/tabs/skills_%s.png", currentTab.id)
  elseif currentTab.id == "effects" and currentEffectTab then
    -- Override with the specific tab info in the effects menu.
    titleText = currentEffectTab.pretty
    descText = currentEffectTab.description
    icon = string.format("icons/tabs/effects_%s.png", currentEffectTab.id)
  end

  infoPanel:setVisible(false)
  unlockPanel:setVisible(false)
  if effectsStatsPanel then effectsStatsPanel:setVisible(false) end

  descriptionTitle:setText(titleText)
  descriptionText:setText(descText)
  descriptionIcon:setFile(icon)
  descriptionIcon:queueRedraw()

  if accessorySelected and accessoryBack then
    accessoryBack:setFile("accessoryback.png:unselected")
    accessoryBack:queueRedraw()
    accessorySelected = false
  end
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

  if selectedSkill.levels > 1 then
    _ENV[string.format("%sSkill_backLevelText", selectedSkill.name)]:setText(formatSkillLevel(selectedSkill.name))
  end

  checkSkills()
  selectSkill(selectedSkill)
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

  for _, item in ipairs(skillItems) do
    local itemCount = root.itemType(item[1]) == "currency" and player.currency(item[1]) or player.hasCountOfItem(item[1])
    if itemCount < item[2] then
      return false
    end
  end
  return true
end

function unlockIncrease:onClick()
  starPounds.moduleFunc("skills", "set", selectedSkill.name, metagui.checkShift() and starPounds.moduleFunc("skills", "unlockedLevel", selectedSkill.name) or (starPounds.moduleFunc("skills", "level", selectedSkill.name) + 1))
  selectSkill(selectedSkill)
  _ENV[string.format("%sSkill_backLevelText", selectedSkill.name)]:setText(formatSkillLevel(selectedSkill.name))
end

function unlockDecrease:onClick()
  starPounds.moduleFunc("skills", "set", selectedSkill.name, metagui.checkShift() and 0 or (starPounds.moduleFunc("skills", "level", selectedSkill.name) - 1))
  selectSkill(selectedSkill)
  _ENV[string.format("%sSkill_backLevelText", selectedSkill.name)]:setText(formatSkillLevel(selectedSkill.name))
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
    player.radioMessage({important = true, unique = false, messageId = "BUT_WHY", text = "Since you've decided to click this 100 times, I'm guessing you're expecting a reward. Have a single pixel."})
    player.giveItem("money")
  elseif statInfoCount == 250 then
    player.radioMessage({important = true, unique = false, messageId = "BUT_WHY", text = "Fine." })
    player.giveItem("gracecupcake")
    widget.playSound("/sfx/objects/colonydeed_partyhorn.ogg", nil, 0.75)
  end
end

function setProgress(currentExperience, currentLevel)
  local experienceConfig = starPounds.moduleFunc("experience", "config")
  local progress = math.min(currentExperience / (experienceConfig.experienceAmount * (1 + currentLevel * experienceConfig.experienceIncrement)), 1)

  experienceText:setText(string.format("%s XP", currentLevel))
  experienceBar:setFile(string.format("bar.png?crop;0;0;%s;14", math.floor(70 * (progress or 0) + 0.5)))
  experienceBar:queueRedraw()
  experienceBar:queueGeometryUpdate()
  experienceLayout:queueRedraw()
  experienceLayout:queueGeometryUpdate()
end

function weightDecrease:onClick()
  if metagui.checkShift() then
    starPounds.moduleFunc("size", "setWeight", 0)
  else
    starPounds.moduleFunc("size", "setSize", starPounds.currentSizeIndex - 1, math.min(starPounds.progress, 0.99))
  end
end

function weightIncrease:onClick()
  if metagui.checkShift() then
    starPounds.moduleFunc("size", "setWeight", starPounds.moduleFunc("size", "maximumWeight"))
  else
    starPounds.moduleFunc("size", "setSize", starPounds.currentSizeIndex + 1, math.max(starPounds.progress, 0.01))
  end
end

function admin()
  return player.isAdmin() or starPounds.hasOption("admin") or false
end

function replaceInData(data, keyname, value, replacevalue)
  if type(data) == "table" then
    for k, v in pairs(data) do
      if (k == keyname or keyname == nil) and (v == value or value == nil) then
        data[k] = replacevalue
      else
        replaceInData(v, keyname, value, replacevalue)
      end
    end
  end
end
