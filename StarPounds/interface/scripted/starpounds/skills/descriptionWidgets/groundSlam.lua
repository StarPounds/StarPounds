descriptionFunctions.groundSlam = descriptionFunctions.groundSlam or function(descriptionWidget)
  descriptionWidget.onClick = function()
    if contains(player.availableTechs(), "doublejump") then
      player.makeTechAvailable("starpoundsgroundslam")
      player.enableTech("starpoundsgroundslam")
      player.equipTech("starpoundsgroundslam")
    else
      widget.playSound("/sfx/interface/clickon_error.ogg")
    end
  end
end
