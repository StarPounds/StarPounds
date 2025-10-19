local bloatCola = starPounds.moduleFunc("effects", "new")

function bloatCola:init()
  self.airAmount = self.config.airAmount or 2
  self.fizzVolume = self.config.volume or 0.25
  self.fizzMultiplier = 1
  self.volumeMultiplier = 1
  self.firstUpdate = false
  self.expiring = false
  self.baseDuration = starPounds.moduleFunc("effects", "getConfig", "bloatCola").duration
  starPounds.moduleFunc("sound", "stop", "fizzloop")

  starPounds.events:on("stomach:slosh", self.onSlosh)
  starPounds.events:on("player:landing", self.onSlosh)
end

function bloatCola.onSlosh(sloshAmount)
  bloatCola:shake(sloshAmount)
end

function bloatCola:apply()
  self.expiring = false
  self.airAmount = (self.config.airAmount or 2.5) * self.data.level
end

function bloatCola:update(dt)
  -- Decrease fizz amount and sound volume as it runs out.
  self.fizzMultiplier = util.clamp(self.data.duration/self.baseDuration, 0.25, 1)
  self.volumeMultiplier = (self.fizzMultiplier + 1) * 0.5
  -- Update the sound volume after the first update.
  if self.firstUpdate then
    starPounds.moduleFunc("sound", "setVolume", "fizzloop", self.fizzVolume * self.volumeMultiplier, dt)
  end
  -- Gurgle sound that plays when enabling the mod overrides if we trigger it on init.
  if not self.firstUpdate then
    starPounds.moduleFunc("sound", "play", "fizzloop", self.fizzVolume * self.volumeMultiplier, 0.75, -1)
    self.firstUpdate = true
  end
  -- Ramp down sound as it expires.
  if not self.expiring and (self.data.duration + dt) <= 1 then
    self.expiring = true
    starPounds.moduleFunc("sound", "setVolume", "fizzloop", 0, 1)
  end
  starPounds.moduleFunc("stomach", "feed", self.airAmount * self.fizzMultiplier * dt, "air")
end

function bloatCola:expire()
  self:uninit()
end

function bloatCola:uninit()
  starPounds.moduleFunc("sound", "stop", "fizzloop")
  starPounds.events:off("stomach:slosh", self.onSlosh)
  starPounds.events:off("player:landing", self.onSlosh)
end

function bloatCola:shake(duration)
  -- Remove duration for double the air.
  self.data.duration = math.max(self.data.duration - duration, 0)
  starPounds.moduleFunc("stomach", "feed", duration * self.airAmount * self.fizzMultiplier * 2, "air")
  starPounds.moduleFunc("stomach", "rumble", self.volumeMultiplier)
end
-- Add the effect.
starPounds.modules.effects.effects.bloatCola = bloatCola
