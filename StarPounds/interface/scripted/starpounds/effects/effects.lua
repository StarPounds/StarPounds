-- Menu made with a huge amount of help from @meltmeltix
require "/scripts/messageutil.lua"
require "/scripts/util.lua"
starPounds = getmetatable ''.starPounds

function init()
  local buttonIcon = string.format("%s.png", starPounds.isEnabled() and "enabled" or "disabled")
  enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
  tabs = root.assetJson("/scripts/starpounds/modules/effects.config:tabs")
  effects = root.assetJson("/scripts/starpounds/modules/effects.config:effects")

  isAdmin = admin()

  weightDecrease:setVisible(isAdmin)
  weightIncrease:setVisible(isAdmin)
  barPadding:setVisible(not isAdmin)

  if starPounds then
    buildTabs()
    populateTabs()
  end
  resetInfoPanel()

  listTimer = 0.25

  glyphTimer = 2
  glyphIndex = 1
  glyphs = {"pendant", "ring", "trinket"}
  buildAccessoryFunctions()

  statListener = function()
    accessory:setItem(starPounds.moduleFunc("accessories", "get"))
    accessoryChanged()
  end
  starPounds.events:on("stats:calculate", statListener)
end

function update()
  listTimer = math.max(listTimer - script.updateDt(), 0)
  if listTimer == 0 and currentTab.id == "active" then
    listTimer = 0.25

    for effectKey, effect in pairs(effects) do
      local effectData = starPounds.moduleFunc("effects", "get", effectKey)
      local widgetParent = _ENV[string.format("active_%sEffect_parent", effectKey)]
      local widgetDuration = _ENV[string.format("active_%sEffect_duration", effectKey)]
      local widgetLevels = _ENV[string.format("active_%sEffect_levels", effectKey)]
      if effectData then
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
          populateTabs()
        end
        if selectedEffectKey == effectKey then selectEffect(effectKey, effect) end
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
    updateAccessoryGlyph()
  end

  if starPounds.optionChanged then
    accessory:setItem(starPounds.moduleFunc("accessories", "get"))
    accessoryChanged()
  end

  if isAdmin ~= admin() then
    isAdmin = admin()
    weightDecrease:setVisible(isAdmin)
    weightIncrease:setVisible(isAdmin)
    barPadding:setVisible(not isAdmin)
    populateTabs()
  end

  promises:update()
end

function uninit()
  starPounds.events:off("stats:calculate", statListener)
end

function buildTabs()
  for _, tab in ipairs(tabs) do
    tab.title = " "
    tab.icon = string.format("icons/tabs/%s.png", tab.id)
    tab.contents = copy(tabField.data.templateTab)
    replaceInData(tab.contents, "id", "<panel>", "panel_"..tab.id)
    replaceInData(tab.contents, "text", "<title>", tab.pretty)
    -- This is dirty but w/e
    if tab.id == "active" then
      local listPanel = tab.contents[1].children[3].children
      listPanel[#listPanel + 1] = { type = "layout", size = {142, 20}, mode = "manual", children = {
        { id = "accessoryBack", type = "image", noAutoCrop = true, position = {0, 0}, file = "accessoryback.png:unselected" },
        { id = "accessoryLabel", type = "label", position = {24, 6}, size = {117, 9}, text = "" },
        { id = "accessoryButton", type = "iconButton", size = {142, 20} },
        { id = "accessory", type = "itemSlot", position = {2, 1}, glyph = "backingimagering.png", autoInteract = true}
      }}
    end

    local newTab = tabField:newTab(tab)
    newTab.pretty = tab.pretty
    newTab.description = tab.description

    if not currentTab then
      currentTab = newTab
    end
  end

  -- This is dirty 2: Electric Boogaloo
  accessoryButton.onClick = function()
    local item = accessory:item()
    if item then
      selectEffect()
      root.itemConfig(descriptor)
      local itemDirectory = root.itemConfig(item).directory
      local icon = string.format("%s%s", itemDirectory, configParameter(item, "inventoryIcon"))
      effectsPanel:setVisible(true)
      controlsPanel:setVisible(false)
      descriptionTitle:setText(configParameter(item, "shortdescription"))
      descriptionText:setText(configParameter(item, "description"))
      descriptionIcon:setFile(icon)
      accessoryBack:setFile("accessoryback.png:selected")
      accessorySelected = true,

      setAccessoryStats(item)

      descriptionIcon:queueRedraw()
      accessoryBack:queueRedraw()
    end
  end
  currentTab:select()
end

function populateTabs()
  -- Remove existing entries.
  panel_active:clearChildren()
  panel_codex:clearChildren()

  local sortedEffectKeys = {}
  local sort = function(a, b)
    local typePriority = {negative = -1, neutral = 0, positive = 1, special = 2}
    local aType = effects[a].type or "neutral"
    local bType = effects[b].type or "neutral"
    if aType ~= bType then
      return typePriority[aType] > typePriority[bType]
    else
      return effects[a].pretty:lower() < effects[b].pretty:lower()
    end
  end

  for effectKey, effect in pairs(effects) do
    if not effect.hidden then
      table.insert(sortedEffectKeys, effectKey)
    end
  end
  table.sort(sortedEffectKeys, sort)

  for _, effectKey in ipairs(sortedEffectKeys) do
    local effect = effects[effectKey]
    -- Active effect panel
    if starPounds.moduleFunc("effects", "get", effectKey) then
      panel_active:addChild(makeEffectWidget("active", effectKey, effect))
      _ENV[string.format("active_%sEffect", effectKey)].onClick = function() selectEffect(effectKey, effect) end
    end
    -- Codex panel
    if isAdmin or starPounds.moduleFunc("effects", "hasDiscovered", effectKey) then
      panel_codex:addChild(makeEffectWidget("codex", effectKey, effect))
      _ENV[string.format("codex_%sEffect", effectKey)].onClick = function() selectEffect(effectKey, effect) end
    end

  end
end

function makeEffectWidget(tab, effectKey, effect)
  local height = root.imageSize(metagui.path(string.format("%s_effectback.png:default.selected", tab)))[2]
  local effectWidget = { id = string.format("%s_%sEffect_parent", tab, effectKey), type = "layout", size = {142, height}, mode = "manual", children = {
    { id = string.format("%s_%sEffect_back", tab, effectKey), type = "image", noAutoCrop = true, position = {0, 0}, file = string.format("%s_effectback.png:%s.%s", tab, effect.type or "default", selectedEffectKey == effectKey and "selected" or "unselected") },
    { id = string.format("%s_%sEffect_name", tab, effectKey), type = "label", position = {22, 6}, size = {112, 9}, text = effect.pretty },
    { id = string.format("%s_%sEffect_icon", tab, effectKey), type = "image", noAutoCrop = true, position = {2, 2}, file = string.format("icons/effects/%s.png", effectKey) },
    { id = string.format("%s_%sEffect", tab, effectKey), type = "iconButton", size = {142, 20} }
  }}

  if tab == "active" then
    local effectData = starPounds.moduleFunc("effects", "get", effectKey)
    table.insert(effectWidget.children, 3, {
      id = string.format("%s_%sEffect_duration", tab, effectKey),
      type = "label", position = {22, 6}, size = {112, 9},
      align = "right",
      text = (starPounds.isEnabled() and "^lightgray;" or "^darkgray;")..(effectData.duration and timeFormat(effectData.duration) or "--:--")
    })

    local levelWidget = { id = string.format("%s_%sEffect_levels", tab, effectKey), type = "layout", position = {7, 21}, size = {128, 5}, spacing = 5, mode = "horizontal", children = {"spacer"}}
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
  effectsPanel:setVisible(true)
  controlsPanel:setVisible(true)
  local canIncrease = false
  local canDecrease = false
  local canUpgrade = false
  local useToggle = false

  if selectedEffectKey and (not effectKey or selectedEffectKey ~= effectKey) then
    _ENV[string.format("%s_%sEffect_back", currentTab.id, selectedEffectKey)]:setFile(string.format("%s_effectback.png:%s.unselected", currentTab.id, selectedEffect.type or "default"))
    _ENV[string.format("%s_%sEffect_back", currentTab.id, selectedEffectKey)]:queueRedraw()
  end

  if effectKey then
    _ENV[string.format("%s_%sEffect_back", currentTab.id, effectKey)]:setFile(string.format("%s_effectback.png:%s.selected", currentTab.id, effect.type or "default"))
    _ENV[string.format("%s_%sEffect_back", currentTab.id, effectKey)]:queueRedraw()

    local icon = string.format("icons/effects/%s.png", effectKey)
    descriptionTitle:setText(effect.pretty)
    descriptionText:setText(effect.description)
    descriptionIcon:setFile(icon)
    descriptionIcon:queueRedraw()
  end

  if accessorySelected then
    accessoryBack:setFile("accessoryback.png:unselected")
    accessoryBack:queueRedraw()
  end

  selectedEffectKey = effectKey
  selectedEffect = effect

  accessorySelected = false

  setEffectStats(effectKey, effect, level, duration)
end

function setEffectStats(effectKey, effect, level, duration)
  if not effect then return end

  local effectStats = jarray()
  local effectStatString = ""
  local effectStatValues = jarray()
  local effectStatValueString = ""

  local effectData = starPounds.moduleFunc("effects", "get", effectKey)

  if effect.stats then
    local level = effectData and effectData.level or effect.levels
    for _, stat in ipairs(effect.stats) do
      local statString = ""
      local modStat = starPounds.moduleFunc("stats", "getRaw", stat[1])
      local amount = stat[3] + (stat[4] or 0) * (level - 1)
      if stat[2] == "mult" then
        local negative = (modStat.negative and amount > 1) or (not modStat.negative and amount < 1)
        statString = string.format("%sx%s", negative and "^red;" or "^green;", string.format("%.2f", (modStat.invertDescriptor and (1/amount) or amount)):gsub("%.?0+$", ""))
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
        local amount = stat[3] + (stat[4] or 0) * (level - 1)
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

function resetInfoPanel()
  selectedEffectKey = nil
  selectedEffect = nil
  selectEffect()
  local icon = string.format("icons/tabs/%s.png", currentTab.id)
  effectsPanel:setVisible(false)
  controlsPanel:setVisible(false)
  descriptionTitle:setText(currentTab.pretty)
  descriptionText:setText(currentTab.description)
  descriptionIcon:setFile(icon)
  descriptionIcon:queueRedraw()
end

function tabField:onTabChanged(tab, previous)
  if currentTab then
    currentTab = tab
    if selectedEffectKey then
      _ENV[string.format("%s_%sEffect_back", previous.id, selectedEffectKey)]:setFile(string.format("%s_effectback.png:%s.unselected", previous.id, selectedEffect.type or "default"))
      _ENV[string.format("%s_%sEffect_back", previous.id, selectedEffectKey)]:queueRedraw()
    end
    listTimer = 0
    resetInfoPanel()
    populateTabs()
  end
end

function enable:onClick()
  local buttonIcon = string.format("%s.png", starPounds.toggleEnable() and "enabled" or "disabled")
  enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
end

function reset:onClick()
  local confirmLayout = sb.jsonMerge(root.assetJson("/interface/confirmation/resetstarpoundsconfirmation.config"), {
    title = "Effects",
    icon = "/interface/scripted/starpounds/menu/icon.png",
    images = {
      portrait = world.entityPortrait(player.id(), "full")
    }
  })
  promises:add(player.confirm(confirmLayout), function(response)
    if response then
      promises:add(world.sendEntityMessage(player.id(), "starPounds.reset"), function()
        local buttonIcon = "disabled.png"
        enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
      end)
    end
  end)
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

function buildAccessoryFunctions()
    -- Pop out bad items.
  local item = starPounds.moduleFunc("accessories", "get") and root.createItem(starPounds.moduleFunc("accessories", "get")) or nil
  if item and not accessory:acceptsItem(item) then
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
    accessoryLabel:setText(item and configParameter(root.createItem(accessory:item()), "shortdescription", "") or "^lightgray;NO ACCESSORY EQUIPPED")
    updateAccessoryGlyph()
    if accessorySelected then
      resetInfoPanel()
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

    accessory.glyph = metagui.path(string.format("backingimage%s.png", glyph))
    accessory:queueRedraw()
  end

  accessory:setItem(starPounds.moduleFunc("accessories", "get"))
  accessoryChanged()
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

function replaceInData(data, keyname, value, replacevalue)
  if type(data) == "table" then
    for k, v in pairs(data) do
      if (k == keyname or keyname == nil) and (v == value or value == nil) then
        -- sb.logInfo("Replacing value %s of key %s with value %s", v, k, replacevalue)
        data[k] = replacevalue
      else
        replaceInData(v, keyname, value, replacevalue)
      end
    end
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
