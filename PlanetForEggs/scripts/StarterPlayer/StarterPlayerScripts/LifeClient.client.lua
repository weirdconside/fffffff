--!nocheck
-- (v41) Planet life on screen (the server's side is GameServer.PlanetLife / Caves):
--  * the weather of the planet you stand on: rain, snow, sand, ash, spores, glitches... around the camera, its fog, its
--    loop sound, the wind that pushes you, the weak gravity of a gravity flux, the shaking ground of a quake;
--  * strikes: the red warning circle on the ground, then the meteor / bolt / volcanic bomb / hailstone / comet... and its
--    impact; the boss's slams and throws use the same thing;
--  * what you can smash (crystals, rocks, ice blocks, bombs, cave walls, chests): a health bar over it when it's hit, sparks
--    on every hit, shards when it breaks;
--  * the solar flare's countdown, spore pods' launches, glitch zones, the coin rain, air vents, getting hurt;
--  * floating eggs sit in bubbles, the spirit fog's wisps fly off towards their hidden eggs.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local Life = require(api:WaitForChild("LifeConfig"))
local UI = require(api:WaitForChild("UIKit"))
local player = Players.LocalPlayer
local rng = Random.new()
local C = UI.C

local folder = Instance.new("Folder")
folder.Name = "PFE_LifeFX"
folder.Parent = workspace
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local S = Config.Sounds

local state = {Planet = "Base"}
api:WaitForChild("State").OnClientEvent:Connect(function(payload)
	if type(payload) == "table" and payload.Planet ~= nil then state.Planet = payload.Planet end
end)
local function cave() local c = player:GetAttribute("PFECave"); return type(c) == "string" and c ~= "" end
local function ship() local s = player:GetAttribute("PFEDungeon"); return type(s) == "string" and s ~= "" end
local function flying() return player:GetAttribute("PFEFlightActive") == true end
-- the planet whose weather you're out in (nil: home, aboard a ship, in a cave, flying)
local function outside()
	local id = player:GetAttribute("PFESpectateWorld") or state.Planet
	if not Config.Planets[id] or cave() or ship() or flying() then return nil end
	return id
end
local function myRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- ---------------------------------------------------------------- little helpers
local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = props.Parent or folder
	return p
end
local function sound(id, position, volume, speed, range)
	if not id then return end
	local holder = part({Transparency = 1, Size = Vector3.one, Position = position or Vector3.zero})
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = volume or 0.6; s.PlaybackSpeed = speed or 1
	s.RollOffMaxDistance = range or 300; s.Parent = holder; s:Play()
	Debris:AddItem(holder, 6)
end
local function sound2D(id, volume, speed)
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = volume or 0.5; s.PlaybackSpeed = speed or 1; s.Parent = SoundService
	s:Play(); Debris:AddItem(s, 6)
end
local function burst(position, color, count, size, speed, texture)
	local holder = part({Transparency = 1, Size = Vector3.one, Position = position})
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture or SPARK; e.Color = ColorSequence.new(color); e.LightEmission = 1; e.LightInfluence = 0
	e.Speed = NumberRange.new((speed or 22) * 0.5, speed or 22); e.SpreadAngle = Vector2.new(180, 180); e.Drag = 3
	e.Lifetime = NumberRange.new(0.4, 1); e.Size = NumberSequence.new(size or 1, 0); e.Enabled = false; e.Parent = holder
	e:Emit(count or 24)
	Debris:AddItem(holder, 2)
	return holder
end
local function dust(position, color, count, size)
	local holder = part({Transparency = 1, Size = Vector3.one, Position = position})
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE; e.Color = ColorSequence.new(color or Color3.fromRGB(120, 110, 100)); e.LightInfluence = 1
	e.Speed = NumberRange.new(6, 16); e.SpreadAngle = Vector2.new(180, 40); e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Size = NumberSequence.new(size or 4, (size or 4) * 2.5); e.Transparency = NumberSequence.new(0.3, 1); e.Enabled = false; e.Parent = holder
	e:Emit(count or 12)
	Debris:AddItem(holder, 2.5)
end
local function flashLight(position, color, range, brightness, time)
	local holder = part({Transparency = 1, Size = Vector3.one, Position = position})
	local l = Instance.new("PointLight"); l.Color = color; l.Range = range or 30; l.Brightness = brightness or 4; l.Parent = holder
	TweenService:Create(l, TweenInfo.new(time or 0.6), {Brightness = 0}):Play()
	Debris:AddItem(holder, (time or 0.6) + 0.1)
end
-- a flat disc on the ground
local function disc(at, radius, color, transparency, material)
	return part({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, radius * 2, radius * 2), Color = color, Material = material or Enum.Material.Neon,
		Transparency = transparency or 0.5, CFrame = CFrame.new(at + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2)})
end

-- ---------------------------------------------------------------- the screen layer
local gui = Instance.new("ScreenGui")
gui.Name = "PFE_Life"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")
local vignette = UI.new("Frame", {Name = "Hurt", BackgroundColor3 = Color3.fromRGB(255, 40, 40), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1}, gui)
UI.new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.35, 1),
	NumberSequenceKeypoint.new(0.65, 1), NumberSequenceKeypoint.new(1, 0.1)})}, vignette)
local whiteout = UI.new("Frame", {Name = "Flash", BackgroundColor3 = Color3.fromRGB(255, 250, 235), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2}, gui)
local banner = UI.text(gui, "", UDim2.new(1, -40, 0, 60), UDim2.new(0, 20, 0.3, 0), 46, C.Gold)
banner.Name = "Banner"; banner.TextXAlignment = Enum.TextXAlignment.Center; banner.TextTransparency = 1; banner.TextScaled = true; banner.ZIndex = 5
UI.new("UITextSizeConstraint", {MaxTextSize = 46, MinTextSize = 18}, banner)
local bannerStroke = banner:FindFirstChildOfClass("UIStroke")
local subBanner = UI.text(gui, "", UDim2.new(1, -40, 0, 30), UDim2.new(0, 20, 0.3, 58), 24, C.White)
subBanner.Name = "SubBanner"; subBanner.TextXAlignment = Enum.TextXAlignment.Center; subBanner.TextTransparency = 1; subBanner.TextScaled = true; subBanner.ZIndex = 5
UI.new("UITextSizeConstraint", {MaxTextSize = 24, MinTextSize = 12}, subBanner)
local subStroke = subBanner:FindFirstChildOfClass("UIStroke")
local bannerToken = 0
local function showBanner(title, sub, color, seconds)
	bannerToken += 1
	local token = bannerToken
	banner.Text = title; banner.TextColor3 = color or C.Gold; subBanner.Text = sub or ""
	for _, obj in ipairs({banner, subBanner}) do obj.TextTransparency = 0 end
	for _, s in ipairs({bannerStroke, subStroke}) do if s then s.Transparency = 0 end end
	local pop = banner:FindFirstChildOfClass("UIScale") or UI.new("UIScale", {}, banner)
	pop.Scale = 0.4
	UI.tween(pop, {Scale = 1}, 0.3, Enum.EasingStyle.Back)
	task.delay(seconds or 2.5, function()
		if token ~= bannerToken then return end
		for _, obj in ipairs({banner, subBanner}) do UI.tween(obj, {TextTransparency = 1}, 0.4) end
		for _, s in ipairs({bannerStroke, subStroke}) do if s then UI.tween(s, {Transparency = 1}, 0.4) end end
	end)
end
local function hurtFlash(strength)
	vignette.BackgroundTransparency = math.clamp(0.75 - (strength or 0.3), 0.2, 0.9)
	UI.tween(vignette, {BackgroundTransparency = 1}, 0.45)
end
local function screenFlash(color, from, time)
	whiteout.BackgroundColor3 = color or Color3.fromRGB(255, 250, 235)
	whiteout.BackgroundTransparency = from or 0.3
	UI.tween(whiteout, {BackgroundTransparency = 1}, time or 0.5)
end

-- ---------------------------------------------------------------- strikes
local sky = api:FindFirstChild("Sky")
local function rock(size, color, material)
	return part({Shape = Enum.PartType.Ball, Size = Vector3.one * size, Color = color, Material = material or Enum.Material.Slate})
end
local function trail(p, color, size)
	if p:IsA("Model") then p = p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true) end
	local a0 = Instance.new("Attachment"); a0.Parent = p
	local e = Instance.new("ParticleEmitter")
	e.Texture = FIRE; e.Rate = 80; e.Lifetime = NumberRange.new(0.25, 0.5); e.Speed = NumberRange.new(1, 3); e.LightEmission = 1; e.LightInfluence = 0
	e.Size = NumberSequence.new(size or 3, 0); e.Color = ColorSequence.new(color or Color3.fromRGB(255, 200, 100), Color3.fromRGB(255, 70, 20)); e.Parent = a0
	return e
end
-- something flying from `from` to `to` in `time` s (a straight dive or an arc), then onLand
local function fly(p, from, to, time, arc, onLand, spin)
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - started) / time, 0, 1)
		local pos = from:Lerp(to, arc and t or t * t) + Vector3.new(0, arc and math.sin(t * math.pi) * arc or 0, 0)
		local cf = CFrame.new(pos) * (spin and CFrame.Angles(t * 8, t * 5, 0) or CFrame.identity)
		if p.Parent then if p:IsA("Model") then p:PivotTo(cf) else p.CFrame = cf end end
		if t >= 1 then
			connection:Disconnect()
			if p.Parent then p:Destroy() end
			if onLand then onLand() end
		end
	end)
end
local function meteorModel(scale)
	local template = sky and sky:FindFirstChild("Meteor_C")
	if template then
		local m = template:Clone()
		for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end end
		pcall(function() m:ScaleTo(scale) end)
		m.Parent = folder
		return m
	end
	return rock(4 * scale / 0.35, Color3.fromRGB(70, 50, 40))
end
local function bolt(top, bottom, color)
	local points = {top}
	local steps = 7
	for i = 1, steps - 1 do
		local t = i / steps
		table.insert(points, top:Lerp(bottom, t) + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4)))
	end
	table.insert(points, bottom)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = part({Size = Vector3.new(0.6, 0.6, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = color, Material = Enum.Material.Neon})
		TweenService:Create(seg, TweenInfo.new(0.35), {Transparency = 1}):Play()
		Debris:AddItem(seg, 0.4)
	end
end

local STRIKE_COLOR = {Star = Color3.fromRGB(255, 220, 90), Geyser = Color3.fromRGB(255, 140, 60)}
local function warnCircle(at, radius, delay, kind)
	local color = STRIKE_COLOR[kind] or Color3.fromRGB(255, 40, 40)
	local edge = disc(at, radius, color, 0.35)
	local fill = disc(at + Vector3.new(0, 0.02, 0), 0.5, color, 0.55)
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - started) / delay, 0, 1)
		if not fill.Parent then connection:Disconnect(); return end
		local r = math.max(0.5, radius * t)
		fill.Size = Vector3.new(0.15, r * 2, r * 2)
		edge.Transparency = 0.35 + 0.35 * math.abs(math.sin(os.clock() * 12))
		if t >= 1 then connection:Disconnect() end
	end)
	Debris:AddItem(edge, delay + 0.05); Debris:AddItem(fill, delay + 0.05)
end

local IMPACT = {}
function IMPACT.Meteor(at, radius)
	burst(at + Vector3.new(0, 1, 0), Color3.fromRGB(255, 150, 60), 40, 1.4, 30)
	dust(at, Color3.fromRGB(90, 70, 60), 16, radius * 0.5)
	flashLight(at + Vector3.new(0, 4, 0), Color3.fromRGB(255, 140, 50), radius * 4, 5)
	sound(S.Boom, at, 0.8, 1)
	local scorch = disc(at, radius * 0.7, Color3.fromRGB(35, 25, 25), 0.15, Enum.Material.Slate)
	TweenService:Create(scorch, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 4), {Transparency = 1}):Play()
	Debris:AddItem(scorch, 7.5)
end
IMPACT.VolcanoBomb = IMPACT.Meteor
IMPACT.Comet = function(at, radius) IMPACT.Meteor(at, radius); screenFlash(Color3.fromRGB(255, 200, 120), 0.5, 0.6); sound(S.BigBoom, at, 0.9, 1, 600) end
function IMPACT.Lightning(at)
	bolt(at + Vector3.new(rng:NextNumber(-10, 10), 160, rng:NextNumber(-10, 10)), at, Color3.fromRGB(200, 220, 255))
	burst(at + Vector3.new(0, 1, 0), Color3.fromRGB(170, 200, 255), 30, 1.2, 26)
	flashLight(at + Vector3.new(0, 8, 0), Color3.fromRGB(190, 210, 255), 90, 8, 0.35)
	sound(S.Lightning, at, 0.8, 1, 500)
	task.delay(0.3, function() sound(S.Thunder, at, 0.7, 1, 900) end)
	local root = myRoot()
	if root and (root.Position - at).Magnitude < 160 then screenFlash(Color3.fromRGB(220, 230, 255), 0.55, 0.3) end
end
function IMPACT.Geyser(at, radius)
	local column = part({Size = Vector3.new(radius * 1.2, 2, radius * 1.2), CFrame = CFrame.new(at + Vector3.new(0, 1, 0)), Color = Color3.fromRGB(255, 120, 40),
		Material = Enum.Material.Neon, Transparency = 0.2})
	TweenService:Create(column, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {Size = Vector3.new(radius * 0.9, 34, radius * 0.9), CFrame = CFrame.new(at + Vector3.new(0, 17, 0))}):Play()
	TweenService:Create(column, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.4), {Transparency = 1}):Play()
	Debris:AddItem(column, 1.3)
	dust(at, Color3.fromRGB(220, 200, 190), 20, 5)
	sound(S.Boom, at, 0.5, 1.4)
end
function IMPACT.Star(at)
	burst(at + Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 240, 160), 36, 1.2, 24)
	flashLight(at + Vector3.new(0, 4, 0), Color3.fromRGB(255, 230, 140), 30, 4)
	sound(S.Sparkle, at, 0.7, 1.1)
end
function IMPACT.Hail(at)
	burst(at + Vector3.new(0, 0.5, 0), Color3.fromRGB(230, 245, 255), 10, 0.6, 12)
	sound("rbxasset://sounds/impact_water.mp3", at, 0.25, 1.8, 120)
end
function IMPACT.Stalactite(at, radius)
	burst(at + Vector3.new(0, 1, 0), Color3.fromRGB(140, 130, 120), 20, 1, 18)
	dust(at, Color3.fromRGB(100, 95, 90), 12, 3)
	sound(S.RockCrumble, at, 0.6, 1.4, 160)
end
function IMPACT.BossSlam(at, radius)
	local ring = disc(at, 1, Color3.fromRGB(255, 220, 160), 0.2)
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad), {Size = Vector3.new(0.15, radius * 2.2, radius * 2.2), Transparency = 1}):Play()
	Debris:AddItem(ring, 0.5)
	dust(at, Color3.fromRGB(130, 120, 110), 30, 6)
	sound(S.BigBoom, at, 0.8, 0.8, 500)
	local root = myRoot()
	if root and (root.Position - at).Magnitude < radius * 3 then task.spawn(function() for _ = 1, 8 do workspace.CurrentCamera.CFrame *= CFrame.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.4, 0.4), 0); task.wait() end end) end
end
IMPACT.BossBurst = function(at, radius)
	IMPACT.BossSlam(at, radius)
	for _ = 1, 8 do
		local r = rock(rng:NextNumber(1.5, 3), Color3.fromRGB(110, 90, 70))
		local to = at + Vector3.new(rng:NextNumber(-radius, radius), 0, rng:NextNumber(-radius, radius))
		fly(r, at + Vector3.new(0, 1, 0), to, 0.8, rng:NextNumber(8, 18), nil, true)
	end
end
IMPACT.BossLeap = IMPACT.BossSlam
function IMPACT.BossBoulder(at, radius)
	burst(at + Vector3.new(0, 1, 0), Color3.fromRGB(170, 150, 130), 24, 1.4, 24)
	dust(at, Color3.fromRGB(120, 110, 100), 16, radius * 0.5)
	sound(S.Boom, at, 0.7, 0.9)
end
function IMPACT.BossSnowball(at, radius)
	burst(at + Vector3.new(0, 1, 0), Color3.fromRGB(240, 250, 255), 40, 1.6, 26)
	dust(at, Color3.fromRGB(240, 245, 255), 14, radius * 0.5)
	sound("rbxasset://sounds/impact_water.mp3", at, 0.7, 0.8)
end
function IMPACT.BossSpit(at, radius)
	burst(at + Vector3.new(0, 1, 0), Color3.fromRGB(190, 255, 90), 36, 1.4, 22)
	local puddle = disc(at, radius * 0.8, Color3.fromRGB(150, 230, 70), 0.4)
	TweenService:Create(puddle, TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 1.5), {Transparency = 1}):Play()
	Debris:AddItem(puddle, 3.6)
	sound("rbxasset://sounds/impact_water.mp3", at, 0.7, 0.6)
end

local PROJECTILE = {}
function PROJECTILE.Meteor(at, delay)
	local from = at + Vector3.new(rng:NextNumber(-80, 80), 170, rng:NextNumber(-80, 80))
	local m = meteorModel(0.35)
	trail(m, nil, 4)
	fly(m, from, at, delay, nil, nil, true)
end
function PROJECTILE.Comet(at, delay)
	local from = at + Vector3.new(rng:NextNumber(-300, 300), 400, rng:NextNumber(-300, 300))
	local m = meteorModel(0.9)
	trail(m, Color3.fromRGB(255, 230, 140), 10)
	fly(m, from, at, delay, nil, nil, true)
end
function PROJECTILE.VolcanoBomb(at, delay)
	local a = rng:NextNumber(0, math.pi * 2)
	local from = at + Vector3.new(math.cos(a) * 140, 30, math.sin(a) * 140)
	local b = rock(4.5, Color3.fromRGB(46, 40, 42), Enum.Material.Basalt)
	trail(b, Color3.fromRGB(255, 160, 60), 4)
	fly(b, from, at, delay, 90, nil, true)
end
function PROJECTILE.Star(at, delay)
	local from = at + Vector3.new(rng:NextNumber(-120, 120), 200, rng:NextNumber(-120, 120))
	local s = part({Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Color = Color3.fromRGB(255, 245, 190), Material = Enum.Material.Neon})
	local t = trail(s, Color3.fromRGB(255, 250, 210), 3); t.Texture = SPARK
	fly(s, from, at, delay)
end
function PROJECTILE.Hail(at, delay)
	for i = 1, 3 do
		local off = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
		local h = part({Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(0.8, 1.4), Color = Color3.fromRGB(225, 240, 255), Material = Enum.Material.Ice})
		fly(h, at + off + Vector3.new(0, 90, 0), at + off, delay * (0.85 + i * 0.05))
	end
end
function PROJECTILE.Stalactite(at, delay)
	local spike = Instance.new("WedgePart")
	spike.Anchored = true; spike.CanCollide = false; spike.CanQuery = false; spike.CanTouch = false
	spike.Size = Vector3.new(2.4, 6, 2.4); spike.Color = Color3.fromRGB(110, 100, 95); spike.Material = Enum.Material.Slate; spike.Parent = folder
	local from = at + Vector3.new(0, 22, 0)
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - started - delay * 0.55) / (delay * 0.45), 0, 1)
		spike.CFrame = CFrame.new(from:Lerp(at + Vector3.new(0, 3, 0), t * t)) * CFrame.Angles(math.pi, 0, 0)
		if t >= 1 then connection:Disconnect(); spike:Destroy() end
	end)
end
local function bossProjectile(kind, from, at, delay)
	local look = kind == "BossSnowball" and {Color3.fromRGB(240, 250, 255), Enum.Material.Snow, 4}
		or kind == "BossSpit" and {Color3.fromRGB(170, 255, 80), Enum.Material.Neon, 3}
		or {Color3.fromRGB(110, 100, 90), Enum.Material.Slate, 5}
	local b = rock(look[3], look[1], look[2])
	if kind == "BossSpit" then trail(b, Color3.fromRGB(190, 255, 120), 2.5) end
	fly(b, from, at, delay, math.max(12, (at - from).Magnitude * 0.25), nil, true)
end

local function onStrike(payload)
	local at, kind = payload.Position, payload.Kind
	if typeof(at) ~= "Vector3" or type(kind) ~= "string" then return end
	local delay = tonumber(payload.Delay) or 1.5
	local radius = tonumber(payload.Radius) or 8
	warnCircle(at, radius, delay, kind)
	if PROJECTILE[kind] then PROJECTILE[kind](at, delay)
	elseif typeof(payload.From) == "Vector3" and (kind == "BossBoulder" or kind == "BossSnowball" or kind == "BossSpit") then
		bossProjectile(kind, payload.From, at, delay)
	end
	task.delay(delay, function()
		local impact = IMPACT[kind]
		if impact then impact(at, radius) else burst(at + Vector3.new(0, 1, 0), Color3.fromRGB(255, 120, 80), 20, 1, 20) end
	end)
end

-- ---------------------------------------------------------------- things you smash: bars, sparks, shards
local BREAK_COLOR = {Crystal = nil, IceBlock = Color3.fromRGB(200, 235, 255), LavaBomb = Color3.fromRGB(255, 120, 40), Ore = Color3.fromRGB(255, 205, 70),
	Wall = Color3.fromRGB(150, 140, 130), Chest = Color3.fromRGB(255, 210, 80), Vault = Color3.fromRGB(200, 140, 255), CometCore = Color3.fromRGB(255, 200, 90)}
local function breakColor(kind)
	local planet = Config.Planets[state.Planet]
	return BREAK_COLOR[kind] or (planet and planet.Accent) or Color3.fromRGB(200, 160, 255)
end
local bars = {}
local function watchSmashable(model)
	if bars[model] or not model:IsA("Model") or model:GetAttribute("Boss") then return end
	local core = model.PrimaryPart or model:FindFirstChild("Core")
	if not core then return end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PFE_HP"; gui.Adornee = core; gui.Size = UDim2.fromOffset(150, 40); gui.StudsOffsetWorldSpace = Vector3.new(0, core.Size.Y * 0.5 + 2.5, 0)
	gui.AlwaysOnTop = true; gui.MaxDistance = 70; gui.LightInfluence = 0; gui.Enabled = false; gui.Parent = folder
	local label = UI.text(gui, tostring(model:GetAttribute("Label") or "Crystal"), UDim2.new(1, 0, 0, 20), nil, 16, C.White)
	label.TextXAlignment = Enum.TextXAlignment.Center
	local track = UI.new("Frame", {BackgroundColor3 = C.Ink, BorderSizePixel = 0, Size = UDim2.new(1, -10, 0, 12), Position = UDim2.new(0, 5, 0, 23)}, gui)
	UI.round(track, 6); UI.stroke(track, 2, C.Ink)
	local fill = UI.new("Frame", {BackgroundColor3 = C.Green, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1)}, track)
	UI.round(fill, 6)
	local entry = {Gui = gui, Fill = fill, Model = model}
	bars[model] = entry
	local function refresh()
		local hp, max = model:GetAttribute("HP") or 1, model:GetAttribute("MaxHP") or 1
		local ratio = math.clamp(hp / math.max(1, max), 0, 1)
		gui.Enabled = ratio < 0.999 or model:GetAttribute("Kind") == "Chest" or model:GetAttribute("Kind") == "Vault" or model:GetAttribute("Kind") == "Wall"
		fill.Size = UDim2.fromScale(ratio, 1)
		fill.BackgroundColor3 = ratio > 0.5 and C.Green or ratio > 0.25 and C.Orange or C.Red
	end
	model:GetAttributeChangedSignal("HP"):Connect(refresh)
	refresh()
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then gui:Destroy(); bars[model] = nil end
	end)
end
for _, m in ipairs(CollectionService:GetTagged("PFESmashable")) do task.spawn(watchSmashable, m) end
CollectionService:GetInstanceAddedSignal("PFESmashable"):Connect(function(m) task.defer(watchSmashable, m) end)

-- ---------------------------------------------------------------- the weather around you
local ambientPart = part({Name = "WeatherBox", Transparency = 1, Size = Vector3.new(170, 4, 170)})
local weatherFx = Instance.new("ParticleEmitter")
weatherFx.Shape = Enum.ParticleEmitterShape.Box; weatherFx.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward; weatherFx.Enabled = false
weatherFx.EmissionDirection = Enum.NormalId.Bottom; weatherFx.LightInfluence = 0.6; weatherFx.Parent = ambientPart
local lowDetail = UI.isTouch()
local LOOKS = {
	MeteorRain = {Tex = FIRE, Color = Color3.fromRGB(255, 150, 70), Rate = 30, Size = 0.4, Speed = {20, 30}, Life = 4, Accel = Vector3.new(0, -10, 0), Emit = 1, Tint = Color3.fromRGB(255, 225, 205)},
	Sandstorm = {Tex = SMOKE, Color = Color3.fromRGB(214, 160, 100), Rate = 60, Size = 7, Speed = {10, 20}, Life = 3, Accel = Vector3.new(38, -2, 12), Emit = 0, Transparency = 0.55, Sideways = true,
		Tint = Color3.fromRGB(255, 225, 185), Sound = S.Wind, Volume = 0.6},
	Blizzard = {Tex = SPARK, Color = Color3.fromRGB(255, 255, 255), Rate = 260, Size = 0.45, Speed = {24, 36}, Life = 3, Accel = Vector3.new(16, -12, 5), Emit = 0.3, Sideways = true,
		Tint = Color3.fromRGB(225, 240, 255), Sound = S.Wind, Volume = 0.55},
	Eruption = {Tex = FIRE, Color = Color3.fromRGB(255, 120, 40), Rate = 70, Size = 0.5, Speed = {2, 6}, Life = 5, Accel = Vector3.new(0, 3, 0), Emit = 1, Up = true, Tint = Color3.fromRGB(255, 205, 180)},
	AcidRain = {Tex = "rbxasset://textures/particles/SquareParticle.png", Color = Color3.fromRGB(170, 255, 80), Rate = 220, Size = 0.18, Speed = {70, 90}, Life = 1.4,
		Accel = Vector3.new(0, -20, 0), Emit = 0.6, Stretch = true, Tint = Color3.fromRGB(225, 255, 210), Sound = S.Rain, Volume = 0.5},
	SolarFlare = {Tex = SPARK, Color = Color3.fromRGB(255, 230, 120), Rate = 40, Size = 0.5, Speed = {1, 3}, Life = 4, Accel = Vector3.new(0, 1, 0), Emit = 1, Up = true, Tint = Color3.fromRGB(255, 245, 215)},
	ThunderStorm = {Tex = "rbxasset://textures/particles/SquareParticle.png", Color = Color3.fromRGB(170, 190, 255), Rate = 260, Size = 0.18, Speed = {80, 100}, Life = 1.3,
		Accel = Vector3.new(0, -20, 0), Emit = 0.5, Stretch = true, Tint = Color3.fromRGB(205, 215, 245), Sound = S.Rain, Volume = 0.6},
	Earthquake = {Tex = SMOKE, Color = Color3.fromRGB(150, 120, 100), Rate = 20, Size = 4, Speed = {2, 5}, Life = 3, Accel = Vector3.new(0, 1, 0), Emit = 0, Transparency = 0.7, Up = true,
		Tint = Color3.fromRGB(250, 235, 220), Sound = S.Rumble, Volume = 0.45},
	CrystalBloom = {Tex = SPARK, Color = Color3.fromRGB(230, 160, 255), Rate = 60, Size = 0.5, Speed = {1, 3}, Life = 4, Accel = Vector3.new(0, 1.5, 0), Emit = 1, Up = true, Tint = Color3.fromRGB(245, 230, 255)},
	GravityFlux = {Tex = SPARK, Color = Color3.fromRGB(180, 150, 255), Rate = 50, Size = 0.7, Speed = {1, 2}, Life = 6, Accel = Vector3.new(0, 2.5, 0), Emit = 1, Up = true, Tint = Color3.fromRGB(235, 225, 255)},
	SpiritFog = {Tex = SPARK, Color = Color3.fromRGB(150, 255, 220), Rate = 40, Size = 0.8, Speed = {0.5, 2}, Life = 6, Accel = Vector3.new(0, 0.6, 0), Emit = 1, Up = true,
		Tint = Color3.fromRGB(215, 245, 238), Sound = S.Wind, Volume = 0.3},
	SporeBloom = {Tex = SPARK, Color = Color3.fromRGB(255, 150, 230), Rate = 90, Size = 0.6, Speed = {0.5, 2}, Life = 6, Accel = Vector3.new(0, 0.8, 0), Emit = 0.9, Up = true, Tint = Color3.fromRGB(255, 225, 245)},
	DataGlitch = {Tex = "rbxasset://textures/particles/SquareParticle.png", Color = Color3.fromRGB(60, 240, 255), Rate = 70, Size = 0.4, Speed = {0, 3}, Life = 2, Accel = Vector3.zero, Emit = 1, Up = true,
		Tint = Color3.fromRGB(220, 245, 255)},
	Heatwave = {Tex = SMOKE, Color = Color3.fromRGB(255, 200, 150), Rate = 25, Size = 6, Speed = {2, 5}, Life = 3, Accel = Vector3.new(0, 4, 0), Emit = 0.2, Transparency = 0.85, Up = true,
		Tint = Color3.fromRGB(255, 225, 190), Sound = S.Wind, Volume = 0.25},
	CometShower = {Tex = SPARK, Color = Color3.fromRGB(255, 245, 200), Rate = 30, Size = 0.5, Speed = {2, 4}, Life = 5, Accel = Vector3.new(0, -1, 0), Emit = 1, Tint = Color3.fromRGB(250, 245, 230)},
	Hailstorm = {Tex = SPARK, Color = Color3.fromRGB(230, 240, 255), Rate = 160, Size = 0.35, Speed = {60, 80}, Life = 1.6, Accel = Vector3.new(0, -30, 0), Emit = 0.2,
		Tint = Color3.fromRGB(225, 235, 250), Sound = S.Rain, Volume = 0.45},
}
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "PFE_WeatherGrade"; grade.Parent = Lighting
local loop = Instance.new("Sound")
loop.Name = "PFE_WeatherLoop"; loop.Looped = true; loop.Volume = 0; loop.Parent = SoundService
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local fogSaved = nil           -- the planet's own atmosphere while the weather's fog is on
local function fogOff(restore)
	if fogSaved and restore and atmosphere then TweenService:Create(atmosphere, TweenInfo.new(1.5), fogSaved):Play() end
	fogSaved = nil
end
-- the planet look changes under us (a ship, a cave, a flight, another planet): PlanetClient sets the atmosphere - forget ours
for _, key in ipairs({"PFECave", "PFEDungeon", "PFEFlightActive", "PFESpectateWorld"}) do
	player:GetAttributeChangedSignal(key):Connect(function() fogOff(false) end)
end
local lastPlanet
api:WaitForChild("State").OnClientEvent:Connect(function(payload)
	if type(payload) == "table" and payload.Planet ~= nil and payload.Planet ~= lastPlanet then lastPlanet = payload.Planet; fogOff(false) end
end)

local currentLook, currentWeather
local function setLook(id)
	if id == currentWeather then return end
	currentWeather = id
	local look = id and LOOKS[id]
	currentLook = look
	if not look then
		weatherFx.Enabled = false
		TweenService:Create(loop, TweenInfo.new(1.2), {Volume = 0}):Play()
		return
	end
	weatherFx.Texture = look.Tex; weatherFx.Color = ColorSequence.new(look.Color)
	weatherFx.Rate = lowDetail and look.Rate * 0.45 or look.Rate
	weatherFx.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, look.Size), NumberSequenceKeypoint.new(1, look.Size * 0.8)})
	weatherFx.Speed = NumberRange.new(look.Speed[1], look.Speed[2]); weatherFx.Lifetime = NumberRange.new(look.Life * 0.6, look.Life)
	weatherFx.Acceleration = look.Accel; weatherFx.LightEmission = look.Emit
	weatherFx.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, look.Transparency or 0.15), NumberSequenceKeypoint.new(1, 1)})
	weatherFx.EmissionDirection = look.Up and Enum.NormalId.Top or Enum.NormalId.Bottom
	weatherFx.SpreadAngle = look.Sideways and Vector2.new(40, 40) or Vector2.new(look.Up and 180 or 6, look.Up and 180 or 6)
	weatherFx.Rotation = NumberRange.new(0, 360); weatherFx.RotSpeed = NumberRange.new(-60, 60)
	pcall(function() weatherFx.Squash = NumberSequence.new(look.Stretch and -3 or 0) end)
	weatherFx.Enabled = true
	if look.Sound then
		if loop.SoundId ~= look.Sound then loop.SoundId = look.Sound end
		if not loop.IsPlaying then loop:Play() end
		TweenService:Create(loop, TweenInfo.new(1.5), {Volume = look.Volume or 0.4}):Play()
	else
		TweenService:Create(loop, TweenInfo.new(1.2), {Volume = 0}):Play()
	end
end

local shakeOn = false
pcall(function()
	RunService:BindToRenderStep("PFEQuake", Enum.RenderPriority.Camera.Value + 2, function()
		if not shakeOn then return end
		local camera = workspace.CurrentCamera
		local t = os.clock()
		camera.CFrame *= CFrame.new(math.noise(t * 9, 1) * 0.35, math.noise(t * 9, 2) * 0.3, 0) * CFrame.Angles(0, 0, math.noise(t * 7, 3) * 0.01)
	end)
end)

local windClock = 0
local gravitySet = false
RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local planetId = outside()
	local id = planetId and workspace:GetAttribute("PFEWeather_" .. planetId)
	local def = id and Life.Weather[id]
	setLook(def and id or nil)
	local camPos = camera.CFrame.Position
	ambientPart.CFrame = CFrame.new(camPos + Vector3.new(0, currentLook and currentLook.Up and -20 or 45, 0))
	-- the colour of the weather
	grade.TintColor = grade.TintColor:Lerp(currentLook and currentLook.Tint or Color3.new(1, 1, 1), math.min(1, dt * 1.5))
	-- fog
	if def and def.Fog and atmosphere then
		if not fogSaved then
			fogSaved = {Density = atmosphere.Density, Color = atmosphere.Color, Haze = atmosphere.Haze, Offset = atmosphere.Offset}
			TweenService:Create(atmosphere, TweenInfo.new(2), {Density = def.Fog.Density, Color = def.Fog.Color, Haze = 1.5, Offset = 0.15}):Play()
		end
	elseif fogSaved then
		fogOff(true)
	end
	-- the quake shakes the camera
	shakeOn = def ~= nil and def.Shake == true
	-- weak gravity (and back to the planet's own)
	local planet = planetId and Config.Planets[planetId]
	if planet and def and def.Gravity then
		local want = Config.BaseGravity * planet.Gravity * def.Gravity
		if math.abs(workspace.Gravity - want) > 0.5 then workspace.Gravity = want end
		gravitySet = true
	elseif gravitySet then
		gravitySet = false
		if planet and not player:GetAttribute("PFESpectateWorld") then workspace.Gravity = Config.BaseGravity * planet.Gravity end
	end
	-- the wind pushes you about (not while sheltered)
	if def and def.Wind and player:GetAttribute("PFESheltered") ~= true then
		windClock += dt
		local root = myRoot()
		if root and not root.Anchored then
			local a = ((workspace:GetAttribute("PFEWeatherEnds_" .. planetId) or 0) * 7.3) % (math.pi * 2) + math.sin(windClock * 0.3) * 0.6
			local gust = 0.6 + 0.4 * math.max(0, math.sin(windClock * 1.3))
			root:ApplyImpulse(Vector3.new(math.cos(a), 0, math.sin(a)) * root.AssemblyMass * def.Wind * gust * dt * 1.6)
		end
	end
end)

-- ---------------------------------------------------------------- floating eggs in bubbles, the spirit fog's wisps
local pickups = workspace:WaitForChild("PFE_Pickups", 30)
local bubbles = {}
local wispClock = 0
task.spawn(function()
	while true do
		task.wait(0.5)
		local planetId = outside()
		local pool = pickups and planetId and pickups:FindFirstChild(planetId)
		local keep = {}
		if pool then
			for _, item in ipairs(pool:GetChildren()) do
				if item:GetAttribute("Look") == "Float" then
					keep[item] = true
					if not bubbles[item] then
						local proxy = item:FindFirstChild("Pickup")
						if proxy then
							local ball = part({Shape = Enum.PartType.Ball, Size = Vector3.one * 7, CFrame = proxy.CFrame, Color = Color3.fromRGB(190, 170, 255),
								Material = Enum.Material.ForceField, Transparency = 0.1})
							bubbles[item] = ball
						end
					end
				end
			end
			-- the wisps: every few seconds one flies from you towards the nearest wisp egg
			wispClock += 0.5
			local root = myRoot()
			if wispClock >= 3.5 and root then
				wispClock = 0
				local best, bestD
				for _, item in ipairs(pool:GetChildren()) do
					local proxy = item:GetAttribute("Look") == "Wisp" and item:FindFirstChild("Pickup")
					if proxy then
						local d = (proxy.Position - root.Position).Magnitude
						if d < 260 and (not bestD or d < bestD) then best, bestD = proxy, d end
					end
				end
				if best then
					local wisp = part({Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, Color = Color3.fromRGB(170, 255, 230), Material = Enum.Material.Neon,
						CFrame = CFrame.new(root.Position + Vector3.new(0, 4, 0))})
					local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(150, 255, 220); l.Range = 14; l.Brightness = 2; l.Parent = wisp
					local t = trail(wisp, Color3.fromRGB(170, 255, 230), 1.2); t.Texture = SPARK
					local to = root.Position + (best.Position - root.Position).Unit * math.min(bestD, 60) + Vector3.new(0, 3, 0)
					fly(wisp, wisp.Position, to, 2.2, 3)
				end
			end
		end
		for item, ball in pairs(bubbles) do
			if not keep[item] or not item.Parent then ball:Destroy(); bubbles[item] = nil end
		end
	end
end)
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for item, ball in pairs(bubbles) do
		local proxy = item.Parent and item:FindFirstChild("Pickup")
		if proxy then ball.CFrame = proxy.CFrame * CFrame.new(0, 0.3 + math.sin(t * 2) * 0.15, 0) end
	end
end)

-- coins of the Coin Rain spin
local lifeFolder = workspace:WaitForChild("PFE_PlanetLife", 30)
RunService.Heartbeat:Connect(function()
	if not lifeFolder then return end
	local planetId = outside()
	local f = planetId and lifeFolder:FindFirstChild(planetId)
	if not f then return end
	local t = os.clock()
	for _, c in ipairs(f:GetChildren()) do
		if c.Name == "Coin" and c:IsA("BasePart") then
			c.CFrame = CFrame.new(c.Position) * CFrame.Angles(0, t * 3, 0) * CFrame.Angles(0, 0, 0)
		end
	end
end)

-- ---------------------------------------------------------------- what the server says
local flareToken = 0
api:WaitForChild("Effect").OnClientEvent:Connect(function(kind, payload)
	if type(payload) ~= "table" then payload = {} end
	if kind == "LifeStrike" then onStrike(payload)
	elseif kind == "LifeHit" and typeof(payload.Position) == "Vector3" then
		burst(payload.Position, breakColor(payload.Kind), 12, 0.8, 18)
		if payload.How == "Laser" then sound(S.LaserHit, payload.Position, 0.4, 1.2, 150) else sound(S.BatHit, payload.Position, 0.5, 1.1, 150) end
	elseif kind == "LifeShatter" and typeof(payload.Position) == "Vector3" then
		local color = breakColor(payload.Kind)
		if payload.Fade then burst(payload.Position, color, 14, 0.8, 8); return end
		burst(payload.Position, color, 46, 1.6, 34)
		dust(payload.Position, color:Lerp(Color3.fromRGB(90, 90, 90), 0.5), 10, 3)
		flashLight(payload.Position, color, 30, 4)
		for _ = 1, 6 do
			local shard = part({Size = Vector3.new(0.6, rng:NextNumber(1, 2.4), 0.6), Color = color, Material = Enum.Material.Glass, Transparency = 0.2,
				CFrame = CFrame.new(payload.Position) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)})
			fly(shard, payload.Position, payload.Position + Vector3.new(rng:NextNumber(-9, 9), -2, rng:NextNumber(-9, 9)), 0.7, rng:NextNumber(4, 9), nil, true)
		end
		sound(payload.Kind == "Wall" and S.RockCrumble or payload.Kind == "Chest" and S.ChestOpen or payload.Kind == "Vault" and S.Jackpot or S.Sparkle,
			payload.Position, 0.8, payload.Kind == "Wall" and 1.2 or 1)
	elseif kind == "LifeSprout" and typeof(payload.Position) == "Vector3" then
		burst(payload.Position + Vector3.new(0, 1, 0), breakColor(payload.Kind), 20, 1, 14)
		sound(S.Sparkle, payload.Position, 0.4, 1.3, 150)
	elseif kind == "LifeHurt" then
		hurtFlash(math.clamp((tonumber(payload.Amount) or 5) / 40, 0.1, 0.5))
	elseif kind == "FlareWarn" then
		flareToken += 1
		local token = flareToken
		local at = tonumber(payload.At) or (workspace:GetServerTimeNow() + 5)
		task.spawn(function()
			while token == flareToken do
				local left = math.ceil(at - workspace:GetServerTimeNow())
				if left <= 0 then break end
				local safe = player:GetAttribute("PFESheltered") == true
				showBanner("SOLAR FLARE IN " .. left .. "!", safe and "You're in the shade - stay there!" or "Get under a shade rock!", safe and C.Green or C.Orange, 1.1)
				sound2D(S.Tick, 0.4, 1.3)
				task.wait(1)
			end
		end)
	elseif kind == "Flare" then
		screenFlash(Color3.fromRGB(255, 245, 200), 0.05, 1.4)
		sound2D(S.BigBoom, 0.5, 1.4)
	elseif kind == "Launch" and typeof(payload.Velocity) == "Vector3" then
		local root = myRoot()
		if root then
			root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z) + payload.Velocity
			burst(root.Position - Vector3.new(0, 3, 0), Color3.fromRGB(255, 150, 230), 24, 1, 20)
			sound2D("rbxasset://sounds/action_jump.mp3", 0.6, 0.8)
		end
	elseif kind == "Glitch" then
		task.spawn(function()
			for i = 1, 6 do
				screenFlash(i % 2 == 0 and Color3.fromRGB(60, 240, 255) or Color3.fromRGB(255, 60, 200), 0.6, 0.08)
				task.wait(0.06)
			end
		end)
		sound2D(S.Teleport, 0.5, 1.4)
	elseif kind == "LifeCoinDrop" and typeof(payload.Position) == "Vector3" then
		burst(payload.Position, Color3.fromRGB(255, 220, 90), 10, 0.7, 12)
	elseif kind == "LifeCoinTaken" and typeof(payload.Position) == "Vector3" then
		burst(payload.Position, Color3.fromRGB(255, 220, 90), 18, 0.8, 16)
	elseif kind == "AirVent" then
		screenFlash(Color3.fromRGB(150, 230, 255), 0.6, 0.6)
		sound2D("rbxasset://sounds/impact_water.mp3", 0.6, 1.3)
	elseif kind == "CaveEnter" then
		showBanner(string.upper(tostring(payload.Name or "Cave")), "Pitch dark down there - take out your flashlight (F). The deeper, the better the loot!", Color3.fromRGB(255, 200, 110), 4)
		sound2D(S.RockCrumble, 0.4, 0.8)
	elseif kind == "CaveExit" then
		showBanner("BACK ON THE SURFACE", "", C.White, 1.6)
	end
end)

-- a new weather on your planet: its name and what to do
local announced = {}
local function announceWeather()
	local planetId = outside()
	if not planetId then return end
	local id = workspace:GetAttribute("PFEWeather_" .. planetId)
	local def = id and Life.Weather[id]
	local key = planetId .. ":" .. tostring(workspace:GetAttribute("PFEWeatherEnds_" .. planetId))
	if def and not announced[key] then
		announced[key] = true
		showBanner(string.upper(def.Name), def.Hint, def.Color, 3.2)
	end
end
workspace.AttributeChanged:Connect(function(name)
	if string.sub(name, 1, 11) == "PFEWeather_" then task.defer(announceWeather) end
end)
api:WaitForChild("State").OnClientEvent:Connect(function() task.delay(2.6, announceWeather) end)
