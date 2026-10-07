-- A small Roblox-like runtime on top of Lune for running the game's scripts outside Studio (tests only).
-- Real Roblox datatypes and instances (with Lune's property checks: a wrong property name is an error), plus fakes
-- for what Lune lacks: events, a few engine methods (PivotTo, Raycast...), characters, players, remotes.
-- Errors in scripts / spawned threads and every warn() are collected in Runtime.Errors / Runtime.Warnings.
-- Needs a Lune (0.10.x) whose lune-roblox lets roblox.implementProperty override real properties (Part.Position...):
-- in lune-roblox's src/instance/base.rs, instance_property_get / _set check InstanceRegistry::find_property_getter /
-- find_property_setter before the reflection database (stock Lune only falls back to them for unknown names).
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local task = require("@lune/task")
local fs = require("@lune/fs")

local Runtime = {Errors = {}, Warnings = {}, Effects = {}, Notices = {}, Log = {}}
local Instance = roblox.Instance
local Vector3, Vector2, CFrame, Color3, UDim, UDim2, BrickColor = roblox.Vector3, roblox.Vector2, roblox.CFrame, roblox.Color3, roblox.UDim, roblox.UDim2, roblox.BrickColor
local NumberSequence, NumberSequenceKeypoint, ColorSequence, ColorSequenceKeypoint = roblox.NumberSequence, roblox.NumberSequenceKeypoint, roblox.ColorSequence, roblox.ColorSequenceKeypoint
local NumberRange, Rect, Ray, Region3, Faces, Axes = roblox.NumberRange, roblox.Rect, roblox.Ray, roblox.Region3, roblox.Faces, roblox.Axes
local PhysicalProperties, Font, Enum = roblox.PhysicalProperties, roblox.Font, roblox.Enum

local function record(list, text)
	table.insert(list, text)
	if #list <= 60 then print((list == Runtime.Errors and "ERROR " or "WARN  ") .. text) end
end
local function traceback(err) return tostring(err) .. "\n" .. debug.traceback("", 2) end
local function safe(fn, ...)
	local ok, err = xpcall(fn, traceback, ...)
	if not ok then record(Runtime.Errors, err) end
end
Runtime.Safe = safe

-- ---------------------------------------------------------------- tasks (errors are caught and recorded)
local simTask = {}
function simTask.spawn(fn, ...)
	if type(fn) == "thread" then return task.spawn(fn, ...) end
	return task.spawn(safe, fn, ...)
end
function simTask.defer(fn, ...)
	if type(fn) == "thread" then return task.defer(fn, ...) end
	return task.defer(safe, fn, ...)
end
function simTask.delay(t, fn, ...)
	if type(fn) == "thread" then return task.delay(t, fn, ...) end
	return task.delay(t or 0, safe, fn, ...)
end
function simTask.wait(t) return task.wait(t) end
function simTask.cancel(t) return task.cancel(t) end
Runtime.task = simTask

-- ---------------------------------------------------------------- signals
local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({Handlers = {}}, Signal) end
function Signal:Connect(fn)
	local handler = {Fn = fn, Connected = true}
	table.insert(self.Handlers, handler)
	local connection = {Connected = true}
	function connection:Disconnect() handler.Connected = false; connection.Connected = false end
	return connection
end
function Signal:Once(fn)
	local c
	c = self:Connect(function(...) c:Disconnect(); fn(...) end)
	return c
end
function Signal:Fire(...)
	for _, h in ipairs(table.clone(self.Handlers)) do
		if h.Connected then simTask.spawn(h.Fn, ...) end
	end
end
function Signal:Wait()
	local co = coroutine.running()
	local c
	c = self:Connect(function(...) c:Disconnect(); task.spawn(co, ...) end)
	return coroutine.yield()
end
Runtime.Signal = Signal

local events = {}      -- instance -> {name -> signal}
local function eventOf(inst, name)
	local t = events[inst]
	if not t then t = {}; events[inst] = t end
	local s = t[name]
	if not s then s = Signal.new(); t[name] = s end
	return s
end
Runtime.Event = eventOf
local EVENTS = {
	Instance = {"AncestryChanged", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "Destroying", "Changed", "AttributeChanged"},
	ProximityPrompt = {"Triggered", "PromptShown", "PromptHidden", "TriggerEnded", "PromptButtonHoldBegan"},
	RemoteEvent = {"OnServerEvent", "OnClientEvent"},
	BindableEvent = {"Event"},
	Players = {"PlayerAdded", "PlayerRemoving"},
	Player = {"CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded", "Chatted", "Idled"},
	Humanoid = {"Died", "Running", "HealthChanged", "StateChanged", "Touched", "Jumping", "MoveToFinished"},
	BasePart = {"Touched", "TouchEnded"},
	Tool = {"Activated", "Deactivated", "Equipped", "Unequipped"},
	Sound = {"Ended", "Loaded"},
	MarketplaceService = {"PromptGamePassPurchaseFinished", "PromptProductPurchaseFinished", "PromptPurchaseFinished", "PromptBundlePurchaseFinished",
		"PromptPremiumPurchaseFinished", "PromptSubscriptionPurchaseFinished"},
	TextChatService = {"MessageReceived", "SendingMessage"},
	ProximityPromptService = {"PromptTriggered", "PromptShown", "PromptHidden"},
	UserInputService = {"InputBegan", "InputEnded", "InputChanged", "TouchStarted", "TouchEnded", "TouchMoved", "TouchTap", "LastInputTypeChanged", "JumpRequest", "TextBoxFocused", "TextBoxFocusReleased"},
	GuiObject = {"MouseEnter", "MouseLeave", "InputBegan", "InputEnded", "InputChanged", "SelectionGained", "SelectionLost"},
	GuiButton = {"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click"},
	TextBox = {"FocusLost", "Focused", "ReturnPressedFromOnScreenKeyboard"},
	Camera = {"Changed"},
	Lighting = {"LightingChanged"},
	GuiService = {"MenuOpened", "MenuClosed"},
}
for class, list in pairs(EVENTS) do
	for _, name in ipairs(list) do
		pcall(roblox.implementProperty, class, name, function(self) return eventOf(self, name) end)
	end
end
-- (events on the concrete part classes: property lookups are by exact class)
local PARTS = {"Part", "WedgePart", "MeshPart", "SpawnLocation", "UnionOperation", "CornerWedgePart", "TrussPart", "Seat", "VehicleSeat"}
for _, class in ipairs(PARTS) do
	for _, name in ipairs({"Touched", "TouchEnded"}) do pcall(roblox.implementProperty, class, name, function(self) return eventOf(self, name) end) end
end

-- ---------------------------------------------------------------- properties Lune has no default for
local store = {}
local function field(inst, key, default)
	local t = store[inst]
	if t and t[key] ~= nil then return t[key] end
	return default
end
local function setField(inst, key, value)
	local t = store[inst]
	if not t then t = {}; store[inst] = t end
	t[key] = value
end
for _, class in ipairs(PARTS) do
	pcall(roblox.implementProperty, class, "Position", function(self) return self.CFrame.Position end,
		function(self, v) self.CFrame = CFrame.new(v) * (self.CFrame - self.CFrame.Position) end)
	pcall(roblox.implementProperty, class, "Orientation", function(self) return Vector3.zero end, function() end)
	pcall(roblox.implementProperty, class, "AssemblyLinearVelocity", function(self) return field(self, "Vel", Vector3.zero) end, function(self, v) setField(self, "Vel", v) end)
	pcall(roblox.implementProperty, class, "AssemblyAngularVelocity", function(self) return Vector3.zero end, function() end)
	pcall(roblox.implementProperty, class, "AssemblyMass", function(self) return self.Size.X * self.Size.Y * self.Size.Z * 0.7 end)
end
pcall(roblox.implementProperty, "Humanoid", "Health", function(self) return field(self, "Health", 100) end, function(self, v)
	local old = field(self, "Health", 100)
	v = math.clamp(v, 0, self.MaxHealth)
	setField(self, "Health", v)
	if v ~= old then eventOf(self, "HealthChanged"):Fire(v) end
	if v <= 0 and old > 0 then eventOf(self, "Died"):Fire() end
end)
pcall(roblox.implementProperty, "Humanoid", "PlatformStand", function(self) return field(self, "PS", false) end, function(self, v) setField(self, "PS", v) end)
pcall(roblox.implementProperty, "RemoteFunction", "OnServerInvoke", function(self) return field(self, "Invoke", nil) end, function(self, v) setField(self, "Invoke", v) end)
pcall(roblox.implementProperty, "MarketplaceService", "ProcessReceipt", function(self) return field(self, "Receipt", nil) end, function(self, v) setField(self, "Receipt", v) end)
for name, value in pairs({JobId = "", PlaceId = 0, GameId = 0, PrivateServerId = "", CreatorId = 0, PlaceVersion = 1}) do
	pcall(roblox.implementProperty, "DataModel", name, function() return value end)
end
pcall(roblox.implementProperty, "Workspace", "Gravity", function(self) return field(self, "Gravity", 196.2) end, function(self, v) setField(self, "Gravity", v) end)

-- ---------------------------------------------------------------- methods
local function impl(class, name, fn) roblox.implementMethod(class, name, fn) end
-- destroying = unparenting (Lune really frees an instance; Roblox keeps it readable). Sources are rewritten to call it.
impl("Instance", "SimDestroy", function(self)
	if self.Parent ~= nil then self.Parent = nil end
	setField(self, "Destroyed", true)
	local e = events[self]
	if e and e.Destroying then e.Destroying:Fire() end
end)
impl("Instance", "SimClearAllChildren", function(self) for _, c in self:GetChildren() do c:SimDestroy() end end)
impl("Instance", "WaitForChild", function(self, name, timeout)
	local found = self:FindFirstChild(name)
	if found then return found end
	local deadline = os.clock() + (timeout or 3)
	while os.clock() < deadline do
		task.wait(0.05)
		found = self:FindFirstChild(name)
		if found then return found end
	end
	if not timeout then record(Runtime.Errors, "WaitForChild(" .. tostring(name) .. ") on " .. self:GetFullName() .. " would wait forever") end
	return nil
end)
impl("Instance", "GetPropertyChangedSignal", function(self, prop) return eventOf(self, "Prop:" .. prop) end)
impl("Instance", "GetAttributeChangedSignal", function(self, attr) return eventOf(self, "Attr:" .. attr) end)
impl("Instance", "IsPropertyModified", function() return false end)
-- pivots: a part's is its CFrame; a model's is its PrimaryPart's (or its first part's)
local function firstPart(model)
	if model:IsA("BasePart") then return model end
	local ok, primary = pcall(function() return model.PrimaryPart end)
	if ok and primary then return primary end
	for _, d in model:GetDescendants() do if d:IsA("BasePart") then return d end end
	return nil
end
impl("PVInstance", "GetPivot", function(self)
	if self:IsA("BasePart") then return self.CFrame end
	local p = firstPart(self)
	return field(self, "Pivot", p and p.CFrame or CFrame.identity)
end)
impl("PVInstance", "PivotTo", function(self, cf)
	if self:IsA("BasePart") then self.CFrame = cf; return end
	local current = self:GetPivot()
	local delta = cf * current:Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then d.CFrame = delta * d.CFrame end
	end
	setField(self, "Pivot", cf)
end)
local function bounds(self)
	local lo, hi
	for _, d in (self:IsA("BasePart") and {self} or self:GetDescendants()) do
		if d:IsA("BasePart") then
			local c, s = d.CFrame, d.Size * 0.5
			for _, k in {Vector3.new(1, 1, 1), Vector3.new(-1, -1, -1), Vector3.new(1, -1, 1), Vector3.new(-1, 1, -1)} do
				local p = c:PointToWorldSpace(s * k)
				lo = lo and lo:Min(p) or p; hi = hi and hi:Max(p) or p
			end
		end
	end
	if not lo then return CFrame.identity, Vector3.zero end
	return CFrame.new((lo + hi) / 2), hi - lo
end
impl("Model", "GetBoundingBox", function(self) return bounds(self) end)
impl("Model", "GetExtentsSize", function(self) local _, s = bounds(self); return s end)
impl("Model", "GetScale", function(self) return field(self, "Scale", 1) end)
impl("Model", "ScaleTo", function(self, s)
	local k = s / field(self, "Scale", 1)
	local pivot = self:GetPivot()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = pivot:ToObjectSpace(d.CFrame)
			d.Size *= k
			d.CFrame = pivot * (CFrame.new(rel.Position * k) * (rel - rel.Position))
		end
	end
	setField(self, "Scale", s)
end)
impl("BasePart", "SetNetworkOwner", function() end)
impl("BasePart", "ApplyImpulse", function() end)
impl("BasePart", "GetMass", function(self) return self.Size.X * self.Size.Y * self.Size.Z * 0.7 end)
impl("Workspace", "GetServerTimeNow", function() return os.clock() + 1.7e9 end)
-- (a scenario may give the world a ground: Runtime.Raycast(origin, direction, params))
impl("Workspace", "Raycast", function(_, ...) if Runtime.Raycast then return Runtime.Raycast(...) end; return nil end)
impl("Workspace", "BulkMoveTo", function(_, parts, cframes) for i, p in ipairs(parts) do p.CFrame = cframes[i] end end)
impl("Workspace", "GetPartBoundsInRadius", function() return {} end)
impl("Humanoid", "TakeDamage", function(self, amount)
	local character = self.Parent
	if character and character:FindFirstChildOfClass("ForceField") then return end
	self.Health = self.Health - amount
end)
impl("Humanoid", "MoveTo", function(self, position) setField(self, "MoveTo", position) end)
impl("Humanoid", "ChangeState", function() end)
impl("Humanoid", "GetState", function() return Enum.HumanoidStateType.Running end)
impl("Humanoid", "UnequipTools", function(self)
	local character = self.Parent
	local player = character and Runtime.PlayerOf and Runtime.PlayerOf(character)
	local backpack = player and player:FindFirstChildOfClass("Backpack")
	for _, t in character:GetChildren() do if t:IsA("Tool") and backpack then t.Parent = backpack end end
end)
impl("Humanoid", "EquipTool", function(self, tool) self:UnequipTools(); tool.Parent = self.Parent end)
impl("Humanoid", "LoadAnimation", function() return Runtime.FakeTrack() end)
impl("Animator", "LoadAnimation", function() return Runtime.FakeTrack() end)
impl("Humanoid", "ApplyDescription", function() end)
impl("Sound", "Play", function() end)
impl("Sound", "Stop", function() end)
impl("ParticleEmitter", "Emit", function() end)
impl("Player", "Kick", function(self, reason) record(Runtime.Warnings, "kicked " .. self.Name .. ": " .. tostring(reason)) end)
impl("Player", "LoadCharacterAsync", function(self) Runtime.SpawnCharacter(self) end)
impl("Player", "LoadCharacter", function(self) Runtime.SpawnCharacter(self) end)
impl("Player", "RequestStreamAroundAsync", function() end)
impl("Player", "GetMouse", function() return {} end)
impl("RemoteEvent", "FireClient", function(self, player, ...)
	table.insert(Runtime.Effects, {Remote = self.Name, Player = player, Args = table.pack(...)})
	if Runtime.OnFireClient then Runtime.OnFireClient(self, player, ...) end
end)
impl("RemoteEvent", "FireAllClients", function(self, ...) table.insert(Runtime.Effects, {Remote = self.Name, Args = table.pack(...)}) end)
impl("BindableEvent", "Fire", function(self, ...) eventOf(self, "Event"):Fire(...) end)
impl("CollectionService", "SimCSAddTag", function(_, inst, tag) inst:AddTag(tag) end)
impl("CollectionService", "SimCSRemoveTag", function(_, inst, tag) inst:RemoveTag(tag) end)
impl("CollectionService", "SimCSHasTag", function(_, inst, tag) return inst:HasTag(tag) end)
impl("CollectionService", "GetTagged", function(_, tag)
	local list = {}
	for _, d in Runtime.game:GetDescendants() do if d:HasTag(tag) then table.insert(list, d) end end
	return list
end)
impl("CollectionService", "GetInstanceAddedSignal", function(self, tag) return eventOf(self, "Tag+" .. tag) end)
impl("CollectionService", "GetInstanceRemovedSignal", function(self, tag) return eventOf(self, "Tag-" .. tag) end)
impl("Players", "GetPlayers", function(self) local l = {}; for _, p in self:GetChildren() do if p:IsA("Player") then table.insert(l, p) end end; return l end)
impl("Players", "GetPlayerByUserId", function(self, id) for _, p in self:GetChildren() do if p:IsA("Player") and p.UserId == id then return p end end; return nil end)
impl("Players", "GetPlayerFromCharacter", function(self, character) for _, p in self:GetChildren() do if p:IsA("Player") and p.Character == character then return p end end; return nil end)
impl("Players", "GetUserThumbnailAsync", function() return "rbxassetid://0" end)
impl("RunService", "IsStudio", function() return true end)
impl("RunService", "IsServer", function() return Runtime.Side == "server" end)
impl("RunService", "IsClient", function() return Runtime.Side == "client" end)
impl("RunService", "BindToRenderStep", function() end)
impl("RunService", "UnbindFromRenderStep", function() end)
impl("Debris", "AddItem", function(_, inst, t) simTask.delay(t or 10, function() inst:SimDestroy() end) end)
impl("MarketplaceService", "UserOwnsGamePassAsync", function() return false end)
impl("MarketplaceService", "PromptProductPurchase", function() end)
impl("MarketplaceService", "GetProductInfo", function() return {PriceInRobux = 10} end)
impl("HttpService", "GenerateGUID", function() return string.format("%08x-%04x", math.random(0, 0x7fffffff), math.random(0, 0xffff)) end)
impl("HttpService", "JSONEncode", function() return "{}" end)
impl("TextService", "GetTextSize", function(_, text, size) return Vector2.new(#text * size * 0.6, size) end)
impl("BadgeService", "UserHasBadgeAsync", function() return false end)
impl("DataStoreService", "GetDataStore", function() error("no datastores in the simulator") end)
impl("TweenService", "Create", function() return {Play = function() end, Cancel = function() end, Completed = Signal.new()} end)
impl("ContentProvider", "PreloadAsync", function() end)
impl("SoundService", "PlayLocalSound", function() end)
impl("Instance", "GetActor", function() return nil end)
impl("PhysicsService", "IsCollisionGroupRegistered", function() return false end)
impl("PhysicsService", "RegisterCollisionGroup", function() end)
impl("PhysicsService", "CollisionGroupSetCollidable", function() end)
impl("PhysicsService", "GetRegisteredCollisionGroups", function() return {} end)
impl("MessagingService", "SubscribeAsync", function() return {Disconnect = function() end} end)
impl("MessagingService", "PublishAsync", function() end)
impl("HttpService", "JSONDecode", function() return {} end)
impl("Players", "GetUserIdFromNameAsync", function() return 1 end)
impl("Players", "GetHumanoidDescriptionFromUserId", function() return Instance.new("HumanoidDescription") end)
impl("Players", "CreateHumanoidModelFromDescription", function()
	if Runtime.MakeAvatar then return Runtime.MakeAvatar() end
	error("no avatars in the simulator")
end)
impl("Players", "CreateHumanoidModelFromUserId", function() error("no avatars in the simulator") end)
impl("TeleportService", "TeleportAsync", function() end)
impl("BasePart", "GetTouchingParts", function() return {} end)
impl("BasePart", "CanSetNetworkOwnership", function() return true end)
impl("BasePart", "GetNetworkOwner", function() return nil end)

function Runtime.FakeTrack()
	return {Play = function() end, Stop = function() end, AdjustSpeed = function() end, AdjustWeight = function() end, IsPlaying = false, Looped = false,
		Priority = Enum.AnimationPriority.Core, Length = 1, TimePosition = 0, Stopped = Signal.new(), KeyframeReached = Signal.new(),
		GetMarkerReachedSignal = function() return Signal.new() end}
end

-- ---------------------------------------------------------------- non-instance types Lune lacks
local RandomClass = {}
RandomClass.__index = RandomClass
function RandomClass.new(seed)
	local s = (seed and math.floor(seed) or os.clock() * 1e6) % 2147483647
	if s <= 0 then s = 12345 end
	return setmetatable({S = s}, RandomClass)
end
function RandomClass:_next() self.S = (self.S * 48271) % 2147483647; return self.S / 2147483647 end
function RandomClass:NextNumber(a, b) local r = self:_next(); if a then return a + (b - a) * r end; return r end
function RandomClass:NextInteger(a, b) return a + math.floor(self:_next() * (b - a + 1)) end
function RandomClass:NextUnitVector() local v = Vector3.new(self:NextNumber(-1, 1), self:NextNumber(-1, 1), self:NextNumber(-1, 1)); return v.Magnitude > 0 and v.Unit or Vector3.xAxis end
function RandomClass:Shuffle(t) for i = #t, 2, -1 do local j = self:NextInteger(1, i); t[i], t[j] = t[j], t[i] end end
function RandomClass:Clone() return setmetatable({S = self.S}, RandomClass) end
local function params() return {FilterType = Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {}, RespectCanCollide = false, AddToFilter = function() end} end
local TweenInfoClass = {new = function(t, style, dir, repeats, reverses, delay) return {Time = t or 1, EasingStyle = style, EasingDirection = dir, DelayTime = delay or 0} end}
local DateTimeClass = {now = function() return {UnixTimestamp = os.time(), UnixTimestampMillis = os.time() * 1000, FormatUniversalTime = function() return "" end, ToUniversalTime = function() return {Year = 2026, Month = 1, Day = 1} end} end,
	fromUnixTimestamp = function(t) return {UnixTimestamp = t, ToUniversalTime = function() return {Year = 2026, Month = 1, Day = 1} end, FormatUniversalTime = function() return "" end} end}

-- ---------------------------------------------------------------- the place and the script loader
function Runtime.Load(placePath, side)
	Runtime.Side = side or "server"
	local game = roblox.deserializePlace(fs.readFile(placePath))
	Runtime.game = game
	Runtime.workspace = game:GetService("Workspace")
	for _, name in {"Players", "ReplicatedStorage", "ServerStorage", "ServerScriptService", "Lighting", "SoundService", "StarterGui", "StarterPlayer",
		"CollectionService", "RunService", "Debris", "TweenService", "MarketplaceService", "HttpService", "TextService", "DataStoreService",
		"UserInputService", "ContextActionService", "GuiService", "ProximityPromptService", "TextChatService", "ContentProvider", "BadgeService",
		"PhysicsService", "TeleportService", "LocalizationService", "SocialService", "AssetService", "Chat", "StarterPack", "ReplicatedFirst"} do
		pcall(function() game:GetService(name) end)
	end
	-- run loop signals the scripts use (fired by the scenario)
	local run = game:GetService("RunService")
	pcall(roblox.implementProperty, "RunService", "Heartbeat", function() return eventOf(run, "Heartbeat") end)
	pcall(roblox.implementProperty, "RunService", "RenderStepped", function() return eventOf(run, "RenderStepped") end)
	pcall(roblox.implementProperty, "RunService", "Stepped", function() return eventOf(run, "Stepped") end)
	pcall(roblox.implementProperty, "RunService", "PreSimulation", function() return eventOf(run, "Heartbeat") end)
	return game
end

-- the `game` the scripts see: the real DataModel, plus the properties Lune can't read off it (JobId...)
local gameProxy
local function gameFor()
	if gameProxy then return gameProxy end
	local real = Runtime.game
	local extra = {JobId = "", PlaceId = 0, GameId = 0, PrivateServerId = "", CreatorId = 0, PlaceVersion = 1, BindToClose = function() end}
	gameProxy = setmetatable({}, {
		__index = function(_, key)
			if extra[key] ~= nil then return extra[key] end
			local value = real[key]
			if type(value) == "function" then return function(self, ...) return value(self == gameProxy and real or self, ...) end end
			return value
		end,
		__tostring = function() return "Game" end,
	})
	return gameProxy
end

local modules = {}
local loadScript
local function makeEnv(scriptInstance)
	local env = {
		game = gameFor(), workspace = Runtime.workspace, Workspace = Runtime.workspace, script = scriptInstance, task = simTask,
		Instance = {new = function(class, parent) local i = Instance.new(class); if parent then i.Parent = parent end; return i end},
		Vector3 = Vector3, Vector2 = Vector2, CFrame = CFrame, Color3 = Color3, UDim = UDim, UDim2 = UDim2, BrickColor = BrickColor,
		NumberSequence = NumberSequence, NumberSequenceKeypoint = NumberSequenceKeypoint, ColorSequence = ColorSequence,
		ColorSequenceKeypoint = ColorSequenceKeypoint, NumberRange = NumberRange, Rect = Rect, Ray = Ray, Region3 = Region3, Faces = Faces, Axes = Axes,
		PhysicalProperties = PhysicalProperties, Font = Font, Enum = Enum, Random = RandomClass, TweenInfo = TweenInfoClass, DateTime = DateTimeClass,
		RaycastParams = {new = params}, OverlapParams = {new = params},
		typeof = typeof, type = type, print = function(...) table.insert(Runtime.Log, table.concat(table.pack(...), " ")) end,
		warn = function(...) local parts = {}; for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end; record(Runtime.Warnings, table.concat(parts, " ")) end,
		error = error, assert = assert, pcall = pcall, xpcall = xpcall, select = select, tostring = tostring, tonumber = tonumber,
		ipairs = ipairs, pairs = pairs, next = next, setmetatable = setmetatable, getmetatable = getmetatable, rawget = rawget, rawset = rawset,
		rawequal = rawequal, rawlen = rawlen, unpack = table.unpack, math = math, string = string, table = table, coroutine = coroutine, os = os,
		utf8 = utf8, bit32 = bit32, buffer = buffer, debug = debug, tick = os.clock, time = os.clock, wait = task.wait, delay = simTask.delay,
		spawn = simTask.spawn, newproxy = newproxy, UserSettings = function() return {GetService = function() return {SavedQualityLevel = {Value = 5}} end} end,
		settings = function() return {} end, shared = {},
	}
	env.require = function(target)
		if typeof(target) == "Instance" then return loadScript(target) end
		error("require of a non-instance in the simulator: " .. tostring(target))
	end
	env._G = env
	return env
end
local function prepare(source)
	-- Lune frees destroyed instances; Roblox keeps them readable: Destroy / ClearAllChildren become the simulator's own
	source = string.gsub(source, ":Destroy%(", ":SimDestroy(")
	-- (Lune's own Instance:AddTag etc. shadow the CollectionService methods of the same name)
	for _, m in {"AddTag", "RemoveTag", "HasTag"} do source = string.gsub(source, "CollectionService:" .. m .. "%(", "CollectionService:SimCS" .. m .. "(") end
	source = string.gsub(source, ":ClearAllChildren%(", ":SimClearAllChildren(")
	return source
end
loadScript = function(inst)
	if modules[inst] ~= nil then
		if modules[inst] == false then error("require loop on " .. inst:GetFullName()) end
		return modules[inst].Value
	end
	modules[inst] = false
	local fn = luau.load(prepare(inst.Source), {debugName = inst:GetFullName(), environment = makeEnv(inst)})
	local results = table.pack(fn())
	modules[inst] = {Value = results[1]}
	return results[1]
end
Runtime.Require = loadScript
-- run a Script / LocalScript in its own thread
function Runtime.Run(inst)
	local fn = luau.load(prepare(inst.Source), {debugName = inst:GetFullName(), environment = makeEnv(inst)})
	simTask.spawn(fn)
end

-- ---------------------------------------------------------------- players and characters
local playerOf = {}
function Runtime.PlayerOf(character) return playerOf[character] end
local nextUserId = 1000
function Runtime.AddPlayer(name)
	local players = Runtime.game:GetService("Players")
	local player = Instance.new("Player")
	player.Name = name
	nextUserId += 1
	player.UserId = nextUserId
	player.DisplayName = name
	local backpack = Instance.new("Backpack"); backpack.Parent = player
	local gui = Instance.new("PlayerGui"); gui.Parent = player
	local scripts = Instance.new("PlayerScripts"); scripts.Parent = player
	player.Parent = players
	eventOf(players, "PlayerAdded"):Fire(player)
	return player
end
function Runtime.RemovePlayer(player)
	local players = Runtime.game:GetService("Players")
	eventOf(players, "PlayerRemoving"):Fire(player)
	task.wait(0.1)
	player.Parent = nil
end
function Runtime.SpawnCharacter(player)
	local old = player.Character
	if old then old:SimDestroy() end
	local character = Instance.new("Model")
	character.Name = player.Name
	local function limb(name, size, offset)
		local p = Instance.new("Part")
		p.Name = name; p.Size = size; p.CFrame = CFrame.new(offset); p.Anchored = false; p.Parent = character
		return p
	end
	local root = limb("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
	limb("UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 3.4, 0))
	limb("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.8, 0))
	limb("RightHand", Vector3.new(0.6, 0.6, 0.6), Vector3.new(1.5, 2, 0))
	character.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Parent = character
	local animator = Instance.new("Animator"); animator.Parent = humanoid
	playerOf[character] = player
	character.Parent = Runtime.workspace
	player.Character = character
	eventOf(player, "CharacterAdded"):Fire(character)
	return character
end
-- put a player's character somewhere
function Runtime.Teleport(player, position)
	local character = player.Character
	if character then character:PivotTo(CFrame.new(position)) end
end

-- the effects sent to a player (kind = first argument of the Effect remote)
function Runtime.EffectsOf(player, kind)
	local list = {}
	for _, e in ipairs(Runtime.Effects) do
		if e.Player == player and e.Remote == "Effect" and (not kind or e.Args[1] == kind) then table.insert(list, e.Args[2]) end
	end
	return list
end

return Runtime
