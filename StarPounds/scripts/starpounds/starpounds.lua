require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

starPounds = {
  version = root.assetJson("/scripts/starpounds/starpounds.config:version"),
  settings = root.assetJson("/scripts/starpounds/starpounds.config:settings"),
  sizes = root.assetJson("/scripts/starpounds/starpounds_sizes.config:sizes"),
  options = root.assetJson("/scripts/starpounds/starpounds_options.config:options"),
  foods = root.assetJson("/scripts/starpounds/starpounds_foods.config"),
  traits = root.assetJson("/scripts/starpounds/starpounds_traits.config:traits"),
  selectableTraits = root.assetJson("/scripts/starpounds/starpounds_traits.config:selectableTraits"),
  species = root.assetJson("/scripts/starpounds/starpounds_species.config")
}
-- Mod functions
----------------------------------------------------------------------------------
starPounds.isEnabled = function()
  return storage.starPounds.enabled
end

-- Runs a function in a module. Same as calling directly, but makes sure it exists.
starPounds.moduleFunc = function(name, func, ...)
  local module = starPounds.modules[name]
  if module then
    return module[func](module, ...)
  end
end

starPounds.moduleInit = function(moduleGroups)
  starPounds.modules = starPounds.modules or {}
  starPounds.moduleKeys = jarray()
  local modulePath = "/scripts/starpounds/modules/%s.lua"
  if moduleGroups then
    if type(moduleGroups) == "string" then moduleGroups = {moduleGroups} end
    -- Load all the module scripts.
    for _, moduleGroup in ipairs(moduleGroups) do
      for i = 1, #starPounds.settings.modules[moduleGroup] do
        local moduleName = starPounds.settings.modules[moduleGroup][i]
        starPounds.moduleKeys[#starPounds.moduleKeys + 1] = moduleName
        require(string.format(modulePath, moduleName))
      end
    end
    -- Initialise all the modules in order.
    for _, moduleName in ipairs(starPounds.moduleKeys) do
      starPounds.modules[moduleName]:moduleInit()
    end
  end
end

starPounds.moduleUpdate = function(dt)
  local updated = {}
  -- Do modules in order if they're loaded with starPounds.moduleInit.
  for i = 1, #starPounds.moduleKeys do
    local moduleName = starPounds.moduleKeys[i]
    updated[moduleName] = true
    starPounds.modules[moduleName]:moduleUpdate(dt)
  end
  -- Do others with regular pairs.
  for moduleName, module in pairs(starPounds.modules) do
    if not updated[moduleName] then
      module:moduleUpdate(dt)
    end
  end
end

starPounds.moduleUninit = function()
  for _, module in pairs(starPounds.modules) do
    module:uninit()
  end
end

starPounds.module = {}
function starPounds.module:new(name)
  local module = {}
  local modulePath = "/scripts/starpounds/modules/%s.config"
  module.data = root.assetJson(string.format(modulePath, name))
  setmetatable(module, extend(self))
  return module
end

-- Specific module initialising.
function starPounds.module:moduleInit()
  -- Sticking all the management stuff under a module table just in case.
  self.module = {
    parentDelta = math.round(60 * script.updateDt()),
    tickCounter = 0,
    updateTicks = 1
  }

  self:setUpdateDelta(self.data.scriptDelta)
  self:init()
end
-- Instead of a timer, just count update ticks of the main script.
-- E.g. If the module delta is 10, and the main script is 5, update every 2 main script ticks.
function starPounds.module:moduleUpdate(dt) -- Updates the module's update loop based on it's delta.
  if self.module.updateTicks == 0 then return end
  self.module.tickCounter = (self.module.tickCounter + 1) % self.module.updateTicks
  if self.module.tickCounter == 0 then
    -- Run the actual update loop.
    self:update(dt * self.module.updateTicks)
  end
end

function starPounds.module:setUpdateDelta(dt)
  -- Argument sanitisation.
  dt = math.max(tonumber(dt) or 1, 0)
  -- 0 = No update.
  if dt == 0 then
    self.module.updateTicks = 0
    return
  end
  self.module.updateTicks = math.max(math.round(dt / self.module.parentDelta), 1)
end
-- Standard functions.
function starPounds.module:init() end -- Runs whenever the target loads in, or the mod gets enabled.
function starPounds.module:update(dt) end -- Update loop.
function starPounds.module:uninit() end -- Runs whenever the target unloads, or the mod gets disabled.

starPounds.spawnMouthProjectile = function(actions, count)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  if not actions then return end
  count = tonumber(count) or 1
  world.spawnProjectile("invisibleprojectile", vec2.add(starPounds.mcontroller.mouthPosition, mcontroller.isNullColliding() and 0 or vec2.div(starPounds.mcontroller.velocity, 60)), entity.id(), {0,0}, true, {
    damageKind = "hidden",
    universalDamage = false,
    onlyHitTerrain = true,
    timeToLive = 5/60,
    periodicActions = {{action = "loop", time = 0, ["repeat"] = false, count = count, body = actions}}
  })
end

starPounds.hasOption = function(option)
  -- Argument sanitisation.
  option = tostring(option)
  return storage.starPounds.options[option]
end

starPounds.setOption = function(option, enable)
  -- Argument sanitisation.
  option = tostring(option)
  storage.starPounds.options[option] = enable and true or nil
  starPounds.events:fire("stats:calculate", "setOption")
  -- This is stupid, but prevents 'null' data being saved.
  if getmetatable(storage.starPounds.options) then
    getmetatable(storage.starPounds.options).__nils = {}
  end
  starPounds.moduleFunc("data", "backup")
  return storage.starPounds.options[option]
end

starPounds.getTrait = function()
  -- Reset the trait if it doesn't exist.
  local trait = storage.starPounds.trait
  -- Reset non-existent traits
  if trait and not starPounds.traits[trait] then
    starPounds.resetTrait()
    return
  end
  -- Remove a player's trait if they shouldn't be able to select it.
  if trait and starPounds.type == "player" then
    if not contains(starPounds.selectableTraits, trait) then
      starPounds.resetTrait()
      return
    end
  end
  return storage.starPounds.trait
end

starPounds.setTrait = function(trait)
  -- Argument sanitisation.
  trait = tostring(trait)
  -- Don't do anything if we already have a trait, or the trait doesn't exist.
  if storage.starPounds.trait or not starPounds.traits[trait] then return false end
  -- Set the trait.
  storage.starPounds.trait = starPounds.traits[trait].idOverride or trait
  local selectedTrait = starPounds.traits[trait]
  local mt = {__index = function (table, key) return starPounds.traits.default[key] end}
  setmetatable(selectedTrait, mt)
  -- Unlock trait skills.
  for _, skill in ipairs(selectedTrait.skills or jarray()) do
    starPounds.moduleFunc("skills", "forceUnlock", skill[1], skill[2])
  end
  -- Set trait starting values. Done a bit weirdly so it still applies when the mod is off.
  storage.starPounds.weight = math.max(storage.starPounds.weight, selectedTrait.weight)
  starPounds.moduleFunc("size", "setWeight", storage.starPounds.weight)
  -- Give trait milk
  storage.starPounds.breasts.amount = math.max(storage.starPounds.breasts.amount, selectedTrait.breasts)
  starPounds.moduleFunc("breasts", "setMilk", storage.starPounds.breasts.amount)
  -- Give trait experience.
  storage.starPounds.experience.level = storage.starPounds.experience.level + selectedTrait.experience
  -- Give trait items to players.
  if starPounds.type == "player" then
    for _, item in ipairs(selectedTrait.items) do
      player.giveItem(item)
    end
  end
  -- Refresh stats.
  starPounds.events:fire("stats:calculate", "setTrait")
  -- Set the trait successfully.
  return true
end

starPounds.resetTrait = function()
  storage.starPounds.trait = nil
  -- Refresh stats.
  starPounds.events:fire("stats:calculate", "resetTrait")
end

-- world.entitySpecies can be unreliable on the first tick.
starPounds.getSpecies = function()
  if storage.starPounds.overrideSpecies then return storage.starPounds.overrideSpecies end
  if starPounds.type == "player" then return player.species() end
  if starPounds.type == "npc" then return npc.species() end
  return world.entitySpecies(entity.id())
end

starPounds.getVisualSpecies = function(species)
  -- Get entity species.
  local species = species and tostring(species) or starPounds.getSpecies()
  return starPounds.species[species] and (starPounds.species[species].override or species) or species
end

starPounds.getSpeciesData = function(species)
  -- Get merged species data.
  local species = species and tostring(species) or starPounds.getSpecies()
  return sb.jsonMerge(starPounds.species.default, starPounds.species[species] or {})
end

starPounds.baseDirectives = function(target)
  local target = tonumber(target) or entity.id()
  if target == entity.id() then
    -- Player shorthand (with oSB or equivalent).
    if starPounds.type == "player" and player.bodyDirectives then
      return player.bodyDirectives()
    end
    -- NPC shorthand.
    if starPounds.type == "npc" then
      return npc.humanoidIdentity().bodyDirectives
    end
  end
  -- Generate a nude portrait.
  for _,v in ipairs(world.entityPortrait(target, "fullnude")) do
    -- Find the player's body sprite.
    if string.find(v.image, "body.png") then
      -- Seperate the body sprite's image directives.
      return string.sub(v.image, (string.find(v.image, "?")))
    end
  end
end

starPounds.getDirectives = function(target)
  -- Argument sanitisation.
  local target = tonumber(target) or entity.id()
  local directives = starPounds.baseDirectives(target)
  -- Get entity species.
  local species = (target ~= entity.id()) and world.entitySpecies(target) or starPounds.getSpecies()
  local speciesData = starPounds.getSpeciesData(species)
  -- Add append directives, if any. (i.e. novakids have this white patch that doesn't change with default species colours, adding ffffff=ffffff means it gets picked up by the fullbright block)
  if speciesData.appendDirectives then
    directives = string.format("%s;%s", directives, speciesData.appendDirectives):gsub(";;", ";")
  end
  -- If the species is fullbright (i.e. novakids), append 'fe' to hexcodes to make them fullbright. (99%+ opacity)
  if speciesData.fullbright then
    directives = (directives..";"):gsub("(%x)(%?)", function(a) return a..";?" end):gsub(";;", ";"):gsub("(%x+=%x%x%x%x%x%x);", function(colour)
      return string.format("%sfe;", colour)
    end)
  end
  -- Slip in override directives, if any. This is after the fullbright block since this is usually used for mimicking species palettes.
  if speciesData.prependDirectives then
    directives = string.format("%s;%s", speciesData.prependDirectives, directives):gsub(";;", ";")
  end
  return directives
end

starPounds.messageHandlers = function()
  -- Handler for enabling the mod.
  message.setHandler("starPounds.toggleEnable", localHandler(starPounds.toggleEnable))
  -- Handlers for grabbing data.
  message.setHandler("starPounds.isEnabled", simpleHandler(starPounds.isEnabled))
  message.setHandler("starPounds.getDirectives", simpleHandler(starPounds.getDirectives))
  message.setHandler("starPounds.getVisualSpecies", simpleHandler(starPounds.getVisualSpecies))
  -- Handlers for traits/options
  message.setHandler("starPounds.hasOption", simpleHandler(starPounds.hasOption))
  message.setHandler("starPounds.setOption", localHandler(starPounds.setOption))
  message.setHandler("starPounds.getTrait", simpleHandler(starPounds.getTrait))
  message.setHandler("starPounds.setTrait", localHandler(starPounds.setTrait))
  -- Interface/debug stuff.
  message.setHandler("starPounds.reset", localHandler(starPounds.reset))
  message.setHandler("starPounds.resetConfirm", localHandler(starPounds.reset))
  message.setHandler("starPounds.resetTrait", localHandler(starPounds.resetTrait))
  message.setHandler("starPounds.setResource", localHandler(status.setResource))
end

-- Other functions
----------------------------------------------------------------------------------
starPounds.toggleEnable = function()
  starPounds.moduleFunc("prey", "released")
  starPounds.moduleFunc("pred", "release", nil, true)
  -- Do a barrel roll (just flip the boolean).
  storage.starPounds.enabled = not storage.starPounds.enabled
  -- Make sure the movement penalty stuff gets reset as well.
  starPounds.moduleFunc("skills", "parse")
  starPounds.events:fire("stats:calculate", "toggleEnable")
  if not storage.starPounds.enabled then
    starPounds.moduleUninit()
    starPounds.movementMultiplier = 1
    starPounds.jumpModifier = 1
    world.sendEntityMessage(entity.id(), "starPounds.expire")
    status.clearPersistentEffects("starpounds")
    status.clearPersistentEffects("starpoundseaten")
  else
    for _, module in pairs(starPounds.modules or {}) do
      module:moduleInit()
    end
  end
  return storage.starPounds.enabled
end

starPounds.reset = function()
  -- Save accessories.
  local accessory = storage.starPounds.accessory
  -- Reset data.
  starPounds.moduleFunc("data", "reset")
  -- If we set this to true, the enable function sets it back to false.
  -- Means we can keep all the 'get rid of stuff' code in one place.
  storage.starPounds.enabled = true
  starPounds.toggleEnable()
  -- Bye bye fat techs.
  if starPounds.type == "player" then
    -- Restore accessories.
    if accessory then
      player.giveItem(accessory)
    end
    -- Remove StarPounds techs.
    for _, v in ipairs(player.availableTechs()) do
      if v:find("starpounds") then
        player.makeTechUnavailable(v)
      end
    end
  end
  -- Re-unlock default trait skills.
  if starPounds.type == "monster" then
    if not starPounds.getTrait() then
      starPounds.setTrait(config.getParameter("starPounds_trait"))
    end
  else
    local speciesTrait = starPounds.traits[starPounds.getSpecies()] or starPounds.traits.default
    for _, skill in ipairs(speciesTrait.skills or jarray()) do
      starPounds.moduleFunc("skills", "forceUnlock", skill[1], skill[2])
    end
  end
  return true
end

starPounds.resetConfirm = function()
  local confirmLayout = root.assetJson("/interface/confirmation/resetstarpoundsconfirmation.config")
  confirmLayout.images.portrait = world.entityPortrait(player.id(), "full")
  promises:add(player.confirm(confirmLayout), function(response)
    if response then
      starPounds.reset()
    end
  end)
  return true
end

-- Other functions
----------------------------------------------------------------------------------
function math.round(num, numDecimalPlaces)
  local format = string.format("%%.%df", numDecimalPlaces or 0)
  return tonumber(string.format(format, num))
end

-- Grabs a parameter, or a config, or defaultValue
configParameter = function(item, keyName, defaultValue)
  if item.parameters[keyName] ~= nil then
    return item.parameters[keyName]
  elseif root.itemConfig(item).config[keyName] ~= nil then
    return root.itemConfig(item).config[keyName]
  else
    return defaultValue
  end
end
