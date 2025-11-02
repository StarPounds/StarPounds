local effects = starPounds.module:new("effects")

function effects:init()
  message.setHandler("starPounds.addEffect", function(_, _, ...) return self:add(...) end)
  message.setHandler("starPounds.removeEffect", function(_, _, ...) return self:remove(...) end)
  message.setHandler("starPounds.getEffect", function(_, _, ...) return self:get(...) end)
  message.setHandler("starPounds.hasDiscoveredEffect", function(_, _, ...) return self:hasDiscovered(...) end)
  message.setHandler("starPounds.resetEffects", localHandler(self.reset))

  self.effects = {}
  self.loaded = false
end

effects.effect = setmetatable({}, { __index = starPounds.module })
function effects.effect:new()
  -- Effects are basically just timed modules.
  local newEffect = starPounds.module:new("effect")
  setmetatable(newEffect, { __index = self })
  return newEffect
end

function effects.effect:apply() end -- Runs whenever the effect gets applied, or reapplied.
function effects.effect:expire() end -- Runs whenever the effect times out, or gets removed.

function effects:new()
  return self.effect:new()
end

function effects:update(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Delay the effects loading by one tick so all the other modules can be ready.
  if not self.loaded then
    for effect in pairs(storage.starPounds.effects.active) do
      self:load(effect)
    end
    self.loaded = true
  end
  -- Update effect durations.
  for effectName, effect in pairs(storage.starPounds.effects.active) do
    local effectData = storage.starPounds.effects.active[effectName]
    if effectData.duration then
      effectData.duration = math.max(effectData.duration - dt, 0)
      if effectData.duration == 0 then
        local effectConfig = self.data.effects[effectName]
        if effectConfig.expirePerLevel and (effectData.level > 1) then
          effectData.level = effectData.level - 1
          effectData.duration = effectConfig.duration
          starPounds.events:fire("stats:calculate", "effectLevelDecrease")
        else
          self:remove(effectName)
        end
      end
    end
  end
end

function effects:load(effect)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  local effectConfig = self.data.effects[effect]
  if effectConfig then
    if effectConfig.script and not self.effects[effect] then
      require(effectConfig.script)
      _SBLOADED[effectConfig.script] = nil
      util.mergeTable(storage.starPounds.effects.active[effect], self.effects[effect].data)
      self.effects[effect].data = storage.starPounds.effects.active[effect]
      self.effects[effect].config = copy(effectConfig.effectConfig)
      self.effects[effect]:moduleInit()

      starPounds.modules[string.format("effect_%s", effect)] = self.effects[effect]
      starPounds.modules[string.format("effect_%s", effect)]:setUpdateDelta(effectConfig.scriptDelta or 1)
    end
    -- Vanilla effect that tracks duration.
    if effectConfig.proxyEffect then
      status.addEphemeralEffect(effectConfig.proxyEffect)
    end
  end
end

function effects:add(effect, duration, level)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  effect = tostring(effect)
  local effectConfig = self.data.effects[effect]
  local effectData = storage.starPounds.effects.active[effect] or {}
  if effectConfig then
    duration = tonumber(duration) or effectConfig.duration
    level = tonumber(level) or 1
    -- Negative durations become infinite.
    if duration < 0 then duration = nil end
    if effectConfig.particle then
      local spec = starPounds.settings.particleTemplates.effect
      world.spawnProjectile("invisibleprojectile", vec2.add(starPounds.mcontroller.position, mcontroller.isNullColliding() and 0 or vec2.div(starPounds.mcontroller.velocity, 60)), entity.id(), {0,0}, true, {
        damageKind = "hidden",
        universalDamage = false,
        onlyHitTerrain = true,
        timeToLive = 5/60,
        periodicActions = {
          { action = "loop", time = 0, ["repeat"] = false, count = 5, body = {
            { action = "particle", specification = spec },
            { action = "particle", specification = sb.jsonMerge(spec, {layer = "front"}) }
          }}
        }
      })
      starPounds.moduleFunc("sound", "play", "digest", 0.5, (math.random(120,150)/100))
    end
    effectData.duration = duration and math.max(effectData.duration or 0, duration) or nil
    effectData.level = math.min((effectData.level or 0) + level, effectConfig.levels or 1)
    storage.starPounds.effects.active[effect] = effectData
    if not (effectConfig.ephemeral or effectConfig.hidden) then
      storage.starPounds.effects.discovered[effect] = true
    end
    -- Load effect.
    self:load(effect)
    -- Scripted effects.
    if effectConfig.script then
      self.effects[effect]:apply()
    end

    starPounds.events:fire("stats:calculate", "effectAdd")
    return true
  end
  return false
end

function effects:remove(effect)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  effect = tostring(effect)
  if storage.starPounds.effects.active[effect] then
    storage.starPounds.effects.active[effect] = nil
    starPounds.events:fire("stats:calculate", "effectRemove")
    if self.effects[effect] then
      self.effects[effect]:expire()
      self.effects[effect] = nil
      starPounds.modules[string.format("effect_%s", effect)] = nil
    end
    return true
  end
  return false
end

function effects:get(effect)
  -- Return empty if the mod is disabled.
  --if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  effect = tostring(effect)
  return storage.starPounds.effects.active[effect]
end

function effects:getConfig(effect)
  return self.data.effects[effect]
end

function effects:hasDiscovered(effect)
  -- Argument sanitisation.
  effect = tostring(effect)
  return storage.starPounds.effects.discovered[effect] ~= nil
end

function effects.reset()
  storage.starPounds.effects.active = {}
  storage.starPounds.effects.discovered = {}
  starPounds.events:fire("stats:calculate", "effectReset")
end

function effects:uninit()
  for effect in pairs(storage.starPounds.effects.active) do
    if self.effects[effect] then
      self.effects[effect]:uninit()
      self.effects[effect] = nil
      starPounds.modules[string.format("effect_%s", effect)] = nil
    end
    -- Can't trigger this in the respawn module, since the effects module gets unloaded (and deletes this effect) beforehand.
    if not status.resourcePositive("health") then
      local effectConfig = self.data.effects[effect]
      if effectConfig.expireOnDeath then
        self:remove(effect)
      end
    end
  end
end

starPounds.modules.effects = effects
