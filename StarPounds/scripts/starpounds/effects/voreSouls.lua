local voreSouls = starPounds.moduleFunc("effects", "new")

function voreSouls:init()
  if getmetatable(self.data) then
    getmetatable(self.data).__nils = {}
  end

  starPounds.events:on("pred:digestEntity", self.digestEntity)
end

function voreSouls.digestEntity(digestedEntity)
  local self = voreSouls
  if digestedEntity.type == "humanoid" then
    -- Check if we have the skill (prevents triggering while disabled, since the effect can persist)
    if starPounds.moduleFunc("skills", "has", "voreSouls") then
      local entityMaxHealth = digestedEntity.health and digestedEntity.health[2] or nil
      if status.resourcePositive("health") then
        status.giveResource("health", entityMaxHealth * self.config.healPercentage)
      end
    end
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

  starPounds.events:off("pred:digestEntity", self.digestEntity)
end

function voreSouls:expire()
  self:uninit()
end
-- Add the effect.
starPounds.modules.effects.effects.voreSouls = voreSouls
