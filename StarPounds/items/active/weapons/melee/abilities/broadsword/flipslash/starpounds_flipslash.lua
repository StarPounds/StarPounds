local FlipSlashFlip_old = FlipSlash.flip
function FlipSlash:flip(...)
  local starPounds = getmetatable ''.starPounds
  if starPounds and starPounds.currentSize.yOffset then
    self:starPounds_superSizeflip(...)
  else
    FlipSlashFlip_old(self, ...)
  end
end

function FlipSlash:starPounds_superSizeflip()
  self.weapon:setStance(self.stances.flip)
  self.weapon:updateAim()

  animator.setAnimationState("swoosh", "flip")
  animator.playSound(self.fireSound or "flipSlash")
  animator.setParticleEmitterActive("flip", true)

  local rotations = math.floor(self.rotations * 1.5) -- 50% more rotations if it's just the sword. (Lines up with the sound better)
  local rotationTime = self.rotationTime / (rotations / self.rotations)

  self.flipTime = rotations * rotationTime
  self.flipTimer = 0

  self.jumpTimer = self.jumpDuration

  while self.flipTimer < self.flipTime do
    self.flipTimer = self.flipTimer + self.dt

    mcontroller.controlParameters(self.flipMovementParameters)

    if self.jumpTimer > 0 then
      self.jumpTimer = self.jumpTimer - self.dt
      mcontroller.setVelocity({self.jumpVelocity[1] * self.weapon.aimDirection, self.jumpVelocity[2]})
    end

    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)
    self.weapon.relativeArmRotation = mcontroller.facingDirection() * -math.pi * 2 * self.weapon.aimDirection * (self.flipTimer / rotationTime)

    coroutine.yield()
  end

  status.clearPersistentEffects("weaponMovementAbility")

  animator.setAnimationState("swoosh", "idle")
  self.weapon.relativeArmRotation = 0
  animator.setParticleEmitterActive("flip", false)
  self.cooldownTimer = self.cooldownTime
end
