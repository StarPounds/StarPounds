require "/scripts/vec2.lua"
local startDash_old = startDash or function() end
function startDash(...)
  -- Save this so we can revert to it
  self.baseDashControlForce = self.dashControlForce
  self.baseDashSpeed = self.dashSpeed
  starPounds = getmetatable ''.starPounds or {}
  self.dashControlForce = self.baseDashControlForce * (starPounds.weightMultiplier or 1)
  local movementModifier = (starPounds.movementMultiplier or 1) * 0.9 + 0.1
  self.dashSpeed = self.baseDashSpeed * (movementModifier + (1 - movementModifier) * starPounds.getStat("stomachSmashRange"))
  -- controlApproachVelocity takes into account the speedModifier for whatever reason, so divide by it after the reduction.
  self.dashSpeed = self.dashSpeed / starPounds.movementMultiplier

  startDash_old(...)

  local multiplier = starPounds.weightMultiplier ^ (1/3)
  local width = 0
  for _,v in ipairs(mcontroller.collisionPoly()) do
    width = (v[1] > width) and v[1] or width
  end
  local params = {
    knockback = 20 + 5 * multiplier * (0.5 + starPounds.getStat("stomachSmashForce")),
    statusEffects = {{effect = "ragdoll", duration = 0.25 * multiplier}}
  }
  for offset = width, -1, -2 do
    spawnKnockbackProjectile(vec2.add(mcontroller.position(), vec2.add({(offset) * self.dashDirection, -3}, {0, starPounds.currentSize.yOffset or 0})), params)
  end

  animator.setSoundVolume("weightDash", starPounds.moduleFunc("size", "effectScaling") * 0.5 + 0.5)
  animator.playSound("weightDash")
end

local endDash_old = endDash or function() end
function endDash(...)
  -- Stop harder for weight.
  if self.stopAfterDash then
    self.stopAfterDash = false

    starPounds = getmetatable ''.starPounds or {}
    local movementParams = mcontroller.baseParameters()
    local runSpeed = movementParams.runSpeed * (starPounds.movementMultiplier or 1)
    local currentVelocity = mcontroller.velocity()
    if math.abs(currentVelocity[1]) > runSpeed then
      mcontroller.setVelocity({runSpeed * self.dashDirection, 0})
    end
    mcontroller.controlApproachXVelocity(self.dashDirection * runSpeed, self.dashControlForce)
  end

  self.dashControlForce = self.baseDashControlForce
  self.dashSpeed = self.baseDashSpeed

  endDash_old(...)

  self.stopAfterDash = true
end


function spawnKnockbackProjectile(position, params)
  world.spawnProjectile("starpoundsstomachsmash", position, entity.id(), {self.dashDirection * 5, 0}, true, sb.jsonMerge(params, {
    damageRepeatGroup = "starpoundsstomachsmash_"..entity.id(),
    damageRepeatTimeout = 0.15
  }))
  -- For some reason knocback doesn't apply properly on the first instance for NPCs sometimes, so there's a bunch of stacking no-damage knockback projectiles here.
  world.spawnProjectile("starpoundsstomachsmash", position, entity.id(), {self.dashDirection * 5, 0}, true, sb.jsonMerge(params, {
    damageKind = "nodamage",
    damageRepeatTimeout = 0
  }))
end
