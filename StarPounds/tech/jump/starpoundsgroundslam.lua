require "/scripts/vec2.lua"
require "/tech/doubletap.lua"

function init()
  self.multiJumpCount = config.getParameter("multiJumpCount")
  self.slamCooldown = 0
  self.slamTimer = 0
  self.slamWaitTimer = 0
  self.voreSlamStrain = config.getParameter("voreSlamStrain", 0)
  self.rechargeEffectTimer = 0
  refreshJumps()

  local doubleTapCheck = function(dashKey)
    if self.slamTimer == 0
      and self.slamCooldown == 0
      and not mcontroller.groundMovement()
      and not status.statPositive("activeMovementAbilities") then

      if canSlam() then doSlam() end
    end
  end

  self.doubleTap = DoubleTap:new({"down"}, config.getParameter("maximumDoubleTapTime"), doubleTapCheck)
  self.doubleTapJump = DoubleTap:new({"jump"}, config.getParameter("maximumDoubleTapTime"), doubleTapCheck)

  starPounds = getmetatable ''.starPounds
end

function update(args)
  -- For some reason this tech script doesn't like it only being in init.
  starPounds = getmetatable ''.starPounds
  self.slamWaitTimer = math.max(0, self.slamWaitTimer - args.dt)
  if self.slamWaitTimer == 0 then
    self.slamTimer = math.max(0, self.slamTimer - args.dt)
  end

  self.doubleTap:update(args.dt, args.moves)
  self.doubleTapJump:update(args.dt, args.moves)
  if self.multiJumps > 0 then
    self.doubleTapJump.currentKey = nil
  end

  if self.slamCooldown > 0 then
    self.slamCooldown = math.max(0, self.slamCooldown - args.dt)
    if self.slamCooldown == 0 then
      self.rechargeEffectTimer = 0.1
      animator.playSound("recharge")
      tech.setParentDirectives("?fade=ccbbff=0.25")
    end
  end

  if self.rechargeEffectTimer > 0 then
    self.rechargeEffectTimer = math.max(0, self.rechargeEffectTimer - args.dt)
    if self.rechargeEffectTimer == 0 then
      tech.setParentDirectives()
    end
  end

  if mcontroller.liquidMovement() or mcontroller.zeroG() then
    self.slamTimer = 0
  end

  if self.slamTimer > 0 then
    tech.setParentState("sit")
    tech.setParentOffset({0, -0.5})
    if self.slamWaitTimer == 0 then
      if math.min(self.slamTimer + args.dt, 1) == 1 then
        mcontroller.setXVelocity(self.xVelocity)
      end
      animator.setParticleEmitterActive("slamParticles", true)
      mcontroller.setYVelocity(-75)
      if mcontroller.onGround() then
        tech.setParentState()
        tech.setParentOffset({0, 0})

        local width = {0, 0}
        local position = vec2.add(mcontroller.position(), ({0, starPounds.currentSize.yOffset or 0}))
        for _,v in ipairs(mcontroller.collisionPoly()) do
          width[1] = (v[1] < width[1]) and v[1] or width[1]
          width[2] = (v[1] > width[2]) and v[1] or width[2]
        end
        width = (math.abs(width[1]) + math.abs(width[2])) * 0.5

        local slammed = shockwave.fireShockwave(math.round(width))
        -- Plays impact sound for taking fall damage, but at any height.
        status.applySelfDamageRequest({
          damageType = "IgnoresDef",
          damage = 0,
          damageSourceKind = "falling",
          sourceEntityId = entity.id()
        })
        self.slamTimer = 0
        self.slamCooldown = 0.5
        -- Try and grab the nearest edible entity.
        local hasPrey = false
        if self.voreSlam then
          local entities = world.entityQuery(vec2.add(position, {-(0.25 + width * 0.5), -3}), vec2.add(position, {0.25 + width * 0.5, -1.5}), {order = "nearest", includedTypes = {"player", "npc", "monster"}, withoutEntityId = entity.id()})
          for _, preyId in pairs(entities) do
            if starPounds.moduleFunc("pred", "eat", preyId, {ignoreCapacity = true, ignoreEnergyRequirement = true, energyMultiplier = 0.5, noSwallowSound = true, noSwallowBelch = true, playSquelchSound = true, loud = true}) then
              hasPrey = true
              break
            end
          end
        end
        -- Full cooldown if we did a slam or ate an entity.
        if slammed or hasPrey then
          self.slamCooldown = math.max(self.slamCooldown, 3 * starPounds.getStat("groundSlamCooldown"))
          starPounds.moduleFunc("effects", "add", "groundSlam")
          if hasPrey then
            -- Add strain.
            starPounds.moduleFunc("strain", "add", self.voreSlamStrain)
          end
        end
        -- Little upwards bounce, bigger if kaboom.
        mcontroller.setYVelocity(slammed and 30 or 15)
      end
    else
      mcontroller.setVelocity({0, 10})
    end
  else
    if self.slammed then
      self.slammed = false
      self.slamCooldown = math.max(args.dt * 2, self.slamCooldown)
      tech.setParentState()
      tech.setParentOffset({0, 0})
    end
    animator.setParticleEmitterActive("slamParticles", false)
    status.clearPersistentEffects("starpoundsslam")
  end

  animator.setFlipped(mcontroller.facingDirection() == -1)

  local jumpActivated = args.moves["jump"] and not self.lastJump
  self.lastJump = args.moves["jump"]

  if starPounds then
    updateJumpModifier()
  end

  if jumpActivated and canMultiJump() then
    doMultiJump()
  else
    if mcontroller.groundMovement() or mcontroller.liquidMovement() then
      refreshJumps()
    end
  end
end

function uninit()
  status.clearPersistentEffects("starpoundsslam")
  if self.slamTimer > 0 then
    tech.setParentState()
    tech.setParentOffset({0, 0})
  end
end

-- after the original ground jump has finished, start applying the new jump modifier
function updateJumpModifier()
  self.applyJumpModifier = not status.statPositive("activeMovementAbilities") and self.applyJumpModifier or false
  if not self.applyJumpModifier
      and not mcontroller.jumping()
      and not mcontroller.groundMovement()
      and not status.statPositive("activeMovementAbilities") then

    self.applyJumpModifier = true
  end

  if self.applyJumpModifier then
    local maxMod = (1/starPounds.jumpMultiplier) - 1
    local modifier = 1 + maxMod * starPounds.getStat("groundSlamHeight")
    mcontroller.controlModifiers({airJumpModifier = modifier})
  end
end

function canMultiJump()
  return self.multiJumps > 0
      and not mcontroller.jumping()
      and not mcontroller.canJump()
      and not mcontroller.liquidMovement()
      and not status.statPositive("activeMovementAbilities")
      and math.abs(world.gravity(mcontroller.position())) > 0
end

function canSlam()
  return not self.slammed
      and self.slamCooldown == 0
      and not mcontroller.jumping()
      and not mcontroller.liquidMovement()
      and not status.statPositive("activeMovementAbilities")
      and math.abs(world.gravity(mcontroller.position())) > 0
end

function doMultiJump()
  mcontroller.controlJump(true)
  mcontroller.setYVelocity(math.max(0, mcontroller.yVelocity()))
  self.multiJumps = self.multiJumps - 1
  animator.burstParticleEmitter("multiJumpParticles")
  animator.playSound("multiJumpSound")
end

function doSlam()
  mcontroller.setYVelocity(-75)
  self.voreSlam = starPounds.moduleFunc("skills", "has", "voreSlam")
  self.weightMultiplier = 1 + math.floor(0.5 + (starPounds.currentSize or {weight = 0}).weight/1.2)/100
  self.scale = math.min(math.floor(0.5 + 10 * self.weightMultiplier ^ (1/3))/10, 4)
  self.slammed = true
  self.slamTimer = 1
  self.slamWaitTimer = 0.1
  self.xVelocity = mcontroller.xVelocity()
  animator.playSound("startSlam")
  animator.setSoundVolume("weightDash", starPounds.moduleFunc("size", "effectScaling") * 0.5 + 0.5)
  animator.playSound("weightDash")
  status.setPersistentEffects("starpoundsslam", {
    {stat = "fallDamageMultiplier", effectiveMultiplier = 0},
    {stat = "invulnerable", amount = 1},
    {stat = "activeMovementAbilities", amount = 1}
  })
end

function refreshJumps()
  self.multiJumps = self.multiJumpCount
  self.slammed = false
  self.applyJumpModifier = false
end

-- Hammer ability, but ground slams.
shockwave = {
  projectileType = "physicalshockwave",
  projectileParameters = {
    knockback = 40,
    knockbackMode = "facing"
  },
  shockWaveBounds = {-0.4, -1.375, 0.4, 0.0},
  shockwaveHeight = 1.375,
  impactLine = {{0, -1.5}, {0, -4.5}},

  fireShockwave = function(width)
    local impact
    local position = vec2.add(mcontroller.position(), ({0, starPounds.currentSize.yOffset or 0}))
    local blocks = world.collisionBlocksAlongLine(vec2.add(position, shockwave.impactLine[1]), vec2.add(position, shockwave.impactLine[2]), {"Null", "Block"})
    if #blocks > 0 then
      impact = vec2.add(blocks[1], {0.5, 0.5})
    end

    if impact then
      local explosionConfig = "starpoundsgroundslamexplosion"
      -- No tile damage with the option, or on ship worlds.
      if starPounds.hasOption("disableTileDamage") or world.type() == "unknown" then
        explosionConfig = "starpoundsgroundslamexplosionprotected"
      end
      -- No tile damage, and a softer/quieter sound for vore.
      if self.voreSlam then
        explosionConfig = "starpoundsgroundslamexplosionvore"
      end
      world.spawnProjectile("starpoundsgroundslamexplosion", vec2.add(position, {0, -2.5}), entity.id(), {0, 0}, false, {
        actionOnReap = {{action = "config", file = string.format("/projectiles/explosions/starpoundsgroundslam/%s.config", explosionConfig)}}
      })
      local maxDistance = 1 + (self.voreSlam and 1 or 2) * (self.weightMultiplier - 1)^(1/3)
      local positions = shockwave.shockwaveProjectilePositions(impact, maxDistance + width)
      if #positions > 0 then
        local damageUuid = sb.makeUuid()
        local params = copy(shockwave.projectileParameters)
        params.powerMultiplier = status.stat("powerMultiplier")
        params.onlyHitTerrain = true
        params.actionOnReap = {
          {
            action = "projectile",
            inheritDamageFactor = self.voreSlam and 0 or 1,
            type = shockwave.projectileType,
            config = {
              processing = self.voreSlam and "?multiply=0000" or "",
              damageRepeatGroup = "starpoundsgroundslam_"..damageUuid,
              damageRepeatTimeout = 1,
              damageKind = self.voreSlam and "bugnet" or nil -- Silly, but it works.
            }
          }
        }
        for i, position in pairs(positions) do
          local xDistance = world.distance(position, impact)[1]
          local dir = util.toDirection(xDistance)
          local distance = (math.floor(math.max(math.abs(xDistance) - width, 0)))
          local multiplier = (maxDistance - distance * 0.75) / maxDistance
          params.timeToLive = distance * 0.05
          params.power = self.voreSlam and 0 or math.floor(10 + 30 * (self.scale - 1) + 0.5) * multiplier
          if not self.voreSlam and not starPounds.hasOption("disableTileDamage") and world.type() ~= "unknown" then
            params.actionOnReap[2] = {
              action = "explosion",
              foregroundRadius = 2.5,
              backgroundRadius = 0,
              harvestLevel = 1,
              explosiveDamageAmount = math.floor(0.25 + 0.25 * (self.scale - 1) + 0.5) * multiplier^2
            }
          end
          world.spawnProjectile("shockwavespawner", position, entity.id(), {dir, 0}, false, params)
        end
      end
    end
    return impact ~= nil
  end,

  shockwaveProjectilePositions = function(impactPosition, maxDistance)
    local positions = {}

    for _,direction in pairs({1, -1}) do
      local position = copy(impactPosition)
      for i = 0, maxDistance do
        local continue = false
        for _,yDir in ipairs({-2, -1, 0, 1}) do
          local wavePosition = {position[1] + direction * i, position[2] + 0.5 + yDir + shockwave.shockwaveHeight}
          local groundPosition = {position[1] + direction * i, position[2] + yDir}
          local bounds = {
            shockwave.shockWaveBounds[1] + wavePosition[1],
            shockwave.shockWaveBounds[2] + wavePosition[2],
            shockwave.shockWaveBounds[3] + wavePosition[1],
            shockwave.shockWaveBounds[4] + wavePosition[2]
          }

          if world.pointTileCollision(groundPosition, {"Null", "Block", "Dynamic", "Slippery"}) and not world.rectTileCollision(bounds, {"Null", "Block", "Dynamic", "Slippery"}) then
            table.insert(positions, wavePosition)
            position[2] = position[2] + yDir
            continue = true
            break
          end
        end
        if not continue then break end
      end
    end

    return positions
  end
}
