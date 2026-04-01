require "/scripts/messageutil.lua"

function init()
  script.setUpdateDelta(5)
  self.progressStep = effect.getParameter("progressStep", 0.01) * effect.duration()

  animator.setSoundVolume("digest", 0.75)
  animator.setSoundPitch("digest", 1)

  starPounds = getmetatable ''.starPounds
  if world.entityType(entity.id()) == "npc" or (starPounds and starPounds.isEnabled()) then
    promises:add(world.sendEntityMessage(entity.id(), "starPounds.getData"), function(starPounds)
      increaseWeightProgress(starPounds.weight, self.progressStep)
      effect.expire()
    end)
  end
end

function update(dt)
  promises:update()
end
