--!nocheck
-- Flights, planet egg hunts, oxygen, rocket/suit/cargo upgrades.
local Players = game:GetService("Players")
local Expeditions = {}
local ctx, Config, Data, ModelUtil
local rng = Random.new()

local function planetModel(id) return ctx.planets:FindFirstChild(id) end

-- ---------------------------------------------------------------- carry visual (also used for stolen eggs)
function Expeditions.ClearCarry(profile)
	if profile.CarryVisual then profile.CarryVisual:Destroy(); profile.CarryVisual = nil end
	if profile.Player.Parent then profile.Player:SetAttribute("PFECarrying", false) end
end
function Expeditions.ShowCarry(profile, egg)
	Expeditions.ClearCarry(profile)
	local characterRoot = ctx.root(profile.Player)
	local template = ctx.eggTemplate(egg.EggId)
	if not characterRoot or not template then return end
	local model = template:Clone()
	model.Name = "CarriedPlanetEgg"
	ModelUtil.PrepareVisual(model, true)
	local eggInfo = Config.Eggs[egg.EggId]
	-- its own size (the rarer the bigger), within what two hands can carry
	ModelUtil.FitTo(model, Config.HeldEggSize(eggInfo and eggInfo.Rarity, egg.Scale))
	ModelUtil.ApplyMutation(model, egg.Mutation)
	ModelUtil.AttachEggFX(model, eggInfo and eggInfo.Rarity, egg.Scale)
	model:SetAttribute("OwnerUserId", profile.Player.UserId)
	model:SetAttribute("EggId", egg.EggId)
	local bounds = ModelUtil.VisibleBounds(model)
	local pivotToCenter = model:GetPivot():ToObjectSpace(bounds)
	local _, carried = ModelUtil.VisibleBounds(model)
	model:PivotTo(characterRoot.CFrame * Config.HeldEggOffset(carried, Config.HeadTop(profile.Player.Character)) * pivotToCenter:Inverse())
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false; part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = characterRoot; weld.Part1 = part; weld.Parent = part
		end
	end
	model.Parent = profile.Player.Character
	profile.CarryVisual = model
	-- both hands are on the egg: the bat goes back into the backpack until it is delivered
	profile.Player:SetAttribute("PFECarrying", true)
	local humanoid = ctx.humanoid(profile.Player)
	if humanoid then pcall(function() humanoid:UnequipTools() end) end
end

-- ---------------------------------------------------------------- flights
local function fly(profile, destination, callback)
	ctx.setSprint(profile, false)
	profile.Busy = true
	profile.FlightFrom = profile.Planet
	profile.FlightDestination = destination
	profile.FlightStartedAt = workspace:GetServerTimeNow()
	local fromGalaxy = profile.Planet ~= "Base" and Config.Planets[profile.Planet] and Config.Planets[profile.Planet].Galaxy or "MilkyWay"
	local toGalaxy = destination ~= "Base" and Config.Planets[destination] and Config.Planets[destination].Galaxy or "MilkyWay"
	local duration = Config.FlightDuration + (fromGalaxy ~= toGalaxy and Config.GalaxyJumpBonus or 0)
	profile.FlightDuration = duration
	profile.FlightToken += 1
	local token = profile.FlightToken
	local characterRoot = ctx.root(profile.Player)
	if characterRoot then characterRoot.Anchored = true end
	ctx.remotes.Flight:FireClient(profile.Player, {From = profile.Planet, Destination = destination, Duration = duration,
		Landing = Config.LandingDuration, GalaxyJump = fromGalaxy ~= toGalaxy, BaseIndex = profile.BaseIndex})
	ctx.sendState(profile)
	task.delay(duration, function()
		if ctx.profiles[profile.Player] ~= profile or profile.FlightToken ~= token then return end
		callback()
		ctx.sendState(profile)
		task.delay(Config.LandingDuration, function()
			if ctx.profiles[profile.Player] ~= profile or profile.FlightToken ~= token then return end
			profile.Busy = false
			profile.FlightFrom, profile.FlightDestination, profile.FlightStartedAt, profile.FlightDuration = nil, nil, nil, nil
			local newRoot = ctx.root(profile.Player)
			if newRoot then newRoot.Anchored = false end
			ctx.setMovement(profile)
			ctx.sendState(profile)
		end)
	end)
end

-- ---------------------------------------------------------------- shared eggs on each planet
-- Like Egg Arena's area eggs: every planet has ONE pool of eggs (PFE_Pickups/<PlanetId>) that
-- everyone exploring it sees and races for. Picking one up puts it in your hands; carry it to your
-- rocket. Anyone who hits you with the bat takes it out of your hands (and so on, round and round);
-- if they have no room it drops on the ground for whoever is fastest. Dying drops it too.
local pools = {}       -- planetId -> {Planet, Folder, Seed, UsedSpots, Generation, Counts, Total, Islands}
local pickupEggs = setmetatable({}, {__mode = "k"}) -- pickup model -> its egg (events upgrade them)

-- (v41) no eggs on or around the landing pad: a hiding spot closer than Config.NearEggs.RocketClear to the planet's
-- centre (where the rocket stands) is never used
local function nearRocket(origin, position)
	local clear = Config.NearEggs.RocketClear or 0
	local dx, dz = position.X - origin.X, position.Z - origin.Z
	return dx * dx + dz * dz < clear * clear
end
-- (v41) the ground eggs on hiding spots, counted as they come and go (the pool used to be scanned five times for
-- every egg it laid - hundreds of thousands of attribute reads whenever somebody landed or the maps reset)
local function countIn(pool, item, zone)
	item:SetAttribute("Counted", true)
	pool.Counts[zone or 0] = (pool.Counts[zone or 0] or 0) + 1
	pool.Total += 1
end
local function uncount(pool, item)
	if not pool or not item:GetAttribute("Counted") then return end
	item:SetAttribute("Counted", nil)
	local zone = item:GetAttribute("Zone") or 0
	pool.Counts[zone] = math.max(0, (pool.Counts[zone] or 0) - 1)
	pool.Total = math.max(0, pool.Total - 1)
end

local function explorers(planetId)
	local list = {}
	for _, p in pairs(ctx.profiles) do
		if p.Expedition and p.Expedition.Planet == planetId and p.Planet == planetId then table.insert(list, p) end
	end
	return list
end
-- the luckiest explorer's luck rolls the shared eggs
local function poolLuck(planetId)
	local best = ctx.eventActive("Starfall") and 2 or 1
	for _, p in ipairs(explorers(planetId)) do best = math.max(best, ctx.luck(p)) end
	return best
end
local function luckOf(who, planetId)
	if type(who) == "number" then return who end
	if type(who) == "table" and who.Data then return ctx.luck(who) end
	return planetId and poolLuck(planetId) or 1
end

-- rareBoost > 1 favours the rarer eggs of the planet (sky islands); super = chance of the chase egg
local function rollEgg(who, planetId, zone, rareBoost, super)
	local eggs = Config.EggsOnPlanet(planetId)
	if super and rng:NextNumber() < super and #eggs > 0 then return eggs[#eggs] end
	local weights = Config.ZoneTierWeights[zone] or Config.ZoneTierWeights[3]
	local luck = luckOf(who, planetId)
	local total, list = 0, {}
	for _, egg in ipairs(eggs) do
		local w = egg.Weight * (weights[egg.Tier] or 1) * (egg.Tier >= 2 and luck or 1) * ((rareBoost or 1) ^ ((egg.Tier - 1) / 6))
		total += w
		table.insert(list, {egg, w})
	end
	local roll = rng:NextNumber() * total
	for _, entry in ipairs(list) do
		roll -= entry[2]
		if roll <= 0 then return entry[1] end
	end
	return list[#list] and list[#list][1]
end
local function rollMutation(who, planetId)
	local luck = luckOf(who, planetId)
	local roll = rng:NextNumber()
	local acc = 0
	for i = #Config.MutationList, 2, -1 do
		local m = Config.MutationList[i]
		acc += m.Chance * luck
		if roll < acc then return m.Id end
	end
	-- Golden Hour: every egg that appears is at least golden
	if ctx.eventActive("GoldenHour") then return "Golden" end
	return "Normal"
end
Expeditions.RollEgg, Expeditions.RollMutation = rollEgg, rollMutation
local function rollSize()
	local roll, acc = rng:NextNumber(), 0
	for _, size in ipairs(Config.Sizes) do
		acc += size.Chance
		if roll <= acc then return size.Scale end
	end
	return 1
end
Expeditions.RollSize = rollSize

-- (v28) a free hiding spot in distance ring `zone` (or anywhere)
local function freeSpot(pool, layout, zone)
	local list = zone and layout.SpotsByZone and layout.SpotsByZone[zone] or layout.Spots
	if not list or #list == 0 then list = layout.Spots end
	if not list or #list == 0 then return nil end
	local origin = layout.Origin
	for _ = 1, 40 do
		local spot = list[rng:NextInteger(1, #list)]
		if spot and not pool.UsedSpots[spot.Id] and not nearRocket(origin, spot.Position) then return spot end
	end
	for _, spot in ipairs(list) do
		if not pool.UsedSpots[spot.Id] and not nearRocket(origin, spot.Position) then return spot end
	end
	return nil
end
local function groundCount(pool, zone)
	if zone == nil then return pool.Total end
	return pool.Counts[zone] or 0
end
local function targetCount(pool)
	return math.min(Config.EggsMaxPerPlanet or 330, Config.EggsPerExpedition + math.max(0, #explorers(pool.Planet) - 1) * Config.EggsPerExtraExplorer)
end
-- (v28) the ring the next egg goes to: the one furthest below its share of the pool (Config.ZoneShare: most
-- eggs near the landing pad, few - but rare - out at the edge)
local function nextZone(pool)
	local total = targetCount(pool)
	local best, gap = nil, -math.huge
	for zone, share in ipairs(Config.ZoneShare) do
		local want = total * share
		local missing = (want - groundCount(pool, zone)) / math.max(0.5, want)
		if missing > gap then best, gap = zone, missing end
	end
	if gap <= 0 then
		-- every ring is full: by share
		local roll = rng:NextNumber()
		for zone, share in ipairs(Config.ZoneShare) do
			roll -= share
			if roll <= 0 then return zone end
		end
	end
	return best
end

-- where a pickup is right now (sky-island eggs move with their island)
local function pickupPoint(pool, item, proxy)
	local islandId = item:GetAttribute("IslandId")
	if islandId then
		local island = ctx.SkyPaths.Islands(pool.Planet, pool.Seed)[islandId]
		if island then return ctx.SkyPaths.EggPoint(pool.Planet, island, workspace:GetServerTimeNow()) + Vector3.new(0, 1.9, 0) end
	end
	return proxy.Position
end

-- the egg model, its label and prompt around a proxy part placed at `point`
local function makePickup(pool, name, point, egg, info, opts)
	local item = Instance.new("Model")
	item.Name = name
	item:SetAttribute("Planet", pool.Planet)
	local proxy = Instance.new("Part")
	proxy.Name = "Pickup"; proxy.Size = Vector3.new(3.2, 3.8, 3.2); proxy.Anchored = true; proxy.CanCollide = false
	proxy.CanTouch = false; proxy.CanQuery = false; proxy.Transparency = 1
	proxy.CFrame = CFrame.new(point + Vector3.new(0, 1.9, 0))
	proxy.Parent = item
	item.PrimaryPart = proxy
	local template = ctx.eggTemplate(info.Id)
	local labelHeight = 3.8
	if template then
		local visual = template:Clone()
		ModelUtil.PrepareVisual(visual, true)
		ModelUtil.FitTo(visual, Config.PlanetEggSize(info.Rarity, egg.Scale))
		ModelUtil.ApplyMutation(visual, egg.Mutation)
		visual.Name = "Visual"
		visual.Parent = item
		ModelUtil.PlaceOnGround(visual, point, rng:NextNumber(0, math.pi * 2))
		ModelUtil.AttachEggFX(visual, info.Rarity, egg.Scale)
		local _, size = ModelUtil.VisibleBounds(visual)
		proxy.Size = Vector3.new(math.max(3.2, size.X), math.max(3.8, size.Y), math.max(3.2, size.Z))
		labelHeight = math.max(3.8, size.Y + 1.2)
		-- clients that move the pickup (sky islands) place the egg by this offset from the proxy
		item:SetAttribute("VisualOffset", proxy.CFrame:ToObjectSpace(visual:GetPivot()))
	end
	item:SetAttribute("EggId", info.Id); item:SetAttribute("Rarity", info.Rarity); item:SetAttribute("Mutation", egg.Mutation)
	for key, value in pairs(opts or {}) do item:SetAttribute(key, value) end
	-- (v41) the Golden Egg of the race (PlanetLife) stays the Golden Egg wherever it lies: picked up, knocked away, dropped
	if egg.GoldenRace then item:SetAttribute("GoldenRace", true); item:SetAttribute("Keep", true) end
	local title = egg.GoldenRace and "THE GOLDEN EGG" or Config.EggDisplayName(egg)
	local label = ctx.label(item, title, egg.GoldenRace and "Grab it and get it to your rocket!" or "Hold E to pick up",
		egg.GoldenRace and Color3.fromRGB(255, 214, 60) or Config.Rarities[info.Rarity].Color, labelHeight)
	if label then label.MaxDistance = egg.GoldenRace and 400 or 28 + labelHeight end
	local prompt = ctx.makePrompt(proxy, "CollectPickup", "Pick up", nil,
		{Hold = 0.3, Distance = item:GetAttribute("IslandId") and 16 or 10, ObjectText = title})
	pickupEggs[item] = egg
	return item, proxy, prompt
end

-- put a planet egg into this explorer's hands (the carry model, stats, announcements)
local function giveCarry(profile, egg, announce)
	local expedition = profile.Expedition
	expedition.CarryingEgg = {Id = egg.Id or Data.Guid(), EggId = egg.EggId, Scale = egg.Scale, Mutation = egg.Mutation,
		FastGrow = egg.FastGrow or ctx.eventActive("Aurora") or nil, GoldenRace = egg.GoldenRace}
	Expeditions.ShowCarry(profile, expedition.CarryingEgg)
	if egg.GoldenRace and ctx.GoldenEggTaken then task.spawn(ctx.GoldenEggTaken, profile) end
	profile.Data.DiscoveredEggs[egg.EggId] = true
	profile.Data.TutorialStep = math.max(profile.Data.TutorialStep, 4)
	if announce then
		profile.Data.Stats.EggsFound += 1
		local info = Config.Eggs[egg.EggId]
		local rarity = Config.Rarities[info.Rarity]
		ctx.effect(profile.Player, "EggFound", {EggId = egg.EggId, Mutation = egg.Mutation, Scale = egg.Scale})
		if rarity.Order >= 5 or egg.Mutation ~= "Normal" or egg.Scale >= 2.5 then
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= profile.Player then
					ctx.remotes.Notice:FireClient(other, profile.Player.DisplayName .. " found " .. Config.EggDisplayName(egg) .. "!", info.Rarity)
				end
			end
		end
	end
	ctx.publishTracker(profile)
	ctx.markDirty(profile)
end

-- can this explorer take one more egg right now? (nil, or the reason why not)
local function roomFor(profile)
	local expedition = profile.Expedition
	if not expedition or profile.Busy then return "busy" end
	if expedition.CarryingEgg then return "Carry this egg to your rocket before taking another one." end
	if #expedition.Eggs >= ctx.capacity(profile) then return "Rocket cargo is full! Fly home or upgrade your cargo." end
	if #profile.Data.Eggs + #expedition.Eggs >= Config.MaxStoredEggs then return "Your egg storage is full. Plant eggs at your base first." end
	return nil
end

local spawnSpot, spawnIslandEgg, spawnDropped
local function onPickup(pool, item, respawn, proxy)
	return function(player)
		local profile = ctx.profiles[player]
		local expedition = profile and profile.Expedition
		if not expedition or expedition.Planet ~= pool.Planet or profile.Busy or item.Parent == nil or pools[pool.Planet] ~= pool then return end
		local egg = pickupEggs[item]
		local characterRoot = ctx.root(player)
		local reach = Config.PickupDistance * (Config.PromptReach or 1) + (item:GetAttribute("IslandId") and 10 or 0)
		if not egg or not characterRoot or (characterRoot.Position - pickupPoint(pool, item, proxy)).Magnitude > reach then return end
		local full = roomFor(profile)
		if full then ctx.notice(profile, full, "Red"); ctx.effect(player, "PickupBlocked", {Reason = full}); return end
		pickupEggs[item] = nil
		local dropped = item:GetAttribute("Dropped") == true
		uncount(pool, item)
		item:Destroy()
		giveCarry(profile, egg, not dropped)
		if respawn then
			local generation = pool.Generation
			task.delay(rng:NextNumber(Config.EggRespawn[1], Config.EggRespawn[2]), function()
				if pools[pool.Planet] == pool and pool.Generation == generation then respawn() end
			end)
		end
	end
end

spawnSpot = function(pool, bonus)
	local layout = ctx.PlanetGen.Generate(pool.Planet, pool.Seed)
	if not layout or pools[pool.Planet] ~= pool or (not bonus and groundCount(pool) >= targetCount(pool)) then return end
	local spot = freeSpot(pool, layout, not bonus and nextZone(pool) or nil)
	if not spot then return end
	pool.UsedSpots[spot.Id] = true
	local info = rollEgg(nil, pool.Planet, spot.Zone)
	if not info then pool.UsedSpots[spot.Id] = nil; return end
	local egg = {EggId = info.Id, Scale = rollSize(), Mutation = rollMutation(nil, pool.Planet)}
	local item, proxy, prompt = makePickup(pool, "Egg_" .. spot.Id, spot.Position, egg, info,
		bonus and {Bonus = true, Zone = spot.Zone} or {SpotId = spot.Id, Zone = spot.Zone})
	prompt.Triggered:Connect(onPickup(pool, item, function()
		pool.UsedSpots[spot.Id] = nil
		if not bonus then spawnSpot(pool) end
	end, proxy))
	if not bonus then countIn(pool, item, spot.Zone) end
	item.Parent = pool.Folder
	return item
end

-- an egg on a floating sky island: the higher the island, the better the odds
spawnIslandEgg = function(pool, island)
	if pools[pool.Planet] ~= pool then return end
	local band = Config.SkyIslands.Bands[island.Band]
	local info = rollEgg(nil, pool.Planet, 3, band.Rare, band.Super)
	if not info then return end
	local egg = {EggId = info.Id, Scale = rollSize(), Mutation = rollMutation(nil, pool.Planet)}
	local point = ctx.SkyPaths.EggPoint(pool.Planet, island, workspace:GetServerTimeNow())
	local item, proxy, prompt = makePickup(pool, "SkyEgg_" .. island.Id, point, egg, info, {IslandId = island.Id})
	prompt.Triggered:Connect(onPickup(pool, item, function()
		if rng:NextNumber() < band.Chance then spawnIslandEgg(pool, island) end
	end, proxy))
	item.Parent = pool.Folder
	pool.Islands[item] = proxy   -- (the server moves its prompt part along with the island, see Init)
	return item
end

-- an egg knocked out of someone's hands lies where they stood, for anyone to grab
spawnDropped = function(pool, egg, position)
	local info = Config.Eggs[egg.EggId]
	if not info or pools[pool.Planet] ~= pool then return end
	local item, proxy, prompt = makePickup(pool, "Dropped_" .. egg.EggId, position, egg, info, {Dropped = true})
	prompt.Triggered:Connect(onPickup(pool, item, nil, proxy))
	item.Parent = pool.Folder
	return item
end

local function fillPool(pool)
	pool.UsedSpots = {}
	pool.Counts, pool.Total = {}, 0
	pool.Generation += 1
	-- (v36) a few dozen at once, the rest a batch per frame: hundreds of eggs (models, labels, prompts) built in one
	-- frame made the server hitch whenever someone landed or the maps reset
	local total = targetCount(pool)
	for _ = 1, math.min(total, 40) do spawnSpot(pool) end
	if total > 40 then
		local generation = pool.Generation
		task.spawn(function()
			for i = 41, total do
				if pools[pool.Planet] ~= pool or pool.Generation ~= generation then return end
				spawnSpot(pool)
				if i % 12 == 0 then task.wait() end
			end
		end)
	end
	for _, island in ipairs(ctx.SkyPaths.Islands(pool.Planet, pool.Seed)) do
		if rng:NextNumber() < Config.SkyIslands.Bands[island.Band].Chance then spawnIslandEgg(pool, island) end
	end
end
local function ensurePool(planetId)
	local pool = pools[planetId]
	if pool then
		-- a newcomer: top the ground eggs up for one more explorer
		for _ = groundCount(pool) + 1, targetCount(pool) do spawnSpot(pool) end
		return pool
	end
	local folder = Instance.new("Folder")
	folder.Name = planetId
	folder:SetAttribute("Planet", planetId)
	folder.Parent = ctx.pickups
	pool = {Planet = planetId, Folder = folder, Seed = ctx.mapSeed(), UsedSpots = {}, Generation = 0, Counts = {}, Total = 0,
		Islands = setmetatable({}, {__mode = "k"})}
	pools[planetId] = pool
	fillPool(pool)
	if ctx.OnPoolReady then task.spawn(ctx.OnPoolReady, planetId) end
	return pool
end
-- nobody left on the planet: its eggs go away a little later (a quick return finds them still there)
local function releasePool(planetId)
	task.delay(20, function()
		local pool = pools[planetId]
		if pool and #explorers(planetId) == 0 then
			pools[planetId] = nil
			pool.Folder:Destroy()
		end
	end)
end

-- drop a carried planet egg on the ground at the explorer's feet
local function dropCarry(profile, position)
	local expedition = profile.Expedition
	local egg = expedition and expedition.CarryingEgg
	if not egg then return end
	expedition.CarryingEgg = nil
	Expeditions.ClearCarry(profile)
	local pool = pools[expedition.Planet]
	-- (the root part of a character that just died still says where they fell)
	local character = profile.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local at = position or (root and root.Position - Vector3.new(0, 3, 0))
	if pool and at then spawnDropped(pool, egg, at) end
	ctx.markDirty(profile)
end
Expeditions.DropCarry = dropCarry

-- a bat hit: `taker` takes the planet egg out of `victim`'s hands (or it drops if they can't hold it)
function Expeditions.TakeCarry(victim, taker)
	local expedition = victim.Expedition
	local egg = expedition and expedition.CarryingEgg
	if not egg then return false end
	local sameWorld = taker.Expedition and taker.Expedition.Planet == expedition.Planet
	if sameWorld and not roomFor(taker) then
		expedition.CarryingEgg = nil
		Expeditions.ClearCarry(victim)
		giveCarry(taker, egg, false)
		ctx.notice(taker, "You snatched " .. Config.EggDisplayName(egg) .. "! Get it to your rocket!", "Gold")
		ctx.notice(victim, taker.Player.DisplayName .. " knocked your egg away!", "Red")
		ctx.markDirty(victim)
	else
		dropCarry(victim)
		ctx.notice(victim, "Your egg was knocked out of your hands!", "Red")
	end
	return true
end

-- (v30) a bot's bat hit: the egg leaves the victim's hands (the bot carries it now)
function Expeditions.BotSnatch(victim, botName)
	local expedition = victim.Expedition
	local egg = expedition and expedition.CarryingEgg
	if not egg then return nil end
	if egg.GoldenRace then
		-- (v41) the bots never run off with the Golden Egg: it falls to the ground for the players to fight over
		dropCarry(victim)
		ctx.notice(victim, tostring(botName) .. " knocked the Golden Egg out of your hands!", "Red")
		return nil
	end
	expedition.CarryingEgg = nil
	Expeditions.ClearCarry(victim)
	ctx.notice(victim, tostring(botName) .. " knocked your egg away!", "Red")
	ctx.markDirty(victim)
	return egg
end
-- (v30) an egg falls out of a bot's hands onto the planet, for anyone to grab
function Expeditions.DropEggAt(planetId, egg, position)
	local pool = pools[planetId]
	if pool and egg and position then return spawnDropped(pool, egg, position) end
end

-- ---------------------------------------------------------------- event hooks
function Expeditions.ActivePlanets()
	local list = {}
	for planetId, pool in pairs(pools) do
		if pool.Folder.Parent and #explorers(planetId) > 0 then table.insert(list, planetId) end
	end
	table.sort(list)
	return list
end
-- every egg lying on a planet right now
function Expeditions.PlanetEggs(planetId)
	local list = {}
	local pool = pools[planetId]
	if pool then
		for _, item in ipairs(pool.Folder:GetChildren()) do
			if pickupEggs[item] then table.insert(list, item) end
		end
	end
	return list
end
function Expeditions.PickupEgg(item) return pickupEggs[item] end
-- (v29) a bot explorer takes an egg: it is gone from the pool and a new one appears somewhere, as for a player
function Expeditions.BotTake(item)
	local pool = pools[item:GetAttribute("Planet") or ""]
	if not pool or not pickupEggs[item] then return end
	local egg = pickupEggs[item]
	pickupEggs[item] = nil
	local spot = item:GetAttribute("SpotId")
	if spot then pool.UsedSpots[spot] = nil end
	local near = item:GetAttribute("Near")
	uncount(pool, item)
	item:Destroy()
	local generation = pool.Generation
	if not near then
		task.delay(rng:NextNumber(Config.EggRespawn[1], Config.EggRespawn[2]), function()
			if pools[pool.Planet] == pool and pool.Generation == generation then spawnSpot(pool) end
		end)
	end
	return egg
end
-- (v35) a bot explorer (its profile: Bots.lua) picks a planet egg up into its hands, like a player's prompt does
function Expeditions.BotPickup(profile, item)
	local expedition = profile.Expedition
	local root = ctx.root(profile.Player)
	local proxy = item and item:FindFirstChild("Pickup")
	if not expedition or not root or not proxy or not item.Parent or roomFor(profile) then return false end
	local pool = pools[item:GetAttribute("Planet") or ""]
	if pool and (root.Position - pickupPoint(pool, item, proxy)).Magnitude > Config.PickupDistance * (Config.PromptReach or 1) + 4 then return false end
	local dropped = item:GetAttribute("Dropped") == true
	local egg = Expeditions.BotTake(item)
	if not egg then return false end
	giveCarry(profile, egg, not dropped)
	return true
end
-- (v35) a bot is home from a planet: what it brought goes into its backpack (and the planet's bonus, like a safe return)
function Expeditions.BotEnd(profile)
	local expedition = profile.Expedition
	if not expedition then return end
	profile.Expedition = nil
	Expeditions.ClearCarry(profile)
	local planet = Config.Planets[expedition.Planet]
	for _, egg in ipairs(expedition.Eggs) do
		if #profile.Data.Eggs < Config.MaxStoredEggs then
			table.insert(profile.Data.Eggs, {Id = egg.Id or Data.Guid(), EggId = egg.EggId, Scale = egg.Scale, Mutation = egg.Mutation, FastGrow = egg.FastGrow})
			profile.Data.DiscoveredEggs[egg.EggId] = true
		end
	end
	if #expedition.Eggs > 0 and planet then profile.Data.Coins += planet.Reward or 0 end
	profile.Data.Stats.Expeditions += 1
	profile.Oxygen = ctx.maxOxygen(profile)
end

-- (v29) take a pickup off the planet (Pumpkin Night's leftovers)
function Expeditions.RemovePickup(item)
	pickupEggs[item] = nil
	local pool = pools[item:GetAttribute("Planet") or ""]
	local spot = item:GetAttribute("PumpkinSpot")
	if pool and spot then pool.UsedSpots[spot] = nil end
	uncount(pool, item)
	item:Destroy()
end
-- a meteor (or golden light) upgrades an egg lying on a planet: next mutation tier, or `to`
function Expeditions.UpgradePickup(item, to)
	local egg = pickupEggs[item]
	if not egg or not item.Parent then return false end
	local order = {}
	for i, m in ipairs(Config.MutationList) do order[m.Id] = i end
	local current = order[egg.Mutation or "Normal"] or 1
	local target = to and order[to] or math.min(#Config.MutationList, current + 1)
	if target <= current then return false end
	egg.Mutation = Config.MutationList[target].Id
	-- rebuild the egg visual with the new mutation on the same spot
	local old = item:FindFirstChild("Visual")
	local proxy = item:FindFirstChild("Pickup")
	local template = ctx.eggTemplate(egg.EggId)
	if old and template and proxy then
		local bounds, size = ModelUtil.VisibleBounds(old)
		local bottom = bounds.Position - Vector3.new(0, size.Y / 2, 0)
		local visual = template:Clone()
		ModelUtil.PrepareVisual(visual, true)
		local rarity = Config.Eggs[egg.EggId] and Config.Eggs[egg.EggId].Rarity
		ModelUtil.FitTo(visual, Config.PlanetEggSize(rarity, egg.Scale))
		ModelUtil.ApplyMutation(visual, egg.Mutation)
		visual.Name = "Visual"
		ModelUtil.PlaceOnGround(visual, bottom, rng:NextNumber(0, math.pi * 2))
		ModelUtil.AttachEggFX(visual, rarity, egg.Scale)
		old:Destroy()
		visual.Parent = item
		item:SetAttribute("VisualOffset", proxy.CFrame:ToObjectSpace(visual:GetPivot()))
	end
	item:SetAttribute("Mutation", egg.Mutation)
	local title = egg.GoldenRace and "THE GOLDEN EGG" or Config.EggDisplayName(egg)
	local label = item:FindFirstChild("PFELabel")
	if label then label.Title.Text = title end
	local prompt = proxy and proxy:FindFirstChild("CollectPickup")
	if prompt then prompt.ObjectText = title end
	return true, egg
end
-- (v30) eggs follow the explorer: keep Config.NearEggs.Min eggs within Radius of `position` (free hiding spots
-- first, else a bare patch of ground - the planets are flat), and clear the extras nobody is near any more
local GRID = 100
local spotGrids = setmetatable({}, {__mode = "k"})
-- (v30) only the hiding spots in the grid cells round a point (a 5x planet has thousands of spots); (v41) shared by
-- everything that lays an egg near somebody, never on the landing pad
local function spotsAround(pool, layout, position, minD, maxD)
	local grid = spotGrids[layout]
	if not grid then
		grid = {}
		for _, spot in ipairs(layout.Spots) do
			local key = math.floor(spot.Position.X / GRID) .. ":" .. math.floor(spot.Position.Z / GRID)
			local cell = grid[key]
			if not cell then cell = {}; grid[key] = cell end
			table.insert(cell, spot)
		end
		spotGrids[layout] = grid
	end
	local here = Vector2.new(position.X, position.Z)
	local list = {}
	local cx, cz = math.floor(position.X / GRID), math.floor(position.Z / GRID)
	local reach = math.ceil(maxD / GRID)
	for gx = cx - reach, cx + reach do
		for gz = cz - reach, cz + reach do
			for _, spot in ipairs(grid[gx .. ":" .. gz] or {}) do
				local d = (Vector2.new(spot.Position.X, spot.Position.Z) - here).Magnitude
				if d > minD and d < maxD and not pool.UsedSpots[spot.Id] and not nearRocket(layout.Origin, spot.Position) then
					table.insert(list, spot)
				end
			end
		end
	end
	return list
end
local function spawnNear(pool, position)
	local cfg = Config.NearEggs
	local layout = ctx.PlanetGen.Generate(pool.Planet, pool.Seed)
	if not layout or pools[pool.Planet] ~= pool then return nil end
	local candidates = spotsAround(pool, layout, position, cfg.Inner, cfg.Radius)
	local spot = candidates[rng:NextInteger(1, math.max(1, #candidates))]
	local point, zone, key
	if spot then
		point, zone, key = spot.Position, spot.Zone, spot.Id
		pool.UsedSpots[key] = true
	else
		local origin = layout.Origin
		for _ = 1, 12 do
			local angle, dist = rng:NextNumber(0, math.pi * 2), rng:NextNumber(cfg.Inner + 8, cfg.Radius - 10)
			local flat = Vector3.new(position.X - origin.X + math.cos(angle) * dist, 0, position.Z - origin.Z + math.sin(angle) * dist)
			local fromCenter = flat.Magnitude
			if fromCenter > math.max(60, cfg.RocketClear or 0) and fromCenter < layout.Radius - 8 then
				point, zone = origin + flat, ctx.PlanetGen.ZoneOf(fromCenter, layout.Radius)
				break
			end
		end
		if not point then return nil end
	end
	local info = rollEgg(nil, pool.Planet, zone)
	if not info then if key then pool.UsedSpots[key] = nil end; return nil end
	local egg = {EggId = info.Id, Scale = rollSize(), Mutation = rollMutation(nil, pool.Planet)}
	local opts = {Near = true, Zone = zone}
	if key then opts.SpotId = key end
	local item, proxy, prompt = makePickup(pool, "Near_" .. tostring(key or rng:NextInteger(1, 1e9)), point, egg, info, opts)
	prompt.Triggered:Connect(onPickup(pool, item, function() if key then pool.UsedSpots[key] = nil end end, proxy))
	item.Parent = pool.Folder
	return item
end
local function topUpNear(profile)
	local cfg = Config.NearEggs
	local expedition = profile.Expedition
	local pool = expedition and pools[expedition.Planet]
	local root = ctx.root(profile.Player)
	if not pool or not root or profile.Busy or expedition.Planet ~= profile.Planet or profile.InCave then return end
	-- (v41) by the rocket nothing is topped up: the explorers have to go out for their eggs
	local planet = Config.Planets[pool.Planet]
	if planet and nearRocket(planet.Origin, root.Position) then return end
	local here = Vector2.new(root.Position.X, root.Position.Z)
	local near, extras = 0, 0
	for _, item in ipairs(pool.Folder:GetChildren()) do
		local proxy = item:FindFirstChild("Pickup")
		if proxy and not item:GetAttribute("IslandId") then
			if (Vector2.new(proxy.Position.X, proxy.Position.Z) - here).Magnitude < cfg.Radius then near += 1 end
			if item:GetAttribute("Near") then extras += 1 end
		end
	end
	local limit = cfg.MaxPerExplorer * math.max(1, #explorers(pool.Planet))
	for _ = 1, math.min(cfg.PerTick, cfg.Min - near, limit - extras) do spawnNear(pool, root.Position) end
end
local function clearFarNear(pool)
	local cfg = Config.NearEggs
	local people = {}
	for _, p in ipairs(explorers(pool.Planet)) do
		local root = ctx.root(p.Player)
		if root then table.insert(people, Vector2.new(root.Position.X, root.Position.Z)) end
	end
	for _, item in ipairs(pool.Folder:GetChildren()) do
		local proxy = item:FindFirstChild("Pickup")
		if item:GetAttribute("Near") and proxy then
			local at, close = Vector2.new(proxy.Position.X, proxy.Position.Z), false
			for _, spot in ipairs(people) do if (spot - at).Magnitude < cfg.Cleanup then close = true; break end end
			if not close then
				pickupEggs[item] = nil
				local key = item:GetAttribute("SpotId")
				if key then pool.UsedSpots[key] = nil end
				item:Destroy()
			end
		end
	end
end
Expeditions.TopUpNear = topUpNear

-- Egg Storm: an extra egg (beyond the usual count) on a free hiding spot of that planet
function Expeditions.SpawnBonusEgg(planetId)
	local pool = pools[planetId]
	if not pool then return nil end
	return spawnSpot(pool, true)
end

-- (v29) Pumpkin Night: a carved jack-o-lantern next to the egg (plain parts, lit, a few ghostly wisps)
local function addPumpkin(item, point)
	local model = Instance.new("Model")
	model.Name = "Pumpkin"
	local base = CFrame.new(point) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.new(0, 0, 3.4)
	local function block(name, size, cf, color, material)
		local p = Instance.new("Part")
		p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.TopSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local orange, dark = Color3.fromRGB(255, 130, 30), Color3.fromRGB(220, 96, 20)
	block("Body", Vector3.new(3.6, 2.8, 3.2), base * CFrame.new(0, 1.4, 0), orange)
	block("RibL", Vector3.new(0.8, 2.4, 3.0), base * CFrame.new(-1.9, 1.4, 0), dark)
	block("RibR", Vector3.new(0.8, 2.4, 3.0), base * CFrame.new(1.9, 1.4, 0), dark)
	block("Top", Vector3.new(2.8, 0.5, 2.6), base * CFrame.new(0, 2.95, 0), orange)
	block("Stem", Vector3.new(0.5, 0.9, 0.5), base * CFrame.new(0, 3.5, 0), Color3.fromRGB(90, 140, 50))
	local glow = Color3.fromRGB(255, 230, 90)
	for _, spec in ipairs({{-0.8, 1.9}, {0.8, 1.9}}) do
		block("Eye", Vector3.new(0.6, 0.6, 0.1), base * CFrame.new(spec[1], spec[2], -1.62), glow, Enum.Material.Neon)
	end
	block("Mouth", Vector3.new(2.0, 0.4, 0.1), base * CFrame.new(0, 1.05, -1.62), glow, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 50); light.Range = 14; light.Brightness = 2.2; light.Parent = model.Body
	local wisp = Instance.new("ParticleEmitter")
	wisp.Texture = "rbxasset://textures/particles/smoke_main.dds"; wisp.Rate = 4; wisp.Lifetime = NumberRange.new(1.5, 2.5)
	wisp.Speed = NumberRange.new(1, 2.5); wisp.Size = NumberSequence.new(1.2, 2.4); wisp.Transparency = NumberSequence.new(0.5, 1)
	wisp.Color = ColorSequence.new(Color3.fromRGB(170, 110, 255)); wisp.LightEmission = 0.6; wisp.Parent = model.Body
	model.Parent = item
end

-- (v29) Pumpkin Night: an egg (3x luck, a mutation step up) in a jack-o-lantern on a hiding spot near `near`
function Expeditions.SpawnPumpkinEgg(planetId, near)
	local pool = pools[planetId]
	if not pool or not near then return nil end
	local layout = ctx.PlanetGen.Generate(pool.Planet, pool.Seed)
	if not layout then return nil end
	-- the free hiding spots 18-110 studs away (a random one of them; v41: from the grid cells round you, not the whole map)
	local candidates = spotsAround(pool, layout, near, 18, 110)
	local best = candidates[rng:NextInteger(1, math.max(1, #candidates))]
	if not best then return nil end
	pool.UsedSpots[best.Id] = true
	local info = rollEgg(nil, pool.Planet, best.Zone, 3)
	if not info then pool.UsedSpots[best.Id] = nil; return nil end
	local mutation = rollMutation(nil, pool.Planet)
	for i, m in ipairs(Config.MutationList) do
		if m.Id == mutation then mutation = (Config.MutationList[i + 1] or m).Id; break end
	end
	local egg = {EggId = info.Id, Scale = rollSize(), Mutation = mutation}
	local item, proxy, prompt = makePickup(pool, "Pumpkin_" .. best.Id, best.Position, egg, info, {Bonus = true, Pumpkin = true, Zone = best.Zone})
	addPumpkin(item, best.Position)
	item:SetAttribute("PumpkinSpot", best.Id)
	prompt.Triggered:Connect(onPickup(pool, item, function() pool.UsedSpots[best.Id] = nil end, proxy))
	item.Parent = pool.Folder
	return item
end

-- ---------------------------------------------------------------- (v41) eggs made by the weather, the bosses, caves...
-- An egg lying at `position` on `planetId` (any point: a crater, a cave, where a crystal broke), rolled for that planet
-- with opts: Zone (distance ring 1-5 for the odds, default 3), Boost (rare boost, like the sky islands), Super (chance of
-- the chase egg), MinMutation ("Golden"...: at least that), MutationStep (n tiers up), Life (seconds before it fades),
-- Name / Tag (attributes). Returns the pickup (nil when nobody explores that planet: no pool).
function Expeditions.HasPool(planetId) return pools[planetId] ~= nil end
function Expeditions.SpawnEventEgg(planetId, position, opts)
	local pool = pools[planetId]
	if not pool or typeof(position) ~= "Vector3" then return nil end
	opts = opts or {}
	local info = opts.EggId and Config.Eggs[opts.EggId] or rollEgg(nil, pool.Planet, opts.Zone or 3, opts.Boost, opts.Super)
	if not info then return nil end
	local mutation = rollMutation(nil, pool.Planet)
	local order = {}
	for i, m in ipairs(Config.MutationList) do order[m.Id] = i end
	local tier = order[mutation] or 1
	if opts.MutationStep then tier = math.min(#Config.MutationList, tier + opts.MutationStep) end
	if opts.MinMutation and order[opts.MinMutation] then tier = math.max(tier, order[opts.MinMutation]) end
	local egg = {EggId = info.Id, Scale = opts.Scale or rollSize(), Mutation = Config.MutationList[tier].Id, GoldenRace = opts.GoldenRace}
	local attributes = {Bonus = true, Zone = opts.Zone or 3}
	if opts.Tag then attributes.EventTag = opts.Tag end
	if opts.Keep then attributes.Keep = true end
	local item, proxy, prompt = makePickup(pool, opts.Name or ("EventEgg_" .. rng:NextInteger(1, 1e9)), position, egg, info, attributes)
	prompt.Triggered:Connect(onPickup(pool, item, nil, proxy))
	item.Parent = pool.Folder
	if opts.Life then
		local generation = pool.Generation
		task.delay(opts.Life, function()
			if item.Parent and pickupEggs[item] and pools[planetId] == pool and pool.Generation == generation then
				for _, other in pairs(ctx.profiles) do
					if other.Planet == planetId then ctx.effect(other.Player, "EventStrike", {Kind = "Vanish", Position = proxy.Position, Delay = 0}) end
				end
				pickupEggs[item] = nil
				item:Destroy()
			end
		end)
	end
	return item
end
-- the race's Golden Egg (PlanetLife): `egg` is the record ({EggId, Scale, Mutation, GoldenRace = true}) lying at `position`
function Expeditions.SpawnGoldenEgg(planetId, position, egg)
	local pool = pools[planetId]
	local info = egg and Config.Eggs[egg.EggId]
	if not pool or not info then return nil end
	local item, proxy, prompt = makePickup(pool, "GoldenEgg", position, egg, info, {Bonus = true, Zone = 5})
	prompt.HoldDuration = 0.5
	prompt.Triggered:Connect(onPickup(pool, item, nil, proxy))
	item.Parent = pool.Folder
	return item
end
-- (the Golden Egg leaves a planet everybody left: it waits for the next explorer, out of the pool)
function Expeditions.TakeOutPickup(item)
	local egg = pickupEggs[item]
	pickupEggs[item] = nil
	if item.Parent then item:Destroy() end
	return egg
end

-- ---------------------------------------------------------------- platform & expedition end
local function onRocketPlatform(profile)
	local characterRoot = ctx.root(profile.Player)
	local planet = profile.Expedition and planetModel(profile.Expedition.Planet)
	if not characterRoot or not planet then return false end
	local pad = planet:FindFirstChild("LandingDeck")
	if pad and pad:IsA("BasePart") then
		local point = pad.CFrame:PointToObjectSpace(characterRoot.Position)
		if pad:IsA("Part") and pad.Shape == Enum.PartType.Cylinder then
			local ry, rz = pad.Size.Y * 0.5, pad.Size.Z * 0.5
			return (point.Y / ry) ^ 2 + (point.Z / rz) ^ 2 <= 1 and math.abs(point.X) <= pad.Size.X * 0.5 + 8
		end
		return math.abs(point.X) <= pad.Size.X * 0.5 + 1 and math.abs(point.Z) <= pad.Size.Z * 0.5 + 1 and math.abs(point.Y) <= pad.Size.Y * 0.5 + 8
	end
	local landing = planet:FindFirstChild("Landing")
	return landing ~= nil and (characterRoot.Position - landing.Position).Magnitude <= 16
end

local function loadCarriedEgg(profile)
	local expedition = profile.Expedition
	if not expedition or not expedition.CarryingEgg or profile.Busy or not onRocketPlatform(profile) then return false end
	if #expedition.Eggs >= ctx.capacity(profile) then return false end
	local loaded = expedition.CarryingEgg
	table.insert(expedition.Eggs, loaded)
	expedition.CarryingEgg = nil
	Expeditions.ClearCarry(profile)
	profile.Data.TutorialStep = math.max(profile.Data.TutorialStep, 5)
	ctx.notice(profile, "Egg loaded " .. #expedition.Eggs .. "/" .. ctx.capacity(profile), "Green")
	if loaded.GoldenRace then
		loaded.GoldenRace = nil   -- (it is an ordinary egg of this rocket from now on)
		if ctx.GoldenEggSecured then task.spawn(ctx.GoldenEggSecured, profile, loaded) end
	end
	ctx.effect(profile.Player, "EggLoaded", {})
	ctx.markDirty(profile)
	return true
end

-- (v35) a bot on its landing pad puts the egg in its hands into the rocket
function Expeditions.BotLoad(profile)
	return loadCarriedEgg(profile)
end

function Expeditions.EndExpedition(profile, success, reason)
	local expedition = profile.Expedition
	if not expedition or profile.Busy then return end
	profile.Expedition = nil
	Expeditions.ClearCarry(profile)
	releasePool(expedition.Planet)
	local eggs = Data.Copy(expedition.Eggs)
	if not success and #eggs > 0 then table.remove(eggs, rng:NextInteger(1, #eggs)) end
	local planet = Config.Planets[expedition.Planet]
	local bonus = success and #eggs > 0 and planet.Reward or 0
	profile.Result = {Success = success, Planet = expedition.Planet, Eggs = #eggs, Coins = bonus, Reason = reason}
	profile.Data.Stats.Expeditions += 1
	fly(profile, "Base", function()
		profile.Planet = "Base"
		profile.Oxygen = ctx.maxOxygen(profile)
		for _, egg in ipairs(eggs) do
			if #profile.Data.Eggs < Config.MaxStoredEggs then
				table.insert(profile.Data.Eggs, {Id = egg.Id, EggId = egg.EggId, Scale = egg.Scale, Mutation = egg.Mutation, FastGrow = egg.FastGrow})
			end
		end
		profile.Data.Coins += bonus
		profile.Data.TutorialStep = math.max(profile.Data.TutorialStep, #eggs > 0 and 6 or profile.Data.TutorialStep)
		ctx.teleport(profile, profile.Base:FindFirstChild("Spawn"))
		ctx.publishTracker(profile)
		if success then
		else
			ctx.notice(profile, "Rescued! You lost one item.", "Red")
		end
		ctx.markDirty(profile)
	end)
end

-- straight home without the flight (joining the Meteor Run from a planet): the egg in the hands is
-- lost, the eggs already loaded into the rocket come home like after a safe return. Returns the lost egg.
function Expeditions.EndNow(profile)
	local expedition = profile.Expedition
	if not expedition or profile.Busy then return false end
	local lost = expedition.CarryingEgg
	expedition.CarryingEgg = nil
	profile.Expedition = nil
	Expeditions.ClearCarry(profile)
	releasePool(expedition.Planet)
	local planet = Config.Planets[expedition.Planet]
	local eggs = Data.Copy(expedition.Eggs)
	local bonus = #eggs > 0 and planet and planet.Reward or 0
	profile.Data.Stats.Expeditions += 1
	profile.Planet = "Base"
	profile.Oxygen = ctx.maxOxygen(profile)
	for _, egg in ipairs(eggs) do
		if #profile.Data.Eggs < Config.MaxStoredEggs then
			table.insert(profile.Data.Eggs, {Id = egg.Id, EggId = egg.EggId, Scale = egg.Scale, Mutation = egg.Mutation, FastGrow = egg.FastGrow})
		end
	end
	profile.Data.Coins += bonus
	if #eggs > 0 then ctx.notice(profile, #eggs .. (#eggs == 1 and " egg" or " eggs") .. " from your rocket went home.", "Green") end
	ctx.publishTracker(profile)
	ctx.markDirty(profile)
	return true, lost
end

local function launchTo(profile, destination)
	profile.Result = nil
	profile.Data.TutorialStep = math.max(profile.Data.TutorialStep, 3)
	fly(profile, destination, function()
		profile.Planet = destination
		profile.Oxygen = ctx.maxOxygen(profile)
		profile.Expedition = {Planet = destination, Eggs = {}, Id = Data.Guid(), UsedSpots = {}, Seed = ctx.mapSeed()}
		profile.WarnLow, profile.WarnCritical = false, false
		profile.Data.VisitedPlanets[destination] = true
		local planet = planetModel(destination)
		ctx.teleport(profile, planet and planet:FindFirstChild("Landing"), Vector3.new(0, 4, 0))
		ensurePool(destination)
		ctx.publishTracker(profile)
		ctx.markDirty(profile)
	end)
end

-- a new map cycle: every planet's eggs move to the new hiding spots (carried and dropped eggs stay)
function Expeditions.ResetPools()
	for planetId, pool in pairs(pools) do
		pool.Seed = ctx.mapSeed()
		for _, item in ipairs(pool.Folder:GetChildren()) do
			-- (v41: Keep - the Golden Egg of the race - stays where it is too)
			if not item:GetAttribute("Dropped") and not item:GetAttribute("Keep") then pickupEggs[item] = nil; item:Destroy() end
		end
		fillPool(pool)
		for _, profile in ipairs(explorers(planetId)) do
			profile.Expedition.Seed = pool.Seed
			ctx.notice(profile, "The planet changed! New eggs are hidden.", "Purple")
			ctx.markDirty(profile)
		end
	end
end
function Expeditions.OnMapReset(_profile) end

function Expeditions.RequestLaunch(profile, destination)
	if type(destination) ~= "string" then return end
	if destination == "Earth" or destination == "Base" then Expeditions.RequestReturn(profile); return end
	local planet = Config.Planets[destination]
	if not planet then return end
	if profile.Planet ~= "Base" then ctx.notice(profile, "Fly home before visiting another planet."); return end
	if profile.Stolen then ctx.notice(profile, "You can't launch while carrying a stolen egg!", "Red"); return end
	if not ctx.near(profile, profile.Base:FindFirstChild("Launch"), Config.InteractionDistance + 6) then
		ctx.notice(profile, "Go to your rocket to launch."); return
	end
	local range = Config.Rockets[profile.Data.RocketLevel].Range
	if range < planet.RequiredRange and not (ctx.devMode and profile.DevTravel) then
		ctx.notice(profile, "Upgrade your rocket first!", "Red"); return
	end
	launchTo(profile, destination)
end

function Expeditions.RequestReturn(profile)
	local expedition = profile.Expedition
	if not expedition then return end
	local planet = planetModel(expedition.Planet)
	if not planet or not ctx.near(profile, planet:FindFirstChild("Landing"), Config.SafeRadius + 10) then
		ctx.notice(profile, "Return to your rocket landing pad to fly home."); return
	end
	loadCarriedEgg(profile)
	if expedition.CarryingEgg then ctx.notice(profile, "Your cargo is full - drop into the rocket first or upgrade cargo.", "Red"); return end
	Expeditions.EndExpedition(profile, true, "Safe return")
end

-- ---------------------------------------------------------------- upgrades
function Expeditions.Upgrade(profile, kind)
	if profile.Planet ~= "Base" or not ctx.near(profile, profile.Base:FindFirstChild("Spawn"), Config.BaseInteractionDistance) then
		ctx.notice(profile, "Return to your base to upgrade."); return
	end
	local data = profile.Data
	if kind == "Suit" then
		local nextSuit = Config.Suits[data.SuitLevel + 1]
		if not nextSuit then ctx.notice(profile, "Your suit is fully upgraded."); return end
		if data.Coins < nextSuit.Cost then ctx.notice(profile, "You need " .. Config.Format(nextSuit.Cost) .. " coins.", "Red"); return end
		data.Coins -= nextSuit.Cost; data.SuitLevel += 1
		profile.Oxygen = ctx.maxOxygen(profile)
		ctx.notice(profile, nextSuit.Name .. " helmet equipped!", "Purple")
		profile.Player:SetAttribute("PFESuitLevel", data.SuitLevel)
	elseif kind == "Rocket" then
		local nextRocket = Config.Rockets[data.RocketLevel + 1]
		if not nextRocket then ctx.notice(profile, "Your rocket is fully upgraded."); return end
		if data.Coins < nextRocket.Cost then ctx.notice(profile, "You need " .. Config.Format(nextRocket.Cost) .. " coins.", "Red"); return end
		data.Coins -= nextRocket.Cost
		data.RocketLevel += 1
		profile.Base:SetAttribute("RocketLevel", data.RocketLevel)
		local unlocked = {}
		for _, planet in ipairs(Config.PlanetOrder) do if planet.RequiredRange == data.RocketLevel then table.insert(unlocked, planet.Name) end end
		ctx.notice(profile, nextRocket.Name .. " ready!" .. (#unlocked > 0 and (" " .. table.concat(unlocked, ", ") .. " unlocked!") or ""), "Gold")
		ctx.effect(profile.Player, "RocketUpgrade", {Level = data.RocketLevel})
	elseif kind == "Jetpack" then
		local nextPack = Config.Jetpacks[data.JetpackLevel + 1]
		if not nextPack then ctx.notice(profile, "Your jetpack is fully upgraded."); return end
		if data.Coins < nextPack.Cost then ctx.notice(profile, "You need " .. Config.Format(nextPack.Cost) .. " coins.", "Red"); return end
		data.Coins -= nextPack.Cost; data.JetpackLevel += 1
		ctx.Gear.AttachJetpack(profile)
		ctx.notice(profile, nextPack.Name .. " jetpack: " .. nextPack.FlightTime .. "s of flight!", "Blue")
	elseif kind == "Cargo" then
		local nextCargo = Config.Cargo[data.CargoLevel + 1]
		if not nextCargo then ctx.notice(profile, "Your cargo bay is fully upgraded."); return end
		if data.Coins < nextCargo.Cost then ctx.notice(profile, "You need " .. Config.Format(nextCargo.Cost) .. " coins.", "Red"); return end
		data.Coins -= nextCargo.Cost; data.CargoLevel += 1
		ctx.notice(profile, nextCargo.Name .. " installed!", "Blue")
	end
	data.TutorialStep = math.max(data.TutorialStep, 7)
	ctx.markDirty(profile)
end

function Expeditions.UseOxygenTank(profile)
	if not profile.Expedition or profile.Data.OxygenTanks <= 0 then return end
	profile.Data.OxygenTanks -= 1
	profile.Oxygen = ctx.maxOxygen(profile)
	profile.WarnLow, profile.WarnCritical = false, false
	ctx.notice(profile, "Air refilled!", "Blue")
	ctx.markDirty(profile)
end

-- ---------------------------------------------------------------- lifecycle
function Expeditions.OnCharacterReset(profile)
	profile.FlightToken += 1; profile.Busy = false; profile.Sprinting = false
	if profile.Expedition then
		profile.Result = {Success = false, Planet = profile.Expedition.Planet, Eggs = 0, Coins = 0, Reason = "Respawn: expedition cargo lost"}
		ctx.notice(profile, "Expedition cargo was lost. Your eggs at home are safe.", "Red")
		profile.Data.Stats.EggsLost += #profile.Expedition.Eggs
	end
	local planetId = profile.Expedition and profile.Expedition.Planet
	if profile.Expedition then dropCarry(profile) end
	profile.Expedition = nil
	Expeditions.ClearCarry(profile)
	if planetId then releasePool(planetId) end
	profile.Planet = "Base"
	profile.Oxygen = ctx.maxOxygen(profile)
	profile.Player:SetAttribute("PFESuitLevel", profile.Data.SuitLevel)
	ctx.markDirty(profile)
end
function Expeditions.OnDied(profile)
	profile.FlightToken += 1; profile.Busy = false
	if profile.Expedition then
		local planetId = profile.Expedition.Planet
		profile.Result = {Success = false, Planet = planetId, Eggs = 0, Coins = 0, Reason = profile.DeathReason or "You ran out of air"}
		profile.Data.Stats.EggsLost += #profile.Expedition.Eggs
		dropCarry(profile)
		profile.Expedition = nil
		Expeditions.ClearCarry(profile)
		releasePool(planetId)
	end
	profile.DeathReason = nil
	profile.Planet = "Base"
end
function Expeditions.OnPlayerLeaving(profile)
	local planetId = profile.Expedition and profile.Expedition.Planet
	if profile.Expedition then dropCarry(profile) end
	Expeditions.ClearCarry(profile)
	if planetId then profile.Expedition = nil; releasePool(planetId) end
end

function Expeditions.Tick(profile, dt)
	local expedition = profile.Expedition
	if not expedition or profile.Busy or not ctx.root(profile.Player) then return end
	if profile.InDungeon then return end -- the alien ships have air
	loadCarriedEgg(profile)
	profile.NearEggClock = (profile.NearEggClock or 0) + dt
	if profile.NearEggClock >= Config.NearEggs.Every then
		profile.NearEggClock = 0
		topUpNear(profile)
		local pool = pools[expedition.Planet]
		if pool and rng:NextNumber() < 0.25 then clearFarNear(pool) end
	end
	if profile.God or ctx.immortal(profile) then return end -- (;god / immortality: no air used)
	local planet = Config.Planets[expedition.Planet]
	-- (v41) the weather (a blizzard far from a campfire, a heatwave in the sun...) and the caves change how fast it goes
	local rate = planet.OxygenMultiplier * (ctx.AirMultiplier and ctx.AirMultiplier(profile) or 1)
	profile.Oxygen = math.max(0, profile.Oxygen - rate * dt)
	local maxOxygen = ctx.maxOxygen(profile)
	if profile.Oxygen <= maxOxygen * 0.12 and profile.Data.OxygenTanks > 0 then Expeditions.UseOxygenTank(profile) end
	local humanoid = ctx.humanoid(profile.Player)
	if profile.Oxygen <= Config.LowOxygenThreshold and humanoid and humanoid.Health > 0 then
		humanoid:TakeDamage(Config.LowOxygenDamagePerSecond * dt)
	end
	if profile.Oxygen <= Config.CriticalOxygenThreshold and not profile.WarnCritical then
		profile.WarnCritical = true; ctx.notice(profile, "NO OXYGEN - you are suffocating!", "Red")
	elseif profile.Oxygen <= Config.LowOxygenThreshold and not profile.WarnLow then
		profile.WarnLow = true; ctx.notice(profile, "LOW OXYGEN - get back to the rocket!", "Red")
	end
end

-- ---------------------------------------------------------------- studio tools
function Expeditions.DevAction(profile, action, argument)
	local data = profile.Data
	if action == "DevGrant" then
		data.Coins = math.max(data.Coins, 1e13)
		profile.DevTravel = true
		ctx.notice(profile, "Studio: 10T coins, every planet unlocked for travel.")
	elseif action == "DevResetMaps" then
		ctx.ResetMaps()
	elseif action == "DevReadyEggs" then
		for _, egg in ipairs(data.GrowingEggs) do egg.ReadyAt = os.time() end
		ctx.Bases.UpdateGrowing(profile)
	elseif action == "DevEggs" then
		for _, egg in ipairs(Config.EggCatalog) do
			if #data.Eggs < Config.MaxStoredEggs then
				table.insert(data.Eggs, {Id = Data.Guid(), EggId = egg.Id, Scale = 1, Mutation = "Normal"})
				data.DiscoveredEggs[egg.Id] = true
			end
		end
	elseif action == "DevPets" then
		for species, info in pairs(Config.Pets) do
			if info.Special then continue end
			table.insert(data.Pets, {Id = Data.Guid(), Species = species, Scale = 1, Mutation = "Normal"})
			data.DiscoveredPets[species] = true
		end
		ctx.Bases.RenderGarden(profile)
	elseif action == "DevPasses" then
		profile.DevPasses = not profile.DevPasses
		ctx.notice(profile, "Studio: all game passes " .. (profile.DevPasses and "ON" or "OFF"))
		ctx.setMovement(profile)
	elseif action == "DevVisit" then
		if type(argument) == "string" and Config.Planets[argument] and profile.Planet == "Base" and not profile.Busy then
			profile.DevTravel = true
			launchTo(profile, argument)
		end
	elseif action == "DevHome" then
		profile.FlightToken += 1; profile.Busy = false
		local planetId = profile.Expedition and profile.Expedition.Planet
		profile.Expedition = nil; Expeditions.ClearCarry(profile)
		if planetId then releasePool(planetId) end
		profile.Planet = "Base"
		local characterRoot = ctx.root(profile.Player)
		if characterRoot then characterRoot.Anchored = false end
		ctx.teleport(profile, profile.Base:FindFirstChild("Spawn"))
	end
	ctx.markDirty(profile)
end

function Expeditions.Init(context)
	ctx = context
	Config, Data, ModelUtil = ctx.Config, ctx.Data, ctx.ModelUtil
	ctx.Expeditions = Expeditions
	for _, planet in ipairs(Config.PlanetOrder) do
		local model = planetModel(planet.Id)
		local landing = model and model:FindFirstChild("Landing")
		if landing then
			local prompt = ctx.makePrompt(landing, "FlyHome", "Fly home", function(player)
				local profile = ctx.profiles[player]
				if profile and profile.Expedition and profile.Expedition.Planet == planet.Id and not profile.Busy then
					Expeditions.RequestReturn(profile); ctx.markDirty(profile)
				end
			end, {Hold = 0.6, Distance = 18, ObjectText = "Rocket"})
		end
	end
	for _, base in ipairs(ctx.bases:GetChildren()) do
		local launch = base:FindFirstChild("Launch")
		if launch then
			ctx.makePrompt(launch, "OpenRocketHub", "Launch", function(player)
				local profile = ctx.profiles[player]
				if profile and profile.Base == base and profile.Planet == "Base" and not profile.Busy then
					ctx.remotes.OpenMenu:FireClient(player, "RocketHub"); ctx.sendState(profile)
				end
			end, {Hold = 0.2, Distance = 16, ObjectText = "Rocket"})
		end
	end
	-- eggs on the floating islands: the server moves their prompt part along with the island too. Roblox
	-- checks a prompt's distance on the server, so a part left where the egg spawned (while the island
	-- drifted on, up to ~140 studs) made those eggs impossible to pick up.
	-- (v41: only the island eggs are walked - the pool keeps a list of them - not every egg on the planet ten times a second)
	task.spawn(function()
		while true do
			task.wait(0.1)
			for _, pool in pairs(pools) do
				for item, proxy in pairs(pool.Islands) do
					if not item.Parent or not proxy.Parent then
						pool.Islands[item] = nil
					else
						local ok, point = pcall(pickupPoint, pool, item, proxy)
						if ok and point then proxy.CFrame = CFrame.new(point) end
					end
				end
			end
		end
	end)
end

return Expeditions
