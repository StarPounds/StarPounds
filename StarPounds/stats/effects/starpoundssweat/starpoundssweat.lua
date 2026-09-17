function init()
  animator.setParticleEmitterActive("drips", true)
end

function update(dt)
  if effect.duration() and world.liquidAt({mcontroller.xPosition(), mcontroller.yPosition() - 1}) then
    effect.expire()
  end
  animator.setParticleEmitterOffsetRegion("drips", mcontroller.boundBox())
end

function uninit()

end
