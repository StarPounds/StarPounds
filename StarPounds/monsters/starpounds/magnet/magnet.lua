require "/scripts/util.lua"
require "/scripts/vec2.lua"
function init()
  if config.getParameter("uniqueId") then
    monster.setUniqueId(config.getParameter("uniqueId"))
    self.owner = config.getParameter("owner")
    self.forceRegions = ControlMap:new(config.getParameter("forceRegions", {}))
  end

  script.setUpdateDelta(10)
end

function update(dt)
  if self.owner and world.entityExists(self.owner) then
    local ownerPosition = world.entityPosition(self.owner)
    mcontroller.setPosition(ownerPosition)
    self.forceRegions:clear()
    self.forceRegions:setActive("magnet")
    setPhysicsForces()
  else
    status.setResource("health", 0)
  end
end

function shouldDie()
  return not status.resourcePositive("health") or self.dead
end

function uninit()
  self.owner = nil
  status.setResource("health", 0)
end

function setRange(range)
  self.forceRegions.controlValues.magnet.innerRadius = math.min(range, 3)
  self.forceRegions.controlValues.magnet.outerRadius = range
end

function setPhysicsForces()
  local regions = util.map(self.forceRegions:values(), function(region)
    if region.type == "RadialForceRegion" then
      region.center = vec2.add(mcontroller.position(), region.center)
    elseif region.type == "DirectionalForceRegion" then
      if region.rectRegion then
        region.rectRegion = rect.translate(region.rectRegion, mcontroller.position())
      elseif region.polyRegion then
        region.polyRegion = poly.translate(region.polyRegion, mcontroller.position())
      end
    end

    return region
  end)

  monster.setPhysicsForces(regions)
end
