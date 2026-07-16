local canvasWidget, centerCoordinates, menuOptions, optionCount, sliceAngle, lastHoveredTarget
local radiusInner, radiusOuter, hoveredOptionIndex, hasSelectedOption = 25, 75, nil, false
local isMouseDown = false
local isMouseReleased = false
local menuStack = {}

local animationTimer = 0
local animationDuration = 0.2 -- Initial grow animation time.

local needsRedraw = true
local prevMouseDown = false

-- Colours.
local colours = {
  center = {60, 50, 80, 180},
  base = {190, 180, 200, 160},
  hover = {157, 114, 237, 180},
  press = {180, 140, 255, 200},
  hidden = {0, 0, 0, 0},
  -- Text.
  text = {190, 180, 200},
  textHover = {255, 255, 255},
  textGrey = {170, 170, 170},
  textDark = {40, 50, 60}
}
local shared = getmetatable ""

local function loadMenu(newOptionsList)
  menuOptions = newOptionsList
  optionCount = #menuOptions
  if optionCount == 0 then return pane.dismiss() end

  radiusInner = optionCount <= 6 and 36 or math.max(22, 50 - optionCount * 2)
  radiusOuter = radiusInner + 22
  hoveredOptionIndex = nil
  isMouseDown = false
  isMouseReleased = false
  lastHoveredTarget = nil

  animationTimer = 0
  -- Force redraw on load.
  needsRedraw = true
  -- Calculate total weight.
  local totalWeight = 0
  for _, option in ipairs(menuOptions) do
    option.weight = tonumber(option.weight) or 1
    totalWeight = totalWeight + option.weight
  end
  -- Start at counterclockwise edge of option 1 so it's centered. (math.pi * 0.5)
  local firstSweep = (menuOptions[1].weight / totalWeight) * (math.pi * 2)
  local currentEndAngle = (math.pi * 0.5) + (firstSweep * 0.5)

  for optionIndex, option in ipairs(menuOptions) do
    local sweepAngle = (option.weight / totalWeight) * (math.pi * 2)
    option.endAngle = currentEndAngle
    option.startAngle = currentEndAngle - sweepAngle
    option.midpointAngle = currentEndAngle - (sweepAngle * 0.5)

    currentEndAngle = option.startAngle

    if option.init and type(option.init) == "function" then
      option:init(optionIndex)
    end
  end
end

function init()
  shared.starPoundsRadialMenuOpen = true
  shared.starPoundsRadialMenu = nil

  canvasWidget = widget.bindCanvas("canvas")
  widget.focus("canvas")

  local canvasSize = canvasWidget:size()
  local canvasWidth = (canvasSize[1] > 0) and canvasSize[1] or 200
  local canvasHeight = (canvasSize[2] > 0) and canvasSize[2] or 200
  centerCoordinates = {canvasWidth * 0.5, canvasHeight * 0.5}

  local options = shared.starPoundsRadialOptions or config.getParameter("options", {})
  loadMenu(options)
end
-- HELL. HELL. HATE. HELL.
local function drawArcSegment(startAngle, endAngle, innerArcRadius, outerArcRadius, fillColour, linearGapInPixels)
  local halfGap = (linearGapInPixels or 0) * 0.5
  local deltaAngleInner = (innerArcRadius > 0) and (halfGap / innerArcRadius) or 0
  local deltaAngleOuter = (outerArcRadius > 0) and (halfGap / outerArcRadius) or 0

  local startAngleInner = startAngle + deltaAngleInner
  local endAngleInner =   endAngle - deltaAngleInner
  local startAngleOuter = startAngle + deltaAngleOuter
  local endAngleOuter =   endAngle - deltaAngleOuter

  local arcSteps = math.max(2, math.ceil((endAngle - startAngle) * 6))
  local angleStepInner = (endAngleInner - startAngleInner) / arcSteps
  local angleStepOuter = (endAngleOuter - startAngleOuter) / arcSteps

  for stepIndex = 0, arcSteps - 1 do
    local currentAngleInner = startAngleInner + stepIndex * angleStepInner
    local nextAngleInner    = startAngleInner + (stepIndex + 1) * angleStepInner
    local currentAngleOuter = startAngleOuter + stepIndex * angleStepOuter
    local nextAngleOuter    = startAngleOuter + (stepIndex + 1) * angleStepOuter

    local currentCosInner, currentSinInner  = math.cos(currentAngleInner),  math.sin(currentAngleInner)
    local nextCosInner, nextSinInner        = math.cos(nextAngleInner),     math.sin(nextAngleInner)
    local currentCosOuter, currentSinOuter  = math.cos(currentAngleOuter),  math.sin(currentAngleOuter)
    local nextCosOuter, nextSinOuter        = math.cos(nextAngleOuter),     math.sin(nextAngleOuter)

    local innerStartPoint = {centerCoordinates[1] + currentCosInner * innerArcRadius, centerCoordinates[2] + currentSinInner * innerArcRadius}
    local outerStartPoint = {centerCoordinates[1] + currentCosOuter * outerArcRadius, centerCoordinates[2] + currentSinOuter * outerArcRadius}
    local outerEndPoint   = {centerCoordinates[1] + nextCosOuter * outerArcRadius, centerCoordinates[2] + nextSinOuter * outerArcRadius}
    local innerEndPoint   = {centerCoordinates[1] + nextCosInner * innerArcRadius, centerCoordinates[2] + nextSinInner * innerArcRadius}

    canvasWidget:drawTriangles({{innerStartPoint, outerStartPoint, outerEndPoint}, {innerStartPoint, outerEndPoint, innerEndPoint}}, fillColour)
  end
end

function update(dt)
  if shared.starPoundsRadialMenuClose then
    shared.starPoundsRadialMenuClose = nil
    return pane.dismiss()
  end
  -- Redraw while the animation is running.
  if animationTimer < animationDuration then
    animationTimer = math.min(animationDuration, animationTimer + dt)
    needsRedraw = true
  end
  local animationProgress = animationTimer / animationDuration
  local animationScale = 1 - (1 - animationProgress)^3
  -- Arc detection.
  local mousePosition = canvasWidget:mousePosition()
  local deltaX = mousePosition[1] - centerCoordinates[1]
  local deltaY = mousePosition[2] - centerCoordinates[2]
  local distanceFromCenter = (deltaX * deltaX + deltaY * deltaY)^0.5

  local previousHoveredIndex = hoveredOptionIndex
  hoveredOptionIndex = nil
  local isCenterHovered = false
  local currentHoverTarget = nil

  if distanceFromCenter < (radiusInner - 5) then
    isCenterHovered = true
    currentHoverTarget = "center"
  elseif distanceFromCenter >= radiusInner then
    local mouseAngle = math.atan(deltaY, deltaX)
    local targetIndex = nil

    for optionIndex, option in ipairs(menuOptions) do
      local diff = (mouseAngle - option.midpointAngle) % (math.pi * 2)
      if diff > math.pi then diff = diff - (math.pi * 2) end

      local halfSweep = (option.endAngle - option.startAngle) * 0.5
      if math.abs(diff) <= (halfSweep + 0.0001) then
        targetIndex = optionIndex
        break
      end
    end

    if targetIndex then
      local maxRadius = (targetIndex == previousHoveredIndex) and (radiusOuter + 10) or radiusOuter

      if distanceFromCenter <= maxRadius then
        hoveredOptionIndex = targetIndex
        currentHoverTarget = hoveredOptionIndex
      end
    end
  end
  -- Play sound (and queue redraw) on hover change.
  if currentHoverTarget ~= lastHoveredTarget then
    if currentHoverTarget ~= nil then
      pane.playSound("/sfx/interface/hoverover_bumb.ogg")
    end
    needsRedraw = true
  end
  lastHoveredTarget = currentHoverTarget
  -- Queue redraw on clicks.
  if isMouseDown ~= prevMouseDown then
    needsRedraw = true
    prevMouseDown = isMouseDown
  end
  -- Trigger on mouse release.
  if isMouseReleased then
    isMouseReleased = false
    needsRedraw = true -- Redraw on mouse releases.
    if hoveredOptionIndex and menuOptions[hoveredOptionIndex] then
      local selectedOption = menuOptions[hoveredOptionIndex]

      if selectedOption.onClick and type(selectedOption.onClick) == "function" then
        local preventDefault = selectedOption:onClick(hoveredOptionIndex)
        if preventDefault == true then return end
      end
      -- Clicky.
      pane.playSound("/sfx/interface/clickon_success.ogg")
      -- Load new menu if it has children.
      if selectedOption.options and #selectedOption.options > 0 then
        table.insert(menuStack, menuOptions)
        loadMenu(selectedOption.options)
        return
      end
      -- Bubbly sound when we select a new action.
      pane.playSound("/sfx/interface/crafting_medical.ogg")

      hasSelectedOption = true
      shared.starPoundsRadialMenu = {
        selection = selectedOption.name,
        type = config.getParameter("type"),
        instant = selectedOption.instant,
        keepOpen = selectedOption.keepOpen,
        pressed = true
      }

      if not selectedOption.keepOpen then
        return pane.dismiss()
      end
    elseif isCenterHovered then
      pane.playSound("/sfx/interface/clickon_success.ogg")
      -- Load the previous menu if it exists, or close.
      if #menuStack > 0 then
        local parentMenu = table.remove(menuStack)
        loadMenu(parentMenu)
        return
      else
        return pane.dismiss()
      end
    end
  end

  for optionIndex = 1, optionCount do
    local isHovered = (optionIndex == hoveredOptionIndex)
    local currentOption = menuOptions[optionIndex]
    if currentOption.update then
      currentOption:update(dt, isHovered, optionIndex)
    end
  end
  -- Skip the rest if we're not redrawing.
  if not needsRedraw then return end
  needsRedraw = false

  canvasWidget:clear()

  for optionIndex = 1, optionCount do
    local isHovered = (optionIndex == hoveredOptionIndex)
    local isPressed = isHovered and isMouseDown
    local currentOption = menuOptions[optionIndex]

    local startAngle = currentOption.startAngle
    local endAngle = currentOption.endAngle
    local midpointAngle = currentOption.midpointAngle

    local currentOuterRadius = isHovered and (radiusOuter + 5) or radiusOuter

    local defaultColour = isPressed and colours.press or (isHovered and colours.hover or colours.base)
    local sliceColour = isHovered and currentOption.colour or defaultColour

    local animInnerRadius = radiusInner
    local animOuterRadius = radiusInner + (currentOuterRadius - radiusInner) * animationScale

    drawArcSegment(startAngle, endAngle, animInnerRadius, animOuterRadius, sliceColour, 3.5)

    local iconRadius = (radiusInner + animOuterRadius) * 0.5
    local elementPosition = {centerCoordinates[1] + math.cos(midpointAngle) * iconRadius, centerCoordinates[2] + math.sin(midpointAngle) * iconRadius}
    local displayText = currentOption.pretty or currentOption.name or ""

    if currentOption.icon then
      local iconPos = isHovered and {elementPosition[1], elementPosition[2] + 4} or elementPosition
      canvasWidget:drawImage(currentOption.icon, iconPos, nil, nil, true)

      if isHovered then
        local textPosition = {elementPosition[1], elementPosition[2] - 8}
        canvasWidget:drawText("^shadow,set;"..displayText, {position = textPosition, horizontalAnchor = "mid", verticalAnchor = "mid"}, 6, colours.textHover)
      end
    else
      -- Fallback to the title/name if there's no icon.
      canvasWidget:drawText("^shadow,set;"..displayText, {position = elementPosition, horizontalAnchor = "mid", verticalAnchor = "mid"}, 8, isHovered and colours.textHover or colours.textDark)
    end
  end
  -- Inner circle.
  local isCenterPressed = isCenterHovered and isMouseDown
  local centerBackgroundColour = isCenterPressed and colours.press or (isCenterHovered and colours.hover or colours.center)
  local centerRingColour = not (isCenterPressed or isCenterHovered) and colours.base or colours.hidden

  drawArcSegment(0, math.pi * 2, 0, radiusInner - 6, centerBackgroundColour)
  drawArcSegment(0, math.pi * 2, radiusInner - 7, radiusInner - 5, centerRingColour)
  -- Default center text.
  local centerText = (#menuStack > 0) and "Back" or "Close"
  local centerTextColour = isCenterHovered and colours.textHover or colours.text
  local centerDescription = nil
  -- Set the center text if we're hovering an option.
  if hoveredOptionIndex and menuOptions[hoveredOptionIndex] then
    centerText = menuOptions[hoveredOptionIndex].title or menuOptions[hoveredOptionIndex].pretty or menuOptions[hoveredOptionIndex].name or "?"
    centerTextColour = colours.textHover
    centerDescription = menuOptions[hoveredOptionIndex].description
  end
  -- Shift title up slightly if there is a description to make room.
  local titleYOffset = centerDescription and 5 or 0
  local titlePosition = {centerCoordinates[1], centerCoordinates[2] + titleYOffset}

  canvasWidget:drawText("^shadow,set;"..centerText, {position = titlePosition, horizontalAnchor = "mid", verticalAnchor = "mid"}, 8, centerTextColour)
  -- Title and description text in center.
  if centerDescription then
    local descriptionPosition = {centerCoordinates[1], centerCoordinates[2] - 2}
    canvasWidget:drawText("^shadow,set;"..centerDescription, {position = descriptionPosition, horizontalAnchor = "mid", verticalAnchor = "top"}, 6, colours.textGrey)
  end
end

function canvasClickEvent(clickPosition, mouseButton, isButtonDown)
  if mouseButton == 0 then
    if isButtonDown ~= isMouseDown then
      needsRedraw = true
    end
    if isButtonDown then
      isMouseDown = true
    else
      if isMouseDown then
        isMouseReleased = true
        isMouseDown = false
      end
    end
  elseif mouseButton == 2 and isButtonDown then
    -- Right click immediately closes the menu.
    pane.dismiss()
  end
end

function uninit()
  shared.starPoundsRadialMenuOpen = false
  if not hasSelectedOption then
    shared.starPoundsRadialMenu = {selection = "cancel", pressed = true}
  end
  shared.starPoundsRadialOptions = nil
end
