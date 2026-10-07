--!nocheck
-- (v41) The Golden Egg race: every Life.Golden.Every seconds ONE Golden Egg appears somewhere on a random planet (one
-- somebody's rocket reaches; a planet with explorers is likelier) - out in the wilds, a long run from the rocket. Everybody
-- sees where: the tracker marks the planet, workspace attributes say where it is (GoldenEggClient draws a pillar of light
-- across the planet and an arrow), the carrier glows. It is an ordinary planet egg in every other way (Expeditions): pick
-- it up, run to your rocket - and anybody can knock it out of your hands with the bat (it falls where you stood).
-- Whoever gets it into their rocket keeps it (a great egg, at least Golden) and gets a coin prize. Nobody: it fades away.
-- On a planet nobody explores the egg waits "in the air" (no pool to lie in) and lands as soon as somebody arrives.
local Players = game:GetService("Players")
local GoldenRace = {}
local ctx, Config, Life, L
local rng = Random.new()
local race     -- {Planet, Position, Egg, Item, Carrier, EndsAt, Missing}
local nextAt = 0

local function now() return workspace:GetServerTimeNow() end
local function announce(text, color)
	for _, player in ipairs(Players:GetPlayers()) do ctx.remotes.Notice:FireClient(player, text, color or "Gold") end
end

local function publish()
	workspace:SetAttribute("PFEGoldenPlanet", race and race.Planet or "")
	workspace:SetAttribute("PFEGoldenPos", race and race.Position or Vector3.zero)
	workspace:SetAttribute("PFEGoldenEndsAt", race and race.EndsAt or 0)
	workspace:SetAttribute("PFEGoldenCarrier", race and race.Carrier and race.Carrier.Player.UserId or 0)
	workspace:SetAttribute("PFEGoldenNextAt", nextAt)
end

-- everybody who can hold it: the players and the bots out on the planets
local function holders()
	local list = {}
	for _, profile in pairs(ctx.profiles) do table.insert(list, profile) end
	if ctx.Bots and ctx.Bots.Profiles then for _, profile in ipairs(ctx.Bots.Profiles()) do table.insert(list, profile) end end
	return list
end

local function stop()
	if race and race.Item and race.Item.Parent then ctx.Expeditions.TakeOutPickup(race.Item) end
	for _, profile in ipairs(holders()) do
		local carried = profile.Expedition and profile.Expedition.CarryingEgg
		if carried and carried.GoldenRace then carried.GoldenRace = nil end
	end
	race = nil
	publish()
end

-- lay the egg down where it was last seen (when its planet has a pool)
local function materialize()
	if not race or not ctx.Expeditions.HasPool(race.Planet) then return end
	race.Item = ctx.Expeditions.SpawnGoldenEgg(race.Planet, race.Position, race.Egg)
	race.Missing = 0
end

local function start()
	-- planets somebody's rocket reaches (none: nobody to race - try again later)
	local range = 0
	for _, p in pairs(ctx.profiles) do range = math.max(range, Config.Rockets[p.Data.RocketLevel] and Config.Rockets[p.Data.RocketLevel].Range or 1) end
	if range == 0 then return false end
	local options, total = {}, 0
	for _, planet in ipairs(Config.PlanetOrder) do
		if planet.RequiredRange <= range then
			local w = 1 + #L.SurfaceExplorers(planet.Id) * 2
			total += w
			table.insert(options, {planet, w})
		end
	end
	local roll = rng:NextNumber() * total
	local planet = options[#options][1]
	for _, o in ipairs(options) do
		roll -= o[2]
		if roll <= 0 then planet = o[1]; break end
	end
	-- out in the wilds: 350-1000 studs from the rocket (a race - but one the air allows there and back)
	local position = L.SpotNear(planet.Id, planet.Origin, 350, math.min(1000, (planet.Radius or 2800) - 200))
	if not position then return false end
	local G = Life.Golden
	local info = ctx.Expeditions.RollEgg(nil, planet.Id, 5, G.Boost, G.Super)
	if not info then return false end
	local mutation = ctx.Expeditions.RollMutation(nil, planet.Id)
	if mutation == "Normal" then mutation = "Golden" end
	race = {Planet = planet.Id, Position = position, Egg = {EggId = info.Id, Scale = ctx.Expeditions.RollSize(), Mutation = mutation, GoldenRace = true},
		EndsAt = now() + G.Duration, Missing = 0, StartedAt = now()}
	materialize()
	publish()
	announce("THE GOLDEN EGG appeared on " .. planet.Name .. "! Get it into your rocket first - knock it out of other people's hands with the bat!", "Gold")
	for _, player in ipairs(Players:GetPlayers()) do ctx.effect(player, "GoldenStart", {Planet = planet.Id, PlanetName = planet.Name}) end
	if ctx.Bots and ctx.Bots.OnRally then task.spawn(ctx.Bots.OnRally, planet.Id, "Golden") end
	return true
end

-- where is it now? (lying somewhere, in somebody's hands, or nowhere: then it comes back where it was last seen)
local function poll()
	if not race then return end
	local found = false
	local carrier
	for _, profile in ipairs(holders()) do
		local carried = profile.Expedition and profile.Expedition.CarryingEgg
		if carried and carried.GoldenRace then
			carrier = profile
			local r = ctx.root(profile.Player)
			if r then race.Position = r.Position end
			found = true
		end
	end
	if not found and race.Item and race.Item.Parent then
		local proxy = race.Item:FindFirstChild("Pickup")
		if proxy then race.Position = proxy.Position - Vector3.new(0, 1.9, 0) end
		found = true
	end
	if not found then
		-- knocked out of somebody's hands / dropped when they fell: a new pickup carries the GoldenRace mark
		local pickups = workspace:FindFirstChild("PFE_Pickups")
		local pool = pickups and pickups:FindFirstChild(race.Planet)
		for _, item in ipairs(pool and pool:GetChildren() or {}) do
			if item:GetAttribute("GoldenRace") then
				race.Item = item
				local proxy = item:FindFirstChild("Pickup")
				if proxy then race.Position = proxy.Position - Vector3.new(0, 1.9, 0) end
				found = true
				break
			end
		end
	end
	if race.Carrier ~= carrier then
		race.Carrier = carrier
		publish()
	elseif found then
		workspace:SetAttribute("PFEGoldenPos", race.Position)
	end
	if not found then
		race.Missing += 1
		-- (2 polls without it: put it back where it was last seen, if that planet has a pool)
		if race.Missing >= 2 then materialize() end
	end
	-- time's up: it fades away (in somebody's hands it waits until they load it or lose it, a little longer)
	local t = now()
	if t >= race.EndsAt and (not carrier or t >= race.EndsAt + 45) then
		local planet = Config.Planets[race.Planet]
		if carrier then
			local carried = carrier.Expedition and carrier.Expedition.CarryingEgg
			if carried then carried.GoldenRace = nil end
		end
		announce("The Golden Egg on " .. (planet and planet.Name or race.Planet) .. " faded away... the next one comes soon!", "Purple")
		stop()
	end
end

-- (Expeditions: giveCarry) somebody has it in their hands now
local function taken(profile)
	if not race then return end
	race.Carrier = profile
	race.Item = nil
	publish()
	announce(profile.Player.DisplayName .. " has THE GOLDEN EGG! Stop them before they reach their rocket!", "Gold")
	ctx.effect(profile.Player, "GoldenTaken", {})
end

-- (Expeditions: loadCarriedEgg) it's in somebody's rocket: they win
local function secured(profile, egg)
	if not race then return end
	local planet = Config.Planets[race.Planet]
	local coins = math.floor((planet and planet.Reward or 100) * Life.Golden.Coins)
	profile.Data.Coins = math.min(1e15, profile.Data.Coins + coins)
	profile.Data.Stats.GoldenEggs = (profile.Data.Stats.GoldenEggs or 0) + 1
	ctx.effect(profile.Player, "Coins", {Amount = coins})
	ctx.markDirty(profile)
	announce(profile.Player.DisplayName .. " WON THE GOLDEN EGG RACE! (" .. Config.EggDisplayName(egg) .. ")", "Gold")
	for _, player in ipairs(Players:GetPlayers()) do
		ctx.effect(player, "GoldenWon", {Winner = profile.Player.DisplayName, Mine = player == profile.Player, Coins = coins, EggId = egg.EggId})
	end
	race.Item = nil
	race = nil
	publish()
end

function GoldenRace.Current() return race end
function GoldenRace.StartNow() if race then stop() end; return start() end

function GoldenRace.Init(context, planetLife)
	ctx, L = context, planetLife
	Config, Life = ctx.Config, ctx.Life
	ctx.GoldenEggTaken = taken
	ctx.GoldenEggSecured = secured
	-- a planet that gets a pool (somebody landed): the egg waiting over it lands now
	local previous = ctx.OnPoolReady
	ctx.OnPoolReady = function(planetId)
		if previous then pcall(previous, planetId) end
		if race and race.Planet == planetId and not race.Carrier and not (race.Item and race.Item.Parent) then materialize() end
	end
	nextAt = now() + Life.Golden.First
	publish()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local t = now()
			if race then
				local ok, err = pcall(poll)
				if not ok then warn("[PFE] golden race failed", err) end
			elseif t >= nextAt then
				local ok, started = pcall(start)
				if not ok then warn("[PFE] golden race start failed", started) end
				nextAt = t + ((ok and started) and Life.Golden.Every or 30)
				publish()
			end
		end
	end)
end

return GoldenRace
