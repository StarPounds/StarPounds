local pizzaFee = starPounds.moduleFunc("effects", "new")

function pizzaFee:init()
  -- Strip stored json nonsense.
  if getmetatable(self.data) then
    setmetatable(self.data, nil)
  end
  -- Only because I'd rather not have mootant NPCs slowly gain cup sizes over time.
  if not starPounds.type == "player" then
    function self:update(dt) end
  end
end

-- Add the effect.
starPounds.modules.effects.effects.pizzaFee = pizzaFee
