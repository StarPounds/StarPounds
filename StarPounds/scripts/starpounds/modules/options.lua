local options = starPounds.module:new("options")

function options:init()
  message.setHandler("starPounds.hasOption", simpleHandler(starPounds.hasOption))
  message.setHandler("starPounds.setOption", localHandler(starPounds.setOption))

  self.globalOptions = {}
  for _, option in ipairs(self.data.globalOptions) do
    self.globalOptions[option] = true
  end
  -- Disable some options based on whether we have oSB or not.
  self.disabledOptions = {}
  -- Ignore clientside options for players/configured NPCs.
  local isClient = starPounds.type == "player" or config.getParameter("starPounds_optionsClientside")

  for _, option in ipairs(starPounds.options) do
    if isClient and option.clientOnly then
      self.globalOptions[option.name] = nil
    end
  end
end

function options:has(option)
  -- Argument sanitisation.
  option = tostring(option)
  return (storage.starPounds.options[option] or self.globalOptions[option]) and not self.disabledOptions[option]
end

function options:set(option, enable)
  -- Argument sanitisation.
  option = tostring(option)
  storage.starPounds.options[option] = enable and true or nil
  starPounds.events:fire("stats:calculate", "setOption")
  -- This is stupid, but prevents 'null' data being saved.
  if getmetatable(storage.starPounds.options) then
    getmetatable(storage.starPounds.options).__nils = {}
  end
  starPounds.moduleFunc("data", "backup")
  return storage.starPounds.options[option]
end

function options:isGlobal(option)
  -- Argument sanitisation.
  option = tostring(option)
  return self.globalOptions[option]
end

function options:oSB()
  local openStarbound = starPounds.moduleFunc("oSB", "hasOpenStarbound")
  for _, option in ipairs(starPounds.options) do
    -- Disable oSB specific options if we don't have it.
    if option.oSBOnly and not openStarbound then
      self.disabledOptions[option.name] = true
    end
    -- Disable retail specific options if we have oSB.
    if option.retailOnly and openStarbound then
      self.disabledOptions[option.name] = true
    end
  end
end

-- Shorthand for other modules, option module is always loaded anyway.
function starPounds.hasOption(...)
  return options:has(...)
end

function starPounds.setOption(...)
  return options:set(...)
end

starPounds.modules.options = options
