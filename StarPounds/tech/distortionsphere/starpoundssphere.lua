local init_old = init or function() end
function init()
  init_old()
  local activate_old = activate or function() end
  local deactivate_old = deactivate or function() end

  function activate()
    activate_old()
    status.setPersistentEffects("movementAbility", {{stat = "activeMovementAbilities", amount = 2}})
    starPounds = getmetatable ''.starPounds or {}
    if starPounds then starPounds.events:fire("stats:calculate", "tech:sphereActivate") end
  end

  function deactivate()
    deactivate_old()
    starPounds = getmetatable ''.starPounds or {}
    if starPounds then starPounds.events:fire("tech:sphereDeactivate") end
  end
  -- Already in the throg sphere.
  if config.getParameter("name") ~= "starpoundsthrogsphere" then
    local update_old = update or function() end
    function update(args)
      starPounds = getmetatable ''.starPounds or {}
      self.currentSize = starPounds.currentSize and starPounds.currentSize.size or ""
      if self.currentSize ~= self.oldSize then
        self.basePoly = starPounds.currentSize and (starPounds.currentSize.controlParameters[starPounds.getVisualSpecies()] or starPounds.currentSize.controlParameters.default).standingPoly or mcontroller.baseParameters().standingPoly
      end
      self.oldSize = self.currentSize
      update_old(args)
    end
  end
end
