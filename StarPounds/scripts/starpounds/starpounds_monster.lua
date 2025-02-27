-- Dummy empty function so we save memory.
local function nullFunction()
end
-- Old functions. (we call these in functons we replace)
local update_old = update or nullFunction
local uninit_old = uninit or nullFunction
-- Monsters load this from a behaviour script, so we can't just hook into init since it's already run.
require "/scripts/starpounds/starpounds.lua"
storage.starPounds = sb.jsonMerge(starPounds.baseData, storage.starPounds)
-- This is stupid, but prevents 'null' data being saved.
getmetatable(storage.starPounds).__nils = {}
-- Used in functions for detection.
starPounds.type = "monster"
starPounds.moduleInit("base")
-- Setup message handlers
starPounds.messageHandlers()
-- Reload whenever the entity loads in/beams/etc.
starPounds.statCache = {}
starPounds.statCacheTimer = starPounds.settings.statCacheTimer
starPounds.parseSkills()
starPounds.parseStats()
starPounds.accessoryModifiers = starPounds.getAccessoryModifiers()
starPounds.moduleInit({"entity", "monster", "vore"})
starPounds.effectInit()
starPounds.setWeight(storage.starPounds.weight)

starPounds.events:on("main:statChange", function()
  starPounds.updateStats(true)
end)

function update(dt)
  -- Run old NPC/Monster stuff.
  update_old(dt)
  -- Check promises.
  promises:update()
  -- Reset stat cache.
  starPounds.statCacheTimer = math.max(starPounds.statCacheTimer - dt, 0)
  if starPounds.statCacheTimer == 0 then
    starPounds.statCache = {}
    starPounds.statCacheTimer = starPounds.settings.statCacheTimer
  end
  -- Modules.
  starPounds.moduleUpdate(dt)
end

function uninit()
  starPounds.moduleUninit()
  uninit_old()
end
