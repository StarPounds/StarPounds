require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

function init()
  self.weapon = Weapon:new()

  self.weapon:addTransformationGroup("weapon", {0,0}, util.toRadians(config.getParameter("baseWeaponRotation", 0)))

  local primaryAbility = NuruSpearAttack:new(config.getParameter("primaryAbility"), config.getParameter("stances"))
  self.weapon:addAbility(primaryAbility)

  self.weapon:init()
end

function update(dt, fireMode, shiftHeld)
  self.weapon:update(dt, fireMode, shiftHeld)
end

function uninit()
  self.weapon:uninit()
end

-----------------------------------------------

NuruSpearAttack = WeaponAbility:new()

function NuruSpearAttack:init()
  self:reset()
  self.cooldownTimer = self.fireTime

  self.weapon:setStance(self.stances.idle)

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

function NuruSpearAttack:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility and self.fireMode == "primary" and self.cooldownTimer == 0 then
    self:setState(self.windup)
  end
end

function NuruSpearAttack:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()

  animator.setParticleEmitterActive("charge", true)
  animator.playSound("charge")

  util.wait(self.stances.windup.duration)

  self:setState(self.fire)
end

function NuruSpearAttack:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  animator.setParticleEmitterActive("charge", false)
  animator.playSound("fire")

  local params = copy(self.projectileParameters)
  params.powerMultiplier = activeItem.ownerPowerMultiplier()

  local position = vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint("spear", "projectileSource")))
  world.spawnProjectile(self.projectileType, position, activeItem.ownerEntityId(), {mcontroller.facingDirection() * math.cos(self.weapon.aimAngle), math.sin(self.weapon.aimAngle)}, false, params)

  util.wait(self.stances.fire.duration)

  self.cooldownTimer = self.fireTime - self.stances.windup.duration - self.stances.fire.duration
end

function NuruSpearAttack:reset()
  animator.setParticleEmitterActive("charge", false)
end

function NuruSpearAttack:uninit()
  self:reset()
end
