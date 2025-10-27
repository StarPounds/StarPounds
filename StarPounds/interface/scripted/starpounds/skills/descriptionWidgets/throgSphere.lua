descriptionFunctions.throgSphere = descriptionFunctions.throgSphere or function(descriptionWidget)
  descriptionWidget.onClick = function()
    if contains(player.availableTechs(), "distortionsphere") then
      player.makeTechAvailable("starpoundsthrogsphere")
      player.enableTech("starpoundsthrogsphere")
      player.equipTech("starpoundsthrogsphere")
    else
      widget.playSound("/sfx/interface/clickon_error.ogg")
    end
  end
end
