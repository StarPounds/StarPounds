-- param entity
function tryEatEntity(args, board)
  if args.entity == nil then return false end
  return starPounds.moduleFunc("pred", "eat", args.entity, {triggerPreyCooldown = true, ignoreEnergyRequirement = true, energyMultiplier = 0})
end

-- param entity
function hasEatenEntity(args, board)
  if args.entity == nil then return #storage.starPounds.stomachEntities ~= 0 end
  local eatenEntity = false
  if storage.starPounds then
    for _, prey in ipairs(storage.starPounds.stomachEntities) do
      if prey.id == args.entity then
        eatenEntity = true
        break
      end
    end
  end
  return eatenEntity
end

function movementMultiplier(args, board)
  return true, {number = (starPounds.currentSize and starPounds.currentSize.movementMultiplier or 1)}
end

function fullStomach(args, board)
  return starPounds.stomach.contents > starPounds.stomach.capacity
end

function isEaten(args, board)
  return (storage.starPounds.pred ~= nil) or status.uniqueStatusEffectActive("starpoundsvore")
end

function supersizeOffset(args, board)
  return offsetPosition({
    position = args.position,
    offset = {0, -(starPounds.currentSize and starPounds.currentSize.yOffset or 0)}
  }, board)
end
