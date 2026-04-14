local accessories = starPounds.module:new("accessories")

function accessories:init()
  message.setHandler("starPounds.accessories.get", function(_, _, ...) return self:get(...) end)
end

function accessories:get(liq)
  if storage.starPounds.accessory then
    return root.createItem(storage.starPounds.accessory)
  end
end

function accessories:set(item)
  -- Argument sanitisation.
  if item and type(item) ~= "table" then
    item = tostring(item)
  end
  storage.starPounds.accessory = item and root.createItem(item) or nil
  starPounds.events:fire("stats:calculate", "setAccessory")
end

-- Add the module.
starPounds.modules.accessories = accessories
