-- Old functions. (we call these in functons we replace)-- Old functions. (we call these in functons we replace)
local init_old = init or function() end
local update_old = update or function(dt) end
local uninit_old = uninit or function() end

function starPoundsInit()
  -- Monsters usually load this from a behaviour script, so we can't just hook into init since it's already run.
  require "/scripts/starpounds/starpounds.lua"
  -- Used in functions for detection.
  starPounds.type = "monster"
  -- Base module.
  starPounds.moduleInit("base")
  -- Setup message handlers
  starPounds.messageHandlers()
  -- Reload whenever the entity loads in/beams/etc.
  starPounds.parseSkills()
  starPounds.moduleInit({"entity", "monster", "vore"})
  starPounds.weightMultiplier = 1
end

-- Dirty.
if root then
  starPoundsInit()
else
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
