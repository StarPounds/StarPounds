local oSB = starPounds.module:new("oSB")

function oSB:init()
  self.offset = 0
  self.interactRadius = root.assetJson("/player.config:interactRadius")
  self.lactateBindTimer = self.data.lactateBindTime
  self.damageTeam = world.entityDamageTeam(entity.id())
  self.handSlots = {"primary", "alt"}
  self.selectedSlot = nil
  self.consumableCache = {}
  self.notConsumableCache = {}

  self.openStarbound = root.assetJson("/player.config:genericScriptContexts").OpenStarbound or false
  starPounds.moduleFunc("options", "oSB")
  -- Load up the toolbar if we have oSB isntalled.
  if self.openStarbound and not self.loadedToolbar then
    player.interact("ScriptPane", "/interface/scripted/starpounds/toolbar/toolbar.config")
    self.loadedToolbar = true
  end
end

function oSB:hasOpenStarbound()
  return self.openStarbound
end

function oSB:update(dt)
  if not self.hasOpenStarbound then return end

  self:toggleBind()
  self:menuBinds()
  self:belchBind()
  self:drinkBind()
  self:voreBinds(dt)
  self:lactateBind(dt)

  -- Extended interaction radius at supersize.
  self.offset = starPounds.currentSize.yOffset or 0
  if self.offset ~= self.offsetOld then
    player.setInteractRadius(self.interactRadius + math.round(math.abs(self.offset), 2))
    self.offsetOld = self.offset
  end

  -- Update food items in the player's hotbar.
  if starPounds.swapSlotItem then self.selectedSlot = nil return end -- Action slots are ignored while we have something in the cursor.
  local slot = player.selectedActionBarSlot()
  if type(slot) ~= "number" then self.selectedSlot = nil return end -- Don't run on the essential slots.

  -- Only update when we change slots/groups. Slot only returns an array, so less data/overhead (Probably).
  local newSelectedSlot = slot..sb.print(player.actionBarSlotLink(slot, "primary") ~= nil)..player.actionBarGroup()
  if newSelectedSlot == self.selectedSlot then
    return
  end
  self.selectedSlot = newSelectedSlot
  -- Checks for primary/alt.
  for _, slotType in ipairs(self.handSlots) do
    local item = player[slotType.."HandItem"]()
    if item and not self.notConsumableCache[item.name] then
      if self.consumableCache[item.name] or (root.itemType(item.name) == "consumable") then
        -- Little cache for repeated itemType lookups.
        if not self.consumableCache[item.name] then self.consumableCache[item.name] = true end
        if not item.parameters.starpounds_effectApplied then
          local updated = starPounds.moduleFunc("food", "updateItem", item)
          if updated then
            player.setItem(player.actionBarSlotLink(slot, slotType), updated)
          end
        end
      elseif not self.notConsumableCache[item.name] then
        self.notConsumableCache[item.name] = true
      end
    end
  end
  -- Make the player invisible to enemies while eaten.
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
    local belchPitch = 1
    local addMomentum = false
    starPounds.moduleFunc("belch", "belch", belchVolume, belchPitch, addMomentum)
  end
end
-- Eat/Regurgitate/Bite entities.
function oSB:voreBinds(dt)
  if input.bindDown("starpounds", "voreEat") then
    if player.isAdmin() or starPounds.moduleFunc("pred", "cooldown") == 0 then
      local mouthPosition = starPounds.mcontroller.mouthPosition
      local aimPosition = player.aimPosition()
      local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), self.data.voreRange - self.data.voreQuerySize - self.offset)
      local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
      local success = starPounds.moduleFunc("pred", "eatNearby", targetPosition, self.data.voreRange - self.offset, self.data.voreQuerySize, {particles = true})
      if success then starPounds.moduleFunc("pred", "cooldownStart") end
    end
  end

  if input.bindDown("starpounds", "voreRegurgitate") then
    starPounds.moduleFunc("pred", "release")
  end

  if input.bindDown("starpounds", "voreBite") then
    if player.isAdmin() or starPounds.moduleFunc("pred", "cooldown") == 0 then
      local mouthPosition = starPounds.mcontroller.mouthPosition
      local aimPosition = player.aimPosition()
      local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), self.data.voreRange - self.data.voreQuerySize - self.offset)
      local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
      starPounds.moduleFunc("pred", "cooldownStart")
      starPounds.moduleFunc("pred", "bite", targetPosition, true)
    end
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
-- Chat message hook.
function oSB:addChatMessage(text, conf)
  if not starPounds.hasOption("disableChatMessages") then
    chat.addMessage(text, conf)
  end
end

starPounds.modules.oSB = oSB
