local init_old = init
function init()
  -- Default.
  self.sizes = root.assetJson("/scripts/starpounds/size/humanoid.config:sizes")
  self.maxWeight = root.assetJson("/scripts/starpounds/size/humanoid.config:maxWeight")
  self.entityType = world.entityType(entity.id())

  starPounds = getmetatable ''.starPounds
  if starPounds and entityType == "player" then
    self.sizes = starPounds.moduleFunc("size", "sizes")
    self.maxWeight = starPounds.moduleFunc("size", "maximumWeight")
  elseif entityType == "npc" then
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
  if starPounds and starPounds.isEnabled() and entityType == "player"  then
    starPounds.moduleFunc("size", "gainWeight", weightGain, true)
  elseif entityType == "npc" then
    gained = world.callScriptedEntity(entity.id(), "starPounds.moduleFunc", "size", "gainWeight", weightGain, true)
  end
end

function decreaseWeightProgress(weight, step)
  local step = math.max(0, math.min((step or 1), 1))
  local currentSize, currentSizeIndex = getSize(weight)
  local nextWeight = self.sizes[currentSizeIndex + 1] and self.sizes[currentSizeIndex + 1].weight or self.maxWeight
  local weightLoss = math.floor(step * (nextWeight - self.sizes[currentSizeIndex].weight) + 0.5)
  if starPounds and starPounds.isEnabled() and entityType == "player"  then
    starPounds.moduleFunc("size", "loseWeight", weightLoss, true)
  elseif entityType == "npc" then
    gained = world.callScriptedEntity(entity.id(), "starPounds.moduleFunc", "size", "loseWeight", weightLoss, true)
  end
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
