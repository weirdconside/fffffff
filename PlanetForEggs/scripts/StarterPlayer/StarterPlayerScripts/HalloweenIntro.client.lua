--!nocheck
-- (v37) The Halloween join cutscene: once per account (every time in Studio, Config.HalloweenIntro.StudioAlways).
-- Authored in tools/intro_anim.py (the timing, the camera, your avatar's acting, the Pumpkin King's climb) and played
-- here from ReplicatedStorage.PFE.IntroAnim:
--  * a calm sunny afternoon on the island as it was before Halloween: your own avatar strolls past its base, stretches;
--  * a storm rolls in; from under the island's edge a black cloud of hundreds of crows rises and dives straight at you,
--    knocking you off your feet;
--  * behind them a wall of darkness sweeps across the island and swallows it: thorny vines crawl over the grass, the
--    world turns Halloween, pumpkins and graves rise out of the ground; the island's Halloween music starts;
--  * the ground shakes: over the edge rise a top hat... two burning eyes... giant claws slam onto the rim, and the
--    Pumpkin King hauls itself up onto the island, summons its scythe and laughs; it bends down over you - black.
-- Presentation only: a local copy of your avatar acts; the real character waits anchored out of sight at the spawn
-- (the server keeps the bots away meanwhile: action "Cutscene"; "IntroDone" remembers it was seen). Nothing else on
-- screen meanwhile: no interface, no Roblox bar, no name tags, no other players or bots.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local api = ReplicatedStorage:WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local INTRO = Config.HalloweenIntro
local S = Config.Sounds
if not INTRO or INTRO.Enabled == false or workspace:GetAttribute("PFENoIntro") == true then return end
local SPEED = workspace:GetAttribute("PFEIntroSpeed") or INTRO.Speed or 1   -- (the offline test runs it faster)

-- ---------------------------------------------------------------- should it play?
local function isStudio()
	local ok, v = pcall(function() return RunService:IsStudio() end)
	return ok and v == true
end
local deadline = os.clock() + 25
while player:GetAttribute("PFEIntroSeen") == nil and os.clock() < deadline do task.wait(0.2) end
local seen = player:GetAttribute("PFEIntroSeen")
local forced = isStudio() and INTRO.StudioAlways == true
if not forced and (type(seen) ~= "number" or seen >= INTRO.Version) then return end
local animModule = api:WaitForChild("IntroAnim", 10)
if not animModule then return end
local ANIM = require(animModule)
local EV = ANIM.Events
player:SetAttribute("PFECutscene", true)   -- the music holds its breath from now on (Music.client)

local world = workspace:WaitForChild("PlanetForEggs")
local island = world:WaitForChild("OriginalIsland")
local bases = world:WaitForChild("Bases")
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart", 20)
local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 20)
local base
for _ = 1, 100 do
	for _, b in ipairs(bases:GetChildren()) do
		if b:GetAttribute("OwnerUserId") == player.UserId then base = b end
	end
	if base then break end
	task.wait(0.2)
end
if not (root and humanoid and base) then player:SetAttribute("PFECutscene", false); return end
-- the title screen first (its music and its wipe)
while player:GetAttribute("IntroActive") == true do task.wait(0.03) end

-- ---------------------------------------------------------------- our screen: black, flashes, the boss's card, skip
local playerGui = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "PFE_IntroCutscene"; gui.DisplayOrder = 1000; gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false
local function frame(name, color, z, transparency)
	local f = Instance.new("Frame")
	f.Name = name; f.BorderSizePixel = 0; f.BackgroundColor3 = color; f.ZIndex = z; f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = transparency or 0; f.Parent = gui
	return f
end
local black = frame("Black", Color3.new(0, 0, 0), 20, 0)
local white = frame("Flash", Color3.new(1, 1, 1), 15, 1)
local engulf = frame("Engulf", Color3.fromRGB(26, 6, 34), 14, 1)
-- crows brushing past the lens: dark wing shapes sweeping across the screen
local flutter = {}
for k = 1, 6 do
	local w = Instance.new("Frame")
	w.Name = "Wing"; w.BorderSizePixel = 0; w.BackgroundColor3 = Color3.fromRGB(8, 8, 12); w.AnchorPoint = Vector2.new(0.5, 0.5)
	w.Size = UDim2.fromScale(0.7, 0.32); w.Visible = false; w.ZIndex = 13; w.Parent = gui
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = w
	flutter[k] = w
end
local skip = Instance.new("TextButton")
skip.Name = "Skip"; skip.AnchorPoint = Vector2.new(1, 1); skip.Position = UDim2.new(1, -18, 1, -14); skip.Size = UDim2.fromOffset(110, 34)
skip.BackgroundColor3 = Color3.new(0, 0, 0); skip.BackgroundTransparency = 0.55; skip.Text = "SKIP  >>"; skip.TextScaled = true
skip.TextColor3 = Color3.fromRGB(235, 225, 245); skip.TextTransparency = 1; skip.ZIndex = 21; skip.Parent = gui
pcall(function() skip.FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy) end)
do
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = skip
	local p = Instance.new("UIPadding"); p.PaddingTop = UDim.new(0, 6); p.PaddingBottom = UDim.new(0, 6); p.Parent = skip
end
skip.Visible = INTRO.Skippable ~= false
-- the boss's name card (lower left)
local card = Instance.new("Frame")
card.Name = "BossCard"; card.BackgroundTransparency = 1; card.AnchorPoint = Vector2.new(0, 1)
card.Position = UDim2.new(0.05, 0, 0.93, 0); card.Size = UDim2.fromScale(0.62, 0.2); card.ZIndex = 12; card.Visible = false; card.Parent = gui
local cardScale = Instance.new("UIScale"); cardScale.Parent = card
local function label(name, text, y, h, color, size)
	local t = Instance.new("TextLabel")
	t.Name = name; t.BackgroundTransparency = 1; t.Text = text; t.TextScaled = true; t.TextColor3 = color
	t.TextXAlignment = Enum.TextXAlignment.Left; t.Position = UDim2.fromScale(0, y); t.Size = UDim2.fromScale(1, h); t.ZIndex = 13
	t.TextStrokeTransparency = 0; t.TextStrokeColor3 = Color3.fromRGB(30, 8, 0)
	pcall(function() t.FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy) end)
	local limit = Instance.new("UITextSizeConstraint"); limit.MaxTextSize = size; limit.Parent = t
	t.Parent = card
	return t
end
local cardName = label("BossName", "THE PUMPKIN KING", 0, 0.62, Color3.fromRGB(255, 150, 40), 84)
pcall(function() cardName.FontFace = Font.fromEnum(Enum.Font.Creepster) end)
local cardLine = Instance.new("Frame")
cardLine.Name = "Line"; cardLine.BorderSizePixel = 0; cardLine.BackgroundColor3 = Color3.fromRGB(255, 120, 30)
cardLine.Position = UDim2.fromScale(0, 0.66); cardLine.Size = UDim2.fromScale(0, 0.03); cardLine.ZIndex = 13; cardLine.Parent = card
local cardSub = label("Subtitle", "HALLOWEEN HAS BEGUN...", 0.72, 0.26, Color3.fromRGB(215, 190, 255), 30)
gui.Parent = playerGui

local function tween(object, seconds, props, style, direction)
	local tw = TweenService:Create(object, TweenInfo.new(seconds / SPEED, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- ---------------------------------------------------------------- undo list (everything comes back, whatever happens)
local undo = {}
local function onEnd(fn) table.insert(undo, fn) end
local finished = false
local function restoreAll()
	for i = #undo, 1, -1 do
		local ok, err = pcall(undo[i])
		if not ok then warn("[PFE] intro cleanup:", err) end
	end
	table.clear(undo)
end

-- nothing else on screen: our interface, Roblox's (the top bar too), prompts, name tags, other people and bots
-- (anything that switches itself back on meanwhile goes straight off again, and comes back on at the end)
local hiddenGuis, guards = {}, {}
local function keepOff(object)
	if guards[object] then return end
	guards[object] = object:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not finished and object.Enabled then hiddenGuis[object] = true; object.Enabled = false end
	end)
end
local function hideGui(g)
	if g:IsA("ScreenGui") and g ~= gui then
		if g.Enabled then hiddenGuis[g] = true; g.Enabled = false end
		keepOff(g)
	end
end
local function hideGuis() for _, g in ipairs(playerGui:GetChildren()) do hideGui(g) end end
hideGuis()
local guiConn = playerGui.ChildAdded:Connect(function(g) task.defer(hideGui, g) end)
onEnd(function()
	guiConn:Disconnect()
	for _, c in pairs(guards) do c:Disconnect() end
	table.clear(guards)
	for g in pairs(hiddenGuis) do if g.Parent then g.Enabled = true end end
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
	pcall(function() StarterGui:SetCore("TopbarEnabled", true) end)
end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
pcall(function() StarterGui:SetCore("TopbarEnabled", false) end)
pcall(function()
	local promptService = game:GetService("ProximityPromptService")
	local promptsWere = promptService.Enabled
	promptService.Enabled = false
	onEnd(function() promptService.Enabled = promptsWere end)
end)
local hiddenTags = hiddenGuis      -- (the same bookkeeping: name tags, signs, the guide's arrow...)
local function hideTag(d)
	if d:IsA("BillboardGui") then
		if d.Enabled then hiddenTags[d] = true; d.Enabled = false end
		keepOff(d)
	end
end
for _, d in ipairs(workspace:GetDescendants()) do if d:IsA("BillboardGui") then hideTag(d) end end
local tagConn = workspace.DescendantAdded:Connect(function(d) if d:IsA("BillboardGui") then task.defer(hideTag, d) end end)
onEnd(function() tagConn:Disconnect() end)
local ghosted = {}
local function hidePeople()
	local list = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Character then table.insert(list, other.Character) end
	end
	local bots = workspace:FindFirstChild("PFE_Bots")
	if bots then for _, m in ipairs(bots:GetChildren()) do table.insert(list, m) end end
	for _, model in ipairs(list) do
		for _, d in ipairs(model:GetDescendants()) do
			if (d:IsA("BasePart") or d:IsA("Decal")) and d.LocalTransparencyModifier < 1 then
				ghosted[d] = true; d.LocalTransparencyModifier = 1
			end
		end
	end
end
hidePeople()
onEnd(function() for d in pairs(ghosted) do if d.Parent then d.LocalTransparencyModifier = 0 end end end)

api:WaitForChild("Action"):FireServer("Cutscene", true)

-- ---------------------------------------------------------------- the stage: the base's own frame (tools/intro_anim.py)
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local standCF = root.CFrame
local R15 = humanoid.RigType == Enum.HumanoidRigType.R15
local hip = R15 and (humanoid.HipHeight + root.Size.Y / 2) or 3
local groundY = standCF.Position.Y - hip
local spawnPart = base:FindFirstChild("Spawn")
local origin = spawnPart and spawnPart.Position or standCF.Position
local inward = flat(-origin)
inward = inward.Magnitude > 1 and inward.Unit or Vector3.new(-1, 0, 0)
local side = Vector3.new(inward.Z, 0, -inward.X)      -- (every base's treadmill is on the other side: s, u, i stays right-handed)
local ground0 = Vector3.new(origin.X, groundY, origin.Z)
local function L(s, u, i) return ground0 + side * s + Vector3.yAxis * u + inward * i end
local function Lv(v) return ground0 + side * v.X + Vector3.yAxis * v.Y + inward * v.Z end
local function lv(t) return Vector3.new(t[1], t[2], t[3]) end
local function frameAt(pos, facing, pitch, roll)
	local f = side * math.cos(math.rad(facing)) + inward * math.sin(math.rad(facing))
	return CFrame.lookAt(pos, pos + f) * CFrame.Angles(math.rad(pitch or 0), 0, math.rad(roll or 0))
end
local function sample(arr, rate, t, start)
	local x = (t - (start or 0)) * rate
	local n = #arr
	if x <= 0 then return arr[1] end
	if x >= n - 1 then return arr[n] end
	local k = math.floor(x)
	local f = x - k
	return arr[k + 1] + (arr[k + 2] - arr[k + 1]) * f
end
local function span(t, a, b) return math.clamp((t - a) / (b - a), 0, 1) end
local function smooth(u) u = math.clamp(u, 0, 1); return u * u * (3 - 2 * u) end
local EDGE, OUT, TANG = lv(ANIM.Edge), lv(ANIM.Out), lv(ANIM.Tang)
local EDGE_W = Lv(EDGE)

-- ---------------------------------------------------------------- the actor: a local copy of your avatar
local actor, actorRoot, actorHumanoid
do
	local ok, copy = pcall(function()
		local was = character.Archivable
		character.Archivable = true
		local c = character:Clone()
		character.Archivable = was
		return c
	end)
	if ok and copy then
		actor = copy
		actor.Name = "PFE_IntroActor"
		for _, d in ipairs(actor:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("BillboardGui") or d:IsA("Sound")
				or d.Name == "CarriedPlanetEgg" then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.CanCollide = false; d.CanTouch = false; d.CanQuery = false; d.LocalTransparencyModifier = 0
			end
		end
		actorRoot = actor:FindFirstChild("HumanoidRootPart")
		actorHumanoid = actor:FindFirstChildOfClass("Humanoid")
		if actorRoot then actorRoot.Anchored = true end
		if actorHumanoid then
			actorHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			pcall(function() actorHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff end)
			pcall(function() actorHumanoid.EvaluateStateMachine = false end)
			local animator = actorHumanoid:FindFirstChildOfClass("Animator")
			if animator then animator:Destroy() end      -- (every move is ours)
		end
		if not actorRoot then actor:Destroy(); actor = nil end
	end
end
if actor then
	actor.Parent = workspace
	onEnd(function() actor:Destroy() end)
end
-- the real character waits anchored, out of sight under its spawn
local realParts = {}
for _, d in ipairs(character:GetDescendants()) do
	if d:IsA("BasePart") or d:IsA("Decal") then table.insert(realParts, d) end
end
local function hideReal()
	for _, p in ipairs(realParts) do if p.Parent then p.LocalTransparencyModifier = 1 end end
end
local hiddenCF = standCF - Vector3.yAxis * 14
root.Anchored = true
root.CFrame = hiddenCF
hideReal()
pcall(function() RunService:BindToRenderStep("PFEIntroHide", Enum.RenderPriority.Last.Value, hideReal) end)
local displayWas = humanoid.DisplayDistanceType
humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
onEnd(function()
	pcall(function() RunService:UnbindFromRenderStep("PFEIntroHide") end)
	for _, p in ipairs(realParts) do if p.Parent then p.LocalTransparencyModifier = 0 end end
	humanoid.DisplayDistanceType = displayWas
	if root.Parent then
		root.CFrame = standCF
		root.AssemblyLinearVelocity = Vector3.zero
		root.Anchored = false
	end
end)

-- the avatar's joints (Motor6D or AnimationConstraint, by the part they move), each turned in its parent's frame
local JOINTS = {}
if actor then
	for _, d in ipairs(actor:GetDescendants()) do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			local ok, p1 = pcall(function() return d.Part1 end)
			if ok and p1 and (not JOINTS[p1.Name] or d:IsA("AnimationConstraint")) then
				local ok2, c0 = pcall(function() return d.C0 end)
				JOINTS[p1.Name] = {Joint = d, Rot = ok2 and (c0 - c0.Position) or CFrame.identity}
			end
		end
	end
end
local AC = ANIM.Actor
local R6 = {UpperTorso = "Torso", Head = "Head", RightUpperArm = "Right Arm", LeftUpperArm = "Left Arm", RightUpperLeg = "Right Leg", LeftUpperLeg = "Left Leg"}
local actorPos, actorHead = root.Position, root.Position
local function setJoint(name, x, y, z)
	local rec = JOINTS[name]
	if not rec then return end
	local ok = pcall(function()
		rec.Joint.Transform = rec.Rot:Inverse() * CFrame.Angles(math.rad(x), math.rad(y), math.rad(z)) * rec.Rot
	end)
	if not ok then JOINTS[name] = nil end
end
local function playActor(t)
	if not actorRoot then return end
	local rate = AC.Rate
	local r = AC.Root
	local s, u, i = sample(r.s, rate, t), sample(r.u, rate, t), sample(r.i, rate, t)
	local pos = L(s, 0, i) + Vector3.yAxis * (u * hip)
	actorRoot.CFrame = frameAt(pos, sample(r.facing, rate, t), sample(r.pitch, rate, t), sample(r.roll, rate, t))
	actorPos = pos
	local shake = sample(AC.Tremble, rate, t)
	if R15 then
		for _, name in ipairs(AC.Joints) do
			local ch = AC.Pose[name]
			local x, y, z = sample(ch.x, rate, t), sample(ch.y, rate, t), sample(ch.z, rate, t)
			if shake > 0 and (name == "Head" or name == "UpperTorso" or string.find(name, "Arm")) then
				x += math.sin(t * 41 + #name) * shake; z += math.sin(t * 37 + #name * 2) * shake * 0.6
			end
			setJoint(name, x, y, z)
		end
	else
		-- R6: a joint per limb (the forearm's bend folded into the arm), the torso leans at the root joint by half
		for r15, r6 in pairs(R6) do
			local ch = AC.Pose[r15]
			local x, y, z = sample(ch.x, rate, t), sample(ch.y, rate, t), sample(ch.z, rate, t)
			local lower = AC.Pose[(string.gsub(r15, "Upper", "Lower"))]
			if string.find(r15, "Arm") and lower then
				x += sample(lower.x, rate, t) * 0.5; z += sample(lower.z, rate, t) * 0.5
			end
			if r15 == "UpperTorso" then x, y, z = x * 0.5, 0, 0 end
			setJoint(r6, x, y, z)
		end
	end
	local head = actor:FindFirstChild("Head")
	actorHead = head and head.Position or pos
end

-- ---------------------------------------------------------------- the world before Halloween, and the switch back
local halloween = island:FindFirstChild("Halloween")
local recolor = {}
for _, d in ipairs(island:GetDescendants()) do
	if d:IsA("BasePart") then
		local pre = d:GetAttribute("PFEPre")
		if typeof(pre) == "Color3" then
			table.insert(recolor, {Part = d, Pre = pre, Now = d.Color, D = flat(d.Position - EDGE_W).Magnitude})
		end
	end
end
table.sort(recolor, function(a, b) return a.D < b.D end)
local decor = {}
if halloween then
	for _, m in ipairs(halloween:GetChildren()) do
		if m:IsA("Model") and not m:GetAttribute("HalloweenBob") then
			local ok, home = pcall(function() return m:GetPivot() end)
			local ok2, size = pcall(function() return m:GetExtentsSize() end)
			if ok and ok2 then table.insert(decor, {Model = m, Home = home, H = size.Y + 1.5, D = flat(home.Position - EDGE_W).Magnitude}) end
		end
	end
end
table.sort(decor, function(a, b) return a.D < b.D end)
local ghosts, fogs = {}, {}
if halloween then
	for _, m in ipairs(halloween:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("HalloweenBob") then
			local parts = {}
			for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") or d:IsA("Decal") then table.insert(parts, d) end end
			local ok, home = pcall(function() return m:GetPivot().Position end)
			table.insert(ghosts, {Parts = parts, D = ok and flat(home - EDGE_W).Magnitude or 0, Shown = false})
		end
	end
	for _, d in ipairs(halloween:GetDescendants()) do
		if d:IsA("ParticleEmitter") and d.Enabled then
			local holder = d.Parent
			local pos = holder and holder:IsA("BasePart") and holder.Position or EDGE_W
			table.insert(fogs, {E = d, D = flat(pos - EDGE_W).Magnitude})
		end
	end
end
local greenery = {}
local trees = island:FindFirstChild("EarthGreenery")
if trees then
	for _, m in ipairs(trees:GetChildren()) do
		local ok, p = pcall(function() return m:GetPivot().Position end)
		if ok then table.insert(greenery, {Pos = p, D = flat(p - EDGE_W).Magnitude}) end
	end
	table.sort(greenery, function(a, b) return a.D < b.D end)
end
for _, e in ipairs(recolor) do e.Part.Color = e.Pre end
if halloween then halloween.Parent = nil end
player:SetAttribute("PFEPreHalloween", true)   -- (Halloween.client keeps its bats away)
onEnd(function()
	player:SetAttribute("PFEPreHalloween", false)
	for _, e in ipairs(recolor) do if e.Part.Parent then e.Part.Color = e.Now end end
	for _, e in ipairs(decor) do pcall(function() e.Model:PivotTo(e.Home) end) end
	if halloween then halloween.Parent = island end
end)

-- lighting: the Halloween dusk as it is now (PlanetClient set it) comes back exactly at the end
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local sky = Lighting:FindFirstChildOfClass("Sky")
local function snap()
	local s = {L = {ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient}}
	if atmosphere then s.A = {Density = atmosphere.Density, Offset = atmosphere.Offset, Color = atmosphere.Color, Decay = atmosphere.Decay, Glare = atmosphere.Glare, Haze = atmosphere.Haze} end
	if bloom then s.B = {Intensity = bloom.Intensity, Threshold = bloom.Threshold} end
	if grade then s.G = {TintColor = grade.TintColor, Saturation = grade.Saturation, Contrast = grade.Contrast, Brightness = grade.Brightness} end
	return s
end
local HALLOWEEN = snap()
local moonWas = sky and sky.MoonAngularSize
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local DAY = {L = {ClockTime = 14, Brightness = 2.4, Ambient = rgb(96, 107, 143), OutdoorAmbient = rgb(130, 140, 164)},
	A = {Density = 0.08, Offset = 0.1, Color = rgb(137, 165, 205), Decay = rgb(55, 59, 110), Glare = 0, Haze = 0.5},
	B = {Intensity = 0.18, Threshold = 1.25}, G = {TintColor = rgb(255, 255, 255), Saturation = 0.05, Contrast = 0, Brightness = 0}}
local STORM = {L = {ClockTime = 16.4, Brightness = 0.8, Ambient = rgb(66, 70, 86), OutdoorAmbient = rgb(78, 82, 98)},
	A = {Density = 0.42, Offset = 0.22, Color = rgb(104, 108, 122), Decay = rgb(58, 58, 70), Glare = 0, Haze = 2.6},
	B = {Intensity = 0.3, Threshold = 1.1}, G = {TintColor = rgb(212, 218, 232), Saturation = -0.35, Contrast = 0.12, Brightness = 0}}
local function lightTo(state, seconds)
	local function set(object, props)
		if not object or not props then return end
		if seconds <= 0 then
			for k, v in pairs(props) do pcall(function() object[k] = v end) end
		else
			tween(object, seconds, props, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		end
	end
	set(Lighting, state.L); set(atmosphere, state.A); set(bloom, state.B); set(grade, state.G)
end
lightTo(DAY, 0)
if sky then pcall(function() sky.MoonAngularSize = 11 end) end
onEnd(function()
	lightTo(HALLOWEEN, 0)
	if sky and moonWas then pcall(function() sky.MoonAngularSize = moonWas end) end
end)
local flashFx = Instance.new("ColorCorrectionEffect")
flashFx.Name = "PFE_IntroFlash"; flashFx.Parent = Lighting
onEnd(function() flashFx:Destroy() end)
local dof
pcall(function()
	dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "PFE_IntroFocus"; dof.FarIntensity = 0.2; dof.NearIntensity = 0; dof.FocusDistance = 30; dof.InFocusRadius = 30
	dof.Parent = Lighting
end)
onEnd(function() if dof then dof:Destroy() end end)
local clouds
pcall(function()
	local terrain = workspace.Terrain
	clouds = terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		local was = {Cover = clouds.Cover, Density = clouds.Density, Color = clouds.Color, Enabled = clouds.Enabled}
		onEnd(function() for k, v in pairs(was) do clouds[k] = v end end)
	else
		clouds = Instance.new("Clouds")
		clouds.Name = "PFE_IntroClouds"; clouds.Parent = terrain
		local made = clouds
		onEnd(function() made:Destroy() end)
	end
	clouds.Enabled = true; clouds.Cover = 0.32; clouds.Density = 0.2; clouds.Color = rgb(255, 255, 255)
end)

-- ---------------------------------------------------------------- sounds
local sounds = {}
local function sound(id, volume, looped)
	if not id or id == "" then return nil end
	local s = Instance.new("Sound")
	s.Name = "PFE_Intro"; s.SoundId = id; s.Volume = volume or 0.5; s.Looped = looped == true
	s:SetAttribute("PFEKeepSound", true)
	s.Parent = SoundService
	table.insert(sounds, s)
	return s
end
onEnd(function() for _, s in ipairs(sounds) do s:Destroy() end end)
local function oneShot(id, volume, delay, pitch, speed)
	local s = sound(id, volume)
	if not s then return end
	if speed then s.PlaybackSpeed = speed end
	if pitch then pcall(function() local fx = Instance.new("PitchShiftSoundEffect"); fx.Octave = pitch; fx.Parent = s end) end
	if delay and delay > 0 then task.delay(delay / SPEED, function() if s.Parent then s:Play() end end) else s:Play() end
	return s
end
local calm = sound(S.IntroCalm, 0, true)
local wind = sound(S.Wind, 0, true)
local rain = sound(S.Rain, 0, true)
local rumble = sound(S.Rumble, 0, true)
local caws = sound(S.CrowsCaw, 0, true)
if calm then calm:Play(); tween(calm, 1.5, {Volume = 0.45}) end

-- ---------------------------------------------------------------- effects
local fx = Instance.new("Folder")
fx.Name = "PFE_IntroFx"; fx.Parent = workspace
onEnd(function() fx:Destroy() end)
local function newPart(name, size, cf, color, material, transparency, parent)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0; p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or fx
	return p
end
local function emitter(parent, props)
	local pe = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do pcall(function() pe[k] = v end) end
	pe.Parent = parent
	return pe
end
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TEX_FIRE = "rbxasset://textures/particles/fire_main.dds"
local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local function seq(...) return NumberSequence.new(...) end
local function fade(a, b, c)
	return NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(a, b), NumberSequenceKeypoint.new(1, c or 1)})
end
-- a puff of smoke / sparks anywhere: one emitter part moved round and fired
local puffPart = newPart("Puff", Vector3.new(6, 1, 6), CFrame.new(0, -500, 0), Color3.new(1, 1, 1), nil, 1)
local puffSmoke = emitter(puffPart, {Texture = TEX_SMOKE, Rate = 0, Lifetime = NumberRange.new(1.4, 2.6), Speed = NumberRange.new(6, 18),
	Size = seq(5, 16), Transparency = fade(0.15, 0.35), SpreadAngle = Vector2.new(70, 70), Color = ColorSequence.new(rgb(90, 76, 62)),
	Acceleration = Vector3.new(0, 3, 0), RotSpeed = NumberRange.new(-60, 60), Rotation = NumberRange.new(0, 360)})
local puffDark = emitter(puffPart, {Texture = TEX_SMOKE, Rate = 0, Lifetime = NumberRange.new(1.2, 2.2), Speed = NumberRange.new(4, 12),
	Size = seq(4, 12), Transparency = fade(0.15, 0.3), SpreadAngle = Vector2.new(80, 80), Color = ColorSequence.new(rgb(38, 12, 54)),
	Acceleration = Vector3.new(0, 4, 0)})
local puffSpark = emitter(puffPart, {Texture = TEX_SPARK, Rate = 0, Lifetime = NumberRange.new(0.5, 1.2), Speed = NumberRange.new(12, 30),
	Size = seq(0.9, 0), Color = ColorSequence.new(rgb(255, 200, 90), rgb(255, 90, 20)), LightEmission = 1, LightInfluence = 0,
	SpreadAngle = Vector2.new(80, 80)})
local function puff(at, smoke, dark, sparks, size)
	puffPart.Size = Vector3.new(size or 6, 1, size or 6)
	puffPart.CFrame = CFrame.new(at)
	if smoke and smoke > 0 then pcall(function() puffSmoke:Emit(smoke) end) end
	if dark and dark > 0 then pcall(function() puffDark:Emit(dark) end) end
	if sparks and sparks > 0 then pcall(function() puffSpark:Emit(sparks) end) end
end
-- rain: a wide sheet over the camera; gusts of dust and leaves round the avatar
local rainSheet = newPart("Rain", Vector3.new(160, 1, 160), CFrame.new(0, -500, 0), Color3.new(1, 1, 1), nil, 1)
local rainFx = emitter(rainSheet, {Texture = TEX_SPARK, Rate = 0, Lifetime = NumberRange.new(0.9, 1.2), Speed = NumberRange.new(95, 120),
	EmissionDirection = Enum.NormalId.Bottom, Size = seq(0.16), Squash = seq(4), Transparency = seq(0.45),
	Color = ColorSequence.new(rgb(196, 210, 235)), LightEmission = 0.2, LightInfluence = 0.6, SpreadAngle = Vector2.new(4, 4),
	Acceleration = Vector3.new(14, 0, 6)})
local windDir = (flat(Lv(EDGE) - L(31, 0, -3)).Unit) * -1
local gustPart = newPart("Gust", Vector3.new(60, 1, 60), CFrame.new(L(31, 0.5, -3)), Color3.new(1, 1, 1), nil, 1)
local gustFx = emitter(gustPart, {Texture = TEX_SMOKE, Rate = 0, Lifetime = NumberRange.new(1.4, 2.4), Speed = NumberRange.new(2, 5),
	Size = seq(2, 7), Transparency = fade(0.3, 0.75), Color = ColorSequence.new(rgb(150, 132, 104)), Acceleration = windDir * 30,
	EmissionDirection = Enum.NormalId.Top, LightInfluence = 1})
local leafFx = emitter(gustPart, {Texture = TEX_SPARK, Rate = 0, Lifetime = NumberRange.new(1.6, 2.6), Speed = NumberRange.new(3, 8),
	Size = seq(0.5), Color = ColorSequence.new(rgb(140, 160, 60), rgb(190, 120, 40)), Acceleration = windDir * 36 + Vector3.yAxis * 4,
	RotSpeed = NumberRange.new(-300, 300), Rotation = NumberRange.new(0, 360), LightInfluence = 1, EmissionDirection = Enum.NormalId.Top})
-- lightning: a jagged neon bolt with a branch and a light at its foot
local function segment(a, b, width)
	local d = (b - a).Magnitude
	if d < 0.05 then return nil end
	return newPart("Bolt", Vector3.new(width, width, d), CFrame.lookAt((a + b) / 2, b), rgb(214, 224, 255), Enum.Material.Neon)
end
local function bolt(from, to, width, life)
	local pts = {from}
	local dir = to - from
	local p1 = dir:Cross(Vector3.new(1, 0, 0.3)).Unit
	local p2 = dir:Cross(p1).Unit
	for i = 1, 11 do
		table.insert(pts, from + dir * (i / 12) + (p1 * (math.random() - 0.5) + p2 * (math.random() - 0.5)) * dir.Magnitude * 0.07)
	end
	table.insert(pts, to)
	local made = {}
	for i = 1, #pts - 1 do table.insert(made, segment(pts[i], pts[i + 1], width)) end
	local k = math.random(3, 6)
	local tip = pts[k] + (p1 * (math.random() - 0.5) * 2 - Vector3.yAxis * 0.8).Unit * dir.Magnitude * 0.25
	table.insert(made, segment(pts[k], tip, width * 0.5))
	local foot = newPart("BoltLight", Vector3.new(1, 1, 1), CFrame.new(to + Vector3.yAxis * 3), Color3.new(1, 1, 1), nil, 1)
	local light = Instance.new("PointLight"); light.Range = 60; light.Brightness = 10; light.Color = rgb(200, 212, 255); light.Parent = foot
	table.insert(made, foot)
	task.delay((life or 0.18) / SPEED, function()
		for _, c in ipairs(made) do c:Destroy() end
	end)
end
local function flash(amount, seconds)
	flashFx.Brightness = amount
	tween(flashFx, seconds, {Brightness = 0})
end

-- ---------------------------------------------------------------- the crows (tools/intro_anim.py crow_at, the same numbers)
local CR = ANIM.Crows
local HEAD_HIT, SIDE_E = lv(CR.HeadHit), lv(CR.SideOfEdge)
local crows = {}
do
	local seed = CR.Seed
	local function nextR(a, b)
		seed = (seed * 16807) % 2147483647
		return a + (b - a) * seed / 2147483647
	end
	local folder = Instance.new("Folder"); folder.Name = "Crows"; folder.Parent = fx
	local black_ = rgb(18, 18, 24)
	for k = 1, CR.Count do
		local c = {d = nextR(0, 1.1), a = nextR(0, 2 * math.pi), r = nextR(3, 26), h = nextR(-8, 12), w = nextR(0.8, 1.6),
			side = nextR(-1, 1), lift = nextR(-0.4, 1.0), off = nextR(0.7, 6.0), spd = nextR(0.85, 1.25)}
		local body = newPart("Crow", Vector3.new(1.0, 0.9, 2.2), CFrame.new(0, -500, 0), black_, nil, 0, folder)
		local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = body
		local headP = newPart("CrowHead", Vector3.new(0.75, 0.75, 0.75), CFrame.new(0, -500, 0), black_, nil, 0, folder)
		headP.Shape = Enum.PartType.Ball
		local wl = newPart("CrowWing", Vector3.new(2.1, 0.12, 1.1), CFrame.new(0, -500, 0), black_, nil, 0, folder)
		local wr = newPart("CrowWing", Vector3.new(2.1, 0.12, 1.1), CFrame.new(0, -500, 0), black_, nil, 0, folder)
		c.Parts = {body, headP, wl, wr}
		crows[k] = c
	end
end
local function crowAt(c, t)
	if t < EV.CrowsRise - 0.2 then return nil end
	local rise = smooth(span(t, EV.CrowsRise + 0.4 * c.d, 10.4 + 0.3 * c.d))
	local function swirl(tt)
		local ang = c.a + c.w * tt
		local ctr = EDGE + OUT * 6 + Vector3.new(0, -70 + 92 * rise, 0)
		return ctr + TANG * (math.cos(ang) * c.r) + OUT * (math.sin(ang) * c.r * 0.6) + Vector3.new(0, c.h + 3 * math.sin(1.7 * tt + c.a), 0)
	end
	local t0 = EV.CrowsDive + 0.6 * c.d
	local t1 = t0 + 1.45 / c.spd
	local target = HEAD_HIT + SIDE_E * (c.side * c.off) + Vector3.new(0, c.lift * c.off * 0.6, 0)
	if t < t0 then return swirl(t) end
	if t < t1 then
		local u = (t - t0) / (t1 - t0)
		local p = swirl(t0):Lerp(target, u ^ 1.6)
		return p + SIDE_E * (math.sin(u * math.pi) * 2 * c.side)
	end
	local dt = t - t1
	if dt > 2.6 then return nil end
	local dir = (target - swirl(t0)).Unit
	local p = target + dir * (dt * 40 * c.spd)
	return p + Vector3.new(0, dt * dt * 12 + dt * 4, 0) + SIDE_E * (c.side * dt * 10)
end
local PARK = CFrame.new(0, -600, 0)
local crowParts, crowCFrames = {}, {}
local nearCamCrow = 0
local function playCrows(t, camPos)
	local n = 0
	nearCamCrow = 0
	for _, c in ipairs(crows) do
		local p = crowAt(c, t)
		local cf0, cf1, cf2, cf3
		if p then
			local q = crowAt(c, t + 0.05) or p
			local pw, qw = Lv(p), Lv(q)
			local look = (qw - pw).Magnitude > 1e-3 and CFrame.lookAt(pw, qw) or CFrame.new(pw)
			local flap = math.sin(t * 22 + c.a * 5) * 0.9
			cf0 = look
			cf1 = look * CFrame.new(0, 0.35, -1.25)
			cf2 = look * CFrame.new(-0.4, 0.1, 0.1) * CFrame.Angles(0, 0, flap) * CFrame.new(-1.0, 0, 0)
			cf3 = look * CFrame.new(0.4, 0.1, 0.1) * CFrame.Angles(0, 0, -flap) * CFrame.new(1.0, 0, 0)
			if camPos and (pw - camPos).Magnitude < 4 then nearCamCrow += 1 end
		else
			cf0, cf1, cf2, cf3 = PARK, PARK, PARK, PARK
		end
		local parts = c.Parts
		crowParts[n + 1], crowCFrames[n + 1] = parts[1], cf0
		crowParts[n + 2], crowCFrames[n + 2] = parts[2], cf1
		crowParts[n + 3], crowCFrames[n + 3] = parts[3], cf2
		crowParts[n + 4], crowCFrames[n + 4] = parts[4], cf3
		n += 4
	end
	local ok = pcall(function() workspace:BulkMoveTo(crowParts, crowCFrames, Enum.BulkMoveMode.FireCFrameChanged) end)
	if not ok then for k = 1, n do crowParts[k].CFrame = crowCFrames[k] end end
end

-- ---------------------------------------------------------------- the darkness sweeping the island
local WAVE = ANIM.Wave
local wallParts = {}
for k = 1, 44 do
	local p = newPart("DarkWall", Vector3.new(10, 1, 10), CFrame.new(0, -500, 0), Color3.new(1, 1, 1), nil, 1)
	local smoke = emitter(p, {Texture = TEX_SMOKE, Rate = 0, Lifetime = NumberRange.new(2.2, 3.4), Speed = NumberRange.new(4, 10),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 12), NumberSequenceKeypoint.new(1, 34)}), Transparency = fade(0.2, 0.3),
		Color = ColorSequence.new(rgb(46, 12, 66), rgb(14, 6, 22)), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 3, 0), RotSpeed = NumberRange.new(-40, 40), Rotation = NumberRange.new(0, 360), LightInfluence = 0.4})
	local embers = emitter(p, {Texture = TEX_SPARK, Rate = 0, Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(6, 16),
		Size = seq(0.8, 0), Color = ColorSequence.new(rgb(255, 160, 60), rgb(200, 60, 255)), LightEmission = 1, LightInfluence = 0,
		SpreadAngle = Vector2.new(50, 50), Acceleration = Vector3.new(0, 6, 0)})
	wallParts[k] = {Part = p, Smoke = smoke, Embers = embers, A = (k - 0.5) / 44}
end
-- the thorny vines it drags across the grass
local vines = {}
do
	local seed = 4242
	local function nextR(a, b) seed = (seed * 16807) % 2147483647; return a + (b - a) * seed / 2147483647 end
	local inwardAt = -OUT
	for k = 1, 11 do
		local ang = math.rad(-70 + 140 * (k - 0.5) / 11 + nextR(-6, 6))
		local dir = (inwardAt * math.cos(ang) + TANG * math.sin(ang)).Unit
		table.insert(vines, {Dir = dir, Len = 0, Max = nextR(150, 240), Wig = nextR(0, 6.28), Seed = nextR(0, 100),
			Tip = EDGE + dir * 2, Count = 0})
	end
end
local VINE = rgb(28, 10, 34)
local function growVines(R)
	for _, v in ipairs(vines) do
		while v.Len + 5 <= math.min(R, v.Max) do
			v.Len += 5
			v.Count += 1
			local bend = math.sin(v.Len * 0.06 + v.Wig) * 0.5 + math.sin(v.Len * 0.17 + v.Seed) * 0.25
			local d = (v.Dir + TANG * bend * 0.6).Unit
			local nextTip = v.Tip + d * 5
			local a, b = Lv(v.Tip) + Vector3.yAxis * 0.4, Lv(nextTip) + Vector3.yAxis * 0.4
			local w = math.max(0.5, 1.6 - v.Len / v.Max * 1.1)
			newPart("Vine", Vector3.new(w, w * 0.7, (b - a).Magnitude + 0.3), CFrame.lookAt((a + b) / 2, b), VINE, Enum.Material.SmoothPlastic)
			if v.Count % 2 == 0 then
				local sideV = (b - a):Cross(Vector3.yAxis).Unit * (v.Count % 4 == 0 and 1 or -1)
				local thorn = newPart("Thorn", Vector3.new(0.3, 1.0, 0.9), CFrame.lookAt(a + sideV * w * 0.6, a + sideV * 4) * CFrame.Angles(0, 0, 0),
					rgb(255, 120, 40), Enum.Material.Neon)
				thorn.Size = Vector3.new(0.25, 0.25, 1.1)
			end
			v.Tip = nextTip
		end
	end
end
local function playWave(t, camPos)
	local R = sample(WAVE, ANIM.WaveRate, t)
	-- the dark wall: a ring of rising murk at the front (only where it is over the island)
	for _, w in ipairs(wallParts) do
		local ang = math.rad(-95 + 190 * w.A)
		local dir = ((-OUT) * math.cos(ang) + TANG * math.sin(ang)).Unit
		local p = Lv(EDGE + dir * R)
		local onIsland = R > 2 and t < EV.WaveEnd + 2 and Vector2.new(p.X, p.Z).Magnitude < 352
		if onIsland then
			w.Part.CFrame = CFrame.new(p.X, groundY + 1, p.Z)
			w.Smoke.Rate = 7; w.Embers.Rate = 8
		else
			w.Smoke.Rate = 0; w.Embers.Rate = 0
		end
	end
	growVines(R)
	-- what it has swallowed turns Halloween; the decor rises out of the ground behind it
	return R
end
local waveIndex, decorIndex, treeIndex, rising = 1, 1, 1, {}
local function backOut(u)
	u = math.clamp(u, 0, 1)
	local c1 = 1.9
	return 1 + (c1 + 1) * (u - 1) ^ 3 + c1 * (u - 1) ^ 2
end
local focusPos = L(31, 0, -3)
local function startWave()
	-- the decor waits underground (it rises as the darkness passes), the ghosts and the fog wait unseen
	for _, e in ipairs(decor) do pcall(function() e.Model:PivotTo(e.Home * CFrame.new(0, -e.H, 0)) end) end
	for _, g in ipairs(ghosts) do for _, p in ipairs(g.Parts) do p.LocalTransparencyModifier = 1 end end
	for _, f in ipairs(fogs) do f.E.Enabled = false end
	if halloween then halloween.Parent = island end
end
onEnd(function()
	for _, g in ipairs(ghosts) do for _, p in ipairs(g.Parts) do if p.Parent then p.LocalTransparencyModifier = 0 end end end
	for _, f in ipairs(fogs) do if f.E.Parent then f.E.Enabled = true end end
end)
local function swallow(t, R)
	for _, g in ipairs(ghosts) do
		if not g.Shown and g.D <= R then
			g.Shown = true
			for _, p in ipairs(g.Parts) do p.LocalTransparencyModifier = 0 end
		end
	end
	for _, f in ipairs(fogs) do if not f.E.Enabled and f.D <= R then f.E.Enabled = true end end
	while waveIndex <= #recolor and recolor[waveIndex].D <= R do
		local e = recolor[waveIndex]
		if e.Part.Parent then e.Part.Color = e.Now end
		waveIndex += 1
	end
	while decorIndex <= #decor and decor[decorIndex].D <= R do
		local e = decor[decorIndex]
		if (flat(e.Home.Position - focusPos)).Magnitude < 190 then table.insert(rising, {E = e, Start = t})
		else pcall(function() e.Model:PivotTo(e.Home) end) end
		decorIndex += 1
	end
	while treeIndex <= #greenery and greenery[treeIndex].D <= R do
		local g = greenery[treeIndex]
		if (flat(g.Pos - focusPos)).Magnitude < 150 then puff(g.Pos + Vector3.yAxis * 6, 0, 22, 6, 10) end
		treeIndex += 1
	end
	for i = #rising, 1, -1 do
		local item = rising[i]
		local u = (t - item.Start) / 0.6
		local y = -item.E.H * (1 - backOut(u))
		pcall(function() item.E.Model:PivotTo(item.E.Home * CFrame.new(0, y, 0)) end)
		if u >= 1 then table.remove(rising, i) end
	end
end

-- ---------------------------------------------------------------- the Pumpkin King
local BO = ANIM.Boss
local boss, bossRoot, motors, glow, headLight, mouthAtt, scytheParts
local bossTemplate = api:FindFirstChild("Cutscene") and api.Cutscene:FindFirstChild("PumpkinKing")
local GLOWS = {EyeR = true, EyeL = true, EyeCore = true, Nose = true, Mouth = true, Throat = true, Crack = true, Heart = true, Tear = true}
if bossTemplate then
	local ok = pcall(function()
		boss = bossTemplate:Clone()
		bossRoot = boss.PrimaryPart or boss:FindFirstChild("Root")
		bossRoot.Anchored = true
		bossRoot.CFrame = CFrame.new(EDGE_W - Vector3.yAxis * 400)
		motors, glow, scytheParts = {}, {}, {}
		for _, d in ipairs(boss:GetDescendants()) do
			if d:IsA("Motor6D") then motors[d.Name] = d end
			if d:IsA("BasePart") then
				d.CanCollide = false; d.CanTouch = false; d.CanQuery = false
				if d.Material == Enum.Material.Neon and GLOWS[d.Name] then table.insert(glow, {Part = d, Color = d.Color}) end
			end
		end
		-- the scythe is summoned later: hidden till then (everything welded to its grip)
		local grip = motors.Scythe and motors.Scythe.Part1
		if grip then
			for _, w in ipairs(boss:GetDescendants()) do
				if w:IsA("WeldConstraint") and (w.Part0 == grip or w.Part1 == grip) then
					local other = w.Part0 == grip and w.Part1 or w.Part0
					if other and other ~= grip then table.insert(scytheParts, {Part = other, T = other.Transparency}) end
				end
			end
			table.insert(scytheParts, {Part = grip, T = grip.Transparency})
			for _, e in ipairs(scytheParts) do e.Part.Transparency = 1 end
		end
		boss.Parent = fx
	end)
	if not ok then boss = nil end
end
local function bossPart(name)
	local m = boss and motors[name]
	return m and m.Part1
end
if boss then
	local headPart = bossPart("Head")
	if headPart then
		headLight = Instance.new("PointLight"); headLight.Color = rgb(255, 140, 40); headLight.Range = 46; headLight.Brightness = 2; headLight.Parent = headPart
		for _, eye in ipairs({"EyeR", "EyeL"}) do
			local part = boss:FindFirstChild(eye, true)
			if part then
				emitter(part, {Texture = TEX_FIRE, Rate = 22, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(3, 7),
					Size = seq(2.6, 0.4), Transparency = seq(0.2, 1), Color = ColorSequence.new(rgb(255, 200, 80), rgb(255, 70, 20)),
					LightEmission = 1, LightInfluence = 0, EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, 6, 0)})
			end
		end
		mouthAtt = Instance.new("Attachment")
		mouthAtt.Name = "Mouth"; mouthAtt.Parent = headPart
		local mouthWorld = bossRoot.CFrame * CFrame.new(0, 75.5, -12.5)
		mouthAtt.WorldCFrame = CFrame.lookAt(mouthWorld.Position, mouthWorld.Position + mouthWorld.LookVector)
		emitter(mouthAtt, {Name = "Embers", Texture = TEX_SPARK, Rate = 0, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(14, 26),
			Size = seq(1.2, 0), Color = ColorSequence.new(rgb(255, 210, 90), rgb(255, 90, 20)), LightEmission = 1, LightInfluence = 0,
			EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(28, 18), Acceleration = Vector3.new(0, 10, 0)})
	end
	local heart = boss:FindFirstChild("Heart", true)
	if heart then local l = Instance.new("PointLight"); l.Color = rgb(255, 110, 30); l.Range = 18; l.Brightness = 2; l.Parent = heart end
	local hand = bossPart("HandR")
	if hand then
		emitter(hand, {Name = "Summon", Texture = TEX_FIRE, Rate = 0, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(4, 14),
			Size = seq(6, 0), Color = ColorSequence.new(rgb(200, 110, 255), rgb(90, 20, 160)), LightEmission = 1, LightInfluence = 0,
			SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 12, 0)})
	end
end
local function playBoss(t, laughing)
	if not boss then return end
	if t < BO.Start then return end
	local rate, start, r = BO.Rate, BO.Start, BO.Root
	local pos = L(sample(r.s, rate, t, start), sample(r.u, rate, t, start), sample(r.i, rate, t, start))
	bossRoot.CFrame = frameAt(pos, sample(r.facing, rate, t, start), sample(r.pitch, rate, t, start))
	for _, name in ipairs(BO.Joints) do
		local motor = motors[name]
		local ch = BO.Pose[name]
		if motor and ch then
			local x, y, z = sample(ch.x, rate, t, start), sample(ch.y, rate, t, start), sample(ch.z, rate, t, start)
			-- the coat in the wind, the head never quite still, the crows looking about; the laugh shakes it all
			if name == "Tails" then x += math.sin(t * 2.1) * 5; z += math.sin(t * 1.3) * 3 end
			if name == "Head" then y += math.sin(t * 0.9) * 3 end
			if name == "Crow" or name == "Crow2" then y += (math.floor(t * 1.6 + #name) % 3 - 1) * 25 end
			if laughing > 0 then
				local beat = t * math.pi * 2 * 4.2
				if name == "Head" then x += math.sin(beat) * 7 * laughing; z += math.sin(beat * 0.5) * 4 * laughing end
				if name == "Jaw" then x -= math.abs(math.sin(beat)) * 12 * laughing end
				if name == "Torso" then x += math.sin(beat + 1) * 2.5 * laughing end
				if name == "ArmL" then z -= math.sin(beat + 2) * 5 * laughing end
				if name == "Hat" then x += math.sin(beat + 0.6) * 4 * laughing end
			end
			motor.Transform = CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
		end
	end
	local pulse = laughing > 0 and (0.35 + 0.45 * math.abs(math.sin(t * math.pi * 4.2))) * laughing or 0.15 + 0.1 * math.sin(t * 3)
	for _, g in ipairs(glow) do g.Part.Color = g.Color:Lerp(Color3.new(1, 0.96, 0.78), math.clamp(pulse, 0, 1)) end
	if headLight then headLight.Brightness = 2 + pulse * 4 end
end
-- rocks and earth thrown off the rim
local chunks = {}
local EARTH = {rgb(78, 62, 44), rgb(96, 76, 52), rgb(66, 82, 48), rgb(110, 90, 60), rgb(107, 96, 81)}
local function throwRocks(at, count, up, out)
	for _ = 1, count do
		local s = 0.8 + math.random() * 2.6
		local p = newPart("Rock", Vector3.new(s, s * 0.7, s * 1.1), CFrame.new(at + Vector3.new(math.random() * 8 - 4, 0.5, math.random() * 8 - 4)),
			EARTH[math.random(1, #EARTH)], Enum.Material.Slate)
		local dir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 2 + (out or Vector3.zero)
		table.insert(chunks, {Part = p, V = dir * (6 + math.random() * 10) + Vector3.yAxis * (up or 30) * (0.5 + math.random() * 0.7),
			Spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 8, Age = 0})
	end
end
local function playRocks(dt)
	for i = #chunks, 1, -1 do
		local c = chunks[i]
		c.Age += dt
		c.V += Vector3.new(0, -110, 0) * dt
		local cf = c.Part.CFrame
		local pos = cf.Position + c.V * dt
		if c.Age > 4 or pos.Y < groundY - 160 then
			c.Part:Destroy(); table.remove(chunks, i)
		else
			c.Part.CFrame = CFrame.new(pos) * (cf - cf.Position) * CFrame.Angles(c.Spin.X * dt, c.Spin.Y * dt, c.Spin.Z * dt)
		end
	end
end

-- ---------------------------------------------------------------- the camera (baked shots)
local camera = workspace.CurrentCamera
local camWas = {Fov = camera.FieldOfView}
camera.CameraType = Enum.CameraType.Scriptable
onEnd(function()
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
	camera.FieldOfView = camWas.Fov
	if root.Parent then camera.CFrame = CFrame.lookAt(standCF.Position + standCF.LookVector * -12 + Vector3.yAxis * 5, standCF.Position) end
end)
local SHOTS = ANIM.Camera
local function shotAt(t)
	for _, s in ipairs(SHOTS) do if t < s.To then return s end end
	return SHOTS[#SHOTS]
end
local function playCamera(t)
	local s = shotAt(t)
	local rate, from = s.Rate, s.From
	local eye = L(sample(s.Eye.s, rate, t, from), sample(s.Eye.u, rate, t, from), sample(s.Eye.i, rate, t, from))
	local tgt = L(sample(s.Target.s, rate, t, from), sample(s.Target.u, rate, t, from), sample(s.Target.i, rate, t, from))
	if (tgt - eye).Magnitude < 0.05 then return eye end
	local amp = sample(s.Shake, rate, t, from)
	local n1 = math.noise(t * 14, 1.7) * amp
	local n2 = math.noise(t * 14, 9.1) * amp
	local n3 = math.noise(t * 11, 4.4) * amp
	camera.CFrame = CFrame.lookAt(eye, tgt) * CFrame.Angles(math.rad(n1 * 2.2), math.rad(n2 * 2.2), math.rad(n3 * 1.4))
	camera.FieldOfView = sample(s.Fov, rate, t, from)
	if dof then pcall(function() dof.FocusDistance = (tgt - eye).Magnitude; dof.InFocusRadius = math.max(6, (tgt - eye).Magnitude * 0.6) end) end
	return eye
end

-- ---------------------------------------------------------------- the timeline
local startClock = os.clock()
local skipped = false
local function now() return (os.clock() - startClock) * SPEED end
local fired = {}
local function once(key, t, at, fn)
	if not fired[key] and t >= at then fired[key] = true; fn() end
end
skip.Activated:Connect(function() if not skipped and not finished then skipped = true end end)
local lastT, lastHide = 0, 0
local frameConn
frameConn = RunService.RenderStepped:Connect(function()
	if finished then return end
	local t = now()
	local dt = math.clamp(t - lastT, 0, 0.1)
	lastT = t
	if t - lastHide > 0.25 then
		lastHide = t; hideGuis(); hidePeople()
		if root.Parent then
			if not root.Anchored then root.Anchored = true end
			if (root.Position - hiddenCF.Position).Magnitude > 1 then root.CFrame = hiddenCF end
		end
	end
	playActor(t)
	local camPos = playCamera(t)
	-- ---- the calm, then the storm
	once("skip", t, 1.0, function() tween(skip, 0.6, {TextTransparency = 0.15}) end)
	once("storm", t, EV.StormStart, function()
		lightTo(STORM, 4.4)
		if clouds then pcall(function() tween(clouds, 4, {Cover = 0.94, Density = 0.82, Color = rgb(72, 72, 84)}) end) end
		if wind then wind:Play(); tween(wind, 2.5, {Volume = 0.7}) end
		if calm then tween(calm, 2.6, {PlaybackSpeed = 0.5, Volume = 0}) end
		gustFx.Rate = 12; leafFx.Rate = 16
	end)
	once("rain", t, EV.Rain, function()
		if rain then rain:Play(); tween(rain, 2, {Volume = 0.55}) end
		tween(rainFx, 2.2, {Rate = 900})
	end)
	once("far1", t, EV.FarBolt1, function()
		bolt(L(-60, 320, 180), L(-40, 0, 230), 1.6, 0.16); flash(0.35, 0.5); oneShot(S.Thunder, 0.45, 0.9)
	end)
	once("far2", t, EV.FarBolt2, function()
		bolt(Lv(EDGE) + Vector3.new(30, 340, 0) + side * 40, Lv(EDGE) + side * 60 - inward * 30, 1.8, 0.2); flash(0.45, 0.5)
		oneShot(S.Thunder, 0.6, 0.4)
	end)
	-- ---- the crows: out from under the edge, straight at it
	once("crows", t, EV.CrowsRise, function()
		if caws then caws:Play(); tween(caws, 1.2, {Volume = 0.8}) end
		oneShot(S.RavenSquawk, 0.6, 0.6)
	end)
	once("wings", t, EV.CrowsDive + 0.5, function() oneShot(S.WingsRush, 1, 0); oneShot(S.WingsRush, 0.8, 0.9, nil, 0.85) end)
	if t >= EV.CrowsRise - 0.3 and t < EV.CrowsGone then playCrows(t, camPos) elseif t >= EV.CrowsGone then
		once("crowsOff", t, EV.CrowsGone, function() playCrows(-1) end)
	end
	-- crows brushing past the lens
	for k, w in ipairs(flutter) do
		local on = nearCamCrow > 0 and t > EV.CrowsDive and t < EV.CrowsGone and (k <= nearCamCrow)
		w.Visible = on
		if on then
			w.Position = UDim2.fromScale(0.5 + math.noise(t * 6, k) * 0.9, 0.5 + math.noise(k, t * 6) * 0.9)
			w.Rotation = math.noise(t * 3, k * 2) * 180
		end
	end
	for _, h in ipairs(ANIM.Actor.Hits or {}) do
		once("hit" .. h, t, h, function() oneShot(S.BatHit, 0.35, 0, nil, 0.8 + math.random() * 0.4) end)
	end
	once("knock", t, 13.75, function() oneShot(S.BatHit, 0.7, 0, nil, 0.6); puff(actorPos - Vector3.yAxis * 2, 10, 0, 0, 4) end)
	once("cawsOff", t, EV.CrowsGone - 1.2, function() if caws then tween(caws, 2.5, {Volume = 0}) end end)
	-- ---- the darkness: the music, the wave across the island, the world swallowed
	once("sting", t, EV.WaveStart, function()
		startWave()
		oneShot(S.HorrorSting, 0.8); oneShot(S.WaveWhoosh, 0.7, 0.2, nil, 0.7)
		tween(rainFx, 2, {Rate = 450}); if rain then tween(rain, 2, {Volume = 0.3}) end
		gustFx.Rate = 4; leafFx.Rate = 4
		if clouds then pcall(function() tween(clouds, 3, {Color = rgb(58, 40, 76)}) end) end
	end)
	once("music", t, EV.Music, function() player:SetAttribute("PFECutscene", "music") end)   -- (Music.client: the island's playlist)
	once("dusk", t, EV.WaveAtActor - 1.8, function()
		lightTo(HALLOWEEN, 2.4)
		if sky and moonWas then pcall(function() sky.MoonAngularSize = moonWas end) end
	end)
	once("engulf", t, EV.WaveAtActor, function()
		engulf.BackgroundTransparency = 0.15
		tween(engulf, 1.1, {BackgroundTransparency = 1})
		oneShot(S.WaveWhoosh, 1, 0); puff(actorPos, 0, 40, 20, 14)
		player:SetAttribute("PFEPreHalloween", false)
	end)
	if t >= EV.WaveStart then
		local R = playWave(t, camPos)
		swallow(t, R)
	end
	once("wallOff", t, EV.WaveEnd + 2, function() for _, w in ipairs(wallParts) do w.Smoke.Rate = 0; w.Embers.Rate = 0 end end)
	-- ---- the Pumpkin King
	once("rumble", t, EV.Rumble, function() if rumble then rumble:Play(); tween(rumble, 1.4, {Volume = 0.9}) end end)
	once("growl", t, EV.Growl, function() oneShot(S.BossGrowl, 0.9, 0, 0.7) end)
	once("slam1", t, EV.Slam1, function()
		local p = Lv(lv(ANIM.GripR)); puff(p, 40, 0, 20, 16); throwRocks(p, 14, 34, OUT); oneShot(S.BigBoom, 0.9); flash(0.2, 0.3)
	end)
	once("slam2", t, EV.Slam2, function()
		local p = Lv(lv(ANIM.GripL)); puff(p, 40, 0, 20, 16); throwRocks(p, 14, 34, OUT); oneShot(S.BigBoom, 0.9); flash(0.2, 0.3)
	end)
	once("climb", t, EV.Climb, function() oneShot(S.RockCrumble, 0.8) end)
	if t > EV.Climb and t < EV.Stomp and math.random() < 0.25 then throwRocks(Lv(EDGE + TANG * (math.random() * 30 - 15)), 1, 4, OUT * 0.8) end
	once("stomp", t, EV.Stomp, function()
		puff(Lv(EDGE - OUT * 10), 60, 0, 0, 30); oneShot(S.BigBoom, 1, 0, nil, 0.7)
		if rumble then tween(rumble, 1.6, {Volume = 0}) end
	end)
	once("summon", t, EV.Summon, function()
		local hand = bossPart("HandR")
		local e = hand and hand:FindFirstChild("Summon")
		if e then pcall(function() e:Emit(90) end) end
		oneShot(S.MagicWhoosh, 0.9)
		for _, s in ipairs(scytheParts or {}) do
			s.Part.Transparency = 1
			tween(s.Part, 0.6, {Transparency = s.T})
		end
	end)
	local laughing = 0
	if t >= EV.Laugh and t < EV.Loom + 0.4 then laughing = math.min(1, (t - EV.Laugh) / 0.4) * (1 - span(t, EV.Loom - 0.3, EV.Loom + 0.4)) end
	once("laugh", t, EV.Laugh, function()
		oneShot(S.BossLaugh, 1, 0.1, 0.78)
		task.delay(1.1 / SPEED, function() oneShot(S.BossLaugh, 0.35, 0, 0.62) end)
		local embers = mouthAtt and mouthAtt:FindFirstChild("Embers")
		if embers then embers.Rate = 90 end
	end)
	once("card", t, EV.Card, function()
		card.Visible = true; cardScale.Scale = 1.5
		cardName.TextTransparency = 1; cardSub.TextTransparency = 1
		tween(cardScale, 0.5, {Scale = 1}, Enum.EasingStyle.Back)
		tween(cardName, 0.4, {TextTransparency = 0})
		tween(cardLine, 0.8, {Size = UDim2.fromScale(0.55, 0.03)})
		task.delay(0.5 / SPEED, function() tween(cardSub, 0.6, {TextTransparency = 0}) end)
	end)
	once("back1", t, EV.Laugh + 1.0, function()
		local p = Lv(EDGE + OUT * 120)
		bolt(p + Vector3.new(-30, 380, 0), p + side * 40, 2.2, 0.2); flash(0.5, 0.6); oneShot(S.Thunder, 0.7, 0.3)
	end)
	once("cardOut", t, EV.Loom - 0.2, function()
		tween(cardName, 0.4, {TextTransparency = 1}); tween(cardSub, 0.4, {TextTransparency = 1}); tween(cardLine, 0.4, {Size = UDim2.fromScale(0, 0.03)})
	end)
	once("loom", t, EV.Loom, function()
		local embers = mouthAtt and mouthAtt:FindFirstChild("Embers")
		if embers then embers.Rate = 40 end
		oneShot(S.BossGrowl, 1, 0.3, 0.6)
	end)
	playBoss(t, laughing)
	playRocks(dt)
	-- ---- black, and back to the game
	once("black", t, EV.Black, function()
		tween(black, 0.4, {BackgroundTransparency = 0})
		oneShot(S.BigBoom, 0.8)
		if rain then tween(rain, 1.2, {Volume = 0}) end
		if wind then tween(wind, 1.2, {Volume = 0}) end
	end)
	rainSheet.CFrame = CFrame.new(camera.CFrame.Position + Vector3.yAxis * 40)
end)
onEnd(function() if frameConn then frameConn:Disconnect() end end)

-- ---------------------------------------------------------------- run it, then put everything back
tween(black, 1.0, {BackgroundTransparency = 1})
while now() < ANIM.Duration and not skipped do task.wait() end
if skipped then
	tween(black, 0.3, {BackgroundTransparency = 0})
	task.wait(0.35 / SPEED)
end
finished = true
black.BackgroundTransparency = 0
card.Visible = false
for _, w in ipairs(flutter) do w.Visible = false end
restoreAll()
player:SetAttribute("PFECutscene", false)
api:WaitForChild("Action"):FireServer("IntroDone")
task.wait(0.35 / SPEED)
tween(black, 0.9, {BackgroundTransparency = 1})
tween(skip, 0.3, {TextTransparency = 1, BackgroundTransparency = 1})
task.wait(1 / SPEED)
gui:Destroy()
