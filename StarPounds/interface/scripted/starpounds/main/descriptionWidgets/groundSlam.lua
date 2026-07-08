descriptionFunctions.groundSlam = descriptionFunctions.groundSlam or function(descriptionWidget)
  descriptionWidget.onClick = function()
    local availableTechs = player.availableTechs()
    if contains(availableTechs, "doublejump") or contains(availableTechs, "sb_doublejump") then
      player.makeTechAvailable("starpoundsgroundslam")
      player.enableTech("starpoundsgroundslam")
      player.equipTech("starpoundsgroundslam")
    else
      widget.playSound("/sfx/interface/clickon_error.ogg")
    end
  end
end
