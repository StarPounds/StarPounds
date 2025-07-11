local oSB = starPounds.module:new("oSB")

function oSB:init()
  self.offset = 0
  self.interactRadius = root.assetJson("/player.config:interactRadius")
  self.lactateBindTimer = self.data.lactateBindTime
  self.damageTeam = world.entityDamageTeam(entity.id())
end

function oSB:update(dt)
  -- If we have input access.
  if input then
    self:toggleBind()
    self:menuBinds()
    self:belchBind()
    self:drinkBind()
    self:voreBinds(dt)
    self:lactateBind(dt)
  end

  if player.setInteractRadius then
    self.offset = starPounds.currentSize.yOffset or 0
    if self.offset ~= self.offsetOld then
      player.setInteractRadius(self.interactRadius + math.round(math.abs(self.offset), 2))
      self.offsetOld = self.offset
    end
  end

  if storage.starPounds.pred and player.setDamageTeam then
    player.setDamageTeam(starExtensions and {type = "ghostly", team = storage.starPounds.damageTeam.team} or "ghostly")
  end
end

function oSB:uninit()
  if player.setInteractRadius then
    player.setInteractRadius(self.interactRadius)
  end
end

-- Toggle the mod.
function oSB:toggleBind()
  if input.bindDown("starpounds", "toggle") then
    starPounds.toggleEnable()
  end
end
-- Menu time.
function oSB:menuBinds()
  for _, menu in ipairs({"menu", "skills", "effects", "options"}) do
    if input.bindDown("starpounds", menu.."Menu") then
      player.interact("ScriptPane", {gui = {}, scripts = {"/metagui.lua"}, ui = "starpounds:"..menu})
    end
  end
end
-- Burpy.
function oSB:belchBind()
  if input.bindDown("starpounds", "belch") then
    local belchVolume = 0.75
    local addMomentum = false
    starPounds.belch(belchVolume, starPounds.belchPitch(), addMomentum)
  end
end
-- Eat/Regurgitate entities.
function oSB:voreBinds(dt)
  if input.bindDown("starpounds", "voreEat") then
    if player.isAdmin() or starPounds.moduleFunc("pred", "cooldown") == 0 then
      local mouthPosition = starPounds.mcontroller.mouthPosition
      local aimPosition = player.aimPosition()
      local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), self.data.voreRange - self.data.voreQuerySize - self.offset)
      local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
      local success = starPounds.moduleFunc("pred", "eatNearby", targetPosition, self.data.voreRange - self.offset, self.data.voreQuerySize)
      if success then starPounds.moduleFunc("pred", "cooldownStart") end
    end
  end

  if input.bindDown("starpounds", "voreRegurgitate") then
    starPounds.moduleFunc("pred", "release")
  end
end

-- Lactate.
function oSB:lactateBind(dt)
  if input.bind("starpounds", "lactate") then
    if input.bindDown("starpounds", "lactate") then
      starPounds.moduleFunc("breasts", "lactate", math.random(5, 10)/10)
    end
    -- Lactate constantly after holding for 1 second.
    self.lactateBindTimer = math.max(self.lactateBindTimer - dt, 0)
    if self.lactateBindTimer == 0 then
      starPounds.moduleFunc("breasts", "lactate", math.random(5, 10)/10)
      self.lactateBindTimer = self.data.lactateInterval
    end
  else
    self.lactateBindTimer = self.data.lactateBindTime
  end
end

-- Drink.
function oSB:drinkBind()
  -- Only run this if we have auto drinking disabled.
  if not starPounds.hasOption("disableDrinking") then return end
  if input.bind("starpounds", "drink") then
    starPounds.moduleFunc("drinking", "drink")
  end
end

starPounds.modules.oSB = oSB
