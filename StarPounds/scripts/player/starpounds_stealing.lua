function init()
  local setHandler_old = message.setHandler
  -- Hook handler.
  function message.setHandler(messageName, handler)
    if (messageName == "tileBroken") or (messageName == "tileEntityBroken") then
      local oldHandler = handler
      handler = function(msgName, isLocal, ...)
        local shared = getmetatable ""
        local starPounds = shared.starPounds
        starPounds.events:fire(messageName, {...})
        return oldHandler(msgName, isLocal, ...)
      end
    end

    return setHandler_old(messageName, handler)
  end
  -- Load old script.
  require(root.assetJson("/player.config:starpounds_stealing_old"))
  init()
end
