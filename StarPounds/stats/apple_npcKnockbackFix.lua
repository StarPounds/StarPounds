if not apple_appliedKnockbackFix then
  local apple_oldApplyDamageRequest = applyDamageRequest
  function applyDamageRequest(damageRequest)
    local result = apple_oldApplyDamageRequest(damageRequest)
    if not result or #result == 0 then return result end

    local knockbackFactor = (1 - status.stat("grit"))
    local momentum = knockbackMomentum(vec2.mul(damageRequest.knockbackMomentum, knockbackFactor))

    if status.resourcePositive("health") and vec2.mag(momentum) > status.stat("knockbackThreshold") then
      -- Set pathing to something that fails.
      local bounds = mcontroller.boundBox()
      local pos = vec2.add(mcontroller.position(), {0, 10})
      mcontroller.controlPathMove(pos, false, {
        returnBest = false, mustEndOnGround = false, maxDistance = 0,
        swimCost = 1, dropCost = 1, boundBox = bounds, droppingBoundBox = bounds,
        standingBoundBox = bounds, smallJumpMultiplier = 1, jumpDropXMultiplier = 1,
        enableWalkSpeedJumps = false, nableVerticalJumpAirControl = false, maxFScore = 0,
        maxNodesToSearch = 1, maxLandingVelocity = 0, liquidJumpCost = 1
      })
    end

    return result
  end
  apple_appliedKnockbackFix = true
end
