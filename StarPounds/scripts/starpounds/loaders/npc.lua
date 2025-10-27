-- Old functions.
local init_old = init or function() end
local update_old = update or function(dt) end
local uninit_old = uninit or function() end
-- Run on load.
function init()
  -- Run old NPC/Monster stuff.
  init_old()
  require "/scripts/starpounds/starpounds.lua"
  -- Used in functions for detection.
  starPounds.type = "npc"
  -- Setup message handlers
  starPounds.messageHandlers()
  -- Reload whenever the entity loads in/beams/etc.
  starPounds.moduleInit({"base", "entity", "humanoid", "npc", "vore"})
  -- Setup species traits.
  storage.starPounds.overrideSpecies = config.getParameter("starPounds_overrideSpecies")
  local speciesTrait = starPounds.traits[starPounds.getSpecies()] or starPounds.traits.default
  for _, skill in ipairs(speciesTrait.skills or jarray()) do
    starPounds.moduleFunc("skills", "forceUnlock", skill[1], skill[2])
  end
end

function update(dt)
  -- Run old NPC/Monster stuff.
  update_old(dt)
  -- Check promises.
  promises:update()
  -- Modules.
  starPounds.moduleUpdate(dt)
  -- Dumb, but fixes the vanilla issue where stunned NPCs don't realise they're dead.
  -- Might make this separate fix later.
  self.die = self.die or (self.shouldDie and not status.resourcePositive("health")) or self.forceDie
end

function uninit()
  starPounds.moduleUninit()
  uninit_old()
end
