local TrailDashDash_old = TrailDash.dash
function TrailDash:dash(...)
  local defaultDashSpeed = self.dashSpeed

  local starPounds = getmetatable ''.starPounds
  if starPounds then
    -- Keep at least 10% of the speed in case we're immobile.
    self.dashSpeed = math.max(defaultDashSpeed * (starPounds.movementMultiplier or 1), defaultDashSpeed * 0.1)
  end

  TrailDashDash_old(self, ...)
  self.dashSpeed = defaultDashSpeed
end
