require "/scripts/vec2.lua"
local startDash_old = (startDash_old or startDash) or function() end
function startDash(direction)
  starPounds = getmetatable ''.starPounds
  local movementModifier = math.max(starPounds.movementMultiplier or 1, 0.25)
  self.dashControlForce = self.baseDashControlForce * starPounds.weightMultiplier
  self.dashSpeed = self.baseDashSpeed * (movementModifier + (1 - movementModifier) * starPounds.getStat("stomachSmashRange"))
  startDash_old(direction)
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
