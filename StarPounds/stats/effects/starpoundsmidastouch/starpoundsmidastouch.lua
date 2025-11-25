require "/scripts/rect.lua"

function init()
  _, lastStep = status.inflictedDamageSince()
  sourceEntityId = entity.id()

  animator.setParticleEmitterOffsetRegion("sparkle", rect.rotate(mcontroller.boundBox(), mcontroller.rotation()))
  animator.setParticleEmitterActive("sparkle", true)

  actions = {
    hitSound = {{action = "sound", time = 0, ["repeat"] = false, options = {
      "/sfx/objects/coinstack_small1.ogg",
      "/sfx/objects/coinstack_small2.ogg",
      "/sfx/objects/coinstack_small3.ogg"
    }}},
    killSound = {
      {action = "sound", time = 0, ["repeat"] = false, options = {"/sfx/objects/coinstack_large.ogg"}},
      {action = "sound", time = 0, ["repeat"] = false, options = {
      "/sfx/objects/ancient_pot_break_medium1.ogg",
      "/sfx/objects/ancient_pot_break_medium2.ogg",
      "/sfx/objects/ancient_pot_break_medium3.ogg",
      "/sfx/objects/ancient_pot_break_medium4.ogg",
      "/sfx/objects/ancient_pot_break_medium5.ogg",
      "/sfx/objects/ancient_pot_break_medium6.ogg"
    }}},
    killSoundSmall = {
      {action = "sound", time = 0, ["repeat"] = false, options = {
        "/sfx/objects/coinstack_medium1.ogg",
        "/sfx/objects/coinstack_medium2.ogg"
      }},
      {action = "sound", time = 0, ["repeat"] = false, options = {
        "/sfx/objects/ancient_pot_break_small1.ogg",
        "/sfx/objects/ancient_pot_break_small2.ogg",
        "/sfx/objects/ancient_pot_break_small3.ogg",
        "/sfx/objects/ancient_pot_break_small4.ogg",
        "/sfx/objects/ancient_pot_break_small5.ogg",
        "/sfx/objects/ancient_pot_break_small6.ogg",
        "/sfx/objects/ancient_pot_break_small7.ogg",
        "/sfx/objects/ancient_pot_break_small8.ogg",
        "/sfx/objects/ancient_pot_break_small9.ogg"
      }}
    },
    killSoundTiny = {
      {action = "sound", time = 0, ["repeat"] = false, options = {
        "/sfx/objects/coinstack_small1.ogg",
        "/sfx/objects/coinstack_small2.ogg",
        "/sfx/objects/coinstack_small3.ogg"
      }},
      {action = "sound", time = 0, ["repeat"] = false, options = {
        "/sfx/objects/ancient_pot_break_small1.ogg",
        "/sfx/objects/ancient_pot_break_small2.ogg",
        "/sfx/objects/ancient_pot_break_small3.ogg",
        "/sfx/objects/ancient_pot_break_small4.ogg",
        "/sfx/objects/ancient_pot_break_small5.ogg",
        "/sfx/objects/ancient_pot_break_small6.ogg",
        "/sfx/objects/ancient_pot_break_small7.ogg",
        "/sfx/objects/ancient_pot_break_small8.ogg",
        "/sfx/objects/ancient_pot_break_small9.ogg"
      }}
    }
  }
end

function update(dt)
  local damageRequests, nextStep = status.inflictedDamageSince(lastStep)
  lastStep = nextStep

  for _, notification in ipairs(damageRequests) do
    spawnPixels(notification)
  end
end

function spawnPixels(notification)
  -- Maybe this does nothing.
  if notification.sourceEntityId ~= sourceEntityId then return end
  -- Must be damage to another entity.
  if sourceEntityId == notification.targetEntityId then return end
  -- Must have a position to spawn the loot.
  if not notification.position then return end
  -- Spawn 1 + up to 10% of damage as money.
  local moneyMult = 1
  local speedMult = 1
  local killSound = actions.killSound
  local entityType = world.entityType(notification.targetEntityId)
  local entityTypeName = world.entityTypeName(notification.targetEntityId)
  -- Monsters.
  if entityType == "monster" then
    -- 50% reduced money for monsters.
    moneyMult = moneyMult * 0.5
    speedMult = speedMult * 0.5
    killSound = actions.killSoundSmall
    -- 50% futher reduced money for passive monsters.
    if not world.entityCanDamage(notification.targetEntityId, sourceEntityId) then
      moneyMult = moneyMult * 0.5
      killSound = actions.killSoundTiny
    end
    -- Punchy gives nothing.
    if entityTypeName == "punchy" or entityTypeName == "starpoundspudgy" then
      return
    end
  end
  -- Objects give nothing.
  if entityType == "object" then
    return
  end

  if math.random() > 0.5 and notification.healthLost > 0 then
    local projectileCount = math.random(1, math.min(math.ceil(notification.healthLost * moneyMult / 10), 5))
    local playSound = true
    for i = 1, projectileCount do
      local xDirection = (math.random() - 0.5)
      local yDirection = world.gravity(notification.position) > 0 and (math.random() * 0.5) or (math.random() - 0.5)
      world.spawnProjectile("money", notification.position, sourceEntityId, {xDirection, yDirection}, false, {
        onlyHitTerrain = true,
        speed = math.random(3, 5),
        periodicActions = playSound and actions.hitSound or nil
      })

      playSound = false
    end
  end

  if notification.hitType == "Kill" then
    local projectileCount = math.floor(math.random(10, 25) * moneyMult + 0.5)
    local playSound = true
    for i = 1, projectileCount do
      local xDirection = (math.random() - 0.5)
      local yDirection = world.gravity(notification.position) > 0 and math.random() or (math.random() - 0.5)
      world.spawnProjectile("money", notification.position, sourceEntityId, {xDirection, yDirection}, false, {
        onlyHitTerrain = true,
        speed = math.random(5, 20) * (1 + speedMult) * 0.5,
        periodicActions = playSound and killSound or nil
      })

      playSound = false
    end
  end
end
