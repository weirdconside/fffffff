--!nocheck
-- World events, one at a time for the whole server a few minutes apart (like Egg Arena's):
--  MeteorShower  meteors strike eggs lying on the planets and upgrade their mutation
--  GoldenHour    every egg that appears is golden and a golden light turns lying eggs golden
--  Starfall      rare egg luck x2
--  EggStorm      extra eggs rain down around every player on a planet
--  Aurora        eggs picked up during it grow twice as fast at home
-- The running and the next event are workspace attributes (PFEEvent, PFEEventEndsAt,
-- PFEEventNext, PFEEventNextAt) for the HUD timer and the sky effects on the clients.
local Players = game:GetService("Players")
local Events = {}
local ctx, Config
local rng = Random.new()
local current, endsAt = nil, 0
local nextId, nextAt = nil, 0

function Events.Active(id)
	return current == id and workspace:GetServerTimeNow() < endsAt
end

local function publish()
	workspace:SetAttribute("PFEEvent", current or "")
	workspace:SetAttribute("PFEEventEndsAt", endsAt)
	workspace:SetAttribute("PFEEventNext", nextId or "")
	workspace:SetAttribute("PFEEventNextAt", nextAt)
end

local function scheduleNext(after)
	local list = Config.EventList
	local pick = list[rng:NextInteger(1, #list)]
	if #list > 1 then
		while pick.Id == current do pick = list[rng:NextInteger(1, #list)] end
	end
	nextId = pick.Id
	nextAt = workspace:GetServerTimeNow() + (after or rng:NextInteger(Config.EventInterval[1], Config.EventInterval[2]))
end

-- visual strike for everyone on that planet; the server applies `impact` when it lands
local function strike(planetId, kind, position, impact, extra)
	local delayTime = kind == "Meteor" and 1.5 or 0.9
	for _, other in pairs(ctx.profiles) do
		if other.Planet == planetId then
			local payload = {Kind = kind, Position = position, Delay = delayTime}
			for k, v in pairs(extra or {}) do payload[k] = v end
			ctx.effect(other.Player, "EventStrike", payload)
		end
	end
	task.delay(delayTime, impact)
end

local function groundEggs(planetId)
	local list = {}
	for _, item in ipairs(ctx.Expeditions.PlanetEggs(planetId)) do
		if not item:GetAttribute("IslandId") and item:GetAttribute("Mutation") ~= "Cosmic" then table.insert(list, item) end
	end
	return list
end

-- a meteor result worth shouting about: Diamond or better, or any upgrade on an Epic+ egg
local function isCool(egg)
	local order = 1
	for i, m in ipairs(Config.MutationList) do if m.Id == egg.Mutation then order = i end end
	local info = Config.Eggs[egg.EggId]
	local rarity = info and Config.Rarities[info.Rarity]
	return order >= 3 or (rarity ~= nil and rarity.Order >= 4)
end

local glowing = {}
local function clearGlow()
	for item in pairs(glowing) do
		if item.Parent then item:SetAttribute("MeteorGlow", nil) end
	end
	glowing = {}
end

local handlers = {}
function handlers.MeteorShower(elapsed, state)
	state.Next = state.Next or 0
	if elapsed < state.Next then return end
	state.Next = elapsed + 1.1
	local planets = ctx.Expeditions.ActivePlanets()
	if #planets == 0 then return end
	local planetId = planets[rng:NextInteger(1, #planets)]
	local eggs = groundEggs(planetId)
	if #eggs == 0 then return end
	local item = eggs[rng:NextInteger(1, #eggs)]
	local proxy = item:FindFirstChild("Pickup")
	if not proxy then return end
	strike(planetId, "Meteor", proxy.Position - Vector3.new(0, 1.9, 0), function()
		local ok, egg = ctx.Expeditions.UpgradePickup(item)
		if ok and egg and isCool(egg) then
			-- only the good ones are announced, to everyone; players on that planet see it through walls
			item:SetAttribute("MeteorGlow", true)
			glowing[item] = true
			local planet = Config.Planets[planetId]
			local info = Config.Eggs[egg.EggId]
			for _, player in ipairs(Players:GetPlayers()) do
				ctx.remotes.Notice:FireClient(player, "A meteor hit an egg on " .. (planet and planet.Name or planetId) .. ": it's now "
					.. Config.EggDisplayName(egg) .. " (" .. info.Rarity .. ")!", info.Rarity)
			end
		end
	end)
end
function handlers.GoldenHour(elapsed, state)
	if state.Done then return end
	state.Done = true
	for _, planetId in ipairs(ctx.Expeditions.ActivePlanets()) do
		for _, item in ipairs(groundEggs(planetId)) do
			local proxy = item:FindFirstChild("Pickup")
			if proxy and item:GetAttribute("Mutation") == "Normal" and rng:NextNumber() < 0.35 then
				strike(planetId, "Golden", proxy.Position - Vector3.new(0, 1.9, 0), function()
					ctx.Expeditions.UpgradePickup(item, "Golden")
				end)
			end
		end
	end
end
function handlers.EggStorm(elapsed, state)
	state.Next = state.Next or 0
	if elapsed < state.Next then return end
	state.Next = elapsed + 2.4
	state.Count = state.Count or {}
	for _, planetId in ipairs(ctx.Expeditions.ActivePlanets()) do
		local count = state.Count[planetId] or 0
		if count < 12 then
			local item = ctx.Expeditions.SpawnBonusEgg(planetId)
			if item then
				state.Count[planetId] = count + 1
				local proxy = item:FindFirstChild("Pickup")
				if proxy then
					for _, other in pairs(ctx.profiles) do
						if other.Planet == planetId then
							ctx.effect(other.Player, "EventStrike", {Kind = "EggDrop", Position = proxy.Position - Vector3.new(0, 1.9, 0), Delay = 0.9,
								EggId = item:GetAttribute("EggId")})
						end
					end
				end
			end
		end
	end
end

-- (v29) Pumpkin Night: every 2.5 s a jack-o-lantern with a lucky egg sprouts near each explorer (8 each at most);
-- the ones nobody grabbed vanish in a puff of ghost smoke when the night ends
function handlers.PumpkinNight(elapsed, state)
	state.Next = state.Next or 0
	state.Count = state.Count or {}
	state.Pumpkins = state.Pumpkins or {}
	if elapsed < state.Next then return end
	state.Next = elapsed + 2.5
	for _, profile in pairs(ctx.profiles) do
		local root = ctx.root(profile.Player)
		if Config.Planets[profile.Planet] and profile.Expedition and root then
			local count = state.Count[profile] or 0
			if count < 8 then
				local item = ctx.Expeditions.SpawnPumpkinEgg(profile.Planet, root.Position)
				if item then
					state.Count[profile] = count + 1
					table.insert(state.Pumpkins, item)
					local proxy = item:FindFirstChild("Pickup")
					if proxy then
						ctx.effect(profile.Player, "EventStrike", {Kind = "Pumpkin", Position = proxy.Position - Vector3.new(0, 1.9, 0), Delay = 0.6,
							EggId = item:GetAttribute("EggId")})
					end
				end
			end
		end
	end
end
local function endPumpkins(state)
	for _, item in ipairs(state.Pumpkins or {}) do
		if item.Parent then
			local proxy = item:FindFirstChild("Pickup")
			if proxy then
				for _, other in pairs(ctx.profiles) do
					if other.Planet == item:GetAttribute("Planet") then
						ctx.effect(other.Player, "EventStrike", {Kind = "Vanish", Position = proxy.Position, Delay = 0})
					end
				end
			end
			ctx.Expeditions.RemovePickup(item)
		end
	end
	state.Pumpkins = {}
end

-- ---------------------------------------------------------------- (v41) the new events (PlanetLife does the work)
-- the explorers out on a planet's surface, a random one of them, a spot near them
local function surface(planetId) return ctx.PlanetLife and ctx.PlanetLife.SurfaceExplorers(planetId) or {} end
local function nearSomebody(planetId, minD, maxD)
	local list = surface(planetId)
	if #list == 0 then return nil end
	local r = ctx.root(list[rng:NextInteger(1, #list)].Player)
	return r and ctx.PlanetLife.SpotNear(planetId, r.Position, minD, maxD)
end
-- Treasure Comet: a comet crashes near every explorer (one per explorer, three a planet at most) and leaves its crystal
-- heart in a crater: smash it - three eggs and a heap of coins
function handlers.TreasureComet(elapsed, state)
	if state.Done or not ctx.PlanetLife then return end
	state.Done = true
	for _, planetId in ipairs(ctx.Expeditions.ActivePlanets()) do
		local explorers = surface(planetId)
		for i = 1, math.min(3, #explorers) do
			local r = ctx.root(explorers[i].Player)
			local at = r and ctx.PlanetLife.SpotNear(planetId, r.Position, 50, 110)
			if at then
				ctx.PlanetLife.Strike(planetId, "Comet", at, {Delay = 3, Radius = 16, Damage = 30, Knock = 70}, {Reason = "A comet hit you!", Range = 1200,
					OnLand = function()
						ctx.PlanetLife.Breakable(planetId, "CometCore", CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), {Life = 150, Zone = 4, Size = 10})
					end})
			end
		end
	end
end
-- Coin Rain: coins drop round every explorer, walk over them to pick them up
function handlers.CoinRain(elapsed, state)
	if not ctx.PlanetLife then return end
	state.Next = state.Next or 0
	if elapsed < state.Next then return end
	state.Next = elapsed + 0.8
	for _, planetId in ipairs(ctx.Expeditions.ActivePlanets()) do
		local planet = Config.Planets[planetId]
		local value = math.max(10, math.floor((planet and planet.Reward or 100) * 0.04))
		for _, p in ipairs(surface(planetId)) do
			local r = ctx.root(p.Player)
			local at = r and ctx.PlanetLife.SpotNear(planetId, r.Position, 6, 38)
			if at then ctx.PlanetLife.Coin(planetId, at, value) end
		end
	end
end
-- Egg Tornado: a tornado on every planet with explorers wanders after them, flings whoever it catches into the air and
-- spits an egg out every few seconds
function handlers.EggTornado(elapsed, state)
	if not ctx.PlanetLife then return end
	state.Tornados = state.Tornados or {}
	for _, planetId in ipairs(ctx.Expeditions.ActivePlanets()) do
		local tornado = state.Tornados[planetId]
		if not tornado then
			local at = nearSomebody(planetId, 60, 110)
			if at then
				local record = ctx.PlanetLife.Zone(planetId, {Kind = "Tornado", Radius = 11, Launch = 95, Life = 9999}, at)
				if record then
					record.Moving = true
					state.Tornados[planetId] = {Record = record, Target = at, NextEgg = elapsed + 2}
				end
			end
		else
			local record = tornado.Record
			if not record.Model.Parent then state.Tornados[planetId] = nil; continue end
			-- wander towards a spot near somebody
			if (record.Position - tornado.Target).Magnitude < 6 then tornado.Target = nearSomebody(planetId, 10, 70) or tornado.Target end
			local step = (tornado.Target - record.Position) * Vector3.new(1, 0, 1)
			if step.Magnitude > 0.1 then
				local move = step.Unit * math.min(step.Magnitude, 9 * 0.25)
				record.Position += move
				record.CF = record.CF + move
				record.Model:PivotTo(record.Model:GetPivot() + move)
			end
			if elapsed >= tornado.NextEgg then
				tornado.NextEgg = elapsed + 3
				local a = rng:NextNumber(0, math.pi * 2)
				local spot = record.Position + Vector3.new(math.cos(a) * 16, 0, math.sin(a) * 16)
				local item = ctx.Expeditions.SpawnEventEgg(planetId, spot, {Zone = 4, Boost = 3, Life = 70})
				if item then
					local proxy = item:FindFirstChild("Pickup")
					ctx.PlanetLife.Tell(planetId, spot, "EventStrike", {Kind = "EggDrop", Position = proxy and proxy.Position - Vector3.new(0, 1.9, 0) or spot, Delay = 0.9,
						EggId = item:GetAttribute("EggId")}, 500)
				end
			end
		end
	end
end
local enders = {}
function enders.EggTornado(state)
	for _, tornado in pairs(state.Tornados or {}) do
		if ctx.PlanetLife then ctx.PlanetLife.RemoveZone(tornado.Record.Model) end
	end
	state.Tornados = {}
end
enders.PumpkinNight = endPumpkins

local state = {}
function Events.Start(id)
	local event = Config.Events[id]
	if not event then return end
	current = id
	endsAt = workspace:GetServerTimeNow() + event.Duration
	state = {Started = os.clock()}
	-- (v41) the next one starts EventInterval seconds after this one started (every 5 minutes)
	scheduleNext(math.max(event.Duration + 30, rng:NextInteger(Config.EventInterval[1], Config.EventInterval[2])))
	publish()
	for _, player in ipairs(Players:GetPlayers()) do
		ctx.remotes.Notice:FireClient(player, event.Name .. "! " .. event.Buff, "Purple")
	end
end

function Events.Init(context)
	ctx = context
	Config = ctx.Config
	ctx.Events = Events
	scheduleNext()
	publish()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = workspace:GetServerTimeNow()
			if current and now >= endsAt then
				if enders[current] then pcall(enders[current], state) end
				current = nil
				clearGlow()
				publish()
			elseif current then
				local handler = handlers[current]
				if handler then
					local ok, err = pcall(handler, os.clock() - state.Started, state)
					if not ok then warn("[PFE] event", current, "failed:", err) end
				end
			elseif now >= nextAt then
				Events.Start(nextId)
			end
		end
	end)
end

return Events
