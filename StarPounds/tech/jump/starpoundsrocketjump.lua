local init_old = init or function() end
function init()
  init_old()
  -- Save this so we can revert to it
  self.baseBoostForce = self.boostForce
  self.baseBoostSpeed = self.boostSpeed
end

local update_old = update or function() end
function update(...)
  -- Increase the boost force based on weight multiplier.
  if self.state == "charge" or self.state == "boost" then
    starPounds = getmetatable ''.starPounds or {}
    self.boostForce = self.baseBoostForce * (starPounds.weightMultiplier or 1)
    self.boostSpeed = self.baseBoostSpeed * ((starPounds.movementMultiplier or 1) * 0.5 + 0.5) -- Only a 50% reduction.
  else
    self.boostForce = self.baseBoostForce
    self.boostSpeed = self.baseBoostSpeed
  end
  update_old(...)
end
