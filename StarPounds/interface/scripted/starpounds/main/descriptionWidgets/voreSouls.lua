descriptionFunctions.voreSouls = descriptionFunctions.voreSouls or function(descriptionWidget)
  local soulLabel = descriptionWidget.children[2]
  local soulRefresh = descriptionWidget.children[3]
  local starPounds = getmetatable ''.starPounds

  local function updateSoulCount()
    local soulCount = 0
    local effect = starPounds.moduleFunc("effects", "get", "voreSouls")
    if effect then
      soulCount = effect.level
    end

    soulLabel:setText(soulCount)
  end

  soulRefresh.onClick = updateSoulCount

  updateSoulCount()
end
