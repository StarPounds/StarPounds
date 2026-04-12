function init()
  script.setUpdateDelta(5)
  self.progressStep = effect.getParameter("progressStep", 0.02)
  self.tickTime = effect.getParameter("tickTime", 1)
  self.tickTimeStep = effect.getParameter("tickTimeStep", 0)
  self.tickTimeMinimum = effect.getParameter("tickTimeMinimum", self.tickTime)
  self.tickTimer = self.tickTime
  self.minimumLiquid = root.assetJson("/player.config:statusControllerSettings.minimumLiquidStatusEffectPercentage")

  animator.setSoundVolume("digest", 0.75)
  animator.setSoundPitch("digest", 2/(1 + self.tickTime))
end

function update(dt)
  if status.uniqueStatusEffectActive("caloriumliquid") then return end
  if world.entityType(entity.id()) == "npc" or (starPounds and starPounds.isEnabled()) then

    self.tickTimer = self.tickTimer - dt
    if self.tickTimer <= 0 then
      self.tickTime = math.max(self.tickTime - self.tickTimeStep, self.tickTimeMinimum)
      self.tickTimer = self.tickTime

      if starPounds and starPounds.isEnabled() then
        increaseWeightProgress(starPounds.moduleFunc("data", "get", "weight"), self.progressStep)
      else
        increaseWeightProgress(world.callScriptedEntity(entity.id(), "starPounds.moduleFunc", "data", "get", "weight"), self.progressStep)
      end

      animator.setSoundPitch("digest", 2/(1 + self.tickTime))
      animator.playSound("digest")
    end
  else
    effect.expire()
  end
end
