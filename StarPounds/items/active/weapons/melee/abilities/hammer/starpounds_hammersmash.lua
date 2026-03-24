local HammerSmashFire_old = HammerSmash.fire
function HammerSmash:fire(...)
  local defaultDamage = self.damageConfig.baseDamage
  local defaultMomentum = self.smashMomentum

  local starPounds = getmetatable ''.starPounds
  if starPounds then
    self.damageConfig.baseDamage = defaultDamage * (1 + starPounds.getStat("smashDamage") * starPounds.moduleFunc("size", "effectScaling"))
    self.smashMomentum = vec2.mul(defaultMomentum, starPounds.weightMultiplier)
  end

  HammerSmashFire_old(self, ...)
  self.damageConfig.baseDamage = defaultDamage
  self.smashMomentum = defaultMomentum
end
