--!nocheck
-- (v41) The planet bosses on screen. The server moves an invisible hitbox (GameServer.PlanetLife.Bosses) and says what
-- the boss does (attributes Act / ActAt, and BossAct effects); this script builds its body out of parts - a stone GOLEM,
-- a furry YETI or a segmented WORM, in the boss's colours - follows the hitbox smoothly and animates it: walking, the
-- wind-up and the slam, throwing, the Yeti's leap, the Worm diving into the ground and bursting up under someone, the roar
-- when it gets angry, falling over when beaten. On the boss's planet a health bar with its name sits at the top.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local UI = require(api:WaitForChild("UIKit"))
local player = Players.LocalPlayer
local C = UI.C
local S = Config.Sounds

local folder = Instance.new("Folder")
folder.Name = "PFE_BossBodies"
folder.Parent = workspace

local function part(model, name, props)
	local p = Instance.new("Part")
	p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = model
	return p
end
local function sound(id, position, volume, speed)
	local holder = Instance.new("Part")
	holder.Anchored = true; holder.CanCollide = false; holder.CanQuery = false; holder.Transparency = 1; holder.Size = Vector3.one; holder.Position = position
	holder.Parent = folder
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = volume or 0.7; s.PlaybackSpeed = speed or 1; s.RollOffMaxDistance = 600; s.Parent = holder
	s:Play(); Debris:AddItem(holder, 8)
end

-- ---------------------------------------------------------------- bodies (part offsets from the feet, in the boss's frame)
-- every piece: {name, size, offset CFrame, colour key, material, shape, joint}; joint = the limb it swings with
local function golem(h, main, dark, glow)
	local u = h / 20
	return {
		{"LegL", Vector3.new(3.6, 6, 3.6) * u, CFrame.new(-2.6 * u, 3 * u, 0), dark, Enum.Material.Slate, nil, "LegL"},
		{"LegR", Vector3.new(3.6, 6, 3.6) * u, CFrame.new(2.6 * u, 3 * u, 0), dark, Enum.Material.Slate, nil, "LegR"},
		{"Torso", Vector3.new(10, 8, 6) * u, CFrame.new(0, 10 * u, 0), main, Enum.Material.Slate, nil, "Body"},
		{"Chest", Vector3.new(8, 3, 6.4) * u, CFrame.new(0, 12.5 * u, -0.2 * u), main, Enum.Material.Slate, nil, "Body"},
		{"Core", Vector3.new(2.4, 2.4, 0.6) * u, CFrame.new(0, 10.5 * u, -3.2 * u), glow, Enum.Material.Neon, nil, "Body"},
		{"Head", Vector3.new(4.6, 3.6, 4.2) * u, CFrame.new(0, 15.8 * u, -0.6 * u), main, Enum.Material.Slate, nil, "Head"},
		{"EyeL", Vector3.new(0.9, 0.6, 0.3) * u, CFrame.new(-1.1 * u, 16.2 * u, -2.8 * u), glow, Enum.Material.Neon, nil, "Head"},
		{"EyeR", Vector3.new(0.9, 0.6, 0.3) * u, CFrame.new(1.1 * u, 16.2 * u, -2.8 * u), glow, Enum.Material.Neon, nil, "Head"},
		{"ArmL", Vector3.new(3.2, 9, 3.2) * u, CFrame.new(-6.8 * u, 9.5 * u, 0), dark, Enum.Material.Slate, nil, "ArmL"},
		{"ArmR", Vector3.new(3.2, 9, 3.2) * u, CFrame.new(6.8 * u, 9.5 * u, 0), dark, Enum.Material.Slate, nil, "ArmR"},
		{"FistL", Vector3.new(4.2, 3.6, 4.2) * u, CFrame.new(-6.8 * u, 4.4 * u, 0), main, Enum.Material.Slate, nil, "ArmL"},
		{"FistR", Vector3.new(4.2, 3.6, 4.2) * u, CFrame.new(6.8 * u, 4.4 * u, 0), main, Enum.Material.Slate, nil, "ArmR"},
		{"CrackA", Vector3.new(0.3, 5, 0.3) * u, CFrame.new(-2.5 * u, 9.5 * u, -3.05 * u) * CFrame.Angles(0, 0, 0.5), glow, Enum.Material.Neon, nil, "Body"},
		{"CrackB", Vector3.new(0.3, 4, 0.3) * u, CFrame.new(2.8 * u, 8.5 * u, -3.05 * u) * CFrame.Angles(0, 0, -0.6), glow, Enum.Material.Neon, nil, "Body"},
		{"Shoulder", Vector3.new(12.6, 2.6, 5) * u, CFrame.new(0, 13.6 * u, 0.4 * u), dark, Enum.Material.Slate, nil, "Body"},
	}, {ArmL = CFrame.new(-6.8 * u, 13 * u, 0), ArmR = CFrame.new(6.8 * u, 13 * u, 0), LegL = CFrame.new(-2.6 * u, 6 * u, 0), LegR = CFrame.new(2.6 * u, 6 * u, 0),
		Head = CFrame.new(0, 14 * u, 0), Body = CFrame.new(0, 6 * u, 0)}
end
local function yeti(h, main, dark, glow)
	local u = h / 18
	return {
		{"LegL", Vector3.new(3.4, 5, 3.4) * u, CFrame.new(-2.4 * u, 2.5 * u, 0), main, Enum.Material.Fabric, nil, "LegL"},
		{"LegR", Vector3.new(3.4, 5, 3.4) * u, CFrame.new(2.4 * u, 2.5 * u, 0), main, Enum.Material.Fabric, nil, "LegR"},
		{"Belly", Vector3.new(10, 10, 9) * u, CFrame.new(0, 9 * u, 0), main, Enum.Material.Fabric, Enum.PartType.Ball, "Body"},
		{"Chest", Vector3.new(7, 6, 3) * u, CFrame.new(0, 9.5 * u, -3.4 * u), dark, Enum.Material.SmoothPlastic, nil, "Body"},
		{"Head", Vector3.new(6, 6, 6) * u, CFrame.new(0, 15.5 * u, -0.5 * u), main, Enum.Material.Fabric, Enum.PartType.Ball, "Head"},
		{"Face", Vector3.new(4, 3.2, 1) * u, CFrame.new(0, 15.2 * u, -3 * u), dark, Enum.Material.SmoothPlastic, nil, "Head"},
		{"EyeL", Vector3.new(0.8, 0.8, 0.3) * u, CFrame.new(-0.9 * u, 15.8 * u, -3.55 * u), glow, Enum.Material.Neon, nil, "Head"},
		{"EyeR", Vector3.new(0.8, 0.8, 0.3) * u, CFrame.new(0.9 * u, 15.8 * u, -3.55 * u), glow, Enum.Material.Neon, nil, "Head"},
		{"Mouth", Vector3.new(2.4, 0.6, 0.3) * u, CFrame.new(0, 14.4 * u, -3.55 * u), Color3.fromRGB(40, 20, 30), Enum.Material.SmoothPlastic, nil, "Head"},
		{"HornL", Vector3.new(0.8, 2.6, 0.8) * u, CFrame.new(-2.2 * u, 18.4 * u, 0) * CFrame.Angles(0, 0, 0.5), Color3.fromRGB(240, 235, 220), Enum.Material.SmoothPlastic, nil, "Head"},
		{"HornR", Vector3.new(0.8, 2.6, 0.8) * u, CFrame.new(2.2 * u, 18.4 * u, 0) * CFrame.Angles(0, 0, -0.5), Color3.fromRGB(240, 235, 220), Enum.Material.SmoothPlastic, nil, "Head"},
		{"ArmL", Vector3.new(3.6, 10, 3.6) * u, CFrame.new(-6.4 * u, 8.6 * u, 0), main, Enum.Material.Fabric, nil, "ArmL"},
		{"ArmR", Vector3.new(3.6, 10, 3.6) * u, CFrame.new(6.4 * u, 8.6 * u, 0), main, Enum.Material.Fabric, nil, "ArmR"},
		{"HandL", Vector3.new(3.6, 2.6, 3.6) * u, CFrame.new(-6.4 * u, 3 * u, 0), dark, Enum.Material.SmoothPlastic, nil, "ArmL"},
		{"HandR", Vector3.new(3.6, 2.6, 3.6) * u, CFrame.new(6.4 * u, 3 * u, 0), dark, Enum.Material.SmoothPlastic, nil, "ArmR"},
	}, {ArmL = CFrame.new(-6.4 * u, 13 * u, 0), ArmR = CFrame.new(6.4 * u, 13 * u, 0), LegL = CFrame.new(-2.4 * u, 5 * u, 0), LegR = CFrame.new(2.4 * u, 5 * u, 0),
		Head = CFrame.new(0, 13.5 * u, 0), Body = CFrame.new(0, 4 * u, 0)}
end
-- the worm: segments (placed every frame along its curve), a head with jaws
local function worm(h, main, dark, glow)
	local u = h / 16
	local pieces = {}
	for i = 1, 8 do
		local s = (4.6 - i * 0.25) * u
		table.insert(pieces, {"Seg" .. i, Vector3.new(s, s, s), CFrame.identity, i % 2 == 0 and dark or main, Enum.Material.Slate, Enum.PartType.Ball, "Seg" .. i})
	end
	table.insert(pieces, {"Head", Vector3.new(5.6, 5.6, 6.4) * u, CFrame.identity, main, Enum.Material.Slate, Enum.PartType.Ball, "HeadSeg"})
	table.insert(pieces, {"JawTop", Vector3.new(4.6, 1.2, 4) * u, CFrame.new(0, 1.3 * u, -2.8 * u), dark, Enum.Material.Slate, nil, "HeadSeg"})
	table.insert(pieces, {"JawBottom", Vector3.new(4.2, 1.1, 3.6) * u, CFrame.new(0, -1.5 * u, -2.6 * u), dark, Enum.Material.Slate, nil, "HeadSeg"})
	table.insert(pieces, {"Maw", Vector3.new(3.4, 1.6, 0.4) * u, CFrame.new(0, -0.1 * u, -3.4 * u), glow, Enum.Material.Neon, nil, "HeadSeg"})
	table.insert(pieces, {"EyeL", Vector3.new(0.9, 0.9, 0.4) * u, CFrame.new(-1.6 * u, 1.4 * u, -2.4 * u), glow, Enum.Material.Neon, nil, "HeadSeg"})
	table.insert(pieces, {"EyeR", Vector3.new(0.9, 0.9, 0.4) * u, CFrame.new(1.6 * u, 1.4 * u, -2.4 * u), glow, Enum.Material.Neon, nil, "HeadSeg"})
	return pieces, {}
end

local bodies = {} -- hitbox model -> body
local function build(model)
	local kind = model:GetAttribute("Body")
	local hitbox = model:FindFirstChild("Hitbox")
	if not hitbox or bodies[model] then return end
	local main, dark, glow = model:GetAttribute("Main"), model:GetAttribute("Dark"), model:GetAttribute("Glow")
	main = typeof(main) == "Color3" and main or Color3.fromRGB(150, 150, 160)
	dark = typeof(dark) == "Color3" and dark or Color3.fromRGB(90, 90, 100)
	glow = typeof(glow) == "Color3" and glow or Color3.fromRGB(120, 230, 255)
	local h = hitbox.Size.Y
	local pieces, joints
	if kind == "Yeti" then pieces, joints = yeti(h, main, dark, glow)
	elseif kind == "Worm" then pieces, joints = worm(h, main, dark, glow)
	else pieces, joints = golem(h, main, dark, glow) end
	local visual = Instance.new("Model")
	visual.Name = "Boss_" .. tostring(model:GetAttribute("Boss"))
	local list = {}
	for _, spec in ipairs(pieces) do
		local p = part(visual, spec[1], {Size = spec[2], Color = spec[4], Material = spec[5], CastShadow = spec[5] ~= Enum.Material.Neon})
		if spec[6] then p.Shape = spec[6] end
		table.insert(list, {Part = p, Offset = spec[3], Joint = spec[7], Glow = spec[5] == Enum.Material.Neon})
	end
	local glowLight = Instance.new("PointLight")
	glowLight.Color = glow; glowLight.Range = h * 1.4; glowLight.Brightness = 1.5; glowLight.Shadows = false
	glowLight.Parent = visual:FindFirstChild("Head") or list[1].Part
	visual.Parent = folder
	local body = {Model = model, Hitbox = hitbox, Visual = visual, Pieces = list, Joints = joints, Kind = kind, Height = h, Glow = glow,
		CF = hitbox.CFrame * CFrame.new(0, -h / 2, 0), Speed = 0, Clock = math.random() * 10, Flash = 0, Light = glowLight, Rise = os.clock()}
	bodies[model] = body
	return body
end

-- ---------------------------------------------------------------- per frame
local function lerp(a, b, t) return a + (b - a) * t end
local function act(body)
	local name = body.Model:GetAttribute("Act") or ""
	local at = body.Model:GetAttribute("ActAt") or 0
	return name, workspace:GetServerTimeNow() - at
end
local function poseHumanoid(body, base, t, dt)
	local name, since = act(body)
	local walk = math.clamp(body.Speed / 12, 0, 1)
	local swing = math.sin(t * 6) * 0.6 * walk
	local arms = {ArmL = CFrame.Angles(swing, 0, 0), ArmR = CFrame.Angles(-swing, 0, 0)}
	local legs = {LegL = CFrame.Angles(-swing, 0, 0), LegR = CFrame.Angles(swing, 0, 0)}
	local bodyTilt = CFrame.Angles(math.sin(t * 2) * 0.03, 0, 0)
	local head = CFrame.Angles(0, math.sin(t * 0.8) * 0.2, 0)
	local lift = 0
	if name == "Slam" and since < 1.8 then
		-- both arms up (wind-up), then down on the ground at 1.3 s
		local up = since < 1.3 and math.min(1, since / 0.9) or math.max(0, 1 - (since - 1.3) / 0.2)
		arms.ArmL = CFrame.Angles(-math.pi * 0.95 * up, 0, -0.2 * up); arms.ArmR = CFrame.Angles(-math.pi * 0.95 * up, 0, 0.2 * up)
		bodyTilt = CFrame.Angles(-0.25 * up + (since > 1.3 and 0.35 * (1 - math.min(1, (since - 1.3) / 0.4)) or 0), 0, 0)
	elseif name == "Throw" and since < 1.2 then
		local wind = since < 0.6 and since / 0.6 or math.max(0, 1 - (since - 0.6) / 0.2)
		arms.ArmR = CFrame.Angles(-math.pi * 0.9 * wind - (since > 0.6 and 0.8 or 0), 0, 0)
	elseif name == "Roar" and since < 1.4 then
		head = CFrame.Angles(-0.4, 0, 0) * CFrame.Angles(0, 0, math.sin(t * 40) * 0.05)
		arms.ArmL = CFrame.Angles(0, 0, -1.2); arms.ArmR = CFrame.Angles(0, 0, 1.2)
	elseif name == "Leap" and since < 1.6 then
		local delay = 1.4
		local u = math.clamp(since / delay, 0, 1)
		local from, to = body.LeapFrom, body.LeapTo
		if from and to then
			local p = from:Lerp(to, u) + Vector3.new(0, math.sin(u * math.pi) * 26, 0)
			base = CFrame.new(p) * (base - base.Position)
		end
		arms.ArmL = CFrame.Angles(-2.6, 0, 0); arms.ArmR = CFrame.Angles(-2.6, 0, 0)
	elseif name == "Die" then
		local u = math.clamp(since / 1.2, 0, 1)
		bodyTilt = CFrame.Angles(-math.pi / 2 * u, 0, 0)
		lift = -u * 2
	elseif name == "Rise" and since < 2.5 then
		lift = -(1 - math.clamp(since / 2.2, 0, 1)) * body.Height
	elseif name == "Leave" then
		lift = -math.clamp(since / 2, 0, 1) * body.Height
	end
	base = base * CFrame.new(0, lift, 0)
	local J = body.Joints
	for _, piece in ipairs(body.Pieces) do
		local joint = piece.Joint
		local cf
		if joint == "ArmL" or joint == "ArmR" then
			local pivot = J[joint]
			cf = base * bodyTilt * pivot * arms[joint] * pivot:Inverse() * piece.Offset
		elseif joint == "LegL" or joint == "LegR" then
			local pivot = J[joint]
			cf = base * pivot * legs[joint] * pivot:Inverse() * piece.Offset
		elseif joint == "Head" then
			local pivot = J.Head
			cf = base * bodyTilt * pivot * head * pivot:Inverse() * piece.Offset
		else
			cf = base * bodyTilt * piece.Offset
		end
		piece.Part.CFrame = cf
	end
end
local function poseWorm(body, base, t)
	local name, since = act(body)
	local h = body.Height
	local depth = 0 -- how far it is down in the ground (0..1)
	if name == "Burrow" then
		if since < 0.6 then depth = since / 0.6
		elseif since < 1.8 then depth = 1
		else depth = math.max(0, 1 - (since - 1.8) / 0.4) end
		if since >= 1.8 and body.BurstAt then base = CFrame.new(body.BurstAt) * (base - base.Position) end
	elseif name == "Rise" and since < 2.5 then depth = 1 - math.clamp(since / 2.2, 0, 1)
	elseif name == "Leave" then depth = math.clamp(since / 2, 0, 1)
	elseif name == "Die" then depth = math.clamp(since / 1.8, 0, 1) * 0.8 end
	local rear = name == "Slam" and since < 1.6 and math.sin(math.clamp(since / 1.3, 0, 1) * math.pi * 0.5) or 0
	local segs = {}
	for _, piece in ipairs(body.Pieces) do
		local i = tonumber(string.match(piece.Joint, "^Seg(%d+)$"))
		if i then segs[i] = piece end
	end
	-- the body rises out of the ground in an S curve; the head on top looks forward (down when it slams)
	local n = 8
	local prev
	for i = 1, n + 1 do
		local u = (i - 1) / n
		local y = (u * h * 0.95 - depth * h * 1.1)
		local sway = math.sin(t * 2.2 - u * 3) * (1 - depth) * h * 0.08
		local fwd = -math.sin(u * math.pi * 0.5) * h * 0.25 * (1 + rear * 0.8)
		local pos = base * CFrame.new(sway, y, fwd)
		if i <= n then
			local piece = segs[i]
			if piece then piece.Part.CFrame = pos end
		else
			local head = pos * CFrame.Angles(-0.3 * rear + math.sin(t * 1.5) * 0.08, math.sin(t * 0.9) * 0.2, 0)
			for _, piece in ipairs(body.Pieces) do
				if piece.Joint == "HeadSeg" then piece.Part.CFrame = head * piece.Offset end
			end
		end
		prev = pos
	end
	-- (hidden below the ground: invisible)
	local hidden = depth >= 0.98
	for _, piece in ipairs(body.Pieces) do piece.Part.LocalTransparencyModifier = hidden and 1 or 0 end
	local _ = prev
end

RunService.RenderStepped:Connect(function(dt)
	for model, body in pairs(bodies) do
		if not model.Parent then
			body.Visual:Destroy(); bodies[model] = nil
		else
			-- only drawn on its own planet (the planets are far apart, but not out of sight)
			local here = player:GetAttribute("PFESpectateWorld") or player:GetAttribute("PFETrackerPlanet")
			local show = here == model:GetAttribute("Planet") and player:GetAttribute("PFECave") == nil
			body.Visual.Parent = show and folder or nil
			body.Clock += dt
			local target = body.Hitbox.CFrame * CFrame.new(0, -body.Height / 2, 0)
			local before = body.CF.Position
			body.CF = body.CF:Lerp(target, math.min(1, dt * 8))
			body.Speed = lerp(body.Speed, (body.CF.Position - before).Magnitude / math.max(dt, 1 / 240), math.min(1, dt * 6))
			local base = body.CF
			if body.Kind == "Worm" then poseWorm(body, base, body.Clock) else poseHumanoid(body, base, body.Clock, dt) end
			-- hit flash / angry glow
			body.Flash = math.max(0, body.Flash - dt * 4)
			local angry = model:GetAttribute("Angry") == true
			for _, piece in ipairs(body.Pieces) do
				if piece.Glow then piece.Part.Color = body.Glow:Lerp(Color3.fromRGB(255, 40, 40), angry and (0.5 + 0.5 * math.sin(body.Clock * 8)) or 0) end
			end
			body.Light.Brightness = (angry and 3 or 1.5) + body.Flash * 4
			body.Light.Color = angry and Color3.fromRGB(255, 70, 50) or body.Glow
		end
	end
end)

local function watch(model)
	if not model:IsA("Model") then return end
	task.defer(function()
		if not model:FindFirstChild("Hitbox") then model:WaitForChild("Hitbox", 5) end
		local body = build(model)
		if body then sound(S.BossGrowl, model.Hitbox.Position, 1, 0.8) end
	end)
end
for _, m in ipairs(CollectionService:GetTagged("PFEBoss")) do watch(m) end
CollectionService:GetInstanceAddedSignal("PFEBoss"):Connect(watch)

-- ---------------------------------------------------------------- the health bar and the splashes
local gui = Instance.new("ScreenGui")
gui.Name = "PFE_Boss"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = false; gui.DisplayOrder = 22
gui.Parent = player:WaitForChild("PlayerGui")
local holder = UI.new("Frame", {Name = "BossBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(460, 62),
	BackgroundTransparency = 1, Visible = false}, gui)
local barScale = UI.new("UIScale", {}, holder)
local title = UI.text(holder, "", UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 0), 28, Color3.fromRGB(255, 120, 90))
title.TextXAlignment = Enum.TextXAlignment.Center; title.TextWrapped = false
local track, setBar, fill = UI.bar(holder, UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 32), C.Red)
local hpText = UI.text(track, "", UDim2.fromScale(1, 1), nil, 16)
hpText.TextXAlignment = Enum.TextXAlignment.Center; hpText.ZIndex = 9
local _ = fill

local function layout()
	local camera = workspace.CurrentCamera
	if not camera then return end
	barScale.Scale = math.clamp(UI.scaleFor(camera.ViewportSize), UI.minScale(), 1.1)
	-- under the planet name / air bar on a planet
	holder.Position = UDim2.new(0.5, 0, 0, (UI.isTouch() and 300 or 320) * barScale.Scale)   -- (below the toasts)
end
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
layout()

local shownRatio = -1
RunService.Heartbeat:Connect(function()
	local current
	for model in pairs(bodies) do if model.Parent and not model:GetAttribute("Dead") then current = model end end
	local mine = player:GetAttribute("PFESpectateWorld") or nil
	local visible = current ~= nil and player:GetAttribute("PFEFlightActive") ~= true and player:GetAttribute("PFEPlanetMapOpen") ~= true
		and player:GetAttribute("PFECave") == nil and player:GetAttribute("PFEDungeon") == nil
	if visible then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		visible = root ~= nil and (root.Position - current.Hitbox.Position).Magnitude < 1500
	end
	local _ = mine
	holder.Visible = visible
	if not visible then return end
	local hp, max = current:GetAttribute("HP") or 0, current:GetAttribute("MaxHP") or 1
	local left = math.max(0, (workspace:GetAttribute("PFEBossEndsAt") or 0) - workspace:GetServerTimeNow())
	title.Text = string.upper(tostring(current:GetAttribute("Boss"))) .. string.format("  %d:%02d", left // 60, left % 60)
	local ratio = math.clamp(hp / math.max(1, max), 0, 1)
	if math.abs(ratio - shownRatio) > 0.001 then
		shownRatio = ratio
		setBar(ratio, current:GetAttribute("Angry") and C.Orange or C.Red)
		hpText.Text = Config.Format(math.ceil(hp)) .. " / " .. Config.Format(max)
	end
end)

local splash = UI.text(gui, "", UDim2.new(1, -40, 0, 64), UDim2.new(0, 20, 0.2, 0), 52, Color3.fromRGB(255, 90, 70))
splash.Name = "BossSplash"; splash.TextXAlignment = Enum.TextXAlignment.Center; splash.TextTransparency = 1; splash.TextScaled = true
UI.new("UITextSizeConstraint", {MaxTextSize = 52, MinTextSize = 20}, splash)
local splashSub = UI.text(gui, "", UDim2.new(1, -40, 0, 30), UDim2.new(0, 20, 0.2, 64), 24, C.White)
splashSub.TextXAlignment = Enum.TextXAlignment.Center; splashSub.TextTransparency = 1; splashSub.TextScaled = true
UI.new("UITextSizeConstraint", {MaxTextSize = 24, MinTextSize = 12}, splashSub)
local splashToken = 0
local function showSplash(text, sub, color, seconds)
	splashToken += 1
	local token = splashToken
	splash.Text = text; splash.TextColor3 = color; splashSub.Text = sub or ""
	for _, l in ipairs({splash, splashSub}) do
		l.TextTransparency = 0
		local s = l:FindFirstChildOfClass("UIStroke"); if s then s.Transparency = 0 end
	end
	local pop = splash:FindFirstChildOfClass("UIScale") or UI.new("UIScale", {}, splash)
	pop.Scale = 0.3; UI.tween(pop, {Scale = 1}, 0.35, Enum.EasingStyle.Back)
	task.delay(seconds or 3, function()
		if token ~= splashToken then return end
		for _, l in ipairs({splash, splashSub}) do
			UI.tween(l, {TextTransparency = 1}, 0.4)
			local s = l:FindFirstChildOfClass("UIStroke"); if s then UI.tween(s, {Transparency = 1}, 0.4) end
		end
	end)
end
local function play2D(id, volume, speed)
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = volume or 0.6; s.PlaybackSpeed = speed or 1; s.Parent = SoundService
	s:Play(); Debris:AddItem(s, 8)
end

api:WaitForChild("Effect").OnClientEvent:Connect(function(kind, payload)
	if type(payload) ~= "table" then payload = {} end
	if kind == "BossSpawn" then
		if player:GetAttribute("PFECutscene") then return end
		showSplash("BOSS: " .. string.upper(tostring(payload.Name)), "woke up on " .. tostring(payload.PlanetName) .. " - fight it, eggs rain when it falls!", Color3.fromRGB(255, 90, 70), 4)
		play2D(S.HorrorSting, 0.5, 1)
	elseif kind == "BossAct" then
		for model, body in pairs(bodies) do
			if payload.Act == "Leap" then body.LeapFrom = typeof(payload.From) == "Vector3" and payload.From or body.CF.Position; body.LeapTo = payload.To end
			if payload.Act == "Burrow" then body.BurstAt = payload.To; sound(S.RockCrumble, body.CF.Position, 0.9, 0.9) end
			if payload.Act == "Slam" or payload.Act == "Roar" then sound(S.BossGrowl, body.CF.Position, 0.9, payload.Act == "Roar" and 0.7 or 1) end
			if payload.Act == "Die" then sound(S.BossLaugh, body.CF.Position, 0.8, 0.6) end
			local _ = model
		end
	elseif kind == "BossHit" then
		for _, body in pairs(bodies) do body.Flash = 1 end
	elseif kind == "BossAngry" then
		showSplash(string.upper(tostring(payload.Name)) .. " IS ANGRY!", "It's faster now - keep hitting!", Color3.fromRGB(255, 120, 40), 2.2)
	elseif kind == "BossReward" then
		local coins = Config.Format(tonumber(payload.Coins) or 0)
		showSplash("BOSS DEFEATED!", "+" .. coins .. " coins  -  you were #" .. tostring(payload.Rank) .. " of " .. tostring(payload.Fighters) .. " fighters", C.Gold, 4)
		play2D(S.Jackpot, 0.6, 1)
		play2D(S.Cheer, 0.5, 1)
	end
end)
