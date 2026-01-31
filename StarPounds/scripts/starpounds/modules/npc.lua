-- Underscore here since the NPC table exists.
local _npc = starPounds.module:new("npc")

function _npc:init()
  -- Set NPC specific trait.
  if not starPounds.getTrait() then
    starPounds.setTrait(config.getParameter("starPounds_trait"))
  end
  -- Initial skills and options.
  storage.starPounds.options = sb.jsonMerge(storage.starPounds.options, config.getParameter("starPounds_options", {}))
  if not storage.starPounds.parsedInitialSkills then
    local skills = config.getParameter("starPounds_skills", {})
    for k, v in pairs(skills) do
      local level = 0
      if type(v) == "table" then
        level = math.random(v[1], v[2])
      elseif type(v) == "number" then
        level = v
      end
      if level > 0 then
        skills[k] = jarray()
        skills[k][1] = level
        skills[k][2] = level
      else
        skills[k] = nil
      end
    end
    storage.starPounds.skills = sb.jsonMerge(storage.starPounds.skills, skills)
    storage.starPounds.parsedInitialSkills = true
    -- Triggers the minimumSize weight floor.
    local minimumSize = math.max(starPounds.moduleFunc("skills", "level", "minimumSize"), starPounds.moduleFunc("skills", "level", "softMinimumSize"), 0)
    starPounds.moduleFunc("size", "setWeight", starPounds.sizes[minimumSize + 1].weight)
  end
  self:setup()
  starPounds.moduleFunc("skills", "parse")
  -- Triggers aggro.
  message.setHandler("starPounds.notifyDamage", simpleHandler(damage))
  message.setHandler("starPounds.notifyDamage", simpleHandler(function(args)
    _ENV.self.damaged = true
    _ENV.self.board:setEntity("damageSource", args.sourceId)
  end))
  -- I hate it.
  self.setNpcItemSlot_old = setNpcItemSlot
  self.setNpcItemSlotCC_old = setNpcItemSlotCC or nullFunction
  setNpcItemSlot = function(...)
    self.setNpcItemSlot_old(...)
  end
  setNpcItemSlotCC = function(...)
    self.setNpcItemSlotCC_old(...)
  end
end

function _npc:update(dt)
  if storage.starPounds.enabled then
    if starPounds.currentSize.movementMultiplier == 0 then
      mcontroller.controlModifiers({
        movementSuppressed = true
      })
    end
  end
end

function _npc:setup()
  -- Dummy empty function so we save memory.
  local speciesData = starPounds.getSpeciesData(npc.species())
  entity.setDamageOnTouch = npc.setDamageOnTouch
  entity.setDamageTeam = npc.setDamageTeam
  entity.weight = speciesData.weight
  entity.foodType = speciesData.foodType
  -- Save default functions.
  npc.say_old = npc.say_old or npc.say
  notify_old = notify_old or notify
  openDoors_old = openDoors_old or openDoors
  closeDoors_old = closeDoors_old or closeDoors
  closeDoorsBehind_old = closeDoorsBehind_old or closeDoorsBehind
  preservedStorage_old = preservedStorage_old or preservedStorage
  -- Override default functions.
  npc.say = function(...) if not storage.starPounds.pred then npc.say_old(...) end end
  notify = function(...) if not storage.starPounds.pred then notify_old(...) end end
  closeDoorsBehind = function() if storage.starPounds.pred then closeDoorsBehind_old() end end
  openDoors = function(...) return storage.starPounds.pred and false or openDoors_old(...) end
  closeDoors = function(...) return storage.starPounds.pred and false or closeDoors_old(...) end
  preservedStorage = function()
    -- Grab old NPC stuff
    local preserved = preservedStorage_old()
    -- Add to preserved storage so it persists in crewmembers/bounties/etc.
    preserved.starPounds = storage.starPounds
    return preserved
  end
  -- Configurable prey treasure pool.
  entity.preyTreasure = sb.jsonMerge(starPounds.getSpeciesData(npc.species()).preyTreasure, config.getParameter("starPounds_preyTreasure"))
  -- No XP if disabled.
  if config.getParameter("starPounds_options.disableExperience") then
    entity.foodType = entity.foodType.."_noExperience"
  end
end

starPounds.modules.npc = _npc
