local experience = starPounds.module:new("experience")

function experience:init()
  message.setHandler("starPounds.experience.add", function(_, _, ...) return self:add(...) end)

  self:add(0)

  self.buffer = self.buffer or 0
  self.popupTimer = 0
  self.oldLevel = storage.starPounds.experience.level

  starPounds.level = storage.starPounds.experience.level
  starPounds.experience = storage.starPounds.experience.amount
end

function experience:update(dt)
  starPounds.level = storage.starPounds.experience.level
  starPounds.experience = storage.starPounds.experience.amount
  -- If we spend XP or reset, then this needs to adjust.
  if self.oldLevel > storage.starPounds.experience.level then
    self.oldLevel = storage.starPounds.experience.level
  end
  -- Popup message.
  if self.popupTimer > 0 then
    self.popupTimer = math.max(self.popupTimer - dt, 0)
    if self.popupTimer == 0 then
      local diff = storage.starPounds.experience.level - self.oldLevel
      if diff > 0 and not starPounds.hasOption("disablePopupMessages") then
        local text = diff > 1 and self.data.levelMessages[2] or self.data.levelMessages[1]
        starPounds.moduleFunc("oSB", "addPopupMessage", string.format(text, diff, storage.starPounds.experience.level))
      end
      self.oldLevel = storage.starPounds.experience.level
    end
  end
end

function experience:add(amount, multiplier, isLevel)
  if not storage.starPounds.enabled then return end
  -- Legacy mode gains no experience.
  if starPounds.hasOption("legacyMode") then return end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  multiplier = tonumber(multiplier) or math.max(starPounds.getStat("experienceMultiplier") - self:hungerPenalty(), 0)
  -- Start timer for a popup.
  if amount > 0 then
    self.popupTimer = self.data.popupTime
  end
  -- Skip everything else if we're just adding straight levels.
  if isLevel then
    self:addLevel(amount)
    return
  end
  -- Keep this for amounts lost by rounding.
  local baseAmount = amount * multiplier
  local levelModifier = 1 + storage.starPounds.experience.level * self.data.experienceIncrement
  local addedAmount = math.floor(baseAmount)
  local amountRequired = math.round(self.data.experienceAmount * levelModifier - storage.starPounds.experience.amount)
  if addedAmount < amountRequired then
    storage.starPounds.experience.amount = math.round(storage.starPounds.experience.amount + addedAmount)
  elseif storage.starPounds.experience.level >= self.data.maximumLevel then
    storage.starPounds.experience.level = self.data.maximumLevel
    storage.starPounds.experience.amount = self.data.experienceAmount * levelModifier
  else
    -- Loop until no experience is left.
    local levelsGained = 0
    while addedAmount >= amountRequired do
      addedAmount = addedAmount - amountRequired
      baseAmount = baseAmount - amountRequired
      levelsGained = levelsGained + 1
      -- Stop calculating if we hit max level.
      if (storage.starPounds.experience.level + levelsGained) >= self.data.maximumLevel then
        break
      end
      -- Grab amount for next level.
      local nextLevelModifier = 1 + (storage.starPounds.experience.level + levelsGained) * self.data.experienceIncrement
      amountRequired = math.round(self.data.experienceAmount * nextLevelModifier)
    end
    -- Reset current experience and apply the total levels gained all at once
    storage.starPounds.experience.amount = 0
    self:addLevel(levelsGained)
    -- Capped experience.
    if storage.starPounds.experience.level >= self.data.maximumLevel then
      local finalLevelModifier = 1 + self.data.maximumLevel * self.data.experienceIncrement
      storage.starPounds.experience.amount = self.data.experienceAmount * finalLevelModifier
      -- Remove overflows if we hit the cap.
      addedAmount = 0
      baseAmount = 0
    else
      -- Add back left over experience.
      storage.starPounds.experience.amount = addedAmount
    end
  end
  -- Store amounts removed by rounding, add them back once it becomes a whole number.
  self.buffer = (self.buffer or 0) + math.max(baseAmount - addedAmount, 0)
  if self.buffer >= 1 then
    local bufferAmount = math.floor(self.buffer)
    self.buffer = self.buffer - bufferAmount
    self:add(bufferAmount, 1)
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
  storage.starPounds.experience.level = math.min(storage.starPounds.experience.level + amount, self.data.maximumLevel)
end

function experience:removeLevel(amount)
  amount = math.round(math.max(tonumber(amount) or 0, 0))
  storage.starPounds.experience.level = math.max(storage.starPounds.experience.level - amount, 0)
end

function experience:hungerPenalty()
  if starPounds.hasOption("disableHunger") then
    return math.max((starPounds.getStat("hunger") - starPounds.moduleFunc("stats", "getRaw", "hunger").base) * 0.2, 0)
  end

  return 0
end

starPounds.modules.experience = experience
