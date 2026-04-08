require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  starPounds = getmetatable ''.starPounds
  experienceConfig = root.assetJson("/scripts/starPounds/modules/experience.config")
  sizes = starPounds.moduleFunc("size", "sizes")
  -- Offset to the left of the action bar, with a 10 pixel buffer.
  offsetPane()
  displayPane()

  lastSize = starPounds.currentSize.size or ""
  updateSizeButton(lastSize)

  starPounds.modules.oSB.dismissToolbar = pane.dismiss
end

function update(dt)
  starPounds = getmetatable ''.starPounds

  local sizeProgress = 0
  local immobileProgress = 0

  if starPounds.isEnabled() then
    sizeProgress = starPounds.progress * 0.01
    -- Overlay a red bar for the last immobile size.
    if starPounds.moduleFunc("size", "sizeIndex") == #sizes then
      immobileProgress = sizeProgress
      sizeProgress = 1
    end
  end

  widget.setProgress("sizeBar", sizeProgress)
  widget.setProgress("sizeBarImmobile", immobileProgress)
  widget.setProgress("experienceBar", starPounds.level / experienceConfig.maxLevel)

  updateStomach()
  updateMilk()

  if starPounds.currentSize.size ~= lastSize then
    updateSizeButton(starPounds.currentSize.size)
    lastSize = starPounds.currentSize.size
  end

  -- Offset can get randomly double on init for whatever fucking reason.
  -- Might be due to interface scaling in oSB.
  if not firstTick then
    -- Offset again with a one tick delay.
    offsetPane()
  end
  -- Hide/show pane.
  displayPane()
end

function offsetPane()
  local paneSize = pane.getSize()
  local actionBarSize = root.imageSize("/interface/actionbar/actionbarbg.png")
  local playerBarOffset = -0.5 * (paneSize[1] + actionBarSize[1]) - 10

  pane.setPosition({playerBarOffset, 1})
end

function displayPane()
  local shouldHide = not (starPounds.isEnabled() and starPounds.moduleFunc("oSB", "hasOpenStarbound") and not starPounds.hasOption("disableInterface"))
  if not hidden and shouldHide then
    pane.hide()
    hidden = true
  elseif hidden and not shouldHide then
    pane.show()
    hidden = nil
  end
end

function updateSizeButton(size)
  local image = string.format("/interface/scripted/starpounds/toolbar/buttonIcons/starpounds%s.png", size)
  widget.setButtonImages("sizeButton", {
    base = image..":default",
    hover = image..":hover",
    pressed = image..":pressed",
  })
end

function updateStomach()
  if not widget.active("stomachButton") then return end
  local fullness = 0
  local bar1 = 0
  local bar2 = 0
  local bar3 = 0

  local strain = 0

  if starPounds.isEnabled() then
    fullness = starPounds.stomach.interpolatedFullness
    bar1 = math.min(fullness, 1)
    bar2 = math.max(math.min(fullness - 1, 2), 0)
    bar3 = math.max(math.min(fullness - 2, 3), 0)
    strain = starPounds.moduleFunc("strain", "get")
  end

  widget.setProgress("capacityBar1", bar1)
  widget.setProgress("capacityBar2", bar2)
  widget.setProgress("capacityBar3", bar3)
  widget.setProgress("strainBar", strain)

  local stomachFrame = tostring(util.clamp(math.ceil(fullness), 1, 3))
  if stomachFrame ~= stomachLastFrame then
    updateStomachButton(stomachFrame)
    stomachLastFrame = stomachFrame
  end
end

function updateStomachButton(frame)
  local image = string.format("/interface/scripted/starpounds/toolbar/stomach.png:%s", frame)
  widget.setButtonImages("stomachButton", {
    base = image,
    hover = image..".hover",
    pressed = image..".hover",
  })
end

function updateMilk()
  if not widget.active("milkButton") then return end
  local fullness = 0
  local contents = 0
  local icon = "milk"

  if starPounds.isEnabled() then
    local breasts = starPounds.moduleFunc("breasts", "get")
    fullness = breasts.fullness
    contents = breasts.contents
    icon = breasts.type
  end

  widget.setProgress("milkBar", fullness)

  local breastSize = (starPounds.hasOption("disableBreastGrowth") and 0 or contents)
  if starPounds.currentSize.breastOptions then
    local additionalSize = 0
    for option, amount in pairs(starPounds.currentSize.breastOptions) do
      additionalSize = math.max(additionalSize, starPounds.hasOption(option) and amount or 0)
    end

    breastSize = breastSize + additionalSize
  end

  local milkFrame = 1
  for i, threshold in ipairs(starPounds.currentSize.thresholds.breasts) do
    if breastSize >= threshold.amount then
      milkFrame = i + 1
    end
  end

  -- Just use the biggest with hyper.
  if starPounds.hasOption("hyper") then milkFrame = 3 end

  milkFrame = tostring(util.clamp(milkFrame, 1, 3))

  if milkFrame ~= milkLastFrame then
    updateMilkButton(milkFrame)
    milkLastFrame = milkFrame
  end

  if icon ~= milkLastType then
    widget.setImage("barIcon1", "/interface/scripted/starpounds/toolbar/milkbaricon.png:"..icon)
    milkLastType = icon
  end
end

function updateMilkButton(frame)
  local image = string.format("/interface/scripted/starpounds/toolbar/milk.png:%s", frame)
  widget.setButtonImages("milkButton", {
    base = image,
    hover = image..".hover",
    pressed = image..".hover",
  })
end

function sizeButton()
  player.interact("ScriptPane", {gui = {}, scripts = {"/metagui.lua"}, ui = "starpounds:menu"})
end

function stomachButton()
  displayStomachInfo(false)
  displayMilkInfo(true)
end

function milkButton()
  displayMilkInfo(false)
  displayStomachInfo(true)
end


function displayStomachInfo(visible)
  widget.setVisible("stomachButton", visible)
  widget.setVisible("capacityBar1", visible)
  widget.setVisible("capacityBar2", visible)
  widget.setVisible("capacityBar3", visible)
  widget.setVisible("strainBar", visible)

  if visible then
    widget.setImage("barIcon1", "/interface/scripted/starpounds/toolbar/capacitybaricon.png")
    widget.setImage("barIcon2", "/interface/scripted/starpounds/toolbar/strainbaricon.png")
    widget.setVisible("barBackground1", true)
    widget.setVisible("barBackground2", true)
  else
    widget.setImage("barIcon1", "")
    widget.setImage("barIcon2", "")
    widget.setVisible("barBackground1", false)
    widget.setVisible("barBackground2", false)
  end
end


function displayMilkInfo(visible)
  widget.setVisible("milkButton", visible)
  widget.setVisible("milkBar", visible)

  if visible then
    widget.setImage("barIcon1", "/interface/scripted/starpounds/toolbar/milkbaricon.png:"..(milkLastType or "milk"))
    widget.setImage("barIcon2", "")
    widget.setVisible("barBackground1", true)
    widget.setVisible("barBackground2", false)
  else
    widget.setImage("barIcon1", "")
    widget.setImage("barIcon2", "")
    widget.setVisible("barBackground1", false)
    widget.setVisible("barBackground2", false)
  end
end

function uninit()
  -- oSB module reopens it automatically.
  pane.dismiss()
end
