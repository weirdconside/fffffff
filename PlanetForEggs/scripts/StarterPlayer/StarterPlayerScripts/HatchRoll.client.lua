--!nocheck
-- v28 THE HATCH MULTIPLIER ("casino"). Every hatch rolls a multiplier on the server (Bases.Hatch); this plays it
-- back: a giant "x1.00" that climbs faster and faster - m(t) = exp(A * t^Power), Config.HatchCurve - with a
-- heartbeat every second (it may stop on any of them), and everything grows with it: the number swells and
-- changes colour, the screen shakes harder, the sunbursts spin faster, sparks fly, the drum roll speeds up,
-- milestones (x10, x100, x1K ... x10M) slam in with flashes, shockwaves and stings. Where it stops is where the
-- server said (T seconds in). Then the pet: what the multiplier bought (luck, a mutation step) - and past x1000,
-- when nothing in the egg is good enough any more, the OVERLOAD: a one-of-a-kind Chimera stitched out of three pets.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local EggForge = require(game:GetService("ReplicatedStorage"):WaitForChild("PFE"):WaitForChild("EggForge"))
local UI = require(api:WaitForChild("UIKit"))
local PetModels = require(api:WaitForChild("PetModels"))
local assets = api:WaitForChild("UIAssets")
local C = UI.C
local S = Config.Sounds

local function sfx(id, volume, speed, looped)
	if not id then return nil end
	local s = Instance.new("Sound")
	s.SoundId = id; s.Volume = volume or 0.6; s.PlaybackSpeed = speed or 1; s.Looped = looped == true
	s:SetAttribute("PFEKeepSound", true)
	s.Parent = SoundService
	s:Play()
	if not looped then Debris:AddItem(s, 10) end
	return s
end
local function tween(object, props, time, style, direction)
	local t = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play(); return t
end

-- the colour ladder: x1 grey .. x10 green .. x100 blue .. x1K purple .. x10K gold .. x100K pink .. x1M cyan .. x10M rainbow
local LADDER = {
	{1, Color3.fromRGB(230, 232, 240), Color3.fromRGB(150, 156, 175)},
	{10, Color3.fromRGB(140, 255, 120), Color3.fromRGB(40, 190, 70)},
	{100, Color3.fromRGB(120, 210, 255), Color3.fromRGB(30, 110, 255)},
	{1000, Color3.fromRGB(220, 150, 255), Color3.fromRGB(140, 50, 255)},
	{10000, Color3.fromRGB(255, 240, 140), Color3.fromRGB(255, 160, 20)},
	{100000, Color3.fromRGB(255, 160, 210), Color3.fromRGB(255, 40, 120)},
	{1000000, Color3.fromRGB(170, 255, 250), Color3.fromRGB(30, 220, 230)},
	{10000000, Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255)},
}
local MILESTONES = {
	[10] = "NICE!", [100] = "AMAZING!", [1000] = "INSANE!!", [10000] = "LEGENDARY!!",
	[100000] = "MYTHICAL!!!", [1000000] = "GODLY!!!!", [10000000] = "IMPOSSIBLE!!!!!",
}
local function tierOf(m)
	local tier = 1
	for i, row in ipairs(LADDER) do if m >= row[1] then tier = i end end
	return tier
end
local RAINBOW = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 60)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 240, 90)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 180, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(190, 90, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 200))})

-- ---------------------------------------------------------------- the screen
local function build()
	local gui = UI.new("ScreenGui", {Name = "PFE_HatchRoll", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 58,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
	pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None end)
	local dim = UI.new("TextButton", {Name = "Dim", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(8, 6, 16),
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1}, gui)
	-- vignette in the tier colour (four soft edges)
	local edges = {}
	for i, spec in ipairs({{UDim2.new(1, 0, 0.32, 0), UDim2.new(0, 0, 0, 0), 90}, {UDim2.new(1, 0, 0.32, 0), UDim2.new(0, 0, 0.68, 0), 270},
		{UDim2.new(0.25, 0, 1, 0), UDim2.new(0, 0, 0, 0), 0}, {UDim2.new(0.25, 0, 1, 0), UDim2.new(0.75, 0, 0, 0), 180}}) do
		local f = UI.new("Frame", {Name = "Edge" .. i, BackgroundColor3 = C.White, BackgroundTransparency = 1, BorderSizePixel = 0,
			Size = spec[1], Position = spec[2], ZIndex = 2}, gui)
		UI.new("UIGradient", {Rotation = spec[3], Transparency = NumberSequence.new(0, 1)}, f)
		table.insert(edges, f)
	end
	local stage = UI.new("Frame", {Name = "Stage", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(760, 600), ZIndex = 3}, gui)
	local cam = workspace.CurrentCamera
	local s = cam and math.clamp(math.min(cam.ViewportSize.X / 800, cam.ViewportSize.Y / 640), 0.45, 1.3) or 1
	UI.new("UIScale", {Scale = s}, stage)
	local burst = UI.sunburst(stage, UDim2.fromOffset(620, 620), C.White, 0.75)
	burst.Position = UDim2.fromScale(0.5, 0.42); burst.ZIndex = 4
	local burst2 = UI.sunburst(stage, UDim2.fromOffset(900, 900), C.White, 1)
	burst2.Position = UDim2.fromScale(0.5, 0.42); burst2.ZIndex = 3
	local ring = UI.new("Frame", {Name = "Pulse", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(300, 300), ZIndex = 5}, stage)
	UI.round(ring, UDim.new(0.5, 0))
	local ringStroke = UI.new("UIStroke", {Thickness = 6, Color = C.White, Transparency = 1}, ring)
	local caption = UI.text(stage, "HATCH MULTIPLIER", UDim2.fromOffset(760, 34), UDim2.new(0, 0, 0.36, 0), 30, C.Gold)
	caption.TextXAlignment = Enum.TextXAlignment.Center; caption.TextWrapped = false; caption.ZIndex = 9
	local number = UI.text(stage, "x1.00", UDim2.fromOffset(760, 130), UDim2.new(0, 0, 0.44, 0), 110, C.White)
	-- (v30) scaled about its own centre: with the top-left anchor a growing x drifted off to the side
	number.AnchorPoint = Vector2.new(0.5, 0.5); number.Position = UDim2.new(0.5, 0, 0.44, 65)
	number.Name = "Multiplier"; number.TextXAlignment = Enum.TextXAlignment.Center; number.TextWrapped = false; number.ZIndex = 10
	local numberScale = UI.new("UIScale", {Scale = 1}, number)
	local numberGrad = UI.new("UIGradient", {Rotation = 90, Color = ColorSequence.new(LADDER[1][2], LADDER[1][3])}, number)
	local numberStroke = number:FindFirstChildOfClass("UIStroke")
	if numberStroke then numberStroke.Thickness = 7 end
	local shoutText = UI.text(stage, "", UDim2.fromOffset(760, 80), UDim2.new(0, 0, 0.7, 0), 64, C.White)
	shoutText.AnchorPoint = Vector2.new(0.5, 0.5); shoutText.Position = UDim2.new(0.5, 0, 0.7, 40)
	shoutText.TextXAlignment = Enum.TextXAlignment.Center; shoutText.TextWrapped = false; shoutText.ZIndex = 11; shoutText.TextTransparency = 1
	local shoutScale = UI.new("UIScale", {Scale = 1}, shoutText)
	local shoutGrad = UI.new("UIGradient", {Rotation = 90}, shoutText)
	local check = UI.text(stage, "", UDim2.fromOffset(760, 30), UDim2.new(0, 0, 0.66, 0), 24, C.Soft)
	check.TextXAlignment = Enum.TextXAlignment.Center; check.ZIndex = 9
	return {Gui = gui, Dim = dim, Edges = edges, Stage = stage, Burst = burst, Burst2 = burst2, Ring = ring, RingStroke = ringStroke,
		Caption = caption, Number = number, NumberScale = numberScale, NumberGrad = numberGrad, Shout = shoutText, ShoutScale = shoutScale,
		ShoutGrad = shoutGrad, Check = check}
end

local function sparks(parent, color, count, radius, pos)
	for i = 1, count do
		local size = math.random(6, 18)
		local spark = UI.new("Frame", {BackgroundColor3 = i % 3 == 0 and C.White or color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos or UDim2.fromScale(0.5, 0.56), Size = UDim2.fromOffset(size, size), Rotation = math.random(0, 90), ZIndex = 20}, parent)
		UI.round(spark, 3)
		local a = math.random() * math.pi * 2
		local r = math.random(math.floor(radius * 0.4), radius)
		local base = pos or UDim2.fromScale(0.5, 0.56)
		tween(spark, {Position = base + UDim2.fromOffset(math.cos(a) * r, math.sin(a) * r), Rotation = spark.Rotation + math.random(-360, 360),
			BackgroundTransparency = 1, Size = UDim2.fromOffset(2, 2)}, math.random(50, 110) / 100, Enum.EasingStyle.Quart)
		Debris:AddItem(spark, 1.2)
	end
end
local function shockwave(parent, color, pos)
	local wave = UI.new("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos or UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(60, 60), ZIndex = 19}, parent)
	UI.round(wave, UDim.new(0.5, 0))
	local st = UI.new("UIStroke", {Thickness = 14, Color = color, Transparency = 0}, wave)
	tween(wave, {Size = UDim2.fromOffset(1100, 1100)}, 0.8, Enum.EasingStyle.Quart)
	tween(st, {Transparency = 1, Thickness = 2}, 0.8)
	Debris:AddItem(wave, 0.9)
end
local function flash(gui, color, from)
	local f = UI.new("Frame", {BackgroundColor3 = color or C.White, BackgroundTransparency = from or 0.1, Size = UDim2.fromScale(1, 1), ZIndex = 40}, gui)
	tween(f, {BackgroundTransparency = 1}, 0.5)
	Debris:AddItem(f, 0.6)
end
local function confetti(gui, n)
	local colors = {Color3.fromRGB(255, 90, 140), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 220, 255), Color3.fromRGB(140, 255, 110),
		Color3.fromRGB(190, 120, 255)}
	for i = 1, n do
		local piece = UI.new("Frame", {BackgroundColor3 = colors[i % #colors + 1], BorderSizePixel = 0, Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20)),
			Position = UDim2.new(math.random(), 0, -0.05, -math.random(0, 220)), Rotation = math.random(0, 180), ZIndex = 30}, gui)
		tween(piece, {Position = UDim2.new(piece.Position.X.Scale + math.random(-10, 10) / 100, 0, 1.1, 0), Rotation = piece.Rotation + math.random(180, 720)},
			math.random(180, 320) / 100, Enum.EasingStyle.Linear)
		Debris:AddItem(piece, 3.4)
	end
end
local function shout(ui, text, color1, color2, rainbow)
	ui.Shout.Text = text
	ui.ShoutGrad.Color = rainbow and RAINBOW or ColorSequence.new(color1, color2)
	ui.Shout.TextTransparency = 0
	local stroke = ui.Shout:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Transparency = 0 end
	ui.ShoutScale.Scale = 3
	tween(ui.ShoutScale, {Scale = 1}, 0.35, Enum.EasingStyle.Back)
	task.delay(1.4, function()
		if ui.Shout.Parent then
			tween(ui.Shout, {TextTransparency = 1}, 0.4)
			if stroke then tween(stroke, {Transparency = 1}, 0.4) end
		end
	end)
end

-- ---------------------------------------------------------------- the reveal card
local function reveal(ui, payload)
	local stage = ui.Stage
	local info = Config.PetInfo({Species = payload.Species, Name = payload.Name, Parts = payload.Parts, Income = payload.Income})
	local rarity = Config.Rarities[payload.Rarity or (info and info.Rarity) or "Common"] or Config.Rarities.Common
	local color = rarity.Color
	for _, name in ipairs({"Caption", "Multiplier", "Pulse"}) do
		local o = stage:FindFirstChild(name)
		if o and o:IsA("TextLabel") then tween(o, {TextTransparency = 1}, 0.25) end
	end
	tween(ui.Number, {Position = UDim2.new(0.5, 0, 0.04, 65)}, 0.35)
	tween(ui.NumberScale, {Scale = 0.55}, 0.35)
	ui.Caption.Text = ""
	local stitched = (payload.Chimera or payload.Hybrid) and type(payload.Parts) == "table"
	local template = PetModels.Template(stitched and {Species = "Chimera", Parts = payload.Parts} or payload.Species)
	if stitched then
		-- the three pets fly together into one
		local minis = {}
		for i, sp in ipairs(payload.Parts) do
			local v = UI.viewport(stage, assets.Pets:FindFirstChild(sp), UDim2.fromOffset(170, 170), nil, {Yaw = 0.5})
			v.AnchorPoint = Vector2.new(0.5, 0.5); v.ZIndex = 12
			v.Position = UDim2.new(0.5, (i - 2) * 250, 0.5, 0)
			table.insert(minis, v)
		end
		sfx(S.MagicWhoosh, 0.8, 1)
		task.wait(0.7)
		for _, v in ipairs(minis) do tween(v, {Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(60, 60)}, 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In) end
		task.wait(0.45)
		for _, v in ipairs(minis) do v:Destroy() end
		flash(ui.Gui, C.White, 0)
		shockwave(stage, Color3.fromRGB(255, 70, 255), UDim2.fromScale(0.5, 0.5))
		sparks(stage, Color3.fromRGB(255, 120, 255), 50, 420, UDim2.fromScale(0.5, 0.5))
		sfx(S.Legendary, 0.7, 1.1)
	end
	local view = UI.viewport(stage, template, UDim2.fromOffset(20, 20), nil, {Yaw = 0.5})
	view.AnchorPoint = Vector2.new(0.5, 0.5); view.Position = UDim2.fromScale(0.5, 0.47); view.ZIndex = 12
	tween(view, {Size = UDim2.fromOffset(360, 360)}, 0.8, Enum.EasingStyle.Elastic)
	local title = UI.text(stage, payload.Chimera and "✦ SPECIAL PET ✦" or string.upper(payload.Rarity or rarity.Id) .. "!", UDim2.fromOffset(760, 64),
		UDim2.new(0, 0, 0.73, 0), 58, C.White)
	title.AnchorPoint = Vector2.new(0.5, 0.5); title.Position = UDim2.new(0.5, 0, 0.73, 32)
	title.TextXAlignment = Enum.TextXAlignment.Center; title.TextWrapped = false; title.ZIndex = 13
	local tgrad = UI.new("UIGradient", {Rotation = 90, Color = payload.Chimera and RAINBOW or ColorSequence.new(C.White, color)}, title)
	local ts = UI.new("UIScale", {Scale = 0.2}, title)
	tween(ts, {Scale = 1}, 0.5, Enum.EasingStyle.Back)
	local mutation = Config.Mutations[payload.Mutation or "Normal"]
	local nameText = ((mutation and mutation.Id ~= "Normal") and (mutation.Name .. " ") or "") .. (payload.Name or (info and info.Name) or "?")
	local name = UI.text(stage, nameText, UDim2.fromOffset(760, 44), UDim2.new(0, 0, 0.84, 0), 38, mutation and mutation.Id ~= "Normal" and mutation.Color or C.White)
	name.TextXAlignment = Enum.TextXAlignment.Center; name.TextWrapped = false; name.ZIndex = 13
	local line = UI.text(stage, "+" .. Config.Format(payload.Income or 0) .. "/s" .. (payload.Upgraded and "   ·   MUTATION UPGRADED!" or ""),
		UDim2.fromOffset(760, 32), UDim2.new(0, 0, 0.92, 0), 26, Color3.fromRGB(120, 255, 90))
	line.TextXAlignment = Enum.TextXAlignment.Center; line.ZIndex = 13
	local order = rarity.Order or 1
	sfx(order >= 5 and S.Legendary or S.Reward, 0.8, 1)
	if order >= 4 or payload.Chimera then confetti(ui.Gui, payload.Chimera and 120 or 60) end
	local spin = RunService.RenderStepped:Connect(function(dt)
		if payload.Chimera then tgrad.Rotation = (tgrad.Rotation + dt * 160) % 360 end
	end)
	local closed = false
	local hit = ui.Dim.Activated:Connect(function() closed = true end)
	local started = os.clock()
	repeat RunService.RenderStepped:Wait() until closed or os.clock() - started > (payload.Chimera and 6 or 4.2)
	spin:Disconnect(); hit:Disconnect()
end

-- ---------------------------------------------------------------- one roll
local fovSaved
local function play(payload)
	local M = math.max(1, tonumber(payload.M) or 1)
	local A = tonumber(payload.A) or 0.4
	local T = math.max(0, tonumber(payload.T) or 0)
	local ui = build()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "PFE_HatchRollCC"; cc.Parent = Lighting
	local camera = workspace.CurrentCamera
	fovSaved = fovSaved or (camera and camera.FieldOfView) or 70
	tween(ui.Dim, {BackgroundTransparency = 0.45}, 0.3)
	local eggView = UI.viewport(ui.Stage, EggForge.Template(payload.EggId or ""), UDim2.fromOffset(170, 170), nil, {Yaw = 0.5})
	eggView.AnchorPoint = Vector2.new(0.5, 0.5); eggView.Position = UDim2.fromScale(0.5, 0.2); eggView.ZIndex = 8
	local drum = nil   -- (v29: no drum roll / heartbeat / riser - bright chimes instead)
	local started = os.clock()
	local lastTick, lastDigits, nextCheck = 0, "", 1
	local passed = {}
	local display = 1
	-- the climb
	while true do
		local t = os.clock() - started
		if t >= T then break end
		local m = math.min(M, Config.HatchCurve(A, t))
		-- the digits roll: a little random flicker below the true value
		display = math.max(1, m * (1 - math.random() * 0.025))
		local intensity = math.clamp(math.log10(display) / 7, 0, 1)
		local tier = tierOf(display)
		local row = LADDER[tier]
		ui.Number.Text = Config.FormatMultiplier(display)
		ui.NumberGrad.Color = tier >= 8 and RAINBOW or ColorSequence.new(row[2], row[3])
		if tier >= 7 then ui.NumberGrad.Rotation = (ui.NumberGrad.Rotation + 6) % 360 end
		ui.NumberScale.Scale = 1 + intensity * 1.25 + math.sin(t * (6 + intensity * 30)) * 0.03 * (1 + intensity * 3)
		ui.Number.Rotation = math.sin(t * 17) * intensity * 6
		-- shake, spin, glow
		local shake = 2 + intensity ^ 1.4 * 26
		ui.Stage.Position = UDim2.new(0.5, math.random(-100, 100) / 100 * shake, 0.48, math.random(-100, 100) / 100 * shake)
		ui.Burst.Rotation += 1 + intensity * 14
		ui.Burst.ImageColor3 = row[3]; ui.Burst.ImageTransparency = 0.75 - intensity * 0.5
		ui.Burst2.Rotation -= 0.5 + intensity * 9
		ui.Burst2.ImageColor3 = row[2]; ui.Burst2.ImageTransparency = 1 - math.max(0, intensity - 0.25) * 1.1
		for _, e in ipairs(ui.Edges) do e.BackgroundColor3 = row[3]; e.BackgroundTransparency = 0.85 - intensity * 0.6 end
		eggView.Rotation = math.sin(t * (10 + intensity * 40)) * (6 + intensity * 20)
		cc.Saturation = intensity * 0.5; cc.Contrast = intensity * 0.2
		cc.TintColor = Color3.new(1, 1, 1):Lerp(row[2], intensity * 0.25)
		if camera then camera.FieldOfView = fovSaved - intensity * 14 end
		if drum then drum.PlaybackSpeed = 1 + intensity * 0.9; drum.Volume = 0.35 + intensity * 0.4 end
		if math.random() < 0.1 + intensity * 0.8 then sparks(ui.Stage, row[3], 1 + math.floor(intensity * 4), 260 + intensity * 260) end
		-- the slot ticks follow the digits
		local digits = string.sub(ui.Number.Text, 1, 4)
		if digits ~= lastDigits and os.clock() - lastTick > 0.07 - intensity * 0.04 then
			lastDigits = digits; lastTick = os.clock()
			sfx(S.Tick, 0.35 + intensity * 0.3, 0.9 + intensity * 1.2)
		end
		-- every second: the heartbeat (it may stop here)
		if t >= nextCheck then
			nextCheck += 1
			sfx(S.Sparkle, 0.3 + intensity * 0.2, 1 + intensity * 0.5)
			ui.RingStroke.Color = row[3]; ui.RingStroke.Transparency = 0
			ui.Ring.Size = UDim2.fromOffset(240, 240)
			tween(ui.Ring, {Size = UDim2.fromOffset(520 + intensity * 400, 520 + intensity * 400)}, 0.6)
			tween(ui.RingStroke, {Transparency = 1}, 0.6)
			ui.Check.Text = "will it stop?"
			ui.Check.TextColor3 = row[2]
			task.delay(0.45, function() if ui.Check.Parent then ui.Check.Text = "" end end)
		end
		-- milestones
		for value, text in pairs(MILESTONES) do
			if display >= value and not passed[value] then
				passed[value] = true
				local mrow = LADDER[tierOf(value)]
				shout(ui, text, mrow[2], mrow[3], value >= 1e7)
				flash(ui.Gui, mrow[2], 0.35)
				shockwave(ui.Stage, mrow[3])
				sparks(ui.Stage, mrow[3], 24 + tierOf(value) * 6, 520)
				sfx(S.LevelUp, 0.5, 0.9 + tierOf(value) * 0.06)
				if value >= 1000 then sfx(S.Reward, 0.55, 1); confetti(ui.Gui, 30 + tierOf(value) * 10) end
				if false then ui.Caption.Text = "OVERLOAD - A SPECIAL PET IS COMING..."; ui.Caption.TextColor3 = Color3.fromRGB(255, 120, 255) end
			end
		end
		if display >= Config.HatchRoll.ChimeraFrom and not passed.chimera then
			passed.chimera = true
			ui.Caption.Text = "OVERLOAD - A SPECIAL PET IS COMING..."; ui.Caption.TextColor3 = Color3.fromRGB(255, 120, 255)
		end
		RunService.RenderStepped:Wait()
	end
	-- STOP
	if drum then drum:Stop(); drum:Destroy() end
	local tier = tierOf(M)
	local row = LADDER[tier]
	ui.Number.Text = Config.FormatMultiplier(M)
	ui.NumberGrad.Color = tier >= 8 and RAINBOW or ColorSequence.new(row[2], row[3])
	ui.Stage.Position = UDim2.fromScale(0.5, 0.48)
	ui.Number.Rotation = 0
	local intensity = math.clamp(math.log10(M) / 7, 0, 1)
	ui.NumberScale.Scale = 1.6 + intensity * 1.2
	tween(ui.NumberScale, {Scale = 1.05 + intensity * 0.9}, 0.45, Enum.EasingStyle.Back)
	if M <= 1.0001 then
		ui.Caption.Text = "NO LUCK THIS TIME..."; ui.Caption.TextColor3 = C.Soft
		sfx(S.Click, 0.4, 0.8)
	else
		ui.Caption.Text = "STOPPED!"; ui.Caption.TextColor3 = row[2]
		flash(ui.Gui, row[2], 0.2)
		shockwave(ui.Stage, row[3])
		sparks(ui.Stage, row[3], 20 + tier * 10, 600)
		sfx(tier >= 3 and S.Legendary or S.Reward, 0.6, 1)
		if tier >= 4 then sfx(S.Confetti, 0.5, 1) end
	end
	if payload.Chimera then
		-- OVERLOAD: the number glitches, the screen tears, then the special pet
		local glyphs = {"#", "%", "@", "&", "?", "!", "X", "0", "7"}
		local t0 = os.clock()
		while os.clock() - t0 < 1.1 do
			local s = "x"
			for _ = 1, 7 do s ..= glyphs[math.random(1, #glyphs)] end
			ui.Number.Text = s
			ui.Stage.Position = UDim2.new(0.5, math.random(-30, 30), 0.48, math.random(-18, 18))
			ui.NumberGrad.Color = RAINBOW; ui.NumberGrad.Rotation = math.random(0, 360)
			if math.random() < 0.3 then flash(ui.Gui, Color3.fromRGB(255, 60, 255), 0.6) end
			RunService.RenderStepped:Wait()
		end
		ui.Number.Text = Config.FormatMultiplier(M)
		ui.Stage.Position = UDim2.fromScale(0.5, 0.48)
	else
		task.wait(0.8)
	end
	tween(eggView, {ImageTransparency = 1}, 0.3)
	if camera then tween(camera, {FieldOfView = fovSaved}, 0.6) end
	tween(cc, {Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1)}, 0.6)
	reveal(ui, payload)
	-- out
	for _, d in ipairs(ui.Gui:GetDescendants()) do
		if d:IsA("TextLabel") then tween(d, {TextTransparency = 1}, 0.3) end
		if d:IsA("ImageLabel") or d:IsA("ViewportFrame") then tween(d, {ImageTransparency = 1}, 0.3) end
		if d:IsA("UIStroke") then tween(d, {Transparency = 1}, 0.3) end
	end
	tween(ui.Dim, {BackgroundTransparency = 1}, 0.3)
	task.wait(0.35)
	ui.Gui:Destroy()
	cc:Destroy()
	if camera then camera.FieldOfView = fovSaved end
	fovSaved = nil
end

-- one at a time: hatches that come in while one plays wait their turn
local queue, running = {}, false
api:WaitForChild("Effect").OnClientEvent:Connect(function(kind, payload)
	if kind ~= "HatchRoll" or type(payload) ~= "table" then return end
	table.insert(queue, payload)
	if running then return end
	running = true
	task.spawn(function()
		while #queue > 0 do
			local item = table.remove(queue, 1)
			local ok, err = pcall(play, item)
			if not ok then
				warn("[PFE] hatch roll: " .. tostring(err))
				local left = player.PlayerGui:FindFirstChild("PFE_HatchRoll")
				if left then left:Destroy() end
				local cc = Lighting:FindFirstChild("PFE_HatchRollCC")
				if cc then cc:Destroy() end
				if workspace.CurrentCamera and fovSaved then workspace.CurrentCamera.FieldOfView = fovSaved end
				fovSaved = nil
			end
		end
		running = false
	end)
end)
