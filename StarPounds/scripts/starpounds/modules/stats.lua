local stats = starPounds.module:new("stats")

function stats:init()
  message.setHandler("starPounds.getStat", function(_, _, ...) return self:get(...) end)

  self.cache = {}

  self.skills = starPounds.moduleFunc("skills", "getSkillList")
  self.skillStats = {}
  self.traitStats = {}
  self.effectStats = {}
  self.optionStats = {}
  self.accessoryModifiers = {}

  self:calculate()

  starPounds.events:on("stats:calculate", self.updateEvent)
end

function stats.updateEvent(trace) -- Trace shows you where the 'change' is coming from.
  -- Kill the cache, and force an update to stats.
  local self = stats
  self.cache = {}
  self:calculate()
  starPounds.moduleFunc("size", "updateStats", true)
end

function stats:update(dt)
  self.cache = {}
end

-- I don't feel like editing an absurd amount of files.
starPounds.getStat = function(stat)
  return stats:get(stat)
end

function stats:get(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  if not self.data.stats[stat] then return 0 end
  -- Only recalculate per tick, otherwise use the cached value. (self.cache gets reset every tick)
  if not self.cache[stat] then
    -- Default amount (or 1, so we can boost stats that start at 0), modified by accessory values.
    local accessoryBonus = (self.data.stats[stat].base ~= 0 and self.data.stats[stat].base or 1) * self:accessoryMods(stat)
    -- Base stat + Skill bonuses + Accessory bonuses.
    local statAmount = self.data.stats[stat].base + self:skillBonus(stat) + accessoryBonus
    -- Trait multiplier and effect multiplier.
    statAmount = statAmount * self:traitMult(stat) * self:effectMult(stat)
    -- Trait bonus and effect bonus
    statAmount = statAmount + self:traitBonus(stat) + self:effectBonus(stat)
    -- Status effect multipliers and bonuses.
    statAmount = statAmount * self:statusEffectMult(stat) + self:statusEffectBonus(stat)
    -- Option multipliers, bonuses, and overrides.
    statAmount = self:optionsOverride(stat) or (statAmount * self:optionsMult(stat) + self:optionsBonus(stat))
    -- Cap the stat between 0 and it's maxValue.
    self.cache[stat] = util.clamp(statAmount, self.data.stats[stat].minValue or 0, self.data.stats[stat].maxValue or math.huge)
  end

  return self.cache[stat]
end

function stats:getRaw(stat)
  stat = tostring(stat)
  return self.data.stats[stat]
end

function stats:calculate()
  -- Skill stats.
  self.skillStats = {}
  for skillName in pairs(storage.starPounds.skills) do
    local skill = self.skills[skillName]
    if skill then
      if skill.type == "addStat" then
        self.skillStats[skill.stat] = (self.skillStats[skill.stat] or 0) + (skill.amount * starPounds.moduleFunc("skills", "level", skillName))
      elseif skill.type == "subtractStat" then
        self.skillStats[skill.stat] = (self.skillStats[skill.stat] or 0) - (skill.amount * starPounds.moduleFunc("skills", "level", skillName))
      end
      if self.skillStats[skill.stat] == 0 then
        self.skillStats[skill.stat] = nil
      end
    end
  end
  -- Trait Stats.
  self.traitStats = {}
  local selectedTrait = starPounds.traits[starPounds.getTrait() or "default"]
  local speciesTrait = starPounds.traits[starPounds.getSpecies()] or starPounds.traits.default
  for _, trait in ipairs({speciesTrait, selectedTrait}) do
    for _, stat in ipairs(trait.stats or {}) do
      self.traitStats[stat[1]] = self.traitStats[stat[1]] or {0, 1}
      if stat[2] == "add" then
        self.traitStats[stat[1]][1] = self.traitStats[stat[1]][1] + stat[3]
      elseif stat[2] == "sub" then
        self.traitStats[stat[1]][1] = self.traitStats[stat[1]][1] - stat[3]
      elseif stat[2] == "mult" then
        self.traitStats[stat[1]][2] = self.traitStats[stat[1]][2] * stat[3]
      end
    end
  end
  -- Effect stats.
  self.effectStats = {}
  if starPounds.modules.effects then
    for effectName, effectData in pairs(storage.starPounds.effects.active) do
      local effectConfig = starPounds.moduleFunc("effects", "getConfig", effectName)
      if effectConfig then
        for _, stat in ipairs(effectConfig.stats or {}) do
          self.effectStats[stat[1]] = self.effectStats[stat[1]] or {0, 1}
          if stat[2] == "add" then
            self.effectStats[stat[1]][1] = self.effectStats[stat[1]][1] + stat[3] + (effectData.level - 1) * (stat[4] or 0)
          elseif stat[2] == "sub" then
            self.effectStats[stat[1]][1] = self.effectStats[stat[1]][1] - (stat[3] + (effectData.level - 1) * (stat[4] or 0))
          elseif stat[2] == "mult" then
            self.effectStats[stat[1]][2] = self.effectStats[stat[1]][2] * stat[3] + (effectData.level - 1) * (stat[4] or 0)
          end
        end
      end
    end
  end
  -- Options stats.
  self.optionStats = {}
  for _, optionConfig in ipairs(starPounds.options) do
    if starPounds.hasOption(optionConfig.name) then
      for _, stat in ipairs(optionConfig.stats or {}) do
        self.optionStats[stat[1]] = self.optionStats[stat[1]] or {0, 1}
        if stat[2] == "add" then
          self.optionStats[stat[1]][1] = self.optionStats[stat[1]][1] + stat[3]
        elseif stat[2] == "sub" then
          self.optionStats[stat[1]][1] = self.optionStats[stat[1]][1] - stat[3]
        elseif stat[2] == "mult" then
          self.optionStats[stat[1]][2] = self.optionStats[stat[1]][2] * stat[3]
        elseif stat[2] == "override" then
          self.optionStats[stat[1]][3] = stat[3]
        end
      end
    end
  end

  -- Accessory stats
  self:accessoryMods()

  starPounds.moduleFunc("data", "backup")
end
-- Skills -------------------------------------------------------
function stats:skillBonus(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (self.skillStats[stat] or 0)
end
-- Traits -------------------------------------------------------
function stats:traitMult(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (self.traitStats[stat] or {0, 1})[2]
end

function stats:traitBonus(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (self.traitStats[stat] or {0, 1})[1]
end
-- StarPounds Effects -------------------------------------------
function stats:effectMult(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (self.effectStats[stat] or {0, 1})[2]
end

function stats:effectBonus(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (self.effectStats[stat] or {0, 1})[1]
end
-- Status Effects -----------------------------------------------
function stats:statusEffectMult(stat)
  return starPounds.moduleFunc("statuses", "getStatusEffectMultiplier", stat) or 1
end

function stats:statusEffectBonus(stat)
  return starPounds.moduleFunc("statuses", "getStatusEffectBonus", stat) or 0
end
-- Options ------------------------------------------------------
function stats:optionsMult(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (self.optionStats[stat] or {0, 1})[2]
end

function stats:optionsBonus(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (self.optionStats[stat] or {0, 1})[1]
end

function stats:optionsOverride(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (self.optionStats[stat] or {0, 1})[3]
end
-- Accessories --------------------------------------------------
function stats:accessoryMods(stat)
  -- Argument sanitisation.
  stat = stat and tostring(stat) or nil
  if not stat then
    self.accessoryModifiers = {}
    local accessory = starPounds.moduleFunc("accessories", "get")
    if accessory then
      for _, stat in pairs(configParameter(accessory, "stats", {})) do
        if self.data.stats[stat.name] then
          self.accessoryModifiers[stat.name] = math.round((self.accessoryModifiers[stat.name] or 0) + stat.modifier, 3)
        end
      end
    end
  else
    return self.accessoryModifiers[stat] or 0
  end
end

function stats:uninit()
  starPounds.events:off("stats:calculate", self.updateEvent)
end

starPounds.modules.stats = stats
