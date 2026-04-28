local sound = starPounds.module:new("sound")

function sound:init()
  message.setHandler("starPounds.sound.play", function(_, _, ...) return self:play(...) end)
  message.setHandler("starPounds.sound.stop", function(_, _, ...) return self:stop(...) end)
  message.setHandler("starPounds.sound.setVolume", function(_, _, ...) return self:setVolume(...) end)
  message.setHandler("starPounds.sound.setPitch", function(_, _, ...) return self:setPitch(...) end)

  if storage.starPounds.enabled then
    status.addEphemeralEffect("starpoundssoundhandler")
  end

  self.secret = false
  self.secretIndex = {}
end

function sound:update(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't create if we can't add statuses anyway.
  if status.statPositive("statusImmunity") then return end
  -- Check if status doesn't exist.
  if not status.uniqueStatusEffectActive("starpoundssoundhandler") then
    status.addEphemeralEffect("starpoundssoundhandler")
  end

  local secret = starPounds.moduleFunc("skills", "has", "secret")
  if self.secret ~= secret then
    self.secret = secret
    -- Refesh sound pools.
    if not secret then
      status.removeEphemeralEffect("starpoundssoundhandler")
    end
  end
end

function sound:play(soundPool, volume, pitch, loops)
  -- No sound with the option.
  if starPounds.hasOption("disableSound") then return end
  -- Set volume/pitch.
  self:setVolume(soundPool, volume)
  self:setPitch(soundPool, pitch)
  -- Hehe.
  if self.secret then self:applySecret(soundPool) end

  world.sendEntityMessage(starPounds.entityId, "starPounds.handler_playSound", soundPool, loops)
end

function sound:stop(soundPool)
  world.sendEntityMessage(starPounds.entityId, "starPounds.handler_stopSound", soundPool)
end

function sound:setVolume(soundPool, volume, rampTime)
  volume = util.clamp(tonumber(volume) or 1, 0, self.data.maxVolume)
  -- Secret volume averaged closer to 0.75.
  if self.secret and volume > 0 then
    volume = (volume + 0.75) * 0.5
  end
  -- Quiet sound option.
  if starPounds.hasOption("quietSounds") then
    volume = volume * 0.5
  end

  world.sendEntityMessage(starPounds.entityId, "starPounds.handler_setSoundVolume", soundPool, volume, rampTime)
end

function sound:setPitch(soundPool, pitch, rampTime)
  pitch = util.clamp(tonumber(pitch) or 1, self.data.minPitch, self.data.maxPitch)

  if self.secret then
    pitch = 1
  end

  world.sendEntityMessage(starPounds.entityId, "starPounds.handler_setSoundPitch", soundPool, pitch, rampTime)
end

function sound:applySecret(soundPool)
  local secretPool
  if soundPool:find("loop") then
    secretPool = {"/sfx/starpounds/other/secret.ogg"}
  else
    if not self.secretIndex[soundPool] then self.secretIndex[soundPool] = 1 end
    secretPool = {"/sfx/starpounds/other/secret" .. self.secretIndex[soundPool] .. ".ogg"}
    self.secretIndex[soundPool] = (self.secretIndex[soundPool] % 8) + 1
  end
  world.sendEntityMessage(starPounds.entityId, "starPounds.handler_setSoundPool", soundPool, secretPool)
end

starPounds.modules.sound = sound
