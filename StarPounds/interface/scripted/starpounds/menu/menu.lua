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
  if metagui.checkShift() then
    starPounds.moduleFunc("size", "setWeight", 0)
  else
    starPounds.moduleFunc("size", "setSize", starPounds.currentSizeIndex - 1, math.min(starPounds.progress, 0.99))
  end
end

function weightIncrease:onClick()
  if metagui.checkShift() then
    starPounds.moduleFunc("size", "setWeight", starPounds.moduleFunc("size", "maximumWeight"))
  else
    starPounds.moduleFunc("size", "setSize", starPounds.currentSizeIndex + 1, math.max(starPounds.progress, 0.01))
  end
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
