--!nocheck
-- Planted eggs, Steal an Egg style:
--  * a freshly planted egg pops out of the ground in a burst of dirt and leaves a dug-up
--    dirt patch under it that fades away after a few seconds;
--  * it then grows smoothly from a sprout to full size while it incubates;
--  * now and then a growing egg hops and wiggles, a ready egg pulses;
--  * a skipped egg shoots up to full size;
--  * Steal an Egg's egg effects (glow, aura, halo) by rarity, scaled to the egg.
-- The egg model is drawn here from UIAssets.Eggs (the server's object only anchors the prompts and
-- carries the timers and sizes as attributes), so it is always whole and the right size at once.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local ModelUtil = require(api:WaitForChild("ModelUtil"))
local world = workspace:WaitForChild("PlanetForEggs")
local library = api:WaitForChild("UIAssets"):WaitForChild("Eggs")

local DIRT = {Color3.fromRGB(101, 67, 33), Color3.fromRGB(92, 60, 28), Color3.fromRGB(110, 75, 40), Color3.fromRGB(85, 55, 25)}
local EMERGE = 0.75
local HOP = 0.55
local tracked = {}
local emerged = {}          -- egg ids that already played their planting pop
local rng = Random.new()

local function now() return workspace:GetServerTimeNow() end
local function sound(id, volume, speed, parent)
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = volume; s.PlaybackSpeed = speed or 1
	s.RollOffMaxDistance = 90; s.Parent = parent; s:Play(); Debris:AddItem(s, 4)
end
local function backOut(t)
	local c1 = 1.70158
	return 1 + (c1 + 1) * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end
local function progressOf(object)
	local readyAt = object:GetAttribute("ReadyAt") or 0
	local duration = math.max(1, object:GetAttribute("Duration") or 1)
	return math.clamp(1 - (readyAt - now()) / duration, 0, 1)
end

-- ---------------------------------------------------------------- dirt
local function block(size, cf, color, parent)
	local part = Instance.new("Part")
	part.Size = size; part.CFrame = cf; part.Color = color; part.Material = Enum.Material.Plastic
	part.Anchored = true; part.CanCollide = false; part.CanQuery = false; part.CanTouch = false; part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth; part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end
local function fade(parts, delay, duration)
	task.delay(delay, function()
		for _, part in ipairs(parts) do
			if part.Parent then TweenService:Create(part, TweenInfo.new(duration), {Transparency = 1}):Play() end
		end
		task.wait(duration + 0.1)
		for _, part in ipairs(parts) do part:Destroy() end
	end)
end
local function dirtPatch(point, width)
	local folder = Instance.new("Folder"); folder.Name = "PFE_DirtPatch"; folder.Parent = workspace
	local parts = {}
	-- the dug-up hole: a dark stepped patch with a lighter rim of clumps
	local d = math.max(3.2, width * 1.8)
	table.insert(parts, block(Vector3.new(0.12, d, d), CFrame.new(point + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2), DIRT[4], folder))
	parts[1].Shape = Enum.PartType.Cylinder
	table.insert(parts, block(Vector3.new(0.14, d * 0.62, d * 0.62), CFrame.new(point + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(62, 40, 18), folder))
	parts[2].Shape = Enum.PartType.Cylinder
	for i = 1, 9 do
		local a = i / 9 * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local r = d * 0.5 + rng:NextNumber(-0.15, 0.25)
		local s = rng:NextNumber(0.3, 0.6) * math.clamp(width / 2.4, 0.8, 2.5)
		table.insert(parts, block(Vector3.new(s, s * 0.7, s), CFrame.new(point + Vector3.new(math.cos(a) * r, s * 0.3, math.sin(a) * r)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			DIRT[rng:NextInteger(1, #DIRT)], folder))
	end
	fade(parts, rng:NextInteger(7, 11), 1.4)
	Debris:AddItem(folder, 14)
end
local function dirtBurst(point, width)
	local folder = Instance.new("Folder"); folder.Name = "PFE_DirtBurst"; folder.Parent = workspace
	local chunks = {}
	local count = 10 + math.floor(math.clamp(width, 2, 10))
	for _ = 1, count do
		local s = rng:NextNumber(0.25, 0.55) * math.clamp(width / 2.4, 0.8, 2.2)
		local part = block(Vector3.new(s, s, s), CFrame.new(point + Vector3.new(0, 0.3, 0)), DIRT[rng:NextInteger(1, #DIRT)], folder)
		local a = rng:NextNumber(0, math.pi * 2)
		local speed = rng:NextNumber(6, 13)
		table.insert(chunks, {Part = part, Velocity = Vector3.new(math.cos(a) * speed * 0.55, rng:NextNumber(11, 19), math.sin(a) * speed * 0.55),
			Spin = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8)), Rotation = CFrame.new()})
	end
	-- simple ballistic arcs (anchored: no physics owner, no collisions with players)
	task.spawn(function()
		local started = os.clock()
		local last = started
		while os.clock() - started < 1.1 do
			local t = os.clock()
			local dt = t - last; last = t
			for _, chunk in ipairs(chunks) do
				local position = chunk.Part.Position + chunk.Velocity * dt
				chunk.Velocity += Vector3.new(0, -workspace.Gravity * 0.3 * dt, 0)
				if position.Y < point.Y + chunk.Part.Size.Y * 0.5 then
					position = Vector3.new(position.X, point.Y + chunk.Part.Size.Y * 0.5, position.Z)
					chunk.Velocity = Vector3.new(chunk.Velocity.X * 0.4, math.abs(chunk.Velocity.Y) * 0.25, chunk.Velocity.Z * 0.4)
				end
				chunk.Rotation *= CFrame.Angles(chunk.Spin.X * dt, chunk.Spin.Y * dt, chunk.Spin.Z * dt)
				chunk.Part.CFrame = CFrame.new(position) * chunk.Rotation
			end
			RunService.RenderStepped:Wait()
		end
		local parts = {}
		for _, chunk in ipairs(chunks) do table.insert(parts, chunk.Part) end
		fade(parts, 0.4, 0.5)
	end)
	Debris:AddItem(folder, 4)
end
local function sparkle(point, height, color)
	local anchor = block(Vector3.one, CFrame.new(point + Vector3.new(0, height * 0.5, 0)), Color3.new(1, 1, 1), workspace)
	anchor.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(255, 226, 120))
	emitter.LightEmission = 0.8; emitter.Rate = 0; emitter.Speed = NumberRange.new(6, 12); emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.5, 0.9); emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0)})
	emitter.Drag = 4; emitter.Parent = anchor
	emitter:Emit(26)
	Debris:AddItem(anchor, 1.6)
end

-- ---------------------------------------------------------------- tracking
local function measure(record)
	local visual = record.Visual
	local pivot = visual:GetPivot()
	local bounds, size = ModelUtil.VisibleBounds(visual)
	local bottom = bounds.Position - Vector3.new(0, size.Y / 2, 0)
	record.Rotation = pivot - pivot.Position
	record.Offset = pivot.Position - bottom     -- pivot relative to the bottom centre at MeasuredScale
	record.Size = size
	record.MeasuredScale = ModelUtil.GetScale(visual)
end
local function place(record, scale, lift, tilt)
	local visual = record.Visual
	if not visual.Parent then return end
	if math.abs(ModelUtil.GetScale(visual) - scale) > 1e-3 then ModelUtil.SetScale(visual, scale) end
	local k = scale / record.MeasuredScale
	local cf = CFrame.new(record.Point + Vector3.new(0, lift or 0, 0) + record.Offset * k)
	if tilt and tilt ~= 0 then
		-- wiggle around the bottom of the egg, not its pivot
		local base = CFrame.new(record.Point + Vector3.new(0, lift or 0, 0))
		cf = base * CFrame.Angles(0, 0, tilt) * CFrame.new(record.Offset * k)
	end
	visual:PivotTo(cf * record.Rotation)
	record.Scale = scale
	local height = record.Size.Y * k
	record.Object:SetAttribute("TopOffset", height - 1.7)
	local label = record.Object:FindFirstChild("PFELabel")
	if label then label.StudsOffsetWorldSpace = Vector3.new(0, height - 1.7 + 1.3 + (lift or 0), 0) end
end
local function growthScale(record)
	local object = record.Object
	local a, b = object:GetAttribute("StartScale") or record.MeasuredScale, object:GetAttribute("TargetScale") or record.MeasuredScale
	return a + (b - a) * progressOf(object)
end

local function track(object)
	if tracked[object] or not object:IsA("Model") then return end
	local point = object:GetAttribute("Point")
	local template = library:FindFirstChild(object:GetAttribute("EggId") or "")
	if not template or not object.Parent or typeof(point) ~= "Vector3" then return end
	local old = object:FindFirstChild("EggVisual")
	if old then old:Destroy() end
	local visual = template:Clone(); visual.Name = "EggVisual"
	ModelUtil.PrepareVisual(visual, true)
	ModelUtil.ApplyMutation(visual, object:GetAttribute("Mutation"))
	visual:PivotTo(CFrame.new(point) * CFrame.Angles(0, object:GetAttribute("Yaw") or 0, 0))
	ModelUtil.PlaceOnGround(visual, point, 0)
	visual.Parent = object
	local info = Config.Eggs[object:GetAttribute("EggId")]
	local record = {Object = object, Visual = visual, Point = point, Anim = nil, NextHop = os.clock() + rng:NextNumber(4, 12),
		NextPulse = os.clock() + rng:NextNumber(1, 3), LastUpdate = 0, ReadyAt = object:GetAttribute("ReadyAt") or 0,
		Rarity = info and info.Rarity}
	measure(record)
	tracked[object] = record
	local target = growthScale(record)
	local planted = object:GetAttribute("PlacedAt")
	if planted and now() - planted < 3 and not emerged[object.Name] then
		emerged[object.Name] = true
		-- just planted: pop out of the dug-up ground
		local width = math.max(record.Size.X, record.Size.Z) * target / record.MeasuredScale
		dirtPatch(point, width)
		dirtBurst(point, width)
		sound(Config.Sfx.Plant, 0.7, rng:NextNumber(0.95, 1.08), visual.PrimaryPart or visual:FindFirstChildWhichIsA("BasePart", true))
		record.Anim = {Kind = "Emerge", Started = os.clock(), To = target}
		place(record, target * 0.05, -record.Size.Y * target / record.MeasuredScale * 0.4)
	else
		place(record, target, 0)
	end
	object:GetAttributeChangedSignal("ReadyAt"):Connect(function()
		local readyAt = object:GetAttribute("ReadyAt") or 0
		if readyAt < record.ReadyAt - 2 then
			-- skipped: shoot up to the new size with a sparkle
			record.Anim = {Kind = "Skip", Started = os.clock(), From = record.Scale, To = growthScale(record)}
			sparkle(record.Point, record.Size.Y * record.Scale / record.MeasuredScale, Color3.fromRGB(255, 226, 120))
			sound(Config.Sfx.Sparkle, 0.6, 1, visual:FindFirstChildWhichIsA("BasePart", true))
		end
		record.ReadyAt = readyAt
	end)
end

local function scan(folder)
	for _, object in ipairs(folder:GetChildren()) do task.spawn(track, object) end
	folder.ChildAdded:Connect(function(object) task.spawn(track, object) end)
end
local function watchBase(base)
	local folder = base:FindFirstChild("GrowingEggs")
	if folder then scan(folder) end
	base.ChildAdded:Connect(function(child)
		if child.Name == "GrowingEggs" and child:IsA("Folder") then scan(child) end
	end)
end
local bases = world:WaitForChild("Bases")
for _, base in ipairs(bases:GetChildren()) do watchBase(base) end
bases.ChildAdded:Connect(watchBase)

-- ---------------------------------------------------------------- animation
RunService.Heartbeat:Connect(function()
	local clock = os.clock()
	for object, record in pairs(tracked) do
		if not object.Parent or not record.Visual.Parent then
			tracked[object] = nil
			continue
		end
		-- the egg's effects follow its size (rebuilt when it has grown a fifth since; not mid-animation)
		if not record.Anim and (not record.FXScale or math.abs(record.Scale / record.FXScale - 1) > 0.2) then
			record.FXScale = record.Scale
			ModelUtil.AttachEggFX(record.Visual, record.Rarity, object:GetAttribute("Scale"))
		end
		local anim = record.Anim
		local ready = object:GetAttribute("Ready") == true
		if anim then
			local base = growthScale(record)
			if anim.Kind == "Emerge" then
				local t = math.clamp((clock - anim.Started) / EMERGE, 0, 1)
				local e = backOut(t)
				local height = record.Size.Y * base / record.MeasuredScale
				place(record, base * math.max(0.05, e), -height * 0.4 * (1 - math.min(1, t * 1.6)))
				if t >= 1 then record.Anim = nil end
			elseif anim.Kind == "Skip" then
				local t = math.clamp((clock - anim.Started) / 0.8, 0, 1)
				place(record, anim.From + (base - anim.From) * backOut(t), 0)
				if t >= 1 then record.Anim = nil end
			elseif anim.Kind == "Hop" then
				local t = math.clamp((clock - anim.Started) / HOP, 0, 1)
				local lift = math.sin(t * math.pi) * 0.85 * anim.Mult
				local squash = 1 + math.sin(t * math.pi * 2) * 0.06
				place(record, base * squash, lift, math.sin(t * math.pi * 4) * 0.14 * (1 - t))
				if t >= 1 then record.Anim = nil; place(record, base, 0) end
			elseif anim.Kind == "Pulse" then
				local t = math.clamp((clock - anim.Started) / 0.5, 0, 1)
				place(record, base * (1 + math.sin(t * math.pi) * 0.12), 0)
				if t >= 1 then record.Anim = nil; place(record, base, 0) end
			end
		else
			if ready and clock >= record.NextPulse then
				record.Anim = {Kind = "Pulse", Started = clock}
				record.NextPulse = clock + rng:NextNumber(5, 10)
			elseif not ready and clock >= record.NextHop then
				record.Anim = {Kind = "Hop", Started = clock, Mult = math.clamp(record.Scale / record.MeasuredScale * record.Size.Y / 2.4, 0.6, 3)}
				record.NextHop = clock + rng:NextNumber(27, 65)
			elseif clock - record.LastUpdate > 0.1 then
				record.LastUpdate = clock
				local scale = growthScale(record)
				if math.abs(scale - record.Scale) > 0.002 then place(record, scale, 0) end
			end
		end
	end
end)
