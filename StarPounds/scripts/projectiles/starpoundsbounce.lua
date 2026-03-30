require "/scripts/vec2.lua"

function init()
  self.bounceFactor = config.getParameter("bounceFactor", 1) * -1
  self.bounces = config.getParameter("bounces", -1)
  self.collideActions = config.getParameter("actionOnCollide", jarray())
end

function hit(entityId)
  if self.bounces == 0 then
    return
  end

  local velocity = mcontroller.velocity()
  -- Calculate the vector from the entity to the object and normalize it
  local normal = {0, 1}
  local reflectedVelocity = vec2.sub(velocity, vec2.mul(normal, 2 * vec2.dot(velocity, normal)))

  -- Update the velocity
  mcontroller.setVelocity(vec2.mul(reflectedVelocity, self.bounceFactor))

  if self.bounces ~= 0 then
    for _, collideAction in ipairs(self.collideActions) do
      projectile.processAction(collideAction)
    end
  end

  bounce()
end

function bounce()
  if self.bounces == 0 then
    projectile.setTimeToLive(0)
  end

  self.bounces = self.bounces - 1
end
