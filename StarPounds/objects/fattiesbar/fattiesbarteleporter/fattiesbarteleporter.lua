function init()
	self.randomSource = sb.makeRandomSource()

	self.spawnInterval = config.getParameter("spawnInterval")
	self.spawnPosition = object.toAbsolutePosition(config.getParameter("spawnOffset", {0, 0}))

	resetTimer()

	local filteredNpcs = {}
	self.totalNpcWeights = 0

	local validSpecies = {}
	setmetatable(validSpecies, {
		__index = function(t, key)
			t[key] = npcExists("base", key)
			return t[key]
		end
	})

  local types = config.getParameter("npcTypes")
  if type(types) == "string" then
    types = root.assetJson(types)
  end

	for _, npc in pairs(types) do
		if not npcExists(npc.type) then goto continue end

		local filteredSpecies = {}
		npc.totalSpeciesWeights = 0

		for _, species in pairs(npc.species) do
			if type(species) == "string" then
				species = {name = species, weight = 1}
			end

			if validSpecies[species.name] then
				filteredSpecies[#filteredSpecies + 1] = species
				npc.totalSpeciesWeights = npc.totalSpeciesWeights + (species.weight or 1)
			end
		end

		if #filteredSpecies == 0 then goto continue end
		npc.species = filteredSpecies

		npc.weight = npc.weight or 1
		self.totalNpcWeights = self.totalNpcWeights + npc.weight
		filteredNpcs[#filteredNpcs + 1] = npc

		::continue::
	end

	self.npcList = filteredNpcs
end

function update(dt)
	self.spawnTimer = math.max(0, self.spawnTimer - dt)
	if self.spawnTimer == 0 then
		spawnNpc()
		resetTimer()
	end
end

function spawnNpc(beam)
	local npc = weightedRandom(self.npcList, self.totalNpcWeights)
	if not npc then return end
	
	local species = weightedRandom(npc.species, npc.totalSpeciesWeights)
	if not species then return end

	local npcId = world.spawnNpc(self.spawnPosition, species.name, npc.type, 1)

	if beam ~= false then
		world.callScriptedEntity(npcId, "status.addEphemeralEffect", "beamin")
	end
	
	if npc.displayNametag then
		world.callScriptedEntity(npcId, "npc.setDisplayNametag", true)
	end
	
	return npcId
end

function resetTimer()
	self.spawnTimer = self.randomSource:randf(self.spawnInterval[1], self.spawnInterval[2])
end

function npcExists(npcType, species)
	return pcall(root.npcVariant, species or "human", npcType or "base", 0)
end

function weightedRandom(options, totalWeight)
	local choice = self.randomSource:randf() * totalWeight
	for _, option in ipairs(options) do
		choice = choice - (option.weight or 1)
		if choice < 0 then
			return option
		end
	end
	return nil
end