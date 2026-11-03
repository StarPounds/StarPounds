local satiated = starPounds.moduleFunc("effects", "new")

function satiated:update(dt)
  self.data.duration = math.max(self.data.duration - dt * (self:dtMultiplier() - 1), 0)
end

function satiated:dtMultiplier()
  local hunger = math.max(starPounds.getStat("hunger") / self.config.hungerMultiplier, 0.001)
  local foodValue = math.max(starPounds.getStat("foodValue"), 0.001)

  return hunger / foodValue
end
-- Add the effect.
starPounds.modules.effects.effects.satiated = satiated
