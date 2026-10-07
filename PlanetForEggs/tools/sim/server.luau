-- lune run tools/sim/server.luau <built place.rbxl>
-- Boots the real game server (GameServer and all its modules) in the simulator with two fake players, flies them to a
-- planet and runs every new system through its paces: all 16 weathers, a boss fight, the Golden Egg race, a cave, the
-- three new world events, the offline income. Fails (exit 1) on any script error or game warning.
local task = require("@lune/task")
local process = require("@lune/process")
local R = require("./runtime")
local roblox = require("@lune/roblox")
local Vector3, Vector2, CFrame = roblox.Vector3, roblox.Vector2, roblox.CFrame

local game = R.Load(process.args[1], "server")
local workspace = R.workspace
local RS = game:GetService("ReplicatedStorage")
local PFE = RS:FindFirstChild("PFE")
local Players = game:GetService("Players")

-- quicker clocks for the test (the shared tables are patched before the server reads them)
local Config = R.Require(PFE:FindFirstChild("Config"))
local Life = R.Require(PFE:FindFirstChild("LifeConfig"))
Config.Bots.Enabled = false
Life.WeatherDuration = {200, 200}
Life.Boss.First, Life.Boss.Every, Life.Boss.Duration = 9999, 9999, 40
Life.Golden.First, Life.Golden.Every, Life.Golden.Duration = 9999, 9999, 30
Life.Caves.LootRespawn = 5

local function section(name) print(("\n==== %s ===="):format(name)) end
local function ok(cond, text)
	if not cond then table.insert(R.Errors, "CHECK FAILED: " .. text); print("FAIL  " .. text) else print("ok    " .. text) end
end
local function count(kind, player)
	local n = 0
	for _, e in ipairs(R.Effects) do
		if e.Remote == "Effect" and e.Args[1] == kind and (not player or e.Player == player) then n += 1 end
	end
	return n
end

section("boot")
local server = game:GetService("ServerScriptService"):FindFirstChild("GameServer")
R.Run(server)
task.wait(1)
local alice = R.AddPlayer("Alice")
local bob = R.AddPlayer("Bob")
task.wait(2)
ok(alice.Character ~= nil and alice.Character:FindFirstChild("HumanoidRootPart") ~= nil, "characters spawn")
local backpack = alice:FindFirstChildOfClass("Backpack")
ok(backpack:FindFirstChild("Flashlight") ~= nil, "the flashlight is in the backpack")
ok(backpack:FindFirstChild("Bat") ~= nil and backpack:FindFirstChild("Raygun") ~= nil, "bat and raygun too")
local PlanetLife = R.Require(server:FindFirstChild("PlanetLife"))
local ctx = PlanetLife.Ctx
ok(ctx ~= nil, "PlanetLife is up")
if not ctx then print("boot failed"); process.exit(1) end
local profileA, profileB = ctx.profiles[alice], ctx.profiles[bob]
ok(profileA ~= nil and profileB ~= nil, "profiles")
ok(ctx.maxOxygen(profileA) == 80, "air starts at 80 (got " .. tostring(ctx.maxOxygen(profileA)) .. ")")

section("offline income")
profileA.Persistent = true
profileA.OfflineSettled = nil
profileA.Data.LastSeen = os.time() - 3600
profileA.Data.Pets = {{Id = "p1", Species = Config.PetList[5].Species, Scale = 1, Mutation = "Normal"}}
local before = profileA.Data.Coins
ctx.payOffline(profileA)
local _, income = ctx.petList(profileA)
ok(profileA.Data.Coins - before == income * 3600, ("offline: %d coins for an hour at %d/s"):format(profileA.Data.Coins - before, income))
ok(count("OfflineIncome", alice) == 1, "the welcome-back card is sent")
profileA.Persistent = false

section("fly to Frostia")
local action = PFE:FindFirstChild("Action")
R.Event(action, "OnServerEvent"):Fire(alice, "DevVisit", "Frostia")
R.Event(action, "OnServerEvent"):Fire(bob, "DevVisit", "Frostia")
task.wait(10)
ok(profileA.Planet == "Frostia" and profileA.Expedition ~= nil, "Alice landed on Frostia")
ok(profileB.Planet == "Frostia", "Bob landed on Frostia")
local planet = Config.Planets.Frostia
local origin = planet.Origin
-- (the test players never run out of air or health: what's tested is the world around them)
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, p in ipairs({profileA, profileB}) do
			if p.Expedition then p.Oxygen = ctx.maxOxygen(p) end
			local h = ctx.humanoid(p.Player)
			if h and h.Health > 0 then h.Health = 100 end
		end
	end
end)
-- no eggs at the rocket
local pickups = workspace:FindFirstChild("PFE_Pickups"):FindFirstChild("Frostia")
local nearest = math.huge
for _, item in ipairs(pickups:GetChildren()) do
	local proxy = item:FindFirstChild("Pickup")
	if proxy and not item:GetAttribute("IslandId") then
		nearest = math.min(nearest, Vector2.new(proxy.Position.X - origin.X, proxy.Position.Z - origin.Z).Magnitude)
	end
end
ok(nearest >= Config.NearEggs.RocketClear, ("no egg within %d studs of the rocket (nearest %d, %d eggs)"):format(Config.NearEggs.RocketClear, nearest, #pickups:GetChildren()))

-- the explorers wander about 300-500 studs out
local function wander()
	for _, p in ipairs({alice, bob}) do
		local a = math.random() * math.pi * 2
		local d = 300 + math.random() * 200
		R.Teleport(p, origin + Vector3.new(math.cos(a) * d, 3, math.sin(a) * d))
	end
end
wander()

section("every weather")
local seen = {}
for id in pairs(Life.Weather) do
	PlanetLife.ForceWeather("Frostia", id, 60)
	for _ = 1, 8 do
		task.wait(0.5)
		if math.random() < 0.3 then wander() end
	end
	seen[id] = true
	-- keep them alive and breathing
	for _, p in ipairs({profileA, profileB}) do
		local h = ctx.humanoid(p.Player)
		if h then h.Health = 100 end
		p.Oxygen = ctx.maxOxygen(p)
	end
end
local n = 0
for _ in pairs(seen) do n += 1 end
ok(n >= 16, n .. " weathers ran")
ok(count("LifeStrike") > 10, count("LifeStrike") .. " strikes")
ok(count("LifeSprout") > 0, count("LifeSprout") .. " crystals / ice blocks sprouted")

section("smashing things")
local lifeFolder = workspace:FindFirstChild("PFE_PlanetLife"):FindFirstChild("Frostia")
local target
for _, m in ipairs(lifeFolder:GetChildren()) do
	if m:IsA("Model") and m:GetAttribute("HP") and not m:GetAttribute("Boss") then target = m; break end
end
if not target then
	target = PlanetLife.Breakable("Frostia", "Geode", CFrame.new(origin + Vector3.new(400, 0, 0)), {}).Model
end
local bat = backpack:FindFirstChild("Bat")
bat.Parent = alice.Character
local smash = PFE:FindFirstChild("Smash")
R.Teleport(alice, target.PrimaryPart.Position + Vector3.new(4, 3, 0))
task.wait(0.3)
local hp0 = target:GetAttribute("HP")
for _ = 1, 12 do
	R.Event(smash, "OnServerEvent"):Fire(alice, target)
	task.wait(0.8)
	if not target.Parent then break end
end
ok(target.Parent == nil, ("the bat broke a %s (hp %d)"):format(tostring(target:GetAttribute("Kind")), hp0))
ok(count("LifeShatter", alice) > 0, "shards fly")

section("raygun on a crystal")
local crystal = PlanetLife.Breakable("Frostia", "Crystal", CFrame.new(origin + Vector3.new(0, 0, 420)), {})
R.Teleport(alice, origin + Vector3.new(0, 3, 400))
bat.Parent = backpack
local gun = backpack:FindFirstChild("Raygun")
gun.Parent = alice.Character
local raygun = PFE:FindFirstChild("Raygun")
for _ = 1, 8 do
	R.Event(raygun, "OnServerEvent"):Fire(alice, crystal.Model.PrimaryPart.Position)
	task.wait(0.25)
end
ok(crystal.Model:GetAttribute("HP") < crystal.Max, ("laser hits crystals (hp %d/%d)"):format(crystal.Model:GetAttribute("HP"), crystal.Max))
gun.Parent = backpack

section("boss")
ok(PlanetLife.Bosses.SpawnNow(), "a boss wakes up")
local boss = PlanetLife.Bosses.Current()
ok(boss ~= nil and boss.Planet == "Frostia", "on the explorers' planet: " .. tostring(boss and boss.Def.Name))
task.wait(3)
bat.Parent = alice.Character
local hits = 0
for _ = 1, 160 do
	local b = PlanetLife.Bosses.Current()
	if not b then break end
	R.Teleport(alice, b.Position + Vector3.new(6, 3, 0))
	R.Teleport(bob, b.Position + Vector3.new(-6, 3, 0))
	R.Event(smash, "OnServerEvent"):Fire(alice, b.Model)
	b.HP = math.max(1, b.HP - 60) -- (Bob helps)
	hits += 1
	for _, p in ipairs({profileA, profileB}) do local h = ctx.humanoid(p.Player); if h then h.Health = 100 end end
	task.wait(0.8)
end
ok(PlanetLife.Bosses.Current() == nil, "the boss went down after " .. hits .. " swings")
ok(count("BossReward", alice) == 1, "Alice got her reward")
ok(count("BossAct") > 0, count("BossAct") .. " boss actions shown")
task.wait(3)

section("golden egg race")
-- (rockets that reach Frostia: the race picks among the planets somebody's rocket reaches)
profileA.Data.RocketLevel, profileB.Data.RocketLevel = #Config.Rockets, #Config.Rockets
ok(PlanetLife.GoldenRace.StartNow(), "the race starts")
local race = PlanetLife.GoldenRace.Current()
ok(race ~= nil, "on " .. tostring(race and race.Planet))
for _ = 1, 15 do
	-- make it ours for the test: again until it's on Frostia
	if race and race.Planet == "Frostia" then break end
	PlanetLife.GoldenRace.StartNow()
	race = PlanetLife.GoldenRace.Current()
end
task.wait(1)
local golden
for _ = 1, 20 do
	race = PlanetLife.GoldenRace.Current()
	for _, item in ipairs(pickups:GetChildren()) do if item:GetAttribute("GoldenRace") then golden = item end end
	if golden or not race or race.Planet ~= "Frostia" then break end
	task.wait(0.25)
end
if golden then
	bat.Parent = backpack
	R.Teleport(alice, golden.Pickup.Position)
	task.wait(0.2)
	R.Event(golden.Pickup:FindFirstChild("CollectPickup"), "Triggered"):Fire(alice)
	task.wait(0.6)
	ok(profileA.Expedition.CarryingEgg and profileA.Expedition.CarryingEgg.GoldenRace == true, "Alice holds the Golden Egg")
	ok(workspace:GetAttribute("PFEGoldenCarrier") == alice.UserId, "everybody sees who holds it")
	-- Bob bats it out of her hands
	R.Teleport(bob, alice.Character.HumanoidRootPart.Position + Vector3.new(3, 0, 0))
	local bobBat = bob:FindFirstChildOfClass("Backpack"):FindFirstChild("Bat")
	bobBat.Parent = bob.Character
	R.Event(PFE:FindFirstChild("Bat"), "OnServerEvent"):Fire(bob, alice.UserId)
	task.wait(0.6)
	ok(profileB.Expedition.CarryingEgg and profileB.Expedition.CarryingEgg.GoldenRace == true, "Bob knocked it away and holds it now")
	bobBat.Parent = bob:FindFirstChildOfClass("Backpack")
	-- Bob runs to his rocket
	local deck = workspace.PlanetForEggs.Planets.Frostia:FindFirstChild("LandingDeck")
	R.Teleport(bob, deck.Position + Vector3.new(0, 3, 0))
	task.wait(2.5)
	ok(PlanetLife.GoldenRace.Current() == nil, "the race is over")
	ok(count("GoldenWon", bob) == 1, "Bob won it")
else
	print("(the race went to " .. tostring(race and race.Planet) .. " - nobody explores it: the egg waits in the air)")
	ok(race ~= nil and not pickups:FindFirstChild("GoldenEgg"), "a race on an empty planet waits")
end

section("caves")
local mouth
for _, m in ipairs(lifeFolder:GetChildren()) do if m:GetAttribute("CaveMouth") == "Shallow Cave" then mouth = m end end
ok(mouth ~= nil, "the cave mouths stand on the planet")
local pad = mouth:FindFirstChild("CavePad")
R.Teleport(alice, pad.Position + Vector3.new(0, 3, 0))
task.wait(0.2)
R.Event(pad:FindFirstChild("EnterCave"), "Triggered"):Fire(alice)
for _ = 1, 40 do if alice:GetAttribute("PFECave") then break end; task.wait(0.25) end
ok(alice:GetAttribute("PFECave") == "Shallow Cave", "Alice is in the Shallow Cave")
ok(profileA.InCave == "Frostia", "the server knows")
local caves = workspace:FindFirstChild("PFE_Caves"):FindFirstChild("Frostia_Caves")
local chambers = {}
for _, c in ipairs(caves:GetChildren()) do if c.Name:match("^Chamber") then table.insert(chambers, c) end end
table.sort(chambers, function(a, b) return tonumber(a.Name:sub(8)) < tonumber(b.Name:sub(8)) end)
ok(#chambers >= 16, #chambers .. " chambers")
local parts = 0
for _, d in ipairs(caves:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
print("     cave parts: " .. parts)
-- walk down through every chamber; smash what's there
bat.Parent = alice.Character
local deepest = 0
for _, chamber in ipairs(chambers) do
	local floor = chamber:FindFirstChild("Floor")
	R.Teleport(alice, floor.Position + Vector3.new(0, 4, 0))
	profileA.Oxygen = ctx.maxOxygen(profileA)
	local h = ctx.humanoid(alice); if h then h.Health = 100 end
	task.wait(0.6)
	deepest = math.max(deepest, alice:GetAttribute("PFECaveDepth") or 0)
	for _, m in ipairs(lifeFolder:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("HP") and m.PrimaryPart and (m.PrimaryPart.Position - floor.Position).Magnitude < 40 then
			R.Teleport(alice, m.PrimaryPart.Position + Vector3.new(3, 3, 0))
			for _ = 1, 10 do
				if not m.Parent then break end
				R.Event(smash, "OnServerEvent"):Fire(alice, m)
				task.wait(0.72)
			end
		end
	end
end
ok(deepest >= Life.Caves.MainLength - 1, "reached depth " .. deepest)
ok(profileA.Data.Stats.CavesExplored >= 1, "the Deep Vault was opened")
bat.Parent = backpack
-- out again
local way
for _, d in ipairs(caves:GetChildren()) do if d.Name == "WayOut" then way = d end end
R.Event(way:FindFirstChild("ClimbOut"), "Triggered"):Fire(alice)
task.wait(0.5)
ok(alice:GetAttribute("PFECave") == nil and profileA.InCave == nil, "climbed out")

section("world events")
local Events = R.Require(server:FindFirstChild("Events"))
wander()
for _, id in ipairs({"TreasureComet", "CoinRain", "EggTornado"}) do
	Events.Start(id)
	task.wait(6)
	ok(workspace:GetAttribute("PFEEvent") == id, id .. " runs")
end
ok(count("LifeCoinDrop") > 0, "coins rained")
-- an admin starts another event over the Egg Tornado: its tornadoes go
local tornados = 0
for _, z in pairs(PlanetLife.Zones()) do if z.Kind == "Tornado" then tornados += 1 end end
Events.Start("CoinRain")
task.wait(0.5)
local left = 0
for _, z in pairs(PlanetLife.Zones()) do if z.Kind == "Tornado" then left += 1 end end
ok(tornados > 0 and left == 0, ("an event started over the Egg Tornado takes its tornadoes away (%d -> %d)"):format(tornados, left))

section("errors caught by pcall (Studio pauses on these)")
for _, c in ipairs(R.CaughtSummary()) do print(("  %4dx  %s"):format(c.N, c.Key)) end

section("summary")
local real = {}
for _, w in ipairs(R.Warnings) do
	if not w:find("kicked") then table.insert(real, w) end
end
print(("errors: %d   warnings: %d   effects: %d"):format(#R.Errors, #real, #R.Effects))
for i = 1, math.min(#real, 25) do print("  warn: " .. real[i]) end
process.exit((#R.Errors > 0 or #real > 0) and 1 or 0)
