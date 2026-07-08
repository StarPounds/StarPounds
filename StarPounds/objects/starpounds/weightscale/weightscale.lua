require "/scripts/messageutil.lua"
function init()
  units = root.assetJson("/scripts/starpounds/starpounds.config:settings.units")
  script.setUpdateDelta(1)
end

function update(dt)
  promises:update()
end

function onInteraction(args)
  promises:add(world.sendEntityMessage(args.sourceId, "starPounds.data.get"), function(data)
    promises:add(world.sendEntityMessage(args.sourceId, "starPounds.options.get", "weightUnit"), function(weightUnit)
      object.say(string.format(config.getParameter("interactMessage"), string.format("%g", math.floor(data.weight * units[weightUnit][2] * 100 + 0.5)/100), units[weightUnit][1]))
    end)
  end)
end
