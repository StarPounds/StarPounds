local experience = starPounds.module:new("experience")

function experience:init()
  message.setHandler("starPounds.addExperience", function(_, _, ...) return self:add(...) end)

  starPounds.level = storage.starPounds.level
  starPounds.experience = storage.starPounds.experience
end

function experience:update(dt)
  starPounds.level = storage.starPounds.level
  starPounds.experience = storage.starPounds.experience
end

function experience:add(amount, multiplier, isLevel)
  if not storage.starPounds.enabled then return end
  -- Legacy mode gains no experience.
  if starPounds.hasOption("legacyMode") then return end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  multiplier = tonumber(multiplier) or math.max(starPounds.getStat("experienceMultiplier") - self:hungerPenalty(), 0)
  -- Skip everything else if we're just adding straight levels.
  if isLevel then
    self:addLevel(amount)
    return
  end

  local levelModifier = 1 + storage.starPounds.level * self.data.experienceIncrement
  local amount = math.round((amount or 0) * multiplier)
  local amountRequired = math.round(self.data.experienceAmount * levelModifier - storage.starPounds.experience)
  if amount < amountRequired then
    storage.starPounds.experience = math.round(storage.starPounds.experience + amount)
  elseif storage.starPounds.level >= self.data.maxLevel then
    storage.starPounds.level = self.data.maxLevel
    storage.starPounds.experience = self.data.experienceAmount * levelModifier
  else
    amount = amount - amountRequired
    storage.starPounds.experience = 0
    self:add(amount, 1)
    self:addLevel(1)
  end
end

function experience:config()
  return {
    experienceAmount = self.data.experienceAmount,
    experienceIncrement = self.data.experienceIncrement
  }
end

function experience:addLevel(amount)
  amount = math.round(math.max(tonumber(amount) or 0, 0))
  storage.starPounds.level = math.min(storage.starPounds.level + amount, self.data.maxLevel)
end

function experience:hungerPenalty()
  if starPounds.hasOption("disableHunger") then
    return math.max((starPounds.getStat("hunger") - starPounds.stats.hunger.base) * 0.2, 0)
  end

  return 0
end

starPounds.modules.experience = experience
