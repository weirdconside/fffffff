--!nocheck
-- (v41) Planet bosses: every Life.Boss.Every seconds the boss of a planet wakes up (Life.Bosses: the Moon Golem, the
-- Sand Worm, the Ice Yeti, the Lava Golem...). It comes up where most explorers are (or anywhere on a random planet when
-- nobody is out) and everybody on the server is told. The whole server fights it - bat hits and raygun bolts (PlanetLife's
-- targets) - while it slams the ground, throws rocks / snowballs / spit, leaps (Yeti) or burrows and bursts up under
-- someone (Worm); every attack is telegraphed with a red circle first. Under 40% it gets angry (faster, more often).
-- When it falls, eggs rain down around it (rarer than anything on the ground) and every fighter gets coins by the share
-- of the damage they did. If nobody beats it in Life.Boss.Duration seconds it leaves.
-- The server only moves an invisible hitbox; BossClient draws the body from its attributes and animates it.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Bosses = {}
local ctx, Config, Life, L
local rng = Random.new()
local boss -- the one awake now
local nextAt = 0

local function now() return workspace:GetServerTimeNow() end
local function flat(a, b) return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude end

local function publish()
	workspace:SetAttribute("PFEBossPlanet", boss and boss.Planet or "")
	workspace:SetAttribute("PFEBossName", boss and boss.Def.Name or "")
	workspace:SetAttribute("PFEBossEndsAt", boss and boss.EndsAt or 0)
	workspace:SetAttribute("PFEBossNextAt", nextAt)
end

local function announce(text, color)
	for _, player in ipairs(Players:GetPlayers()) do ctx.remotes.Notice:FireClient(player, text, color or "Red") end
end

-- the fighters a boss can go after: explorers on its planet's surface, off the landing pad
local function fighters(b)
	local list = {}
	for _, p in ipairs(L.SurfaceExplorers(b.Planet)) do
		local r = ctx.root(p.Player)
		if r and flat(r.Position, b.Origin) > Life.SafeRadius then table.insert(list, {Profile = p, Root = r}) end
	end
	return list
end

local function setCF(b, position, look)
	b.Position = Vector3.new(position.X, b.Ground, position.Z)
	local face = look and Vector3.new(look.X, b.Ground, look.Z) or (b.Position + b.Facing)
	if (face - b.Position).Magnitude > 0.1 then b.Facing = (face - b.Position).Unit end
	b.Hitbox.CFrame = CFrame.lookAt(b.Position + Vector3.new(0, b.Size.Y / 2, 0), b.Position + Vector3.new(0, b.Size.Y / 2, 0) + b.Facing)
end

local function act(b, name, payload)
	payload = payload or {}
	payload.Act = name
	b.Model:SetAttribute("Act", name)
	b.Model:SetAttribute("ActAt", now())
	L.Tell(b.Planet, b.Position, "BossAct", payload, 900)
end

-- ---------------------------------------------------------------- attacks
local function slam(b)
	local radius = b.Body.Slam * b.Def.Scale
	act(b, "Slam", {Delay = 1.3, Radius = radius})
	L.Strike(b.Planet, "BossSlam", b.Position, {Delay = 1.3, Radius = radius, Damage = b.Damage, Knock = 65},
		{Reason = "The " .. b.Def.Name .. " flattened you!", Range = 900})
	b.Busy = now() + 1.8
end
local function throw(b, target)
	local at = target.Root.Position + target.Root.AssemblyLinearVelocity * Vector3.new(1, 0, 1) * 0.6
	at = Vector3.new(at.X, b.Ground, at.Z)
	local kind = b.Def.Body == "Yeti" and "Snowball" or b.Def.Body == "Worm" and "Spit" or "Boulder"
	act(b, "Throw", {Delay = 1.6, To = at, Kind = kind, From = b.Position + Vector3.new(0, b.Size.Y * 0.8, 0)})
	L.Strike(b.Planet, "Boss" .. kind, at, {Delay = 1.6, Radius = b.Body.Throw * b.Def.Scale, Damage = math.floor(b.Damage * 0.8), Knock = 45},
		{Reason = "The " .. b.Def.Name .. " got you!", From = b.Position + Vector3.new(0, b.Size.Y * 0.8, 0), Range = 900})
	b.Busy = now() + 1.2
end
local function leap(b, target)
	local at = Vector3.new(target.Root.Position.X, b.Ground, target.Root.Position.Z)
	act(b, "Leap", {Delay = 1.4, To = at, From = b.Position})
	L.Strike(b.Planet, "BossLeap", at, {Delay = 1.4, Radius = 13 * b.Def.Scale, Damage = b.Damage, Knock = 70},
		{Reason = "The " .. b.Def.Name .. " landed on you!", Range = 900,
			OnLand = function() if boss == b and not b.Dead then setCF(b, at) end end})
	b.Busy = now() + 2
end
local function burrow(b, target)
	local at = Vector3.new(target.Root.Position.X, b.Ground, target.Root.Position.Z)
	act(b, "Burrow", {Delay = 1.8, To = at, From = b.Position})
	b.Under = true
	b.Model:SetAttribute("Under", true)
	L.Strike(b.Planet, "BossBurst", at, {Delay = 1.8, Radius = 11 * b.Def.Scale, Damage = math.floor(b.Damage * 1.1), Knock = 85},
		{Reason = "The " .. b.Def.Name .. " burst up under you!", Range = 900,
			OnLand = function()
				if boss ~= b or b.Dead then return end
				setCF(b, at)
				b.Under = false
				b.Model:SetAttribute("Under", false)
			end})
	b.Busy = now() + 2.6
end

-- ---------------------------------------------------------------- the end of a boss
local function finish(b, won)
	if boss ~= b then return end
	boss = nil
	b.Dead = true
	L.RemoveTarget(b.Model)
	CollectionService:RemoveTag(b.Model, "PFEBoss")
	if won then
		b.Model:SetAttribute("Dead", true)
		act(b, "Die", {})
		local total = 0
		for _, dmg in pairs(b.Damages) do total += dmg end
		local list = {}
		for profile, dmg in pairs(b.Damages) do
			if ctx.profiles[profile.Player] == profile then table.insert(list, {Profile = profile, Damage = dmg}) end
		end
		table.sort(list, function(x, y) return x.Damage > y.Damage end)
		-- coins by the share of the damage (everybody who hit it gets something)
		local reward = (Config.Planets[b.Planet].Reward or 100) * Life.Boss.CoinsReward
		for i, entry in ipairs(list) do
			local share = entry.Damage / math.max(1, total)
			local coins = math.floor(reward * (0.35 + 0.65 * share * #list))
			local p = entry.Profile
			p.Data.Coins = math.min(1e15, p.Data.Coins + coins)
			p.Data.Stats.BossesDefeated = (p.Data.Stats.BossesDefeated or 0) + 1
			ctx.effect(p.Player, "Coins", {Amount = coins})
			ctx.effect(p.Player, "BossReward", {Name = b.Def.Name, Coins = coins, Rank = i, Fighters = #list, Share = share})
			ctx.markDirty(p)
		end
		local top = list[1] and list[1].Profile.Player.DisplayName
		announce("The " .. b.Def.Name .. " is DEFEATED" .. (top and (" - top fighter: " .. top) or "") .. "! Eggs are raining on " .. Config.Planets[b.Planet].Name .. "!", "Gold")
		-- the egg rain
		local rain = Life.Boss.EggRain
		local count = rain.Base + rain.PerFighter * #list
		local centre = b.Position
		task.spawn(function()
			for i = 1, count do
				local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(rain.Radius[1], rain.Radius[2])
				local spot = Vector3.new(centre.X + math.cos(a) * d, b.Ground, centre.Z + math.sin(a) * d)
				local item = ctx.Expeditions.SpawnEventEgg(b.Planet, spot, {Zone = 5, Boost = rain.Boost, Super = rain.Super, Life = rain.Life})
				if item then
					local proxy = item:FindFirstChild("Pickup")
					L.Tell(b.Planet, spot, "EventStrike", {Kind = "EggDrop", Position = proxy and proxy.Position - Vector3.new(0, 1.9, 0) or spot, Delay = 0.9,
						EggId = item:GetAttribute("EggId")}, 900)
				end
				task.wait(0.12)
			end
		end)
		task.delay(3, function() if b.Model.Parent then b.Model:Destroy() end end)
	else
		act(b, "Leave", {})
		announce("The " .. b.Def.Name .. " went back to sleep... nobody beat it this time.", "Purple")
		task.delay(2.5, function() if b.Model.Parent then b.Model:Destroy() end end)
	end
	publish()
end

local function hit(b, amount, profile, how)
	if boss ~= b or b.Dead or b.Under or now() < b.WakeAt then return end
	b.HP = math.max(0, b.HP - amount)
	b.Model:SetAttribute("HP", math.ceil(b.HP))
	if profile then
		b.Damages[profile] = (b.Damages[profile] or 0) + amount
		if not b.Target or rng:NextNumber() < 0.15 then b.Target = profile end
	end
	L.Tell(b.Planet, b.Position, "BossHit", {How = how, Ratio = b.HP / b.Max}, 400)
	if not b.Angry and b.HP <= b.Max * 0.4 then
		b.Angry = true
		b.Model:SetAttribute("Angry", true)
		act(b, "Roar", {})
		L.Tell(b.Planet, b.Position, "BossAngry", {Name = b.Def.Name}, 900)
	end
	if b.HP <= 0 then finish(b, true) end
end

-- ---------------------------------------------------------------- waking one up
local function spawnBoss()
	-- the planet with the most explorers on it; nobody out: any planet somebody's rocket reaches
	local best, bestCount = nil, 0
	for _, planet in ipairs(Config.PlanetOrder) do
		local n = #L.SurfaceExplorers(planet.Id)
		if n > bestCount or (n == bestCount and n > 0 and rng:NextNumber() < 0.5) then best, bestCount = planet, n end
	end
	if not best then
		local range = 0
		for _, p in pairs(ctx.profiles) do range = math.max(range, Config.Rockets[p.Data.RocketLevel] and Config.Rockets[p.Data.RocketLevel].Range or 1) end
		if range == 0 then return false end
		local options = {}
		for _, planet in ipairs(Config.PlanetOrder) do if planet.RequiredRange <= range then table.insert(options, planet) end end
		best = options[rng:NextInteger(1, #options)]
	end
	local def = Life.Bosses[best.Id]
	local body = def and Life.BossBodies[def.Body]
	if not def or not body then return false end
	-- where: near the explorers (a little way off), else a walk from the rocket that the air allows there and back
	local at
	local explorers = L.SurfaceExplorers(best.Id)
	if #explorers > 0 then
		local r = ctx.root(explorers[rng:NextInteger(1, #explorers)].Player)
		at = r and L.SpotNear(best.Id, r.Position, 55, 85)
	end
	at = at or L.SpotNear(best.Id, best.Origin, 220, 520)
	if not at then return false end
	local count = math.max(1, #explorers)
	local size = body.Size * def.Scale
	local model = Instance.new("Model")
	model.Name = "Boss_" .. best.Id
	local hitbox = L.Part(model, {Name = "Hitbox", Size = size, Transparency = 1, CFrame = CFrame.new(at + Vector3.new(0, size.Y / 2, 0))})
	model.PrimaryPart = hitbox
	local hp = math.floor(def.Health * (1 + Life.Boss.HealthPerExtra * (count - 1)))
	for key, value in pairs({Boss = def.Name, Body = def.Body, Planet = best.Id, HP = hp, MaxHP = hp, Scale = def.Scale, Main = def.Main, Dark = def.Dark,
		Glow = def.Glow, Angry = false, Under = false, Dead = false, Act = "Rise", ActAt = now()}) do
		model:SetAttribute(key, value)
	end
	model.Parent = L.Folder(best.Id)
	CollectionService:AddTag(model, "PFEBoss")
	local b = {Model = model, Hitbox = hitbox, Def = def, Body = body, Planet = best.Id, Origin = best.Origin, Ground = best.Origin.Y, Size = size,
		HP = hp, Max = hp, Damage = def.Damage, Damages = {}, Facing = Vector3.new(0, 0, -1), Busy = 0, NextAttack = now() + 4,
		WakeAt = now() + 2.5, EndsAt = now() + Life.Boss.Duration, Home = at}
	boss = b
	setCF(b, at)
	L.AddTarget(model, {Planet = best.Id, Radius = math.max(size.X, size.Z) * 0.55, Center = function() return hitbox.Position end,
		CanHit = function() return boss == b and not b.Dead and not b.Under end,
		Hit = function(amount, profile, how) hit(b, amount, profile, how) end})
	publish()
	act(b, "Rise", {})
	announce("BOSS! The " .. def.Name .. " woke up on " .. best.Name .. "! Fight it with your bat and raygun - eggs rain when it falls!", "Red")
	for _, player in ipairs(Players:GetPlayers()) do
		ctx.effect(player, "BossSpawn", {Name = def.Name, Planet = best.Id, PlanetName = best.Name})
	end
	if ctx.Bots and ctx.Bots.OnRally then task.spawn(ctx.Bots.OnRally, best.Id, "Boss") end
	return true
end

-- ---------------------------------------------------------------- the brain (10 times a second)
local function think(b, dt)
	local t = now()
	if t >= b.EndsAt then finish(b, false); return end
	if t < b.WakeAt or t < b.Busy or b.Under then return end
	local list = fighters(b)
	-- the target: whoever it was after (if still around), else the nearest
	local target
	for _, f in ipairs(list) do if f.Profile == b.Target then target = f end end
	if not target or flat(target.Root.Position, b.Position) > 260 then
		target = nil
		local bestD
		for _, f in ipairs(list) do
			local d = flat(f.Root.Position, b.Position)
			if d < 260 and (not bestD or d < bestD) then target, bestD = f, d end
		end
		b.Target = target and target.Profile or nil
	end
	local speed = b.Def.Speed * (b.Angry and 1.35 or 1)
	if not target then
		-- nobody about: it wanders round where it came up
		if not b.Wander or flat(b.Wander, b.Position) < 4 then
			b.Wander = L.SpotNear(b.Planet, b.Home, 5, 60) or b.Home
		end
		local step = (b.Wander - b.Position) * Vector3.new(1, 0, 1)
		if step.Magnitude > 0.1 then setCF(b, b.Position + step.Unit * math.min(step.Magnitude, speed * 0.5 * dt), b.Wander) end
		return
	end
	local d = flat(target.Root.Position, b.Position)
	-- attack when it's time
	if t >= b.NextAttack then
		b.NextAttack = t + rng:NextNumber(2.4, 3.6) * (b.Angry and 0.7 or 1)
		local body = b.Def.Body
		local slamReach = b.Body.Slam * b.Def.Scale
		if d <= slamReach * 0.85 then slam(b)
		elseif body == "Worm" and rng:NextNumber() < 0.6 then burrow(b, target)
		elseif body == "Yeti" and d > 30 and rng:NextNumber() < 0.5 then leap(b, target)
		else throw(b, target) end
		return
	end
	-- walk up to it (it never steps onto the landing pad)
	if d > b.Body.Reach * b.Def.Scale then
		local dir = (target.Root.Position - b.Position) * Vector3.new(1, 0, 1)
		local nextPos = b.Position + dir.Unit * math.min(dir.Magnitude - b.Body.Reach, speed * dt)
		if flat(nextPos, b.Origin) > Life.SafeRadius + b.Size.X then setCF(b, nextPos, target.Root.Position) else setCF(b, b.Position, target.Root.Position) end
		b.Model:SetAttribute("Moving", true)
	else
		setCF(b, b.Position, target.Root.Position)
		b.Model:SetAttribute("Moving", false)
	end
end

function Bosses.Current() return boss end
-- (Studio / admin) wake one up now
function Bosses.SpawnNow() if boss then finish(boss, false) end; return spawnBoss() end

function Bosses.Init(context, planetLife)
	ctx, L = context, planetLife
	Config, Life = ctx.Config, ctx.Life
	nextAt = now() + Life.Boss.First
	publish()
	task.spawn(function()
		local warned = false
		local last = os.clock()
		while true do
			task.wait(0.1)
			local clock = os.clock()
			local dt = math.min(0.5, clock - last)
			last = clock
			local t = now()
			if boss then
				local ok, err = pcall(think, boss, dt)
				if not ok then warn("[PFE] boss AI failed", err) end
			elseif t >= nextAt then
				local ok, spawned = pcall(spawnBoss)
				if not ok then warn("[PFE] boss spawn failed", spawned) end
				nextAt = t + ((ok and spawned) and Life.Boss.Every or 60)
				warned = false
				publish()
			elseif not warned and t >= nextAt - Life.Boss.Announce then
				warned = true
				if next(ctx.profiles) then announce("A planet boss wakes up in " .. Life.Boss.Announce .. " seconds - get ready!", "Orange") end
			end
		end
	end)
end

return Bosses
