require "/scripts/messageutil.lua"
function init()
  local options = root.assetJson("/scripts/starpounds/starpounds_options.config:options")
  -- Entity message will always return local from a status, so we have to check it again here.
  -- Prevents editing other player's options.
  entityId = entity.id()
  isLocal = (world.entityType(entityId) ~= "player") or (effect.sourceEntity() == entityId)
  -- Select an option from the list based on the effect's duration.
  local optionList = effect.getParameter("options")
  selectedOption = optionList[math.ceil(effect.duration())]
  if selectedOption then
    promises:add(world.sendEntityMessage(entityId, "starPounds.data.get", "options"), function(entityOptions)
      if selectedOption.children then
        local currentIndex = 0
        for i, optionName in ipairs(selectedOption.children) do
          if entityOptions[optionName] then currentIndex = i end
        end
        selectedOption.name = selectedOption.children[math.min(#selectedOption.children, currentIndex + 1)]
      end
      -- Find the option in the config.
      for _, v in ipairs(options) do
        if (v.name == selectedOption.name) and v.group then
          option = v
        end
      end
      -- Second loop to disable grouped options. (i.e. no having bottom and top heavy at the same time)
      disableOptions = jarray()
      for _, v in ipairs(options) do
        if (v ~= option) and (v.group == option.group) then
          disableOptions[#disableOptions + 1] = v.name
        end
      end
      -- Set the option.                                                    I hate it.
      world.sendEntityMessage(entityId, "starPounds.options.set", option.name, not not selectedOption.value)
      if selectedOption.value then
        for _, v in ipairs(disableOptions) do
          world.sendEntityMessage(entityId, "starPounds.options.set", v, false)
        end
      end
      effect.expire()
    end)
  end
end

function update(dt)
  if not isLocal then effect.expire() end
  -- Check promises.
  promises:update()
  effect.modifyDuration(dt)
end
