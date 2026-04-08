local shipWorld = starPounds.moduleFunc("effects", "new")

function shipWorld:init()
  -- Strip stored json nonsense.
  if getmetatable(self.data) then
    setmetatable(self.data, nil)
  end

  if not (world.getProperty("ship.level") and starPounds.type == "player") then
    starPounds.moduleFunc("effects", "remove", "shipWorld")
  end
end
-- Add the effect.
starPounds.modules.effects.effects.shipWorld = shipWorld
