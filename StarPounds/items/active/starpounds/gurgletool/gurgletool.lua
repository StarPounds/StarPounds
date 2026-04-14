function init()
  activeItem.setHoldingItem(false)
end

function activate(fireMode, shiftHeld)
  world.sendEntityMessage(activeItem.ownerEntityId(), "starPounds.sound.play", shiftHeld and "digest" or "rumble", 0.75, (math.random(90,110)/100))
end
