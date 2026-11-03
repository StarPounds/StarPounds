local liquid = starPounds.module:new("liquid")
function liquid:init()
  self.particleCache = {}
  self.splashConfig = root.assetJson("/player.config:splashConfig")
end

function liquid:get(liq)
  return self.data.liquids[liq] or self.data.liquids.default
end

function liquid:edible(liq)
  return self:get(liq).edible or false
end

function liquid:inedible(liq)
  return self:get(liq).inedible or false
end

function liquid:getFood(liq)
  local food = 0
  local liq = self:get(liq)
  -- Iterate to get total food value.
  for foodType, foodAmount in pairs(liq.food) do
    local foodType = starPounds.moduleFunc("food", "foodType", foodType)
    if foodType then
      food = food + (foodAmount * foodType.multipliers.food)
    end
  end

  return food
end

function liquid:getParticles(liq)
  if self.particleCache[liq] == nil then
    local liquidConfig = root.liquidConfig(liq)
    if liquidConfig and liquidConfig.config.color then
      self.particleCache[liq] = sb.jsonMerge(self.splashConfig.splashParticle, {
        color = liquidConfig.config.color,
        variance = self.splashConfig.splashParticleVariance
      })
    else
      self.particleCache[liq] = false
    end
  end

  return copy(self.particleCache[liq])
end
-- Add the module.
starPounds.modules.liquid = liquid
