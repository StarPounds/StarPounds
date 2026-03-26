local preyStruggleExperience = starPounds.moduleFunc("effects", "new")

function preyStruggleExperience:init()
  -- Strip stored json nonsense.
  if getmetatable(self.data) then
    setmetatable(self.data, nil)
  end


  starPounds.events:on("pred:struggle", self.struggle)
end

function preyStruggleExperience.struggle(strength)
  local self = preyStruggleExperience
  starPounds.moduleFunc("experience", "add", math.round(strength * self.config.experience, 2))
end

function preyStruggleExperience:update(dt)
  -- Duration is infinite with the trait active.
  if not starPounds.moduleFunc("traits", "hasEffect", "preyStruggleExperience") then
    starPounds.moduleFunc("effects", "remove", "preyStruggleExperience")
  end
end

function preyStruggleExperience:uninit()
  starPounds.events:off("pred:struggle", self.struggle)
end

function preyStruggleExperience:expire()
  self:uninit()
end
-- Add the effect.
starPounds.modules.effects.effects.preyStruggleExperience = preyStruggleExperience
