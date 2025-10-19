local supersize = starPounds.module:new("supersize")

function supersize:init()
  self.didUpdate = false
  self.isSupersize = false
  self.projectileActive = false
  self.size = ""
  self.bounds = rect.pad(mcontroller.boundBox(), {0, -1})
  self.boundsCache = {}
  self.playerWidth = math.abs(self.bounds[3] - self.bounds[1]) * 0.5
  self.doorDeltaTime = self.data.doorDelta * self.data.scriptDelta
  self.doorTimer = 0

  self.triggerSizeUpdate = function()
    self.didUpdate = false
  end

  starPounds.events:on("sizes:changed", self.triggerSizeUpdate)
end

function supersize:update(dt)
  -- Projectile spawner for the hitbox/magnet.
  self.projectileActive = self.projectile and world.entityExists(self.projectile)
  if not self.projectileActive and self:doProjectile() then
    self.projectile = world.spawnProjectile(self.projectileType, starPounds.mcontroller.position, entity.id(), {0, 0}, true)
  elseif self.projectileActive and not self:doProjectile() then
    self:killProjectile()
  end
  -- Delay door update loop by 1 tick, and setup size data.
  if not self.didUpdate then
    self:sizeUpdate()
    self.didUpdate = true
    return
  end
  -- Don't run anything after this if we're not a large size.
  if not self.isSupersize then return end
  -- Automatically open doors in front/close doors behind since large sizes cant reach to interact.
  if not starPounds.hasOption("disableAutomaticDoors") then
    self:automaticDoors(dt)
  end
end

function supersize:uninit()
  self:killProjectile()
  starPounds.events:off("sizes:changed", self.triggerSizeUpdate)
end

function supersize:sizeUpdate()
  self:killProjectile()
  self.size = starPounds.currentSize.size
  self.isSupersize = starPounds.currentSize.yOffset
  self.projectileType = starPounds.currentSize.projectile
  if self.isSupersize then
    local poly = (starPounds.currentSize.controlParameters[starPounds.getVisualSpecies()] or starPounds.currentSize.controlParameters.default).standingPoly
    self.bounds = self.boundsCache[self.size] or rect.translate(rect.pad(util.boundBox(poly), {0, self.data.boundsPadding}), self.data.boundsOffset)
    self.boundsCache[self.size] = self.bounds
    self.width = math.abs(self.bounds[3] - self.bounds[1]) * 0.5
  end
end

function supersize:killProjectile()
  self.projectileActive = self.projectile and world.entityExists(self.projectile)
  if self.projectileActive then
    world.callScriptedEntity(self.projectile, "projectile.die")
    self.projectile = nil
    self.projectileActive = false
  end
end

function supersize:doProjectile()
  if not storage.starPounds.enabled then return false end
  if not self.isSupersize then return false end
  if not self.projectileType then return false end
  if starPounds.hasOption("disableCollision") then return false end
  if status.stat("activeMovementAbilities") >= 1 then return false end
  return true
end

function supersize:automaticDoors(dt)
  -- Run this less often.
  self.doorTimer = math.max(self.doorTimer - dt, 0)
  if self.doorTimer > 0 then return end
  self.doorTimer = self.doorDeltaTime * dt

  local walking = starPounds.mcontroller.walking
  local running = starPounds.mcontroller.running
  if not (running or walking) then
    return
  end

  local openBounds = rect.translate(self.bounds, starPounds.mcontroller.position)
  local closeBounds = {table.unpack(openBounds)}

  if starPounds.mcontroller.movingDirection > 0 then
    openBounds[1], openBounds[3] = openBounds[3] + self.data.openRange[1], openBounds[3] + self.data.openRange[2]
    closeBounds[3], closeBounds[1] = closeBounds[1] - self.data.closeRange[1], closeBounds[1] - self.data.closeRange[2]
  else
    openBounds[3], openBounds[1] = openBounds[1] + self.data.openRange[1], openBounds[1] - self.data.openRange[2]
    closeBounds[1], closeBounds[3] = closeBounds[3] + self.data.closeRange[1], closeBounds[3] + self.data.closeRange[2]
  end

  if world.rectTileCollision(openBounds, {"dynamic"}) then
    self:queryDoors(openBounds, nil, "openDoor")
  end
  self:queryDoors(closeBounds, 1, "closeDoor")
end

function supersize:queryDoors(bounds, minimumDistance, message)
  local doorIds = world.objectQuery(rect.ll(bounds), rect.ur(bounds))
  for _, doorId in ipairs(doorIds) do
    local valid = false
    if world.isEntityInteractive(doorId) and contains(world.getObjectParameter(doorId, "scripts", jarray()), "/objects/wired/door/door.lua") then
      local position = world.entityPosition(doorId)
      local spaces = world.getObjectParameter(doorId, "closedMaterialSpaces", world.objectSpaces(doorId))
      -- Check if the object is actually in the rect because queries suck.
      for i = 1, #spaces do
        -- The space can also be {{x, y}, "material"} instead of {x, y}
        local pos = spaces[i]
        if type(pos[1]) == "table" then
          pos = pos[1]
        end

        local space = vec2.add(pos, world.entityPosition(doorId))
        if rect.contains(bounds, space) then
          valid = true
          break
        end
      end
    end
    -- Message valid doors.
    if valid then
      world.sendEntityMessage(doorId, message)
    end
  end
end

starPounds.modules.supersize = supersize
