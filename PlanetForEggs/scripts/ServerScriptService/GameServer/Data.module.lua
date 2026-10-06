--!nocheck
-- Player records: session-locked DataStore load/save with durable purchase receipts.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Data = {}
local Config
local store
local sessionId = game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false)

local function guid() return HttpService:GenerateGUID(false) end
Data.Guid = guid

local function copy(value)
	if type(value) ~= "table" then return value end
	local output = {}
	for k, v in pairs(value) do output[k] = copy(v) end
	return output
end
Data.Copy = copy

local function integer(value, default, maximum)
	if type(value) ~= "number" or value ~= value then return default end
	return math.clamp(math.floor(value), 0, maximum or 1e15)
end
Data.Integer = integer

function Data.Init(config)
	Config = config
	if not RunService:IsStudio() then
		local ok, result = pcall(function() return DataStoreService:GetDataStore(Config.DataStoreName) end)
		if ok then store = result else warn("[PFE] DataStore unavailable:", result) end
	end
end
function Data.HasStore() return store ~= nil end

-- the first egg every new explorer gets: the Moon's first egg
local function starterEgg()
	local moon = Config.EggsOnPlanet("Moon")
	return moon[1] and moon[1].Id or "MoonrockEgg"
end

function Data.Default()
	local starter = starterEgg()
	return {
		Version = Config.Version, Coins = Config.StartingCoins,
		SuitLevel = 1, RocketLevel = 1, CargoLevel = 1, JetpackLevel = 1, OxygenTanks = 0,
		Eggs = {{Id = guid(), EggId = starter, Scale = 1, Mutation = "Normal"}}, GrowingEggs = {}, Pets = {},
		TutorialStep = 1, DiscoveredEggs = {[starter] = true}, DiscoveredPets = {}, Purchases = {},
		-- (v41: AliensDefeated was counted but never kept - Normalize only keeps the keys listed here; the new ones too)
		Stats = {EggsFound = 0, EggsHatched = 0, EggsStolen = 0, Expeditions = 0, EggsLost = 0, Fusions = 0, AliensDefeated = 0,
			BossesDefeated = 0, GoldenEggs = 0, CrystalsBroken = 0, CavesExplored = 0},
		LastSeen = 0,    -- (v41) unix time of the last save: the pets keep earning while you are away (Config.OfflineIncome)
		LuckUntil = 0, ImmortalUntil = 0, VisitedPlanets = {}, SkipBank = 0,
		TempPasses = {}, DungeonLoot = {},
		Codes = {}, FreeStage = 0, FreeAskedAt = 0, VipDailyDay = 0,
		-- v28: speed trained on the treadmill, the treadmill's level, the trails bought and the one worn
		SpeedPower = 0, TreadmillLevel = 1, Trails = {}, Trail = "",
		IntroSeen = 0,   -- (v37) the Halloween join cutscene's version this account has seen
		DailyDay = 0, DailyStep = 0, DailyStreak = 0,   -- (v38) the daily calendar: last claim (UTC day), its day 1-7, the streak
	}
end

-- (v28) a Fusion Egg remembers the eggs fused into it: up to three real (non-fusion) egg ids
local function sourcesOf(value)
	if type(value) ~= "table" then return nil end
	local out = {}
	for _, id in ipairs(value) do
		if #out >= 3 then break end
		local info = type(id) == "string" and Config.Eggs[id]
		if info and not info.Fusion then table.insert(out, id) end
	end
	return #out > 0 and out or nil
end
Data.SourcesOf = sourcesOf
-- (v28) a Chimera keeps the pets it is made of, its name and its base income
local function chimeraOf(pet)
	if type(pet.Parts) ~= "table" then return nil end
	local parts = {}
	for _, sp in ipairs(pet.Parts) do
		if #parts >= 3 then break end
		if type(sp) == "string" and sp ~= "Chimera" and Config.Pets[sp] then table.insert(parts, sp) end
	end
	if #parts < 2 then return nil end
	local income = type(pet.Income) == "number" and pet.Income == pet.Income and math.clamp(math.floor(pet.Income), 1, 1e14) or 1
	local name = type(pet.Name) == "string" and string.sub(pet.Name, 1, 32) or Config.ChimeraName(parts[1], parts[2])
	return parts, income, name
end

local function eggIdOf(raw)
	if type(raw.EggId) == "string" and Config.Eggs[raw.EggId] then return raw.EggId end
	-- (v27) an egg from before the 100 eggs: the new egg of its planet and tier
	local renamed = type(raw.EggId) == "string" and Config.LegacyEggs[raw.EggId]
	if renamed and Config.Eggs[renamed] then return renamed end
	if type(raw.Planet) == "string" and type(raw.Tier) == "number" then
		local legacy = raw.Planet .. math.floor(raw.Tier)
		if Config.Eggs[legacy] then return legacy end
	end
	return nil
end
local function mutationOf(value)
	return type(value) == "string" and Config.Mutations[value] and value or "Normal"
end

function Data.Normalize(raw)
	if type(raw) ~= "table" then return Data.Default() end
	local data = Data.Default()
	-- the old bank / vault balances now land straight in the wallet
	data.Coins = math.min(1e15, integer(raw.Coins, Config.StartingCoins) + integer(raw.Bank, 0) + integer(raw.Vault, 0))
	data.SuitLevel = math.max(1, integer(raw.SuitLevel, 1, #Config.Suits))
	-- v5 had FuelLevel + RocketLevel (both needed for range). Keep whichever was higher.
	local legacyRange = math.max(integer(raw.RocketLevel, 1), integer(raw.FuelLevel, 1))
	data.RocketLevel = math.clamp(legacyRange, 1, #Config.Rockets)
	data.CargoLevel = math.max(1, integer(raw.CargoLevel, 1, #Config.Cargo))
	data.OxygenTanks = integer(raw.OxygenTanks, 0, 1000)
	data.JetpackLevel = math.max(1, integer(raw.JetpackLevel, 1, #Config.Jetpacks))
	data.TutorialStep = integer(raw.TutorialStep, 1, 20)
	data.IntroSeen = integer(raw.IntroSeen, 0, 1000)
	data.DailyDay = integer(raw.DailyDay, 0)
	data.DailyStep = integer(raw.DailyStep, 0, 7)
	data.DailyStreak = integer(raw.DailyStreak, 0, 100000)
	data.LastSeen = integer(raw.LastSeen, 0, 1e12)
	data.LuckUntil = integer(raw.LuckUntil, 0)
	data.ImmortalUntil = integer(raw.ImmortalUntil, 0)
	data.SkipBank = integer(raw.SkipBank, 0, 10000000)
	-- codes used (code -> when), the Free reward's progress, the VIP's last daily present (day number)
	-- v28 speed: SP keeps two decimals
	if type(raw.SpeedPower) == "number" and raw.SpeedPower == raw.SpeedPower then
		data.SpeedPower = math.clamp(math.floor(raw.SpeedPower * 100) / 100, 0, 1e15)
	end
	data.TreadmillLevel = math.max(1, integer(raw.TreadmillLevel, 1, math.max(1, #(Config.Treadmills or {}))))
	if type(raw.Trails) == "table" then
		for id, v in pairs(raw.Trails) do if Config.Trails[id] and v == true then data.Trails[id] = true end end
	end
	data.Trail = type(raw.Trail) == "string" and data.Trails[raw.Trail] and raw.Trail or ""
	data.FreeStage = integer(raw.FreeStage, 0, 2)
	data.FreeAskedAt = integer(raw.FreeAskedAt, 0)
	data.VipDailyDay = integer(raw.VipDailyDay, 0)
	if type(raw.Codes) == "table" then
		for code, at in pairs(raw.Codes) do
			if type(code) == "string" and #code <= 40 and type(at) == "number" then data.Codes[code] = math.floor(at) end
		end
	end
	-- game passes won in dungeons (key -> unix time they run out) and when each ship was last looted
	data.TempPasses, data.DungeonLoot = {}, {}
	if type(raw.TempPasses) == "table" then
		for key, untilTime in pairs(raw.TempPasses) do
			if Config.GamePasses[key] and type(untilTime) == "number" and untilTime > os.time() then data.TempPasses[key] = math.floor(untilTime) end
		end
	end
	if type(raw.DungeonLoot) == "table" then
		for key, at in pairs(raw.DungeonLoot) do
			if type(key) == "string" and #key < 40 and type(at) == "number" then data.DungeonLoot[key] = math.floor(at) end
		end
	end
	data.Eggs, data.GrowingEggs, data.Pets = {}, {}, {}
	if type(raw.DiscoveredEggs) == "table" then
		for eggId, v in pairs(raw.DiscoveredEggs) do
			eggId = Config.Eggs[eggId] and eggId or Config.LegacyEggs[eggId]
			if eggId and Config.Eggs[eggId] and v == true then data.DiscoveredEggs[eggId] = true end
		end
	end
	if type(raw.DiscoveredPets) == "table" then
		for species, v in pairs(raw.DiscoveredPets) do if Config.Pets[species] and v == true then data.DiscoveredPets[species] = true end end
	end
	if type(raw.VisitedPlanets) == "table" then
		for planet, v in pairs(raw.VisitedPlanets) do if Config.Planets[planet] and v == true then data.VisitedPlanets[planet] = true end end
	end
	if type(raw.Purchases) == "table" then
		for purchaseId, value in pairs(raw.Purchases) do
			if type(purchaseId) == "string" and #purchaseId <= 128 and (type(value) == "number" or type(value) == "boolean" or type(value) == "string") then
				data.Purchases[purchaseId] = value
			end
		end
	end
	if type(raw.Stats) == "table" then
		for key in pairs(data.Stats) do data.Stats[key] = integer(raw.Stats[key], 0) end
	end
	local seen = {}
	if type(raw.Eggs) == "table" then
		for _, egg in ipairs(raw.Eggs) do
			if #data.Eggs >= Config.MaxStoredEggs then break end
			local eggId = type(egg) == "table" and eggIdOf(egg)
			if eggId then
				local id = type(egg.Id) == "string" and not seen[egg.Id] and egg.Id or guid()
				seen[id] = true
				local info = Config.Eggs[eggId]
				table.insert(data.Eggs, {Id = id, EggId = eggId, Scale = Config.AssetScale(egg.Scale), Mutation = mutationOf(egg.Mutation),
					FastGrow = egg.FastGrow == true or nil, Sources = info.Fusion and sourcesOf(egg.Sources) or nil})
				data.DiscoveredEggs[eggId] = true
			end
		end
	end
	if type(raw.GrowingEggs) == "table" then
		for _, egg in ipairs(raw.GrowingEggs) do
			if #data.GrowingEggs >= Config.MaxGrowingEggs then break end
			local eggId = type(egg) == "table" and eggIdOf(egg)
			if eggId and type(egg.LocalPosition) == "table" then
				local x, z = egg.LocalPosition[1], egg.LocalPosition[3]
				local id = type(egg.Id) == "string" and egg.Id or guid()
				if not seen[id] and type(x) == "number" and type(z) == "number" and x == x and z == z and math.abs(x) <= 100 and math.abs(z) <= 100 then
					seen[id] = true
					local info = Config.Eggs[eggId]
					local planted = integer(egg.PlacedAt, os.time(), 1e12)
					local scale = Config.AssetScale(egg.Scale)
					local duration = Config.EggGrowthDuration(info, scale) * (egg.FastGrow == true and 0.5 or 1)
					local ready = integer(egg.ReadyAt, planted + duration, 1e12)
					table.insert(data.GrowingEggs, {Id = id, EggId = eggId, LocalPosition = {x, 0, z}, PlacedAt = planted,
						GrowthDuration = duration, Scale = scale, Mutation = mutationOf(egg.Mutation), FastGrow = egg.FastGrow == true or nil,
						ReadyAt = math.clamp(ready, planted, planted + duration), Sources = info.Fusion and sourcesOf(egg.Sources) or nil})
					data.DiscoveredEggs[eggId] = true
				end
			end
		end
	end
	if type(raw.Pets) == "table" then
		for _, pet in ipairs(raw.Pets) do
			if #data.Pets >= Config.MaxPets then break end
			local species = type(pet) == "table" and (Config.LegacySpecies[pet.Species] or pet.Species)
			if species == "Chimera" then
				local parts, income, name = chimeraOf(pet)
				if parts then
					table.insert(data.Pets, {Id = type(pet.Id) == "string" and pet.Id or guid(), Species = "Chimera", Parts = parts, Income = income,
						Rarity = (type(pet.Rarity) == "string" and Config.Rarities[pet.Rarity]) and pet.Rarity or nil,
						Name = name, Multiplier = type(pet.Multiplier) == "number" and pet.Multiplier or nil,
						Scale = Config.AssetScale(pet.Scale), Mutation = mutationOf(pet.Mutation)})
					data.DiscoveredPets.Chimera = true
				end
			elseif species and Config.Pets[species] then
				table.insert(data.Pets, {Id = type(pet.Id) == "string" and pet.Id or guid(), Species = species,
					Scale = Config.AssetScale(pet.Scale), Mutation = mutationOf(pet.Mutation)})
				data.DiscoveredPets[species] = true
			end
		end
	end
	return data
end

function Data.Load(player)
	if not store then return Data.Default(), "Studio: temporary session", false end
	local locked = false
	for attempt = 1, 3 do
		local success, record = pcall(function()
			return store:UpdateAsync(tostring(player.UserId), function(old)
				locked = false
				if type(old) == "table" and type(old.Session) == "table" and old.Session.Id ~= sessionId and (old.Session.At or 0) > os.time() - 180 then
					locked = true
					return nil
				end
				return {Data = Data.Normalize(type(old) == "table" and (old.Data or old) or nil), Session = {Id = sessionId, At = os.time()}}
			end)
		end)
		if success and type(record) == "table" and record.Session and record.Session.Id == sessionId then
			return Data.Normalize(record.Data), "Saved", true
		end
		if success and locked then return nil, "Your profile is still open on another server. Please rejoin in a moment.", false end
		if attempt < 3 then task.wait(attempt) end
	end
	return nil, "Could not load your saved progress. Please rejoin; no data was changed.", false
end

-- Receipts stored in the durable record are merged into every write so a commit whose
-- response was lost is never applied twice.
local function mergeReceipts(snapshot, stored)
	local merged = copy(snapshot)
	merged.Purchases = merged.Purchases or {}
	if type(stored) == "table" and type(stored.Purchases) == "table" then
		for purchaseId, value in pairs(stored.Purchases) do
			if merged.Purchases[purchaseId] == nil then merged.Purchases[purchaseId] = value end
		end
	end
	return merged
end

function Data.Save(profile, release)
	if not store or not profile.Persistent then return true end
	local deadline = os.clock() + (release and 20 or 10)
	while profile.Saving and os.clock() < deadline do
		if not release then return false end
		task.wait(0.1)
	end
	if profile.Saving or not profile.Persistent then return false end
	profile.Saving = true
	-- (v41) the moment of every save is when the offline earnings start counting if this is the last one
	if profile.OfflineSettled then profile.Data.LastSeen = os.time() end
	local snapshot = copy(profile.Data)
	local writeId = guid()
	local success, result
	for attempt = 1, (release and 3 or 2) do
		success, result = pcall(function()
			return store:UpdateAsync(tostring(profile.Player.UserId), function(old)
				if type(old) == "table" and old.LastWrite == writeId then return old end
				if type(old) ~= "table" or type(old.Session) ~= "table" or old.Session.Id ~= sessionId then return nil end
				return {Data = mergeReceipts(snapshot, old.Data), Session = not release and {Id = sessionId, At = os.time()} or nil, LastWrite = writeId}
			end)
		end)
		if success then break end
		local delay = 2 ^ (attempt - 1)
		if os.clock() + delay >= deadline then break end
		task.wait(delay)
	end
	profile.Saving = false
	if success and type(result) == "table" and result.LastWrite == writeId then
		if type(result.Data) == "table" and type(result.Data.Purchases) == "table" then
			for purchaseId, value in pairs(result.Data.Purchases) do
				if profile.Data.Purchases[purchaseId] == nil then profile.Data.Purchases[purchaseId] = value end
			end
		end
		profile.SaveStatus = "Saved"; profile.LastSave = os.clock(); profile.SaveFailures = 0
		if release then profile.Persistent = false end
		return true
	elseif success then
		profile.Persistent = false
		profile.SaveStatus = "Session moved"
		if profile.Player.Parent then profile.Player:Kick("Your saved profile was opened by another session. Please rejoin.") end
		return false
	end
	profile.SaveFailures = (profile.SaveFailures or 0) + 1
	profile.NextSaveAttempt = os.clock() + math.min(60, 15 * 2 ^ math.min(profile.SaveFailures - 1, 2))
	profile.SaveStatus = "Save retry pending"
	warn("[PFE] save failed for", profile.Player.UserId, result)
	return false
end

return Data
