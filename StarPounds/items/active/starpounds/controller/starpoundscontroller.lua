require "/scripts/vec2.lua"
require "/scripts/util.lua"

local shared = getmetatable ""
local starPounds = shared.starPounds

function buildActions()
  actions = {
    menu = {
      onClick = function(self, shiftHeld)
        player.interact("ScriptPane", {gui = {}, scripts = {"/metagui.lua"}, ui = "starpounds:main"})
      end
    },
    -- Lactate.
    lactate = {
      icon = "/items/active/starpounds/controller/icons/inventory_lactate.png",
      init = function(self)
        self.cooldown = 0
        self.cooldownTime = 0.1
        self.capacityFrames = 12
      end,

      update = function(self, dt, fireMode, isButtonHeld, shiftHeld)
        activeItem.setFacingDirection(starPounds.mcontroller.movingDirection)

        local breasts = starPounds.moduleFunc("breasts", "get") or {type = "milk", fullness = 0}
        local cursor = "empty"
        if breasts.fullness >= 1 then
          cursor = "full"
        elseif breasts.fullness > 0 then
          cursor = "capacity_"..math.floor(breasts.fullness * self.capacityFrames)
        end

        activeItem.setCursor(string.format("/cursors/starpoundsmilk.cursor:%s_%s", breasts.type, cursor))

        if self.cooldown > 0 then
          self.cooldown = math.max(0, self.cooldown - dt)
        end

        if isButtonHeld and self.cooldown == 0 then
          starPounds.moduleFunc("breasts", "lactate", math.random(5, 10)/10)
          self.cooldown = self.cooldownTime
        end
      end
    },
    -- Milk types.
    breastMilk = {onClick = function(self, shiftHeld)
      starPounds.moduleFunc("breasts", "setMilkType", "milk")
    end},
    breastChocolate = {onClick = function(self, shiftHeld)
      if starPounds.moduleFunc("skills", "has", "breastChocolate") then
        starPounds.moduleFunc("breasts", "setMilkType", "starpoundschocolateliquid")
      end
    end},
    breastHoney = {onClick = function(self, shiftHeld)
      if starPounds.moduleFunc("skills", "has", "breastHoney") then
        starPounds.moduleFunc("breasts", "setMilkType", "bees_liquidhoney")
      end
    end},
    -- Vore actions.
    voreEat = {
      icon = "/items/active/starpounds/controller/icons/inventory_voreEat.png",
      init = function(self)
        self.range = config.getParameter("range", 2.5)
        self.querySize = config.getParameter("querySize", 0.5)
        self.readyEmote = config.getParameter("readyEmote", "Happy")
        self.cooldownFrames = 8
        self.cursorType = "pred"
        self.wasValid = false
        self.emoteActive = false
        self.cooldown = 0
        self.eatOptions = {particles = true}

        self.syncCooldown = function() self.cooldown = starPounds.moduleFunc("pred", "cooldown") end
        starPounds.events:on("pred:eatEntity", self.syncCooldown)
        starPounds.events:on("pred:bite", self.syncCooldown)
        starPounds.events:on("pred:entityEscape", self.syncCooldown)
      end,

      update = function(self, dt, fireMode, isButtonHeld, shiftHeld)
        local aimPosition = activeItem.ownerAimPosition()
        local aimAngle, aimDirection = activeItem.aimAngleAndDirection(0, aimPosition)
        activeItem.setFacingDirection(aimDirection)

        if self.cooldown > 0 then
          self.cooldown = math.max(0, self.cooldown - (dt / starPounds.getStat("voreCooldown")))
        end

        if shiftHeld then
          if shiftHeld then
            activeItem.setCursor(string.format("/cursors/starpoundsvore.cursor:release%s", canRelease() and "_valid" or ""))
            return
          end
        end

        local target = activeItem.ownerAimPosition()
        local valid = not world.getProperty("nonCombat") and starPounds.moduleFunc("pred", "eatNearby", target, self.range - (starPounds.currentSize.yOffset or 0), self.querySize, self.eatOptions, true)
        local safe = (valid and valid[3]) and "safe_" or ""
        self.cursorType = (valid and valid[1]) and (valid[2] and "pred_"..safe.."valid" or "pred_"..safe.."nearby") or "pred"

        if self.readyEmote ~= "none" then
          if self.cursorType:find("valid") and self.cooldown == 0 then
            activeItem.emote(self.readyEmote)
            self.emoteActive = true
          elseif self.emoteActive then
            activeItem.emote("Idle")
            self.emoteActive = false
          end
        end

        local readyPercent = 1 - (self.cooldown / starPounds.moduleFunc("pred", "cooldownTime"))
        local frameIndex = math.min(math.floor(readyPercent * self.cooldownFrames), self.cooldownFrames - 1)
        local frameSuffix = (self.cooldown > 0) and ("_" .. frameIndex) or ""
        activeItem.setCursor(string.format("/cursors/starpoundsvore.cursor:%s%s", self.cursorType, frameSuffix))
      end,

      onClick = function(self, shiftHeld)
        -- Release.
        if shiftHeld then
          starPounds.moduleFunc("pred", "release")
          return
        end

        if self.cooldown == 0 then
          local target = getVoreTargetPosition(self)
          local valid = not world.getProperty("nonCombat") and starPounds.moduleFunc("pred", "eatNearby", target, self.range - (starPounds.currentSize.yOffset or 0), self.querySize, self.eatOptions)

          if (valid and valid[1]) then
            starPounds.moduleFunc("pred", "cooldownStart")
            self.cooldown = starPounds.moduleFunc("pred", "cooldownTime")
          end
        end
      end,

      uninit = function(self)
        starPounds.events:off("pred:eatEntity", self.syncCooldown)
        starPounds.events:off("pred:bite", self.syncCooldown)
        starPounds.events:off("pred:entityEscape", self.syncCooldown)
        if self.emoteActive then activeItem.emote("Idle") end
        activeItem.setCursor()
      end
    },
    voreEatSafe = {
      icon = "/items/active/starpounds/controller/icons/inventory_voreEatSafe.png",
      init = function(self, ...)
        actions.voreEat.init(self)
        self.eatOptions.noDamage = true
      end,
      update = function(self, dt, fireMode, isButtonHeld, shiftHeld)
        actions.voreEat.update(self, dt, fireMode, isButtonHeld, shiftHeld)
      end,
      onClick = function(self, shiftHeld) actions.voreEat.onClick(self, shiftHeld) end,
      uninit = function(self) actions.voreEat.uninit(self) end
    },
    voreEatUnsafe = {
      icon = "/items/active/starpounds/controller/icons/inventory_voreEatUnsafe.png",
      init = function(self)
        actions.voreEat.init(self)
        self.eatOptions.unsafe = true
      end,
      update = function(self, dt, fireMode, isButtonHeld, shiftHeld)
        actions.voreEat.update(self, dt, fireMode, isButtonHeld, shiftHeld)
      end,
      onClick = function(self, shiftHeld) actions.voreEat.onClick(self, shiftHeld) end,
      uninit = function(self) actions.voreEat.uninit(self) end
    },
    vorePrey = {
      icon = "/items/active/starpounds/controller/icons/inventory_vorePrey.png",
      init = function(self)
        self.range = config.getParameter("range", 2.5)
        self.querySize = config.getParameter("querySize", 0.5)
        self.monsterBehaviors = root.assetJson("/scripts/starpounds/modules/pred.config:monsterBehaviors")
      end,

      isTargetPred = function(self, target)
        if not target or target == activeItem.ownerEntityId() then return false end

        local targetType = world.entityTypeName(target)
        if world.entityType(target) == "monster" then
          local scriptCheck = contains(root.monsterParameters(targetType).scripts or {}, "/scripts/starpounds/loaders/monster.lua")
          local parameters = root.monsterParameters(targetType)
          local behaviorCheck = parameters.behavior and contains(self.monsterBehaviors, parameters.behavior) or false
          if parameters.starPounds_options and parameters.starPounds_options.disablePred then return false end
          if not (scriptCheck or behaviorCheck) then
            return false
          end
        elseif world.entityType(target) == "npc" then
          if not contains(root.npcConfig(targetType).scripts or {}, "/scripts/starpounds/loaders/npc.lua") then return false end
          if world.getNpcScriptParameter(target, "starPounds_options", {}).disablePred then return false end
        end

        return not world.lineTileCollision(world.entityMouthPosition(target), world.entityPosition(activeItem.ownerEntityId()), {"Null", "Block", "Dynamic", "Slippery"})
      end,

      findValidTarget = function(self)
        if not starPounds.isEnabled() or starPounds.hasOption("disablePrey") or world.getProperty("nonCombat") then
          return nil
        end

        local mouthPosition = starPounds.mcontroller.mouthPosition
        if starPounds.currentSize.yOffset then
          mouthPosition = vec2.add(mouthPosition, {0, starPounds.currentSize.yOffset})
        end

        local aimPosition = activeItem.ownerAimPosition()

        if world.magnitude(mouthPosition, aimPosition) > (self.range + self.querySize) then
          return nil
        end

        local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), self.range - self.querySize - (starPounds.currentSize.yOffset or 0))
        local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
        local entities = world.entityQuery(targetPosition, self.querySize, {order = "nearest", includedTypes = {"player", "npc", "monster"}, withoutEntityId = activeItem.ownerEntityId()}) or {}

        for _, target in ipairs(entities) do
          if self:isTargetPred(target) then
            return target
          end
        end
        return nil
      end,

      update = function(self, dt, fireMode, isButtonHeld, shiftHeld)
        local aimPosition = activeItem.ownerAimPosition()
        local aimAngle, aimDirection = activeItem.aimAngleAndDirection(0, aimPosition)
        activeItem.setFacingDirection(aimDirection)

        local validTarget = self:findValidTarget()
        activeItem.setCursor(validTarget and "/cursors/starpoundsvore.cursor:prey_valid" or "/cursors/starpoundsvore.cursor:prey")
      end,

      onClick = function(self, shiftHeld)
        local validTarget = self:findValidTarget()
        if validTarget then
          world.sendEntityMessage(validTarget, "starPounds.pred.eat", activeItem.ownerEntityId(), {ignoreSkills = true, ignoreCapacity = true, ignoreEnergyRequirement = true, energyMultiplier = 0})
        end
      end,

      uninit = function(self)
        activeItem.setCursor()
      end
    },
    voreBite = {
      icon = "/items/active/starpounds/controller/icons/inventory_voreBite.png",
      init = function(self)
        self.range = config.getParameter("range", 2.5)
        self.querySize = config.getParameter("querySize", 0.5)
        self.cooldownFrames = 8
        self.cooldown = 0
      end,

      update = function(self, dt, fireMode, isButtonHeld, shiftHeld)
        local aimPosition = activeItem.ownerAimPosition()
        local aimAngle, aimDirection = activeItem.aimAngleAndDirection(0, aimPosition)
        activeItem.setFacingDirection(aimDirection)

        if self.cooldown > 0 then
          self.cooldown = math.max(0, self.cooldown - (dt / starPounds.getStat("voreCooldown")))
        end

        local readyPercent = 1 - (self.cooldown / starPounds.moduleFunc("pred", "cooldownTime"))
        local frameIndex = math.min(math.floor(readyPercent * self.cooldownFrames), self.cooldownFrames - 1)
        local frameSuffix = (self.cooldown > 0) and ("_" .. frameIndex) or ""

        activeItem.setCursor(string.format("/cursors/starpoundsvore.cursor:bite%s", frameSuffix))
      end,

      onClick = function(self, shiftHeld)
        if self.cooldown == 0 and not starPounds.hasOption("disablePredBite") then
          local target = getVoreTargetPosition(self)
          starPounds.moduleFunc("pred", "cooldownStart")
          starPounds.moduleFunc("pred", "bite", target, true)
          self.cooldown = starPounds.moduleFunc("pred", "cooldownTime")
        end
      end,

      uninit = function(self)
        activeItem.setCursor()
      end
    },
    -- Sounds.
    soundBelch = {
      icon = "/items/active/starpounds/controller/icons/inventory_belch.png",
      init = function(self)
        self.cooldownFrames = 8
        self.cooldown = 0
        self.cooldownTime = 0.5
      end,

      update = function(self, dt, fireMode, isButtonHeld, shiftHeld)
        activeItem.setFacingDirection(starPounds.mcontroller.movingDirection)

        if self.cooldown > 0 then
          self.cooldown = math.max(0, self.cooldown - dt)
        end

        local readyPercent = 1 - (self.cooldown / self.cooldownTime)
        local frameIndex = math.min(math.floor(readyPercent * self.cooldownFrames), self.cooldownFrames - 1)
        local frameSuffix = (self.cooldown > 0) and ("_" .. frameIndex) or ""

        activeItem.setCursor(string.format("/cursors/starpoundssound.cursor:sound%s", frameSuffix))
      end,

      onClick = function(self, shiftHeld)
        if self.cooldown == 0 then
          starPounds.moduleFunc("belch", "belch", 0.75, nil, false)
          self.cooldown = self.cooldownTime
        end
      end
    },
    soundRumble = {
      icon = "/items/active/starpounds/controller/icons/inventory_rumble.png",
      init = function(self)
        self.cooldownFrames = 8
        self.cooldown = 0
        self.cooldownTime = 0.35
      end,

      update = function(self, dt, fireMode, isButtonHeld, shiftHeld)
        activeItem.setFacingDirection(starPounds.mcontroller.movingDirection)

        if self.cooldown > 0 then
          self.cooldown = math.max(0, self.cooldown - dt)
        end
        -- Loops when held.
        if isButtonHeld and self.cooldown == 0 then
          starPounds.moduleFunc("sound", "play", shiftHeld and "digest" or "rumble", 0.75, (math.random(90,110)/100))
          self.cooldown = self.cooldownTime
        end

        local readyPercent = 1 - (self.cooldown / self.cooldownTime)
        local frameIndex = math.min(math.floor(readyPercent * self.cooldownFrames), self.cooldownFrames - 1)
        local frameSuffix = (self.cooldown > 0) and ("_" .. frameIndex) or ""

        activeItem.setCursor(string.format("/cursors/starpoundssound.cursor:sound%s", frameSuffix))
      end
    },

    default = {
      icon = string.format("/items/active/starpounds/controller/icons/inventory_default%s.png", config.getParameter("twoHanded", true) and "" or "_oneHanded"),
      init = function(self) end,
      update = function(self, dt, fireMode, isButtonHeld, shiftHeld) end,
      onClick = function(self, shiftHeld) end,
      uninit = function(self) end
    }
  }
end

function canRelease()
  local canRelease = false
  local stomachEntities = starPounds.moduleFunc("data", "get", "stomachEntities")
  for preyIndex = #stomachEntities, 1, -1 do
    local prey = stomachEntities[preyIndex]
    if not prey.noRelease then
      canRelease = true
      break
    end
  end
  return canRelease
end

function getVoreTargetPosition(self)
  local mouthPosition = {starPounds.mcontroller.mouthPosition[1], starPounds.mcontroller.mouthPosition[2] + (starPounds.currentSize.yOffset or 0)}
  local aimPosition = activeItem.ownerAimPosition()
  local posMag = math.min(world.magnitude(mouthPosition, aimPosition), self.range - self.querySize - (starPounds.currentSize.yOffset or 0))
  local distVec = world.distance(aimPosition, mouthPosition)
  local distMag = world.magnitude(aimPosition, mouthPosition) + 0.001

  return {
    mouthPosition[1] + (distVec[1] / distMag * math.max(posMag, 0)),
    mouthPosition[2] + (distVec[2] / distMag * math.max(posMag, 0))
  }
end

function init()
  activeItem.setHoldingItem(false)

  self.click = true
  shared.starPoundsRadialMenu = nil
  shared.starPoundsRadialMenuClose = nil
  shared.starPoundsRadialMenuOpen = false

  storage.action = storage.action or "default"
  buildActions()
  equipAction(storage.action)
end

function equipAction(actionName)
  local actionTemplate = actions[actionName] or actions["default"]
  -- Clean up old module if it exists.
  if self.action and type(self.action.uninit) == "function" then
    self.action:uninit()
  end

  local newAction = {}
  for key, value in pairs(actionTemplate) do
    newAction[key] = value
  end

  self.action = newAction
  storage.action = actionName
  -- Init.
  if type(self.action.init) == "function" then
    self.action:init()
  end
  -- Set the icon.
  if self.action.icon then
    activeItem.setInventoryIcon(self.action.icon)
  end
end

function update(dt, fireMode, shiftHeld)
  -- Default just opens the menu. (Converts left clicks into right clicks)
  if storage.action == "default" and fireMode == "primary" then
    fireMode = "alt"
  end
  -- self.click prevents the menu/actions rapidly spamming.
  if fireMode == "none" then
    self.click = false
  end

  checkInterface()

  if shared.starPoundsRadialMenuOpen then
    -- Clear any custom cursors while the menu is open.
    activeItem.setCursor()
    -- Close the menu on right click.
    if not self.click and fireMode == "alt" then
      self.click = true
      shared.starPoundsRadialMenuClose = true
    end
  else
    local isPrimaryHeld = (fireMode == "primary")
    if self.action and type(self.action.update) == "function" then
      self.action:update(dt, fireMode, isPrimaryHeld, shiftHeld)
    end

    if not self.click then
      if fireMode == "primary" then
        self.click = true
        if self.action and type(self.action.onClick) == "function" then
          self.action:onClick(shiftHeld)
        end
      elseif fireMode == "alt" then
        self.click = true
        local offset
        if starPounds.openStarbound then
          offset = vec2.div(vec2.sub(camera.worldToScreen(activeItem.ownerAimPosition()), camera.worldToScreen(camera.position())), interface.scale())
        end

        openRadialInterface(offset)
      end
    end
  end
end

function openRadialInterface(offset)
  shared.starPoundsRadialMenu = nil

  local menuConfig = root.assetJson("/interface/scripted/starpounds/radialmenu/radialmenu.config")
  menuConfig.options = {
    { name = "menu", pretty = "Menu", instant = true, weight = 3, description = "Open the\n^#ccbbff;StarPounds^reset;\nmenu", icon = "/items/active/starpounds/controller/icons/menu.png" },
    {
      name = "voreMenu",
      pretty = "Vore", description = "Bind vore\nactions", icon = "/items/active/starpounds/controller/icons/voreMenu.png",
      options = {
        { name = "voreEat", pretty = "Eat", weight = 1, description = "Hold ^#ccbbff;[Shift]^reset; to\nrelease prey", icon = "/items/active/starpounds/controller/icons/voreEat.png" },
        { name = "voreEatUnsafe", pretty = "Fatal", title = "Eat: ^#ed7272;Fatal^reset;", weight = 0.5, description = "^#ccbbff;Eat^reset;, but ignores\nskills for safe\nvore", colour = {237, 114, 114, 200}, icon = "/items/active/starpounds/controller/icons/voreEat.png?border=1;ed7272bb;00000000" },
        { name = "voreBite", pretty = "Bite", description = string.format("^#ccbbff;%g^reset; damage", string.format("%.2f", starPounds.moduleFunc("pred", "biteDamage"))), icon = "/items/active/starpounds/controller/icons/voreBite.png" },
        { name = "vorePrey", pretty = "Feed", description = "Become prey for\nothers", icon = "/items/active/starpounds/controller/icons/vorePrey.png" },
        { name = "voreEatSafe", pretty = "Endo", title = "Eat: ^#72ed72;Endo^reset;", weight = 0.5, description = "^#ccbbff;Eat^reset;, but will\nnever digest\nprey", colour = {114, 237, 114, 200}, icon = "/items/active/starpounds/controller/icons/voreEat.png?border=1;72ed72bb;00000000" }
      }
    },
    {
      name = "breastsMenu",
      pretty = "Breasts", description = "Bind breast\nactions", icon = "/items/active/starpounds/controller/icons/breastsMenu.png",
      options = compact(
        { name = "lactate", pretty = "Lactate", weight = 1 + (starPounds.moduleFunc("skills", "has", "breastChocolate") and 1 or 0) + (starPounds.moduleFunc("skills", "has", "breastHoney") and 1 or 0), icon = "/interface/scripted/starpounds/main/icons/skills/breastEfficiency.png" },
        starPounds.moduleFunc("skills", "has", "breastHoney") and { name = "breastHoney", pretty = "Honey", description = "Set your milk\ntype", instant = true, keepOpen = true, colour = {247, 166, 25, 200}, icon = "/interface/scripted/starpounds/main/icons/skills/breastHoney.png" } or nil,
        starPounds.moduleFunc("skills", "has", "breastChocolate") and { name = "breastChocolate", pretty = "Chocolate", description = "Set your milk\ntype", instant = true, keepOpen = true, colour = {117, 70, 26, 200}, icon = "/interface/scripted/starpounds/main/icons/skills/breastChocolate.png" } or nil,
        { name = "breastMilk", pretty = "Milk", description = "Set your milk\ntype", instant = true, keepOpen = true, icon = "/interface/scripted/starpounds/main/icons/skills/breastMilk.png", colour = {151, 221, 247, 200} }
      )
    },
    {
      name = "soundMenu",
      pretty = "Sound", description = "Bind sound\nactions", icon = "/items/active/starpounds/controller/icons/soundMenu.png",
      options = {
        { name = "soundBelch", pretty = "Belch", icon = "/items/active/starpounds/controller/icons/soundBelch.png" },
        { name = "soundRumble", pretty = "Rumble", description = "Hold ^#ccbbff;[Shift]^reset; to\nchange sound", icon = "/items/active/starpounds/controller/icons/soundRumble.png" },
      }
    }
  }

  if offset then
    menuConfig.gui.panefeature = {
      type = "panefeature",
      anchor = "center",
      offset = offset
    }
  end

  activeItem.interact("ScriptPane", menuConfig, activeItem.ownerEntityId())
end

function checkInterface()
  local interfaceData = shared.starPoundsRadialMenu

  if interfaceData and interfaceData.pressed then
    if interfaceData.selection ~= "cancel" then
      if interfaceData.instant then
        local targetModule = actions[interfaceData.selection]
        if targetModule and type(targetModule.onClick) == "function" then
          targetModule:onClick(false)
        end
      else
        equipAction(interfaceData.selection)
      end
    end
    shared.starPoundsRadialMenu = nil
    self.click = true
  end
end

function uninit()
  shared.starPoundsRadialMenuClose = true
  if self.action and self.action.uninit then self.action:uninit() end
end

function compact(...)
  local clean = {}
  for i = 1, select('#', ...) do
    local val = select(i, ...)
    if val ~= nil then clean[#clean+1] = val end
  end
  return clean
end
