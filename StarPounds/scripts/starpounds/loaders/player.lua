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
  local speciesTrait = starPounds.traits[starPounds.getSpecies()] or starPounds.traits.default
  for _, skill in ipairs(speciesTrait.skills or jarray()) do
    starPounds.moduleFunc("skills", "forceUnlock", skill[1], skill[2])
  end
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
