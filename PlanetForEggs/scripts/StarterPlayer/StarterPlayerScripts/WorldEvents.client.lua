--!nocheck
-- World event visuals on the planets.
--  EventStrike (from the server): a fiery meteor slams into an egg (MeteorShower), a golden beam
--  turns an egg golden (GoldenHour), an egg drops out of the sky onto its spot (EggStorm).
--  While an event runs the sky shows it: meteor streaks, falling stars, golden sparkles or aurora
--  ribbons, plus a colour grade.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local ModelUtil = require(api:WaitForChild("ModelUtil"))
local sky = api:WaitForChild("Sky")
local player = Players.LocalPlayer
local rng = Random.new()

local folder = Instance.new("Folder")
folder.Name = "PFE_EventFX"
folder.Parent = workspace
local onPlanet, currentPlanet = false, "Base"
api:WaitForChild("State").OnClientEvent:Connect(function(payload)
	if type(payload) == "table" and payload.Planet ~= nil then
		onPlanet = Config.Planets[payload.Planet] ~= nil
		currentPlanet = payload.Planet
	end
end)

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	for k, v in pairs(props) do p[k] = v end
	p.Parent = folder
	return p
end
local function sound(id, volume, speed, position)
	local holder = part({Transparency = 1, Size = Vector3.one, Position = position or Vector3.zero})
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = volume; s.PlaybackSpeed = speed or 1
	s.RollOffMaxDistance = 260; s.Parent = holder; s:Play()
	Debris:AddItem(holder, 4)
end
local function burst(position, color, count, size)
	local holder = part({Transparency = 1, Size = Vector3.one, Position = position})
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"; sparks.Color = ColorSequence.new(color)
	sparks.LightEmission = 1; sparks.Speed = NumberRange.new(14, 30); sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Lifetime = NumberRange.new(0.5, 1.1); sparks.Size = NumberSequence.new(size or 1.2, 0); sparks.Drag = 3
	sparks.Enabled = false; sparks.Parent = holder
	sparks:Emit(count or 30)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"; smoke.Color = ColorSequence.new(Color3.fromRGB(90, 80, 80))
	smoke.Speed = NumberRange.new(6, 12); smoke.SpreadAngle = Vector2.new(180, 60); smoke.Lifetime = NumberRange.new(0.8, 1.4)
	smoke.Size = NumberSequence.new(3, 9); smoke.Transparency = NumberSequence.new(0.3, 1); smoke.Enabled = false; smoke.Parent = holder
	smoke:Emit(math.floor((count or 30) / 3))
	local light = Instance.new("PointLight"); light.Color = color; light.Range = 26; light.Brightness = 4; light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.8), {Brightness = 0}):Play()
	Debris:AddItem(holder, 2.5)
end

-- a burning rock flying from `from` to `to` in `duration` seconds
local function flyingMeteor(from, to, duration, scale, onLand)
	local template = sky:FindFirstChild("Meteor_C")
	local model = template and template:Clone() or Instance.new("Model")
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false end
	end
	if template then pcall(function() model:ScaleTo(scale) end) end
	model.Parent = folder
	local core = model:FindFirstChildWhichIsA("BasePart", true) or part({Size = Vector3.new(2, 2, 2), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 120, 40)})
	local attachment = Instance.new("Attachment"); attachment.Parent = core
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"; fire.Rate = 90; fire.Lifetime = NumberRange.new(0.3, 0.6)
	fire.Speed = NumberRange.new(1, 3); fire.LightEmission = 1; fire.Size = NumberSequence.new(4 * scale, 0)
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 70, 20)); fire.Parent = attachment
	local started = os.clock()
	local spin = CFrame.Angles(rng:NextNumber(-3, 3), rng:NextNumber(-3, 3), 0)
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - started) / duration, 0, 1)
		local position = from:Lerp(to, t * t)
		model:PivotTo(CFrame.new(position) * CFrame.Angles(t * 6, t * 4, 0) * spin)
		if t >= 1 then
			connection:Disconnect()
			fire.Enabled = false
			model:Destroy()
			if onLand then onLand() end
		end
	end)
end

local function myPickupNear(position)
	local pickups = workspace:FindFirstChild("PFE_Pickups")
	local pool = pickups and pickups:FindFirstChild(currentPlanet)
	if not pool then return nil end
	for _, item in ipairs(pool:GetChildren()) do
		local proxy = item:FindFirstChild("Pickup")
		if proxy and (proxy.Position - Vector3.new(0, 1.9, 0) - position).Magnitude < 1 then return item end
	end
	return nil
end

api:WaitForChild("Effect").OnClientEvent:Connect(function(kind, payload)
	if kind ~= "EventStrike" or type(payload) ~= "table" or typeof(payload.Position) ~= "Vector3" then return end
	local target = payload.Position
	local delayTime = tonumber(payload.Delay) or 1
	if payload.Kind == "Meteor" then
		local from = target + Vector3.new(rng:NextNumber(-60, 60), 140, rng:NextNumber(-60, 60))
		flyingMeteor(from, target + Vector3.new(0, 1, 0), delayTime, 0.35, function()
			burst(target + Vector3.new(0, 1, 0), Color3.fromRGB(255, 150, 60), 40)
			sound(Config.Sounds.Boom, 0.7, 1, target)
			local scorch = part({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 7, 7), Color = Color3.fromRGB(40, 30, 30),
				CFrame = CFrame.new(target + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2)})
			TweenService:Create(scorch, TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 3), {Transparency = 1}):Play()
			Debris:AddItem(scorch, 6)
		end)
	elseif payload.Kind == "Golden" then
		local beam = part({Size = Vector3.new(2.4, 120, 2.4), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 214, 90), Transparency = 0.35,
			CFrame = CFrame.new(target + Vector3.new(0, 60, 0))})
		TweenService:Create(beam, TweenInfo.new(delayTime + 0.4), {Transparency = 1, Size = Vector3.new(0.2, 120, 0.2)}):Play()
		Debris:AddItem(beam, delayTime + 0.5)
		task.delay(delayTime, function()
			burst(target + Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 220, 90), 26, 1)
			sound(Config.Sfx.Sparkle, 0.6, 1.1, target)
		end)
	elseif payload.Kind == "EggDrop" then
		local item = myPickupNear(target)
		local visual = item and item:FindFirstChild("Visual")
		if not visual then return end
		local ghost = visual:Clone()
		for _, p in ipairs(visual:GetDescendants()) do if p:IsA("BasePart") then p.LocalTransparencyModifier = 1 end end
		ghost.Parent = folder
		local landing = ghost:GetPivot()
		local started = os.clock()
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local t = math.clamp((os.clock() - started) / delayTime, 0, 1)
			ghost:PivotTo(landing + Vector3.new(0, 70 * (1 - t * t), 0))
			if t >= 1 then
				connection:Disconnect()
				ghost:Destroy()
				for _, p in ipairs(visual:GetDescendants()) do if p:IsA("BasePart") then p.LocalTransparencyModifier = 0 end end
				burst(target + Vector3.new(0, 1, 0), Color3.fromRGB(160, 230, 255), 18, 0.8)
				sound("rbxasset://sounds/action_jump_land.mp3", 0.5, 1.2, target)
			end
		end)
	elseif payload.Kind == "Pumpkin" then
		-- (v29 Pumpkin Night) the jack-o-lantern bursts out of the ground in a swirl of purple smoke
		local item = myPickupNear(target)
		local pumpkin = item and item:FindFirstChild("Pumpkin")
		if pumpkin then
			local home = pumpkin:GetPivot()
			pumpkin:PivotTo(home * CFrame.new(0, -4, 0))
			local started = os.clock()
			local connection
			connection = RunService.RenderStepped:Connect(function()
				local t = math.clamp((os.clock() - started) / 0.5, 0, 1)
				if not pumpkin.Parent then connection:Disconnect(); return end
				local bounce = math.sin(t * math.pi) * 1.2
				pumpkin:PivotTo(home * CFrame.new(0, -4 * (1 - t) + bounce, 0))
				if t >= 1 then connection:Disconnect(); pumpkin:PivotTo(home) end
			end)
		end
		burst(target + Vector3.new(0, 1.5, 0), Color3.fromRGB(190, 110, 255), 26, 1.1)
		burst(target + Vector3.new(0, 1, 0), Color3.fromRGB(255, 150, 40), 16, 0.8)
		sound(Config.Sfx.Sparkle, 0.5, 0.8, target)
	elseif payload.Kind == "Vanish" then
		burst(target, Color3.fromRGB(170, 120, 255), 30, 1.4)
		sound(Config.Sfx.Sparkle, 0.4, 0.6, target)
	end
end)

-- ---------------------------------------------------------------- ambient sky while an event runs
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "PFE_EventGrade"; grade.Parent = Lighting
local ambient = part({Transparency = 1, Size = Vector3.new(160, 1, 160)})
local motes = Instance.new("ParticleEmitter")
motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"; motes.Rate = 0; motes.Lifetime = NumberRange.new(3, 5)
motes.Speed = NumberRange.new(2, 5); motes.EmissionDirection = Enum.NormalId.Bottom; motes.LightEmission = 1
motes.Size = NumberSequence.new(0.5, 0); motes.Shape = Enum.ParticleEmitterShape.Box; motes.Parent = ambient
local ribbons = {}
local streakClock = 0
local TINTS = {
	MeteorShower = {Tint = Color3.fromRGB(255, 225, 205), Motes = nil},
	GoldenHour = {Tint = Color3.fromRGB(255, 236, 190), Motes = Color3.fromRGB(255, 214, 90)},
	Starfall = {Tint = Color3.fromRGB(225, 220, 255), Motes = Color3.fromRGB(200, 190, 255)},
	EggStorm = {Tint = Color3.fromRGB(225, 240, 255), Motes = Color3.fromRGB(170, 230, 255)},
	Aurora = {Tint = Color3.fromRGB(210, 255, 238), Motes = Color3.fromRGB(110, 255, 200)},
	PumpkinNight = {Tint = Color3.fromRGB(255, 196, 150), Motes = Color3.fromRGB(255, 140, 40)},
}
-- (v29 Pumpkin Night) a blood-orange moon low in the sky and flocks of bats circling the explorer
local nightBats, bloodMoon = {}, nil
local function setPumpkinNight(on, camPos)
	if on and #nightBats == 0 then
		bloodMoon = part({Shape = Enum.PartType.Ball, Size = Vector3.new(90, 90, 90), Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 120, 40), Transparency = 0.15})
		for i = 1, 14 do
			local m = Instance.new("Model")
			local body = part({Size = Vector3.new(1, 0.8, 1.3), Color = Color3.fromRGB(26, 16, 34)})
			local l = part({Size = Vector3.new(2, 0.14, 1), Color = Color3.fromRGB(26, 16, 34)})
			local r = part({Size = Vector3.new(2, 0.14, 1), Color = Color3.fromRGB(26, 16, 34)})
			body.Parent = m; l.Parent = m; r.Parent = m; m.Parent = folder
			table.insert(nightBats, {Model = m, Body = body, L = l, R = r, Radius = rng:NextNumber(18, 46), Height = rng:NextNumber(14, 34),
				Speed = rng:NextNumber(0.5, 1.1) * (i % 2 == 0 and 1 or -1), Phase = rng:NextNumber(0, math.pi * 2)})
		end
	elseif not on and #nightBats > 0 then
		for _, b in ipairs(nightBats) do b.Model:Destroy() end
		nightBats = {}
		if bloodMoon then bloodMoon:Destroy(); bloodMoon = nil end
	end
	if on and camPos then
		local clock = os.clock()
		bloodMoon.CFrame = CFrame.new(camPos + Vector3.new(-700, 260, -900))
		for _, b in ipairs(nightBats) do
			local a = b.Phase + clock * b.Speed
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local centre = root and root.Position or camPos
			local pos = centre + Vector3.new(math.cos(a) * b.Radius, b.Height + math.sin(clock * 2 + b.Phase) * 2, math.sin(a) * b.Radius)
			local ahead = centre + Vector3.new(math.cos(a + 0.1 * math.sign(b.Speed)) * b.Radius, b.Height, math.sin(a + 0.1 * math.sign(b.Speed)) * b.Radius)
			local cf = CFrame.lookAt(pos, Vector3.new(ahead.X, pos.Y, ahead.Z))
			local flap = math.sin(clock * 16 + b.Phase) * 0.7
			b.Body.CFrame = cf
			b.L.CFrame = cf * CFrame.new(-0.6, 0, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-0.8, 0, 0)
			b.R.CFrame = cf * CFrame.new(0.6, 0, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(0.8, 0, 0)
		end
	end
end
local function activeEvent()
	local id = workspace:GetAttribute("PFEEvent")
	if onPlanet and Config.Events[id] and (workspace:GetAttribute("PFEEventEndsAt") or 0) > workspace:GetServerTimeNow() then return id end
	return nil
end
local function setRibbons(on)
	if on and #ribbons == 0 then
		for i = 1, 5 do
			local ribbon = part({Size = Vector3.new(260, 26, 1), Material = Enum.Material.Neon, Transparency = 0.8,
				Color = i % 2 == 0 and Color3.fromRGB(90, 255, 190) or Color3.fromRGB(140, 120, 255)})
			table.insert(ribbons, {Part = ribbon, Phase = i * 1.3})
		end
	elseif not on and #ribbons > 0 then
		for _, r in ipairs(ribbons) do r.Part:Destroy() end
		ribbons = {}
	end
end

RunService.RenderStepped:Connect(function(dt)
	local id = activeEvent()
	local look = id and TINTS[id]
	grade.TintColor = grade.TintColor:Lerp(look and look.Tint or Color3.new(1, 1, 1), math.min(1, dt * 2))
	local camera = workspace.CurrentCamera
	if not camera then return end
	local camPos = camera.CFrame.Position
	ambient.CFrame = CFrame.new(camPos + Vector3.new(0, 40, 0))
	motes.Rate = look and look.Motes and 60 or 0
	if look and look.Motes then motes.Color = ColorSequence.new(look.Motes) end
	setRibbons(id == "Aurora")
	setPumpkinNight(id == "PumpkinNight", camPos)
	for _, r in ipairs(ribbons) do
		local t = os.clock() * 0.2 + r.Phase
		r.Part.CFrame = CFrame.new(camPos + Vector3.new(math.sin(t) * 60, 150 + r.Phase * 8, -180 + r.Phase * 30))
			* CFrame.Angles(math.rad(-25 + math.sin(t * 1.7) * 8), math.rad(r.Phase * 20), math.rad(math.sin(t) * 12))
		r.Part.Transparency = 0.72 + 0.12 * math.sin(t * 2)
	end
	-- meteor streaks / falling stars crossing the sky
	if id == "MeteorShower" or id == "Starfall" then
		streakClock += dt
		if streakClock > (id == "MeteorShower" and 0.35 or 0.2) then
			streakClock = 0
			local start = camPos + Vector3.new(rng:NextNumber(-250, 250), rng:NextNumber(160, 230), rng:NextNumber(-250, 250))
			local finish = start + Vector3.new(rng:NextNumber(-120, 120), -rng:NextNumber(120, 180), rng:NextNumber(-120, 120))
			if id == "MeteorShower" then
				flyingMeteor(start, finish, rng:NextNumber(1.2, 1.8), rng:NextNumber(0.15, 0.3))
			else
				local star = part({Size = Vector3.new(0.4, 0.4, 14), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 250, 220),
					CFrame = CFrame.lookAt(start, finish)})
				TweenService:Create(star, TweenInfo.new(1, Enum.EasingStyle.Linear), {CFrame = CFrame.lookAt(finish, finish + (finish - start)), Transparency = 1}):Play()
				Debris:AddItem(star, 1.1)
			end
		end
	end
end)

-- ---------------------------------------------------------------- meteor-made treasures
-- An egg a meteor turned into something special (the server marks it MeteorGlow) shines through
-- walls for everyone on that planet until the Meteor Shower ends.
local glows = {}
task.spawn(function()
	while true do
		task.wait(0.3)
		local active = workspace:GetAttribute("PFEEvent") == "MeteorShower"
		local pickups = workspace:FindFirstChild("PFE_Pickups")
		local pool = active and pickups and pickups:FindFirstChild(currentPlanet)
		local keep = {}
		if pool then
			for _, item in ipairs(pool:GetChildren()) do
				if item:GetAttribute("MeteorGlow") then
					keep[item] = true
					local highlight = glows[item]
					local visual = item:FindFirstChild("Visual")
					if not highlight or not highlight.Parent then
						local rarity = Config.Rarities[item:GetAttribute("Rarity") or "Common"]
						highlight = Instance.new("Highlight")
						highlight.Name = "PFEMeteorGlow"
						highlight.FillColor = rarity and rarity.Color or Color3.fromRGB(255, 200, 80)
						highlight.OutlineColor = Color3.new(1, 1, 1)
						highlight.FillTransparency = 0.35
						highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						highlight.Parent = folder
						glows[item] = highlight
					end
					if highlight.Adornee ~= visual then highlight.Adornee = visual end
				end
			end
		end
		for item, highlight in pairs(glows) do
			if not keep[item] then highlight:Destroy(); glows[item] = nil end
		end
	end
end)
