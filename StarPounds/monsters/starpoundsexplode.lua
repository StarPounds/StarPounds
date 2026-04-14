-- Super spaghetti and I hate it, but people wanted this so here we are.
local update_old = update or function() end
function update(dt)
  update_old(dt)
  if starPounds then
    if storage.starPounds.pred and ((not starPounds.explodeTimer) or starPounds.explodeTimer > 0) then
      starPounds.explodeTimer = math.max((starPounds.explodeTimer or 1.5) - dt, 0)
      if starPounds.explodeTimer == 0 then
        starPoundsExplode()
      end
    end

    if starPounds.explodeDelay then
      starPounds.explodeDelay = math.max(starPounds.explodeDelay - dt, 0)
      if starPounds.explodeDelay == 0 then
        status.setResource("health", 0)
      end
    end
  end
end

function starPoundsExplode()
  -- Shamelessly stolen (and stripped down) from the behavior scripts.
  local function scalePower(power)
    power = (power or 10) * root.evalFunction("monsterLevelPowerMultiplier", monster.level()) * status.stat("powerMultiplier")
    return power
  end

  local deathActions = config.getParameter("behaviorConfig.deathActions", {})
  for _, action in pairs(deathActions) do
    if action.name == "action-projectile" then
      local parameters = action.parameters
      local power = scalePower((parameters.projectileParameters or {}).power)
      local damageKind = root.projectileConfig(action.parameters.projectileType).damageKind or "default"
      local damageConfig = root.assetJson("/damage/" .. damageKind .. ".damage")

      local soundSuffix = damageConfig.elementalType and "_fire" or ""
      local sounds = jarray()
      for i = 1, 3 do
        sounds[i] = "/sfx/projectiles/blast_small" .. soundSuffix .. i .. ".ogg"
      end

      starPounds.explodeDelay = 0.15
      world.sendEntityMessage(storage.starPounds.pred, "starPounds.stomach.feed", power, "air")
      world.sendEntityMessage(storage.starPounds.pred, "starPounds.sound.play", "slosh", 1, 0.75)
      world.sendEntityMessage(storage.starPounds.pred, "starPounds.sound.play", "digest", 1, 0.75)
      world.spawnProjectile("invisibleprojectile", mcontroller.position(), entity.id(), {0,0}, true, {
        damageKind = "hidden",
        universalDamage = false,
        onlyHitTerrain = true,
        timeToLive = 5/60,
        actionOnReap = {
          { action = "sound", options = sounds }
        }
      })

      break
    end
  end
end
