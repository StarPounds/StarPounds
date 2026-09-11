require "/scripts/vec2.lua"
local hue
local timer = 0
local defaultColour = {159, 128, 255}
local colour = {255, 96, 96}
local highlightColour = defaultColour

function update(dt)
  timer = timer + dt
  -- Brightness is 100% when timer is 0.
  local highlightBonus = animationConfig.animationParameter("voreTileHighlight")
  if highlightBonus then
    timer = 0
  end

  local newHue = animationConfig.animationParameter("hue")
  if hue ~= newHue then
    hue = newHue
    if newHue then
      highlightColour = hueshift(colour, newHue)
    else
      highlightColour = defaultColour
    end
  end

  local ratio = (math.sin(timer * 4 + math.pi * 0.5) + 1) * 0.5
  local outlineAlpha = math.floor(64 + (255 - 64) * ratio)
  local highlightAlpha = math.floor(16 + (64 - 16) * ratio)

  localAnimator.clearDrawables()
  outlineTiles(animationConfig.animationParameter("voreTiles"), {highlightColour[1], highlightColour[2], highlightColour[3], outlineAlpha})
  highlightTiles(animationConfig.animationParameter("voreTiles"), {highlightColour[1], highlightColour[2], highlightColour[3], highlightAlpha})
end

function outlineTiles(tiles, colour)
  if not tiles then return end
  -- Lookup table.
  local tileList = {}
  for _, position in ipairs(tiles) do
    local key = math.floor(position[1])..","..math.floor(position[2])
    tileList[key] = true
  end
  -- Draw lines.
  local shadowColour = {colour[1] * 0.25, colour[2] * 0.25, colour[3] * 0.25, colour[4] * 0.5}
  local highlightColour = {
    math.max(math.min(colour[1] * 1.5, 255), 128),
    math.max(math.min(colour[2] * 1.5, 255), 128),
    math.max(math.min(colour[3] * 1.5, 255), 128),
    colour[4] * 0.5
  }
  for _, position in ipairs(tiles) do
    local function drawLine(p1, p2)
      -- Shadow.
      localAnimator.addDrawable({
        line = {p1, p2},
        width = 1,
        color = shadowColour,
        fullbright = true,
        position = vec2.add(position, {0, -0.125}),
      }, "Overlay-1")
      -- Colour.
      localAnimator.addDrawable({
        line = {p1, p2},
        width = 1,
        color = colour,
        fullbright = true,
        position = position
      }, "Overlay")
      -- Highlight horizontal lines.
      if (p1[2] - p2[2]) == 0 then
        localAnimator.addDrawable({
          line = {p1, p2},
          width = 0.5,
          color = highlightColour,
          fullbright = true,
          position = vec2.add(position, {0, 0.03125}),
        }, "Overlay+1")
      end
    end
    -- Draw outlines if they have no neighbour on that side.
    if not tileList[position[1]..","..(position[2] + 1)] then drawLine({1, 1}, {0, 1}) end -- Top
    if not tileList[position[1]..","..(position[2] - 1)] then drawLine({0, 0}, {1, 0}) end -- Bottom
    if not tileList[(position[1] - 1)..","..position[2]] then drawLine({0, 1}, {0, 0}) end -- Left
    if not tileList[(position[1] + 1)..","..position[2]] then drawLine({1, 0}, {1, 1}) end -- Right
  end
end

function highlightTiles(tiles, colour)
  if not tiles then return end
  local minY = math.huge
  for _, position in ipairs(tiles) do
    if position[2] < minY then minY = position[2] end
  end

  local layers = {}
  local pixel = 0.125
  for i = 0, 7 do
    local yOffset = i * pixel
    layers[i] = {
      poly = {{0, yOffset}, {0, yOffset + pixel}, {1, yOffset + pixel}, {1, yOffset}},
      centerOffset = yOffset + (pixel * 0.5)
    }
  end

  for _, position in ipairs(tiles) do
    for i = 0, 7 do
      local fraction = math.min((position[2] + layers[i].centerOffset - minY) / 10, 1)
      local alpha = math.floor(colour[4] * (1 - fraction))
      if alpha > 0 then
        localAnimator.addDrawable({
          poly = layers[i].poly,
          color = {colour[1], colour[2], colour[3], alpha},
          fullbright = true,
          position = position
        }, "Overlay")
      end
    end
  end
end

function hueshift(rgba, degrees)
  local r, g, b, a = rgba[1] / 255, rgba[2] / 255, rgba[3] / 255, rgba[4]
  local max, min = math.max(r, g, b), math.min(r, g, b)
  local delta = max - min
  if delta == 0 then return {rgba[1], rgba[2], rgba[3], a} end
  local h = (max == r and (g - b) / delta or max == g and 2 + (b - r) / delta or 4 + (r - g) / delta) * 60
  h = (h + degrees) % 360
  local function f(n)
    local k = (n + h / 60) % 6
    return math.floor((max - delta * math.max(0, math.min(k, 4 - k, 1))) * 255 + 0.5)
  end

  return {f(5), f(3), f(1), a}
end
