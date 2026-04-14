require "/scripts/messageutil.lua"

function init()
  script.setUpdateDelta(5)
  self.amount = effect.getParameter("amount", 1)
  self.tickTime = effect.getParameter("tickTime", 1)
  self.tickTimer = 0
end

function update(dt)
  promises:update()

  self.tickTimer = self.tickTimer - dt
  if self.tickTimer <= 0 then
    self.tickTimer = self.tickTime
    promises:add(world.sendEntityMessage(entity.id(), "starPounds.breasts.gainMilk", self.amount * self.tickTime), function()
      world.sendEntityMessage(entity.id(), "starPounds.breasts.lactate", 0.5 * self.amount * self.tickTime, true)
    end)
  end
end
