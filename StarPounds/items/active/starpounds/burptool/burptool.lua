function init()
  activeItem.setHoldingItem(false)
end

function activate(fireMode, shiftHeld)
  local starPounds = getmetatable ''.starPounds
  if starPounds then
    starPounds.moduleFunc("belch", "belch", 0.75, starPounds.moduleFunc("belch", "pitch"), false)
  end
end
