--!nocheck
-- (v38) The fusion show is a 3D VFX scene now (fusionShow3D below: an altar in the sky, the eggs on trails, the core,
-- the supernova); the 2D show further up stays as its fallback.
-- The fusion show (v28: Brawl Stars style - the better the result, the bigger the show) and the limited egg's arrival:
--  1. the three eggs fly in and circle a glowing core, faster and tighter, charging up (magic charge, rising
--     ticks, the screen shaking more and more);
--  2. they crash together into an orb of light, and the RARITY CLIMB starts: the orb pulses through the ladder
--     (grey, green, blue, purple, gold, pink, cyan, orange), one step per beat, each step bigger than the last -
--     shockwaves, lightning, flashes, a deeper boom - until it locks on the result's rarity;
--  3. the Fusion Egg bursts out of the light with an elastic bounce: its rarity in big letters, its name and the
--     pets it may hatch; rays, confetti and a crowd for the top tiers. A tap (or a few seconds) closes it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local EggForge = require(api:WaitForChild("EggForge"))
local PetModels = require(api:WaitForChild("PetModels"))
local UI = require(api:WaitForChild("UIKit"))
local assets = api:WaitForChild("UIAssets")
local C = UI.C
local S = Config.Sounds

local function sfx(id, volume, speed)
	if not id then return end
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = volume or 0.6; s.PlaybackSpeed = speed or 1; s.Parent = SoundService
	s:SetAttribute("PFEKeepSound", true)
	s:Play(); Debris:AddItem(s, 8)
	return s
end
local function tween(object, props, time, style, direction)
	local t = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play(); return t
end
local function wait(seconds)
	local started = os.clock()
	repeat RunService.RenderStepped:Wait() until os.clock() - started >= seconds
end

local busy = false
local function screen()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PFE_FusionShow"; gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false; gui.DisplayOrder = 60
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.Parent = player:WaitForChild("PlayerGui")
	local dim = UI.new("TextButton", {Name = "Dim", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Ink, BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), ZIndex = 1}, gui)
	local stage = UI.new("Frame", {Name = "Stage", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(700, 700), ZIndex = 2}, gui)
	local camera = workspace.CurrentCamera
	local s = camera and math.clamp(math.min(camera.ViewportSize.X, camera.ViewportSize.Y) / 760, 0.45, 1.3) or 1
	UI.new("UIScale", {Scale = s}, stage)
	return gui, dim, stage
end

-- (v29) a four-pointed twinkle star: a diamond with a thin cross through it
local function twinkle(parent, color, size, pos, z)
	local holder = UI.new("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(size, size),
		ZIndex = z or 20}, parent)
	local core = UI.new("Frame", {BackgroundColor3 = C.White, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.42, 0.42), Rotation = 45, ZIndex = (z or 20) + 1}, holder)
	UI.new("UIGradient", {Color = ColorSequence.new(C.White, color), Rotation = 45}, core)
	for _, rot in ipairs({0, 90}) do
		local bar = UI.new("Frame", {BackgroundColor3 = color:Lerp(C.White, 0.5), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, math.max(2, size / 9)), Rotation = rot, ZIndex = z or 20}, holder)
		UI.round(bar, UDim.new(0.5, 0))
		UI.new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1)})}, bar)
	end
	return holder
end
-- stars bursting out of the middle, spinning and twinkling as they go
local function starburst(stage, color, count, reach)
	for i = 1, count do
		local size = math.random(16, 40)
		local s = twinkle(stage, i % 4 == 0 and C.White or color, size, UDim2.fromScale(0.5, 0.5), 20)
		local a = math.random() * math.pi * 2
		local r = math.random(160, reach or 420)
		tween(s, {Position = UDim2.new(0.5, math.cos(a) * r, 0.5, math.sin(a) * r), Rotation = math.random(-200, 200), Size = UDim2.fromOffset(4, 4)},
			math.random(70, 120) / 100, Enum.EasingStyle.Quart)
		Debris:AddItem(s, 1.3)
	end
end
-- long soft rays fanning out behind the middle (a light flare)
local function rays(stage, color, n, length, life)
	local holder = UI.new("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10), Rotation = math.random(0, 360), ZIndex = 4}, stage)
	for i = 1, n do
		local ray = UI.new("Frame", {BackgroundColor3 = i % 2 == 0 and color or color:Lerp(C.White, 0.5), BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, i % 2 == 0 and 26 or 14),
			Rotation = i / n * 360, ZIndex = 4}, holder)
		UI.new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})}, ray)
		tween(ray, {Size = UDim2.fromOffset(length or 520, i % 2 == 0 and 40 or 20)}, (life or 0.7) * 0.6, Enum.EasingStyle.Quart)
		tween(ray, {BackgroundTransparency = 1}, life or 0.7)
	end
	tween(holder, {Rotation = holder.Rotation + 40}, life or 0.7)
	Debris:AddItem(holder, (life or 0.7) + 0.1)
end
local function shockwave(stage, color, width)
	-- (v29) a soft glowing halo instead of a hard ring, with a flare of rays
	rays(stage, color, 12, 420 + (width or 12) * 12, 0.7)
	local halo = UI.new("Frame", {BackgroundColor3 = color, BackgroundTransparency = 0.35, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(120, 120), ZIndex = 5}, stage)
	UI.round(halo, UDim.new(0.5, 0))
	UI.new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.6),
		NumberSequenceKeypoint.new(1, 1)}), Rotation = 0}, halo)
	tween(halo, {Size = UDim2.fromOffset(700, 700), BackgroundTransparency = 1}, 0.6, Enum.EasingStyle.Quart)
	Debris:AddItem(halo, 0.65)
end
-- sparks: small glowing squares flying out from the middle
local function sparks(stage, color, count, reach)
	if true then return starburst(stage, color, math.ceil(count * 0.7), reach) end
	for i = 1, count do
		local size = math.random(8, 20)
		local spark = UI.new("Frame", {BackgroundColor3 = i % 3 == 0 and C.White or color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size), Rotation = math.random(0, 90), ZIndex = 20}, stage)
		UI.round(spark, 3)
		local a = math.random() * math.pi * 2
		local r = math.random(180, reach or 420)
		tween(spark, {Position = UDim2.new(0.5, math.cos(a) * r, 0.5, math.sin(a) * r), Rotation = spark.Rotation + math.random(-360, 360),
			BackgroundTransparency = 1, Size = UDim2.fromOffset(2, 2)}, math.random(60, 110) / 100, Enum.EasingStyle.Quart)
		Debris:AddItem(spark, 1.3)
	end
end
local function confetti(gui, n)
	local colors = {Color3.fromRGB(255, 90, 140), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 220, 255), Color3.fromRGB(140, 255, 110),
		Color3.fromRGB(190, 120, 255)}
	for i = 1, n or 60 do
		local piece = UI.new("Frame", {BackgroundColor3 = colors[i % #colors + 1], BorderSizePixel = 0, Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20)),
			Position = UDim2.new(math.random(), 0, -0.05, -math.random(0, 200)), Rotation = math.random(0, 180), ZIndex = 30}, gui)
		tween(piece, {Position = UDim2.new(piece.Position.X.Scale + math.random(-10, 10) / 100, 0, 1.1, 0), Rotation = piece.Rotation + math.random(180, 720)},
			math.random(180, 320) / 100, Enum.EasingStyle.Linear)
		Debris:AddItem(piece, 3.4)
	end
end
local function oldShockwave(stage, color, width)
	local wave = UI.new("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(80, 80), ZIndex = 18}, stage)
	UI.round(wave, UDim.new(0.5, 0))
	local st = UI.new("UIStroke", {Thickness = width or 12, Color = color, Transparency = 0}, wave)
	tween(wave, {Size = UDim2.fromOffset(1200, 1200)}, 0.75, Enum.EasingStyle.Quart)
	tween(st, {Transparency = 1, Thickness = 2}, 0.75)
	Debris:AddItem(wave, 0.8)
end
-- a jagged lightning bolt from the middle out (a chain of thin frames)
local function lightning(stage, color)
	local a = math.random() * math.pi * 2
	local x, y = 350, 350
	local pieces = {}
	for _ = 1, 7 do
		local len = math.random(40, 80)
		local turn = a + math.rad(math.random(-40, 40))
		local nx, ny = x + math.cos(turn) * len, y + math.sin(turn) * len
		local seg = UI.new("Frame", {BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((x + nx) / 2, (y + ny) / 2), Size = UDim2.fromOffset(len + 4, math.random(4, 8)),
			Rotation = math.deg(math.atan2(ny - y, nx - x)), ZIndex = 17}, stage)
		UI.round(seg, 3)
		local glow = UI.new("UIStroke", {Thickness = 3, Color = C.White, Transparency = 0.3}, seg)
		table.insert(pieces, {seg, glow})
		x, y = nx, ny
	end
	for _, p in ipairs(pieces) do
		tween(p[1], {BackgroundTransparency = 1}, 0.35)
		tween(p[2], {Transparency = 1}, 0.35)
		Debris:AddItem(p[1], 0.4)
	end
end
local function flash(gui, color, from)
	local f = UI.new("Frame", {BackgroundColor3 = color or C.White, BackgroundTransparency = from or 0, Size = UDim2.fromScale(1, 1), ZIndex = 40}, gui)
	tween(f, {BackgroundTransparency = 1}, 0.6)
	Debris:AddItem(f, 0.7)
end

local function reveal(gui, dim, stage, opts)
	local color = opts.Color
	local order = opts.Order or 1
	local burst = UI.sunburst(stage, UDim2.fromOffset(640, 640), color, opts.Space and 0.8 or 0.25)
	burst.ZIndex = 5
	local burst2 = UI.sunburst(stage, UDim2.fromOffset(460, 460), C.White, opts.Space and 0.88 or 0.55)
	burst2.ZIndex = 6
	local burst3
	if order >= 5 and not opts.Space then
		burst3 = UI.sunburst(stage, UDim2.fromOffset(980, 980), color:Lerp(C.White, 0.3), 0.55)
		burst3.ZIndex = 4
	end
	local view = UI.viewport(stage, opts.Model, UDim2.fromOffset(20, 20), nil, {Yaw = 0.4})
	view.AnchorPoint = Vector2.new(0.5, 0.5); view.Position = UDim2.fromScale(0.5, 0.44); view.ZIndex = 10
	tween(view, {Size = UDim2.fromOffset(380, 380)}, 0.9, Enum.EasingStyle.Elastic)
	local pillar = UI.new("Frame", {BackgroundColor3 = color:Lerp(C.White, 0.5), BackgroundTransparency = 0.3, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(40, 0), ZIndex = 3}, stage)
	UI.new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0.3),
		NumberSequenceKeypoint.new(1, 0)})}, pillar)
	tween(pillar, {Size = UDim2.fromOffset(opts.Space and 120 or 260, 1400), BackgroundTransparency = opts.Space and 0.85 or 0.55}, 0.6, Enum.EasingStyle.Quart)
	local ribbon = UI.new("Frame", {BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(-0.6, 0, 0.775, 0), Size = UDim2.fromOffset(760, 86), Rotation = -3, ZIndex = 11}, stage)
	UI.new("UIStroke", {Thickness = 5, Color = C.Ink}, ribbon)
	UI.new("UIGradient", {Rotation = 90, Color = ColorSequence.new(color:Lerp(C.White, 0.25), color:Lerp(Color3.new(0, 0, 0), 0.2))}, ribbon)
	local sheen = UI.new("Frame", {BackgroundColor3 = C.White, BackgroundTransparency = 0.45, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.2, 0.5), Size = UDim2.new(0, 60, 1.4, 0), Rotation = 20, ZIndex = 12}, ribbon)
	ribbon.ClipsDescendants = true
	tween(ribbon, {Position = UDim2.new(0.5, 0, 0.775, 0)}, 0.45, Enum.EasingStyle.Back)
	task.delay(0.5, function()
		if sheen.Parent then
			tween(sheen, {Position = UDim2.fromScale(1.2, 0.5)}, 0.7, Enum.EasingStyle.Quad)
			task.delay(1.4, function() if sheen.Parent then sheen.Position = UDim2.fromScale(-0.2, 0.5); tween(sheen, {Position = UDim2.fromScale(1.2, 0.5)}, 0.7) end end)
		end
	end)
	local title = UI.text(stage, opts.Title, UDim2.fromOffset(700, 70), UDim2.new(0.5, 0, 0.74, 35), 64, C.White)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.TextXAlignment = Enum.TextXAlignment.Center; title.TextWrapped = false; title.ZIndex = 12
	UI.new("UIGradient", {Color = ColorSequence.new(C.White, color), Rotation = 90}, title)
	local titleScale = UI.new("UIScale", {Scale = 0.2}, title)
	tween(titleScale, {Scale = 1}, 0.6, Enum.EasingStyle.Back)
	local name = UI.text(stage, opts.Name, UDim2.fromOffset(700, 44), UDim2.new(0, 0, 0.84, 0), 38, C.White)
	name.TextXAlignment = Enum.TextXAlignment.Center; name.TextWrapped = false; name.ZIndex = 12
	local line = UI.text(stage, opts.Line or "", UDim2.fromOffset(700, 34), UDim2.new(0, 0, 0.91, 0), 24, Color3.fromRGB(120, 255, 90))
	line.TextXAlignment = Enum.TextXAlignment.Center; line.TextWrapped = false; line.ZIndex = 12
	if not opts.Space then confetti(gui, 40 + order * 12) end
	if order >= 6 then sfx(S.Cheer, 0.55, 1) end
	local spin = RunService.RenderStepped:Connect(function(dt)
		burst.Rotation += dt * (25 + order * 6); burst2.Rotation -= dt * (40 + order * 6)
		if burst3 then burst3.Rotation += dt * 12 end
		if math.random() < 0.12 + order * 0.02 then
			local s = twinkle(stage, math.random() < 0.5 and C.White or color, math.random(14, 30),
				UDim2.new(0.5, math.random(-280, 280), 0.44, math.random(-220, 180)), 13)
			s.Size = UDim2.fromOffset(2, 2)
			local size = math.random(16, 34)
			tween(s, {Size = UDim2.fromOffset(size, size), Rotation = 90}, 0.35, Enum.EasingStyle.Back)
			task.delay(0.4, function() if s.Parent then tween(s, {Size = UDim2.fromOffset(2, 2), Rotation = 180}, 0.3) end end)
			Debris:AddItem(s, 0.8)
		end
	end)
	local closed = false
	dim.Activated:Connect(function() closed = true end)
	local started = os.clock()
	repeat RunService.RenderStepped:Wait() until closed or os.clock() - started > 4.5 + order * 0.25
	spin:Disconnect()
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("GuiObject") then pcall(function() tween(d, {BackgroundTransparency = 1}, 0.3) end) end
		if d:IsA("TextLabel") then tween(d, {TextTransparency = 1}, 0.3) end
		if d:IsA("ImageLabel") or d:IsA("ViewportFrame") then tween(d, {ImageTransparency = 1}, 0.3) end
	end
	wait(0.35)
end

-- ===================================================================== (v30) the deep-space fusion
-- A dark starfield; the stars stretch into warp streaks as the power rises; in the middle a tiny white-hot
-- singularity with a purple glow and a lens-flare streak swallows the three eggs, flips through the rarity
-- colours, and gives birth to the Fusion Egg.
local function spaceBackdrop(gui)
	local back = UI.new("Frame", {Name = "Space", BackgroundColor3 = Color3.fromRGB(6, 4, 16), BorderSizePixel = 0, BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), ZIndex = 1}, gui)
	-- a faint purple nebula round the middle (concentric soft discs)
	for i, s in ipairs({1.4, 1.0, 0.65}) do
		local neb = UI.new("Frame", {BackgroundColor3 = Color3.fromRGB(70, 30, 140), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(s, s * 1.2), BackgroundTransparency = 1, ZIndex = 1}, back)
		UI.new("UIAspectRatioConstraint", {AspectRatio = 1}, neb)
		UI.round(neb, UDim.new(0.5, 0))
		neb:SetAttribute("Alpha", 0.93 - i * 0.025)
	end
	tween(back, {BackgroundTransparency = 0.04}, 0.5)
	for _, neb in ipairs(back:GetChildren()) do tween(neb, {BackgroundTransparency = neb:GetAttribute("Alpha")}, 0.8) end
	return back
end

local function starfield(gui, count)
	local holder = UI.new("Frame", {Name = "Stars", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2}, gui)
	local stars = {}
	local camera = workspace.CurrentCamera
	local function reach() local v = camera and camera.ViewportSize or Vector2.new(1280, 720); return math.max(v.X, v.Y) * 0.62 end
	local function spawn(star, anywhere)
		star.Angle = math.random() * math.pi * 2
		star.Dist = anywhere and math.random() * reach() or math.random(8, 60)
		star.Speed = math.random(40, 160)
		star.Size = math.random(1, 3) + (math.random() < 0.08 and 2 or 0)
	end
	for i = 1, count or 140 do
		local f = UI.new("Frame", {BackgroundColor3 = C.White, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2}, holder)
		UI.round(f, UDim.new(0.5, 0))
		local star = {Frame = f}
		spawn(star, true)
		stars[i] = star
	end
	local ctl = {Warp = 0.15, Color = C.White}
	function ctl.Step(dt)
		local limit = reach()
		for _, st in ipairs(stars) do
			local v = st.Speed * (0.2 + ctl.Warp * 6) * (0.3 + st.Dist / limit)
			st.Dist += v * dt
			if st.Dist > limit then spawn(st, false) end
			local len = st.Size + math.min(260, v * 0.06 * ctl.Warp)
			local x, y = math.cos(st.Angle) * st.Dist, math.sin(st.Angle) * st.Dist
			st.Frame.Position = UDim2.new(0.5, x, 0.5, y)
			st.Frame.Size = UDim2.fromOffset(len, st.Size)
			st.Frame.Rotation = math.deg(st.Angle)
			st.Frame.BackgroundTransparency = math.clamp(1 - st.Dist / (limit * 0.35), 0, 0.85)
		end
	end
	function ctl.Tint(color)
		for i, st in ipairs(stars) do st.Frame.BackgroundColor3 = (i % 3 == 0) and color or C.White:Lerp(color, 0.25) end
	end
	function ctl.Destroy() holder:Destroy() end
	return ctl
end

local function singularity(stage, color)
	local root = UI.new("Frame", {Name = "Singularity", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10), ZIndex = 9}, stage)
	local glows = {}
	for i, k in ipairs({1, 0.62, 0.36}) do
		local g = UI.new("Frame", {BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 0.82 - i * 0.12, ZIndex = 9 + i}, root)
		UI.round(g, UDim.new(0.5, 0))
		glows[i] = {Frame = g, K = k}
	end
	local function flare(w, h, z)
		local f = UI.new("Frame", {BackgroundColor3 = color:Lerp(C.White, 0.5), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h), ZIndex = z}, root)
		UI.round(f, UDim.new(0.5, 0))
		UI.new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1)})}, f)
		return f
	end
	local streak = flare(420, 5, 13)
	local streak2 = flare(160, 3, 13); streak2.Rotation = 90
	local ring = UI.new("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(46, 46), ZIndex = 14}, root)
	UI.round(ring, UDim.new(0.5, 0))
	local ringStroke = UI.new("UIStroke", {Thickness = 3, Color = color:Lerp(C.White, 0.3), Transparency = 0.2}, ring)
	local core = UI.new("Frame", {BackgroundColor3 = C.White, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16), ZIndex = 15}, root)
	UI.round(core, UDim.new(0.5, 0))
	local ctl = {Power = 0.2}
	function ctl.Set(c, power)
		ctl.Power = power or ctl.Power
		for _, g in ipairs(glows) do g.Frame.BackgroundColor3 = c end
		streak.BackgroundColor3 = c:Lerp(C.White, 0.55); streak2.BackgroundColor3 = c:Lerp(C.White, 0.55)
		ringStroke.Color = c:Lerp(C.White, 0.3)
	end
	function ctl.Step(t)
		local p = ctl.Power
		local breathe = 1 + math.sin(t * (5 + p * 10)) * 0.06
		for _, g in ipairs(glows) do
			local s = (60 + 360 * p) * g.K * breathe
			g.Frame.Size = UDim2.fromOffset(s, s)
		end
		streak.Size = UDim2.fromOffset((260 + 900 * p) * breathe, 3 + 5 * p)
		streak2.Size = UDim2.fromOffset((90 + 260 * p) * breathe, 2 + 3 * p)
		local rs = 30 + 70 * p
		ring.Size = UDim2.fromOffset(rs, rs)
		core.Size = UDim2.fromOffset(10 + 18 * p, 10 + 18 * p)
	end
	function ctl.Pulse(c, big)
		local wave = UI.new("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(40, 40), ZIndex = 12}, stage)
		UI.round(wave, UDim.new(0.5, 0))
		local st = UI.new("UIStroke", {Thickness = big and 6 or 3, Color = (c or C.White):Lerp(C.White, 0.3), Transparency = 0.1}, wave)
		local to = big and 900 or 520
		tween(wave, {Size = UDim2.fromOffset(to, to)}, big and 0.8 or 0.55, Enum.EasingStyle.Quart)
		tween(st, {Transparency = 1, Thickness = 1}, big and 0.8 or 0.55)
		Debris:AddItem(wave, 0.9)
	end
	function ctl.Destroy() root:Destroy() end
	return ctl
end

-- ===================================================================== (v36) the galaxy fusion
-- A spiral galaxy turns round a white-hot singularity with a glowing accretion disk; the three eggs spiral in on
-- light trails, lightning arcs between them and the core, the stars stretch into warp streaks; the core climbs the
-- rarity ladder; a SUPERNOVA (rings, rays, a flash, a pillar of light in the world itself) gives birth to the new
-- one-of-a-kind egg, and the hybrid pets inside it are dealt out on cards (their model, income and chance).
local function galaxy(stage, color)
	local holder = UI.new("Frame", {Name = "Galaxy", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), ZIndex = 3}, stage)
	local dots = {}
	local arms = 3
	for arm = 1, arms do
		for i = 1, 26 do
			local t = i / 26
			local angle = arm / arms * math.pi * 2 + t * math.pi * 2.6
			local r = 40 + t * 330
			local size = math.random(3, 7) * (1 - t * 0.4)
			local dot = UI.new("Frame", {BackgroundColor3 = (i % 4 == 0) and C.White or color:Lerp(C.White, math.random() * 0.4), BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, ZIndex = 3}, holder)
			UI.round(dot, UDim.new(0.5, 0))
			table.insert(dots, {Frame = dot, A = angle + (math.random() - 0.5) * 0.3, R = r + math.random(-14, 14), T = t})
		end
	end
	local ctl = {Spin = 0, Bright = 0}
	function ctl.Step(dt, k)
		ctl.Spin += dt * (0.25 + k * 2.2)
		for _, d in ipairs(dots) do
			local a = d.A + ctl.Spin * (1.4 - d.T * 0.8)
			local r = d.R * (1 - k * 0.55 * (1 - d.T * 0.5))
			d.Frame.Position = UDim2.fromOffset(math.cos(a) * r, math.sin(a) * r * 0.62)
			d.Frame.BackgroundTransparency = math.clamp(1 - ctl.Bright * (1 - d.T * 0.6), 0.05, 1)
		end
	end
	function ctl.Tint(c)
		for i, d in ipairs(dots) do d.Frame.BackgroundColor3 = (i % 4 == 0) and C.White or c:Lerp(C.White, 0.2) end
	end
	function ctl.Destroy() holder:Destroy() end
	return ctl
end

local function accretion(stage, color)
	local holder = UI.new("Frame", {Name = "Disk", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), ZIndex = 8}, stage)
	local dots = {}
	for i = 1, 44 do
		local dot = UI.new("Frame", {BackgroundColor3 = i % 3 == 0 and C.White or color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(6, 6), ZIndex = 8}, holder)
		UI.round(dot, UDim.new(0.5, 0))
		table.insert(dots, {Frame = dot, A = i / 44 * math.pi * 2, R = 70 + (i % 5) * 9})
	end
	local ctl = {Spin = 0, Size = 0.4}
	function ctl.Step(dt, k)
		ctl.Spin += dt * (2 + k * 9)
		for _, d in ipairs(dots) do
			local a = d.A + ctl.Spin * (90 / d.R)
			local r = d.R * ctl.Size
			local y = math.sin(a)
			d.Frame.Position = UDim2.fromOffset(math.cos(a) * r, y * r * 0.28)
			local s = (4 + 4 * k) * (y > 0 and 1.25 or 0.8)
			d.Frame.Size = UDim2.fromOffset(s * 2.2, s)
			d.Frame.Rotation = math.deg(a) + 90
			d.Frame.ZIndex = y > 0 and 16 or 8      -- the near half passes in front of the core
			d.Frame.BackgroundTransparency = y > 0 and 0.05 or 0.45
		end
	end
	function ctl.Tint(c)
		for i, d in ipairs(dots) do d.Frame.BackgroundColor3 = i % 3 == 0 and C.White or c end
	end
	function ctl.Destroy() holder:Destroy() end
	return ctl
end

-- a fading dot left behind (the eggs' light trails)
local function trailDot(stage, pos, color, size)
	local dot = UI.new("Frame", {BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos,
		Size = UDim2.fromOffset(size, size), BackgroundTransparency = 0.2, ZIndex = 7}, stage)
	UI.round(dot, UDim.new(0.5, 0))
	tween(dot, {BackgroundTransparency = 1, Size = UDim2.fromOffset(2, 2)}, 0.45)
	Debris:AddItem(dot, 0.5)
end
-- a crackling arc from the core to a point (a chain of thin segments)
local function arc(stage, to, color)
	local x, y = 350, 350
	local tx, ty = 350 + to.X, 350 + to.Y
	local steps = 6
	for i = 1, steps do
		local t = i / steps
		local nx = 350 + to.X * t + (i < steps and math.random(-18, 18) or 0)
		local ny = 350 + to.Y * t + (i < steps and math.random(-18, 18) or 0)
		local len = math.sqrt((nx - x) ^ 2 + (ny - y) ^ 2)
		local seg = UI.new("Frame", {BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((x + nx) / 2, (y + ny) / 2), Size = UDim2.fromOffset(len + 3, 3),
			Rotation = math.deg(math.atan2(ny - y, nx - x)), ZIndex = 15}, stage)
		UI.new("UIStroke", {Thickness = 2, Color = C.White, Transparency = 0.35}, seg)
		tween(seg, {BackgroundTransparency = 1}, 0.18)
		Debris:AddItem(seg, 0.22)
		x, y = nx, ny
	end
	local _ = tx + ty
end
-- the supernova: a blinding core, three expanding rings, rays and stars
local function supernova(gui, stage, color)
	flash(gui, C.White, 0)
	task.delay(0.12, function() if gui.Parent then flash(gui, color:Lerp(C.White, 0.4), 0.15) end end)
	local disk = UI.new("Frame", {BackgroundColor3 = C.White, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(60, 60), ZIndex = 18}, stage)
	UI.round(disk, UDim.new(0.5, 0))
	UI.new("UIGradient", {Color = ColorSequence.new(C.White, color), Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.3), NumberSequenceKeypoint.new(1, 1)})}, disk)
	tween(disk, {Size = UDim2.fromOffset(1100, 1100), BackgroundTransparency = 1}, 0.9, Enum.EasingStyle.Quart)
	Debris:AddItem(disk, 1)
	for i, c in ipairs({C.White, color, color:Lerp(Color3.new(0, 0, 0), 0.2)}) do
		task.delay((i - 1) * 0.09, function()
			if not stage.Parent then return end
			local ring = UI.new("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(60, 60), ZIndex = 17}, stage)
			UI.round(ring, UDim.new(0.5, 0))
			local st = UI.new("UIStroke", {Thickness = 14 - i * 3, Color = c, Transparency = 0}, ring)
			tween(ring, {Size = UDim2.fromOffset(1300 - i * 150, 1300 - i * 150)}, 0.95, Enum.EasingStyle.Quart)
			tween(st, {Transparency = 1, Thickness = 1}, 0.95)
			Debris:AddItem(ring, 1)
		end)
	end
	rays(stage, color, 18, 760, 1.1)
	starburst(stage, color, 46, 560)
end
-- the world's own moment: a pillar of light on the player and a burst of sparks round them
local function worldPillar(color)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local pillar = Instance.new("Part")
	pillar.Name = "PFE_FusionPillar"; pillar.Anchored = true; pillar.CanCollide = false; pillar.CanQuery = false; pillar.CanTouch = false
	pillar.Material = Enum.Material.Neon; pillar.Color = color; pillar.Transparency = 0.25; pillar.Shape = Enum.PartType.Cylinder
	pillar.Size = Vector3.new(180, 1, 1)
	pillar.CFrame = CFrame.new(root.Position + Vector3.new(0, 87, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Parent = workspace
	tween(pillar, {Size = Vector3.new(180, 14, 14), Transparency = 0.55}, 0.35, Enum.EasingStyle.Quart)
	task.delay(0.45, function() tween(pillar, {Size = Vector3.new(180, 0.2, 0.2), Transparency = 1}, 0.9) end)
	Debris:AddItem(pillar, 1.5)
	local burst = Instance.new("Part")
	burst.Anchored = true; burst.CanCollide = false; burst.CanQuery = false; burst.CanTouch = false; burst.Transparency = 1
	burst.Size = Vector3.new(1, 1, 1); burst.CFrame = root.CFrame; burst.Parent = workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"; pe.Color = ColorSequence.new(C.White, color)
	pe.LightEmission = 1; pe.Speed = NumberRange.new(18, 38); pe.Lifetime = NumberRange.new(0.6, 1.3); pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0)}); pe.Rate = 0; pe.Parent = burst
	pe:Emit(90)
	Debris:AddItem(burst, 2)
end

-- the new egg and its hybrids, dealt out on cards
local function revealForged(gui, dim, stage, payload, color, order)
	local egg = Config.Eggs[payload.EggId]
	-- a soft halo and slow rays behind the egg
	local halo = UI.new("Frame", {BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.33),
		Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 0.3, ZIndex = 5}, stage)
	UI.round(halo, UDim.new(0.5, 0))
	UI.new("UIGradient", {Color = ColorSequence.new(C.White, color), Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.55, 0.55), NumberSequenceKeypoint.new(1, 1)})}, halo)
	tween(halo, {Size = UDim2.fromOffset(430, 430)}, 0.7, Enum.EasingStyle.Back)
	local burst = UI.sunburst(stage, UDim2.fromOffset(560, 560), color:Lerp(C.White, 0.3), 0.78)
	burst.Position = UDim2.fromScale(0.5, 0.33); burst.ZIndex = 4
	local view = UI.viewport(stage, EggForge.Template(payload.EggId), UDim2.fromOffset(20, 20), nil, {Yaw = 0.4})
	view.AnchorPoint = Vector2.new(0.5, 0.5); view.Position = UDim2.fromScale(0.5, 0.33); view.ZIndex = 10
	tween(view, {Size = UDim2.fromOffset(300, 300)}, 0.85, Enum.EasingStyle.Elastic)
	local title = UI.text(stage, string.upper(payload.Rarity or (egg and egg.Rarity) or "") .. (payload.Upgraded and "!! UPGRADE!" or "!"),
		UDim2.fromOffset(700, 60), UDim2.new(0.5, 0, 0.555, 0), 56, C.White)
	title.AnchorPoint = Vector2.new(0.5, 0.5); title.TextXAlignment = Enum.TextXAlignment.Center; title.TextWrapped = false; title.ZIndex = 12
	UI.new("UIGradient", {Color = ColorSequence.new(C.White, color), Rotation = 90}, title)
	local ts = UI.new("UIScale", {Scale = 0.2}, title)
	tween(ts, {Scale = 1}, 0.55, Enum.EasingStyle.Back)
	local mutation = Config.Mutations[payload.Mutation or "Normal"]
	local name = UI.text(stage, ((mutation and mutation.Id ~= "Normal") and (mutation.Name .. " ") or "") .. (payload.Name or (egg and egg.Name) or "Fusion Egg"),
		UDim2.fromOffset(700, 40), UDim2.new(0.5, 0, 0.625, 0), 34, C.White)
	name.AnchorPoint = Vector2.new(0.5, 0.5); name.TextXAlignment = Enum.TextXAlignment.Center; name.TextWrapped = false; name.ZIndex = 12
	local sub = UI.text(stage, "ONE OF A KIND  -  HYBRIDS INSIDE", UDim2.fromOffset(700, 26), UDim2.new(0.5, 0, 0.675, 0), 20,
		Color3.fromRGB(255, 225, 120))
	sub.AnchorPoint = Vector2.new(0.5, 0.5); sub.TextXAlignment = Enum.TextXAlignment.Center; sub.TextWrapped = false; sub.ZIndex = 12
	-- the hybrid cards, one after another
	local hybrids = payload.Hybrids or {}
	local n = #hybrids
	local cardW = n >= 4 and 160 or 190
	for i, h in ipairs(hybrids) do
		task.delay(0.35 + i * 0.22, function()
			if not stage.Parent then return end
			local x = (i - (n + 1) / 2) * (cardW + 12)
			local card = UI.card(stage, color, UDim2.fromOffset(cardW, 196), UDim2.new(0.5, x, 0.705, 0), "Hybrid" .. i)
			card.AnchorPoint = Vector2.new(0.5, 0); card.ZIndex = 13
			local sc = UI.new("UIScale", {Scale = 0.2}, card)
			tween(sc, {Scale = 1}, 0.4, Enum.EasingStyle.Back)
			local ok, model = pcall(function() return PetModels.Template({Species = "Chimera", Parts = h.Parts, Name = h.Name}) end)
			local pv = UI.viewport(card, ok and model or nil, UDim2.new(1, -12, 0, 110), UDim2.fromOffset(6, 4), {Yaw = 0.6})
			pv.ZIndex = 15
			local nm = UI.text(card, h.Name or "?", UDim2.new(1, -10, 0, 24), UDim2.fromOffset(5, 114), 19, C.White)
			nm.TextXAlignment = Enum.TextXAlignment.Center; nm.TextWrapped = false; nm.TextScaled = true; nm.ZIndex = 16
			UI.new("UITextSizeConstraint", {MaxTextSize = 19}, nm)
			local inc = UI.text(card, "+" .. Config.Format(h.Income or 0) .. "/s", UDim2.new(1, -10, 0, 24), UDim2.fromOffset(5, 140), 20,
				Color3.fromRGB(120, 255, 90))
			inc.TextXAlignment = Enum.TextXAlignment.Center; inc.TextWrapped = false; inc.ZIndex = 16
			local pct = (h.Chance or 0) * 100
			local ch = UI.text(card, (pct >= 10 and string.format("%d%%", math.floor(pct + 0.5)) or string.format("%.1f%%", pct)),
				UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 166), 18, Color3.fromRGB(255, 230, 120))
			ch.TextXAlignment = Enum.TextXAlignment.Center; ch.TextWrapped = false; ch.ZIndex = 16
			for _, d in ipairs(card:GetDescendants()) do if d:IsA("GuiObject") and d.ZIndex < 14 then d.ZIndex = 14 end end
			starburst(stage, color, 8, 220)
			sfx(S.Sparkle, 0.4, 0.9 + i * 0.12)
		end)
	end
	if order >= 4 then confetti(gui, 40 + order * 10) end
	if order >= 6 then sfx(S.Cheer, 0.55, 1) end
	local spin = RunService.RenderStepped:Connect(function(dt)
		burst.Rotation += dt * (18 + order * 4)
		if math.random() < 0.1 + order * 0.02 then
			local s = twinkle(stage, math.random() < 0.5 and C.White or color, math.random(12, 26),
				UDim2.new(0.5, math.random(-250, 250), 0.33, math.random(-170, 150)), 11)
			s.Size = UDim2.fromOffset(2, 2)
			local size = math.random(14, 30)
			tween(s, {Size = UDim2.fromOffset(size, size), Rotation = 90}, 0.35, Enum.EasingStyle.Back)
			task.delay(0.4, function() if s.Parent then tween(s, {Size = UDim2.fromOffset(2, 2), Rotation = 180}, 0.3) end end)
			Debris:AddItem(s, 0.8)
		end
	end)
	local closed = false
	dim.Activated:Connect(function() closed = true end)
	local started = os.clock()
	repeat RunService.RenderStepped:Wait() until (closed and os.clock() - started > 1) or os.clock() - started > 6.5 + n * 0.3
	spin:Disconnect()
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("GuiObject") then pcall(function() tween(d, {BackgroundTransparency = 1}, 0.3) end) end
		if d:IsA("TextLabel") then tween(d, {TextTransparency = 1}, 0.3) end
		if d:IsA("ImageLabel") or d:IsA("ViewportFrame") then tween(d, {ImageTransparency = 1}, 0.3) end
	end
	wait(0.35)
end

local function fusionShow(payload)
	local egg = Config.Eggs[payload.EggId]
	if not egg then return end
	local rarity = Config.Rarities[payload.Rarity or egg.Rarity]
	local color = rarity and rarity.Color or C.Pink
	local order = rarity and rarity.Order or 1
	local gui, dim, stage = screen()
	dim.BackgroundTransparency = 1
	local space = spaceBackdrop(gui)
	local stars = starfield(gui, 140)
	local purple = Color3.fromRGB(170, 110, 255)
	stars.Tint(purple)
	local gx = galaxy(stage, purple)
	local disk = accretion(stage, Color3.fromRGB(200, 150, 255))
	local core = singularity(stage, purple)
	local cc = Instance.new("ColorCorrectionEffect"); cc.Name = "PFE_FusionCC"; cc.Parent = Lighting
	local k = 0
	local running = true
	local clock0 = os.clock()
	local loop = RunService.RenderStepped:Connect(function(dt)
		if not running then return end
		dt = math.min(dt, 0.05)
		stars.Step(dt)
		core.Step(os.clock() - clock0)
		gx.Step(dt, k)
		disk.Step(dt, k)
	end)
	-- 1. the eggs spiral in on light trails; the galaxy brightens and spins up; arcs crackle at the end
	local eggs = {}
	for i, eggId in ipairs(payload.Eggs or {}) do
		local view = UI.viewport(stage, EggForge.Template(eggId), UDim2.fromOffset(140, 140), nil, {Yaw = 0.5})
		view.AnchorPoint = Vector2.new(0.5, 0.5); view.ZIndex = 9
		view.Position = UDim2.new(0.5, math.cos(i * 2.09) * 700, 0.5, math.sin(i * 2.09) * 700)
		table.insert(eggs, {View = view, Angle = i * 2.09})
	end
	sfx(S.FuseCharge, 0.8, 1)
	sfx(S.FuseWhoosh, 0.6, 0.9)
	local duration, t0, nextTick, tick, nextTrail = 3.2, os.clock(), 0, 0, 0
	while true do
		local t = os.clock() - t0
		if t >= duration then break end
		k = t / duration
		local radius = 310 * (1 - k ^ 1.25)
		local speed = 1.0 + 8 * k ^ 2
		for _, e in ipairs(eggs) do
			e.Angle += speed / 60
			local fly = math.min(1, t / 0.6)
			local r = radius + (1 - fly) * 520
			local pos = UDim2.new(0.5, math.cos(e.Angle) * r, 0.5, math.sin(e.Angle) * r * 0.5)
			e.View.Position = pos
			local sz = 140 * (1 - k * 0.78)
			e.View.Size = UDim2.fromOffset(sz, sz)
			if t >= nextTrail then trailDot(stage, pos, k > 0.5 and C.White or purple, 10 + k * 8) end
			if k > 0.62 and math.random() < 0.18 then arc(stage, Vector2.new(math.cos(e.Angle) * r, math.sin(e.Angle) * r * 0.5), C.White) end
		end
		if t >= nextTrail then nextTrail = t + 0.03 end
		gx.Bright = math.min(1, 0.25 + k * 1.1)
		disk.Size = 0.4 + k * 0.9
		stars.Warp = 0.12 + 1.2 * k ^ 2
		core.Power = 0.12 + 0.6 * k ^ 1.5
		cc.Contrast = k * 0.15
		local shake = k ^ 3 * 6
		stage.Position = UDim2.new(0.5, (math.random() - 0.5) * shake, 0.5, (math.random() - 0.5) * shake)
		if t >= nextTick then
			tick += 1
			sfx(S.Tick, 0.7, 0.8 + tick * 0.1)
			nextTick = t + math.max(0.09, 0.42 - k * 0.33)
		end
		RunService.RenderStepped:Wait()
	end
	-- 2. swallowed: a white pulse; the core climbs the rarity ladder (galaxy and disk take each colour)
	for _, e in ipairs(eggs) do e.View:Destroy() end
	stage.Position = UDim2.fromScale(0.5, 0.5)
	flash(gui, C.White, 0.3)
	core.Pulse(C.White, true)
	rays(stage, C.White, 12, 520, 0.6)
	sfx(S.Boom, 0.6, 1.1)
	stars.Warp = 0.5
	local label = UI.text(stage, "", UDim2.fromOffset(700, 60), UDim2.new(0.5, 0, 0.76, 0), 50, C.White)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.TextXAlignment = Enum.TextXAlignment.Center; label.TextWrapped = false; label.ZIndex = 16
	local labelScale = UI.new("UIScale", {Scale = 1}, label)
	for step = 1, order do
		local r = Config.Rarities[Config.RarityOrder[step]]
		local c = r and r.Color or C.White
		local power = step / 8
		core.Set(c, 0.35 + power * 0.55)
		stars.Tint(c); gx.Tint(c); disk.Tint(c)
		stars.Warp = 0.4 + power * 0.9
		core.Pulse(c, step == order)
		if step >= 4 then rays(stage, c, 10 + step, 420 + step * 30, 0.5) end
		if step >= 5 then for _ = 1, step - 3 do arc(stage, Vector2.new(math.random(-300, 300), math.random(-200, 200)), c) end end
		cc.TintColor = Color3.new(1, 1, 1):Lerp(c, 0.1 + power * 0.15)
		label.Text = string.upper(Config.RarityOrder[step])
		label.TextColor3 = c:Lerp(C.White, 0.35)
		labelScale.Scale = 1.6; tween(labelScale, {Scale = 1}, 0.25, Enum.EasingStyle.Back)
		sfx(S.Tick, 0.8, 0.8 + step * 0.15)
		if step >= 3 then sfx(S.Sparkle, 0.35 + power * 0.4, 0.9 + power * 0.4) end
		local beat = step == order and 0.85 or (0.32 + power * 0.16)
		local t1 = os.clock()
		while os.clock() - t1 < beat do
			local shake = power * 5
			stage.Position = UDim2.new(0.5, (math.random() - 0.5) * shake, 0.5, (math.random() - 0.5) * shake)
			RunService.RenderStepped:Wait()
		end
	end
	stage.Position = UDim2.fromScale(0.5, 0.5)
	label:Destroy()
	-- 3. the SUPERNOVA: the new egg is born (the world gets its pillar of light)
	core.Power = 1.4
	supernova(gui, stage, color)
	worldPillar(color)
	local camera = workspace.CurrentCamera
	if camera then
		local fov = camera.FieldOfView
		camera.FieldOfView = math.max(30, fov - 14)
		tween(camera, {FieldOfView = fov}, 0.8, Enum.EasingStyle.Elastic)
	end
	stars.Warp = 1.8
	sfx(order >= 5 and S.BigBoom or S.Boom, 0.8, 1)
	sfx(order >= 5 and S.Legendary or S.Reward, 0.8, 1)
	if order >= 4 then sfx(S.Jackpot, 0.5, 1) end
	task.delay(0.4, function() stars.Warp = 0.1; core.Power = 0.2; k = 0.15 end)
	tween(cc, {TintColor = Color3.new(1, 1, 1), Saturation = 0.1, Contrast = 0}, 0.8)
	wait(0.45)
	core.Destroy(); disk.Destroy()
	gx.Bright = 0.35
	-- 4. the egg and its hybrids
	revealForged(gui, dim, stage, payload, color, order)
	running = false
	loop:Disconnect()
	gx.Destroy()
	stars.Destroy()
	space:Destroy()
	cc:Destroy()
	gui:Destroy()
end


-- (v38) over the 3D show: the rarity and the name up top, the hybrid cards along the bottom (the egg itself is in
-- the world in the middle of the screen); a tap or a few seconds closes it
local function revealCards(gui, dim, stage, payload, color, order)
	local egg = Config.Eggs[payload.EggId]
	local title = UI.text(stage, string.upper(payload.Rarity or (egg and egg.Rarity) or "") .. (payload.Upgraded and "!! UPGRADE!" or "!"),
		UDim2.fromOffset(700, 60), UDim2.new(0.5, 0, 0.06, 0), 56, C.White)
	title.AnchorPoint = Vector2.new(0.5, 0.5); title.TextXAlignment = Enum.TextXAlignment.Center; title.TextWrapped = false; title.ZIndex = 12
	UI.new("UIGradient", {Color = ColorSequence.new(C.White, color), Rotation = 90}, title)
	local ts = UI.new("UIScale", {Scale = 0.2}, title)
	tween(ts, {Scale = 1}, 0.55, Enum.EasingStyle.Back)
	local mutation = Config.Mutations[payload.Mutation or "Normal"]
	local name = UI.text(stage, ((mutation and mutation.Id ~= "Normal") and (mutation.Name .. " ") or "") .. (payload.Name or (egg and egg.Name) or "Fusion Egg"),
		UDim2.fromOffset(700, 40), UDim2.new(0.5, 0, 0.13, 0), 34, C.White)
	name.AnchorPoint = Vector2.new(0.5, 0.5); name.TextXAlignment = Enum.TextXAlignment.Center; name.TextWrapped = false; name.ZIndex = 12
	local sub = UI.text(stage, "ONE OF A KIND  -  HYBRIDS INSIDE", UDim2.fromOffset(700, 26), UDim2.new(0.5, 0, 0.18, 0), 20,
		Color3.fromRGB(255, 225, 120))
	sub.AnchorPoint = Vector2.new(0.5, 0.5); sub.TextXAlignment = Enum.TextXAlignment.Center; sub.TextWrapped = false; sub.ZIndex = 12
	local hybrids = payload.Hybrids or {}
	local n = #hybrids
	local cardW = n >= 4 and 160 or 190
	for i, h in ipairs(hybrids) do
		task.delay(0.35 + i * 0.22, function()
			if not stage.Parent then return end
			local x = (i - (n + 1) / 2) * (cardW + 12)
			local card = UI.card(stage, color, UDim2.fromOffset(cardW, 196), UDim2.new(0.5, x, 0.72, 0), "Hybrid" .. i)
			card.AnchorPoint = Vector2.new(0.5, 0); card.ZIndex = 13
			local sc = UI.new("UIScale", {Scale = 0.2}, card)
			tween(sc, {Scale = 1}, 0.4, Enum.EasingStyle.Back)
			local ok, model = pcall(function() return PetModels.Template({Species = "Chimera", Parts = h.Parts, Name = h.Name}) end)
			local pv = UI.viewport(card, ok and model or nil, UDim2.new(1, -12, 0, 110), UDim2.fromOffset(6, 4), {Yaw = 0.6})
			pv.ZIndex = 15
			local nm = UI.text(card, h.Name or "?", UDim2.new(1, -10, 0, 24), UDim2.fromOffset(5, 114), 19, C.White)
			nm.TextXAlignment = Enum.TextXAlignment.Center; nm.TextWrapped = false; nm.TextScaled = true; nm.ZIndex = 16
			UI.new("UITextSizeConstraint", {MaxTextSize = 19}, nm)
			local inc = UI.text(card, "+" .. Config.Format(h.Income or 0) .. "/s", UDim2.new(1, -10, 0, 24), UDim2.fromOffset(5, 140), 20,
				Color3.fromRGB(120, 255, 90))
			inc.TextXAlignment = Enum.TextXAlignment.Center; inc.TextWrapped = false; inc.ZIndex = 16
			local pct = (h.Chance or 0) * 100
			local ch = UI.text(card, (pct >= 10 and string.format("%d%%", math.floor(pct + 0.5)) or string.format("%.1f%%", pct)),
				UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 166), 18, Color3.fromRGB(255, 230, 120))
			ch.TextXAlignment = Enum.TextXAlignment.Center; ch.TextWrapped = false; ch.ZIndex = 16
			for _, d in ipairs(card:GetDescendants()) do if d:IsA("GuiObject") and d.ZIndex < 14 then d.ZIndex = 14 end end
			sfx(S.Sparkle, 0.4, 0.9 + i * 0.12)
		end)
	end
	if order >= 4 then confetti(gui, 40 + order * 10) end
	if order >= 6 then sfx(S.Cheer, 0.55, 1) end
	local closed = false
	dim.Activated:Connect(function() closed = true end)
	local started = os.clock()
	repeat RunService.RenderStepped:Wait() until (closed and os.clock() - started > 1) or os.clock() - started > 6.5 + n * 0.3
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("GuiObject") then pcall(function() tween(d, {BackgroundTransparency = 1}, 0.3) end) end
		if d:IsA("TextLabel") then tween(d, {TextTransparency = 1}, 0.3) end
		if d:IsA("ImageLabel") or d:IsA("ViewportFrame") then tween(d, {ImageTransparency = 1}, 0.3) end
	end
	wait(0.35)
end

-- ===================================================================== (v38) the fusion as a 3D VFX show
-- Up in the open sky above you: a floating glass altar with a neon rim, two rings of runes turning against each
-- other and six pillars of light. Your three eggs (three times their size) circle it on glowing trails, pulled in
-- tighter and faster; energy beams tie them to a white-hot core that drinks in sparks from all around (an inward
-- sphere of particles); lightning snaps between them. The core climbs the rarity ladder - a colour, a shockwave
-- across the altar and a burst per step - then the eggs crash into it: a SUPERNOVA (the blast's core, smoke, sparks,
-- rings of shock, a pillar of light up to the sky, the camera kicked back) and out of the light the new egg rises
-- in its aura with a fan of rays behind it, its hybrids on cards below. Bloom up and the background blurred while it
-- lasts; the interface steps aside. Everything is local and cleaned up; ~150 parts, a handful of emitters.
local VFX = {
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	FireSparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Core = "rbxasset://textures/particles/explosion01_core_main.dds",
	Shock = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	BlastSmoke = "rbxasset://textures/particles/explosion01_smoke_main.dds",
}
local function set(object, props)
	for k, v in pairs(props) do pcall(function() object[k] = v end) end
	return object
end
local function seqN(...) return NumberSequence.new(...) end
local function keys(list)
	local kps = {}
	for _, kv in ipairs(list) do table.insert(kps, NumberSequenceKeypoint.new(kv[1], kv[2])) end
	return NumberSequence.new(kps)
end

local function fusionShow3D(payload)
	local egg = Config.Eggs[payload.EggId]
	if not egg then return end
	local rarity = Config.Rarities[payload.Rarity or egg.Rarity]
	local color = rarity and rarity.Color or C.Pink
	local order = rarity and rarity.Order or 1
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local here = hrp and hrp.Position or (camera and camera.CFrame.Position) or Vector3.new(0, 70, 0)
	local O = Vector3.new(here.X, here.Y + 180, here.Z)            -- the altar's centre, up in the open sky
	local look = camera and Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z) or Vector3.new(0, 0, -1)
	look = look.Magnitude > 0.05 and look.Unit or Vector3.new(0, 0, -1)
	local sideV = look:Cross(Vector3.yAxis).Unit
	local undo = {}
	local function onEnd(fn) table.insert(undo, fn) end
	local gui, dim, stage
	local ok, err = pcall(function()
	local folder = Instance.new("Folder"); folder.Name = "PFE_FusionStage"; folder.Parent = workspace
	onEnd(function() folder:Destroy() end)
	-- the interface steps aside (ours stays: the rarity ladder's words and the cards)
	gui, dim, stage = screen()
	dim.BackgroundTransparency = 1
	local hidden = {}
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g ~= gui and g.Enabled and g.Name ~= "PFE_IntroCutscene" then hidden[g] = true; g.Enabled = false end
	end
	onEnd(function() for g in pairs(hidden) do if g.Parent then g.Enabled = true end end end)
	-- the light: bloom up for the neon, the background soft, a touch more contrast
	local cc = Instance.new("ColorCorrectionEffect"); cc.Name = "PFE_FusionCC"; cc.Parent = Lighting
	set(cc, {Contrast = 0.15, Saturation = 0.2, Brightness = -0.04})
	onEnd(function() cc:Destroy() end)
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		local was = {Intensity = bloom.Intensity, Threshold = bloom.Threshold, Size = bloom.Size}
		set(bloom, {Intensity = 1.1, Threshold = 0.82, Size = 40})
		onEnd(function() set(bloom, was) end)
	end
	local dof = Instance.new("DepthOfFieldEffect")
	set(dof, {Name = "PFE_FusionFocus", FarIntensity = 0.45, NearIntensity = 0, FocusDistance = 30, InFocusRadius = 22})
	dof.Parent = Lighting
	onEnd(function() dof:Destroy() end)
	-- the camera is the show's
	local camWas = camera and {Type = camera.CameraType, Fov = camera.FieldOfView}
	if camera then camera.CameraType = Enum.CameraType.Scriptable end
	onEnd(function()
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			if humanoid then camera.CameraSubject = humanoid end
			camera.FieldOfView = camWas.Fov
		end
	end)

	local function part(name, size, cf, col, material, transparency, shape)
		local p = Instance.new("Part")
		p.Name = name; p.Size = size; p.CFrame = cf; p.Color = col; p.Material = material or Enum.Material.Neon
		p.Transparency = transparency or 0; p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
		if shape then p.Shape = shape end
		p.Parent = folder
		return p
	end
	local function emitter(parent, props)
		local pe = Instance.new("ParticleEmitter")
		set(pe, {LightInfluence = 0, Rate = 0})
		set(pe, props)
		pe.Parent = parent
		return pe
	end
	local glow = Color3.fromRGB(180, 120, 255)
	-- ---- the altar
	local floorY = O.Y - 4
	local altar = part("Altar", Vector3.new(2, 28, 28), CFrame.new(O.X, floorY - 1, O.Z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(30, 18, 52),
		Enum.Material.Glass, 0.1, Enum.PartType.Cylinder)
	local rim, runes = {}, {}
	for i = 1, 28 do
		local a = i / 28 * math.pi * 2
		local p = part("Rim", Vector3.new(3.4, 0.45, 0.5), CFrame.new(), glow)
		table.insert(rim, {Part = p, A = a})
	end
	local GLYPHS = {
		{{0, 0, 0.25, 1.4}, {0.45, 0.45, 0.9, 0.25}},          -- a T
		{{-0.3, 0, 0.25, 1.3}, {0.3, 0, 0.25, 1.3}, {0, 0.5, 0.85, 0.22}},
		{{0, 0, 0.25, 1.5}, {0, 0, 1.0, 0.22}},                -- a cross
		{{-0.35, 0, 0.22, 1.2}, {0.2, -0.45, 0.8, 0.22}},       -- an L
		{{0, 0.4, 0.9, 0.22}, {0, -0.4, 0.9, 0.22}, {0, 0, 0.22, 1.0}},
	}
	for ringIndex, spec in ipairs({{R = 10.5, N = 16, Dir = 1}, {R = 6.2, N = 10, Dir = -1}}) do
		for i = 1, spec.N do
			local a = i / spec.N * math.pi * 2
			local g = GLYPHS[(i + ringIndex) % #GLYPHS + 1]
			for _, bar in ipairs(g) do
				local p = part("Rune", Vector3.new(bar[3], 0.2, bar[4]), CFrame.new(), glow)
				table.insert(runes, {Part = p, R = spec.R, A = a, Dir = spec.Dir, Off = Vector3.new(bar[1], 0, bar[2])})
			end
		end
	end
	-- pillars of light round the rim
	local beams = {}
	local hub = part("Hub", Vector3.new(1, 1, 1), CFrame.new(O), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(math.cos(a) * 13, floorY - O.Y, math.sin(a) * 13); a0.Parent = hub
		local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(math.cos(a) * 13, floorY - O.Y + 40, math.sin(a) * 13); a1.Parent = hub
		local b = Instance.new("Beam")
		set(b, {Attachment0 = a0, Attachment1 = a1, Width0 = 1.8, Width1 = 0.2, LightEmission = 1, LightInfluence = 0, Texture = VFX.Spark,
			TextureSpeed = 1.5, TextureLength = 6, FaceCamera = true, Color = ColorSequence.new(glow),
			Transparency = keys({{0, 0.15}, {0.7, 0.6}, {1, 1}})})
		b.Parent = hub
		table.insert(beams, b)
	end
	-- the core and what it drinks in
	local core = part("Core", Vector3.new(1, 1, 1), CFrame.new(O + Vector3.yAxis * 5), Color3.new(1, 1, 1), Enum.Material.Neon, 0, Enum.PartType.Ball)
	local coreLight = Instance.new("PointLight"); set(coreLight, {Range = 30, Brightness = 2, Color = glow}); coreLight.Parent = core
	local coreAtt = Instance.new("Attachment"); coreAtt.Parent = core
	local shell = part("Shell", Vector3.new(30, 30, 30), CFrame.new(O + Vector3.yAxis * 5), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1,
		Enum.PartType.Ball)
	local inward = emitter(shell, {Texture = VFX.Spark, Lifetime = NumberRange.new(0.7, 0.95), Speed = NumberRange.new(16, 22),
		Size = keys({{0, 0.9}, {1, 0.1}}), Transparency = keys({{0, 1}, {0.2, 0.1}, {1, 0}}), LightEmission = 1, Color = ColorSequence.new(C.White, glow),
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward})
	local coreFx = emitter(core, {Texture = VFX.Fire, Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(1, 3),
		Size = keys({{0, 3}, {1, 0.5}}), Transparency = keys({{0, 0.2}, {1, 1}}), LightEmission = 1, Color = ColorSequence.new(C.White, glow),
		SpreadAngle = Vector2.new(180, 180), RotSpeed = NumberRange.new(-200, 200), Rotation = NumberRange.new(0, 360)})
	-- bursts: sparks / smoke / the blast's core / shock rings lying on the altar or facing us
	local burstPart = part("Burst", Vector3.new(2, 2, 2), CFrame.new(O + Vector3.yAxis * 5), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	local sparks = emitter(burstPart, {Texture = VFX.FireSparks, Lifetime = NumberRange.new(0.5, 1.1), Speed = NumberRange.new(30, 60),
		Size = keys({{0, 1.4}, {1, 0}}), LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Drag = 3, Color = ColorSequence.new(C.White, glow)})
	local blast = emitter(burstPart, {Texture = VFX.Core, Lifetime = NumberRange.new(0.45, 0.7), Speed = NumberRange.new(0, 2),
		Size = keys({{0, 6}, {1, 42}}), Transparency = keys({{0, 0}, {0.6, 0.3}, {1, 1}}), LightEmission = 1, Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60)})
	local smoke = emitter(burstPart, {Texture = VFX.BlastSmoke, Lifetime = NumberRange.new(1.4, 2.4), Speed = NumberRange.new(8, 22),
		Size = keys({{0, 8}, {1, 28}}), Transparency = keys({{0, 0.3}, {1, 1}}), LightEmission = 0.3, SpreadAngle = Vector2.new(180, 180), Drag = 2,
		Color = ColorSequence.new(Color3.fromRGB(120, 90, 160)), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30)})
	local ringPart = part("RingSource", Vector3.new(1, 0.2, 1), CFrame.new(O.X, floorY + 0.2, O.Z), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	local floorRing = emitter(ringPart, {Texture = VFX.Shock, Lifetime = NumberRange.new(0.7, 0.7), Speed = NumberRange.new(0.01, 0.01),
		EmissionDirection = Enum.NormalId.Top, Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Size = keys({{0, 2}, {1, 34}}),
		Transparency = keys({{0, 0}, {1, 1}}), LightEmission = 1})
	local faceRing = emitter(burstPart, {Texture = VFX.Shock, Lifetime = NumberRange.new(0.6, 0.6), Speed = NumberRange.new(0, 0),
		Size = keys({{0, 4}, {1, 70}}), Transparency = keys({{0, 0}, {1, 1}}), LightEmission = 1})
	local function burst(c, n, ring, big)
		for _, e in ipairs({sparks, floorRing, faceRing}) do set(e, {Color = ColorSequence.new(C.White, c)}) end
		pcall(function() sparks:Emit(n) end)
		if ring then pcall(function() floorRing:Emit(1) end) end
		if big then pcall(function() faceRing:Emit(1) end) end
	end
	-- lightning between the eggs
	local function bolt(a, b, c)
		local pts = {a}
		local dir = b - a
		local p1 = dir:Cross(Vector3.yAxis).Unit
		for i = 1, 5 do table.insert(pts, a + dir * (i / 6) + p1 * (math.random() - 0.5) * 2.4 + Vector3.yAxis * (math.random() - 0.5) * 2) end
		table.insert(pts, b)
		for i = 1, #pts - 1 do
			local d = (pts[i + 1] - pts[i]).Magnitude
			local seg = part("Bolt", Vector3.new(0.22, 0.22, d), CFrame.lookAt((pts[i] + pts[i + 1]) / 2, pts[i + 1]), c)
			Debris:AddItem(seg, 0.09)
		end
	end
	-- ---- the three eggs, three times their size, on trails, tied to the core by beams
	local eggs = {}
	for i, eggId in ipairs(payload.Eggs or {}) do
		local template = EggForge.Template(eggId)
		if template then
			local m = template:Clone()
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false
				elseif d:IsA("ParticleEmitter") or d:IsA("LuaSourceContainer") then d:Destroy() end
			end
			pcall(function() m:ScaleTo(3) end)
			m.Parent = folder
			local info = Config.Eggs[eggId]
			local ec = info and Config.Rarities[info.Rarity] and Config.Rarities[info.Rarity].Color or glow
			local rootPart = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
			local t0 = Instance.new("Attachment"); t0.Position = Vector3.new(0, 1.2, 0); t0.Parent = rootPart
			local t1 = Instance.new("Attachment"); t1.Position = Vector3.new(0, 3.6, 0); t1.Parent = rootPart
			local trail = Instance.new("Trail")
			set(trail, {Attachment0 = t0, Attachment1 = t1, Lifetime = 0.5, LightEmission = 1, LightInfluence = 0, FaceCamera = true,
				Color = ColorSequence.new(C.White, ec), Transparency = keys({{0, 0.1}, {1, 1}}), WidthScale = keys({{0, 1}, {1, 0.2}})})
			trail.Parent = rootPart
			local mid = Instance.new("Attachment"); mid.Position = Vector3.new(0, 2.4, 0); mid.Parent = rootPart
			local beam = Instance.new("Beam")
			set(beam, {Attachment0 = mid, Attachment1 = coreAtt, Width0 = 0.9, Width1 = 0.3, LightEmission = 1, LightInfluence = 0, Texture = VFX.Spark,
				TextureSpeed = 3, TextureLength = 4, FaceCamera = true, Color = ColorSequence.new(ec, C.White), Transparency = seqN(1), Segments = 20})
			beam.Parent = rootPart
			table.insert(eggs, {Model = m, A = (i - 1) / 3 * math.pi * 2, Color = ec, Beam = beam})
		end
	end
	-- ---- the camera's path
	local shakeAmp, kick = 0, 0
	local function camAt(angle, dist, height, target)
		if not camera then return end
		local dirV = (-look * math.cos(angle) + sideV * math.sin(angle))
		local eye = O + dirV * dist + Vector3.yAxis * height
		local n1 = math.noise(os.clock() * 13, 1.1) * shakeAmp
		local n2 = math.noise(os.clock() * 13, 7.3) * shakeAmp
		camera.CFrame = CFrame.lookAt(eye, target or (O + Vector3.yAxis * 4)) * CFrame.Angles(math.rad(n1 * 2), math.rad(n2 * 2), 0)
		pcall(function() dof.FocusDistance = (eye - (target or O)).Magnitude end)
	end
	-- the altar's own motion every frame (runes turning, rim pulsing, eggs flying)
	local clock0 = os.clock()
	local orbit = {R = 11, H = 6, Speed = 0.8, Pull = 0}
	local paint = glow
	local stepConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - clock0
		local list, cfs = {}, {}
		for _, r in ipairs(rim) do
			table.insert(list, r.Part)
			table.insert(cfs, CFrame.new(O.X + math.cos(r.A) * 13.2, floorY, O.Z + math.sin(r.A) * 13.2) * CFrame.Angles(0, -r.A + math.pi / 2, 0))
		end
		for _, g in ipairs(runes) do
			local a = g.A + t * 0.35 * g.Dir * (1 + orbit.Pull * 3)
			local cf = CFrame.new(O.X + math.cos(a) * g.R, floorY + 0.15, O.Z + math.sin(a) * g.R) * CFrame.Angles(0, -a, 0) * CFrame.new(g.Off)
			table.insert(list, g.Part); table.insert(cfs, cf)
		end
		pcall(function() workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged) end)
		for _, e in ipairs(eggs) do
			if e.Model.Parent and not e.Fixed then
				e.A += orbit.Speed / 60
				local pos = O + Vector3.new(math.cos(e.A) * orbit.R, orbit.H + math.sin(t * 2 + e.A) * 0.6, math.sin(e.A) * orbit.R)
				pcall(function() e.Model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, t * 1.4 + e.A, math.sin(t * 3 + e.A) * 0.15)) end)
			end
		end
	end)
	onEnd(function() stepConn:Disconnect() end)
	local function paintAll(c)
		paint = c
		for _, r in ipairs(rim) do r.Part.Color = c end
		for _, g in ipairs(runes) do g.Part.Color = c:Lerp(C.White, 0.25) end
		for _, b in ipairs(beams) do set(b, {Color = ColorSequence.new(c)}) end
		core.Color = c:Lerp(C.White, 0.55)
		coreLight.Color = c
		set(inward, {Color = ColorSequence.new(C.White, c)}); set(coreFx, {Color = ColorSequence.new(C.White, c)})
	end

	-- 1. the charge: the eggs fly in and circle faster, tighter, higher; the core drinks in light
	sfx(S.FuseCharge, 0.8, 1)
	sfx(S.FuseWhoosh, 0.6, 0.9)
	local duration, t0, nextTick, ticks = 3.4, os.clock(), 0, 0
	local ringAt = {0.35, 0.7}
	while true do
		local t = os.clock() - t0
		if t >= duration then break end
		local k = t / duration
		orbit.R = 11 - 6.5 * k ^ 1.4
		orbit.H = 3 + 4 * k
		orbit.Speed = 0.8 + 9 * k ^ 2
		orbit.Pull = k
		local size = 1 + 3.2 * k ^ 1.5
		core.Size = Vector3.new(size, size, size)
		coreLight.Brightness = 2 + 6 * k; coreLight.Range = 30 + 30 * k
		inward.Rate = 40 + 220 * k
		coreFx.Rate = 10 + 50 * k
		for _, e in ipairs(eggs) do set(e.Beam, {Transparency = seqN(math.clamp(1 - (k - 0.25) * 2, 0, 1)), CurveSize0 = math.sin(t * 9) * 3,
			CurveSize1 = math.cos(t * 7) * 3}) end
		if k > 0.55 and math.random() < 0.25 and #eggs >= 2 then
			local a, b = eggs[math.random(1, #eggs)], eggs[math.random(1, #eggs)]
			if a ~= b then bolt(a.Model:GetPivot().Position + Vector3.yAxis * 2.4, b.Model:GetPivot().Position + Vector3.yAxis * 2.4, C.White) end
		end
		for i, at in ipairs(ringAt) do
			if at and k >= at then ringAt[i] = false; burst(paint, 30, true, false); sfx(S.Boom, 0.35, 1.3) end
		end
		shakeAmp = k ^ 3 * 0.8
		camAt(-0.5 + t * 0.22, 34 - 10 * k, 9 - 3 * k)
		if camera then camera.FieldOfView = 70 - 14 * k end
		cc.Contrast = 0.15 + k * 0.15
		if t >= nextTick then
			ticks += 1
			sfx(S.Tick, 0.7, 0.8 + ticks * 0.1)
			nextTick = t + math.max(0.09, 0.42 - k * 0.33)
		end
		RunService.RenderStepped:Wait()
	end
	-- 2. the eggs are swallowed; the core climbs the rarity ladder: a colour, a shockwave, a burst per step
	for _, e in ipairs(eggs) do
		e.Fixed = true
		local from = e.Model:GetPivot()
		task.spawn(function()
			local tt = 0
			while tt < 0.22 do
				tt += RunService.RenderStepped:Wait()
				pcall(function() e.Model:PivotTo(from:Lerp(CFrame.new(core.Position - Vector3.yAxis * 1.5), math.min(1, tt / 0.22))) end)
			end
			e.Model:Destroy()
		end)
	end
	task.wait(0.22)
	flash(gui, C.White, 0.2)
	burst(C.White, 60, true, true)
	sfx(S.Boom, 0.6, 1.1)
	inward.Rate = 0
	local label = UI.text(stage, "", UDim2.fromOffset(700, 60), UDim2.new(0.5, 0, 0.82, 0), 54, C.White)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.TextXAlignment = Enum.TextXAlignment.Center; label.TextWrapped = false; label.ZIndex = 16
	local labelScale = UI.new("UIScale", {Scale = 1}, label)
	for step = 1, order do
		local r = Config.Rarities[Config.RarityOrder[step]]
		local c = r and r.Color or C.White
		local power = step / 8
		paintAll(c)
		local size = 4 + power * 3
		core.Size = Vector3.new(size, size, size)
		coreLight.Brightness = 6 + power * 6
		burst(c, 18 + step * 8, true, step >= 5)
		if step >= 4 and #eggs >= 0 then
			for _ = 1, step - 2 do
				local a = math.random() * math.pi * 2
				bolt(core.Position, core.Position + Vector3.new(math.cos(a) * 12, math.random(-4, 8), math.sin(a) * 12), c)
			end
		end
		cc.TintColor = Color3.new(1, 1, 1):Lerp(c, 0.12 + power * 0.12)
		label.Text = string.upper(Config.RarityOrder[step])
		label.TextColor3 = c:Lerp(C.White, 0.35)
		labelScale.Scale = 1.6; tween(labelScale, {Scale = 1}, 0.25, Enum.EasingStyle.Back)
		sfx(S.Tick, 0.8, 0.8 + step * 0.15)
		if step >= 3 then sfx(S.Sparkle, 0.35 + power * 0.4, 0.9 + power * 0.4) end
		local beat = step == order and 0.8 or (0.3 + power * 0.16)
		local t1 = os.clock()
		while os.clock() - t1 < beat do
			shakeAmp = power * 0.7
			local tt = os.clock() - t1
			camAt(0.15 + (os.clock() - clock0) * 0.05, 24 - power * 2 + math.max(0, 0.6 - tt * 4) * -2, 6)
			RunService.RenderStepped:Wait()
		end
	end
	label:Destroy()
	-- 3. the SUPERNOVA: the blast, the smoke, the rings, a pillar of light to the sky; the camera kicked back
	flash(gui, C.White, 0)
	set(blast, {Color = ColorSequence.new(C.White, color)}); set(smoke, {Color = ColorSequence.new(color:Lerp(Color3.new(0.2, 0.15, 0.3), 0.6))})
	pcall(function() blast:Emit(order >= 5 and 8 or 5) end)
	pcall(function() smoke:Emit(order >= 5 and 26 or 14) end)
	burst(color, 120 + order * 20, true, true)
	task.delay(0.12, function() burst(C.White, 0, true, true) end)
	local pillar = part("Pillar", Vector3.new(1, 6, 6), CFrame.new(O + Vector3.yAxis * 5) * CFrame.Angles(0, 0, math.rad(90)), color:Lerp(C.White, 0.4),
		Enum.Material.Neon, 0.1, Enum.PartType.Cylinder)
	TweenService:Create(pillar, TweenInfo.new(1.6, Enum.EasingStyle.Quart), {Size = Vector3.new(700, 9, 9), Transparency = 1,
		CFrame = CFrame.new(O + Vector3.yAxis * 350) * CFrame.Angles(0, 0, math.rad(90))}):Play()
	core.Transparency = 1; coreFx.Rate = 0
	coreLight.Brightness = 16; coreLight.Color = color; coreLight.Range = 60
	TweenService:Create(coreLight, TweenInfo.new(1.2), {Brightness = 4, Range = 36}):Play()
	sfx(order >= 5 and S.BigBoom or S.Boom, 0.85, 1)
	sfx(order >= 5 and S.Legendary or S.Reward, 0.8, 1)
	if order >= 4 then sfx(S.Jackpot, 0.5, 1) end
	if camera then
		camera.FieldOfView = 46
		tween(camera, {FieldOfView = 62}, 0.9, Enum.EasingStyle.Elastic)
	end
	tween(cc, {TintColor = Color3.new(1, 1, 1), Contrast = 0.12}, 0.8)
	-- 4. out of the light: the new egg in its aura, a fan of rays turning behind it
	local newEgg
	local template = EggForge.Template(payload.EggId)
	if template then
		newEgg = template:Clone()
		for _, d in ipairs(newEgg:GetDescendants()) do
			if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false
			elseif d:IsA("LuaSourceContainer") then d:Destroy() end
		end
		pcall(function() newEgg:ScaleTo(0.6) end)
		newEgg.Parent = folder
		local rootPart = newEgg.PrimaryPart or newEgg:FindFirstChildWhichIsA("BasePart")
		if rootPart then
			emitter(rootPart, {Texture = VFX.Spark, Rate = 30 + order * 8, Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(2, 6),
				Size = keys({{0, 0.9}, {1, 0}}), LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Color = ColorSequence.new(C.White, color),
				Acceleration = Vector3.new(0, 3, 0)})
			local l = Instance.new("PointLight"); set(l, {Range = 26, Brightness = 4, Color = color}); l.Parent = rootPart
		end
	end
	local fan = {}
	local fanCount = 10 + order
	for i = 1, fanCount do
		local p = part("Ray", Vector3.new(0.7, 20 + (i % 2) * 8, 0.2), CFrame.new(), color:Lerp(C.White, 0.3), Enum.Material.Neon, 0.55)
		table.insert(fan, {Part = p, A = i / fanCount * math.pi * 2})
	end
	local reveal0 = os.clock()
	local revealConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - reveal0
		local grow = math.min(1, t / 0.7)
		local s = 0.6 + 3.2 * (1 - (1 - grow) ^ 3) + math.sin(math.min(1, t / 0.7) * math.pi) * 0.4
		if newEgg then
			pcall(function()
				newEgg:ScaleTo(s)
				newEgg:PivotTo(CFrame.new(O + Vector3.yAxis * (2 + math.sin(t * 1.6) * 0.5)) * CFrame.Angles(0, t * 0.9, 0))
			end)
		end
		local toCam = camera and (camera.CFrame.Position - (O + Vector3.yAxis * 6)) or look
		local face = CFrame.lookAt(O + Vector3.yAxis * 6, O + Vector3.yAxis * 6 + Vector3.new(toCam.X, 0, toCam.Z))
		for _, r in ipairs(fan) do
			local a = r.A + t * 0.25
			r.Part.CFrame = face * CFrame.new(0, 0, 2) * CFrame.Angles(0, 0, a) * CFrame.new(0, r.Part.Size.Y / 2 + 4, 0)
			r.Part.Transparency = 0.55 + 0.4 * (1 - math.min(1, t / 0.5))
		end
		shakeAmp = math.max(0, 1.2 - t * 1.6)
		camAt(0.2 + t * 0.12, 30 - math.min(1, t / 1.5) * 6, 7, O + Vector3.yAxis * 5)
	end)
	onEnd(function() revealConn:Disconnect() end)
	wait(0.45)
	-- 5. its name, its hybrids on cards (the 3D egg is the picture)
	revealCards(gui, dim, stage, payload, color, order)
	-- 6. it all fades away and the game comes back
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") then pcall(function() tween(d, {Transparency = 1}, 0.35) end)
		elseif d:IsA("ParticleEmitter") then d.Rate = 0
		elseif d:IsA("Beam") or d:IsA("Trail") then d.Enabled = false end
	end
	wait(0.4)
	end)
	-- (whatever happened, everything comes back)
	for i = #undo, 1, -1 do pcall(undo[i]) end
	if gui then gui:Destroy() end
	if not ok then error(err, 0) end
end

local function limitedShow(payload)
	local egg = Config.Eggs[payload.EggId]
	if not egg then return end
	local gui, dim, stage = screen()
	dim.BackgroundTransparency = 0.2
	local flashFrame = UI.new("Frame", {BackgroundColor3 = Color3.fromRGB(255, 150, 50), BackgroundTransparency = 0.2, Size = UDim2.fromScale(1, 1), ZIndex = 40}, gui)
	tween(flashFrame, {BackgroundTransparency = 1}, 0.8)
	sfx(S.FuseWhoosh, 0.7, 1.1)
	sfx(S.Legendary, 0.8, 1)
	sparks(stage, Color3.fromRGB(255, 140, 40), 40)
	reveal(gui, dim, stage, {Model = EggForge.Template(payload.EggId), Color = Color3.fromRGB(255, 140, 40), Order = 7, Title = "LIMITED!",
		Name = egg.Name, Line = egg.Secret and "Its pets are a secret - plant it and see!" or "Plant it in your pen!"})
	gui:Destroy()
end

api:WaitForChild("Effect").OnClientEvent:Connect(function(kind, payload)
	if type(payload) ~= "table" or busy then return end
	if kind ~= "FusionResult" and kind ~= "LimitedEgg" then return end
	busy = true
	local ok, err
	if kind == "FusionResult" then
		-- (v38) the 3D show; the old 2D one only if the 3D one could not run
		ok, err = pcall(fusionShow3D, payload)
		if not ok then
			warn("[PFE] fusion 3D show: " .. tostring(err))
			for _, name in ipairs({"PFE_FusionStage"}) do local left = workspace:FindFirstChild(name); if left then left:Destroy() end end
			local camera = workspace.CurrentCamera
			if camera then camera.CameraType = Enum.CameraType.Custom end
			local left = player.PlayerGui:FindFirstChild("PFE_FusionShow"); if left then left:Destroy() end
			ok, err = pcall(fusionShow, payload)
		end
	else
		ok, err = pcall(limitedShow, payload)
	end
	busy = false
	local left = player.PlayerGui:FindFirstChild("PFE_FusionShow")
	if left then left:Destroy() end
	local cc = Lighting:FindFirstChild("PFE_FusionCC")
	if cc then cc:Destroy() end
	if not ok then warn("[PFE] fusion show: " .. tostring(err)) end
end)
