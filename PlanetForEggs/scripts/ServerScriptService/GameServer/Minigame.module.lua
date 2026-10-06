--!nocheck
-- Meteor Run, every Config.Minigame.Cycle seconds. Everyone standing in the big circle in the middle
-- of the Earth island when the countdown ends is taken to a random planet (no eggs lying around);
-- for Config.Minigame.Duration seconds meteors carrying eggs fly across its sky. Players jetpack onto
-- a meteor and grab its egg (first come, first served); everyone can win up to MaxEggs eggs.
-- Each meteor flight (start, velocity, start time) is sent to the clients once and both sides
-- compute positions from the server clock, so nothing moving has to be replicated.
local Minigame = {}
local ctx, Config, MG
local rng = Random.new()
local nextAt = 0
local run = nil
local zoneCenter = Vector3.new(0, 68, 0)
local board

local function now() return workspace:GetServerTimeNow() end

local function publish()
	workspace:SetAttribute("PFEMinigameAt", nextAt)
	workspace:SetAttribute("PFEMinigameEndsAt", run and run.EndsAt or 0)
	workspace:SetAttribute("PFEMinigamePlanet", run and run.Planet or "")
end

local function send(profile, kind, payload)
	if profile.Player.Parent then ctx.remotes.Minigame:FireClient(profile.Player, kind, payload) end
end
local function broadcast(kind, payload)
	if not run then return end
	local watchers = {}
	for profile in pairs(run.Players) do
		send(profile, kind, payload)
		if (kind == "Meteor" or kind == "Taken") and ctx.Admin and ctx.Admin.SpectatorsOf then
			for _, admin in ipairs(ctx.Admin.SpectatorsOf(profile.Player)) do watchers[admin] = true end
		end
	end
	for admin in pairs(watchers) do
		if not (ctx.profiles[admin] and ctx.profiles[admin].Minigame == run) then ctx.remotes.Minigame:FireClient(admin, kind, payload) end
	end
end

function Minigame.MeteorPosition(meteor, t)
	return meteor.Start + meteor.Velocity * (t - meteor.T0)
end

-- (v35) the bots: they queue in the circle and fly up to the meteors like the players (run.Bots: their profiles)
local tops = {}
function Minigame.MeteorTop(meteor)
	local top = tops[meteor.Model]
	if top == nil then
		top = 2
		local sky = ctx.network:FindFirstChild("Sky")
		local template = sky and sky:FindFirstChild(meteor.Model)
		if template then
			local ok, cf, size = pcall(function() return template:GetBoundingBox() end)
			if ok and cf then top = cf.Position.Y + size.Y / 2 - template:GetPivot().Position.Y end
		end
		tops[meteor.Model] = top
	end
	return top
end
function Minigame.ZoneCenter() return zoneCenter end
function Minigame.Current() return run end
function Minigame.InviteOpen()
	local t = now()
	return run == nil and t >= nextAt - MG.InviteSeconds and t < nextAt - 1
end
function Minigame.BotEntry(profile)
	return run and run.Bots and run.Bots[profile] or nil
end
local function botProfiles()
	return ctx.Bots and ctx.Bots.Profiles and ctx.Bots.Profiles() or {}
end
function Minigame.LeaveBot(profile, reason)
	local current = profile.Minigame
	if not current then return end
	local entry = current.Bots and current.Bots[profile]
	if current.Bots then current.Bots[profile] = nil end
	profile.Minigame = nil
	profile.Planet = "Base"
	for _, egg in ipairs(entry and entry.Eggs or {}) do
		table.insert(profile.Data.Eggs, {Id = ctx.Data.Guid(), EggId = egg.EggId, Scale = egg.Scale, Mutation = egg.Mutation})
		profile.Data.DiscoveredEggs[egg.EggId] = true
	end
	if reason ~= "left" and ctx.Bots and ctx.Bots.OnMinigameEnd then pcall(ctx.Bots.OnMinigameEnd, profile) end
end

local function inZone(profile)
	if profile.Planet ~= "Base" or profile.Busy or profile.Stolen or profile.Minigame then return false end
	local root, humanoid = ctx.root(profile.Player), ctx.humanoid(profile.Player)
	if not root or not humanoid or humanoid.Health <= 0 then return false end
	local d = root.Position - zoneCenter
	return Vector2.new(d.X, d.Z).Magnitude <= MG.ZoneRadius and math.abs(d.Y) < 25
end

-- a prize egg from a random planet (early worlds more likely) with boosted rarity
local function rollPrize(profile)
	local total, weights = 0, {}
	for i in ipairs(Config.PlanetOrder) do weights[i] = 1 / i; total += weights[i] end
	local roll, planet = rng:NextNumber() * total, Config.PlanetOrder[1]
	for i, w in ipairs(weights) do
		roll -= w
		if roll <= 0 then planet = Config.PlanetOrder[i]; break end
	end
	local info = ctx.Expeditions.RollEgg(profile, planet.Id, 3, 3, 0.02)
	return {EggId = info.Id, Scale = 1, Mutation = ctx.Expeditions.RollMutation(profile)}
end

local function spawnMeteor()
	local planet = Config.Planets[run.Planet]
	local origin = planet.Origin
	local a = rng:NextNumber(0, math.pi * 2)
	local h = rng:NextNumber(MG.Height[1], MG.Height[2])
	local start = origin + Vector3.new(math.cos(a) * MG.ArenaRadius, h, math.sin(a) * MG.ArenaRadius)
	local aim = origin + Vector3.new(rng:NextNumber(-55, 55), h + rng:NextNumber(-8, 8), rng:NextNumber(-55, 55))
	local speed = rng:NextNumber(MG.Speed[1], MG.Speed[2])
	local reference = next(run.Players)
	if not reference then return end
	local meteor = {Id = run.NextId, Start = start, Velocity = (aim - start).Unit * speed, T0 = now(),
		Life = MG.ArenaRadius * 2 / speed, Model = "Meteor_" .. ({"A", "B", "C"})[rng:NextInteger(1, 3)],
		Egg = rollPrize(reference), Spin = rng:NextNumber(-0.25, 0.25)}
	run.NextId += 1
	run.Meteors[meteor.Id] = meteor
	broadcast("Meteor", {Id = meteor.Id, Start = meteor.Start, Velocity = meteor.Velocity, T0 = meteor.T0, Life = meteor.Life,
		Model = meteor.Model, EggId = meteor.Egg.EggId, Mutation = meteor.Egg.Mutation, Spin = meteor.Spin})
end

function Minigame.Leave(profile, reason)
	local current = profile.Minigame
	if not current then return end
	local entry = current.Players[profile]
	current.Players[profile] = nil
	profile.Minigame = nil
	local won = entry and entry.Eggs or {}
	for _, egg in ipairs(won) do
		-- (won prizes are never lost: a full backpack takes up to 10 more)
		if #profile.Data.Eggs < Config.MaxStoredEggs + 10 then
			table.insert(profile.Data.Eggs, {Id = ctx.Data.Guid(), EggId = egg.EggId, Scale = egg.Scale, Mutation = egg.Mutation})
			profile.Data.DiscoveredEggs[egg.EggId] = true
		end
	end
	if profile.Player.Parent then
		profile.Player:SetAttribute("PFEMinigame", false)
		profile.Planet = "Base"
		if reason ~= "died" then ctx.teleport(profile, profile.Base:FindFirstChild("Spawn")) end
		send(profile, "End", {Eggs = won, Reason = reason})
		ctx.publishTracker(profile)
		ctx.markDirty(profile)
		ctx.sendState(profile)
	end
end

-- someone who said JOIN to the invitation can still go (they were taken into the circle)
local function joinable(profile)
	if profile.Planet ~= "Base" or profile.Busy or profile.Stolen or profile.Minigame then return false end
	local humanoid = ctx.humanoid(profile.Player)
	return ctx.root(profile.Player) ~= nil and humanoid ~= nil and humanoid.Health > 0
end

local function start()
	local startedFor = nextAt
	nextAt = math.max(nextAt, now()) + MG.Cycle
	local players = {}
	for _, profile in pairs(ctx.profiles) do
		if inZone(profile) or (profile.MeteorJoined == startedFor and joinable(profile)) then table.insert(players, profile) end
	end
	if #players == 0 then publish(); return end
	local planet = Config.PlanetOrder[rng:NextInteger(1, #Config.PlanetOrder)]
	local model = ctx.planets:FindFirstChild(planet.Id)
	local landing = model and model:FindFirstChild("Landing")
	run = {Planet = planet.Id, StartsAt = now() + 3, EndsAt = now() + 3 + MG.Duration, Players = {}, Meteors = {}, NextId = 1,
		NextSpawn = now() + 2}
	run.Bots = {}
	for _, profile in ipairs(botProfiles()) do
		if inZone(profile) then
			run.Bots[profile] = {Eggs = {}}
			profile.Minigame = run
			profile.Planet = planet.Id
			local a = rng:NextNumber(0, math.pi * 2)
			local cf = landing and (landing.CFrame + Vector3.new(math.cos(a) * 14, 5, math.sin(a) * 14)) or nil
			if ctx.Bots.OnMinigameStart then pcall(ctx.Bots.OnMinigameStart, profile, cf) end
		end
	end
	for _, profile in ipairs(players) do
		run.Players[profile] = {Eggs = {}}
		profile.Minigame = run
		profile.Planet = planet.Id
		profile.Player:SetAttribute("PFEQueued", false)
		profile.Player:SetAttribute("PFEMinigame", true) -- the planet's own eggs are hidden for them
		local a = rng:NextNumber(0, math.pi * 2)
		if landing then ctx.teleport(profile, landing, Vector3.new(math.cos(a) * 14, 5, math.sin(a) * 14)) end
		send(profile, "Start", {Planet = planet.Id, StartsAt = run.StartsAt, EndsAt = run.EndsAt, MaxEggs = MG.MaxEggs})
		ctx.publishTracker(profile)
		ctx.markDirty(profile)
		ctx.sendState(profile)
	end
	publish()
end

local function finish()
	local current = run
	run = nil
	for profile in pairs(current.Players) do Minigame.Leave(profile, "finished") end
	for profile in pairs(current.Bots or {}) do Minigame.LeaveBot(profile, "finished") end
	publish()
end

-- (v35) a bot reached the egg on meteor `id`
local function grabBot(profile, id)
	local entry = run and run.Bots and run.Bots[profile]
	local meteor = entry and run.Meteors[id]
	if not meteor or meteor.Taken or #entry.Eggs >= MG.MaxEggs or profile.Minigame ~= run then return end
	local root = ctx.root(profile.Player)
	if not root then return end
	local egg = Minigame.MeteorPosition(meteor, now()) + Vector3.new(0, 2, 0)
	if (root.Position - egg).Magnitude > MG.GrabRange + 5 then return end
	meteor.Taken = true
	table.insert(entry.Eggs, meteor.Egg)
	broadcast("Taken", {Id = id, By = profile.Player.UserId, Count = #entry.Eggs})
end
Minigame.BotGrab = grabBot

-- a player's client says it reached the egg on meteor `id`
local function grab(player, id)
	local profile = ctx.profiles[player]
	if not run or not profile or profile.Minigame ~= run or type(id) ~= "number" then return end
	local entry = run.Players[profile]
	local meteor = run.Meteors[id]
	if not entry or not meteor or meteor.Taken or #entry.Eggs >= MG.MaxEggs then return end
	local root = ctx.root(player)
	if not root then return end
	-- (generous: the rock is big, the client stands on it, and the meteor moved on while the message travelled)
	local egg = Minigame.MeteorPosition(meteor, now()) + Vector3.new(0, 2, 0)
	if (root.Position - egg).Magnitude > MG.GrabRange + 24 then return end
	meteor.Taken = true
	table.insert(entry.Eggs, meteor.Egg)
	broadcast("Taken", {Id = id, By = player.UserId, Count = #entry.Eggs})
	ctx.notice(profile, Config.EggDisplayName(meteor.Egg) .. " grabbed! (" .. #entry.Eggs .. "/" .. MG.MaxEggs .. ")", "Gold")
end

-- JOIN on the invitation (Config.Minigame.InviteSeconds before a run): wherever you are, you're taken
-- into the circle. From a planet you come home at once: the egg in your hands is lost (the eggs in the
-- rocket come home), a stolen egg flies back to its owner, an alien ship is left.
function Minigame.Join(profile)
	local t = now()
	if run or profile.Minigame or t >= nextAt - 0.5 or t < nextAt - MG.InviteSeconds - 3 then return false end
	local function no(text)
		ctx.notice(profile, text, "Red")
		send(profile, "JoinFailed", {Text = text})
		return false
	end
	if profile.Busy then return no("You're flying - press JOIN again when you land!") end
	local humanoid = ctx.humanoid(profile.Player)
	if not ctx.root(profile.Player) or not humanoid or humanoid.Health <= 0 then return no("Wait until you respawn, then press JOIN.") end
	if profile.Stolen and ctx.Bases then ctx.Bases.CancelSteal(profile, "you joined the Meteor Run") end
	if profile.InDungeon and ctx.Dungeons then ctx.Dungeons.OnLeft(profile) end
	local lost
	if profile.Expedition then
		local ok, egg = ctx.Expeditions.EndNow(profile)
		if not ok then return no("You can't leave right now - try again in a moment.") end
		lost = egg
	end
	if profile.Planet ~= "Base" then return no("You can't join from here.") end
	local character = profile.Player.Character
	local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, MG.ZoneRadius * 0.45)
	if character then character:PivotTo(CFrame.new(zoneCenter + Vector3.new(math.cos(a) * r, 4, math.sin(a) * r))) end
	profile.MeteorJoined = nextAt
	ctx.publishTracker(profile)
	ctx.markDirty(profile)
	ctx.sendState(profile)
	send(profile, "Joined", {StartsAt = nextAt, Lost = lost and Config.EggDisplayName(lost) or nil})
	ctx.notice(profile, "You're in the Meteor Run! Stay in the circle." .. (lost and (" (" .. Config.EggDisplayName(lost) .. " was lost)") or ""), "Gold")
	return true
end

local function updateBoard(queued)
	if not board then return end
	local left = math.max(0, math.ceil(nextAt - now()))
	board.Timer.Text = run and "RUNNING!" or string.format("Starts in %d:%02d", left // 60, left % 60)
	board.Queue.Text = queued .. (queued == 1 and " player" or " players") .. " in the circle"
end

local function makeBoard(anchor)
	local gui = Instance.new("BillboardGui")
	gui.Name = "MeteorRunBoard"; gui.Size = UDim2.fromOffset(300, 120); gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	gui.MaxDistance = 220; gui.LightInfluence = 0; gui.AlwaysOnTop = false; gui.Adornee = anchor; gui.Parent = anchor
	local font = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
	local function line(name, text, y, h, color)
		local label = Instance.new("TextLabel")
		label.Name = name; label.BackgroundTransparency = 1; label.Size = UDim2.new(1, 0, 0, h); label.Position = UDim2.fromOffset(0, y)
		label.FontFace = font; label.TextScaled = true; label.Text = text; label.TextColor3 = color; label.Parent = gui
		local stroke = Instance.new("UIStroke"); stroke.Thickness = 3; stroke.Color = Color3.fromRGB(20, 14, 30); stroke.Parent = label
		return label
	end
	line("Title", "METEOR RUN", 0, 46, Color3.fromRGB(255, 176, 60))
	line("Timer", "", 48, 38, Color3.new(1, 1, 1))
	line("Queue", "", 88, 28, Color3.fromRGB(255, 230, 170))
	return gui
end

function Minigame.Init(context)
	ctx = context
	Config = ctx.Config
	MG = Config.Minigame
	ctx.Minigame = Minigame
	local pad = ctx.world:FindFirstChild("OriginalIsland") and ctx.world.OriginalIsland:FindFirstChild("MeteorRunPad")
	if pad then
		zoneCenter = pad:GetPivot().Position
		local anchor = pad:FindFirstChild("SignAnchor", true)
		if anchor then board = makeBoard(anchor) end
	end
	nextAt = now() + MG.Cycle
	publish()
	if ctx.remotes.MinigameJoin then
		ctx.remotes.MinigameJoin.OnServerEvent:Connect(function(player)
			local profile = ctx.profiles[player]
			if not profile then return end
			local ok, err = pcall(Minigame.Join, profile)
			if not ok then warn("[PFE] meteor join failed", err) end
		end)
	end
	ctx.remotes.MinigameGrab.OnServerEvent:Connect(function(player, id)
		local ok, err = pcall(grab, player, id)
		if not ok then warn("[PFE] meteor grab failed", err) end
	end)
	-- the server takes the egg by itself for anyone who reaches it: it knows every meteor's flight, so this
	-- doesn't depend on the client noticing (the client also asks, see MeteorRun.client)
	task.spawn(function()
		while true do
			task.wait(0.15)
			if run and now() >= run.StartsAt then
				local t = now()
				for profile, entry in pairs(run.Players) do
					local root = ctx.root(profile.Player)
					if root and #entry.Eggs < MG.MaxEggs then
						for id, meteor in pairs(run.Meteors) do
							if not meteor.Taken and t >= meteor.T0 then
								local egg = Minigame.MeteorPosition(meteor, t) + Vector3.new(0, 2, 0)
								if (root.Position - egg).Magnitude <= MG.GrabRange + 5 then pcall(grab, profile.Player, id); break end
							end
						end
					end
				end
				for profile, entry in pairs(run.Bots or {}) do
					local root = ctx.root(profile.Player)
					if root and #entry.Eggs < MG.MaxEggs then
						for id, meteor in pairs(run.Meteors) do
							if not meteor.Taken and t >= meteor.T0 then
								local egg = Minigame.MeteorPosition(meteor, t) + Vector3.new(0, 2, 0)
								if (root.Position - egg).Magnitude <= MG.GrabRange + 4 then pcall(grabBot, profile, id); break end
							end
						end
					end
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(function()
				local queued = 0
				for _, profile in pairs(ctx.profiles) do
					local inside = inZone(profile)
					if inside then queued += 1 end
					if profile.Player:GetAttribute("PFEQueued") ~= inside then profile.Player:SetAttribute("PFEQueued", inside) end
				end
				for _, profile in ipairs(botProfiles()) do if inZone(profile) then queued += 1 end end
				updateBoard(queued)
				local t = now()
				-- the invitation: everyone gets a JOIN / NO window once per run, newcomers too
				if not run and t >= nextAt - MG.InviteSeconds and t < nextAt - 1 then
					for _, profile in pairs(ctx.profiles) do
						if profile.MeteorInvited ~= nextAt and not profile.Minigame then
							profile.MeteorInvited = nextAt
							send(profile, "Invite", {StartsAt = nextAt})
						end
					end
				end
				if run then
					if t >= run.EndsAt then finish(); return end
					if t >= run.NextSpawn and t < run.EndsAt - 4 then
						run.NextSpawn = t + MG.SpawnEvery
						spawnMeteor()
					end
					for id, meteor in pairs(run.Meteors) do
						if t > meteor.T0 + meteor.Life + 1 then run.Meteors[id] = nil end
					end
					if next(run.Players) == nil then finish() end
				elseif t >= nextAt then
					start()
				end
			end)
			if not ok then warn("[PFE] minigame tick failed", err) end
		end
	end)
end

-- Studio: start the countdown now / end the running game now
function Minigame.DevStart(seconds)
	nextAt = now() + (tonumber(seconds) or 2)
	publish()
end
function Minigame.DevEnd()
	if run then finish() end
end

return Minigame
