local exercise = starPounds.module:new("exercise")

function exercise:init()
  self.hasFood = status.isResource("food")
end

function exercise:update(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Skip this if we're in a sphere.
  if status.stat("activeMovementAbilities") > 1 then return end
  local effort = starPounds.moduleFunc("movement", "getEffort")
  -- Skip the rest if we're not moving.
  if effort == 0 then return end
  -- Lose weight based on weight, effort, and the multiplier.
  local amount = effort * (starPounds.weightMultiplier ^ self.data.weightExponent) * self.data.multiplier * starPounds.getStat("metabolism") * dt
  -- Weight loss reduced if you're full, and have food in your stomach.
  if self.hasFood and status.resource("food") >= (status.resourceMax("food") + status.stat("foodDelta")) and starPounds.stomach.food > 0 then
    amount = amount * self.data.foodMultiplier
  end
  local availableWeight = storage.starPounds.weight - starPounds.sizes[starPounds.moduleFunc("skills", "level", "softMinimumSize") + 1].weight
  starPounds.moduleFunc("size", "loseWeight", math.min(amount, availableWeight))
end

starPounds.modules.exercise = exercise
