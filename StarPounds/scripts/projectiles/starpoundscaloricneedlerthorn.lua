require "/scripts/util.lua"

function init()
  self.timeToLive = config.getParameter("timeToLive")
  self.timeToLiveVariance = (math.random() * 2 - 1) * config.getParameter("timeToLiveVariance", 0)

  projectile.setTimeToLive(self.timeToLive + self.timeToLiveVariance)
end
