local hunger = starPounds.module:new("hunger")

function hunger:init()
  self.isStarving = false
  self.baseThreshold = starPounds.settings.thresholds.strain.starpoundsstomach
  self.skillThreshold = starPounds.settings.thresholds.strain.starpoundsstomach3
end

function hunger:update(dt)
  -- Holy shit why can we not detect what gamemode the player is using.
  if starPounds.hasOption("disableHunger") then
    status.setResource("food", status.resourceMax("food") - 0.01)
  end
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Check if the player is starving.
  self.isStarving = status.uniqueStatusEffectActive("starving")
  -- Check upgrade for preventing starving and they have weight loss enabled.
  if starPounds.moduleFunc("skills", "has", "preventStarving") and not starPounds.hasOption("disableLoss") then
    -- 1% more than the food delta.
    if self.isStarving then
      local foodDelta = math.max(status.stat("foodDelta") * -1, 0) * dt
      local minimumSize = math.max(starPounds.moduleFunc("skills", "level", "minimumSize"), starPounds.moduleFunc("skills", "level", "softMinimumSize"), 0)
      local availableWeight = storage.starPounds.weight - starPounds.sizes[minimumSize + 1].weight
      if availableWeight > 0 then
        self.isStarving = false
        local lossMultiplier = math.max(1, 1/math.max(0.01, (starPounds.getStat("foodValue") * starPounds.getStat("absorption"))))
        -- Converting fat, so ignore weight loss modifiers.
        starPounds.moduleFunc("size", "loseWeight", foodDelta * lossMultiplier, true)
      end
    end
  end
  -- Apply wellfed if over capacity.
  if starPounds.stomach.interpolatedFullness >= self.baseThreshold and not starPounds.moduleFunc("skills", "has", "wellfedProtection") then
    self:applyStatus()
  elseif starPounds.stomach.fullness >= self.skillThreshold then
    self:applyStatus()
  end
end

function hunger:applyStatus()
  local effectActive = status.uniqueStatusEffectActive("wellfed")
  -- Refresh the tracker statuses so wellfed appears after.
  if not effectActive then
    starPounds.moduleFunc("trackers", "createStatuses")
  end
  -- Apply the status.
  status.addEphemeralEffect("wellfed")
end

starPounds.modules.hunger = hunger
