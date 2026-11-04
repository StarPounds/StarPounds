local satiated = starPounds.moduleFunc("effects", "new")

function satiated:init()
  self.data.displayDuration = self.data.duration / self:dtMultiplier()
end

function satiated:update(dt)
  local dtMultiplier = self:dtMultiplier()
  self.data.duration = math.max(self.data.duration - dt * (dtMultiplier - 1), 0)
  self.data.displayDuration = self.data.duration / dtMultiplier
end

function satiated:dtMultiplier()
  local hunger = math.max(starPounds.getStat("hunger") / self.config.hungerMultiplier, 0.001)
  local foodValue = math.max(starPounds.getStat("foodValue"), 0.001)

  return hunger / foodValue
end
-- Add the effect.
starPounds.modules.effects.effects.satiated = satiated
