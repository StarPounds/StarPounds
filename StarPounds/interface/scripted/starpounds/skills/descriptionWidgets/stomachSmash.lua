descriptionFunctions.stomachSmash = descriptionFunctions.stomachSmash or function(descriptionWidget)
  descriptionWidget.onClick = function()
    if contains(player.availableTechs(), "dash") then
      player.makeTechAvailable("starpoundsstomachsmash")
      player.enableTech("starpoundsstomachsmash")
      player.equipTech("starpoundsstomachsmash")
    else
      widget.playSound("/sfx/interface/clickon_error.ogg")
    end
  end
end
