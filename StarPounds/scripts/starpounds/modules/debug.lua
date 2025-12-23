local debug = starPounds.module:new("debug")

function debug:init()
  self.colours = { "^#665599;", "^#ccbbff;", "^gray;" }
  self.colourStrings = {}

  self:log()
end

function debug:update(dt)
  -- Debug stuff.
  if starPounds.hasOption("showDebug") then
    local data = storage.starPounds
    local stomach = starPounds.stomach
    local breasts = starPounds.moduleFunc("breasts", "get")
    local gurgleTimer = starPounds.modules.stomach and starPounds.modules.stomach.gurgleTimer or 0
    local rumbleTimer = starPounds.modules.stomach and starPounds.modules.stomach.rumbleTimer or 0
    local accessory = data.accessory
    local experienceConfig = starPounds.moduleFunc("experience", "config")
    self:format("accessory", "<c:1>Accessory: <c:3>%s", accessory and accessory.name or "None")
    self:format("experience", "<c:1>Level: <c:3>%s <c:1>Experience: <c:3>%.0f/%.0f <c:1>Multiplier: <c:3>%s", data.experience.level, data.experience.amount, experienceConfig.experienceAmount * (1 + data.experience.level * experienceConfig.experienceIncrement), math.max(starPounds.getStat("experienceMultiplier") - (starPounds.hasOption("disableHunger") and math.max((starPounds.getStat("hunger") - starPounds.moduleFunc("stats", "getRaw", "hunger").base) * 0.2, 0) or 0), 0))
    self:format("stomach", "<c:1>Fullness: <c:3>%.0f%%%% <c:1>Capacity: <c:3>%.1f/%.1f <c:1>Hunger: <c:3>%.1f/%.0f", stomach.interpolatedFullness * 100, stomach.contents, stomach.capacity, status.resource("food"), status.resourceMax("food"))
    self:format("stomachContents", "<c:1>Contents: <c:3>%.1f <c:1>Food: <c:3>%.1f <c:1>Entities: <c:3>%d", stomach.contents, stomach.food, #data.stomachEntities)
    self:format("breasts", "<c:1>Type: <c:3>%s <c:1>Capacity: <c:3>%.1f/%.1f <c:1>Contents: <c:3>%.1f", breasts.type, breasts.contents, breasts.capacity, data.breasts.amount)
    self:format("size", "<c:1>Size: <c:3>%s <c:1>Weight: <c:3>%.2f%s <c:1>Multiplier: <c:3>%.1fx", (starPounds.currentSize.size == "" and "none" or starPounds.currentSize.size)..(starPounds.currentVariant and ": "..starPounds.currentVariant or ""), starPounds.hasOption("useImperial") and data.weight * 2.20462234 or data.weight, starPounds.hasOption("useImperial") and "lb" or "kg", starPounds.weightMultiplier)
    self:format("timers", "<c:1>Gurgle: <c:3>%.1f <c:1>Rumble: <c:3>%.1f", gurgleTimer or 0, rumbleTimer or 0)
    self:format("trait", "<c:1>Trait: <c:3>%s", data.trait or "None")
  end
end

function debug:format(k, v, ...)
  v = storage.starPounds.enabled and self:colourString(k, v) or self:colourString("disabled", "<c:3>Mod disabled")
  sb.setLogMap(string.format("%s%s", "^#ccbbff;StarPounds_", k), sb.print(string.format(v, ...)))
end

-- Caches coloured format strings so we don't redo it every single tick.
function debug:colourString(k, v)
  if self.colourStrings[k] then return self.colourStrings[k] end
  for i = 1, #self.colours do
    v = v:gsub(string.format("<c:%s>", i), self.colours[i])
  end
  self.colourStrings[k] = v
  return self.colourStrings[k]
end

function debug:log()
  local versionString = string.format("%s STARPOUNDS: %s ", self.data.marginCharacter, starPounds.version)
  local header = string.format("%s%s", versionString, string.rep(self.data.marginCharacter, math.max(self.data.marginSize - string.len(versionString), 0)))
  local footer = string.rep(self.data.marginCharacter, self.data.marginSize)

  local options = (function ()
    local first
    local s = ""
    for option in pairs(starPounds.moduleFunc("data", "get", "options")) do
      s = s..(first and ", " or "")..sb.print(option)
      first = true
    end
    return first and s or "none"
  end)()

  local size = starPounds.moduleFunc("size", "get", storage.starPounds.weight)
  size = size.size == "" and "none" or size.size

  sb.logInfo(header)
  sb.logInfo(string.format("Enabled - %s", sb.print(storage.starPounds.enabled)))
  sb.logInfo(string.format("Species - %s (%s) | %s", sb.print(starPounds.getSpecies()), sb.print(starPounds.getVisualSpecies()), sb.print(player.species())))
  sb.logInfo(string.format("Trait --- %s", sb.print(starPounds.getTrait())))
  sb.logInfo(string.format("Size ---- %s | %s", sb.print(size), sb.print(storage.starPounds.weight)))
  sb.logInfo(string.format("Stomach - %s | %s", sb.print(storage.starPounds.stomach), sb.print(#storage.starPounds.stomachEntities)))
  sb.logInfo(string.format("Options - %s", options))
  sb.logInfo(footer)
end

starPounds.modules.debug = debug
