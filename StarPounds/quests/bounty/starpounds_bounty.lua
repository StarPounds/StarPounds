function init()
  require(config.getParameter("starpounds_script", "/quests/bounty/bounty.lua"))
  init()
  -- Hook participant events for digestion check.
  message.setHandler(quest.questId()..".participantEvent", function(_, _, uniqueId, eventName, ...)
    storage.event[eventName] = true
    if eventName == "starPoundsEaten" then
      storage.event["escape"] = nil
      storage.event["captured"] = true
      storage.event["clueGiven"] = true
    end
  end)

  message.setHandler(quest.questId()..".fail", function(_, _, text)
    if storage.event["starPoundsEaten"] then
      storage.event["escape"] = nil
      storage.event["captured"] = true
      storage.event["clueGiven"] = true
      quest.complete()
    else
      quest.fail()
    end
  end)

  starPoundsHook()
end

function starPoundsHook()
  -- Oh lawd he angi.
  local radioMessage_old = radioMessage
  function radioMessage(text, portraitType)
    if not portraitType and storage.event["starPoundsEaten"] then
      portraitType = "angry"
    end
    return radioMessage_old(text, portraitType)
  end

  -- Less rewards if you digest the target.
  local modifyQuestEvents_old = modifyQuestEvents
  function modifyQuestEvents(status, money, rank, credits)
    local mult = nil
    if storage.event["starPoundsEaten"] and status == "Captured" then
      mult = config.getParameter("digestedMoneyMultiplier", 0.5)
      money = math.floor(money * mult)
      rank = math.floor(rank * config.getParameter("digestedRankMultiplier", 1))
      credits = math.floor(credits * config.getParameter("digestedCreditsMultiplier", 1))
    end

    modifyQuestEvents_old(status, money, rank, credits)

    if mult then
      local newBountyEvents = player.getProperty("newBountyEvents", {})
      local thisQuestEvents = newBountyEvents[quest.questId()]
      if thisQuestEvents then
        thisQuestEvents.digested = true
        newBountyEvents[quest.questId()] = thisQuestEvents
        player.setProperty("newBountyEvents", newBountyEvents)
      end
    end
  end

  -- Wrap completion function.
  local questComplete_old = questComplete
  function questComplete()
    local quests = quest.questArcDescriptor().quests
    local isFinalStep = (quest.questId() == quests[#quests].questId)

    if storage.event["starPoundsEaten"] then
      if not isFinalStep then
        local eatenClueMessages = config.getParameter("digestedClueRadioMessages") or {
          "Did you just digest the informant?! Lucky for you, I'm pickin' up a distress ping from their communicator inside your gut, carry on!"
        }
        storage.completeMessage = util.randomFromList(eatenClueMessages)
      end
    end

    questComplete_old()
    -- Update the completion popup.
    if isFinalStep and storage.event["starPoundsEaten"] then
      local rewards = quest.parameters().rewards
      local reducedRank = math.floor(rewards.rank * config.getParameter("digestedRankMultiplier", 1))

      local textConfig = config.getParameter("generatedText.complete")
      local textPool = (textConfig and textConfig.starPoundsEaten) or {
        "Did you just EAT <bounty.name>?! That's not what \"take 'em in\" means, partner!\n\nYou can still come by the Peacekeeper Station to collect your rewards, but I'm docking your pay for this!",
        "I 'spose justice has been 'literally' served, but we don't accept belches as proof of capture!\n\nReward ain't as large as if you bought 'em in, but swing on by the Peacekeeper Station!"
      }

      local tags = util.generateTextTags(quest.parameters().text.tags)
      tags.bountyPoints = reducedRank
      quest.setCompletionText(sb.replaceTags(util.randomFromList(textPool), tags))
    end
  end
end
