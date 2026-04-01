local init_old = init or function() end
function init()
  init_old()
  -- Save this so we can revert to it
  self.baseDashControlForce = self.dashControlForce
  self.baseDashSpeed = self.dashSpeed
  local startDash_old = startDash or function() end
  function startDash(...)
    starPounds = getmetatable ''.starPounds or {}
    self.dashControlForce = self.baseDashControlForce * (starPounds.weightMultiplier or 1)
    self.dashSpeed = self.baseDashSpeed * ((starPounds.movementMultiplier or 1) * 0.9 + 0.1)
    -- controlApproachVelocity takes into account the speedModifier for whatever reason, so divide by it after the reduction.
    self.dashSpeed = self.dashSpeed / starPounds.movementMultiplier

    startDash_old(...)
  end

  local endDash_old = endDash or function() end
  function endDash(...)
    self.dashControlForce = self.baseDashControlForce
    self.dashSpeed = self.baseDashSpeed

    endDash_old(...)
  end
end
