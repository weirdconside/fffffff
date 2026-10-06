--!nocheck
-- Flight cinematic (client only). Short and punchy:
--   0.0 - 3.0  ignition and lift-off from the real pad, smoke, camera shake
--   ~3.0       flash as the rocket breaks through the sky; lighting becomes deep space
--   3.0 - D    the rocket cruises through a real star field towards the destination
--              (a photographic planet that grows ahead), warp streaks, white-out
--   D - D+L    landing shot at the destination pad, dust, back to the player
-- The server teleports the character at D (info.Duration); landing plays during L.
-- hooks.Space() is called at the sky break (switch to space lighting) and hooks.Arrive()
-- right before the landing shot (switch to the destination's lighting).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UI = require(script.Parent:WaitForChild("UIKit"))
local Config = require(script.Parent:WaitForChild("Config"))
local C = UI.C
local player = Players.LocalPlayer
local M = {}
local active

local SPACE_ORIGIN = Vector3.new(0, 40000, 0)
local LIFT_END = 3.0

local function smooth(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end
local function new(class, props, parent) return UI.new(class, props, parent) end
local function asset(id) return "rbxassetid://" .. tostring(id) end

function M.Cancel() if active then active() end end

local function part(parent, props)
	local p = new("Part", {Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2)}, nil)
	for k, v in pairs(props or {}) do p[k] = v end
	p.Parent = parent
	return p
end

-- engine rig: a compact flame on anchor parts that follow a rocket. The particles are locked
-- to the nozzle so a fast rocket never leaves a glowing streak behind it.
local function engines(folder, count, scale)
	local nodes = {}
	for i = 1, count do
		local p = part(folder, {Name = "Engine" .. i})
		local a0 = new("Attachment", {}, p)
		local flame = new("ParticleEmitter", {Texture = "rbxasset://textures/particles/fire_main.dds", EmissionDirection = Enum.NormalId.Bottom,
			Rate = 110, Lifetime = NumberRange.new(0.1, 0.22), Speed = NumberRange.new(24 * scale, 40 * scale), SpreadAngle = Vector2.new(6, 6),
			LightEmission = 1, LightInfluence = 0, LockedToPart = true, Color = ColorSequence.new(Color3.fromRGB(255, 244, 170), Color3.fromRGB(255, 96, 24)),
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2.4 * scale), NumberSequenceKeypoint.new(0.5, 3.2 * scale), NumberSequenceKeypoint.new(1, 0)}),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1)}),
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-80, 80), Enabled = false}, a0)
		local core = new("ParticleEmitter", {Texture = "rbxasset://textures/particles/sparkles_main.dds", EmissionDirection = Enum.NormalId.Bottom,
			Rate = 60, Lifetime = NumberRange.new(0.06, 0.12), Speed = NumberRange.new(10 * scale, 16 * scale), SpreadAngle = Vector2.new(3, 3),
			LightEmission = 1, LightInfluence = 0, LockedToPart = true, Color = ColorSequence.new(Color3.fromRGB(215, 238, 255)),
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.6 * scale), NumberSequenceKeypoint.new(1, 0.4 * scale)}), Enabled = false}, a0)
		local light = new("PointLight", {Color = Color3.fromRGB(255, 170, 80), Brightness = 0, Range = 40, Shadows = false}, p)
		table.insert(nodes, {Part = p, Flame = flame, Core = core, Light = light})
	end
	return nodes
end
local function setEngines(nodes, on, power, t)
	for _, n in ipairs(nodes) do
		n.Flame.Enabled = on; n.Core.Enabled = on
		n.Flame.Rate = 50 + 80 * power
		n.Light.Brightness = on and power * (2 + math.sin(t * 37) * 0.3) or 0
	end
end

-- a rocket's visible box: centre frame, size, and where the pivot sits relative to it
local function boxOf(model)
	local cf, size = model:GetBoundingBox()
	return CFrame.new(cf.Position), size, CFrame.new(cf.Position):ToObjectSpace(model:GetPivot())
end

local function play(rocket, info, landingRocket, hooks)
	hooks = hooks or {}
	local camera = workspace.CurrentCamera
	if not camera or not rocket or not rocket.Parent then return end
	local duration = math.max(4, tonumber(info.Duration) or Config.FlightDuration)
	local landingTime = tonumber(info.Landing) or Config.LandingDuration
	local startPivot = rocket:GetPivot()
	local box, size = boxOf(rocket)
	-- rockets stand on their pads with different yaws; in space they all fly with their front
	-- (look vector) towards the chase camera, so none of them ends up belly-up
	local boxLocal = startPivot:PointToObjectSpace(box.Position)
	local CANON = CFrame.fromMatrix(Vector3.zero, Vector3.zAxis, Vector3.yAxis)
	local scale = math.clamp(size.Y / 64, 0.4, 2)
	local oldFov = camera.FieldOfView
	local character = player.Character
	local hidden = {}
	local function hide(item)
		if hidden[item] then return end
		if item:IsA("BasePart") then hidden[item] = {"LocalTransparencyModifier", item.LocalTransparencyModifier}; item.LocalTransparencyModifier = 1
		elseif item:IsA("Decal") or item:IsA("Texture") then hidden[item] = {"Transparency", item.Transparency}; item.Transparency = 1
		elseif item:IsA("ParticleEmitter") or item:IsA("Trail") or item:IsA("Beam") or item:IsA("BillboardGui") then hidden[item] = {"Enabled", item.Enabled}; item.Enabled = false end
	end
	local hideConn
	if character then
		for _, d in ipairs(character:GetDescendants()) do hide(d) end
		hideConn = character.DescendantAdded:Connect(hide)
	end
	local folder = new("Folder", {Name = "FlightEffects"}, workspace)
	local screen = new("ScreenGui", {Name = "FlightCinema", IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None, ClipToDeviceSafeArea = false, ResetOnSpawn = false, DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
	-- the letterbox covers the whole physical screen (phones: past notches and rounded corners)
	pcall(function() screen.ScreenInsets = Enum.ScreenInsets.None end)
	pcall(function() screen.ClipToDeviceSafeArea = false end)
	local sounds = {}
	local connection, charConn
	local cleaned, spaceBuilt, arrived, landed = false, false, false, false
	local spaceHooked, arriveHooked = false, false
	local landingStart
	local cleanup
	cleanup = function()
		if cleaned then return end
		cleaned = true
		if connection then connection:Disconnect() end
		if charConn then charConn:Disconnect() end
		if hideConn then hideConn:Disconnect() end
		for item, rec in pairs(hidden) do if item.Parent then pcall(function() item[rec[1]] = rec[2] end) end end
		if rocket.Parent then pcall(function() rocket:PivotTo(startPivot) end) end
		if landingRocket and landingRocket.Parent and landingRocket:GetAttribute("PFELandingPivot") then
			pcall(function() landingRocket:PivotTo(landingRocket:GetAttribute("PFELandingPivot")) end)
			landingRocket:SetAttribute("PFELandingPivot", nil)
		end
		for _, s in ipairs(sounds) do s:Stop(); s:Destroy() end
		folder:Destroy(); screen:Destroy()
		if camera.Parent then
			camera.CameraType = Enum.CameraType.Custom
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then camera.CameraSubject = humanoid end
			camera.FieldOfView = oldFov
		end
		player:SetAttribute("PFEFlightActive", false)
		if active == cleanup then active = nil end
	end
	active = cleanup
	charConn = player.CharacterAdded:Connect(cleanup)

	-- ---------------------------------------------------------------- screen
	-- bars wider than the screen and overlapping its edges, so no sliver of the scene shows at any
	-- aspect ratio; they slide in from off-screen
	local top = new("Frame", {Name = "Top", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(1.2, 0, 0.09, 8), Position = UDim2.new(0.5, 0, 0, 0), ZIndex = 10}, screen)
	local bottom = new("Frame", {Name = "Bottom", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(1.2, 0, 0.1, 8), Position = UDim2.new(0.5, 0, 1, 0), ZIndex = 10}, screen)
	UI.tween(top, {Position = UDim2.new(0.5, 0, 0.08, 0)}, 0.5, Enum.EasingStyle.Quart)
	UI.tween(bottom, {Position = UDim2.new(0.5, 0, 0.91, 0)}, 0.5, Enum.EasingStyle.Quart)
	local dest = Config.Planets[info.Destination]
	local destName = info.Destination == "Base" and "EARTH" or string.upper(dest and dest.Name or tostring(info.Destination))
	local title = UI.text(screen, destName, UDim2.fromOffset(700, 70), UDim2.new(0.5, -350, 0.74, 0), 58)
	title.TextXAlignment = Enum.TextXAlignment.Center; title.TextWrapped = false; title.ZIndex = 12; title.TextTransparency = 1
	local titleStroke = title:FindFirstChildOfClass("UIStroke"); if titleStroke then titleStroke.Transparency = 1 end
	local subtitle = UI.text(screen, info.GalaxyJump and "HYPERSPACE JUMP" or (dest and Config.Galaxies[dest.Galaxy].Name or "Milky Way"),
		UDim2.fromOffset(700, 30), UDim2.new(0.5, -350, 0.74, 66), 24, C.Soft)
	subtitle.TextXAlignment = Enum.TextXAlignment.Center; subtitle.ZIndex = 12; subtitle.TextTransparency = 1
	-- the destination title fits narrow phone screens too
	local viewportWidth = camera.ViewportSize.X
	local fit = math.clamp((viewportWidth - 40) / 760, 0.45, 1)
	for _, label in ipairs({title, subtitle}) do
		local scale = Instance.new("UIScale"); scale.Scale = fit; scale.Parent = label
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(0.5, 0, label.Position.Y.Scale, label.Position.Y.Offset * fit)
	end
	local subStroke = subtitle:FindFirstChildOfClass("UIStroke"); if subStroke then subStroke.Transparency = 1 end
	local flash = new("Frame", {Name = "Flash", BackgroundColor3 = Color3.fromRGB(255, 250, 240), BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = 20}, screen)
	local fade = new("Frame", {Name = "Fade", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = 21}, screen)
	local streakLayer = new("Frame", {Name = "Warp", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 8}, screen)
	local streaks = {}
	local galaxy = dest and Config.Galaxies[dest.Galaxy] or Config.Galaxies.MilkyWay
	for i = 1, 36 do
		local line = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundColor3 = i % 3 == 0 and galaxy.Color:Lerp(C.White, 0.4) or C.White,
			BackgroundTransparency = 1, Size = UDim2.fromOffset(40, i % 3 == 0 and 3 or 2), ZIndex = 8}, streakLayer)
		new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.7, 0.1), NumberSequenceKeypoint.new(1, 1)})}, line)
		table.insert(streaks, {line = line, angle = i * 2.399963, phase = (i * 0.618034) % 1})
	end

	-- ---------------------------------------------------------------- sound
	local function sound(name, file, volume, speed, looped)
		-- the rocket is silent: its flight has the music only (Music.client). The sound objects stay (the
		-- cinema still tweens them) but are never put anywhere they could be heard.
		local s = new("Sound", {Name = name, SoundId = "rbxasset://sounds/" .. file, Volume = 0, PlaybackSpeed = speed or 1, Looped = looped or false})
		s:SetAttribute("PFEMute", true)
		table.insert(sounds, s)
		return s
	end
	local ignition = sound("Ignition", "impact_explosion_03.mp3", 0.45, 0.62)
	local rumble = sound("Rumble", "action_falling.ogg", 0, 0.48, true)
	new("EqualizerSoundEffect", {LowGain = 8, MidGain = -2, HighGain = -10}, rumble)
	local whoosh = sound("Whoosh", "action_falling.ogg", 0, 1.35, true)
	new("EqualizerSoundEffect", {LowGain = -6, MidGain = 0, HighGain = 3}, whoosh)
	local boom = sound("Break", "impact_water.mp3", 0.5, 0.55)
	local land = sound("Touchdown", "impact_explosion_03.mp3", 0.3, 1.1)

	-- ---------------------------------------------------------------- pad effects
	local padNodes = engines(folder, 3, scale)
	local nozzle = {Vector3.new(-size.X * 0.16, -size.Y / 2 + 1, 0), Vector3.new(size.X * 0.16, -size.Y / 2 + 1, 0), Vector3.new(0, -size.Y / 2 + 1, size.Z * 0.12)}
	local ground = part(folder, {Name = "Dust", CFrame = CFrame.new(box.Position - Vector3.new(0, size.Y / 2 - 1, 0))})
	local smoke = new("ParticleEmitter", {Texture = "rbxasset://textures/particles/smoke_main.dds", EmissionDirection = Enum.NormalId.Top,
		Rate = 0, Lifetime = NumberRange.new(2, 3.4), Speed = NumberRange.new(16, 36), SpreadAngle = Vector2.new(85, 85),
		Color = ColorSequence.new(Color3.fromRGB(235, 232, 225), Color3.fromRGB(150, 146, 150)),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 5 * scale), NumberSequenceKeypoint.new(0.5, 16 * scale), NumberSequenceKeypoint.new(1, 26 * scale)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.6, 0.7), NumberSequenceKeypoint.new(1, 1)}),
		Acceleration = Vector3.new(0, -4, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-25, 25), Drag = 1.2}, ground)

	-- ---------------------------------------------------------------- space scene (built at the sky break)
	local space = {}
	local travel = Vector3.new(0, 0.12, -1).Unit
	local function buildSpace()
		spaceBuilt = true
		local clone = rocket:Clone()
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CastShadow = true; d.LocalTransparencyModifier = 0
			elseif d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") then d:Destroy() end
		end
		clone.Parent = folder
		space.Rocket = clone
		space.Nodes = engines(folder, 3, scale * 1.15)
		-- destination: a photographic planet far ahead
		local art = Config.MapArt[info.Destination == "Base" and "Earth" or info.Destination]
		local anchor = part(folder, {Name = "Destination", CFrame = CFrame.new(SPACE_ORIGIN + travel * 6500 + Vector3.new(900, -700, 0))})
		local billboard = new("BillboardGui", {Name = "Planet", Size = UDim2.fromScale(2600, 2600), LightInfluence = 0, AlwaysOnTop = false,
			MaxDistance = 100000, Adornee = anchor}, anchor)
		local glow = new("ImageLabel", {Name = "Glow", BackgroundTransparency = 1, Image = UI.Icons.Sunburst, ImageColor3 = dest and dest.Accent or Color3.fromRGB(120, 190, 255),
			ImageTransparency = 0.75, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.5, 1.5)}, billboard)
		local image = new("ImageLabel", {Name = "Art", BackgroundTransparency = 1, Image = art and asset(art.Image) or "", ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(art and art.Wide and 1.4 or 1, art and art.Wide and 1.4 or 1)}, billboard)
		if art and art.Rect then image.ImageRectOffset = Vector2.new(art.Rect[1], art.Rect[2]); image.ImageRectSize = Vector2.new(art.Rect[3], art.Rect[4]) end
		space.Planet, space.Glow = billboard, glow
		-- star dust rushing past (velocity-stretched sparkles)
		local dust = part(folder, {Name = "StarDust", Size = Vector3.new(300, 180, 10)})
		local stars = new("ParticleEmitter", {Texture = "rbxasset://textures/particles/sparkles_main.dds", EmissionDirection = Enum.NormalId.Back,
			Shape = Enum.ParticleEmitterShape.Box, Rate = 140, Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(260, 380),
			Size = NumberSequence.new(0.5, 0.2), Squash = NumberSequence.new(-4), Orientation = Enum.ParticleOrientation.VelocityParallel,
			LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(Color3.fromRGB(220, 232, 255))}, dust)
		space.Dust, space.Stars = dust, stars
	end
	local function spaceRocketFrame(elapsed)
		local u = elapsed - LIFT_END
		local dist = 60 * u + 70 * u * u
		local pos = SPACE_ORIGIN + travel * dist
		return CFrame.fromMatrix(pos, Vector3.xAxis, travel)
	end

	-- ---------------------------------------------------------------- main loop
	player:SetAttribute("PFEFlightActive", true)
	camera.CameraType = Enum.CameraType.Scriptable
	rumble:Play()
	local begin = os.clock()
	local lit = false
	local function update()
		if cleaned then return end
		if player.Character ~= character or workspace.CurrentCamera ~= camera then cleanup(); return end
		local t = os.clock() - begin
		-- ---------------- phase A: lift-off
		if t < LIFT_END then
			if t > 0.35 and not lit then
				lit = true; ignition:Play(); smoke.Rate = 120; smoke:Emit(40)
				flash.BackgroundTransparency = 0.82; UI.tween(flash, {BackgroundTransparency = 1}, 0.4)
			end
			local power = smooth((t - 0.35) / 0.5)
			local u = math.clamp((t - 0.6) / (LIFT_END - 0.6), 0, 1)
			local height = 720 * u ^ 2.3
			if rocket.Parent then rocket:PivotTo(startPivot + Vector3.new(0, height, 0)) end
			local c = box.Position + Vector3.new(0, height, 0)
			for i, n in ipairs(padNodes) do n.Part.CFrame = CFrame.new(c + nozzle[i]) end
			setEngines(padNodes, lit, power, t)
			if t > 1.4 then smoke.Rate = 40 end
			-- camera: low 3/4 shot, then chasing the rocket upwards
			local base = startPivot.Position
			local side = startPivot.RightVector
			local back = -startPivot.LookVector
			local camPos = base + side * (48 * scale) + back * (-92 * scale) + Vector3.new(0, 10 * scale + height * 0.62, 0)
			local focus = c + Vector3.new(0, size.Y * 0.2, 0)
			local shake = lit and (0.35 * (1 - u) + 0.08) * scale or 0.02
			camera.CFrame = CFrame.lookAt(camPos, focus) * CFrame.new(math.noise(t * 23, 1) * shake, math.noise(2, t * 29) * shake, 0)
			camera.FieldOfView = 52 + 22 * smooth(u)
			rumble.Volume = 0.05 + power * 0.4
			whoosh.Volume = smooth(u) * 0.3
			if t > LIFT_END - 0.45 then flash.BackgroundTransparency = 1 - smooth((t - (LIFT_END - 0.45)) / 0.45) end
			return
		end
		-- ---------------- sky break: switch to space
		if not spaceHooked then
			spaceHooked = true
			boom:Play()
			smoke.Enabled = false; setEngines(padNodes, false, 0, t)
			if rocket.Parent then rocket:PivotTo(startPivot) end
			if hooks.Space then local ok, e = pcall(hooks.Space); if not ok then warn("[PFE] flight space hook: " .. tostring(e)) end end
			buildSpace()
			UI.tween(flash, {BackgroundTransparency = 1}, 0.6)
			UI.tween(title, {TextTransparency = 0}, 0.5); UI.tween(subtitle, {TextTransparency = 0}, 0.5)
			if titleStroke then UI.tween(titleStroke, {Transparency = 0}, 0.5) end
			if subStroke then UI.tween(subStroke, {Transparency = 0}, 0.5) end
		end
		-- ---------------- phase B: space cruise
		if t < duration then
			local frame = spaceRocketFrame(t)
			if space.Rocket then
				local rot = (frame - frame.Position) * CANON
				space.Rocket:PivotTo(CFrame.new(frame.Position - rot:VectorToWorldSpace(boxLocal)) * rot)
			end
			local u = (t - LIFT_END) / math.max(0.5, duration - LIFT_END)
			for i, n in ipairs(space.Nodes) do n.Part.CFrame = CFrame.fromMatrix((frame * CFrame.new(nozzle[i])).Position, Vector3.xAxis, travel) end
			setEngines(space.Nodes, true, 1, t)
			-- chase camera swinging from the side to behind the rocket
			local swing = math.rad(78 - 58 * smooth(u))
			local right, up = Vector3.xAxis, Vector3.yAxis
			local behind = -travel
			local offset = (right * math.sin(swing) + behind * math.cos(swing)) * (size.Y * 1.25) + up * (size.Y * 0.28)
			local focus = frame.Position + travel * (size.Y * 0.9 + 60 * u)
			local shake = 0.05 + 0.25 * smooth((u - 0.7) / 0.3)
			camera.CFrame = CFrame.lookAt(frame.Position + offset, focus) * CFrame.new(math.noise(t * 17, 3) * shake, math.noise(4, t * 19) * shake, 0)
			camera.FieldOfView = 70 + 14 * smooth((u - 0.6) / 0.4)
			space.Dust.CFrame = CFrame.lookAt(camera.CFrame.Position + camera.CFrame.LookVector * 220, camera.CFrame.Position)
			space.Stars.Rate = 100 + 500 * smooth((u - 0.5) / 0.5)
			space.Planet.Size = UDim2.fromScale(2600 + 2400 * smooth(u), 2600 + 2400 * smooth(u))
			space.Glow.Rotation = t * 6
			whoosh.Volume = 0.25 + 0.3 * u; rumble.Volume = 0.25
			-- warp streaks + white-out at the end
			local warp = smooth((t - (duration - 1.3)) / 1.0)
			local vp = camera.ViewportSize
			for _, s in ipairs(streaks) do
				local radius = 0.15 + ((t * (0.25 + warp * 0.9) + s.phase) % 1) * 1.1
				local dx, dy = math.cos(s.angle) * 0.72, math.sin(s.angle) * 0.66
				s.line.Position = UDim2.fromScale(0.5 + dx * radius, 0.47 + dy * radius)
				s.line.Rotation = math.deg(math.atan2(dy * vp.Y, dx * vp.X))
				s.line.Size = UDim2.fromOffset((30 + warp * 180) * radius, s.line.Size.Y.Offset)
				s.line.BackgroundTransparency = 1 - warp * 0.85 * math.clamp(radius - 0.2, 0, 1)
			end
			if t > duration - 0.9 and title.TextTransparency < 0.5 then
				UI.tween(title, {TextTransparency = 1}, 0.3); UI.tween(subtitle, {TextTransparency = 1}, 0.3)
				if titleStroke then UI.tween(titleStroke, {Transparency = 1}, 0.3) end
				if subStroke then UI.tween(subStroke, {Transparency = 1}, 0.3) end
			end
			if t > duration - 0.4 then flash.BackgroundTransparency = 1 - smooth((t - (duration - 0.4)) / 0.25) end
			if t > duration - 0.3 and not arriveHooked then
				arriveHooked = true
				if hooks.Arrive then local ok, e = pcall(hooks.Arrive); if not ok then warn("[PFE] flight arrive hook: " .. tostring(e)) end end
			end
			return
		end
		-- ---------------- phase C: landing
		if not arrived then
			arrived = true
			for _, child in ipairs(folder:GetChildren()) do if child ~= ground then child:Destroy() end end
			for _, s in ipairs(streaks) do s.line.BackgroundTransparency = 1 end
			whoosh.Volume = 0
			flash.BackgroundTransparency = 1; fade.BackgroundTransparency = 0
			UI.tween(fade, {BackgroundTransparency = 1}, 0.45)
			landingStart = t
			if landingRocket and landingRocket.Parent then
				landingRocket:SetAttribute("PFELandingPivot", landingRocket:GetPivot())
				space.LandBox, space.LandSize = boxOf(landingRocket)
				space.LandNodes = engines(folder, 3, math.clamp(space.LandSize.Y / 64, 0.4, 2))
				space.LandDust = part(folder, {Name = "LandDust", CFrame = CFrame.new(space.LandBox.Position - Vector3.new(0, space.LandSize.Y / 2 - 1, 0))})
				space.LandSmoke = smoke:Clone(); space.LandSmoke.Rate = 0; space.LandSmoke.Parent = space.LandDust
			end
		end
		local lt = t - landingStart
		local total = math.max(1, landingTime)
		local lr = landingRocket and landingRocket.Parent and landingRocket:GetAttribute("PFELandingPivot")
		if lr and space.LandBox then
			local touchdown = total * 0.72
			local u = math.clamp(lt / touchdown, 0, 1)
			local drop = 170 * (1 - u) ^ 2.2
			landingRocket:PivotTo(lr + Vector3.new(0, drop, 0))
			local c = space.LandBox.Position + Vector3.new(0, drop, 0)
			local nz = {Vector3.new(-space.LandSize.X * 0.16, -space.LandSize.Y / 2 + 1, 0), Vector3.new(space.LandSize.X * 0.16, -space.LandSize.Y / 2 + 1, 0),
				Vector3.new(0, -space.LandSize.Y / 2 + 1, space.LandSize.Z * 0.12)}
			for i, n in ipairs(space.LandNodes) do n.Part.CFrame = CFrame.new(c + nz[i]) end
			setEngines(space.LandNodes, u < 1, 0.35 + 0.65 * (1 - u), t)
			if u > 0.55 then space.LandSmoke.Rate = 90 end
			if u >= 1 and not landed then
				landed = true; land:Play(); space.LandSmoke:Emit(30); space.LandSmoke.Rate = 0
			end
			local base = lr.Position
			local camPos = base + lr.RightVector * (70 * scale) + lr.LookVector * (-100 * scale) + Vector3.new(0, 26 * scale + drop * 0.35, 0)
			local shake = landed and 0.12 * math.exp(-(lt - touchdown) * 4) or 0.05
			camera.CFrame = CFrame.lookAt(camPos, c + Vector3.new(0, space.LandSize.Y * 0.1, 0)) * CFrame.new(math.noise(t * 21, 5) * shake, math.noise(6, t * 23) * shake, 0)
			camera.FieldOfView = 58
		end
		if lt > total - 0.45 and not landed then landed = true end
		if lt >= total then
			UI.tween(top, {Position = UDim2.new(0.5, 0, 0, 0)}, 0.3); UI.tween(bottom, {Position = UDim2.new(0.5, 0, 1, 0)}, 0.3)
			cleanup()
		end
	end
	connection = RunService.RenderStepped:Connect(function()
		local ok, message = xpcall(update, debug.traceback)
		if not ok then cleanup(); warn("[PFE] flight cinematic stopped safely: " .. tostring(message)) end
	end)
	task.delay(duration + landingTime + 3, function() if not cleaned then cleanup() end end)
end

function M.Play(rocket, info, landingRocket, hooks)
	M.Cancel()
	local ok, message = xpcall(function() play(rocket, info or {}, landingRocket, hooks) end, debug.traceback)
	if not ok then M.Cancel(); warn("[PFE] flight cinematic could not start: " .. tostring(message)) end
end

return M
