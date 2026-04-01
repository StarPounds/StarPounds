require "/scripts/messageutil.lua"
starPounds = getmetatable ''.starPounds

function init()
  local buttonIcon = string.format("%s.png", starPounds.isEnabled() and "enabled" or "disabled")
  enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
end

function update()
  if isAdmin ~= admin() then
    isAdmin = admin()
    weightDecrease:setVisible(isAdmin)
    weightIncrease:setVisible(isAdmin)
    barPadding:setVisible(not isAdmin)
  end

  -- Check promises.
  promises:update()
end

function skills:onClick()
  player.interact("ScriptPane", {gui = {}, scripts = {"/metagui.lua"}, ui = "starpounds:skills"})
  pane.dismiss()
end

function effects:onClick()
  player.interact("ScriptPane", {gui = {}, scripts = {"/metagui.lua"}, ui = "starpounds:effects"})
  pane.dismiss()
end

function options:onClick()
  player.interact("ScriptPane", {gui = {}, scripts = {"/metagui.lua"}, ui = "starpounds:options"}) --string.format("starpounds:options%s", (player.isAdmin() or starPounds.hasOption("admin")) and "Admin" or "")})
  pane.dismiss()
end

function weightDecrease:onClick()
  local sizes = starPounds.moduleFunc("size", "sizes")
  local progress = (starPounds.weight - starPounds.currentSize.weight)/((sizes[starPounds.currentSizeIndex + 1] and sizes[starPounds.currentSizeIndex + 1].weight or starPounds.moduleFunc("size", "maximumWeight")) - starPounds.currentSize.weight)
  local targetWeight = sizes[math.max(starPounds.currentSizeIndex - 1, 1)].weight
  local targetWeight2 = sizes[starPounds.currentSizeIndex].weight
  starPounds.moduleFunc("size", "setWeight", metagui.checkShift() and 0 or (targetWeight + (targetWeight2 - targetWeight) * progress))
end

function weightIncrease:onClick()
  local sizes = starPounds.moduleFunc("size", "sizes")
  local progress = math.max(0.01, (starPounds.weight - starPounds.currentSize.weight)/((sizes[starPounds.currentSizeIndex + 1] and sizes[starPounds.currentSizeIndex + 1].weight or starPounds.moduleFunc("size", "maximumWeight")) - starPounds.currentSize.weight))
  local targetWeight = sizes[starPounds.currentSizeIndex + 1] and sizes[starPounds.currentSizeIndex + 1].weight or starPounds.moduleFunc("size", "maximumWeight")
  local targetWeight2 = sizes[starPounds.currentSizeIndex + 2] and sizes[starPounds.currentSizeIndex + 2].weight or starPounds.moduleFunc("size", "maximumWeight")
  starPounds.moduleFunc("size", "setWeight", metagui.checkShift() and starPounds.moduleFunc("size", "maximumWeight") or (targetWeight + (targetWeight2 - targetWeight) * progress))
end

function enable:onClick()
  local buttonIcon = string.format("%s.png", starPounds.toggleEnable() and "enabled" or "disabled")
  enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
end

function reset:onClick()
  local confirmLayout = sb.jsonMerge(root.assetJson("/interface/confirmation/resetstarpoundsconfirmation.config"), {
    title = "StarPounds Quick Menu",
    icon = "/interface/scripted/starpounds/menu/icon.png",
    images = {
      portrait = world.entityPortrait(player.id(), "full")
    }
  })
  promises:add(player.confirm(confirmLayout), function(response)
    if response then
      promises:add(world.sendEntityMessage(player.id(), "starPounds.reset"), function()
        local buttonIcon = "disabled.png"
        enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
      end)
    end
  end)
end

function reset:onClick()
  local confirmLayout = sb.jsonMerge(root.assetJson("/interface/confirmation/resetstarpoundsconfirmation.config"), {
    title = "StarPounds Quick Menu",
    icon = "/interface/scripted/starpounds/menu/icon.png",
    images = {
      portrait = world.entityPortrait(player.id(), "full")
    }
  })
  promises:add(player.confirm(confirmLayout), function(response)
    if response then
      promises:add(world.sendEntityMessage(player.id(), "starPounds.reset"), function()
        local buttonIcon = "disabled.png"
        enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
      end)
    end
  end)
end

function log:onClick()
  local data = starPounds.moduleFunc("data", "get") or player.getProperty("starPoundsBackup", {})
  sb.logInfo(sb.print(data))
end

function admin()
  return (player.isAdmin() or starPounds.hasOption("admin")) or false
end
