function init()
  self.buyFactor = config.getParameter("buyFactor", root.assetJson("/merchant.config").defaultBuyFactor)

  object.setInteractive(true)

  self.species = {generic = true, ancient = true}
end

function buildInteraction()
  if self.interactData then return self.interactData end

  local interactData = config.getParameter("interactData")
  interactData.recipes = {}

  local storeInventory = config.getParameter("storeInventory")
  local tabs = interactData["modTab"]
  local posY = 277
  local categories = {
    type = "radioGroup",
    toggleMode = false,
    buttons = {}
  }

  if #tabs > 0 then
    for i,modtab in ipairs(tabs) do
    local tabIcon = modtab["file"]
    local tabName = modtab["label"]
    local tabFilter = modtab["filter"]

    local tabIconLabel = {
      type = "image",
      file = tabIcon,
      position = {
      6,
      posY
      },
      zlevel = 3
    }

    local tabNameLabel = {
      type = "label",
      value = tabName,
      position = {
      20,
      posY+2
      },
      zlevel = 3
    }

    local tabButton = {
        selected = true,
        position = {
        3,
        posY-2
        },
        baseImage = "/interface/fattyshops/body/unselectedTab.png",
        baseImageChecked = "/interface/fattyshops/body/selectedTab.png",
        data = {
        filter = tabFilter
        }
      }

    interactData.paneLayoutOverride["icon" .. tabName] = tabIconLabel
    interactData.paneLayoutOverride["lbl" .. tabName] = tabNameLabel
    table.insert(categories["buttons"], 1, tabButton)
    posY = posY - 18
    end
    interactData.paneLayoutOverride["categories"] = categories
  end

  for genre,objects in pairs(storeInventory) do addRecipes(interactData, objects, genre) end

  self.interactData = interactData
  return interactData
end


function onInteraction(args)
  return { "OpenCraftingInterface", buildInteraction() }
end

function addRecipes(interactData, items, category)
  for i, item in ipairs(items) do
    local showItem = false

    local checkSpecies = {}
    local conf
    if type(item) == "string" then
      conf = root.itemConfig(item).config
    elseif type(item) == "table" then
      conf = root.itemConfig(item.output).config
    end

    if conf.race then
      checkSpecies[#checkSpecies + 1] = conf.race
    end

    if conf.races and type(conf.races) == "table" then
      for _, species in ipairs(conf.races) do
        checkSpecies[#checkSpecies + 1] = species
      end
    end

    if #checkSpecies == 0 then
      showItem = true
    end

    for _, species in ipairs(checkSpecies) do
      -- Cache checked species.
      if species and (self.species[species] == nil) then
        self.species[species] = pcall(function () root.npcVariant(species, "base", 1, 1) return true end)
      end

      showItem = showItem or self.species[species]
    end

    if showItem then
      interactData.recipes[#interactData.recipes + 1] = generateRecipe(item, category)
    end
  end
end

function generateRecipe(itemName, category)
  if type(itemName) == "table" then return sb.jsonMerge(itemName, {groups = { category }, duration = 0}) end
  return {
    input = { {"money", math.floor(self.buyFactor * (root.itemConfig(itemName).config.price or root.assetJson("/merchant.config").defaultItemPrice))} },
    output = itemName,
  duration = 0,
    groups = { category }
  }
end
