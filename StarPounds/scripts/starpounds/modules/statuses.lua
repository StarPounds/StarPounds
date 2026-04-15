local statuses = starPounds.module:new("statuses")

function statuses:init()
  self.statusStats = {}
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
      -- Don't recalculate if we've already done it.
      if self.speciesStats then return self.speciesStats end
  end
end

function statuses:updateStats()
  self.statusStats = {}
  -- Iterate over stats.
  for effectName in pairs(self.activeStatuses) do
    local effectConfig = self.data.statuses[effectName] or {}
    for _, stat in ipairs(effectConfig) do
      self.statusStats[stat[1]] = self.statusStats[stat[1]] or {0, 1}
      if stat[2] == "add" then
        self.statusStats[stat[1]][1] = self.statusStats[stat[1]][1] + stat[3]
      elseif stat[2] == "sub" then
        self.statusStats[stat[1]][1] = self.statusStats[stat[1]][1] - stat[3]
      elseif stat[2] == "mult" then
        self.statusStats[stat[1]][2] = self.statusStats[stat[1]][2] * stat[3]
      elseif stat[2] == "override" then
        self.statusStats[stat[1]][3] = stat[3]
      end
    end
  end
  -- Fire stat change event.
  starPounds.events:fire("stats:calculate", "statuses:updatedStats")
end

function statuses:getStatusEffectMultiplier(stat)
  self.statusStats = self.statusStats or {}
  return (self.statusStats[stat] or {0, 1})[2]
end

function statuses:getStatusEffectBonus(stat)
  self.statusStats = self.statusStats or {}
  return (self.statusStats[stat] or {0, 1})[1]
end

function statuses:getStatusEffectOverride(stat)
  self.statusStats = self.statusStats or {}
  return (self.statusStats[stat] or {0, 1})[3]
end

starPounds.modules.statuses = statuses
