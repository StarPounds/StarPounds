require "/scripts/messageutil.lua"

function update(dt)
  -- Check promises.
  promises:update()
  mcontroller.controlModifiers({
    speedModifier = 0.5,
    airJumpModifier = 0.5
  })
  world.sendEntityMessage(entity.id(), "starPounds.size.gainWeight", 50 * dt)
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
