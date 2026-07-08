descriptionFunctions.voreTool = descriptionFunctions.voreTool or function(descriptionWidget)
  descriptionWidget.onClick = function()
    if not player.hasItem("voretool") then
      if not player.swapSlotItem() then
        player.setSwapSlotItem("voretool")
      else
        player.giveItem("voretool")
      end
    else
      widget.playSound("/sfx/interface/clickon_error.ogg")
    end
  end
end
