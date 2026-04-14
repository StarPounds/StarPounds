local pizzaFee = starPounds.moduleFunc("effects", "new")

function pizzaFee:get()
  return self.config.fee * self.data.level
end

-- Add the effect.
starPounds.modules.effects.effects.pizzaFee = pizzaFee
