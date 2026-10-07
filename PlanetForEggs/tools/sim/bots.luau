-- lune run tools/sim/bots.luau <built place.rbxl>
-- Boots the game server with the bots on, in a flat simple world: avatars are a few blocks, Humanoid:Move walks them over
-- the ground (the island at the Meteor Run circle's height, the planets at their origin's) 30 times a second, a downward
-- raycast finds that ground. No real physics - it is the bots' decisions that are tested: the four wanderers and the
-- based bots doing their things on the island, a thief caught, a wanderer hit and lost and back, bots flying out to a
-- planet's boss and Golden Egg, the based bots leaving for real players while the wanderers stay.
local task = require("@lune/task")
local process = require("@lune/process")
local R = require("./runtime")
local roblox = require("@lune/roblox")
local Vector3, CFrame, Instance, Enum = roblox.Vector3, roblox.CFrame, roblox.Instance, roblox.Enum

local game = R.Load(process.args[1], "server")
local workspace = R.workspace
local RS = game:GetService("ReplicatedStorage")
local PFE = RS:FindFirstChild("PFE")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = R.Require(PFE:FindFirstChild("Config"))
local Life = R.Require(PFE:FindFirstChild("LifeConfig"))
Config.Bots.Enabled = true
Config.Bots.Max = 4
Config.Bots.JoinDelay = {0.3, 0.6}
Config.Bots.Ambient = 4
Config.Bots.StudioPreview = false
Life.Boss.First, Life.Boss.Every, Life.Boss.Duration = 9999, 9999, 120
Life.Golden.First, Life.Golden.Every, Life.Golden.Duration = 9999, 9999, 120

local function section(name) print(("\n==== %s ===="):format(name)) end
local function ok(cond, text)
	if not cond then table.insert(R.Errors, "CHECK FAILED: " .. text); print("FAIL  " .. text) else print("ok    " .. text) end
end

-- ---------------------------------------------------------------- a simple world
local islandY, islandCentre, islandRadius = nil, nil, 0
local function groundAt(p)
	for _, planet in ipairs(Config.PlanetOrder) do
		local o = planet.Origin
		if Vector3.new(p.X - o.X, 0, p.Z - o.Z).Magnitude < (planet.Radius or 2800) then return o.Y end
	end
	if islandY and Vector3.new(p.X - islandCentre.X, 0, p.Z - islandCentre.Z).Magnitude < islandRadius then return islandY end
	return nil
end
local groundPart = Instance.new("Part")
groundPart.Name = "SimGround"
R.Raycast = function(origin, direction)
	if direction.Y >= -0.5 then return nil end
	local g = groundAt(origin)
	if g and origin.Y >= g - 0.5 and origin.Y + direction.Y <= g then
		return {Position = Vector3.new(origin.X, g, origin.Z), Normal = Vector3.new(0, 1, 0), Instance = groundPart,
			Material = Enum.Material.Grass, Distance = origin.Y - g}
	end
	return nil
end
-- avatars: a few blocks with a humanoid (enough for the bots' code)
R.MakeAvatar = function()
	local model = Instance.new("Model")
	local function limb(name, size, offset)
		local p = Instance.new("Part")
		p.Name = name; p.Size = size; p.CFrame = CFrame.new(offset); p.Parent = model
		return p
	end
	local root = limb("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
	limb("UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 3.4, 0))
	limb("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.8, 0))
	local hand = limb("RightHand", Vector3.new(0.6, 0.6, 0.6), Vector3.new(1.5, 2, 0))
	local grip = Instance.new("Attachment"); grip.Name = "RightGripAttachment"; grip.Parent = hand
	model.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Parent = model
	local animator = Instance.new("Animator"); animator.Parent = humanoid
	return model
end
local moveDir = setmetatable({}, {__mode = "k"})
roblox.implementMethod("Humanoid", "Move", function(self, dir) moveDir[self] = dir end)
pcall(roblox.implementProperty, "Humanoid", "MoveDirection", function(self) return moveDir[self] or Vector3.zero end, function() end)
pcall(roblox.implementProperty, "Humanoid", "FloorMaterial", function() return Enum.Material.Grass end, function() end)
pcall(roblox.implementProperty, "Humanoid", "Sit", function() return false end, function() end)

-- 30 steps a second: the bots' brains run on Heartbeat; their bodies walk / get knocked about / fall
local function step(dt)
	local folder = workspace:FindFirstChild("PFE_Bots")
	for _, model in ipairs(folder and folder:GetChildren() or {}) do
		local root = model:FindFirstChild("HumanoidRootPart")
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if root and humanoid and not root.Anchored and humanoid.Health > 0 then
			local p = root.Position
			local v
			if humanoid.PlatformStand then
				v = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = v - Vector3.new(0, 196 * dt, 0)
			else
				local d = moveDir[humanoid] or Vector3.zero
				v = Vector3.new(d.X, 0, d.Z) * humanoid.WalkSpeed
			end
			local nextP = p + v * dt
			local g = groundAt(nextP)
			if g and nextP.Y <= g + 3 then
				nextP = Vector3.new(nextP.X, g + 3, nextP.Z)
				if humanoid.PlatformStand then root.AssemblyLinearVelocity = Vector3.new(v.X * 0.5, 0, v.Z * 0.5) end
			elseif not humanoid.PlatformStand then
				nextP = Vector3.new(nextP.X, g and math.max(g + 3, nextP.Y - 60 * dt) or nextP.Y - 60 * dt, nextP.Z)
			end
			local look = v.Magnitude > 0.1 and Vector3.new(v.X, 0, v.Z) or root.CFrame.LookVector
			if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
			model:PivotTo(CFrame.lookAt(nextP, nextP + look.Unit))
		end
	end
	R.Event(RunService, "Heartbeat"):Fire(dt)
end
task.spawn(function()
	while true do
		local ok2, err = pcall(step, 1 / 30)
		if not ok2 then table.insert(R.Errors, "sim step: " .. tostring(err)) end
		task.wait(1 / 30)
	end
end)

-- ---------------------------------------------------------------- boot
section("boot")
local server = game:GetService("ServerScriptService"):FindFirstChild("GameServer")
R.Run(server)
task.wait(1)
local PlanetLife = R.Require(server:FindFirstChild("PlanetLife"))
local ctx = PlanetLife.Ctx
ok(ctx ~= nil, "the server is up")
if not ctx then process.exit(1) end
islandCentre = ctx.Minigame.ZoneCenter()
islandY = islandCentre.Y
for _, base in ipairs(ctx.bases:GetChildren()) do
	local s = base:FindFirstChild("Spawn")
	if s then
		islandRadius = math.max(islandRadius, Vector3.new(s.Position.X - islandCentre.X, 0, s.Position.Z - islandCentre.Z).Magnitude + 70)
		-- (the bases' own floors sit at their spawn's height)
	end
end
print(("     island: y %.1f, radius %d"):format(islandY, islandRadius))
local alice = R.AddPlayer("Alice")
local bob = R.AddPlayer("Bob")
task.wait(2)
local profileA, profileB = ctx.profiles[alice], ctx.profiles[bob]
R.Teleport(alice, islandCentre + Vector3.new(10, 3, 0))
R.Teleport(bob, islandCentre + Vector3.new(-10, 3, 0))
local Bots = ctx.Bots
local Brain = Bots.Brain
local Wanderer = R.Require(server:FindFirstChild("Bots"):FindFirstChild("Wanderer"))

section("they arrive")
task.wait(25)
ok(#Bots.List() == 4, #Bots.List() .. " bots with a base")
ok(#Bots.Wanderers() == 4, #Bots.Wanderers() .. " wanderers")
local tracker = PFE:FindFirstChild("BotTracker")
ok(tracker and #tracker:GetChildren() == #Bots.List(), "only the based bots are in the Tab list (" .. (tracker and #tracker:GetChildren() or -1) .. ")")
for _, w in ipairs(Bots.Wanderers()) do
	ok(w.P.Base == nil and w.Tracker == nil, w.Name .. " (" .. tostring(w.Style) .. ") has no base and no Tab entry")
end

section("island life")
task.wait(60)
local function onIsland(bot)
	local r = bot.Model and bot.Model:FindFirstChild("HumanoidRootPart")
	return r and Vector3.new(r.Position.X - islandCentre.X, 0, r.Position.Z - islandCentre.Z).Magnitude < islandRadius
end
for _, w in ipairs(Bots.Wanderers()) do ok(onIsland(w), w.Name .. " is on the island") end
local kinds = 0
for k, v in pairs(Wanderer.Stats) do kinds += 1; print(("     wanderers: %-10s %d"):format(k, v)) end
ok(kinds >= 6, kinds .. " different things the wanderers did")
for k, v in pairs(Brain.Stats) do print(("     bots:      %-12s %d"):format(k, v)) end

section("a thief")
-- Alice takes an egg out of a bot's pen: the bots and the wanderers around go after her
local victim
for _, bot in ipairs(Bots.List()) do if #bot.P.Data.GrowingEggs > 0 then victim = bot end end
if victim then
	-- (past the newcomers' protection, no shield)
	while ctx.Bases.IsProtected(victim.P) do
		table.insert(victim.P.Data.Pets, {Id = ctx.Data.Guid(), Species = Config.PetList[1].Species, Scale = 1, Mutation = "Normal"})
	end
	victim.P.ShieldUntil = 0
	local egg = victim.P.Data.GrowingEggs[1]
	local point = ctx.Bases.EggPoint(victim.P, egg)
	R.Teleport(alice, point + Vector3.new(0, 3, 0))
	-- the wanderers are about (a few steps from the pen)
	for i, w in ipairs(Bots.Wanderers()) do
		if w.Model and not w.Dead then w.Model:PivotTo(CFrame.new(point + Vector3.new(math.cos(i) * 14, 3, math.sin(i) * 14))) end
	end
	ctx.Bases.TrySteal(profileA, victim.P, egg.Id)
	ok(profileA.Stolen ~= nil, "Alice is holding a stolen egg")
	for _ = 1, 90 do
		if not profileA.Stolen then break end
		task.wait(0.5)
	end
	ok(profileA.Stolen == nil, "somebody knocked it out of her hands")
	if profileA.Stolen then ctx.Bases.CancelSteal(profileA, "test") end
	print(("     catches: wanderers %d, bots %d (hits %d)"):format(Wanderer.Stats.Catch or 0, (Brain.Stats.Snatch or 0), Brain.Stats.Hit or 0))
else
	print("     (no bot has an egg growing)")
end
R.Teleport(alice, islandCentre + Vector3.new(10, 3, 0))

section("a wanderer gets hit, falls off, comes back")
local w1 = Bots.Wanderers()[1]
local wr = w1.Model.HumanoidRootPart
R.Teleport(alice, wr.Position + Vector3.new(3, 0, 0))
local bat = alice:FindFirstChildOfClass("Backpack"):FindFirstChild("Bat")
bat.Parent = alice.Character
R.Event(PFE:FindFirstChild("Bat"), "OnServerEvent"):Fire(alice, -w1.Id)
task.wait(0.3)
ok(w1.Model.Humanoid.PlatformStand == true, "knocked off its feet")
bat.Parent = alice:FindFirstChildOfClass("Backpack")
task.wait(4)
w1.Model:PivotTo(CFrame.new(islandCentre + Vector3.new(islandRadius + 300, -200, 0)))
task.wait(2)
ok(w1.Dead == true, "fell off the island")
task.wait(8)
ok(not w1.Dead and w1.Model and w1.Model.Parent ~= nil and onIsland(w1), "back on the island")
ok(#Bots.Wanderers() == 4 and #tracker:GetChildren() == #Bots.List(), "still 4 wanderers, still not in the Tab list")

section("the boss and the Golden Egg on the Moon")
local action = PFE:FindFirstChild("Action")
R.Event(action, "OnServerEvent"):Fire(bob, "DevVisit", "Moon")
task.wait(10)
ok(profileB.Planet == "Moon", "Bob is on the Moon")
local moon = Config.Planets.Moon
R.Teleport(bob, moon.Origin + Vector3.new(160, 3, 0))
for _ = 1, 40 do if not profileB.Busy then break end; task.wait(0.5) end
print(("     explorers on the Moon: %d (Bob busy %s, expedition %s)"):format(#PlanetLife.SurfaceExplorers("Moon"), tostring(profileB.Busy),
	tostring(profileB.Expedition and profileB.Expedition.Planet)))
ok(PlanetLife.Bosses.SpawnNow(), "a boss wakes up")
do
	local b = PlanetLife.Bosses.Current()
	local r = bob.Character and bob.Character:FindFirstChild("HumanoidRootPart")
	if b and r then print(("     the boss came up %d studs from Bob"):format((b.Position - r.Position).Magnitude)) end
end
ok(PlanetLife.Bosses.Current() and PlanetLife.Bosses.Current().Planet == "Moon", "on the Moon")
-- keep Bob alive and breathing out there
task.spawn(function()
	while true do
		task.wait(1)
		profileB.Oxygen = ctx.maxOxygen(profileB)
		local h = ctx.humanoid(bob)
		if h then h.Health = 100 end
	end
end)
local onMoon = 0
for _ = 1, 120 do
	task.wait(1)
	onMoon = 0
	local b = PlanetLife.Bosses.Current()
	for _, bot in ipairs(Bots.List()) do
		if bot.P.Planet == "Moon" and bot.Shown then
			onMoon += 1
			-- (whoever is out there joins in, for the test)
			if b and bot.BossFor ~= b then bot.BossFor = b; bot.BossWish = true end
		end
	end
	if (Brain.Stats.BossHit or 0) + (Brain.Stats.BossShot or 0) > 6 then break end
	if _ % 10 == 0 then
		for _, bot in ipairs(Bots.List()) do
			if bot.P.Planet == "Moon" then
				local r = bot.Model and bot.Model:FindFirstChild("HumanoidRootPart")
				print(("     t%d %s: shown %s doing %s wish %s d %s air %d busy %s"):format(_, bot.Name, tostring(bot.Shown), tostring(bot.Doing), tostring(bot.BossWish),
					b and r and tostring(math.floor((b.Position - r.Position).Magnitude)) or "-", bot.P.Oxygen or -1, tostring(bot.P.Busy)))
			end
		end
	end
end
print(("     %d of the bots heard the call (Rally)"):format(Brain.Stats.Rally or 0))
ok(onMoon > 0, onMoon .. " bot(s) came out to the Moon")
ok((Brain.Stats.BossHit or 0) + (Brain.Stats.BossShot or 0) > 0, "bots fight the boss (" .. (Brain.Stats.BossHit or 0) .. " bat hits, " .. (Brain.Stats.BossShot or 0) .. " raygun hits)")
local boss = PlanetLife.Bosses.Current()
if boss then print(("     boss HP %d/%d"):format(boss.HP, boss.Max)) end
-- the Golden Egg, a short run from the rocket for the test
ok(PlanetLife.GoldenRace.StartNow(), "the Golden Egg race starts")
local race = PlanetLife.GoldenRace.Current()
print("     the egg is on " .. tostring(race and race.Planet))
if race and race.Planet == "Moon" and race.Item then
	ctx.Expeditions.TakeOutPickup(race.Item)
	race.Position = moon.Origin + Vector3.new(-220, 0, 90)
	race.Item = ctx.Expeditions.SpawnGoldenEgg("Moon", race.Position, race.Egg)
end
for _ = 1, 80 do
	task.wait(1)
	if PlanetLife.GoldenRace.Current() == nil or (Brain.Stats.GoldenPickup or 0) > 0 then break end
end
local carrier = race and race.Carrier
print(("     the race: %s"):format(PlanetLife.GoldenRace.Current() == nil and "over" or carrier and ("carried by " .. carrier.Player.DisplayName) or "the egg is lying out there"))
ok((Brain.Stats.Golden or 0) > 0, "bots race for the Golden Egg (" .. (Brain.Stats.GoldenPickup or 0) .. " pickups)")
task.wait(10)
print(("     golden: %d hunts, %d pickups; dodged %d, smashed %d, sheltered %d"):format(Brain.Stats.Golden or 0, Brain.Stats.GoldenPickup or 0,
	Brain.Stats.Dodged or 0, Brain.Stats.Smashed or 0, Brain.Stats.Shelter or 0))
for _, w in ipairs(Bots.Wanderers()) do ok(w.P.Planet == "Base", w.Name .. " stayed on the island") end

section("players join: the based bots make room, the wanderers stay")
local extra = {}
for i = 1, 7 do
	table.insert(extra, R.AddPlayer("P" .. i))
	task.wait(0.4)
end
task.wait(4)
local based = #Bots.List()
ok(based <= 9 - 9, based .. " based bots left (9 players)")
ok(#Bots.Wanderers() == 4, "the 4 wanderers are still here")

section("errors caught by pcall (Studio pauses on these)")
for _, c in ipairs(R.CaughtSummary()) do print(("  %4dx  %s"):format(c.N, c.Key)) end

section("summary")
local real = {}
for _, w in ipairs(R.Warnings) do
	if not w:find("kicked") then table.insert(real, w) end
end
print(("errors: %d   warnings: %d"):format(#R.Errors, #real))
for i = 1, math.min(#R.Errors, 25) do print("  error: " .. tostring(R.Errors[i]):sub(1, 600)) end
for i = 1, math.min(#real, 25) do print("  warn: " .. real[i]:sub(1, 400)) end
process.exit((#R.Errors > 0 or #real > 0) and 1 or 0)
