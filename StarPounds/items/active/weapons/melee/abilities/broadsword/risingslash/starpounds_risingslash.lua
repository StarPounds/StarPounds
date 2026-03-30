local RisingSlashSlash_old = RisingSlash.slash
function RisingSlash:slash(...)
  local defaultDashSpeed = self.dashSpeed
  local defaultDashControlForce = self.dashControlForce

  local starPounds = getmetatable ''.starPounds
  if starPounds then
    self.dashSpeed = defaultDashSpeed * (starPounds.jumpMultiplier or 1)
    self.dashControlForce = defaultDashControlForce * starPounds.weightMultiplier
  end

  RisingSlashSlash_old(self, ...)
  self.dashSpeed = defaultDashSpeed
  self.dashControlForce = defaultDashControlForce
end
