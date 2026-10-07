-- lune run tools/sim/client.luau <built place.rbxl>
-- "Play solo" in the simulator: the game server AND one player's LocalScripts (ReplicatedFirst, StarterPlayerScripts,
-- each with its own copy of the ModuleScripts) in one DataModel. Remotes are looped back (FireClient / FireAllClients ->
-- the client's OnClientEvent, FireServer -> the server's OnServerEvent; values copied the way Roblox copies them, with a
-- warning for what Roblox wouldn't send). RenderStepped / Heartbeat tick 30 times a second. The player presses PLAY on the
-- title screen, flies to Frostia, goes through every weather, a boss, the Golden Egg, a cave, the events and home again.
-- Fails (exit 1) on any error in any script - client ones included - or any warning.
local task = require("@lune/task")
local process = require("@lune/process")
local R = require("./runtime")
local roblox = require("@lune/roblox")
local Vector3, Vector2, CFrame, Instance, Enum, Rect = roblox.Vector3, roblox.Vector2, roblox.CFrame, roblox.Instance, roblox.Enum, roblox.Rect

local game = R.Load(process.args[1], "server")
local workspace = R.workspace
local RS = game:GetService("ReplicatedStorage")
local PFE = RS:FindFirstChild("PFE")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = R.Require(PFE:FindFirstChild("Config"))
local Life = R.Require(PFE:FindFirstChild("LifeConfig"))
Config.Bots.Enabled = false
Life.WeatherDuration = {200, 200}
Life.Boss.First, Life.Boss.Every, Life.Boss.Duration = 9999, 9999, 60
Life.Golden.First, Life.Golden.Every, Life.Golden.Duration = 9999, 9999, 40

local function section(name) print(("\n==== %s ===="):format(name)) end
local function ok(cond, text)
	if not cond then table.insert(R.Errors, "CHECK FAILED: " .. text); print("FAIL  " .. text) else print("ok    " .. text) end
end

-- ---------------------------------------------------------------- what a client has that a server doesn't
local function prop(class, name, get, set)
	local okP, err = pcall(roblox.implementProperty, class, name, get, set or function() end)
	if not okP then print("     (sim: " .. class .. "." .. name .. ": " .. tostring(err) .. ")") end
end
local function method(class, name, fn)
	local okM, err = pcall(roblox.implementMethod, class, name, fn)
	if not okM then print("     (sim: " .. class .. ":" .. name .. ": " .. tostring(err) .. ")") end
end
local store = setmetatable({}, {__mode = "k"})
local function field(inst, key, default)
	local t = store[inst]
	if t and t[key] ~= nil then return t[key] end
	return default
end
local function setField(inst, key, value)
	store[inst] = store[inst] or {}
	store[inst][key] = value
end
local VIEW = Vector2.new(1280, 720)
local camera = Instance.new("Camera")
camera.Name = "Camera"
camera.Parent = workspace
prop("Workspace", "CurrentCamera", function() return camera end)
prop("Players", "LocalPlayer", function() return R.LocalPlayer end)
prop("Camera", "ViewportSize", function() return VIEW end)
method("Camera", "WorldToViewportPoint", function(_, p) return Vector3.new(640 + (p.X % 300), 360, 20), true end)
method("Camera", "WorldToScreenPoint", function(_, p) return Vector3.new(640 + (p.X % 300), 360, 20), true end)
method("Camera", "ScreenPointToRay", function() return roblox.Ray.new(Vector3.new(0, 80, 0), Vector3.new(0, 0, -1)) end)
method("Camera", "ViewportPointToRay", function() return roblox.Ray.new(Vector3.new(0, 80, 0), Vector3.new(0, 0, -1)) end)
local function absSize(self)
	if self:IsA("ScreenGui") then return VIEW end
	local okS, size = pcall(function() return self.Size end)
	if okS and typeof(size) == "UDim2" then
		local parent = self.Parent
		local ps = (parent and parent:IsA("GuiBase2d")) and parent.AbsoluteSize or VIEW
		return Vector2.new(size.X.Offset + size.X.Scale * ps.X, size.Y.Offset + size.Y.Scale * ps.Y)
	end
	return Vector2.new(100, 100)
end
prop("GuiBase2d", "AbsoluteSize", absSize)
prop("GuiBase2d", "AbsolutePosition", function() return Vector2.new(0, 0) end)
prop("GuiBase2d", "AbsoluteRotation", function() return 0 end)
for _, class in ipairs({"TextLabel", "TextButton", "TextBox"}) do
	prop(class, "TextBounds", function(self) return Vector2.new(#self.Text * self.TextSize * 0.5, self.TextSize) end)
	prop(class, "TextFits", function() return true end)
end
prop("ScrollingFrame", "AbsoluteCanvasSize", function(self) return self.AbsoluteSize end)
prop("ScrollingFrame", "AbsoluteWindowSize", function(self) return self.AbsoluteSize end)
prop("UIGridStyleLayout", "AbsoluteContentSize", function() return Vector2.new(400, 400) end)
local UIS = game:GetService("UserInputService")
for name, value in pairs({TouchEnabled = false, KeyboardEnabled = true, MouseEnabled = true, GamepadEnabled = false, AccelerometerEnabled = false,
	GyroscopeEnabled = false, VREnabled = false, OnScreenKeyboardVisible = false}) do
	prop("UserInputService", name, function() return value end)
end
prop("UserInputService", "MouseBehavior", function(self) return field(self, "MB", Enum.MouseBehavior.Default) end, function(self, v) setField(self, "MB", v) end)
prop("UserInputService", "MouseIconEnabled", function(self) return field(self, "MI", true) end, function(self, v) setField(self, "MI", v) end)
method("UserInputService", "IsKeyDown", function() return false end)
method("UserInputService", "IsGamepadButtonDown", function() return false end)
method("UserInputService", "IsMouseButtonPressed", function() return false end)
method("UserInputService", "GetStringForKeyCode", function() return "E" end)
method("UserInputService", "GetMouseLocation", function() return Vector2.new(640, 360) end)
method("UserInputService", "GetLastInputType", function() return Enum.UserInputType.Keyboard end)
method("UserInputService", "GetFocusedTextBox", function() return nil end)
method("UserInputService", "GetConnectedGamepads", function() return {} end)
method("UserInputService", "GetGamepadConnected", function() return false end)
method("UserInputService", "GetKeysPressed", function() return {} end)
local GuiService = game:GetService("GuiService")
method("GuiService", "GetGuiInset", function() return Vector2.new(0, 58), Vector2.new(0, 0) end)
method("GuiService", "IsTenFootInterface", function() return false end)
prop("GuiService", "MenuIsOpen", function() return false end)
prop("GuiService", "TopbarInset", function() return Rect.new(0, 0, 1280, 58) end)
prop("GuiService", "SelectedObject", function(self) return field(self, "Sel", nil) end, function(self, v) setField(self, "Sel", v) end)
for _, name in ipairs({"SetCoreGuiEnabled", "SetCore"}) do method("StarterGui", name, function() end) end
method("StarterGui", "GetCore", function() return nil end)
method("StarterGui", "GetCoreGuiEnabled", function() return true end)
prop("Sound", "IsPlaying", function(self) return field(self, "Playing", false) end)
prop("Sound", "IsPaused", function(self) return not field(self, "Playing", false) end)
prop("Sound", "IsLoaded", function() return true end)
prop("Sound", "TimeLength", function() return 60 end)
prop("Sound", "PlaybackLoudness", function() return 0 end)
method("Sound", "Pause", function(self) setField(self, "Playing", false) end)
method("Sound", "Resume", function(self) setField(self, "Playing", true) end)
prop("Humanoid", "FloorMaterial", function() return Enum.Material.Plastic end)
prop("Humanoid", "MoveDirection", function() return Vector3.zero end)
method("ReplicatedFirst", "RemoveDefaultLoadingScreen", function() end)
prop("TextChatService", "OnIncomingMessage", function(self) return field(self, "OnIncoming", nil) end, function(self, v) setField(self, "OnIncoming", v) end)
method("TextBox", "ReleaseFocus", function() end)
method("TextBox", "CaptureFocus", function() end)
method("TextBox", "IsFocused", function() return false end)
local CAS = "ContextActionService"
for _, name in ipairs({"BindAction", "BindActionAtPriority", "UnbindAction", "SetTitle", "SetImage", "SetPosition", "SetDescription"}) do method(CAS, name, function() end) end
method(CAS, "GetButton", function() return nil end)
R.Mouse = {Hit = CFrame.new(0, 60, -50), Target = nil, X = 640, Y = 360, Icon = "", TargetFilter = nil, UnitRay = roblox.Ray.new(Vector3.zero, Vector3.new(0, 0, -1)),
	Button1Down = R.Signal.new(), Button1Up = R.Signal.new(), Button2Down = R.Signal.new(), Button2Up = R.Signal.new(), Move = R.Signal.new(),
	WheelForward = R.Signal.new(), WheelBackward = R.Signal.new(), Idle = R.Signal.new()}

-- ---------------------------------------------------------------- remotes between the two sides
local SERVER_ONLY = {game:GetService("ServerStorage"), game:GetService("ServerScriptService")}
local function copy(v, seen, path)
	local t = typeof(v)
	if t == "table" then
		if getmetatable(v) ~= nil then table.insert(R.Warnings, "remote " .. path .. ": a table with a metatable (Roblox drops the metatable)") end
		seen = seen or {}
		if seen[v] then table.insert(R.Warnings, "remote " .. path .. ": a cyclic table"); return nil end
		seen[v] = true
		local out, nums, strs = {}, 0, 0
		for k, x in pairs(v) do
			if type(k) == "number" then nums += 1 elseif type(k) == "string" then strs += 1 else
				table.insert(R.Warnings, "remote " .. path .. ": a " .. typeof(k) .. " key (Roblox only sends string / array keys)") end
			out[k] = copy(x, seen, path .. "." .. tostring(k))
		end
		if nums > 0 and strs > 0 then table.insert(R.Warnings, "remote " .. path .. ": a mixed table (Roblox loses part of it)") end
		seen[v] = nil
		return out
	elseif t == "function" or t == "thread" then
		table.insert(R.Warnings, "remote " .. path .. ": a " .. t .. " (Roblox can't send it)")
		return nil
	elseif t == "Instance" then
		for _, s in ipairs(SERVER_ONLY) do
			if v:IsDescendantOf(s) then table.insert(R.Warnings, "remote " .. path .. ": " .. v:GetFullName() .. " is server-only (the client gets nil)"); return nil end
		end
	end
	return v
end
local function copyArgs(name, ...)
	local args = table.pack(...)
	for i = 1, args.n do args[i] = copy(args[i], nil, name .. "#" .. i) end
	return args
end
R.OnFireClient = function(remote, player, ...)
	if player ~= R.LocalPlayer then return end
	local args = copyArgs(remote.Name, ...)
	R.task.defer(function() R.Event(remote, "OnClientEvent"):Fire(table.unpack(args, 1, args.n)) end)
end
R.OnFireAllClients = function(remote, ...)
	local args = copyArgs(remote.Name, ...)
	R.task.defer(function() R.Event(remote, "OnClientEvent"):Fire(table.unpack(args, 1, args.n)) end)
end
R.OnFireServer = function(remote, ...)
	local args = copyArgs(remote.Name .. "(to server)", ...)
	R.task.defer(function() R.Event(remote, "OnServerEvent"):Fire(R.LocalPlayer, table.unpack(args, 1, args.n)) end)
end

-- ---------------------------------------------------------------- the clock
local frames = 0
task.spawn(function()
	while true do
		local dt = 1 / 30
		frames += 1
		for _, name in ipairs({"Stepped", "Heartbeat", "RenderStepped"}) do
			local okF, err = pcall(function()
				if name == "Stepped" then R.Event(RunService, name):Fire(frames * dt, dt) else R.Event(RunService, name):Fire(dt) end
			end)
			if not okF then table.insert(R.Errors, "clock: " .. tostring(err)) end
		end
		task.wait(dt)
	end
end)

-- ---------------------------------------------------------------- boot
section("boot")
local server = game:GetService("ServerScriptService"):FindFirstChild("GameServer")
R.Run(server)
task.wait(1)
local alice = R.AddPlayer("Alice")
R.LocalPlayer = alice
local clientScripts = {}
for _, holder in ipairs({game:GetService("ReplicatedFirst"), game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")}) do
	for _, inst in ipairs(holder:GetChildren()) do
		if inst:IsA("LocalScript") then table.insert(clientScripts, inst) end
	end
end
for _, inst in ipairs(clientScripts) do R.Run(inst, "client") end
print(("     %d LocalScripts running"):format(#clientScripts))
task.wait(4)
local PlanetLife = R.Require(server:FindFirstChild("PlanetLife"))
local ctx = PlanetLife.Ctx
ok(ctx ~= nil, "the server is up")
if not ctx then process.exit(1) end
local profile = ctx.profiles[alice]
ok(profile ~= nil and alice.Character ~= nil, "Alice joined and has a character")
local gui = alice:FindFirstChildOfClass("PlayerGui")
ok(gui and #gui:GetChildren() > 3, "the interface is built (" .. (gui and #gui:GetChildren() or 0) .. " screens)")

section("title screen")
-- press PLAY (any button that says so)
local pressed = false
for _ = 1, 20 do
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("GuiButton") and d.Visible then
			local label = d:IsA("TextButton") and d.Text or ""
			for _, c in ipairs(d:GetDescendants()) do if c:IsA("TextLabel") then label ..= " " .. c.Text end end
			if string.find(string.upper(label), "START") or string.find(string.upper(label), "PLAY") then
				R.Event(d, "Activated"):Fire()
				R.Event(d, "MouseButton1Click"):Fire()
				pressed = true
			end
		end
	end
	if pressed then break end
	task.wait(0.5)
end
ok(pressed, "PLAY pressed")
task.wait(4)
-- the join cutscene (HalloweenIntro): SKIP
local skipped = false
for _ = 1, 60 do
	if alice:GetAttribute("PFECutscene") == false or alice:GetAttribute("PFECutscene") == nil and skipped then break end
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("TextButton") and d.Name == "Skip" then R.Event(d, "Activated"):Fire(); skipped = true end
	end
	task.wait(0.5)
end
task.wait(3)
ok(alice:GetAttribute("PFECutscene") ~= true and alice.Character.HumanoidRootPart.Anchored == false, "the join cutscene is over (skipped: " .. tostring(skipped) .. ")")

section("to Frostia")
local action = PFE:FindFirstChild("Action")
action:FireServer("DevVisit", "Frostia")
task.wait(12)
ok(profile.Planet == "Frostia", "landed on Frostia")
task.spawn(function()
	while true do
		task.wait(0.5)
		if profile.Expedition then profile.Oxygen = ctx.maxOxygen(profile) end
		local h = ctx.humanoid(alice)
		if h and h.Health > 0 then h.Health = 100 end
	end
end)
local origin = Config.Planets.Frostia.Origin
local function wander()
	local a = math.random() * math.pi * 2
	local d = 250 + math.random() * 200
	R.Teleport(alice, origin + Vector3.new(math.cos(a) * d, 3, math.sin(a) * d))
end
wander()

section("every weather on screen")
for id in pairs(Life.Weather) do
	PlanetLife.ForceWeather("Frostia", id, 60)
	for _ = 1, 6 do task.wait(0.5); if math.random() < 0.3 then wander() end end
end
ok(true, "16 weathers shown")

section("smash, shoot")
local life = workspace:FindFirstChild("PFE_PlanetLife"):FindFirstChild("Frostia")
local target
for _, m in ipairs(life:GetChildren()) do if m:IsA("Model") and m:GetAttribute("HP") and m.PrimaryPart then target = m end end
if not target then
	local rec = PlanetLife.Breakable("Frostia", "Crystal", CFrame.new(alice.Character.HumanoidRootPart.Position + Vector3.new(6, -3, 0)), {Life = 60})
	target = rec and rec.Model
end
if target then
	local bat = alice:FindFirstChildOfClass("Backpack"):FindFirstChild("Bat")
	R.Teleport(alice, target.PrimaryPart.Position + Vector3.new(3, 2, 0))
	bat.Parent = alice.Character
	R.Event(bat, "Equipped"):Fire()
	for _ = 1, 4 do R.Event(bat, "Activated"):Fire(); task.wait(0.8) end
	R.Event(bat, "Unequipped"):Fire()
	bat.Parent = alice:FindFirstChildOfClass("Backpack")
	local gun = alice:FindFirstChildOfClass("Backpack"):FindFirstChild("Raygun")
	if gun then
		gun.Parent = alice.Character
		R.Event(gun, "Equipped"):Fire()
		for _ = 1, 3 do R.Event(gun, "Activated"):Fire(); task.wait(0.5) end
		R.Event(gun, "Unequipped"):Fire()
		gun.Parent = alice:FindFirstChildOfClass("Backpack")
	end
end
local light = alice:FindFirstChildOfClass("Backpack"):FindFirstChild("Flashlight")
if light then
	light.Parent = alice.Character
	R.Event(light, "Equipped"):Fire()
	R.Event(light, "Activated"):Fire()
	task.wait(1)
	R.Event(light, "Unequipped"):Fire()
	light.Parent = alice:FindFirstChildOfClass("Backpack")
end
ok(true, "bat, raygun and flashlight used")

section("boss")
ok(PlanetLife.Bosses.SpawnNow(), "a boss wakes up")
task.wait(8)
local b = PlanetLife.Bosses.Current()
if b then
	for _ = 1, 200 do
		if not PlanetLife.Bosses.Current() then break end
		R.Teleport(alice, b.Hitbox.Position + Vector3.new(6, 0, 0))
		R.Event(PFE:FindFirstChild("Smash"), "OnServerEvent"):Fire(alice, b.Model)
		task.wait(0.4)
	end
end
ok(PlanetLife.Bosses.Current() == nil, "the boss is down")
task.wait(4)

section("golden egg")
profile.Data.RocketLevel = #Config.Rockets
for _ = 1, 15 do
	PlanetLife.GoldenRace.StartNow()
	local race = PlanetLife.GoldenRace.Current()
	if race and race.Planet == "Frostia" then break end
end
task.wait(3)
local race = PlanetLife.GoldenRace.Current()
print(("     race on %s, item %s, Alice busy %s planet %s"):format(tostring(race and race.Planet), tostring(race and race.Item), tostring(profile.Busy), tostring(profile.Planet)))
if race and race.Item then
	R.Teleport(alice, race.Item.Pickup.Position)
	task.wait(0.3)
	local rr = alice.Character.HumanoidRootPart
	print(("     Alice is %.1f studs from the egg (anchored %s, character %s)"):format((rr.Position - race.Item.Pickup.Position).Magnitude, tostring(rr.Anchored), alice.Character:GetFullName()))
	R.Event(race.Item.Pickup:FindFirstChild("CollectPickup"), "Triggered"):Fire(alice)
	task.wait(2)
	print(("     carrying: %s"):format(tostring(profile.Expedition and profile.Expedition.CarryingEgg and profile.Expedition.CarryingEgg.GoldenRace)))
	R.Teleport(alice, workspace.PlanetForEggs.Planets.Frostia.LandingDeck.Position + Vector3.new(0, 3, 0))
	task.wait(3)
end
ok(PlanetLife.GoldenRace.Current() == nil, "the Golden Egg race is over")

section("cave")
local mouth
for _, m in ipairs(life:GetChildren()) do if m:GetAttribute("CaveMouth") then mouth = m end end
if mouth then
	R.Teleport(alice, mouth.CavePad.Position + Vector3.new(0, 3, 0))
	task.wait(0.3)
	R.Event(mouth.CavePad:FindFirstChild("EnterCave"), "Triggered"):Fire(alice)
	task.wait(4)
	ok(alice:GetAttribute("PFECave") ~= nil, "in a cave")
	print(("     Alice: planet %s busy %s expedition %s"):format(tostring(profile.Planet), tostring(profile.Busy), tostring(profile.Expedition ~= nil)))
	local cavesRoot = workspace:FindFirstChild("PFE_Caves")
	local caves = cavesRoot and cavesRoot:FindFirstChild("Frostia_Caves") or Instance.new("Folder")
	local n = 0
	for _, c in ipairs(caves:GetChildren()) do
		if c.Name:match("^Chamber") and n < 8 then
			n += 1
			R.Teleport(alice, c.Floor.Position + Vector3.new(0, 4, 0))
			task.wait(1)
		end
	end
	local way
	for _, d in ipairs(caves:GetChildren()) do if d.Name == "WayOut" then way = d end end
	if way then R.Event(way:FindFirstChild("ClimbOut"), "Triggered"):Fire(alice) end
	task.wait(2)
end

section("events")
local Events = R.Require(server:FindFirstChild("Events"))
wander()
for _, id in ipairs({"TreasureComet", "CoinRain", "EggTornado"}) do
	Events.Start(id)
	task.wait(5)
end
ok(true, "the three events shown")

section("home")
-- the "Fly home" prompt on the landing pad
local landing = workspace.PlanetForEggs.Planets.Frostia:FindFirstChild("Landing")
R.Teleport(alice, landing.Position + Vector3.new(0, 3, 0))
task.wait(0.5)
local flyHome = landing:FindFirstChild("FlyHome", true)
if flyHome then R.Event(flyHome, "Triggered"):Fire(alice) end
task.wait(14)
print("     back: " .. tostring(profile.Planet))
task.wait(3)

section("errors caught by pcall (Studio pauses on these)")
for _, c in ipairs(R.CaughtSummary()) do print(("  %4dx  %s"):format(c.N, c.Key)) end

section("summary")
local real = {}
for _, w in ipairs(R.Warnings) do
	if not w:find("kicked") then table.insert(real, w) end
end
print(("errors: %d   warnings: %d   frames: %d"):format(#R.Errors, #real, frames))
local shown = {}
for i = 1, #R.Errors do
	local key = string.sub(tostring(R.Errors[i]), 1, 160)
	if not shown[key] then shown[key] = true; print("  error: " .. tostring(R.Errors[i]):sub(1, 700)) end
end
local shownW = {}
for i = 1, #real do
	local key = string.sub(real[i], 1, 120)
	if not shownW[key] then shownW[key] = true; print("  warn: " .. real[i]:sub(1, 400)) end
end
process.exit((#R.Errors > 0 or #real > 0) and 1 or 0)
