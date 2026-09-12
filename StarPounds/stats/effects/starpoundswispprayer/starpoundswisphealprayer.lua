function init()
  --Instantiate variables to use in the update function
  ourId = entity.id()
  --These variables come from the status effect file's `scriptConfig`
  range = config.getParameter("range", 8) --8 is the default value if it can't find `range` in the scriptConfig
  statusEffect = config.getParameter("statusEffect")
  animator.setParticleEmitterOffsetRegion("prayer", mcontroller.boundBox())
  animator.setParticleEmitterActive("prayer", config.getParameter("particles", true))
end

function update(dt)
  --Get a list of entities of type `creature` within `range` of our current position
  local targets = world.entityQuery(mcontroller.position(), range, {includedTypes = {"creature"}})
  --Iterate through each entry in the list of targets
  for _, targetId in pairs(targets) do
    --Check if the target is something we CANNOT damage (therefore not an enemy)
    if not world.entityCanDamage(ourId, targetId) then
  if world.lineCollision(mcontroller.position(), world.entityPosition(targetId), {"slippery", "dynamic", "block"}) then
  end
      --Give them the effect via entity messaging
      world.sendEntityMessage(targetId, "applyStatusEffect", statusEffect)
    end
  end
end