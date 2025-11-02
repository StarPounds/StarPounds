-- Old functions.
local init_old = init or function() end
local update_old = update or function(dt) end
local uninit_old = uninit or function() end
-- Run on load.
function starPoundsInit()
  -- Monsters usually load this from a behaviour script, so we can't just hook into init since it's already run.
  require "/scripts/starpounds/starpounds.lua"
  -- Used in functions for detection.
  starPounds.type = "monster"
  -- Setup message handlers
  starPounds.messageHandlers()
  -- Reload whenever the entity loads in/beams/etc.
  starPounds.moduleInit({"base", "entity", "monster", "vore"})
end

-- Kinda dirty. Behaviour scripts may have called init already (which means SB tables such as root are ready).
if root then
  starPoundsInit()
else -- Do the normal init replace otherwise.
  function init()
    init_old()
    starPoundsInit()
  end
end

function update(dt)
  -- Run old NPC/Monster stuff.
  update_old(dt)
  -- Check promises.
  promises:update()
  -- Modules.
  starPounds.moduleUpdate(dt)
end

function uninit()
  starPounds.moduleUninit()
  uninit_old()
end
