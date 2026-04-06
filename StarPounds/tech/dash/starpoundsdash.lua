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
    -- Stop harder for weight.
    if self.stopAfterDash then
      self.stopAfterDash = false

      starPounds = getmetatable ''.starPounds or {}
      local movementParams = mcontroller.baseParameters()
      local runSpeed = movementParams.runSpeed * (starPounds.movementMultiplier or 1)
      local currentVelocity = mcontroller.velocity()
      if math.abs(currentVelocity[1]) > runSpeed then
        mcontroller.setVelocity({runSpeed * self.dashDirection, 0})
      end
      mcontroller.controlApproachXVelocity(self.dashDirection * runSpeed, self.dashControlForce)
    end

    self.dashControlForce = self.baseDashControlForce
    self.dashSpeed = self.baseDashSpeed

    endDash_old(...)

    self.stopAfterDash = true
  end
end
