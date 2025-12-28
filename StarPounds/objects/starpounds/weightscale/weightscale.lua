require "/scripts/messageutil.lua"

function update(dt)
  promises:update()
end

function onInteraction(args)
  promises:add(world.sendEntityMessage(args.sourceId, "starPounds.getData"), function(data)
    local weightMult = 1
    local weightUnit = "kg"
    local isPounds = data.options and data.options.useImperial
    if isPounds then
      weightMult = 2.20462234
      weightUnit = "lb"
    end
    object.say(string.format(config.getParameter("interactMessage"), math.floor(data.weight * weightMult + 0.5), weightUnit))
  end)
end
