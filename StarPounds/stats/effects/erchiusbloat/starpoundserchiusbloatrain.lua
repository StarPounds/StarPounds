local init_old = init
function init()
  init_old()
  animator.setParticleEmitterActive("drips", true)
end

local update_old = update
function update(dt)
  update_old(dt)
  animator.setParticleEmitterOffsetRegion("drips", mcontroller.boundBox())
end
