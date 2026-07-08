descriptionFunctions.throgSphere = descriptionFunctions.throgSphere or function(descriptionWidget)
  descriptionWidget.onClick = function()
    local availableTechs = player.availableTechs()
    if contains(availableTechs, "distortionsphere") or contains(availableTechs, "sb_morphball") then
      player.makeTechAvailable("starpoundsthrogsphere")
      player.enableTech("starpoundsthrogsphere")
      player.equipTech("starpoundsthrogsphere")
    else
      widget.playSound("/sfx/interface/clickon_error.ogg")
    end
  end
end
