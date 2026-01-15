function init()
  animator.setParticleEmitterOffsetRegion("drips", mcontroller.boundBox())
  animator.setParticleEmitterActive("drips", true)
  local directives = config.getParameter("directives")
  if directives then
    effect.setParentDirectives(directives)
  end

  modifiers = config.getParameter("modifiers", {})
end

function update(dt)
  mcontroller.controlModifiers(modifiers)
end

function uninit()

end
