local options = starPounds.module:new("options")

function options:init()
  message.setHandler("starPounds.options.get", simpleHandler(starPounds.getOption))
  message.setHandler("starPounds.options.has", simpleHandler(starPounds.hasOption))
  message.setHandler("starPounds.options.set", localHandler(starPounds.setOption))

  self.globalOptions = {}
  for _, option in ipairs(self.data.globalOptions) do
    if type(option) == "table" and option.name then
      self.globalOptions[option.name] = option.value
    elseif type(option) == "string" then
      self.globalOptions[option] = true
    end
  end

  self.disabledOptions = {}
  self.defaultValues = {} -- Cache default slider values.

  -- Ignore clientside options for players/configured NPCs.
  local isClient = starPounds.type == "player" or config.getParameter("starPounds_optionsClientside")
  local openStarbound = starPounds.moduleFunc("oSB", "hasOpenStarbound")

  for _, option in ipairs(starPounds.options) do
    if option.type == "slider" then
      self.defaultValues[option.name] = option.default or option.min or 0
    elseif option.type == "radio" then
      self.defaultValues[option.name] = option.default or (option.options and option.options[1] and option.options[1].value)
    end

    if isClient and option.clientOnly then
      self.globalOptions[option.name] = nil
    end

    if option.oSBOnly and not openStarbound then
      self.disabledOptions[option.name] = true
    end
    if option.retailOnly and openStarbound then
      self.disabledOptions[option.name] = true
    end
  end
end

function options:get(option)
  -- Argument sanitisation.
  option = tostring(option)
  if self.disabledOptions[option] then return nil end
  -- Global option.
  if self.globalOptions[option] ~= nil then
    return self.globalOptions[option]
  end

  local value = storage.starPounds.options[option]
  if value ~= nil then return value end

  return self.defaultValues[option]
end

function options:has(option)
  -- Argument sanitisation.
  option = tostring(option)
  return self:get(option)
end

function options:set(option, value)
  -- Argument sanitisation.
  option = tostring(option)
  -- Clear if we set it to the default value.
  if self.defaultValues[option] ~= nil and value == self.defaultValues[option] then
    value = nil
  end
  -- Clear if false/nil.
  if value == false or value == nil then
    storage.starPounds.options[option] = nil
  else
    storage.starPounds.options[option] = value
  end

  starPounds.events:fire("stats:calculate", "options:set")

  if getmetatable(storage.starPounds.options) then
    getmetatable(storage.starPounds.options).__nils = {}
  end

  starPounds.moduleFunc("data", "backup")
  return storage.starPounds.options[option]
end

function options:isGlobal(option)
  -- Argument sanitisation.
  option = tostring(option)
  return self.globalOptions[option] ~= nil
end

-- Shorthand wrappers
function starPounds.getOption(...)
  return options:get(...)
end

function starPounds.hasOption(...)
  return options:has(...)
end

function starPounds.setOption(...)
  return options:set(...)
end

starPounds.modules.options = options
