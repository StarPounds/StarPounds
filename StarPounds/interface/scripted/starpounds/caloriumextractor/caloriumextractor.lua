starPounds = getmetatable ''.starPounds
function init()
  maxStack = root.assetJson("/items/defaultParameters.config:defaultMaxStack")
  caloriumFat = root.assetJson("/scripts/starpounds/modules/liquid.config:liquids.starpoundscaloriumliquid").food.fatLiquid
  extracting = false
  extractTimer = 0.1
  effectTarget = 500
  updateButtonIcon()
end

function update()
  updateButtonIcon()
  updateStatusImage()
  if starPounds.isEnabled() and extracting then
    extractTimer = math.max(extractTimer - script.updateDt(), 0)
    local weight = starPounds.moduleFunc("data", "get", "weight")
    if canExtract() then
      if extractTimer == 0 then
        local nextWeight = starPounds.sizes[starPounds.currentSizeIndex + 1] and starPounds.sizes[starPounds.currentSizeIndex + 1].weight or starPounds.settings.maxWeight
        local caloriumCost = caloriumFat + math.floor(0.02 * (nextWeight - starPounds.currentSize.weight) + 0.5)
        local converted = math.floor(starPounds.moduleFunc("size", "loseWeight", caloriumCost, true)/caloriumCost + 0.5)
        starPounds.caloriumExtractTracker = (starPounds.caloriumExtractTracker or 0) + (caloriumCost * converted)
        -- Roughly every 500kg (effectTarget), add a stack. Slightly random for funsies.
        local chance = starPounds.caloriumExtractTracker / effectTarget
        if (chance > math.random()) then
          starPounds.caloriumExtractTracker = starPounds.caloriumExtractTracker - effectTarget
          starPounds.moduleFunc("effects", "add", "caloriumExtractor")
        end

        addCalorium(converted)
        world.sendEntityMessage(pane.sourceEntity(), "heartbeat")
        extractTimer = 0.2
      end
    else
      extractTimer = 0.2
      extracting = false
      widget.playSound("/sfx/objects/apexcoolcomputer_switchoff.ogg")
    end
  end
end

function extract:onClick()
  if not extracting and not canExtract() then
    widget.playSound("/sfx/interface/clickon_error.ogg")
    return
  end
  extracting = not extracting
  if extracting then
    widget.playSound("/sfx/objects/apexcoolcomputer_switchon.ogg")
    world.sendEntityMessage(pane.sourceEntity(), "heartbeat")
  else
    widget.playSound("/sfx/objects/apexcoolcomputer_switchoff.ogg")
  end
end

function caloriumOutput:acceptsItem(item)
  return item.name == "starpoundsliquidcalorium"
end

function addCalorium(amount)
  local item = caloriumOutput:item() or {name = "starpoundsliquidcalorium", count = 0}
  item.count = math.min(maxStack, item.count + amount)
  caloriumOutput:setItem(item)
end

function canExtract()
  local weight = starPounds.moduleFunc("data", "get", "weight")
  local itemCount = (caloriumOutput:item() or {name = "starpoundsliquidcalorium", count = 0}).count
  local canExtract = starPounds.isEnabled() and not starPounds.hasOption("disableLoss") and weight >= 10 and itemCount < maxStack
  return canExtract
end

function updateButtonIcon()
  local buttonIcon = string.format("button.png:%s", canExtract() and (extracting and "on" or "off") or "disabled")
  extract:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=1;00000000;00000000?crop=1;2;49;35")
end

function updateStatusImage()
  statusImage:setFile("status.png:"..(extracting and "on" or "off"))
end

function uninit()
  player.giveItem(caloriumOutput:item())
end
