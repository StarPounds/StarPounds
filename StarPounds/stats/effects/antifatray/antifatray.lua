require "/scripts/messageutil.lua"

function update(dt)
  -- Check promises.
  promises:update()
  mcontroller.controlModifiers({
    speedModifier = 0.9,
    airJumpModifier = 0.9
  })
  animator.setLightActive("glow", true)
  border = 64 + math.floor(math.sin(os.clock()*15)*64 + 0.5)
  effect.setParentDirectives("?saturation=-25?brightness=15?multiply=EEFFBB?fade=EEFFBB;0.2?border=2;EEFFBB"..hexConverter(border)..";DDFF9900")
  -- Lose 50lb/sec
  world.sendEntityMessage(entity.id(), "starPounds.size.loseWeight", 50 * dt)
end

function uninit()
end

function math.round(num, numDecimalPlaces)
  local format = string.format("%%.%df", numDecimalPlaces or 0)
  return tonumber(string.format(format, num))
end

-- Adapted from: http://lua-users.org/lists/lua-l/2004-09/msg00054.html. Converts decimal numbers into hexadecimal.
function hexConverter(input)
  local hexCharacters = '0123456789abcdef'
  local output = ''
  while input > 0 do
      local mod = math.fmod(input, 16)
      output = string.sub(hexCharacters, mod+1, mod+1) .. output
      input = math.floor(input / 16)
  end
  if output == '' then output = '0' end
  if string.len(output) == 1 then output = '0'..output end
  return output
end
