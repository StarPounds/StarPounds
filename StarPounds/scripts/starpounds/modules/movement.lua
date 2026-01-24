local movement = starPounds.module:new("movement")

function movement:init()
  self.metatable = { __index = function(cache, key)
    -- Return the cache if it exists. ~= nil since values can be cached as false.
    local cached = rawget(cache, key)
    if cached ~= nil then
      return cached
    end
    -- Fetch the value if it's not cached.
    local func = mcontroller[key]
    if func then
      local value = func()
      cache[key] = value
      return value
    end
    -- Funni StarPounds function c:
    if key == "mouthPosition" then
      local value = movement:mouthPosition()
      cache[key] = value
      return value
    end

    return nil
  end }

  self.mcontroller = self:getController()
  self.effort = 0
  self.action = "none"
end

function movement:update(dt)
  self.mcontroller = self:getController()
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  self.effort = 0
  self.action = "none"
  -- Skip this if we're in a sphere.
  if status.stat("activeMovementAbilities") > 1 then return end
  -- Jumping > Running > Walking
  if self.mcontroller.groundMovement then
    -- Walking.
    if self.mcontroller.walking then
      self.effort = self.data.effort.walking
      self.action = "walking"
    end
    -- Running.
    if self.mcontroller.running then
      self.effort = self.data.effort.running
      self.action = "running"
    end
    -- Reset jump checker while on ground.
    self.didJump = false
    -- Moving through liquid takes up to 50% more effort.
    self.effort = self.effort * (1 + math.min(math.round(self.mcontroller.liquidPercentage, 1), 0.5))
    -- Jumping.
  elseif not self.mcontroller.liquidMovement and self.mcontroller.jumping and not self.didJump then
    self.effort = self.data.effort.jumping
    self.action = "jumping"
  else
    self.didJump = true
  end
end

function movement:getController()
  self.mcontroller = setmetatable({}, self.metatable)
  starPounds.mcontroller = self.mcontroller

  return self.mcontroller
end

function movement:mouthPosition()
  -- Player module will not have run the function fill for the entity table on the first tick.
  local id = (entity or player).id()
  -- Silly, but when the uninitialising this returns nil.
  if world.entityMouthPosition(id) == nil then return self.mcontroller.position end
  local mouthOffset = {0.375 * self.mcontroller.facingDirection * (self.mcontroller.crouching and 1.5 or 1), (self.mcontroller.crouching and -1 or 0)}
  return vec2.add(world.entityMouthPosition(id), mouthOffset)
end

function movement:getEffort()
  return self.effort, self.action
end

starPounds.modules.movement = movement
