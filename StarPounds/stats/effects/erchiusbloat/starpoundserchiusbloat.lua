function init()
  script.setUpdateDelta(5)
  self.bloatAmount = effect.getParameter("bloatAmount", 10)
  self.bloatIncrease = effect.getParameter("bloatIncrease", 1)
  self.bloatCap = effect.getParameter("bloatCap", 100)
  self.soundVolume = effect.getParameter("soundVolume", 1)
  self.tickTime = effect.getParameter("tickTime", 1)
  self.tickTimer = 0

  self.desaturateAmount = config.getParameter("desaturateAmount")
  self.multiply = config.getParameter("multiplyColor")

  self.saturation = 0

  animator.setSoundVolume("geiger", 0)

  starPounds = getmetatable ''.starPounds
end

function update(dt)
  if world.entityType(entity.id()) == "npc" or (starPounds and starPounds.isEnabled()) then
    -- Gain bloatAmount per tickTime, increased by bloatIncrease per tick. (Max: 100 per second)
    self.tickTimer = self.tickTimer - dt
    if self.tickTimer <= 0 then
      self.tickTimer = self.tickTime
      self.saturation = math.floor(-self.desaturateAmount * self.bloatAmount * 0.01)

      local multiply = {255 + self.multiply[1] * self.bloatAmount * 0.01, 255 + self.multiply[2] * self.bloatAmount * 0.01, 255 + self.multiply[3] * self.bloatAmount * 0.01}
      local multiplyHex = string.format("%s%s%s", toHex(multiply[1]), toHex(multiply[2]), toHex(multiply[3]))
      world.sendEntityMessage(entity.id(), "starPounds.stomach.feed", self.bloatAmount, "bloat")
      effect.setParentDirectives(string.format("?saturation=%d?multiply=%s", self.saturation, multiplyHex))
      if playedSound then
        animator.setSoundVolume("geiger", self.soundVolume * (self.bloatAmount/self.bloatCap))
      end
      self.bloatAmount = math.min(self.bloatAmount + self.bloatIncrease, self.bloatCap)
    end
    -- Delaying this by a tick because setting the volume takes one tick, apparently.
    if not playedSound then
      animator.playSound("geiger", -1)
    end
    playedSound = true
  else
    effect.expire()
  end
end

function toHex(num)
  local hex = string.format("%X", math.floor(num + 0.5))
  if num < 16 then hex = "0"..hex end
  return hex
end
