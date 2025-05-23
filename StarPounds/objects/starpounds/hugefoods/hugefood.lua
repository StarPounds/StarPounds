require "/scripts/messageutil.lua"
function init()
  storage.stage = storage.stage or config.getParameter("stage", 0)
  storage.bites = storage.bites or config.getParameter("bites", 0)

  self.stages = config.getParameter("stages", 5)
  self.bitesPerStage = config.getParameter("bitesPerStage", 4)
  self.food = config.getParameter("food", 1000)/(self.bitesPerStage * self.stages)
  self.fat = config.getParameter("fat", 0)/(self.bitesPerStage * self.stages)
  self.strainedThresholds = root.assetJson("/scripts/starpounds/starpounds.config:settings.thresholds.strain")

  self.experienceBonus = root.assetJson("/scripts/starpounds/modules/food.config:experienceBonus")
  self.rarity = config.getParameter("rarity", "common"):lower()
  self.bonusExperience = self.food * (self.experienceBonus[self.rarity] or 0)

  object.setInteractive(true)

  animator.setGlobalTag("stage", storage.stage)
end

function update(dt)
  promises:update()
end

function onInteraction(args)
  promises:add(world.sendEntityMessage(args.sourceId, "starPounds.getStomach"), function(stomach)
    promises:add(world.sendEntityMessage(args.sourceId, "starPounds.hasSkill", "wellfedProtection"), function(wellfedProtection)
      if stomach.fullness >= self.strainedThresholds.starpoundsstomach and not wellfedProtection then
        return
      elseif stomach.fullness >= self.strainedThresholds.starpoundsstomach3 then
        return
      end
      animator.burstParticleEmitter("bite")
      animator.playSound("bite")

      world.sendEntityMessage(args.sourceId, "starPounds.feed", self.food, "hugeFood")
      world.sendEntityMessage(args.sourceId, "starPounds.feed", self.fat, "fatFood")
      world.sendEntityMessage(args.sourceId, "starPounds.feed", self.bonusExperience, "bonusExperience")
      world.sendEntityMessage(args.sourceId, "starPounds.playSound", "swallow", 0.75)

      storage.bites = storage.bites + 1
      if storage.bites >= self.bitesPerStage then
        storage.stage = storage.stage + 1
        storage.bites = 0
      end
      if storage.stage >= self.stages then
        object.smash()
      end

      animator.setGlobalTag("stage", storage.stage)
    end)
  end)
end

function onNpcPlay(npcId)
  onInteraction({sourceId = npcId})
end

function die()
  if storage.stage < self.stages then
    world.spawnItem(config.getParameter("objectName"), entity.position(), 1, {stage = storage.stage, bites = storage.bites})
  end
end
