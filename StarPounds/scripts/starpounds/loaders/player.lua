-- Run on load.
function init()
  -- Load StarPounds.
  require "/scripts/starpounds/starpounds.lua"
  -- Used in functions for detection.
  starPounds.type = "player"
  -- Setup message handlers
  starPounds.messageHandlers()
  -- Reload whenever the entity loads in/beams/etc.
  starPounds.moduleInit({"base", "entity", "humanoid", "player", "vore"})
  -- Apply species trait skills.
  starPounds.moduleFunc("traits", "applySpeciesTrait")
end

function update(dt)
  -- Check promises.
  promises:update()
  -- Modules.
  starPounds.moduleUpdate(dt)
end

function uninit()
  starPounds.moduleUninit()
end
