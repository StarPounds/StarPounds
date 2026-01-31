local prey = starPounds.module:new("prey")

function prey:init()
  message.setHandler("starPounds.prey.swallowed", function(_, _, ...) return self:swallowed(...) end)
  message.setHandler("starPounds.prey.released", function(_, _, ...) return self:released(...) end)
  message.setHandler("starPounds.prey.digesting", function(_, _, ...) return self:digesting(...) end)
  message.setHandler("starPounds.prey.healing", function(_, _, ...) return self:healing(...) end)
  message.setHandler("starPounds.prey.newPred", function(_, _, ...) return self:newPred(...) end)

  message.setHandler("starPounds.prey.drinkVoreNudge", function(_, _, sourceId, maxWeight, args)
    if storage.starPounds.pred then return end
    if maxWeight < (entity.weight + storage.starPounds.weight) then return end
    if mcontroller.liquidPercentage() < 0.25 then return end
    if not entity.entityInSight(sourceId) then return end

    return mcontroller.controlApproachVelocityAlongAngle(table.unpack(args))
  end)

  self.voreCooldown = 0
  self.heartbeat = self.data.heartbeat
  -- Reload options in case.
  self.options = storage.starPounds.preyOptions or {}
  storage.starPounds.preyOptions = nil

  -- Just in case of reloads.
  if storage.starPounds.preyTech then
    self.oldTech = storage.starPounds.preyTech
    storage.starPounds.preyTech = nil
  end
end

function prey:update(dt)
  -- Tick down vore cooldown.
  self.voreCooldown = math.max(self.voreCooldown - dt, 0)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  self:eaten(dt)
end

function prey:eaten(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if we're not eaten.
  if not storage.starPounds.pred then self.heartbeat = self.data.heartbeat return end
  -- Spectating pred stuff.
  if storage.starPounds.spectatingPred then
    if not (starPounds.hasOption("spectatePred") and world.entityExists(storage.starPounds.pred, true)) then
      self:released()
      status.setResource("health", 0)
      return
    else
      status.setResource("health", 0.1)
    end
  end
  -- Check that the entity actually exists.
  if not world.entityExists(storage.starPounds.pred, true) or starPounds.hasOption("disablePrey") then
    self:released()
    return
  end

  self.heartbeat = math.max(self.heartbeat - dt, 0)
  if not storage.starPounds.spectatingPred and self.heartbeat == 0 then
    self.heartbeat = self.data.heartbeat
    promises:add(world.sendEntityMessage(storage.starPounds.pred, "starPounds.pred.hasPrey", entity.id()), function(eaten)
      if not eaten then self:released() end
    end)
  end
  -- Disable knockback while eaten.
  entity.setDamageOnTouch(false)
  -- Stop entities trying to move.
  mcontroller.clearControls()
  -- Stun the entity.
  if status.isResource("stunned") then
    status.setResource("stunned", math.max(status.resource("stunned"), dt))
  end
  -- Stop lounging.
  mcontroller.resetAnchorState()
  if starPounds.type == "npc" then
    -- Stop NPCs attacking.
    npc.endPrimaryFire()
    npc.endAltFire()
    -- Leave all combat/other NPC groups.
    if BGroup then
      BGroup:uninit()
    end
  end
  if starPounds.type == "monster" then
    pcall(animator.setAnimationState, "body", "idle")
    pcall(animator.setAnimationState, "damage", "none")
    pcall(animator.setGlobalTag, "hurt", "hurt")
  end
  -- Struggle mechanics.
  self[starPounds.type.."Struggle"](self, dt)
  -- Set velocity to zero.
  mcontroller.setVelocity({0, 0})
  -- Stop the prey from colliding/moving normally.
  mcontroller.controlParameters({ airFriction = 0, groundFriction = 0, liquidFriction = 0, collisionEnabled = false, gravityEnabled = false })
end

function prey:swallowed(pred, options)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return false end
  -- Argument sanitisation.
  pred = tonumber(pred)
  options = type(options) == "table" and options or {}
  if not pred then return false end
  -- Don't do anything if disabled.
  if starPounds.hasOption("disablePrey") then return false end
  -- Don't do anything if already eaten.
  if storage.starPounds.pred then return false end
  -- Don't allow if we're on cooldown.
  if self.voreCooldown > 0 then return false end
  -- Don't allow if the max weight is less than the prey's
  if options.maxWeight and (options.maxWeight < (entity.weight + storage.starPounds.weight)) then
    return false
  end
  -- Check that the entity actually exists.
  if not world.entityExists(pred, true) then return false end
  -- Don't get eaten if already dead.
  if not status.resourcePositive("health") then return false end
  -- Save the entityId of the pred.
  storage.starPounds.pred = pred
  -- Clear tracking status effects.
  starPounds.moduleFunc("trackers", "clearStatuses")
  -- Store options locally.
  self.options = options
  -- Eaten entities can't be interacted with. This looks very silly atm since I need to figure out a way to dynamically detect it.
  self.wasInteractable = false
  if starPounds.type == "npc" then
    self.wasInteractable = true
  end
  if self.wasInteractable then
    if starPounds.type == "npc" then
      npc.setInteractive(false)
    end
  end
  storage.starPounds.damageTeam = world.entityDamageTeam(entity.id())
  -- Player specific.
  if starPounds.type == "player" then
    self.oldTech = {}
    for _,v in pairs({"head", "body", "legs"}) do
      local equippedTech = player.equippedTech(v)
      if equippedTech then
        self.oldTech[v] = equippedTech
      end
      player.makeTechAvailable("starpoundseaten_"..v)
      player.enableTech("starpoundseaten_"..v)
      player.equipTech("starpoundseaten_"..v)
    end
  end
  -- NPC specific.
  if starPounds.type == "npc" then
    -- Are they a crewmate, and are we digesting them?
    if recruitable and not options.noDamage then
      -- Did their owner eat them?
      if recruitable.ownerUuid() and world.entityUniqueId(pred) == recruitable.ownerUuid() then
        recruitable.messageOwner("recruits.digestingRecruit")
      end
    end
    -- Alert other NPCs if they are not willing.
    if not options.willing then
      local nearbyNpcs = world.npcQuery(starPounds.mcontroller.position, self.data.witnessRange, {withoutEntityId = entity.id(), callScript = "entity.entityInSight", callScriptArgs = {entity.id()}, callScriptResult = true})
      for _, nearbyNpc in ipairs(nearbyNpcs) do
        local distance = world.distance(starPounds.mcontroller.position, world.entityPosition(nearbyNpc))
        local facingDirection = world.callScriptedEntity(nearbyNpc, "mcontroller.facingDirection")
        local isFacing = (distance[1] * facingDirection) > 0
        local inMinimumRange = vec2.mag(distance) < self.data.alwaysWitnessRange
        -- Facing and distance don't count if they're sleeping.
        local anchorEntity = world.callScriptedEntity(nearbyNpc, "mcontroller.anchorState")
        if anchorEntity and world.entityType(anchorEntity) == "object" then
          if world.getObjectParameter(anchorEntity, "sitEmote") == "sleep" then
            isFacing = false
            inMinimumRange = false
          end
        end
        if inMinimumRange or isFacing or options.loud or not options.silent then
          world.callScriptedEntity(nearbyNpc, "notify", {type = "attack", sourceId = entity.id(), targetId = storage.starPounds.pred})
        end
      end
    end
  end
  -- Non-player.
  if not (starPounds.type == "player") then
    -- Save the old damage team.
    -- Make other entities ignore it.
    entity.setDamageTeam({type = "ghostly", team = storage.starPounds.damageTeam.team})
    entity.setDamageOnTouch(false)
    if starPounds.type == "monster" then
      monster.setDamageSources()
    end
  end
  -- Make the entity immune to outside damage/invisible, and disable regeneration.
  status.setPersistentEffects("starpoundseaten", {
    {stat = "statusImmunity", effectiveMultiplier = 0}
  })
  status.addEphemeralEffect("starpoundseaten")
  return {
    base = entity.weight,
    foodType = entity.foodType,
    weight = storage.starPounds.weight,
    noBelch = starPounds.hasOption("disablePreyBelches")
  }
end

function prey:playerStruggle(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if we're not eaten.
  if not storage.starPounds.pred then return end
  -- Loose calculation for how "powerful" the prey is.
  local healthMultiplier = 0.5 + status.resourcePercentage("health") * 0.5
  local struggleStrength = math.max(1, status.stat("powerMultiplier")) * healthMultiplier
  -- Player struggles are directional.
  self.startedStruggling = self.startedStruggling or os.clock()
  -- Follow the pred's position, struggle if the player is using movement keys.
  local horizontalDirection = (starPounds.mcontroller.xVelocity > 0) and 1 or ((starPounds.mcontroller.xVelocity < 0) and -1 or 0)
  local verticalDirection = (starPounds.mcontroller.yVelocity > 0) and 1 or ((starPounds.mcontroller.yVelocity < 0) and -1 or 0)
  local canStruggle = not self.struggled and not status.resourceLocked("energy")
  self.cycle = vec2.lerp(5 * dt, (self.cycle or {0, 0}), vec2.mul({horizontalDirection, verticalDirection}, canStruggle and 1 or 0.25))
  local struggleMagnitude = vec2.mag(self.cycle)
  -- Spectating.
  local predPosition = world.entityPosition(storage.starPounds.pred)
  if storage.starPounds.spectatingPred then
    predPosition = vec2.add(predPosition, {0, math.sin(os.clock() * 0.5) * 0.25 - 0.25})
    local distance = world.distance(predPosition, starPounds.mcontroller.position)
    mcontroller.translate(vec2.lerp(10 * dt, {0, 0}, distance))
    local timer = self.spectateStopTimer or self.data.spectateStopTime
    if not (horizontalDirection == 0 and verticalDirection == 0) then
      self.spectateStopTimer = math.max(timer - dt, 0)
    else
      self.spectateStopTimer = self.data.spectateStopTime
    end
    -- Release after holding up.
    if timer == 0 then
      status.setResource("health", 0)
      self:released()
    end
    return
  end
  if not self.options.noStruggle then
    if not (horizontalDirection == 0 and verticalDirection == 0) then
      if struggleMagnitude > 0.6 then
        self.struggled = true
        if canStruggle then
          status.overConsumeResource("energy", status.resourceMax("energy") * self.data.struggleEnergyPlayer)
          world.sendEntityMessage(storage.starPounds.pred, "starPounds.pred.struggle", entity.id(), struggleStrength, not starPounds.hasOption("disableEscape"))
        end
      elseif status.resourceLocked("energy") then
        self.struggled = true
      elseif struggleMagnitude < 0.1 then
        self.struggled = false
      end
    elseif struggleMagnitude < 0.1 then
      self.struggled = false
      self.startedStruggling = os.clock()
    end
  end
  local predPosition = vec2.add(predPosition, vec2.mul(self.cycle, 2 + (math.sin((os.clock() - self.startedStruggling) * 2) + 1)/4))
  -- Slowly drift up/down.
  predPosition = vec2.add(predPosition, {0, math.sin(os.clock() * 0.5) * 0.25 - 0.25})
  local distance = world.distance(predPosition, starPounds.mcontroller.position)
  mcontroller.translate(vec2.lerp(10 * dt, {0, 0}, distance))
  -- No air.
  if not
    -- Skip if no damage, spectating, or options are off.
    (self.options.noDamage or
    storage.starPounds.spectatingPred or
    starPounds.hasOption("disablePreyDigestion") or
    starPounds.hasOption("disablePreyBreathLoss"))
    -- Only subtract air if we don't have an EPP, and the world isn't depleting it already.
  and (not status.statPositive("breathProtection")) and world.breathable(world.entityMouthPosition(entity.id())) then
    status.modifyResource("breath", -(status.stat("breathDepletionRate") * self.data.playerBreathMultiplier + status.stat("breathRegenerationRate")) * dt)
  end
end

function prey:npcStruggle(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if we're not eaten.
  if not storage.starPounds.pred then return end
  -- Monsters/NPCs just cause energy loss occassionally, and are locked to the pred's position.
  mcontroller.setPosition(vec2.add(world.entityPosition(storage.starPounds.pred), {0, -1}))
  -- Don't struggle if willing.
  if self.options.willing or self.options.noStruggle then return end
  local canStruggle = not status.resourceLocked("energy")
  -- NPCs don't lock/unlock energy by default.
  if status.resource("energy") == 1 then
    status.setResourceLocked("energy", false)
  end
  -- Loose calculation for how "powerful" the prey is.
  local healthMultiplier = 0.5 + status.resourcePercentage("health") * 0.5
  local struggleStrength = math.max(1, status.stat("powerMultiplier")) * healthMultiplier
  self.cycle = self.cycle and self.cycle - (dt * healthMultiplier) or (math.random(10, 15) / 10)
  if canStruggle and self.cycle <= 0 then
    status.overConsumeResource("energy", status.resourceMax("energy") * self.data.struggleEnergyNpc)
    -- NPCs don't lock/unlock energy by default.
    if status.resource("energy") == 0 then
      status.setResourceLocked("energy", true)
    end
    world.sendEntityMessage(storage.starPounds.pred, "starPounds.pred.struggle", entity.id(), struggleStrength, not starPounds.hasOption("disableEscape"))
    self.cycle = math.random(10, 15) / 10
  end
end

function prey:monsterStruggle(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if we're not eaten.
  if not storage.starPounds.pred then return end
  -- Monsters/NPCs just cause energy loss occassionally, and are locked to the pred's position.
  mcontroller.setPosition(vec2.add(world.entityPosition(storage.starPounds.pred), {0, -1}))
  -- Don't struggle if willing.
  if self.options.willing or self.options.noStruggle then return end
  -- Loose calculation for how "powerful" the prey is.
  local healthMultiplier = 0.5 + status.resourcePercentage("health") * 0.5
  -- Using the NPC power function because the monster one gets stupid high.
  local weightRatio = math.max((entity.weight + storage.starPounds.weight) / starPounds.species.default.weight, 0.1)
  local struggleStrength = math.max(1, status.stat("powerMultiplier")) * healthMultiplier * weightRatio
  self.cycle = self.cycle and self.cycle - (dt * healthMultiplier) or (math.random(10, 15) / 10)
  if self.cycle <= 0 then
    world.sendEntityMessage(storage.starPounds.pred, "starPounds.pred.struggle", entity.id(), struggleStrength, not starPounds.hasOption("disableEscape"))
    self.cycle = math.random(10, 15) / 10
  end
end

function prey:released(source, overrideStatus)
  -- Don't do anything if we're not eaten.
  if not storage.starPounds.pred then return end
  -- Argument sanitisation.
  source = tonumber(source)
  overrideStatus = overrideStatus and tostring(overrideStatus) or nil
  -- Reset damage team.
  entity.setDamageTeam(storage.starPounds.damageTeam)
  storage.starPounds.damageTeam = nil
  local pred = storage.starPounds.pred
  local options = self.options
  -- Remove the pred id from storage.
  storage.starPounds.pred = nil
  -- Recreate tracking status effects.
  starPounds.moduleFunc("trackers", "createStatuses")
  self.options = {}
  storage.starPounds.spectatingPred = nil
  -- Reset struggle cycle.
  self.cycle = nil
  status.clearPersistentEffects("starpoundseaten")
  status.removeEphemeralEffect("starpoundseaten")
  entity.setDamageOnTouch(true)
  -- Set cooldown if needed.
  if options.triggerCooldown then
    self.voreCooldown = self.data.cooldown
  end
  -- Reset interaction.
  if self.wasInteractable then
    if starPounds.type == "npc" then
      npc.setInteractive(true)
    end
  end
  -- Restore techs, and set cooldown.
  if starPounds.type == "player" then
    -- Restore techs.
    for _,v in pairs({"head", "body", "legs"}) do
      player.unequipTech("starpoundseaten_"..v)
      player.makeTechUnavailable("starpoundseaten_"..v)
    end
    for _,v in pairs(self.oldTech or {}) do
      player.equipTech(v)
    end
  end
  -- Out.
  if world.entityExists(pred, true) then
    -- Callback incase the entity calls this.
    if source ~= pred then
      world.sendEntityMessage(pred, "starPounds.pred.release", entity.id())
    end
    -- Don't get stuck in the ground.
    mcontroller.setPosition(world.entityPosition(pred))
    -- Make them wet.
    status.addEphemeralEffect(overrideStatus or "starpoundsslimy")
    -- Behaviour damage trigger.
    if not options.willing then
      self.notifyDamage(pred)
    end
  end
end

function prey:newPred(pred)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  pred = tonumber(pred)
  if not pred then return false end
  -- Don't do anything if disabled.
  if starPounds.hasOption("disablePrey") then return false end
  -- Don't do anything if not already eaten.
  if not storage.starPounds.pred then return false end
  -- New pred.
  storage.starPounds.pred = pred
  return true
end

function prey:digesting(pred, digestionRate, protectionPierce)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if a pred ID isn't specified.
  if not pred or not world.entityExists(tonumber(pred) or 0, true) then return end
  -- Tell the pred we're not eaten there's an ID mismatch.
  if storage.starPounds.pred ~= pred then
    world.sendEntityMessage(pred, "starPounds.pred.release", entity.id())
  end
  -- Skip if we're not taking damage.
  if self.options.noDamage then return end
  -- Argument sanitisation.
  digestionRate = math.max(tonumber(digestionRate) or 0, 0)
  protectionPierce = math.max(tonumber(protectionPierce) or 0, 0)
  if digestionRate == 0 then return end
  -- Don't do anything if disabled.
  if starPounds.hasOption("disablePreyDigestion") then return end
  -- Don't do anything if we're not eaten.
  if not storage.starPounds.pred then return end
  -- 0.5% of current health + 1 or 0.5% max health, whichever is smaller. (Stops low hp entities dying instantly)
  local percentDigestion = status.resource("health") * self.data.percentDigestionRate
  local flatDigestion = math.min(self.data.digestionRate, self.data.percentDigestionRate * status.resourceMax("health"))
  local amount = (percentDigestion + flatDigestion) * digestionRate
  amount = root.evalFunction2("protection", amount, status.stat("protection") - protectionPierce)
  -- Remove the health.
  status.overConsumeResource("health", amount)
  if not status.resourcePositive("health") then
    self:die()
  end
end

function prey:healing(pred, healingRate)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if a pred ID isn't specified.
  if not pred or not world.entityExists(tonumber(pred) or 0, true) then return end
  -- Tell the pred we're not eaten there's an ID mismatch.
  if storage.starPounds.pred ~= pred then
    world.sendEntityMessage(pred, "starPounds.pred.release", entity.id())
  end
  -- Argument sanitisation.
  healingRate = math.max(tonumber(healingRate) or 0, 0)
  if healingRate == 0 then return end
  -- Don't do anything if we're not eaten.
  if not storage.starPounds.pred then return end
  -- 2.5% of missing health + 5 or 2.5% max health, whichever is smaller. (Stops low hp entities healing instantly)
  local maxHealth = status.resourceMax("health")
  local percentHealing = (maxHealth - status.resource("health")) * self.data.percentHealingRate
  local flatHealing = math.min(self.data.healingRate, self.data.percentHealingRate * maxHealth)
  local amount = (percentHealing + flatHealing) * healingRate
  -- Add health.
  status.giveResource("health", amount)
end

function prey:digested()
  -- Don't run if there's no pred.
  if not storage.starPounds.pred then return end
  world.sendEntityMessage(storage.starPounds.pred, "starPounds.pred.digestPrey", entity.id(), self:createDrops(self.options.items), storage.starPounds.stomachEntities)
  -- Transfer over stomach contents.
  for foodType, amount in pairs(storage.starPounds.stomach) do
    world.sendEntityMessage(storage.starPounds.pred, "starPounds.feed", amount, foodType)
  end
  -- Transfer over breast contents.
  local breastContents = starPounds.moduleFunc("breasts", "get")
  if breastContents then
    for foodType, amount in pairs(starPounds.moduleFunc("liquid", "get", breastContents.type).food) do
      world.sendEntityMessage(storage.starPounds.pred, "starPounds.feed", breastContents.contents * amount, foodType)
    end
  end
  -- Player stuff.
  if starPounds.type == "player" then
    if starPounds.hasOption("spectatePred") then
      player.playCinematic("/cinematics/starpounds/starpoundsvore.cinematic")
      storage.starPounds.spectatingPred = true
    else
      for _,v in pairs({"head", "body", "legs"}) do
        player.unequipTech("starpoundseaten_"..v)
        player.makeTechUnavailable("starpoundseaten_"..v)
      end
      for _,v in pairs(self.oldTech or {}) do
        player.equipTech(v)
      end
    end
  end
  -- NPC stuff.
  if starPounds.type == "npc" then
    if world.entityUniqueId(storage.starPounds.pred) and world.entityUniqueId(storage.starPounds.pred) == self.deliveryTarget then
      world.sendEntityMessage(storage.starPounds.pred, "starPounds.digestedPizzaEmployee")
    end
    -- Are they a crewmate?
    if recruitable then
      -- Did their owner eat them?
      local predId = storage.starPounds.pred
      storage.starPounds.pred = nil
      if recruitable.ownerUuid() and world.entityUniqueId(predId) == recruitable.ownerUuid() then
        recruitable.messageOwner("recruits.digestedRecruit", recruitable.recruitUuid())
      end
      recruitable.despawn()
      return
    end
  end
  -- Getting digested by a player or NPC removes all your fat.
  local predType = world.entityType(storage.starPounds.pred)
  if (predType == "player") or (predType == "npc") then
    starPounds.moduleFunc("size", "setWeight", 0)
  end
end

function prey:createDrops(items)
  local level = 0
  local equippedItemFunc = function() return end
  if starPounds.type == "player" then
    equippedItemFunc = player.equippedItem
  elseif starPounds.type == "npc" then
    level = npc.level()
    equippedItemFunc = npc.getItemSlot
  end

  local items = items or {}
  for _, slot in ipairs({"head", "chest", "legs", "back"}) do
    local item = equippedItemFunc(slot.."Cosmetic") or equippedItemFunc(slot)
    if item then
      if (item.parameters and item.parameters.tempSize) then
        item.name = item.parameters.baseName
        item.parameters.scaledSize = nil
        item.parameters.baseName = nil
      end
      item.name = configParameter(item, "regurgitateItem", item.name)
      if not (item.parameters and item.parameters.size) and not configParameter(item, "hideBody") and not configParameter(item, "disableRegurgitation") then
        table.insert(items, item)
      end
    end
  end
  -- Give essence if applicable.
  if starPounds.type == "monster" then
    level = monster.level()
    local dropPools = sb.jsonQuery(monster.uniqueParameters(), "dropPools", jarray())
    if dropPools[1] and dropPools[1].default then
      local dropItems = root.createTreasure(dropPools[1].default, monster.level())
      for _, item in ipairs(dropItems) do
        if item.name == "essence" then table.insert(items, item) end
      end
    end
  end

  for _, pool in ipairs(entity.preyTreasure) do
    for _, item in ipairs(root.createTreasure(pool, level)) do
      table.insert(items, item)
    end
  end

  return items
end

function prey:die()
  if storage.starPounds.pred then
    self:digested()
    -- NPC stuff.
    if starPounds.type == "npc" then
      local setDying = setDying or (function() end)
      setDying({shouldDie = true})
      npc.setDropPools({})
      npc.setDeathParticleBurst()
      status.setResource("health", 0)
    end
    -- Monster stuff.
    if starPounds.type == "monster" then
      monster.setDropPool(nil)
      monster.setDeathParticleBurst(nil)
      monster.setDeathSound(nil)
      _ENV.self.deathBehavior = nil
      _ENV.self.shouldDie = true
      status.addEphemeralEffect("monsterdespawn")
    end
    if not storage.starPounds.spectatingPred then
      storage.starPounds.pred = nil
    end
  end
end

local die_old = die or (function() end)
function die()
  prey:die()
  die_old()
end

function prey.notifyDamage(predId)
  -- NPCs/monsters become hostile when released (as if damaged normally).
  if starPounds.type == "npc" then
    notify({type = "attack", sourceId = entity.id(), targetId = predId})
  elseif starPounds.type == "monster" then
    self.damaged = true
    if self.board then self.board:setEntity("damageSource", predId) end
  end
end

function prey:uninit()
  if self.oldTech then
    storage.starPounds.preyTech = self.oldTech
  end
  -- Save options so we can restore if we're eaten during a reload.
  if self.options and storage.starPounds.pred then
    storage.starPounds.preyOptions = self.options
  end
end

starPounds.modules.prey = prey
