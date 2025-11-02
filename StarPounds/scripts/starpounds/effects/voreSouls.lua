local voreSouls = starPounds.moduleFunc("effects", "new")

function voreSouls:init()
  if getmetatable(self.data) then
    getmetatable(self.data).__nils = {}
  end
end

function voreSouls:update(dt)
  -- Duration is infinite with the skill active.
  if starPounds.moduleFunc("skills", "has", "voreSouls") then
    if self.data.duration then
      self.data.lastDuration = self.data.duration
      self.data.duration = nil
    end
  elseif not self.data.duration then
    self.data.duration = self.data.lastDuration
    self.data.lastDuration = nil
  end
end

function voreSouls:uninit()
  -- Can't trigger this in the respawn module, since the effects module gets unloaded (and deletes this effect) before.
  if not status.resourcePositive("health") then
    local soulsLost = math.ceil(self.data.level * starPounds.getStat("deathPenalty"))
    self.data.level = math.max(self.data.level - soulsLost, 0)
    if self.data.level == 0 then
      starPounds.moduleFunc("effects", "remove", "voreSouls")
    end
  end
end
-- Add the effect.
starPounds.modules.effects.effects.voreSouls = voreSouls
