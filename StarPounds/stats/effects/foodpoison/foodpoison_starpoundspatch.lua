require "/scripts/messageutil.lua"

local init_old = init or function() end
local update_old = update or function() end

function init()
  init_old()
  starPoundsCheckTimer = 0
  starPoundsCheck()
end

function update(dt)
  starPoundsCheckTimer = math.max(starPoundsCheckTimer - dt, 0)
  if starPoundsCheckTimer == 0 then
    starPoundsCheck()
  end

  promises:update()
  update_old(dt)
end

function starPoundsCheck()
  -- Check if we have the prevention skill.
  promises:add(world.sendEntityMessage(entity.id(), "starPounds.hasSkill", "foodPoisonImmunity"), function(hasSkill)
    if hasSkill then effect.expire() end
  end)
end
