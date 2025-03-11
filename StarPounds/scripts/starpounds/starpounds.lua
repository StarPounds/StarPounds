require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/status.lua"

starPounds = {
  version = root.assetJson("/scripts/starpounds/starpounds.config:version"),
  settings = root.assetJson("/scripts/starpounds/starpounds.config:settings"),
  sizes = root.assetJson("/scripts/starpounds/starpounds_sizes.config:sizes"),
  stats = root.assetJson("/scripts/starpounds/starpounds_stats.config"),
  foods = root.assetJson("/scripts/starpounds/starpounds_foods.config"),
  skills = root.assetJson("/scripts/starpounds/starpounds_skills.config:skills"),
  traits = root.assetJson("/scripts/starpounds/starpounds_traits.config:traits"),
  effects = root.assetJson("/scripts/starpounds/starpounds_effects.config:effects"),
  selectableTraits = root.assetJson("/scripts/starpounds/starpounds_traits.config:selectableTraits"),
  species = root.assetJson("/scripts/starpounds/starpounds_species.config"),
  baseData = root.assetJson("/scripts/starpounds/starpounds.config:baseData")
}
-- Mod functions
----------------------------------------------------------------------------------
starPounds.isEnabled = function()
  return storage.starPounds.enabled
end

starPounds.getData = function(key)
  if key then return storage.starPounds[key] end
  return storage.starPounds
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
    for _, moduleGroup in ipairs(moduleGroups) do
      for i = 1, #starPounds.settings.modules[moduleGroup] do
        local moduleName = starPounds.settings.modules[moduleGroup][i]
        starPounds.moduleKeys[#starPounds.moduleKeys + 1] = moduleName
        require(string.format(modulePath, moduleName))
        local module = starPounds.modules[moduleName]
        module:moduleInit()
      end
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

starPounds.belch = function(volume, pitch, loops, addMomentum)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  volume = tonumber(volume) or 1
  pitch = tonumber(pitch) or 1
  loops = tonumber(loops)
  if addMomentum == nil then addMomentum = true end
  -- Skip if belches are disabled.
  if starPounds.hasOption("disableBelches") then return end
  local distortionSphere = status.stat("activeMovementAbilities") > 1
  if status.stat("activeMovementAbilities") > 1 then
    volume = volume * 0.5
    starPounds.moduleFunc("sound", "play", "belch", volume, pitch, loops)
    return
  end
  starPounds.moduleFunc("sound", "play", "belch", volume, pitch, loops)
  -- 7.5 (Rounded to 8) to 10 particles, decreased or increased by up to 2x, -5
  -- Ends up yielding around 10 - 15 particles if the belch is very loud and deep, 3 - 5 at normal volume and pitch, and none if it's half volume or twice as high pitch.
  local volumeMultiplier = math.max(math.min(volume, 1.5), 0)
  local pitchMultiplier = 1/math.max(pitch, 2/3)
  local particleCount = starPounds.hasOption("disableBelchParticles") and 0 or math.round(math.max(math.random(75, 100) * 0.1 * pitchMultiplier * volumeMultiplier - 5, 0))
  -- Belches give momentum in zero g based on the particle count, because why not.
  if addMomentum and starPounds.mcontroller.zeroG then
    mcontroller.addMomentum({-0.5 * starPounds.mcontroller.facingDirection * (0.5 + starPounds.weightMultiplier * 0.5) * particleCount, 0})
  end
  -- Alert nearby enemies.
  local targets = world.entityQuery(starPounds.mcontroller.position, starPounds.settings.belchAlertRadius * volume, { includedTypes = {"npc", "monster"} })
  for _, target in pairs(targets) do
    if world.entityAggressive(target) and world.entityCanDamage(target, entity.id()) then
      world.sendEntityMessage(target, "starPounds.notifyDamage", {sourceId = entity.id()})
    end
  end
  -- Skip if we're not doing particles.
  if particleCount == 0 then return end
    -- Create a belch particle with gravity.
    local particle = {}
    local gravity = world.gravity(starPounds.mcontroller.mouthPosition)
    local friction = world.breathable(starPounds.mcontroller.mouthPosition) or world.liquidAt(starPounds.mcontroller.mouthPosition)
    particle.initialVelocity = {0, gravity/62.5}
    particle.finalVelocity = {0, -gravity}
    particle.approach = {friction and 5 or 0, gravity}

    starPounds.spawnMouthProjectile({{
      action = "particle", specification = starPounds.makeBelchParticle(particle)
    }}, particleCount)
end

function starPounds.makeBelchParticle(override)
  local facing = starPounds.mcontroller.facingDirection
  local velocity = vec2.add(starPounds.mcontroller.velocity, {7 * facing, 0})
  local particle = sb.jsonMerge(starPounds.settings.particleTemplates.belch, override or {})
  -- Flip particles and add extra velocity based on direction.
  particle.initialVelocity = vec2.add(vec2.mul(particle.initialVelocity or {0, 0}, {facing, 1}), velocity)
  particle.finalVelocity = vec2.mul(particle.finalVelocity or {0, 0}, {facing, 1})

  return particle
end

starPounds.belchPitch = function(multiplier)
  multiplier = tonumber(multiplier) or 1
  local pitch = util.randomInRange(starPounds.settings.belchPitch)
  if not starPounds.hasOption("genderlessBelches") then
    local gender = world.entityGender(entity.id())
    if gender then
      pitch = pitch + (starPounds.settings.belchGenderModifiers[gender] or 0)
    end
  end
  pitch = math.round(pitch * multiplier, 2)
  return pitch
end

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

starPounds.updateStats = function(updateStats)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Give the entity hitbox, bonus stats, and effects based on fatness.
  local size = starPounds.currentSize
  local sizeIndex = starPounds.currentSizeIndex
  if updateStats then
    -- Shouldn't activate at base size, so indexes are reduced by one.
    local bonusEffectiveness = math.min(1, (sizeIndex - 1) / (starPounds.settings.scalingSize - 1))
    local applyImmunity = starPounds.currentSizeIndex >= starPounds.settings.activationSize
    local gritReduction = status.stat("activeMovementAbilities") <= 1 and -((starPounds.weightMultiplier - 1) * math.max(0, 1 - starPounds.getStat("knockbackResistance"))) or 0
    local persistentEffects = {
      {stat = "maxHealth", baseMultiplier = 1 + math.round((size.healthMultiplier - 1) * starPounds.getStat("health"), 2)},
      {stat = "foodDelta", effectiveMultiplier = ((starPounds.stomach.food > 0) or starPounds.hasOption("disableHunger")) and 0 or math.round(starPounds.getStat("hunger"), 2)},
      {stat = "grit", amount = gritReduction},
      {stat = "shieldHealth", effectiveMultiplier = 1 + starPounds.getStat("shieldHealth") * bonusEffectiveness},
      {stat = "knockbackThreshold", effectiveMultiplier = 1 - gritReduction},
      {stat = "fallDamageMultiplier", effectiveMultiplier = size.healthMultiplier * (1 - starPounds.getStat("fallDamageResistance"))},
      {stat = "iceStatusImmunity", amount = applyImmunity and starPounds.getSkillLevel("iceImmunity") or 0},
      {stat = "poisonStatusImmunity", amount = applyImmunity and starPounds.getSkillLevel("poisonImmunity") or 0},
      {stat = "iceResistance", amount = starPounds.getStat("iceResistance") * bonusEffectiveness},
      {stat = "poisonResistance", amount = starPounds.getStat("poisonResistance") * bonusEffectiveness}
    }
    -- Probably not optimal, but don't apply effects if they do nothing.
    local filteredPersistentEffects = jarray()
    for i, effect in ipairs(persistentEffects) do
      local skip = (
        effect.baseMultiplier and effect.baseMultiplier == 1) or (
        effect.effectiveMultiplier and effect.effectiveMultiplier == 1) or (
        effect.amount and effect.amount == 0
      )
      if not skip then filteredPersistentEffects[#filteredPersistentEffects + 1] = effect end
    end
    status.setPersistentEffects("starpounds", filteredPersistentEffects)
  end

  -- Check if the entity is using a morphball (Tech patch bumps this number for the morphball).
  if status.stat("activeMovementAbilities") > 1 then return end

  if not baseParameters then baseParameters = mcontroller.baseParameters() end
  local parameters = baseParameters

  if updateStats or not (starPounds.controlModifiers and starPounds.controlParameters) then
    local movement = starPounds.getStat("movement")
    starPounds.movementMultiplier = size.movementMultiplier
    -- If we have the anti-immobile skill, use double the movement penalty of blob instead.
    local isImmobile = starPounds.movementMultiplier == 0
    if isImmobile and starPounds.hasSkill("preventImmobile") then
      starPounds.movementMultiplier = starPounds.sizes[sizeIndex - 1].movementMultiplier ^ 2
    end
    -- Movement stat starts at 0.
    -- Every +1 halves the penalty, every -1 doubles it (muliplicatively).
    if starPounds.movementMultiplier > 0 then
      if movement <= 0 then
        starPounds.movementMultiplier = starPounds.movementMultiplier ^ (1 - movement)
      else
        starPounds.movementMultiplier = 1 - ((1 - starPounds.movementMultiplier) / (2 ^ movement))
      end
    end
    -- Jump/Swim math applies after the movement stat calcuation.
    if starPounds.movementMultiplier <= 0 then
      starPounds.movementMultiplier = 0
      starPounds.jumpModifier = starPounds.settings.minimumJumpMultiplier
      starPounds.swimModifier = starPounds.settings.minimumSwimMultiplier
    else
      starPounds.jumpModifier = math.max(starPounds.settings.minimumJumpMultiplier, 1 - ((1 - starPounds.movementMultiplier) * starPounds.getStat("jumpPenalty")))
      starPounds.swimModifier = math.max(starPounds.settings.minimumSwimMultiplier, 1 - ((1 - starPounds.movementMultiplier) * starPounds.getStat("swimPenalty")))
    end


    local updateModifiers = false
    for _, value in pairs({"movementMultiplier", "jumpModifier", "swimModifier"}) do
      if starPounds[value] ~= starPounds[value.."Old"] then
        starPounds[value.."Old"] = starPounds[value]
        updateModifiers = true
      end
    end

    local movementMultiplier = starPounds.movementMultiplier
    local weightMultiplier = starPounds.weightMultiplier

    if updateModifiers then
      starPounds.controlModifiers = weightMultiplier == 1 and {} or {
        groundMovementModifier = movementMultiplier,
        liquidMovementModifier = starPounds.swimModifier,
        speedModifier = movementMultiplier,
        airJumpModifier = starPounds.jumpModifier,
        liquidJumpModifier = starPounds.swimModifier
      }
      -- Silly, but better than updating modifiers every tick.
      starPounds.controlModifiersAlt = (movementMultiplier < starPounds.settings.minimumAltSpeedMultiplier) and sb.jsonMerge(starPounds.controlModifiers, {
        speedModifier = starPounds.settings.minimumAltSpeedMultiplier
      }) or nil
    end

    starPounds.controlParameters = weightMultiplier == 1 and {} or {
      mass = parameters.mass * weightMultiplier,
      airForce = parameters.airForce * weightMultiplier,
      groundForce = parameters.groundForce * weightMultiplier,
      airFriction = parameters.airFriction * weightMultiplier,
      liquidBuoyancy = parameters.liquidBuoyancy + math.min((weightMultiplier - 1) * 0.01, 0.95),
      liquidForce = parameters.liquidForce * weightMultiplier,
      liquidFriction = parameters.liquidFriction * weightMultiplier,
      normalGroundFriction = parameters.normalGroundFriction * weightMultiplier,
      ambulatingGroundFriction = parameters.ambulatingGroundFriction * weightMultiplier,
      airJumpProfile = {jumpControlForce = parameters.airJumpProfile.jumpControlForce * weightMultiplier},
      liquidJumpProfile = {jumpControlForce = parameters.liquidJumpProfile.jumpControlForce * weightMultiplier}
    }
    -- Apply hitbox if we don't have the disable option checked, or we're a size that modifies our height.
    if size.yOffset or not starPounds.hasOption("disableHitbox") then
      starPounds.controlParameters = sb.jsonMerge(starPounds.controlParameters, (size.controlParameters[starPounds.getVisualSpecies()] or size.controlParameters.default))
    end
  end
  mcontroller.controlModifiers((not starPounds.controlModifiersAlt or starPounds.mcontroller.groundMovement) and starPounds.controlModifiers or starPounds.controlModifiersAlt)
  mcontroller.controlParameters(starPounds.controlParameters)
end

starPounds.createStatuses = function()
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't recreate if we can't add statuses anyway.
  if status.statPositive("statusImmunity") then return end
  status[((storage.starPounds.pred or not status.resourcePositive("health")) and "set" or "clear").."PersistentEffects"]("starpoundseaten", {
    {stat = "statusImmunity", effectiveMultiplier = 0}
  })
  status[((storage.starPounds.pred or not status.resourcePositive("health")) and "add" or "remove").."EphemeralEffect"]("starpoundseaten")
end

starPounds.setOptionsMultipliers = function(options)
  storage.starPounds.optionMultipliers = {}
  for _, option in ipairs(options) do
    if option.statModifiers and starPounds.hasOption(option.name) then
      for _, statModifier in ipairs(option.statModifiers) do
        storage.starPounds.optionMultipliers[statModifier[1]] = (storage.starPounds.optionMultipliers[statModifier[1]] or 1) + statModifier[2]
      end
    end
  end
end

starPounds.getOptionsMultiplier = function(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return storage.starPounds.optionMultipliers[stat] or 1
end

starPounds.setOptionsOverrides = function(options)
  storage.starPounds.optionOverrides = {}
  for _, option in ipairs(options) do
    if option.statOverrides and starPounds.hasOption(option.name) then
      for _, statOverride in ipairs(option.statOverrides) do
        storage.starPounds.optionOverrides[statOverride[1]] = statOverride[2]
      end
    end
  end
end

starPounds.getOptionsOverride = function(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return storage.starPounds.optionOverrides[stat] or nil
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
  starPounds.events:fire("main:statChange", "setOption")
  -- This is stupid, but prevents 'null' data being saved.
  if getmetatable(storage.starPounds.options) then
    getmetatable(storage.starPounds.options).__nils = {}
  end
  starPounds.backup()
  return storage.starPounds.options[option]
end

starPounds.getStat = function(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  if not starPounds.stats[stat] then return 0 end
  -- Only recalculate per tick, otherwise use the cached value. (starPounds.statCache gets reset every tick)
  if not starPounds.statCache[stat] then
    -- Default amount (or 1, so we can boost stats that start at 0), modified by accessory values.
    local accessoryBonus = (starPounds.stats[stat].base ~= 0 and starPounds.stats[stat].base or 1) * starPounds.getAccessoryModifiers(stat)
    -- Base stat + Skill bonuses + Accessory bonuses.
    local statAmount = starPounds.stats[stat].base + starPounds.getSkillBonus(stat) + accessoryBonus
    -- Trait multiplier and effect multiplier.
    statAmount = statAmount * starPounds.getTraitMultiplier(stat) * starPounds.getEffectMultiplier(stat)
    -- Trait bonus and effect bonus
    statAmount = statAmount + starPounds.getTraitBonus(stat) + starPounds.getEffectBonus(stat)
    -- Status effect multipliers and bonuses.
    statAmount = statAmount * starPounds.getStatusEffectMultiplier(stat) + starPounds.getStatusEffectBonus(stat)
    -- Option multipliers.
    statAmount = starPounds.getOptionsOverride(stat) or (statAmount * starPounds.getOptionsMultiplier(stat))
    -- Cap the stat between 0 and it's maxValue.
    starPounds.statCache[stat] = math.max(math.min(statAmount, starPounds.stats[stat].maxValue or math.huge), starPounds.stats[stat].minValue or 0)
  end

  return starPounds.statCache[stat]
end

starPounds.getSkillUnlockedLevel = function(skill)
  -- Argument sanitisation.
  skill = tostring(skill)
  return math.min(storage.starPounds.skills[skill] and storage.starPounds.skills[skill][2] or 0, starPounds.skills[skill] and (starPounds.skills[skill].levels or 1) or 0)
end

starPounds.hasUnlockedSkill = function(skill, level)
  -- Argument sanitisation.
  skill = tostring(skill)
  level = tonumber(level) or 1
  return (starPounds.getSkillUnlockedLevel(skill) >= level)
end

starPounds.getSkillLevel = function(skill)
  -- Argument sanitisation.
  skill = tostring(skill)
  return math.min(storage.starPounds.skills[skill] and storage.starPounds.skills[skill][1] or 0, starPounds.skills[skill] and (starPounds.skills[skill].levels or 1) or 0)
end

starPounds.hasSkill = function(skill, level)
  -- Argument sanitisation.
  skill = tostring(skill)
  level = tonumber(level) or 1
  -- Legacy mode disables skills.
  return (starPounds.getSkillLevel(skill) >= level) and not starPounds.hasOption("legacyMode")
end

starPounds.upgradeSkill = function(skill, cost)
  -- Argument sanitisation.
  skill = tostring(skill)
  cost = tonumber(cost) or 0
  storage.starPounds.skills[skill] = storage.starPounds.skills[skill] or jarray()
  if starPounds.getSkillUnlockedLevel(skill) == starPounds.getSkillLevel(skill) then
    storage.starPounds.skills[skill][1] = math.min(starPounds.getSkillUnlockedLevel(skill) + 1, starPounds.skills[skill].levels or 1)
  end
  storage.starPounds.skills[skill][2] = math.min(starPounds.getSkillUnlockedLevel(skill) + 1, starPounds.skills[skill].levels or 1)

  local experienceConfig = starPounds.moduleFunc("experience", "config")
  local experienceProgress = storage.starPounds.experience/(experienceConfig.experienceAmount * (1 + storage.starPounds.level * experienceConfig.experienceIncrement))
  storage.starPounds.level = math.max(storage.starPounds.level - math.round(cost), 0)
  storage.starPounds.experience = math.round(experienceProgress * experienceConfig.experienceAmount * (1 + storage.starPounds.level * experienceConfig.experienceIncrement))
  starPounds.moduleFunc("experience", "add")
  starPounds.parseSkills()
  starPounds.parseStats()
  starPounds.events:fire("main:statChange", "upgradeSkill")
end

starPounds.forceUnlockSkill = function(skill, level)
  -- Argument sanitisation.
  skill = tostring(skill)
  level = tonumber(level)
  -- Need a level to do anything here.
  if not level then return end
  -- If we're forcing the skill, also increase the unlocked level (and initialise it).
  if starPounds.skills[skill] then
    storage.starPounds.skills[skill] = storage.starPounds.skills[skill] or jarray()
    storage.starPounds.skills[skill][1] = math.max(level, starPounds.getSkillLevel(skill))
    storage.starPounds.skills[skill][2] = math.max(level, starPounds.getSkillUnlockedLevel(skill))
  end
  starPounds.parseSkills()
  starPounds.parseStats()
  -- Update stats if we're already up and running.
  if starPounds.currentSize then
    starPounds.events:fire("main:statChange", "forceUnlockSkill")
  end
end

starPounds.setSkill = function(skill, level)
  -- Argument sanitisation.
  skill = tostring(skill)
  level = tonumber(level)
  -- Need a level to do anything here.
  if not level then return end
  -- Skip if there's no such skill.
  if not storage.starPounds.skills[skill] then return end
  if starPounds.getSkillUnlockedLevel(skill) > 0 then
    storage.starPounds.skills[skill][1] = math.max(math.min(level, starPounds.getSkillUnlockedLevel(skill)), 0)
  end
  starPounds.parseSkills()
  starPounds.parseStats()
  starPounds.events:fire("main:statChange", "setSkill")
end

starPounds.parseStats = function()
  -- Skill stats
  storage.starPounds.stats = {}
  for skillName in pairs(storage.starPounds.skills) do
    local skill = starPounds.skills[skillName]
    if skill.type == "addStat" then
      storage.starPounds.stats[skill.stat] = (storage.starPounds.stats[skill.stat] or 0) + (skill.amount * starPounds.getSkillLevel(skillName))
    elseif skill.type == "subtractStat" then
      storage.starPounds.stats[skill.stat] = (storage.starPounds.stats[skill.stat] or 0) - (skill.amount * starPounds.getSkillLevel(skillName))
    end
    if storage.starPounds.stats[skill.stat] == 0 then
      storage.starPounds.stats[skill.stat] = nil
    end
  end
  -- Trait Stats
  starPounds.traitStats = {}
  local selectedTrait = starPounds.traits[starPounds.getTrait() or "default"]
  local speciesTrait = starPounds.traits[starPounds.getSpecies()] or starPounds.traits.default
  for _, trait in ipairs({speciesTrait, selectedTrait}) do
    for _, stat in ipairs(trait.stats or jarray()) do
      starPounds.traitStats[stat[1]] = starPounds.traitStats[stat[1]] or {0, 1}
      if stat[2] == "add" then
        starPounds.traitStats[stat[1]][1] = starPounds.traitStats[stat[1]][1] + stat[3]
      elseif stat[2] == "sub" then
        starPounds.traitStats[stat[1]][1] = starPounds.traitStats[stat[1]][1] - stat[3]
      elseif stat[2] == "mult" then
        starPounds.traitStats[stat[1]][2] = starPounds.traitStats[stat[1]][2] * stat[3]
      end
    end
  end
  -- Effect stats
  starPounds.effectStats = {}
  for effectName, effectData in pairs(storage.starPounds.effects) do
    local effectConfig = starPounds.effects[effectName]
    if effectConfig then
      for _, stat in ipairs(effectConfig.stats or jarray()) do
        starPounds.effectStats[stat[1]] = starPounds.effectStats[stat[1]] or {0, 1}
        if stat[2] == "add" then
          starPounds.effectStats[stat[1]][1] = starPounds.effectStats[stat[1]][1] + stat[3] + (effectData.level - 1) * (stat[4] or 0)
        elseif stat[2] == "sub" then
          starPounds.effectStats[stat[1]][1] = starPounds.effectStats[stat[1]][1] - (stat[3] + (effectData.level - 1) * (stat[4] or 0))
        elseif stat[2] == "mult" then
          starPounds.effectStats[stat[1]][2] = starPounds.effectStats[stat[1]][2] * stat[3] + (effectData.level - 1) * (stat[4] or 0)
        end
      end
    end
  end

  starPounds.events:fire("main:statChange", "parseStats")
  starPounds.backup()
end

starPounds.parseSkills = function()
  for skill in pairs(storage.starPounds.skills) do
    -- Remove the skill if it doesn't exist.
    if not starPounds.skills[skill] then
      storage.starPounds.skills[skill] = nil
    else
      -- Cap skills at their maximum possible level.
      storage.starPounds.skills[skill][2] = math.min(starPounds.skills[skill].levels or 1, storage.starPounds.skills[skill][2])
      storage.starPounds.skills[skill][1] = math.min(storage.starPounds.skills[skill][1], storage.starPounds.skills[skill][2])
    end
  end
  -- This is stupid, but prevents 'null' data being saved.
  getmetatable(storage.starPounds.skills).__nils = {}
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
    starPounds.forceUnlockSkill(skill[1], skill[2])
  end
  -- Set trait starting values. Done a bit weirdly so it still applies when the mod is off.
  storage.starPounds.weight = math.max(storage.starPounds.weight, selectedTrait.weight)
  starPounds.setWeight(storage.starPounds.weight)
  -- Give trait milk
  storage.starPounds.breasts = math.max(storage.starPounds.breasts, selectedTrait.breasts)
  starPounds.moduleFunc("breasts", "setMilk", storage.starPounds.breasts)
  -- Give trait experience.
  storage.starPounds.level = storage.starPounds.level + selectedTrait.experience
  -- Give trait items to players.
  if starPounds.type == "player" then
    for _, item in ipairs(selectedTrait.items) do
      player.giveItem(item)
    end
  end
  -- Refresh stats.
  starPounds.parseStats()
  -- Set the trait successfully.
  return true
end

starPounds.resetTrait = function()
  storage.starPounds.trait = nil
  -- Refresh stats.
  starPounds.parseStats()
end

starPounds.effect = setmetatable({}, { __index = starPounds.module })
function starPounds.effect:new()
  -- Effects are effectively just timed modules.
  local newEffect = starPounds.module:new("effect")
  setmetatable(newEffect, { __index = self })
  return newEffect
end

function starPounds.effect:apply() end -- Runs whenever the effect gets applied, or reapplied.
function starPounds.effect:expire() end -- Runs whenever the effect times out, or gets removed.

starPounds.updateEffects = function(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  starPounds.effectTimer = math.max((starPounds.effectTimer or 0) - dt, 0)
  -- Update effect durations.
  if starPounds.effectTimer == 0 then
    for effectName, effect in pairs(storage.starPounds.effects) do
      local effectData = storage.starPounds.effects[effectName]
      if effectData.duration then
        effectData.duration = math.max(effectData.duration - starPounds.settings.effectTimer, 0)
        if effectData.duration == 0 then
          local effectConfig = starPounds.effects[effectName]
          if effectConfig.expirePerLevel and (effectData.level > 1) then
            effectData.level = effectData.level - 1
            effectData.duration = effectConfig.duration
            starPounds.parseStats()
          else
            starPounds.removeEffect(effectName)
          end
        end
      end
    end
    starPounds.effectTimer = starPounds.settings.effectTimer
  end
end

starPounds.loadScriptedEffect = function(effect)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  effect = tostring(effect)
  local effectConfig = starPounds.effects[effect]
  if effectConfig then
    if effectConfig.script and not starPounds.scriptedEffects[effect] then
      require(effectConfig.script)
      _SBLOADED[effectConfig.script] = nil
      util.mergeTable(storage.starPounds.effects[effect], starPounds.scriptedEffects[effect].data)
      starPounds.scriptedEffects[effect].data = storage.starPounds.effects[effect]
      starPounds.scriptedEffects[effect].config = copy(effectConfig.effectConfig)
      starPounds.scriptedEffects[effect]:moduleInit()
      starPounds.modules[string.format("effect_%s", effect)] = starPounds.scriptedEffects[effect]
      starPounds.modules[string.format("effect_%s", effect)]:setUpdateDelta(effectConfig.scriptDelta or 1)
    end
  end
end

starPounds.effectInit = function()
  starPounds.scriptedEffects = {}
  for effect in pairs(storage.starPounds.effects) do
    starPounds.loadScriptedEffect(effect)
  end
end

starPounds.addEffect = function(effect, duration, level)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  effect = tostring(effect)
  local effectConfig = starPounds.effects[effect]
  local effectData = storage.starPounds.effects[effect] or {}
  if effectConfig then
    duration = tonumber(duration) or effectConfig.duration
    level = tonumber(level) or 1
    -- Negative durations become infinite.
    if duration < 0 then duration = nil end
    if effectConfig.particle then
      local spec = starPounds.settings.particleTemplates.effect
      world.spawnProjectile("invisibleprojectile", vec2.add(starPounds.mcontroller.position, mcontroller.isNullColliding() and 0 or vec2.div(starPounds.mcontroller.velocity, 60)), entity.id(), {0,0}, true, {
        damageKind = "hidden",
        universalDamage = false,
        onlyHitTerrain = true,
        timeToLive = 5/60,
        periodicActions = {
          { action = "loop", time = 0, ["repeat"] = false, count = 5, body = {
            { action = "particle", specification = spec },
            { action = "particle", specification = sb.jsonMerge(spec, {layer = "front"}) }
          }}
        }
      })
      starPounds.moduleFunc("sound", "play", "digest", 0.5, (math.random(120,150)/100))
    end
    effectData.duration = duration and math.max(effectData.duration or 0, duration) or nil
    effectData.level = math.min((effectData.level or 0) + level, effectConfig.levels or 1)
    storage.starPounds.effects[effect] = effectData
    if not (effectConfig.ephemeral or effectConfig.hidden) then
      storage.starPounds.discoveredEffects[effect] = true
    end
    -- Scripted effects.
    if effectConfig.script then
      starPounds.loadScriptedEffect(effect)
      starPounds.scriptedEffects[effect]:apply()
    end

    starPounds.parseStats()
    return true
  end
  return false
end

starPounds.removeEffect = function(effect)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  effect = tostring(effect)
  if storage.starPounds.effects[effect] then
    storage.starPounds.effects[effect] = nil
    starPounds.parseStats()
    if starPounds.scriptedEffects[effect] then
      starPounds.scriptedEffects[effect]:expire()
      starPounds.scriptedEffects[effect] = nil
      starPounds.modules[string.format("effect_%s", effect)] = nil
    end
    return true
  end
  return false
end

starPounds.getEffect = function(effect)
  -- Return empty if the mod is disabled.
  --if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  effect = tostring(effect)
  return storage.starPounds.effects[effect]
end

starPounds.hasDiscoveredEffect = function(effect)
  -- Argument sanitisation.
  effect = tostring(effect)
  return storage.starPounds.discoveredEffects[effect] ~= nil
end

starPounds.resetEffects = function()
  storage.starPounds.effects = {}
  storage.starPounds.discoveredEffects = {}
  starPounds.parseStats()
end

starPounds.getSkillBonus = function(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (storage.starPounds.stats[stat] or 0)
end

starPounds.getTraitMultiplier = function(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (starPounds.traitStats[stat] or {0, 1})[2]
end

starPounds.getTraitBonus = function(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (starPounds.traitStats[stat] or {0, 1})[1]
end

starPounds.getEffectMultiplier = function(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (starPounds.effectStats[stat] or {0, 1})[2]
end

starPounds.getEffectBonus = function(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (starPounds.effectStats[stat] or {0, 1})[1]
end

starPounds.getStatusEffectMultiplier = function(stat)
  return 1
end

starPounds.getStatusEffectBonus = function(stat)
  return 0
end

starPounds.getAccessory = function()
  if storage.starPounds.accessory then
    return root.createItem(storage.starPounds.accessory)
  end
end

starPounds.getAccessoryModifiers = function(stat)
  -- Argument sanitisation.
  stat = stat and tostring(stat) or nil
  if not stat then
    local accessoryModifiers = {}
    local accessory = starPounds.getAccessory()
    if accessory then
      for _, stat in pairs(configParameter(accessory, "stats", {})) do
        if starPounds.stats[stat.name] then
          accessoryModifiers[stat.name] = math.round((accessoryModifiers[stat.name] or 0) + stat.modifier, 3)
        end
      end
    end
    return accessoryModifiers
  else
    return starPounds.accessoryModifiers[stat] or 0
  end
end

starPounds.setAccessory = function(item)
  -- Argument sanitisation.
  if item and type(item) ~= "table" then
    item = tostring(item)
  end
  storage.starPounds.accessory = item and root.createItem(item) or nil
  starPounds.accessoryModifiers = starPounds.getAccessoryModifiers()
  starPounds.events:fire("main:statChange", "setAccessory")
  starPounds.backup()
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

starPounds.feed = function(amount, foodType)
  -- Runs eat, but adapts for player food.
  -- Use this rather than eat() unless we don't care about the hunger bar for some reason.

  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  -- Don't do anything if there's no food.
  if amount == 0 then return end
  if not storage.starPounds.enabled then
    if status.isResource("food") then
      status.giveResource("food", amount)
    end
  else
    starPounds.eat(amount, foodType)
  end
end

starPounds.eat = function(amount, foodType)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  foodType = foodType and tostring(foodType) or "default"
  if not starPounds.foods[foodType] then foodType = "default" end
  -- Don't do anything if there's no food.
  if amount == 0 then return end
  -- Food type capacity cap.
  local maxCapacity = math.huge
  if starPounds.foods[foodType].maxCapacity then
    maxCapacity = starPounds.stomach.capacity * (starPounds.foods[foodType].maxCapacity / starPounds.foods[foodType].multipliers.capacity)
  end
  -- Stats that affect the amount gained.
  if starPounds.foods[foodType].amountStats then
    for _, stat in pairs(starPounds.foods[foodType].amountStats) do
      amount = math.max(amount * starPounds.getStat(stat), 0)
    end
  end
  -- Insert food into stomach.
  amount = math.round(amount, 3)
  storage.starPounds.stomachContents[foodType] = math.min((storage.starPounds.stomachContents[foodType] or 0) + amount, maxCapacity)
end

starPounds.gainWeight = function(amount, fullAmount)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return 0 end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  -- Don't do anything if weight gain is disabled.
  if starPounds.hasOption("disableGain") then return end
  -- Increase weight by amount.
  amount = math.min(amount * (fullAmount and 1 or starPounds.getStat("weightGain")), starPounds.settings.maxWeight - storage.starPounds.weight)
  starPounds.setWeight(storage.starPounds.weight + amount)
  return amount
end

starPounds.loseWeight = function(amount, fullAmount)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return 0 end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  -- Don't do anything if weight loss is disabled.
  if starPounds.hasOption("disableLoss") then return end
  -- Decrease weight by amount (min: 0)
  amount = math.min(amount * (fullAmount and 1 or starPounds.getStat("weightLoss")), storage.starPounds.weight)
  starPounds.setWeight(storage.starPounds.weight - amount)
  return amount
end

starPounds.setWeight = function(amount)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  -- Set weight, rounded to 4 decimals.
  amount = math.round(amount, 4)
  storage.starPounds.weight = math.max(math.min(amount, starPounds.settings.maxWeight), starPounds.sizes[(starPounds.getSkillLevel("minimumSize") + 1)].weight)
end

starPounds.messageHandlers = function()
  -- Handler for enabling the mod.
  message.setHandler("starPounds.toggleEnable", localHandler(starPounds.toggleEnable))
  -- Handler for grabbing data.
  message.setHandler("starPounds.getData", simpleHandler(starPounds.getData))
  message.setHandler("starPounds.isEnabled", simpleHandler(starPounds.isEnabled))
  message.setHandler("starPounds.getDirectives", simpleHandler(starPounds.getDirectives))
  message.setHandler("starPounds.getVisualSpecies", simpleHandler(starPounds.getVisualSpecies))
  -- Handlers for skills/stats/options
  message.setHandler("starPounds.hasOption", simpleHandler(starPounds.hasOption))
  message.setHandler("starPounds.setOption", localHandler(starPounds.setOption))
  message.setHandler("starPounds.upgradeSkill", simpleHandler(starPounds.upgradeSkill))
  message.setHandler("starPounds.getStat", simpleHandler(starPounds.getStat))
  message.setHandler("starPounds.parseStats", simpleHandler(starPounds.parseStats))
  message.setHandler("starPounds.parseStatusEffectStats", simpleHandler(starPounds.parseStatusEffectStats))
  message.setHandler("starPounds.getSkillLevel", simpleHandler(starPounds.getSkillLevel))
  message.setHandler("starPounds.hasSkill", simpleHandler(starPounds.hasSkill))
  message.setHandler("starPounds.getAccessory", simpleHandler(starPounds.getAccessory))
  message.setHandler("starPounds.getAccessoryModifiers", simpleHandler(starPounds.getAccessoryModifiers))
  message.setHandler("starPounds.getTrait", simpleHandler(starPounds.getTrait))
  message.setHandler("starPounds.setTrait", localHandler(starPounds.setTrait))
  message.setHandler("starPounds.addEffect", simpleHandler(starPounds.addEffect))
  message.setHandler("starPounds.removeEffect", simpleHandler(starPounds.removeEffect))
  message.setHandler("starPounds.getEffect", localHandler(starPounds.getEffect))
  message.setHandler("starPounds.hasDiscoveredEffect", localHandler(starPounds.hasDiscoveredEffect))
  -- Handlers for affecting the entity.
  message.setHandler("starPounds.belch", simpleHandler(starPounds.belch))
  message.setHandler("starPounds.belchPitch", simpleHandler(starPounds.belchPitch))
  message.setHandler("starPounds.feed", simpleHandler(starPounds.feed))
  message.setHandler("starPounds.eat", simpleHandler(starPounds.eat))
  message.setHandler("starPounds.gainWeight", simpleHandler(starPounds.gainWeight))
  message.setHandler("starPounds.loseWeight", simpleHandler(starPounds.loseWeight))
  message.setHandler("starPounds.setWeight", simpleHandler(starPounds.setWeight))
  -- Interface/debug stuff.
  message.setHandler("starPounds.reset", localHandler(starPounds.reset))
  message.setHandler("starPounds.resetConfirm", localHandler(starPounds.reset))
  message.setHandler("starPounds.resetWeight", localHandler(starPounds.resetWeight))
  message.setHandler("starPounds.resetStomach", localHandler(starPounds.resetStomach))
  message.setHandler("starPounds.resetBreasts", localHandler(starPounds.resetBreasts))
  message.setHandler("starPounds.resetTrait", localHandler(starPounds.resetTrait))
  message.setHandler("starPounds.resetEffects", localHandler(starPounds.resetEffects))
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
  starPounds.parseSkills()
  starPounds.events:fire("main:statChange", "toggleEnable")
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
  -- Reset to base data.
  storage.starPounds = root.assetJson("/scripts/starpounds/starpounds.config:baseData")
  -- Delete json metadata so we don't store nils.
  setmetatable(storage.starPounds, nil)
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
      starPounds.forceUnlockSkill(skill[1], skill[2])
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

starPounds.resetWeight = function()
  storage.starPounds.weight = starPounds.sizes[(starPounds.getSkillLevel("minimumSize") + 1)].weight
  return true
end

starPounds.resetStomach = function()
  storage.starPounds.stomachContents = {}
  storage.starPounds.stomachEntities = jarray()
  return true
end

starPounds.resetBreasts = function()
  storage.starPounds.breasts = 0
  return true
end

starPounds.backup = function()
  if starPounds.type == "player" then
    player.setProperty("starPoundsBackup", storage.starPounds)
  end
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
