require "/scripts/messageutil.lua"
require "/scripts/util.lua"
starPounds = getmetatable ''.starPounds

function init()
  local buttonIcon = string.format("%s.png", starPounds.isEnabled() and "enabled" or "disabled")
  enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
  stats = root.assetJson("/scripts/starpounds/modules/stats.config:stats")
  tabs = root.assetJson("/scripts/starpounds/starpounds_options.config:tabs")
  tabs[#tabs + 1] = {
    id = "miscellaneous",
    description = "Miscellaneous Options",
    icon = "miscellaneous.png"
  }

  openStarbound = starPounds.moduleFunc("oSB", "hasOpenStarbound")
  options = {}
  for i, option in ipairs(starPounds.options) do
    if not (option.oSBOnly or option.retailOnly) then
      options[#options + 1] = option
    elseif option.oSBOnly and openStarbound then
      options[#options + 1] = option
    elseif option.retailOnly and not openStarbound then
      options[#options + 1] = option
    end
  end

  populateOptions()
end

function update()
  if isAdmin ~= admin() then
    isAdmin = admin()
    weightDecrease:setVisible(isAdmin)
    weightIncrease:setVisible(isAdmin)
    barPadding:setVisible(not isAdmin)
  end

  -- Check promises.
  promises:update()
end

function populateOptions()
  local firstTab = nil
  for _, tab in ipairs(tabs) do
    tab.title = " "
    tab.icon = tab.id..".png"
    tab.contents = copy(tabField.data)
    replaceInData(tab.contents, "id", "<panel>", "panel_"..tab.id)
    replaceInData(tab.contents, "text", "<title>", tab.description)
    local newTab = tabField:newTab(tab)

    if not firstTab then
      firstTab = newTab
    end
  end
  firstTab:select()

  for optionIndex, option in ipairs(options) do
    local optionStats = jarray()
    local optionStatString = ""

    if option.stats and not option.hideStats then
      for _, stat in ipairs(option.stats) do
        local statString = ""
        local modStat = starPounds.moduleFunc("stats", "getRaw", stat[1])
        local amount = stat[3]
        if stat[2] == "mult" then
          local negative = (modStat.negative and amount > 1) or (not modStat.negative and amount < 1)
          statString = string.format("%s%s x%s", amount > 1 and "increased to" or "decreased to", negative and "^red;" or "^green;", string.format("%.2f", (modStat.invertDescriptor and (1/amount) or amount)):gsub("%.?0+$", ""))
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

    local buttonWidget
    if starPounds.moduleFunc("options", "isGlobal", option.name) then
      buttonWidget = {
        id = string.format("%sOption", option.name),
        type = "iconButton", position = {4, 5}, size = {9, 9},
        toolTip = "^green;Option globally enabled.^reset;\n"..option.description..optionStatString..(option.footer and "\n"..option.footer or ""),
        image = "/interface/scripted/starpounds/options/check.png",
        hoverImage = "/interface/scripted/starpounds/options/check.png",
        pressImage = "/interface/scripted/starpounds/options/check.png"
      }
    else
      buttonWidget = {
        id = string.format("%sOption", option.name),
        type = "checkBox", position = {4, 5}, size = {9, 9},
        toolTip = option.description..optionStatString..(option.footer and "\n"..option.footer or ""),
        radioGroup = option.group and option.name or nil
      }
    end

    local optionWidget = {
      type = "panel", style = "concave", expandMode = {1, 0}, children = {
        {type = "layout", mode = "manual", size = {131, 20}, children = {
          buttonWidget,
          {type = "label", position = {15, 6}, size = {120, 9}, align = "left", text = option.pretty},
        }}
      }
    }

    if _ENV[(string.format("panel_%s", option.tab))] then
      _ENV[(string.format("panel_%s", option.tab))]:addChild(optionWidget)

      if not starPounds.moduleFunc("options", "isGlobal", option.name) then
        _ENV[string.format("%sOption", option.name)].onClick = function() toggleOption(option) end
        _ENV[string.format("%sOption", option.name)]:setChecked(starPounds.hasOption(option.name))
      end
    end
  end
end

function toggleOption(option)
  local enabled = starPounds.setOption(option.name, not starPounds.hasOption(option.name))
  if option.group then
    for _, disableOption in ipairs(options) do
      if (disableOption.name ~= option.name) and (disableOption.group == option.group) then
        _ENV[string.format("%sOption", disableOption.name)]:setChecked(starPounds.setOption(disableOption.name, false))
      end
    end
  end
  _ENV[string.format("%sOption", option.name)]:setChecked(enabled)
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

function enable:onClick()
  local buttonIcon = string.format("%s.png", starPounds.toggleEnable() and "enabled" or "disabled")
  enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
end

function reset:onClick()
  local confirmLayout = sb.jsonMerge(root.assetJson("/interface/confirmation/resetstarpoundsconfirmation.config"), {
    title = "Options",
    icon = "/interface/scripted/starpounds/options/icon.png",
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

function admin()
  return (player.isAdmin() or starPounds.hasOption("admin")) or false
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
