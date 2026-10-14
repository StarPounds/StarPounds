function init()
  script.setUpdateDelta(0)
  self.tube = mcontroller.anchorState()
  if self.tube then
    world.sendEntityMessage(self.tube, "starPounds.feedingTube.setTarget", entity.id())
  end
end

function uninit()
  if self.tube then
    world.sendEntityMessage(self.tube, "starPounds.feedingTube.clearTarget", entity.id())
  end
end
