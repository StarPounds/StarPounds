local init_old = init
function init()
  -- Default.
  self.sizes = root.assetJson("/scripts/starpounds/size/humanoid.config:sizes")
  self.maxWeight = root.assetJson("/scripts/starpounds/size/humanoid.config:maxWeight")

  starPounds = getmetatable ''.starPounds

  if starPounds and world.entityType(entity.id()) == "player" then
    self.sizes = starPounds.moduleFunc("size", "sizes")
    self.maxWeight = starPounds.moduleFunc("size", "maximumWeight")
  elseif world.entityType(entity.id()) == "npc" then
    self.sizes = world.callScriptedEntity(entity.id(), "starPounds.moduleFunc", "size", "sizes")
    self.maxWeight = world.callScriptedEntity(entity.id(), "starPounds.moduleFunc", "size", "maximumWeight")
  end

  init_old()
end

function increaseWeightProgress(weight, step)
  local step = math.max(0, math.min((step or 1), 1))
  local currentSize, currentSizeIndex = getSize(weight)
  local nextWeight = self.sizes[currentSizeIndex + 1] and self.sizes[currentSizeIndex + 1].weight or self.maxWeight
  local weightGain = math.floor(step * (nextWeight - self.sizes[currentSizeIndex].weight) + 0.5)
  world.sendEntityMessage(entity.id(), "starPounds.gainWeight", weightGain, true)
end

function decreaseWeightProgress(weight, step)
  local step = math.max(0, math.min((step or 1), 1))
  local currentSize, currentSizeIndex = getSize(weight)
  local nextWeight = self.sizes[currentSizeIndex + 1] and self.sizes[currentSizeIndex + 1].weight or self.maxWeight
  local weightLoss = math.floor(step * (nextWeight - self.sizes[currentSizeIndex].weight) + 0.5)
  world.sendEntityMessage(entity.id(), "starPounds.loseWeight", weightLoss, true)
end

function getSize(weight)
  local sizeIndex = 0
  -- Go through all sizes (smallest to largest) to find which size.
  for i in ipairs(self.sizes) do
    if weight >= self.sizes[i].weight then
      sizeIndex = i
    end
  end

  return self.sizes[sizeIndex], sizeIndex
end
