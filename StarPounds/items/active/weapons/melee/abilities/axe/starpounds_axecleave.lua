local AxeCleaveFire_old = AxeCleave.fire
function AxeCleave:fire(...)
  local defaultDamage = self.damageConfig.baseDamage

  local entityType = world.entityType(activeItem.ownerEntityId())

  local starPounds = getmetatable ''.starPounds
  if entityType == "player" and starPounds then
    self.damageConfig.baseDamage = defaultDamage * (1 + starPounds.getStat("smashDamage") * starPounds.moduleFunc("size", "effectScaling"))
  elseif entityType == "npc" then
    local smashDamage = world.callScriptedEntity(activeItem.ownerEntityId(), "starPounds.getStat", "smashDamage") or 0
    local effectScaling = world.callScriptedEntity(activeItem.ownerEntityId(), "starPounds.moduleFunc", "size", "effectScaling") or 0
    self.damageConfig.baseDamage = defaultDamage * (1 + smashDamage * effectScaling)
  end

  AxeCleaveFire_old(self, ...)
  self.damageConfig.baseDamage = defaultDamage
end
