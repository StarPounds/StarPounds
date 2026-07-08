descriptionFunctions.breastHoney = descriptionFunctions.breastHoney or function(descriptionWidget)
  descriptionWidget.onClick = function()
    starPounds.moduleFunc("breasts", "setMilkType", "bees_liquidhoney")
    starPounds.moduleFunc("skills", "upgrade", "breastMilk", 0)
  end
end
