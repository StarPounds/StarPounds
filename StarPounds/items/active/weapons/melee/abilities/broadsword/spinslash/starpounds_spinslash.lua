local SpinSlashSlash_old = SpinSlash.slash
function SpinSlash:slash(...)
  if not self.hover then
    SpinSlashSlash_old(self, ...)
    return
  end

  local defaultHoverYSpeed = self.hoverYSpeed
  local defaultHoverForce = self.hoverForce

  local starPounds = getmetatable ''.starPounds
  if starPounds then
    self.hoverYSpeed = defaultHoverYSpeed * (starPounds.movementMultiplier or 1)
    self.hoverForce = defaultHoverForce * starPounds.weightMultiplier
  end

  SpinSlashSlash_old(self, ...)
  self.hoverYSpeed = defaultHoverYSpeed
  self.hoverForce = defaultHoverForce
end
