local belch = starPounds.module:new("belch")

function belch:init()
  message.setHandler("starPounds.belch", function(_, _, ...) return self:belch(...) end)
end

function belch:belch(volume, pitch, addMomentum)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  volume = tonumber(volume) or 1
  pitch = tonumber(pitch) or 1
  if addMomentum == nil then addMomentum = true end
  -- Skip if belches are disabled.
  if starPounds.hasOption("disableBelches") then return end
  local distortionSphere = status.stat("activeMovementAbilities") > 1
  if status.stat("activeMovementAbilities") > 1 then
    volume = volume * 0.5
    starPounds.moduleFunc("sound", "play", "belch", volume, self:pitch(pitch))
    return
  end
  starPounds.moduleFunc("sound", "play", "belch", volume, self:pitch(pitch))
  -- 7.5 (Rounded to 8) to 10 particles, decreased or increased by up to 2x, -5
  -- Ends up yielding around 10 - 15 particles if the belch is very loud and deep, 3 - 5 at normal volume and pitch, and none if it's half volume or twice as high pitch.
  local volumeMultiplier = util.clamp(volume, 0, 1.5)
  local pitchMultiplier = 1/math.max(pitch, 2/3)
  local particleCount = math.round(math.max(math.random(75, 100) * 0.1 * pitchMultiplier * volumeMultiplier - 5, 0))
  -- Belches give momentum in zero g based on the particle count, because why not.
  if starPounds.type == "player" and addMomentum and starPounds.mcontroller.zeroG then
    mcontroller.addMomentum({-0.5 * starPounds.mcontroller.facingDirection * (0.5 + starPounds.weightMultiplier * 0.5) * particleCount, 0})
  end
  -- Alert nearby enemies.
  local targets = world.entityQuery(starPounds.mcontroller.position, self.data.belchAlertRadius * volume, { includedTypes = {"npc", "monster"} })
  for _, target in pairs(targets) do
    if world.entityAggressive(target) and world.entityCanDamage(target, entity.id()) then
      world.sendEntityMessage(target, "starPounds.notifyDamage", {sourceId = entity.id()})
    end
  end

  self:spawnParticles(particleCount)
end

function belch:spawnParticles(particleCount)
-- Skip if 0.
if starPounds.hasOption("disableBelchParticles") or particleCount == 0 then return end
  -- Create a belch particle with gravity.
  local particle = {}
  local gravity = world.gravity(starPounds.mcontroller.mouthPosition)
  local friction = world.breathable(starPounds.mcontroller.mouthPosition) or world.liquidAt(starPounds.mcontroller.mouthPosition)
  particle.initialVelocity = {0, gravity/62.5}
  particle.finalVelocity = {0, -gravity}
  particle.approach = {friction and 5 or 0, gravity}

  starPounds.spawnMouthProjectile({{
    action = "particle", specification = self:particle(particle)
  }}, particleCount)
end

function belch:particle(override)
  local facing = starPounds.mcontroller.facingDirection
  local velocity = vec2.add(starPounds.mcontroller.velocity, {7 * facing, 0})
  local particle = sb.jsonMerge(starPounds.settings.particleTemplates.belch, override or {})
  -- Flip particles and add extra velocity based on direction.
  particle.initialVelocity = vec2.add(vec2.mul(particle.initialVelocity or {0, 0}, {facing, 1}), velocity)
  particle.finalVelocity = vec2.mul(particle.finalVelocity or {0, 0}, {facing, 1})

  return particle
end

function belch:pitch(multiplier)
  multiplier = tonumber(multiplier) or 1
  local pitch = util.randomInRange(self.data.belchPitch)
  -- Gender pitch modifiers.
  if not starPounds.hasOption("genderlessBelches") then
    local gender = world.entityGender(entity.id())
    if gender then
      pitch = pitch + (self.data.belchGenderModifiers[gender] or 0)
    end
  end
  -- Option pitch modifiers.
  if starPounds.hasOption("disableBelches") then return end
  if starPounds.hasOption("higherBelches") then pitch = pitch * 1.25 end
  if starPounds.hasOption("deeperBelches") then pitch = pitch * 0.75 end

  pitch = math.round(pitch * multiplier, 2)
  return pitch
end

-- Add the module.
starPounds.modules.belch = belch
