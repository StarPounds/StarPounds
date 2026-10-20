local loadBountyData_old = loadBountyData
local showSummary_old = showSummary
-- Event order lookup.
local turnInQuestEvents = {}

function loadBountyData(forceNewAssignment)
  turnInQuestEvents = {}

  local bountyData = player.getProperty("bountyData") or {}
  bountyData = bountyData[player.serverUuid()] or {}
  local posters = bountyData.posters or {}
  local newBountyEvents = player.getProperty("newBountyEvents") or {}

  for _, poster in pairs(posters) do
    if poster.accepted and not posterQuestActive(poster) then
      for _, quest in pairs(poster.arc.quests) do
        local bountyEvent = newBountyEvents[quest.questId]
        if bountyEvent then
          table.insert(turnInQuestEvents, bountyEvent)
        end
      end
    end
  end

  loadBountyData_old(forceNewAssignment)
end

function showSummary(events, newAssignment, newRank)
  local digestedStatusNames = {"Digested", "Churned", "Melted", "Dissolved"}
  for i, e in ipairs(events) do
    local bountyEvent = turnInQuestEvents[i]
    if bountyEvent and bountyEvent.digested then
      e.status = digestedStatusNames[math.random(1, #digestedStatusNames)]
    end
  end

  showSummary_old(events, newAssignment, newRank)
end
