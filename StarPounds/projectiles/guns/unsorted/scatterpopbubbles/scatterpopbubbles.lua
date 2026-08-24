require "/scripts/vec2.lua"
function init()
  projectile.setTimeToLive(variance("timeToLiveVariance"))
  mcontroller.setVelocity(vec2.mul(mcontroller.velocity(), variance("speedVariance")))
end

function variance(value)
  return 1 + (math.random() - 0.5) * projectile.getParameter(value, 0)
end