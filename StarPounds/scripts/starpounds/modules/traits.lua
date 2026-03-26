local traits = starPounds.module:new("traits")

function traits:init()
  message.setHandler("starPounds.getTraits", function(_, _, ...) return self:get(...) end)
  message.setHandler("starPounds.hasTrait", function(_, _, ...) return self:has(...) end)
  message.setHandler("starPounds.addTrait", function(_, _, ...) return self:add(...) end)
  -- This is stupid, but prevents 'null' data being saved.
  getmetatable(storage.starPounds.traits.active).__nils = {}
  getmetatable(storage.starPounds.traits.available).__nils = {}
  getmetatable(storage.starPounds.traits.unlockedSkills).__nils = {}
  -- Reset on reloads/enables.
  self.speciesStats = nil
  -- Cleanup data.
  self:parse()
  -- Don't apply effects on other entities.
  self.applyEffects = (starPounds.type == "player") or (starPounds.type == "npc") or (starPounds.type == "monster")
  -- Create an actual update function.
  if self.applyEffects then
    function self:update(dt)
      for effect in pairs(self.effects) do
        starPounds.moduleFunc("effects", "add", effect, -1)
      end
    end
  end
end

function traits:get()
  self:parse()
  return storage.starPounds.traits.active
end

function traits:getConfig(trait)
  if trait then return self.data.traits[trait] end
  return self.data.traits
end

function traits:getSpeciesTraitList()
  return self.data.speciesTraits
end

function traits:speciesTraits()
  return starPounds.getSpeciesData().traits
end

function traits:speciesTraitStats()
  -- Don't recalculate if we've already done it.
  if self.speciesStats then return self.speciesStats end

  self.speciesStats = {}
  local traitList = self:speciesTraits()
  for _, traitName in ipairs(traitList) do
    local traitConfig = self.data.speciesTraits[traitName]
    if traitConfig then
      for _, stat in ipairs(traitConfig.stats or {}) do
        self.speciesStats[stat[1]] = self.speciesStats[stat[1]] or {0, 1}
        if stat[2] == "add" then
          self.speciesStats[stat[1]][1] = self.speciesStats[stat[1]][1] + stat[3]
        elseif stat[2] == "sub" then
          self.speciesStats[stat[1]][1] = self.speciesStats[stat[1]][1] - stat[3]
        elseif stat[2] == "mult" then
          self.speciesStats[stat[1]][2] = self.speciesStats[stat[1]][2] * stat[3]
        end
      end
    end
  end
  return self.speciesStats
end

function traits:applySpeciesTrait()
  for _, traitName in ipairs(self:speciesTraits()) do
    local trait = self.data.speciesTraits[traitName]
    for _, skill in ipairs(trait.skills or {}) do
      starPounds.moduleFunc("skills", "forceUnlock", skill[1], skill[2])
    end
    -- Give items to players.
    if starPounds.type == "player" and not storage.starPounds.traits.hasSpeciesTraitItems then
      for _, item in ipairs(trait.items or {}) do
        if not trait.itemCheck or not player.hasItem(item) then
          player.giveItem(item)
        end
      end
    end
  end
  -- Store item state so it only happens once. (Species traits get 'reapplied' on load)
  if starPounds.type == "player" then
    storage.starPounds.traits.hasSpeciesTraitItems = true
  end
end

function traits:has(trait)
  -- Argument sanitisation.
  trait = tostring(trait)
  return self.data.traits[trait] and storage.starPounds.traits.active[trait]
end

function traits:add(trait, addSkillCost)
  -- Argument sanitisation.
  trait = tostring(trait)
  -- Don't do anything if the trait doesn't exist.
  local traitName = trait
  local trait = self.data.traits[trait]
  if not trait then return end
  -- Merge defaults.
  trait = sb.jsonMerge(self.data.traits.default, trait)
  -- Set the trait.
  storage.starPounds.traits.active[traitName] = true
  -- Unlock trait skills.
  for _, skill in ipairs(trait.skills) do
    local currentLevel = starPounds.moduleFunc("skills", "unlockedLevel", skill[1])
    local levelIncrease = math.max(skill[2] - currentLevel, 0)
    starPounds.moduleFunc("skills", "forceUnlock", skill[1], skill[2])
    if addSkillCost and levelIncrease > 0 then
      storage.starPounds.traits.unlockedSkills[traitName] = storage.starPounds.traits.unlockedSkills[traitName] or {}
      local storedData = storage.starPounds.traits.unlockedSkills[traitName]
      storedData[skill[1]] = jarray()
      storedData[skill[1]][1] = currentLevel
      storedData[skill[1]][2] = levelIncrease
    end
  end
  -- Give trait items to players.
  if starPounds.type == "player" then
    for _, item in ipairs(trait.items) do
      if not trait.itemCheck or not player.hasItem(item) then
        player.giveItem(item)
      end
    end
  end
  -- Refresh stats.
  self:parse()
  starPounds.events:fire("stats:calculate", "addTrait")
  -- Set the trait successfully.
  return true
end

function traits:remove(trait)
  -- Set the trait.
  storage.starPounds.traits.active[trait] = nil
  storage.starPounds.traits.unlockedSkills[trait] = nil
  self:parse()
  starPounds.events:fire("stats:calculate", "removeTrait")
end

function traits:unlockedSkills(trait)
  if storage.starPounds.traits.unlockedSkills[trait] then
    return storage.starPounds.traits.unlockedSkills[trait]
  end

  return {}
end

function traits:removeCost(trait)
  local cost = 0
  -- Check if it has unlocked skills.
  if storage.starPounds.traits.unlockedSkills[trait] then
    for skillName, levels in pairs(storage.starPounds.traits.unlockedSkills[trait]) do
      cost = cost + starPounds.moduleFunc("skills", "upgradeCost", skillName, levels[1], levels[2])
    end
  end

  return math.floor(cost)
end

function traits:parse()
  -- Cleaner than repeating the same loop 3 times.
  local traitData = {
    storage.starPounds.traits.active, -- Active traits.
    storage.starPounds.traits.available, -- Traits that can be unlocked.
    storage.starPounds.traits.unlockedSkills -- Stored data about what traits have unlocked what skills.
  }

  -- Indexing by keys so we don't have to iterate over the entire table multiple times with contains().
  local selectableTraits = {}
  for _, trait in ipairs(self.data.selectableTraits) do
    selectableTraits[trait] = true
  end

  for _, tbl in ipairs(traitData) do
    for trait in pairs(tbl) do
      -- Remove the trait if it doesn't exist.
      if not self.data.traits[trait] then
        storage.starPounds.traits.active[trait] = nil
        storage.starPounds.traits.available[trait] = nil
        storage.starPounds.traits.unlockedSkills[trait] = nil
      end
      -- Remove the trait from the available list (unlocked through gameplay) if it's available by default.
      if storage.starPounds.traits.available[trait] and selectableTraits[trait] then
        storage.starPounds.traits.available[trait] = nil
      end
    end
  end
  -- Removed stored skill unlocks if those skills don't exist.
  local skills = starPounds.moduleFunc("skills", "getSkillList")
  for traitName, skillList in pairs(storage.starPounds.traits.unlockedSkills) do
    for skillName in pairs(skillList) do
      if not skills[skillName] then
        skillList[skillName] = nil
      end
    end
  end
  -- Update effects to apply.
  self:fetchTraitEffects()
end

function traits:fetchTraitEffects()
  self.effects = {}
  -- Species traits.
  for _, traitName in ipairs(self:speciesTraits()) do
    if self.data.speciesTraits[traitName] then
      for _, effect in ipairs(self.data.speciesTraits[traitName].effects or {}) do
        self.effects[effect] = true
      end
    end
  end
  -- Selected traits.
  for traitName in pairs(storage.starPounds.traits.active) do
    if self.data.traits[traitName] then
      for _, effect in ipairs(self.data.traits[traitName].effects or {}) do
        self.effects[effect] = true
      end
    end
  end
  -- Return in case this gets called by moduleFunc.
  return self.effects
end

function traits:hasEffect(effect)
  return not not self.effects[effect]
end

function traits:reset()
  storage.starPounds.traits = {active = {}, available = {}, unlockedSkills = {}}
  -- Refresh stats.
  self:parse()
  starPounds.events:fire("stats:calculate", "resetTraits")
end

function traits:uninit()
end

starPounds.modules.traits = traits
