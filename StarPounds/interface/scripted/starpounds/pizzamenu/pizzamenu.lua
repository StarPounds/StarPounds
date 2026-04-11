require "/scripts/util.lua"
require "/scripts/messageutil.lua"
require "/scripts/staticrandom.lua"
require "/scripts/vec2.lua"
starPounds = getmetatable ''.starPounds

function init()
  menu = root.assetJson("/interface/scripted/starpounds/pizzamenu/menu.config")
  order = {}
  orderCost = 0
  time = world.timeOfDay()
  orderRefreshTimer = 1

  starPounds.pizzaPdaOpen = true

  local randomFeeNames = {
    "Cosmic Rush Hour Fee", "Space Whale Season", "Pizza De-boning", "Payment Processing Fee", "Fee Avoidance Fee",
    "Pepperoni Insurance", "Pirate Insurance", "Premium Cardboard Box", "Fee R&D", "Mantid Evasion Fee",
    "Mandatory Tip", "Service Fee", "Placeholder Fee", "Pineapple Removal", "Asteroid Avoidance",
    "Interstellar Toll", "Cheese Recovery", "Free Delivery Fee", "No Coupon Fee", "Blubberbutt Tribute"
  }
  randomFeeName = randomFeeNames[math.random(1, #randomFeeNames)]

  rareFees = {
    {id = "grace", name = "^#2862e9;« Cute Employee Fee", beaconColours = {splash = {{40, 98, 233, 196}}}, npcType = "starpoundspizzaapple", price = 250},
    {id = "mini", name = "^yellow;^#c4855d; Deer Trainee", beaconColours = {splash = {{193, 133, 93, 196}}}, npcType = "starpoundspizzamini", npcData = {teleportVore = true}, price = -250}
  }
  local randomSeed = math.floor(os.time()/300)

  if sb.staticRandomDouble(randomSeed, string.format("rareFee.%s.%s", player.worldId(), starPounds and starPounds.lastOrdered or "")) < (25/100) then
    rareFee = randomFromList(rareFees, randomSeed, "rareFee")
  end

  isAdmin = player.isAdmin()
  hasRareFee = rareFee ~= nil
  updateOrderButtons()

  for menuType, menuItems in pairs(menu) do
    for i, menuItem in ipairs(menuItems) do
      local parent = _ENV[menuType.."Menu"]
      local parentLayout = parent:addChild({type = "panel", style = "concave", expandMode = {1, 0}, mode = "vertical", size = {75, 24}, position = {0, 25 * (i - 1)}})
      parentLayout:addChild({type = "itemSlot", item = menuItem, glyph = menuType..".png", position = {3, 3}})
      local spinnerLayout = parentLayout:addChild({type = "layout", mode = "manual", size = {74, 24}})
      spinnerLayout:addChild({type = "image", file = "itemCount.png", position = {34, 6}})
      spinnerLayout:addChild({type = "label", id = menuItem.."Amount", align = "center", text = "x0", size = {24, 24}, position = {34, 8}})
      spinnerLayout:addChild({type = "iconButton", id = menuItem.."Decrease", position = {26, 7},
        image = "/interface/pickleft.png",
        hoverImage = "/interface/pickleftover.png",
        pressImage = "/interface/pickleftover.png?border=1;00000000;00000000?crop=1;2;9;11"
      }).onClick = function() changeItemAmount(menuItem, -(metagui.checkShift() and 5 or 1)) end
      spinnerLayout:addChild({type = "iconButton", id = menuItem.."Increase", position = {58, 7},
        image = "/interface/pickright.png",
        hoverImage = "/interface/pickrightover.png",
        pressImage = "/interface/pickrightover.png?border=1;00000000;00000000?crop=1;2;9;11"
      }).onClick = function() changeItemAmount(menuItem, metagui.checkShift() and 5 or 1) end
    end
  end
end

function update()
  orderRefreshTimer = math.max((orderRefreshTimer) - script.updateDt(), 0)
  if orderRefreshTimer == 0 then
    refreshOrderCost()
    time = world.timeOfDay()
    orderRefreshTimer = 1
  end

  local primaryItem = player.primaryHandItem()
  local altItem = player.altHandItem()
  local holdingPda = primaryItem and (primaryItem.name == "starpoundspizzapda") or (altItem and (altItem.name == "starpoundspizzapda") or false)

  if not (primaryItem or altItem) then
    pane.dismiss()
    return
  end


  if not holdingPda and not (primaryItem.name == "geode" and primaryItem.parameters and primaryItem.parameters.scripts and primaryItem.parameters.scripts[1] == "/sys/metagui/helper/shiftstub.lua") then
    pane.dismiss()
    return
  end

  if isAdmin ~= player.isAdmin() then
    isAdmin = player.isAdmin()
    updateOrderButtons()
  end

  hasRareFee = rareFee ~= nil
  if hasRareFee ~= (rareFee ~= nil) then
    updateOrderButtons()
  end

  if couldOrder ~= canOrder() then
    buyOverlay:setVisible(not canOrder())
    couldOrder = canOrder()
  end
  -- Check promises.
  promises:update()
end

function cycleFee:onClick()
  rareFeeIndex = ((rareFeeIndex or 0) % (#rareFees)) + 1
  rareFee = rareFees[rareFeeIndex]
  hasRareFee = rareFee ~= nil
  refreshOrderCost()
  updateOrderButtons()
end

function removeFee:onClick()
  rareFee = nil
  rareFeeIndex = nil
  hasRareFee = rareFee ~= nil
  refreshOrderCost()
  updateOrderButtons()
end


function updateOrderButtons()
  local hasOrder = false
  for _, count in pairs(order) do if count > 0 then hasOrder = true break end end

  local cycleButton = isAdmin
  local removeButton = hasOrder and hasRareFee

  cycleFee:setVisible(cycleButton)
  paddingCycle:setVisible(not cycleButton)

  removeFee:setVisible(removeButton)
  paddingRemove:setVisible(not removeButton)
end

function changeItemAmount(menuItem, amount)
  local currentAmount = order[menuItem] or 0
  order[menuItem] = util.clamp((order[menuItem] or 0) + amount, 0, 99)
  _ENV[menuItem.."Amount"]:setText(string.format("x%s", order[menuItem]))
  if order[menuItem] == 0 then
    if _ENV[menuItem.."Ordered"] then
      _ENV[menuItem.."Ordered"]:delete()
    end
  elseif currentAmount == 0 then
    local orderCount = 0
    for _ in pairs(order) do orderCount = orderCount + 1 end
    local parentLayout = orderList:addChild({type = "panel", id = menuItem.."Ordered", style = "concave", expandMode = {1, 0}, mode = "vertical", size = {80, 24}})
    parentLayout:addChild({type = "itemSlot", id = menuItem.."OrderedCount", item = {name = menuItem, count = order[menuItem]}, position = {3, 3}})
    parentLayout:addChild({type = "image", file = "pixels.png", position = {30, 10}})
    parentLayout:addChild({type = "label", id = menuItem.."OrderedCountLabel", align = "left", text = order[menuItem] * root.itemConfig(menuItem).config.price, size = {48, 24}, position = {42, 8}})
    parentLayout:addChild({type = "iconButton", id = menuItem.."Remove", position = {80, 7},
    image = "/interface/x.png",
    hoverImage = "/interface/xhover.png",
    pressImage = "/interface/xpress.png"
  }).onClick = function() changeItemAmount(menuItem, -math.huge) end
  else
    _ENV[menuItem.."OrderedCount"]:setItem({name = menuItem, count = order[menuItem]})
    _ENV[menuItem.."OrderedCountLabel"]:setText(order[menuItem] * root.itemConfig(menuItem).config.price)
  end

  refreshOrderCost()
end

function refreshOrderCost()
  orderCost = 0
  local foodValue = 0
  for menuItem, menuItemCount in pairs(order) do
    orderCost = orderCost + order[menuItem] * root.itemConfig(menuItem).config.price
    foodValue = foodValue + (root.itemConfig(menuItem).config.foodValue or 0) * menuItemCount
  end
  subtotalLeft:setText(orderCost > 0 and "Subtotal" or "")
  subtotalRight:setText(orderCost > 0 and orderCost or "")

  local position = world.entityPosition(player.id())
  local breathable = world.breathable(position)
  local liquid = world.liquidAt(position)
  local ocean = world.oceanLevel(position) ~= 0
  local tile = world.material(position, "foreground")
  local underground = world.underground(position)

  local onShip = world.type() == "unknown"
  local onMoon = world.type() == "moon"
  local isLateNight = not onShip and ((time > 0.6) and (time < 0.8))
  local inOcean = (liquid and ocean)
  local inSpace = not (breathable or liquid or tile)
  local isUnderground = underground and not inOcean

  local locationalFees = {
    {id = "ship", name = "Ship Docking Fee", items = {}, price = onShip and (0.05 * orderCost) or 0},
    {id = "moon", name = "Ghostbuster Equipment Fee", items = {head = "starpoundshaldenhead", back = "oxygentank"}, price = onMoon and (0.5 * orderCost) or 0},
    {id = "space", name = "Astronaut Training Fee", items = {head = "starpoundshaldenhead", back = "oxygentank"}, price = inSpace and (0.25 * orderCost) or 0},
    {id = "ocean", name = "Scuba License Fee", items = {head = {name = "snorkelhead", count = 1, parameters = {colorIndex = 4}}, back = "oxygentank"}, price = inOcean and (0.25 * orderCost) or 0},
    {id = "underground", name = "Cave Mapping Fee", items = {head = {name = "mininghathead", count = 1, parameters = {colorIndex = 4}}}, price = isUnderground and (0.25 * orderCost) or 0}
  }

  locationalFee = {name = "Locational Fee", price = 0}
  for _, fee in ipairs(locationalFees) do
    if fee.price ~= 0 then
      locationalFee = fee
      break
    end
  end

  local fees = {
    {"Delivery Fee", (randomFeeName == "Free Delivery Fee" and 0 or 100)},
    {"Late Night Fee", isLateNight and (0.1 * orderCost) or 0},
    {"Location Hazard Fee", math.max(0, (world.threatLevel() - 1)) * 0.2 * orderCost},
    {randomFeeName, (randomFeeName == "Free Delivery Fee" and 100 or 0) + 0.2 * orderCost},
    locationalFee and {locationalFee.name, locationalFee.price} or {"-", 0},
    rareFee and {rareFee.name, rareFee.price} or {"-", 0},
    {"^red;ª Staff Replacement Fee", starPounds.modules.pizza:employeeFee()},
    {"^yellow; Couples Discount", (foodValue >= 210 and foodValue < 420) and -0.025 * orderCost or 0},
    {"^yellow; Family Discount", (foodValue >= 420 and foodValue < 1260) and -0.05 * orderCost or 0},
    {"^yellow; Party Discount", (foodValue >= 1260 and foodValue < 5040) and -0.075 * orderCost or 0},
    {"^yellow; Event Discount", (foodValue >= 5040) and -0.1 * orderCost or 0}
  }

  local feeStringLeft = ""
  local feeStringRight = ""
  if orderCost > 0 then
    for _, fee in ipairs(fees) do
      if math.floor(fee[2] + 0.5) ~= 0 then
        if feeStringLeft ~= "" then
          feeStringLeft = feeStringLeft.."\n"
          feeStringRight = feeStringRight.."\n"
        end
        feeStringLeft = string.format("%s^gray;%s", feeStringLeft, fee[1])
        feeStringRight = string.format("%s^gray;%d", feeStringRight, math.floor(fee[2] + 0.5))
        orderCost = orderCost + math.floor(fee[2] + 0.5)
      end
    end
  end
  feeListLeft:setText(feeStringLeft)
  feeListRight:setText(feeStringRight)
  orderTotal:setText(math.max(orderCost, 0))
  updateOrderButtons()
end

function canOrder()
  local hasOrder = false
  for _, count in pairs(order) do if count > 0 then hasOrder = true break end end
  if not hasOrder then return false end
  if not isAdmin and (orderCost > player.currency("money")) then return false end
  return true
end

function order:onClick()
  if canOrder() then
    local playerPosition = world.entityPosition(player.id())

    local locations = {}
    for _, i in ipairs({-5, -4, -3, 3, 4, 5}) do
      local pos = vec2.add(playerPosition, {i, 0})
      if not world.lineTileCollision(playerPosition, pos, {"Null", "Block", "Dynamic"}) then
        locations[#locations + 1] = pos
      end
    end
    if #locations == 0 then locations[1] = playerPosition end

    local overrideItems = {}

    local npcType
    local beaconColours
    local npcData
    if rareFee then
      npcType = rareFee.npcType
      npcData = rareFee.npcData or {}
      beaconColours = rareFee.beaconColours
      for itemType, itemCount in pairs(rareFee.extraItems or {}) do
        order[itemType] = (order[itemType] or 0) + itemCount
      end
      overrideItems = sb.jsonMerge(overrideItems, rareFee.items or {})
    end

    if locationalFee.items then
      overrideItems = sb.jsonMerge(overrideItems, locationalFee.items)
    end

    starPounds.lastOrdered = os.time()

    world.spawnStagehand(locations[math.random(1, #locations)], "starpoundspizzaspawner", {
      npcType = npcType,
      npcData = npcData,
      overrideItems = overrideItems,
      order = order,
      beaconColours = beaconColours,
      target = player.uniqueId(),
    })

    if not isAdmin then
      player.consumeCurrency("money", math.max(orderCost, 0))
    end

    starPounds.modules.pizza:boughtPizza()
    widget.playSound("/sfx/objects/coinstack_medium1.ogg")
    pane.dismiss()
  end
end

function uninit()
  starPounds.pizzaPdaOpen = nil
end
