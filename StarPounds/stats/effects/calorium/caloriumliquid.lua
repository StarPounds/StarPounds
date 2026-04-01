require "/scripts/messageutil.lua"

function init()
  script.setUpdateDelta(5)
  self.progressStep = effect.getParameter("progressStep", 0.02)
  self.tickTime = effect.getParameter("tickTime", 1)
  self.tickTimeStep = effect.getParameter("tickTimeStep", 0)
  self.tickTimeMinimum = effect.getParameter("tickTimeMinimum", self.tickTime)
  self.tickTimer = self.tickTime
  self.minimumLiquid = root.assetJson("/player.config:statusControllerSettings.minimumLiquidStatusEffectPercentage")
  self.caloriumFat = root.assetJson("/scripts/starpounds/modules/liquid.config:liquids.starpoundscaloriumliquid").food.fatLiquid

  animator.setSoundVolume("digest", 0.75)
  animator.setSoundPitch("digest", 2/(1 + self.tickTime))

  starPounds = getmetatable ''.starPounds
end

function update(dt)
  -- Check promises.
  promises:update()
  if mcontroller.liquidPercentage() < self.minimumLiquid then return end
  if world.entityType(entity.id()) == "npc" or (starPounds and starPounds.isEnabled()) then
    wasActive = true
    self.tickTimer = self.tickTimer - dt
    if self.tickTimer <= 0 then
      local bounds = translateRect(mcontroller.boundBox(), mcontroller.position())
      local consumedLiquid = 0
      local liquids = world.liquidAlongLine({bounds[1], bounds[2]}, {bounds[3], bounds[2]})
      local filteredLiquids = jarray()
      for _, liquid in ipairs(liquids) do
        if root.liquidName(liquid[2][1]) == "starpoundscaloriumliquid" then
          filteredLiquids[#filteredLiquids + 1] = liquid
        end
      end

      table.sort(filteredLiquids, function (left, right)
        return right[2][2] < left[2][2]
      end)
      shuffle(filteredLiquids)

      for _, liquid in ipairs(filteredLiquids) do
        consumedLiquid = math.floor((consumedLiquid + world.destroyLiquid(liquid[1])[2]) * 10 + 0.5)/10
        if consumedLiquid >= 1 then break end
      end

      if consumedLiquid > 0 then
        self.tickTime = math.max(self.tickTime - self.tickTimeStep, self.tickTimeMinimum)
        self.tickTimer = self.tickTime

        promises:add(world.sendEntityMessage(entity.id(), "starPounds.getData"), function(starPounds)
          increaseWeightProgress(starPounds.weight, self.progressStep * consumedLiquid)
          world.sendEntityMessage(entity.id(), "starPounds.gainWeight", self.caloriumFat * consumedLiquid, true)
        end)

        animator.setSoundPitch("digest", 2/(1 + self.tickTime))
        animator.playSound("digest")
      else
        self.tickTime = effect.getParameter("tickTime", 1)
      end
    end
  else
    effect.expire()
  end
end

function translateRect(rectangle, offset)
  return {
    rectangle[1] + offset[1], rectangle[2] + offset[2],
    rectangle[3] + offset[1], rectangle[4] + offset[2]
  }
end

function shuffle(tbl)
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end
