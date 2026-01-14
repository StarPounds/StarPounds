require "/scripts/messageutil.lua"

function init()
  target = nil
  object.setInteractive(true)

  message.setHandler("starpounds.treadmill.uninit", simpleHandler(function() target = nil end))
end

function update(dt)
  promises:update()
  if target and not world.entityExists(target) then
    target = nil
  end
end

function onInteraction(args)
  if not target then
    target = args.sourceId
    promises:add(world.sendEntityMessage(args.sourceId, "applyStatusEffect", "starpoundstreadmill", 1, entity.id()), function()
        world.sendEntityMessage(args.sourceId, "starpounds.treadmill.init", {object.direction() == 1 and 10/8 or 14/8, 28/8}, object.direction(), entity.id())
    end)
  elseif target == args.sourceId then
    world.sendEntityMessage(args.sourceId, "starpounds.treadmill.uninit")
    target = nil
  end
end
