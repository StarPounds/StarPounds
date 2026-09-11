local material = starPounds.module:new("material")

function material:get(mat)
  return self.data.materials[mat] or (self:isPlatform(mat) and self.data.materials.default_platform or self.data.materials.default)
end

function material:edible(mat)
  return self:get(mat).edible or false
end

function material:consumable(mat)
  return self:edible(mat) or self:get(mat).consumable or false
end

function material:inedible(mat)
  return self:get(mat).inedible or false
end

function material:mod(mod)
  return self.data.mods[mod] or self.data.mods.default
end

function material:getFood(mat)
  local food = 0
  local mat = self:get(mat)
  -- Iterate to get total food value.
  for foodType, foodAmount in pairs(mat.food) do
    local foodType = starPounds.moduleFunc("food", "foodType", foodType)
    if foodType then
      food = food + (foodAmount * foodType.multipliers.food)
    end
  end

  return food
end

function material:getModFood(mat)
  local food = 0
  local mod = self:getMod(mod)
  -- Iterate to get total food value.
  for foodType, foodAmount in pairs(mod.food) do
    local foodType = starPounds.moduleFunc("food", "foodType", foodType)
    if foodType then
      food = food + (foodAmount * foodType.multipliers.food)
    end
  end

  return food
end

function material:isPlatform(mat)
  local isPlatform = false
  local materialConfig = root.materialConfig(mat)
  if materialConfig and materialConfig.config then
    isPlatform = materialConfig.config.collisionKind == "platform"
  end

  return isPlatform
end

starPounds.modules.material = material
