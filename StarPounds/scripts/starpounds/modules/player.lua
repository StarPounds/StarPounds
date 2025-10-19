-- Underscore here since the player table exists.
local _player = starPounds.module:new("player")

require "/scripts/status.lua"

function _player:init()
  self:setup()
  -- Footstep sound stuff. Initially offset so it lines up nice (hopefully).
  self.footstepTimer = 2 / 60
  self.footstepTiming = root.assetJson("/player.config:footstepTiming")
  self.footstepVolumeVariance = root.assetJson("/sfx.config:footstepVolumeVariance")
  -- Landing sound stuff.
  self.wasFalling = false
  -- Radio message if we have QuickbarMini instead (or with) StardustLite.
  local mmconfig = root.assetJson("/interface/scripted/mmupgrade/mmupgradegui.config")
  if mmconfig.replaced and not pcall(root.assetJson, "/metagui/registry.json") then
    player.radioMessage("starpounds_quickbar")
  elseif not mmconfig.replaced then
    player.radioMessage("starpounds_stardust")
  end
end

function _player:update(dt)
  -- Update fall damage listener.
  self.damageListener:update()
  -- Footsteps.
  self:footstep(dt)
  -- Landing.
  self:landing()

  starPounds.swapSlotItem = player.swapSlotItem()
  if starPounds.swapSlotItem and root.itemType(starPounds.swapSlotItem.name) == "consumable" then
    local replaceItem = starPounds.moduleFunc("food", "updateItem", starPounds.swapSlotItem)
    if replaceItem then
      player.setSwapSlotItem(replaceItem)
    end
  end
end

function _player:setup()
  -- Dummy empty function so we save memory.
  local function nullFunction() end
  local speciesData = starPounds.getSpeciesData(player.species())
  entity = {
    id = player.id,
    weight = speciesData.weight,
    foodType = speciesData.foodType
  }
  local mt = {__index = function () return nullFunction end}
  setmetatable(entity, mt)
end

-- Damage listener for fall/fire damage.
_player.damageListener = damageListener("damageTaken", function(notifications)
  local self = _player
  for _, notification in pairs(notifications) do
    if notification.sourceEntityId == entity.id() and notification.targetEntityId == entity.id() then
      if notification.damageSourceKind == "falling" and starPounds.currentSizeIndex > 1 then
        -- "explosive" damage (ignores tilemods) to blocks is reduced by 80%, for a total of 5% damage applied to blocks. (Isn't reduced by the fall damage skill)
        local baseDamage = (notification.damageDealt)/(starPounds.currentSize.healthMultiplier * (1 - starPounds.getStat("fallDamageResistance")))
        local tileDamage = baseDamage * starPounds.currentSize.healthMultiplier * 0.25
        self:damageHitboxTiles(tileDamage)
        break
      end
      if starPounds.currentSizeIndex > 1 and string.find(notification.damageSourceKind, "fire") and starPounds.getStat("firePenalty") > 0 then
        local percentLost = math.round(notification.healthLost/status.resourceMax("health"), 2)
        percentLost = 2 * percentLost * starPounds.getStat("firePenalty") * (starPounds.currentSizeIndex - 1)/(#starPounds.sizes - 1)

        if percentLost > 0.01 then
          status.overConsumeResource("energy", status.resourceMax("energy") * percentLost)
          status.addEphemeralEffect("sweat")
        end
      end
    end
  end
end)

function _player:damageHitboxTiles(tileDamage)
  if starPounds.hasOption("disableTileDamage") then return end
  local lowDamageTiles = {}
  local highDamageTiles = {}
  local groundLevel = 0
  local height = 0
  local width = {0, 0}
  local position = starPounds.mcontroller.position
  -- Calculate height, groundLevel, and width.
  for _, v in ipairs(mcontroller.collisionPoly()) do
    height = math.max(height, v[2])
    groundLevel = math.min(groundLevel, v[2])
    width[1] = math.min(width[1], v[1])
    width[2] = math.max(width[2], v[1])
  end
  -- Create tile damage polys.
  local lowPoly = {
    vec2.add({width[1] - 1, groundLevel - 0.5}, position),
    vec2.add({width[2] + 1, groundLevel - 0.5}, position),
    vec2.add({math.max(0, width[2] - 1.5), groundLevel - 2.5}, position),
    vec2.add({math.min(0, width[1] + 1.5), groundLevel - 2.5}, position)
  }
  local highPoly = {
    vec2.add({math.min(-0.5, width[1] + 0.5), groundLevel - 0.5}, position),
    vec2.add({math.max(0.5, width[2] - 0.5), groundLevel - 0.5}, position),
    vec2.add({math.max(0, width[2] - 1.5), groundLevel - 1.5}, position),
    vec2.add({math.min(0, width[1] + 1.5), groundLevel - 1.5}, position)
  }
  -- Check if nearby tiles fall in the damage poly.
  local tileQueryRadius = (0.5 * (math.abs(width[1]) + width[2])) - groundLevel + 1
  local foregroundTiles = world.radialTileQuery(position, tileQueryRadius, "foreground")
  for _, tile in pairs(foregroundTiles) do
    if world.polyContains(lowPoly, tile) then
      lowDamageTiles[#lowDamageTiles + 1] = tile
    end
    if world.polyContains(highPoly, tile) then
      highDamageTiles[#highDamageTiles + 1] = tile
    end
  end
  -- Damage valid tiles based on fall damage.
  world.damageTiles(lowDamageTiles, "foreground", position, "explosive", tileDamage * 0.25, 1, entity.id())
  world.damageTiles(highDamageTiles, "foreground", position, "explosive", tileDamage * 0.75, 1, entity.id())
end

-- Audio doesn't line up to the normal step sound (and can't),
-- but having the same cadence as it sounds decently good.
function _player:footstep(dt)
  if not starPounds.mcontroller.groundMovement then return end
  if not (starPounds.mcontroller.walking or starPounds.mcontroller.running) then return end
  if status.stat("activeMovementAbilities") > 1 then return end

  -- Not returning instantly with these so that we can keep the footstep timer somewhat synced.
  local doSound = true
  if starPounds.hasOption("disableMovementSounds") then doSound = false end
  if not storage.starPounds.enabled then doSound = false end

  self.footstepTimer = self.footstepTimer + dt
  if self.footstepTimer > self.footstepTiming then
    -- Skip this if we're not making steppy sounds due to settings/mod status.
    if not doSound then self.footstepTimer = 0 return end

    local volume = 1 - ((math.random() - 0.5) * self.footstepVolumeVariance)
    local stepVolume = self:soundMult()

    local weightMult = self.data.sloshWeightMult * stepVolume
    local stomachMult = self.data.sloshStomachMult * starPounds.stomach.contents / (entity.weight * starPounds.currentSize.thresholdMultiplier)
    local sloshVolume = math.round(math.min(weightMult + stomachMult, self.data.maximumSloshVolume), 2)

    -- No step sound if we can't move (i.e. Immobile without the skill), but boost the slosh volume.
    if starPounds.movementMultiplier == 0 then
      stepVolume = 0
      sloshVolume = sloshVolume ^ 0.8
    end

    if stepVolume > self.data.minimumStepVolume then
      starPounds.moduleFunc("sound", "play", "footstep", stepVolume * volume)
    end

    if sloshVolume > self.data.minimumSloshVolume then
      starPounds.moduleFunc("sound", "play", "slosh", sloshVolume * volume, 0.75)
    end

    self.footstepTimer = 0
  end
end

function _player:landing()
  if not storage.starPounds.enabled then return end

  if self.wasFalling and not starPounds.mcontroller.falling then
    if starPounds.mcontroller.groundMovement then
      local stomachMult = self.data.sloshStomachMult * starPounds.stomach.contents / (entity.weight * starPounds.currentSize.thresholdMultiplier)
      starPounds.events:fire("player:landing", math.min(stomachMult, 1))
      -- Sounds.
      if not starPounds.hasOption("disableMovementSounds") then
        local landVolume = self:soundMult()
        local weightMult = self.data.sloshWeightMult * landVolume
        local sloshVolume = math.round(math.min(weightMult + stomachMult, self.data.maximumSloshVolume), 2)
        starPounds.moduleFunc("sound", "play", "land", landVolume * self.data.landingSoundVolume, self.data.landingSoundPitch)
        if sloshVolume > self.data.minimumSloshVolume then
          starPounds.moduleFunc("sound", "play", "slosh", sloshVolume * self.data.landingSoundVolume, 0.75)
        end
      end
    end
  end
  self.wasFalling = starPounds.mcontroller.falling
end

function _player:soundMult()
  -- Just a cache for math so we only do it once.
  self.sizeMultipliers = self.sizeMultipliers or {}
  -- Dumb but the immobile skill edits the movement penalty.
  local size = starPounds.sizes[starPounds.currentSizeIndex]
  if not self.sizeMultipliers[size.size] then
    local mult = math.round(math.min((1 - size.movementMultiplier) ^ 0.4, self.data.maximumStepVolume), 2)
    self.sizeMultipliers[size.size] = mult
  end

  return self.sizeMultipliers[size.size]
end

starPounds.modules.player = _player
