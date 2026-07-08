--Metagui slider widget fix so it actually works.
local mg = metagui
local widgets = mg.widgetTypes
local mkwidget = mg.mkwidget

do -- slider -------------------------------------------------------------------
  -- Overwrite the existing slider prototype.
  widgets.slider = mg.proto(widgets.button, {
    min = 0, max = 100, value = 0,
    granularity = 1,
    expandMode = {1, 0},

    buffer = 0,
    rawBuffer = 0,
  })

  local namedSiblingPools = { }

  function widgets.slider:init(base, param)
    self.numberFormat = param.numberFormat or "%s"
    self.showRangeText = param.showRangeText ~= false
    self.showThumbText = param.showThumbText ~= false
    self.granularity = param.granularity or param.step
    self:setRange(param.range or param.min, param.max)
    if type(param.value) == "number" then self:setValue(param.value) end

    self.state = "idle"

    self.backingWidget = mkwidget(base, { type = "canvas" })

    -- find/create sibling pool
    local pool = param.pool or param.siblingPool
    if type(pool) == "string" then -- named pool
      self.siblingPool = namedSiblingPools[pool]
      if not self.siblingPool then
        self.siblingPool = { }
        namedSiblingPools[pool] = self.siblingPool
      end
      self.siblingPool[self] = true
    elseif self.parent and self.parent.widgetType == "layout" then -- auto pool
      self.siblingPool = { [self] = true }
      if self.parent.mode == "vertical" then -- immediate siblings
        for _, w in pairs(self.parent.children) do
          if w.widgetType == "slider" and w ~= self then
            if w.siblingPool then -- join existing
              self.siblingPool = w.siblingPool
              self.siblingPool[self] = true
              break
            else self.siblingPool[w] = true end
          end
        end
      elseif self.parent.mode == "horizontal" then -- grouped siblings
        local pp = self.parent.parent
        if pp and pp.widgetType == "layout" and pp.mode == "vertical" then
          for _, l in pairs(pp.children) do
            if l.widgetType == "layout" and l.mode == "horizontal" then -- valid layout
              local sc
              for _, w in pairs(l.children) do
                if w.widgetType == "slider" and w ~= self then
                  if w.siblingPool then -- join existing
                    self.siblingPool = w.siblingPool
                    self.siblingPool[self] = true
                    sc = true break
                  else self.siblingPool[w] = true end
                end
              end
              if sc then break end
            end
          end
        end
      end
    end
    if self.siblingPool then self:setRange() end -- kick buffer
  end

  function widgets.slider:uninit()
    -- remove self from pool
    if self.siblingPool then self.siblingPool[self] = nil end
  end

  function widgets.slider:preferredSize() return {96, mg.theme.sliderHeight} end

  function widgets.slider:draw()
    mg.theme.drawSlider(self)
  end

  function widgets.slider:isMouseInteractable() return true end
  function widgets.slider:isWheelInteractable() return true end

  function widgets.slider:onMouseEnter()
    self.state = "hover"
    self:queueRedraw()
  end

  -- Override onMouseButtonEvent to capture direct clicks
  function widgets.slider:onMouseButtonEvent(btn, down)
    if btn == 0 then -- left button
      if down then
        self.state = "press"
        self:captureMouse(btn)
        self:queueRedraw()
        self:onCaptureMouseMove() -- update value immediately upon clicking
      elseif self.state == "press" then
        self.state = "hover"
        self:releaseMouse()
        self:queueRedraw()
      end
      return true
    end
  end

  function widgets.slider:onCaptureMouseMove()
    local orig = self.value
    local mx = self:relativeMousePosition()[1]
    local tb = self.buffer + mg.theme.sliderPadding + (mg.theme.sliderThumbWidth / 2)
    -- Prevent division by zero if widget is squished
    local tl = math.max(1, self.size[1] - tb * 2)

    self:setValue(self.min + (mx - tb) * (self.max - self.min) / tl)

    -- Only emit event if the value has actually changed
    if self.value ~= orig then
      mg.startEvent(self.onValueChanged, self)
    end
  end

  function widgets.slider:onMouseWheelEvent(dir)
    local orig = self.value
    self:setValue(self.value + self.granularity * dir)

    -- Only emit event if the value has actually changed
    if self.value ~= orig then
      mg.startEvent(self.onValueChanged, self)
    end

    -- Consume the event so we don't accidentally scroll a background panel
    return true
  end

  function widgets.slider:setRange(min, max)
    if not min and not max then min, max = self.min, self.max end -- nothing given, just use current values
    if not max then max = 0 end
    if type(min) == "table" then min, max = min[1] or 0, min[2] or 0 end
    self.min = math.min(min, max)
    self.max = math.max(min, max)

    local minText = self.showRangeText and string.format(self.numberFormat, min) or ""
    local maxText = self.showRangeText and string.format(self.numberFormat, max) or ""
    self.rawBuffer = math.max(mg.measureString(minText, nil, mg.theme.sliderTextSize)[1], mg.measureString(maxText, nil, mg.theme.sliderTextSize)[1])
    self.buffer = self.rawBuffer
    if self.siblingPool then -- automatically sync adjacent sliders' buffer widths
      local b = 0
      for w in pairs(self.siblingPool) do b = math.max(b, w.rawBuffer) end
      for w in pairs(self.siblingPool) do w.buffer = b w:queueRedraw() end
    end

    self:queueRedraw()
  end

  function widgets.slider:setValue(v, raw)
    self.value = v
    if not raw and type(self.granularity) == "number" and self.granularity > 0 then
      self.value = math.floor(self.value / self.granularity + 0.5) * self.granularity
    end
    self.value = util.clamp(self.value, self.min, self.max)
    self:queueRedraw()
  end

  widgets.slider.setText = false

  -- events out
  function widgets.slider:onValueChanged() end
end

mg.theme.assets.sliderBackground = mg.ninePatch "starpounds_sliderBackground"
mg.theme.assets.sliderThumb = mg.extAsset "starpounds_sliderThumb.png"

mg.theme.sliderHeight = mg.theme.sliderHeight or mg.theme.assets.sliderBackground.frameSize[2]
mg.theme.sliderPadding = mg.theme.sliderPadding or 2
mg.theme.sliderTextColor = mg.theme.sliderTextColor or mg.theme.baseTextColor
mg.theme.sliderTextSize = mg.theme.sliderTextSize or 8
mg.theme.sliderThumbWidth = mg.theme.assets.sliderThumb.frameSize[1]

function mg.theme.drawSlider(w)
  local c = widget.bindCanvas(w.backingWidget)
  c:clear()
  local s = c:size()
  local tb = w.buffer + mg.theme.sliderPadding
  local tr = {tb, 0, s[1] - tb, s[2]} -- rect within slider area proper

  local pfx = "^shadow;"

  -- draw slider background
  mg.theme.assets.sliderBackground:draw(c, "idle", tr)
  -- draw range values
  local color = mg.getColor(mg.theme.sliderTextColor)
  if color then color = "#" .. color end
  -- Extra option to hide the text.
  if w.showRangeText ~= false then
    c:drawText(pfx..string.format(w.numberFormat, w.min), { position = {w.buffer / 2, s[2]/2}, horizontalAnchor = "mid", verticalAnchor = "mid" }, theme.sliderTextSize, color)
    c:drawText(pfx..string.format(w.numberFormat, w.max), { position = {s[1] - w.buffer / 2, s[2]/2}, horizontalAnchor = "mid", verticalAnchor = "mid" }, theme.sliderTextSize, color)
  end

  -- and then the thumb
  local thumbWidth = mg.theme.sliderThumbWidth
  local p = util.clamp((w.value - w.min) / (w.max - w.min), 0.0, 1.0) -- proportion
  local tl = tr[3] - tr[1] - thumbWidth
  local tp = tl * p
  tp = tp + tr[1] + thumbWidth/2
  --assets.button:draw(c, w.state, {tp, 0, tp + thumbWidth, s[2]})
  mg.theme.assets.sliderThumb:draw(c, w.state, {tp, s[2]/2}, 1.0, 0)
  -- Extra option to hide the text.
  if w.showThumbText ~= false then
    if p > 0.5 then
      c:drawText(pfx..string.format(w.numberFormat, w.value), { position = {tp - thumbWidth/2 - mg.theme.sliderPadding, s[2]/2}, horizontalAnchor = "right", verticalAnchor = "mid" }, theme.sliderTextSize, color)
    else
      c:drawText(pfx..string.format(w.numberFormat, w.value), { position = {tp + thumbWidth/2 + mg.theme.sliderPadding, s[2]/2}, horizontalAnchor = "left", verticalAnchor = "mid" }, theme.sliderTextSize, color)
    end
  end
end
