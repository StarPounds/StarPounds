local pred = starPounds.module:new("pred")

function pred:init()
  message.setHandler("starPounds.pred.hasPrey", function(_, _, ...) return self:hasPrey(...) end)
  message.setHandler("starPounds.pred.eat", function(_, _, ...) return self:eat(...) end)
  message.setHandler("starPounds.pred.eatNearby", function(_, _, ...) return self:eatNearby(...) end)
  message.setHandler("starPounds.pred.digest", function(_, _, ...) return self:digest(...) end)
  message.setHandler("starPounds.pred.digestPrey", function(_, _, ...) return self:digestPrey(...) end)
  message.setHandler("starPounds.pred.struggle", function(_, _, ...) return self:struggle(...) end)
  message.setHandler("starPounds.pred.release", function(_, _, ...) return self:release(...) end)

  self.voreCooldown = 0

  self.hasEntity = false

  self.struggleCooldown = 0
  self.storedStruggleStrength = 0
  self.storedStruggleVolume = 0
  self.struggleVolumeLerp = 0

  self.preyCheckTimer = self.data.preyCheckTimer
end

function pred:update(dt)
  -- Tick down tool/hotkey cooldown.
  self.voreCooldown = math.max(self.voreCooldown - (dt / starPounds.getStat("voreCooldown")), 0)
  self.struggleCooldown = math.max(self.struggleCooldown - dt, 0)
  self:preyCheck(dt)
  -- Don't run if we don't need to.
  if (self.struggleVolumeLerp + self.storedStruggleVolume > 0) then
    self.struggleVolumeLerp = math.max(0, math.round(util.lerp(dt, self.struggleVolumeLerp, self.storedStruggleVolume - 0.05), 4))
  end

  self.hasEntity = storage.starPounds.enabled and (#storage.starPounds.stomachEntities > 0)
end

function pred:digest(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  dt = math.max(tonumber(dt) or 0, 0)
  if dt == 0 then return end
  -- Don't do anything if disabled.
  if starPounds.hasOption("disablePredDigestion") then return end
  -- Don't do anything if there's no eaten entities.
  if not (#storage.starPounds.stomachEntities > 0) then return end
  -- Eaten entities take less damage the more food/entities the player has eaten (While over capacity). Max of 3x slower.
  local vorePenalty = math.min(1 + math.max(starPounds.stomach.fullness - starPounds.settings.thresholds.strain.starpoundsstomach3, 0), 3)
  local damageMultiplier = math.max(1, status.stat("powerMultiplier")) * starPounds.getStat("voreDamage")
  local protectionPierce = math.max(0, starPounds.getStat("voreArmorPiercing"))
  -- Reduce health of all entities.
  for _, prey in pairs(storage.starPounds.stomachEntities) do
    if prey.safe then
      world.sendEntityMessage(prey.id, "starPounds.prey.healing", entity.id(), starPounds.getStat("voreHealing") * dt)
    else
      world.sendEntityMessage(prey.id, "starPounds.prey.digesting", entity.id(), (damageMultiplier/vorePenalty) * dt, protectionPierce)
    end
  end
end

function pred:eat(preyId, options, check)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return false end
  -- Argument sanitisation.
  preyId = tonumber(preyId)
  if not preyId then return false end
  options = type(options) == "table" and options or {}
  -- Legacy mode doesn't require the skill.
  options.ignoreSkills = options.ignoreSkills or starPounds.hasOption("legacyMode")
  -- Check if they exist.
  if not world.entityExists(preyId, true) then return false end
  -- Counting this as 'combat', so no eating stuff on protected worlds. (e.g. the outpost)
  if world.getProperty("nonCombat") and not options.ignoreProtection then return false end
  -- Don't do anything if pred is disabled.
  if starPounds.hasOption("disablePred") then return false end
  -- Need the upgrades for parts of the skill to work.
  local canVoreCritter = starPounds.moduleFunc("skills", "has", "voreCritter")
  local canVoreMonster = starPounds.moduleFunc("skills", "has", "voreMonster")
  local canVoreHumanoid = starPounds.moduleFunc("skills", "has", "voreHumanoid")
  local canVoreFriendly = options.ignoreSkills or starPounds.moduleFunc("skills", "has", "voreFriendly")
  -- Skip if we can't eat anything at all.
  if not (
    canVoreCritter or
    canVoreMonster or
    canVoreHumanoid or
    options.ignoreSkills
  ) then return false end
  -- Store so we don't have to grab multiple times.
  local preyType = world.entityTypeName(preyId)
  -- Can't eat friendlies without the skill.
  if not canVoreFriendly and not world.entityCanDamage(entity.id(), preyId) then return false end
  -- Don't do anything if eaten.
  if storage.starPounds.pred then return false end
  -- Can only eat if you're below capacity.
  if starPounds.stomach.fullness >= starPounds.settings.thresholds.strain.starpoundsstomach and not starPounds.moduleFunc("skills", "has", "wellfedProtection") and not options.ignoreCapacity then
    return false
  elseif starPounds.stomach.fullness >= starPounds.settings.thresholds.strain.starpoundsstomach3 and not options.ignoreCapacity then
    return false
  end
  -- Don't do anything if they're already eaten.
  if self:hasPrey(preyId) then return false end
  -- Don't do anything if they're not a compatible entity.
  local compatibleEntities = jarray()
  if canVoreCritter or canVoreMonster then
    compatibleEntities[#compatibleEntities + 1] = "monster"
  end
  if canVoreHumanoid then
    compatibleEntities[#compatibleEntities + 1] = "npc"
    compatibleEntities[#compatibleEntities + 1] = "player"
  end
  local preyType = world.entityTypeName(preyId)
  if not options.ignoreEnergyRequirement and status.isResource("energy") and status.resourceLocked("energy") then return false end
  if not options.ignoreSkills then
    if not contains(compatibleEntities, world.entityType(preyId)) then return false end
    -- Need the upgrades for the specific entity type
    if world.entityType(preyId) == "monster" then
      local scriptCheck = contains(root.monsterParameters(preyType).scripts or jarray(), "/scripts/starpounds/loaders/monster.lua")
      if scriptCheck then
        if (not canVoreMonster) and (not preyType:find("critter")) then return false end
        if (not canVoreCritter) and preyType:find("critter") then return false end
      else
        local behavior = root.monsterParameters(preyType).behavior
        if contains(self.data.critterBehaviors, behavior) and not canVoreCritter then return false end
        if contains(self.data.monsterBehaviors, behavior) and not canVoreMonster then return false end
      end
    end
  end

  -- Skip the rest if the monster/npc can't be eaten to begin with.
  local isCritter = false
  if world.entityType(preyId) == "monster" then
    local scriptCheck = contains(root.monsterParameters(preyType).scripts or jarray(), "/scripts/starpounds/loaders/monster.lua")
    local parameters = root.monsterParameters(preyType)
    isCritter = contains(self.data.critterBehaviors, parameters.behavior)
    local isMonster = contains(self.data.monsterBehaviors, parameters.behavior)
    local behaviorCheck = parameters.behavior and (isCritter or isMonster) or false
    if parameters.starPounds_options and parameters.starPounds_options.disablePrey then return false end
    if not (scriptCheck or behaviorCheck) then
      return false
    end
  end

  if world.entityType(preyId) == "npc" then
    if not contains(root.npcConfig(preyType).scripts or jarray(), "/scripts/starpounds/loaders/npc.lua") then return false end
    if world.getNpcScriptParameter(preyId, "starPounds_options", jarray()).disablePrey then return false end
    if starPounds.type == "player" and starPounds.hasOption("disableCrewVore") and world.getNpcScriptParameter(preyId, "ownerUuid") ~= entity.uniqueId() then return false end
  end

  if world.entityDamageTeam(preyId).type == "ghostly" then return false end
  -- Skip eating if we're only checking for a valid target.
  if check then return true end
  -- Options to pass prey-side.
  local safe = starPounds.moduleFunc("skills", "has", "voreSafe") and not world.entityCanDamage(entity.id(), preyId)
  local noDamage = options.noDamage or safe
  local willing = noDamage and (options.willing or starPounds.moduleFunc("skills", "has", "voreWilling")) or nil
  local preyOptions = {
    triggerCooldown = options.triggerPreyCooldown,
    maxWeight = options.maxWeight,
    noDamage = noDamage and true or nil,
    willing = willing and true or nil,
    noStruggle = options.noStruggle,
    silent = not options.loud and (options.silent or starPounds.moduleFunc("skills", "has", "voreSilent")) or nil,
    loud = options.loud
  }
  local preyPosition = world.entityPosition(preyId)
  -- Ask the entity to be eaten, add to stomach if the promise is successful.
  promises:add(world.sendEntityMessage(preyId, "starPounds.prey.swallowed", entity.id(), preyOptions), function(prey)
    if not (prey and (prey.base or prey.weight)) then return end
    local preyConfig = {
      id = preyId,
      base = prey.base or 0,
      weight = prey.weight or 0,
      foodType = prey.foodType or "prey",
      experience = prey.experience or 0,
      world = (starPounds.type == "player") and player.worldId() or nil,
      noRelease = prey.noRelease or options.noRelease,
      noEscape = prey.noEscape or options.noEscape,
      noBelch = prey.noBelch or options.noBelch,
      safe = safe,
      type = world.entityType(preyId):gsub(".+", {player = "humanoid", npc = "humanoid", monster = "creature"}),
      typeName = world.entityTypeName(preyId)
    }
    -- Overstuffing damage proxy. (Player only)
    if starPounds.type == "player" and not preyOptions.willing then
      local foodType = prey.foodType and tostring(prey.foodType) or "default"
      if not starPounds.foods[prey.foodType] then foodType = "prey" end
      local capacityMult = starPounds.foods[foodType].multipliers.capacity
      starPounds.moduleFunc("stomach", "eat", preyConfig.base * capacityMult, "prey_proxy")
      starPounds.moduleFunc("stomach", "eat", preyConfig.weight, "preyWeight_proxy")
      -- Clear them so the stomach size doesn't change.
      storage.starPounds.stomach.prey_proxy = nil
      storage.starPounds.stomach.preyWeight_proxy = nil
    end
    -- Insert prey into tracking table.
    table.insert(storage.starPounds.stomachEntities, preyConfig)
    -- Eating energy cost.
    local energyMult = (options.energyMultiplier or 1) * starPounds.getStat("voreEnergy")
    if energyMult > 0 then
      local preyHealth = world.entityHealth(preyId)
      local preyHealthPercent = preyHealth[1]/preyHealth[2]
      local preySizeMult = (1 + (((prey.base or 0) + (prey.weight or 0))/starPounds.species.default.weight)) * 0.5
      if isCritter then
        preySizeMult = preySizeMult * self.data.critterEnergyMultiplier
      end
      local energyCost = (options.energyMultiplier or 1) * (self.data.energyBase + self.data.energy * preyHealthPercent * preySizeMult)
      status.overConsumeResource("energy", energyCost)
    end
    -- Trigger the tool/hotkey cooldown.
    if options.triggerPredCooldown then
      self:cooldownStart()
    end
    -- Swallow sound.
    if not (options.noSound or options.noSwallowSound) then
      starPounds.moduleFunc("sound", "play", "swallow", 1 + math.random(0, 10)/100)
    end
    -- Stomach sound.
    if not (options.noSound or options.noDigestSound) then
      starPounds.moduleFunc("sound", "play", "digest", 1, 0.75)
    end
    -- Squelch sound.
    if not (options.noSound or starPounds.hasOption("disableSquelchSounds")) and options.playSquelchSound then
      starPounds.moduleFunc("sound", "play", "voreSquelch", 1.25 + math.random(0, 10)/100, 1.25)
    end

    if options.particles and not starPounds.hasOption("disableVoreParticles") then
      local direction = world.distance(preyPosition, starPounds.mcontroller.position)[1] > 0 and "right" or "left"
      world.spawnProjectile("starpoundsvorebite" .. direction, preyPosition, entity.id())
    end

    starPounds.events:fire("pred:eatEntity", preyConfig)
  end)
  return true
end

function pred:eatNearby(position, range, querySize, options, check)
  -- Argument sanitisation.
  position = (type(position) == "table" and type(position[1]) == "number" and type(position[2]) == "number") and position or starPounds.mcontroller.position
  range = math.max(tonumber(range) or 0, 0)
  querySize = math.max(tonumber(querySize) or 0, 0)
  options = type(options) == "table" and options or {}

  local mouthPosition = starPounds.mcontroller.mouthPosition
  if starPounds.currentSize.yOffset then
    mouthPosition = vec2.add(mouthPosition, {0, starPounds.currentSize.yOffset})
  end

  local preferredEntities = position and world.entityQuery(position, querySize, {order = "nearest", includedTypes = {"player", "npc", "monster"}, withoutEntityId = entity.id()}) or jarray()
  local nearbyEntities = world.entityQuery(mouthPosition, range, {order = "nearest", includedTypes = {"player", "npc", "monster"}, withoutEntityId = entity.id()})
  local eatenTargets = jarray()

  for _, prey in ipairs(storage.starPounds.stomachEntities) do
    eatenTargets[prey.id] = true
  end

  local function isTargetValid(target)
    return not eatenTargets[target] and not world.lineTileCollision(mouthPosition, world.entityPosition(target), {"Null", "Block", "Dynamic", "Slippery"})
  end

  for _, target in ipairs(preferredEntities) do
    if isTargetValid(target) then
      return {self:eat(target, options, check), true}
    end
  end

  for _, target in ipairs(nearbyEntities) do
    if isTargetValid(target) then
      return {self:eat(target, options, check), false}
    end
  end
end

function pred:cooldown()
  return self.voreCooldown
end

function pred:cooldownTime()
  return self.data.cooldown
end

function pred:cooldownStart()
  self.voreCooldown = self.data.cooldown
end

function pred:digestPrey(preyId, items, preyStomach)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  preyId = tonumber(preyId)
  if not preyId then return end
  -- Don't do anything if disabled.
  if starPounds.hasOption("disablePredDigestion") then return end
  -- Find the entity's entry in the stomach.
  local digestedEntity = nil
  for preyIndex, prey in ipairs(storage.starPounds.stomachEntities) do
    if prey.id == preyId then
      digestedEntity = table.remove(storage.starPounds.stomachEntities, preyIndex)
      break
    end
  end
  -- Don't do anything if we didn't digest an entity.
  if not digestedEntity then return end
  -- Transfer eaten entities.
  storage.starPounds.stomachEntities = util.mergeLists(storage.starPounds.stomachEntities, preyStomach or jarray())
  for _, prey in ipairs(preyStomach or jarray()) do
    world.sendEntityMessage(prey.id, "starPounds.prey.newPred", entity.id())
  end
  -- Iterate over and edit the items.
  local regurgitatedItems = jarray()
  local hasEssence = false
  if digestedEntity.type == "humanoid" then
    -- Add soul effect if we have the skill.
    if starPounds.moduleFunc("skills", "has", "voreSouls") then
      starPounds.moduleFunc("effects", "add", "voreSouls")
    end
    -- We get purple particles if we digest something that gives ancient essence.
    for _, item in pairs(root.createTreasure("essenceDrop", world.threatLevel())) do
      if item.name == "essence" then
        local itemCount = math.round(item.count * starPounds.getStat("voreEssence"))
        if itemCount > 0 then
          player.addCurrency(item.name, itemCount)
          hasEssence = true
        end
      end
    end
  end
  for _, item in pairs(items or jarray()) do
    for _, scrapItem in ipairs(self:digestItem(item)) do
      if scrapItem.name == "essence" then
        if starPounds.type == "player" then player.giveItem(scrapItem) end
        hasEssence = true
      else
        regurgitatedItems[#regurgitatedItems + 1] = scrapItem
      end
    end
  end

  local doBelch = not (starPounds.hasOption("disableBelches") or starPounds.hasOption("disablePredBelches") or digestedEntity.noBelch)
  -- No belching up items if belching (or their particles) is disabled on the pred or prey side.
  local doBelchParticles = doBelch and not starPounds.hasOption("disableBelchParticles")
  -- Burp/Stomach gurgle.
  if doBelch then
    local belchVolume = 0.75
    local belchPitch = 1 - math.round(((digestedEntity.base + digestedEntity.weight) - starPounds.species.default.weight)/(starPounds.settings.maxWeight * 4), 2)
    starPounds.moduleFunc("belch", "belch", belchVolume, belchPitch)
    starPounds.moduleFunc("stomach", "stopBelch") -- Cancel queued belch.
  end

  if doBelchParticles then
    self:belchParticles(digestedEntity, hasEssence)
  end

  if not starPounds.hasOption("disableGurgleSounds") then
    starPounds.moduleFunc("sound", "play", "digest", 0.75, 0.75)
  end

  if not starPounds.hasOption("disableItemRegurgitation") and (#regurgitatedItems > 0) then
    if doBelchParticles then
      world.spawnProjectile("regurgitateditems", starPounds.mcontroller.mouthPosition, entity.id(), vec2.rotate({math.random(1,2) * starPounds.mcontroller.facingDirection, math.random(0, 2)/2}, starPounds.mcontroller.rotation), false, {
        items = regurgitatedItems
      })
    elseif starPounds.type == "player" then
      for _, regurgitatedItem in pairs(regurgitatedItems) do
        player.giveItem(regurgitatedItem)
      end
    end
  end

  starPounds.moduleFunc("stomach", "feed", digestedEntity.base, digestedEntity.foodType)
  starPounds.moduleFunc("stomach", "feed", digestedEntity.weight, "preyWeight")
  starPounds.events:fire("pred:digestEntity", digestedEntity)
  return true
end

function pred:struggle(preyId, struggleStrength, escape)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  preyId = tonumber(preyId)
  struggleStrength = math.max(tonumber(struggleStrength) or 0, 0)
  if not preyId then return end
  -- Only continue if they're actually eaten.
  for preyIndex, prey in ipairs(storage.starPounds.stomachEntities) do
    if prey.id == preyId then
      local preyHealth = world.entityHealth(prey.id)
      local preyHealthPercent = preyHealth[1]/preyHealth[2]
      local preyWeight = (prey.base or 0) + (prey.weight or 0)
      local struggleStrength = root.evalFunction2("protection", struggleStrength, status.stat("protection"))
      local escapeChance = math.max(world.entityType(preyId) == "player" and self.data.playerEscape or 0, 0.5 * struggleStrength)
      local released = false
      if escape and (math.random() < escapeChance) then
        if world.entityType(preyId) == "player" or (not prey.noEscape and status.resourceLocked("energy") and preyHealthPercent > self.data.inescapableHealth) then
          released = self:release(preyId)
          starPounds.events:fire("pred:entityEscape", released)
        end
      end
      -- If struggles are on cooldown, store the 'strength' and weight and apply it to the next valid one.
      if self.struggleCooldown > 0 then
        self.storedStruggleStrength = self.storedStruggleStrength + struggleStrength
        self.storedStruggleVolume = math.min(self.storedStruggleVolume + 0.25 + preyHealthPercent * (preyWeight/(starPounds.species.default.weight * 2)), 1)
        break
      end

      struggleStrength = struggleStrength + self.storedStruggleStrength

      if status.isResource("energy") then
        local struggleMultiplier = math.max(0, 1 - starPounds.getStat("struggleResistance"))
        local energyAmount = struggleMultiplier * (self.data.struggleEnergyBase + self.data.struggleEnergy * struggleStrength)
        if status.isResource("energyRegenBlock") and status.resourceLocked("energy") then
          status.modifyResource("energyRegenBlock", status.stat("energyRegenBlockTime") * self.data.struggleEnergyLock * struggleMultiplier * struggleStrength)
        elseif status.resource("energy") > energyAmount then
          status.modifyResource("energy", -energyAmount)
        else
          status.overConsumeResource("energy", energyAmount)
        end
      end

      if not (released or starPounds.hasOption("disablePredDigestion")) then
        -- 1 second worth of digestion per struggle.
        local damageMultiplier = math.max(1, status.stat("powerMultiplier")) * starPounds.getStat("voreDamage")
        local protectionPierce = math.max(0, 1 - starPounds.getStat("voreArmorPiercing"))
        world.sendEntityMessage(preyId, "starPounds.prey.digesting", entity.id(), damageMultiplier, protectionPierce)
      end

      -- Outside the block so we can pass it to the event.
      local struggleVolume = math.min(0.75, 0.25 + preyHealthPercent * (preyWeight/(starPounds.species.default.weight * 2)) + self.struggleVolumeLerp)
      local strugglePitch = 1 + 0.1 * (math.random() - 0.5)

      if not starPounds.hasOption("disableStruggleSounds") then
        starPounds.moduleFunc("sound", "play", "struggle", struggleVolume, strugglePitch)
      end

      starPounds.events:fire("pred:struggle", struggleVolume, strugglePitch)

      self.storedStruggleVolume = 0
      self.storedStruggleStrength = 0
      self.struggleCooldown = util.randomInRange({self.data.minimumStruggleCooldownTime, (self.data.struggleCooldownTime * 2) - self.data.minimumStruggleCooldownTime})
      break
    end
  end
end

function pred:release(preyId, releaseAll)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  preyId = tonumber(preyId)
  -- Delete the entity's entry in the stomach.
  local releasedEntity = nil
  local statusEffect = starPounds.moduleFunc("skills", "has", "regurgitateSlimeStatus") and "starpoundsslimyupgrade" or nil
  if releaseAll then
    releasedEntity = storage.starPounds.stomachEntities[1]
    for preyIndex, prey in ipairs(storage.starPounds.stomachEntities) do
      if world.entityExists(prey.id, true) then
        world.sendEntityMessage(prey.id, "starPounds.prey.released", entity.id(), statusEffect)
      end
    end
    if releasedEntity and world.entityExists(releasedEntity.id, true) then
      local belchVolume = 0.75
      local belchPitch = 1 - math.round((releasedEntity.weight + storage.starPounds.weight - starPounds.species.default.weight)/(starPounds.settings.maxWeight * 4), 2)
      starPounds.moduleFunc("belch", "belch", belchVolume, belchPitch)
      starPounds.moduleFunc("stomach", "stopBelch") -- Cancel queued belch.
    end
    storage.starPounds.stomachEntities = jarray()
  else
    -- Reverse order, lastest prey gets removed first (if not specified).
    for preyIndex = #storage.starPounds.stomachEntities, 1, -1 do
      local prey = storage.starPounds.stomachEntities[preyIndex]
      if not prey.noRelease or (starPounds.type == "player" and player.isAdmin()) then
        -- Release the first (allowed) prey, or a specific ID if given.
        if (not preyId) or (prey.id == preyId) then
          releasedEntity = table.remove(storage.starPounds.stomachEntities, preyIndex)
          break
        end
      end
    end
    -- Call back to release the entity incase the pred is releasing them.
    if releasedEntity and world.entityExists(releasedEntity.id, true) then
      local belchVolume = 0.75
      local belchPitch = 1 - math.round((releasedEntity.weight + storage.starPounds.weight - starPounds.species.default.weight)/(starPounds.settings.maxWeight * 4), 2)
      starPounds.moduleFunc("belch", "belch", belchVolume, belchPitch)
      starPounds.moduleFunc("stomach", "stopBelch") -- Cancel queued belch.

      world.sendEntityMessage(releasedEntity.id, "starPounds.prey.released", entity.id(), statusEffect)
      starPounds.events:fire("pred:releaseEntity", releasedEntity)
    end
  end
  -- Callback.
  if releasedEntity then return true end
end

function pred:preyCheck(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if there's no eaten entities.
  if not self.hasEntity then return end
  -- Run on a timer unless manually called.
  if dt then
    self.preyCheckTimer = math.max(self.preyCheckTimer - dt, 0)
    if self.preyCheckTimer > 0 then return end
  end
  -- table.remove is doodoo poop water.
  local newStomach = jarray()
  for preyIndex, prey in ipairs(storage.starPounds.stomachEntities) do
    if world.entityExists(prey.id, true) then
      newStomach[#newStomach + 1] = prey
    end
  end
  storage.starPounds.stomachEntities = newStomach

  self.preyCheckTimer = self.data.preyCheckTimer
end

function pred:hasPrey(preyId)
  -- Argument sanitisation.
  preyId = tonumber(preyId)
  if not preyId then return false end
  for _, prey in ipairs(storage.starPounds.stomachEntities) do
    if prey.id == preyId then return true end
  end
  return false
end

function pred:digestItem(item)
  local convertedItems = jarray()
  local itemType = root.itemType(item.name)
  if string.find(root.itemType(item.name), "armor") then itemType = "clothing" end

  if itemType == "clothing" then
    if math.random() < starPounds.getStat("regurgitateClothingChance") then
      -- Give them item digested effects
      item = self:digestClothing(item)
      -- Spawn the item, but double check if it's still clothing (in case of pgis)
      if (root.itemType(item.name) == "clothing") or string.find(root.itemType(item.name), "armor") then
        convertedItems[#convertedItems + 1] = item
      end
    -- Second chance to regurgitate 'scrap' items instead.
    elseif math.random() < starPounds.getStat("regurgitateChance") then
      -- Default to clothing drops.
      local armorType = ""
      -- Check if it's a tier 5/6 armor, since the classes have different components.
      if configParameter(item, "level", 0) > 4 then
        for _, recipe in ipairs(root.recipesForItem(item.name)) do
          if contains(recipe.groups, "craftingaccelerator") then armorType = "Accelerator" break
          elseif contains(recipe.groups, "craftingmanipulator") then armorType = "Manipulator" break
          elseif contains(recipe.groups, "craftingseparator") then armorType = "Separator" break
          end
        end
      end
      -- Add drops to the pool.
      -- Regular drops.
      local itemLevel = math.min(configParameter(item, "level", 0), math.max(world.threatLevel(), 1))
      for _, item in ipairs(root.createTreasure("voreRegurgitated"..armorType, itemLevel)) do
        convertedItems[#convertedItems + 1] = item
      end
    end
  else
    convertedItems[#convertedItems + 1] = item
  end
  return convertedItems
end

function pred:digestClothing(item)
  -- Argument sanitisation.
  if not (item and type(item) == "table") then return end
  item = root.createItem(item)
  -- Make sure this exists to start with.
  item.parameters = item.parameters or {}
  -- First time digesting the item.
  if not item.parameters.baseParameters then
    local baseParameters = {}
    for k, v in pairs(item.parameters) do
      baseParameters[k] = v
    end
    item.parameters.baseParameters = baseParameters
  end
  item.parameters.digestCount = item.parameters.digestCount and math.min(item.parameters.digestCount + 1, 3) or 1
  -- Reset values before editing.
  item.parameters.category = item.parameters.baseParameters.category
  item.parameters.price = item.parameters.baseParameters.price
  item.parameters.level = item.parameters.baseParameters.level
  item.parameters.directives = item.parameters.baseParameters.directives
  item.parameters.colorIndex = item.parameters.baseParameters.colorIndex
  item.parameters.colorOptions = item.parameters.baseParameters.colorOptions
  -- Add visual flair and reduce rarity down to common.
  local label = root.assetJson("/items/categories.config:labels")[configParameter(item, "category", ""):gsub("enviroProtectionPack", "backwear")]
  item.parameters.category = string.format("%sDigested %s%s", starPounds.hasOption("disableRegurgitatedClothingTint") and "" or "^#a6ba5d;", label, ((item.parameters.digestCount > 1) and string.format(" (x%s)", item.parameters.digestCount) or ""))
  item.parameters.rarity = configParameter(item, "rarity", "common"):lower():gsub(".+", { uncommon = "common", rare = "uncommon", legendary = "rare" })
  -- Reduce price to 10% (15% - 5% per digestion) of the original value.
  item.parameters.price = math.round(configParameter(item, "price", 0) * (0.15 - 0.05 * item.parameters.digestCount))
  -- Reduce armor level by 1 per digestion. (Or planet threat level, whatever is lower)
  item.parameters.level = util.clamp(configParameter(item, "level", 0) - item.parameters.digestCount, configParameter(item, "level", 0) > 0 and 1 or 0, world.threatLevel())
  -- Disable status effects.
  item.parameters.statusEffects = root.itemConfig(item).statusEffects and jarray() or nil
  -- Disable effects.
  item.parameters.effectSources = root.itemConfig(item).effectSources and jarray() or nil
  -- Disable augments.
  if configParameter(item, "acceptsAugmentType") then
    item.parameters.acceptsAugmentType = ""
  end
  if configParameter(item, "tooltipKind") == "baseaugment" then
    item.parameters.tooltipKind = "back"
  end
  if starPounds.hasOption("disableRegurgitatedClothingTint") then return item end
  -- Give the armor some colour changes to make it look digested.
  item.parameters.colorOptions = configParameter(item, "colorOptions", {})
  item.parameters.colorIndex = configParameter(item, "colorIndex", 0) % (#item.parameters.colorOptions > 0 and #item.parameters.colorOptions or math.huge)
  -- Convert colorOptions and colorIndex to directives.
  if not configParameter(item, "directives") and item.parameters.colorOptions and #item.parameters.colorOptions > 0 then
    item.parameters.directives = "?replace;"
    for fromColour, toColour in pairs(item.parameters.colorOptions[item.parameters.colorIndex + 1]) do
      item.parameters.directives = string.format("%s%s=%s;", item.parameters.directives, fromColour, toColour)
    end
  end
  item.parameters.directives = configParameter(item, "directives", "")..string.rep("?brightness=-20?multiply=e9ffa6?saturation=-20", item.parameters.digestCount)
  item.parameters.colorIndex = nil
  item.parameters.colorOptions = jarray()
  return item
end

function pred:belchParticles(prey, essence)
  -- Fancy little particles similar to the normal death animation.
  local friction = world.breathable(starPounds.mcontroller.mouthPosition) or world.liquidAt(starPounds.mcontroller.mouthPosition)
  local particle = sb.jsonMerge(starPounds.settings.particleTemplates.vore, {})
  particle.color = {188, 235, 96}
  particle.initialVelocity = vec2.add({(friction and 2 or 3) * starPounds.mcontroller.facingDirection, 0}, vec2.add(starPounds.mcontroller.velocity, {0, world.gravity(starPounds.mcontroller.mouthPosition)/62.5})) -- Weird math but it works I guess.
  particle.finalVelocity = {starPounds.mcontroller.facingDirection, 10}
  particle.approach = friction and {5, 10} or {0, 0}
  particle.timeToLive = friction and 0.2 or 0.075
  local particles = {{
    action = "particle",
    specification = particle
  }}
  particles[#particles + 1] = sb.jsonMerge(particles[1], {specification = {color = {144, 217, 0}}})
  -- Humanoids get glowy death particles and doesn't have the soul absorb skill.
  if prey.type == "humanoid" and not starPounds.moduleFunc("skills", "has", "voreSouls") then
    particles[#particles + 1] = sb.jsonMerge(particles[1], {specification = {color = {96, 184, 235}, fullbright = true, collidesLiquid = false, timeToLive = 0.5}})
    particles[#particles + 1] = sb.jsonMerge(particles[1], {specification = {color = {0, 140, 217}, fullbright = true, collidesLiquid = false, timeToLive = 0.5}})
  end
  -- Add monster to collection if we have the skill.
  if starPounds.moduleFunc("skills", "has", "voreCollection") and (prey.type == "creature") and prey.typeName then
    local collectables = root.monsterParameters(prey.typeName).captureCollectables or {}
    for collection, collectable in pairs(collectables) do
      world.sendEntityMessage(entity.id(), "addCollectable", collection, collectable)
    end
  end
  -- Essence gets glowy purple particles.
  if essence then
    particles[#particles + 1] = sb.jsonMerge(particles[1], {specification = {color = {160, 70, 235}, fullbright = true, collidesLiquid = false, timeToLive = 0.5, light = {134, 71, 179, 255}}})
    particles[#particles + 1] = sb.jsonMerge(particles[1], {specification = {color = {102, 0, 216}, fullbright = true, collidesLiquid = false, timeToLive = 0.5, light = {134, 71, 179, 255}}})
  end

  starPounds.spawnMouthProjectile(particles, 5)
end

starPounds.modules.pred = pred
