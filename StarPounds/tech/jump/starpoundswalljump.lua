require "/scripts/util.lua"
require "/scripts/vec2.lua"
local init_old = init or function() end
local update_old = update or function() end
function init()
  init_old()
  -- Base size hitbox.
  self.baseBounds = poly.boundBox(mcontroller.baseParameters().standingPoly)

  function buildSensors()
    local bounds = poly.boundBox(mcontroller.collisionPoly())
    self.wallSensors = {
      right = {},
      left = {}
    }
    for _, offset in pairs(config.getParameter("wallSensors")) do
      table.insert(self.wallSensors.left, {bounds[1] - 0.1, bounds[2] + offset})
      table.insert(self.wallSensors.right, {bounds[3] + 0.1, bounds[2] + offset})
    end

    self.leftEmitters = {
      "wallJump.left",
      "wallSlide.left"
    }
    self.rightEmitters = {
      "wallJump.right",
      "wallSlide.right"
    }

    -- Offset the sliding particles by how much 'wider' we are.
    for _, emitterName in ipairs(self.leftEmitters) do
      animator.setParticleEmitterOffsetRegion(emitterName, {
        bounds[1] - self.baseBounds[1], 0,
        bounds[1] - self.baseBounds[1], 0
      })
    end

    for _, emitterName in ipairs(self.rightEmitters) do
      animator.setParticleEmitterOffsetRegion(emitterName, {
        bounds[3] - self.baseBounds[3], 0,
        bounds[3] - self.baseBounds[3], 0
      })
    end
  end

  -- Refresh the size hitbox when checking for walls.
  function checkWall(wall)
    local pos = mcontroller.position()
    local wallCheck = 0
    buildSensors()
    for _, offset in pairs(self.wallSensors[wall]) do
      -- world.debugPoint(vec2.add(pos, offset), world.pointCollision(vec2.add(pos, offset), self.wallCollisionSet) and "yellow" or "blue")
      if world.pointCollision(vec2.add(pos, offset), self.wallCollisionSet) then
        wallCheck = wallCheck + 1
      end
    end
    return wallCheck >= self.wallDetectThreshold
  end

  self.baseAirFriction = self.wallSlideParameters.airFriction
end

function update(args)
  starPounds = getmetatable ''.starPounds
  if starPounds and self.wall then
    self.wallSlideParameters.airFriction = nil
    local frictionFactor = util.clamp(self.baseAirFriction * (starPounds.weightMultiplier or 1) / mcontroller.mass() * args.dt, 0, 1)
    local newVelocity = vec2.lerp(frictionFactor, mcontroller.velocity(), {0, 0})
    mcontroller.setVelocity(newVelocity)
  else
    self.wallSlideParameters.airFriction = self.baseAirFriction
  end
  update_old(args)
end
