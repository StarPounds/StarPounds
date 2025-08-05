local versioning = starPounds.module:new("versioning")

-- Should probably split this up into several lua files, but it's whatever.
versioning.versions = {
  [1] = function(data)
    sb.logInfo(sb.print(data))
    -- Rename stomach variable.
    data.stomach = data.stomachContents or {}
    data.stomachContents = nil
    data.stomachLerp = nil
    -- New milk format.
    local milkAmount = tonumber(data.breasts) or 0
    local milkType = data.breastType or "milk"
    data.breastType = nil
    data.breasts = {type = milkType, amount = milkAmount}
    -- New experience format.
    local level = tonumber(data.level) or 0
    local amount = tonumber(data.experience) or 0
    data.level = nil
    data.experience = {level = level, amount = amount}
    -- No more stat saving.
    data.stats = nil
    sb.logInfo(sb.print(data))
    return data
  end
}

function versioning:update(data)
  data.version = data.version or 0
  -- Can't use ipairs on a sparse list of versions.
  local versionKeys = {}
  for version in pairs(self.versions) do
    table.insert(versionKeys, version)
  end
  table.sort(versionKeys)
  -- Apply versioning.
  for _, version in ipairs(versionKeys) do
    if version > data.version then
      local versioningFunc = self.versions[version]
      if versioningFunc then
        data = versioningFunc(data)
        data.version = version
      end
    end
  end

  return data
end

starPounds.modules.versioning = versioning
