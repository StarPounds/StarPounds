local passiveMilk = starPounds.moduleFunc("effects", "new")

function passiveMilk:init()
  -- Strip stored json nonsense.
  if getmetatable(self.data) then
    setmetatable(self.data, nil)
  end
  -- Only because I'd rather not have mootant NPCs slowly gain cup sizes over time.
  if not starPounds.type == "player" then
    function self:update(dt) end
  end
end

function passiveMilk:update(dt)
  -- Duration is infinite with the trait active.
  if not starPounds.moduleFunc("traits", "hasEffect", "passiveMilk") then
    starPounds.moduleFunc("effects", "remove", "passiveMilk")
  end

  local breasts = starPounds.moduleFunc("breasts", "get")
  local remainingCapacity = math.round(math.max(breasts.maxCapacity - breasts.contents, 0), 4)
  -- Don't bother if we're capped.
  if remainingCapacity == 0 then return end
  -- Slows down based on remaining capacity (up to -75%).
  local baseAmount = math.round(self.config.food * math.max(1 - (breasts.fullness * 0.75), 0.25), 4)
  local milkProduced = math.min(starPounds.moduleFunc("breasts", "milkProduction", baseAmount * dt), remainingCapacity)
  if milkProduced > 0 then
    starPounds.moduleFunc("breasts", "gainMilk", milkProduced)
  end
end
-- Add the effect.
starPounds.modules.effects.effects.passiveMilk = passiveMilk
