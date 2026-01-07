local init_old = init or function() end
local update_old = update or function() end

function init()
  init_old()
  -- Cross script stuff.
  starPounds = getmetatable ''.starPounds
  starPoundsEnabled = starPounds and starPounds.isEnabled()
  -- Turn off the particles if the mod is running.
  animator.setParticleEmitterActive("healing", config.getParameter("particles", not starPoundsEnabled))
end


function update(dt)
  local isEnabled = starPounds and starPounds.isEnabled()
  if isEnabled ~= starPoundsEnabled then
    starPoundsEnabled = isEnabled
    animator.setParticleEmitterActive("healing", config.getParameter("particles", not isEnabled))
  end
  -- Remove the effect if we toggle.
  if isEnabled ~= (starPounds and starPounds.isEnabled()) then
    effect.expire()
    return
  end
  -- Remove the effect if the player falls under the wellfed threshold.
  if isEnabled then
    if starPounds.moduleFunc("stomach", "canEat") then
      effect.expire()
      return
    end
  end
  -- Run old stuff if the mod isn't enabled.
  if not isEnabled then
    update_old(dt)
  end
end
