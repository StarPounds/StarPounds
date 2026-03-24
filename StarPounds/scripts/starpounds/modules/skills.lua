local skills = starPounds.module:new("skills")

function skills:init()
  message.setHandler("starPounds.upgradeSkill", function(_, _, ...) return self:upgrade(...) end)
  message.setHandler("starPounds.getSkillLevel", function(_, _, ...) return self:level(...) end)
  message.setHandler("starPounds.hasSkill", function(_, _, ...) return self:has(...) end)

  self:parse()
end

function skills:getSkillList()
  return self.data.skills
end

function skills:unlockedLevel(skill)
  -- Argument sanitisation.
  skill = tostring(skill)
  return math.min(storage.starPounds.skills[skill] and storage.starPounds.skills[skill][2] or 0, self.data.skills[skill] and (self.data.skills[skill].levels or 1) or 0)
end

function skills:hasUnlocked(skill, level)
  -- Argument sanitisation.
  skill = tostring(skill)
  level = tonumber(level) or 1
  return (self:unlockedLevel(skill) >= level)
end

function skills:level(skill)
  -- Argument sanitisation.
  skill = tostring(skill)
  return math.min(storage.starPounds.skills[skill] and storage.starPounds.skills[skill][1] or 0, self.data.skills[skill] and (self.data.skills[skill].levels or 1) or 0)
end

function skills:has(skill, level)
  -- Argument sanitisation.
  skill = tostring(skill)
  level = tonumber(level) or 1
  -- Legacy mode disables skills.
  return (self:level(skill) >= level) and not starPounds.hasOption("legacyMode")
end

function skills:upgrade(skill)
  -- Argument sanitisation.
  skill = tostring(skill)
  storage.starPounds.skills[skill] = storage.starPounds.skills[skill] or jarray()
  if self:unlockedLevel(skill) == self:level(skill) then
    storage.starPounds.skills[skill][1] = math.min(self:unlockedLevel(skill) + 1, self.data.skills[skill].levels or 1)
  end
  storage.starPounds.skills[skill][2] = math.min(self:unlockedLevel(skill) + 1, self.data.skills[skill].levels or 1)

  self:parse()
  starPounds.events:fire("stats:calculate", "upgradeSkill")
end

function skills:upgradeCost(skill, startLevel, endLevel)
  local skillConfig = self.data.skills[skill]
  if not skillConfig then return 0 end

  local levels = skillConfig.levels or 1

  local base = skillConfig.cost.base or 0
  local increase = skillConfig.cost.increase or 0
  local maxCost = skillConfig.cost.max or math.huge

  startLevel = math.min(math.max(startLevel, 0), levels)
  endLevel = math.min(math.max(endLevel, startLevel), levels)

  if startLevel == endLevel then return 0 end

  -- Level where cost hits max.
  local cappedLevel = math.ceil((maxCost - base) / increase)

  local cost = 0
  -- Cost of the skill while cost is increasing.
  local increaseEnd = math.min((endLevel - 1), cappedLevel - 1)
  if startLevel <= increaseEnd then
    local n = increaseEnd - startLevel + 1
    local first = base + increase * startLevel
    local last = base + increase * increaseEnd
    cost = cost + (n * (first + last)) / 2
  end
  -- Cost of the skill once max has been hit.
  local flatStart = math.max(startLevel, cappedLevel)
  if flatStart <= (endLevel - 1) then
    local n = (endLevel - 1) - flatStart + 1
    cost = cost + n * maxCost
  end

  return math.floor(cost)
end

function skills:forceUnlock(skill, level)
  -- Argument sanitisation.
  skill = tostring(skill)
  level = tonumber(level)
  -- Need a level to do anything here.
  if not level then return end
  -- If we're forcing the skill, also increase the unlocked level (and initialise it).
  if self.data.skills[skill] then
    storage.starPounds.skills[skill] = storage.starPounds.skills[skill] or jarray()
    storage.starPounds.skills[skill][1] = math.max(level, self:level(skill))
    storage.starPounds.skills[skill][2] = math.max(level, self:unlockedLevel(skill))
  end
  self:parse()
  -- Update stats if we're already up and running.
  if starPounds.currentSize then
    starPounds.events:fire("stats:calculate", "forceUnlockSkill")
  end
end

function skills:set(skill, level)
  -- Argument sanitisation.
  skill = tostring(skill)
  level = tonumber(level)
  -- Need a level to do anything here.
  if not level then return end
  -- Skip if there's no such skill.
  if not storage.starPounds.skills[skill] then return end
  if self:unlockedLevel(skill) > 0 then
    storage.starPounds.skills[skill][1] = util.clamp(level, 0, self:unlockedLevel(skill))
  end
  self:parse()
  starPounds.events:fire("stats:calculate", "setSkill")
end

function skills:parse()
  for skill in pairs(storage.starPounds.skills) do
    -- Remove the skill if it doesn't exist.
    if not self.data.skills[skill] then
      storage.starPounds.skills[skill] = nil
    else
      -- Cap skills at their maximum possible level.
      storage.starPounds.skills[skill][2] = math.min(self.data.skills[skill].levels or 1, storage.starPounds.skills[skill][2])
      storage.starPounds.skills[skill][1] = math.min(storage.starPounds.skills[skill][1], storage.starPounds.skills[skill][2])
    end
  end
  -- This is stupid, but prevents 'null' data being saved.
  getmetatable(storage.starPounds.skills).__nils = {}
end

-- Add the module.
starPounds.modules.skills = skills
