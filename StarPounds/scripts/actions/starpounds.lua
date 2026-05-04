-- param entity
function starpoundsObjectDirection(args, board)
  if args.entity == nil or not world.entityExists(args.entity) then return false end
  local direction = world.getObjectParameter(args.entity, "direction", "right") == "left" and -1 or 1

  return true, {number = direction}
end
