descriptionFunctions.stomachSmash = descriptionFunctions.stomachSmash or function(descriptionWidget)
  descriptionWidget.onClick = function()
    local availableTechs = player.availableTechs()
    if contains(availableTechs, "dash") or contains(availableTechs, "sb_dash") then
      player.makeTechAvailable("starpoundsstomachsmash")
      player.enableTech("starpoundsstomachsmash")
      player.equipTech("starpoundsstomachsmash")
    else
      widget.playSound("/sfx/interface/clickon_error.ogg")
    end
  end
end
