require"/scripts/messageutil.lua"

function init()
  message.setHandler("starPounds.expire", localHandler(effect.expire))
  self.mainStatGroup = effect.addStatModifierGroup({
    {stat = "invisible", amount = 1},
    {stat = "invulnerable", amount = 1},
    {stat = "healingStatusImmunity", amount = 1},
    {stat = "fireStatusImmunity", amount = 1},
    {stat = "iceStatusImmunity", amount = 1},
    {stat = "electricStatusImmunity", amount = 1},
    {stat = "poisonStatusImmunity", amount = 1},
    {stat = "specialStatusImmunity", amount = 1},
    {stat = "waterImmunity", amount = 1},
    {stat = "lavaImmunity", amount = 1},
    {stat = "tarStatusImmunity", amount = 1},
    {stat = "wetImmunity", amount = 1},
    {stat = "slimeImmunity", amount = 1},
    {stat = "healthRegen", effectiveMultiplier = 0}
  })
  -- Energy regen reduction based on missing health.
  self.energyRateMult = 1
  if world.entityType(entity.id()) == "npc" then
    -- NPCs have ridiculous energy regen percents.
    local playerRegenRate = root.assetJson("/player.config:statusControllerSettings.stats.energyRegenPercentageRate.baseValue")
    self.energyRateMult = playerRegenRate / status.stat("energyRegenPercentageRate")
  end

  self.energyStatGroup = effect.addStatModifierGroup({
    {stat = "energyRegenPercentageRate", effectiveMultiplier = 1}
  })

  effect.setParentDirectives("?multiply=00000000;")
end

function update(dt)
  effect.modifyDuration(dt)
  effect.setStatModifierGroup(self.energyStatGroup, {
    {stat = "energyRegenPercentageRate", effectiveMultiplier = self.energyRateMult * status.resourcePercentage("health")}
  })
end

function uninit()
  effect.removeStatModifierGroup(self.statGroup)
  effect.removeStatModifierGroup(self.energyStatGroup)
end
