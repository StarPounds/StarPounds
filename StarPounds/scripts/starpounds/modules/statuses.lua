local statuses = starPounds.module:new("statuses")

function statuses:init()
  self.bonuses = {}
  self.multipliers = {}
  self.activeStatuses = {}
  -- Trigger an update straight away.
  self:update()
end

function statuses:update(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Reset statuses if we're immune.
  if status.statPositive("statusImmunity") then
    if not self.statusImmune then
      self.activeStatuses = {}
      self:updateStats()
      self.statusImmune = true
    end
    return
  end

  self.statusImmune = false

  -- Iterate to find statuses that can affect stats.
  local updateStats = false
  for effectName in pairs(self.data.statuses) do
    local active = status.uniqueStatusEffectActive(effectName)
    updateStats = updateStats or (active ~= not not self.activeStatuses[effectName])
    -- Set this to nil when it's inactive so we don't iterate over it.
    self.activeStatuses[effectName] = active or nil
  end
  -- Only recalculate stat values if we need to.
  if updateStats then
    self:updateStats()
  end
end

function statuses:updateStats()
  self.bonuses = {}
  self.multipliers = {}

  for effectName in pairs(self.activeStatuses) do
    local effectConfig = self.data.statuses[effectName] or {}
    -- Bonuses.
    for stat, bonus in pairs(effectConfig.bonuses or {}) do
      local currentBonus = self.bonuses[stat] or 0
      self.bonuses[stat] = currentBonus + bonus
    end
    -- Multipliers.
    for stat, multiplier in pairs(effectConfig.multipliers or {}) do
      local currentMultiplier = self.multipliers[stat] or 1
      self.multipliers[stat] = currentMultiplier * multiplier
    end
  end
  -- Fire stat change event.
  starPounds.events:fire("stats:calculate", "statuses:updatedStats")
end

-- Overwrite stub functions.
function statuses:getStatusEffectMultiplier(stat)
  if not self.multipliers then self.multipliers = {} end
  return self.multipliers[stat] or 1
end

function statuses:getStatusEffectBonus(stat)
  if not self.bonuses then self.bonuses = {} end
  return self.bonuses[stat] or 0
end

starPounds.modules.statuses = statuses
