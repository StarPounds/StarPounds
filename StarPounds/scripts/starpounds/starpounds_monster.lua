-- Old functions. (we call these in functons we replace)-- Old functions. (we call these in functons we replace)
local init_old = init or function() end
local update_old = update or function(dt) end
local uninit_old = uninit or function() end

function starPoundsInit()
  -- Monsters usually load this from a behaviour script, so we can't just hook into init since it's already run.
  require "/scripts/starpounds/starpounds.lua"
  storage.starPounds = sb.jsonMerge(starPounds.baseData, storage.starPounds)
  -- This is stupid, but prevents 'null' data being saved.
  getmetatable(storage.starPounds).__nils = {}
  -- Used in functions for detection.
  starPounds.type = "monster"
  -- Delete json metadata so we don't store nils.
  setmetatable(storage.starPounds, nil)
  -- Base module.
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
  starPounds.weightMultiplier = 1

  starPounds.events:on("main:statChange", function(trace)
    starPounds.updateStats(true)
  end)
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
