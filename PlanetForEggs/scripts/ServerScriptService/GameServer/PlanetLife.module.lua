--!nocheck
-- (v41) Planet life on the server (LifeConfig says what is what):
--  * the WEATHER of every planet - one is always on, a new one every 80-130 s - with its strikes (telegraphed: a red
--    circle first), hazard patches, shelters, its eggs and its breakables;
--  * everything that can be SMASHED with the bat or shot with the raygun (crystals, ore, geodes, ice blocks, volcanic
--    bombs, cracked cave walls, chests) and what falls out of it (coins, eggs);
--  * the surface GEODES around every explorer, the COINS of Coin Rain and the TORNADOES of Egg Tornado (Events.lua);
--  * the hooks the rest of the game calls: ctx.AirMultiplier (Expeditions), ctx.LaserTargets (Aliens' raygun), the Smash
--    remote (the bat on things), profile.WeatherSpeed (ctx.setMovement).
-- Bosses, GoldenRace and Caves (child modules / Caves.lua) build on it. Everything planet-bound sits in
-- workspace.PFE_PlanetLife/<Planet> (a folder with a Planet attribute: PlanetClient shows it only on that planet).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local PlanetLife = {}
local ctx, Config, Life
local rng = Random.new()
local root -- workspace.PFE_PlanetLife
local planetFolders = {}

-- ---------------------------------------------------------------- helpers
local function now() return workspace:GetServerTimeNow() end
local function planetFolder(planetId)
	local f = planetFolders[planetId]
	if f and f.Parent then return f end
	f = Instance.new("Folder")
	f.Name = planetId
	f:SetAttribute("Planet", planetId)
	f.Parent = root
	planetFolders[planetId] = f
	return f
end
PlanetLife.Folder = planetFolder

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end
PlanetLife.Part = part
local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color; l.Range = range or 14; l.Brightness = brightness or 1.5; l.Shadows = false
	l.Parent = parent
	return l
end
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	for k, v in pairs(props) do e[k] = v end
	e.Parent = parent
	return e
end
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function planetOf(id) return Config.Planets[id] end
-- a flat point `d` studs from `near` (planet-relative limits: off the landing pad, inside the map)
local function spotNear(planetId, near, minD, maxD)
	local planet = planetOf(planetId)
	if not planet then return nil end
	local origin = planet.Origin
	local clear = math.max(Life.SafeRadius, Config.NearEggs.RocketClear or 0) + 10
	for _ = 1, 14 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(minD, maxD)
		local x, z = near.X + math.cos(a) * d, near.Z + math.sin(a) * d
		local r = Vector2.new(x - origin.X, z - origin.Z).Magnitude
		if r > clear and r < (planet.Radius or 2800) - 60 then return Vector3.new(x, origin.Y, z) end
	end
	return nil
end
PlanetLife.SpotNear = spotNear
local function flat(a, b) return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude end

-- explorers on a planet's surface (not aboard a ship, not in a cave, not flying)
local function surfaceExplorers(planetId)
	local list = {}
	for _, p in pairs(ctx.profiles) do
		if p.Planet == planetId and p.Expedition and p.Expedition.Planet == planetId and not p.Busy and not p.InDungeon and not p.InCave then
			local r = ctx.root(p.Player)
			if r then table.insert(list, p) end
		end
	end
	return list
end
PlanetLife.SurfaceExplorers = surfaceExplorers
-- everyone whose screen shows this spot (on that planet, within `range`)
local function viewers(planetId, position, range)
	local list = {}
	for _, p in pairs(ctx.profiles) do
		if p.Planet == planetId then
			local r = ctx.root(p.Player)
			if r and (r.Position - position).Magnitude < (range or 700) then table.insert(list, p) end
		end
	end
	return list
end
PlanetLife.Viewers = viewers
local function tell(planetId, position, kind, payload, range)
	for _, p in ipairs(viewers(planetId, position, range)) do ctx.effect(p.Player, kind, payload) end
end
PlanetLife.Tell = tell

-- hurt an explorer (immortality / ;god: no damage, still the shove)
local function hurt(profile, amount, reason, from, knock)
	local humanoid = ctx.humanoid(profile.Player)
	if not humanoid or humanoid.Health <= 0 then return end
	if profile.God or ctx.immortal(profile) then amount = 0 end
	if amount > 0 then
		if humanoid.Health - amount <= 0 then profile.DeathReason = reason end
		humanoid:TakeDamage(amount)
		ctx.effect(profile.Player, "LifeHurt", {Amount = amount})
	end
	if knock and knock > 0 and from then
		ctx.effect(profile.Player, "Knockback", {From = from, Force = knock, Duration = 0.4})
	end
end
PlanetLife.Hurt = hurt

-- ---------------------------------------------------------------- targets (the raygun's and the bat's)
-- model -> {Planet, Radius, Center = fn, Hit = fn(amount, profile, how), CanHit = fn?}
local targets = {}
function PlanetLife.AddTarget(model, record)
	targets[model] = record
	CollectionService:AddTag(model, "PFESmashable")
end
function PlanetLife.RemoveTarget(model)
	targets[model] = nil
end
local function canHit(record) return not record.CanHit or record.CanHit() end
-- the first target along a laser bolt
function PlanetLife.LaserTarget(profile, origin, unit, length)
	local best, bestT
	for model, record in pairs(targets) do
		if model.Parent and record.Planet == profile.Planet and canHit(record) then
			local centre = record.Center()
			local rel = centre - origin
			local t = rel:Dot(unit)
			if t > 0 and t < length + record.Radius then
				local miss = (rel - unit * t).Magnitude
				if miss <= record.Radius + 1.5 and (not bestT or t < bestT) then best, bestT = record, math.max(0, t - record.Radius * 0.5) end
			end
		end
	end
	return best, bestT
end

-- ---------------------------------------------------------------- breakables
local breakables = {} -- model -> record
local function eggVisual(parent, eggId, at, size)
	local template = eggId and ctx.eggTemplate(eggId)
	if not template then
		local ball = part(parent, {Name = "Egg", Shape = Enum.PartType.Ball, Size = Vector3.new(size * 0.8, size, size * 0.8), Color = Color3.fromRGB(255, 240, 220),
			Material = Enum.Material.SmoothPlastic, CFrame = at})
		return ball
	end
	local visual = template:Clone()
	ctx.ModelUtil.PrepareVisual(visual, false)
	ctx.ModelUtil.FitTo(visual, size)
	local bounds = ctx.ModelUtil.VisibleBounds(visual)
	visual:PivotTo(at * bounds:ToObjectSpace(visual:GetPivot()))
	visual.Name = "EggInside"
	visual.Parent = parent
	return visual
end

local BUILD = {}
function BUILD.Crystal(model, cf, s, colors)
	part(model, {Name = "Base", Size = Vector3.new(s * 0.9, s * 0.3, s * 0.8), CFrame = cf * CFrame.new(0, s * 0.15, 0), Color = colors.Rock,
		Material = Enum.Material.Slate, CanCollide = true})
	for i = 1, 5 do
		local h = s * (0.55 + rng:NextNumber() * 0.7) * (i == 1 and 1.3 or 1)
		local off = i == 1 and Vector3.zero or Vector3.new(rng:NextNumber(-0.3, 0.3) * s, 0, rng:NextNumber(-0.3, 0.3) * s)
		local shard = part(model, {Name = "Shard", Size = Vector3.new(s * 0.22, h, s * 0.22), Color = colors.Accent,
			Material = i == 1 and Enum.Material.Neon or Enum.Material.Glass, Transparency = i == 1 and 0.1 or 0.2,
			CFrame = cf * CFrame.new(off + Vector3.new(0, s * 0.3 + h * 0.4, 0)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4))})
		if i == 1 then light(shard, colors.Accent, 16, 1.4) end
	end
end
function BUILD.Ore(model, cf, s, colors)
	for i = 1, 3 do
		part(model, {Name = "Rock", Size = Vector3.new(s * (0.5 + i * 0.12), s * (0.45 + 0.1 * i), s * 0.6), Color = colors.Rock:Lerp(Color3.new(0, 0, 0), 0.1 * i),
			Material = Enum.Material.Slate, CanCollide = i == 1,
			CFrame = cf * CFrame.new((i - 2) * s * 0.22, s * 0.25, rng:NextNumber(-0.15, 0.15) * s) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3))})
	end
	for _ = 1, 6 do
		part(model, {Name = "Nugget", Size = Vector3.new(0.9, 0.7, 0.8) * (s / 7), Color = Color3.fromRGB(255, 200, 50), Material = Enum.Material.Foil,
			CFrame = cf * CFrame.new(rng:NextNumber(-0.4, 0.4) * s, rng:NextNumber(0.25, 0.75) * s, rng:NextNumber(-0.32, 0.32) * s) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)})
	end
	light(model:FindFirstChild("Rock"), Color3.fromRGB(255, 200, 80), 10, 0.8)
end
function BUILD.Geode(model, cf, s, colors)
	local shell = part(model, {Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.one * s, CFrame = cf * CFrame.new(0, s * 0.42, 0), Color = colors.Rock,
		Material = Enum.Material.Slate, CanCollide = true})
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		part(model, {Name = "Shard", Size = Vector3.new(s * 0.18, s * 0.5, s * 0.18), Color = colors.Accent, Material = Enum.Material.Neon,
			CFrame = shell.CFrame * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(50 + (i % 2) * 25), 0, 0) * CFrame.new(0, s * 0.5, 0)})
	end
	light(shell, colors.Accent, 14, 1.2)
end
function BUILD.IceBlock(model, cf, s, colors, opts)
	part(model, {Name = "Ice", Size = Vector3.new(s, s * 0.9, s), CFrame = cf * CFrame.new(0, s * 0.45, 0) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
		Color = Color3.fromRGB(190, 230, 255), Material = Enum.Material.Ice, Transparency = 0.35, CanCollide = true})
	part(model, {Name = "Frost", Size = Vector3.new(s * 1.05, s * 0.12, s * 1.05), CFrame = cf * CFrame.new(0, s * 0.92, 0), Color = Color3.fromRGB(240, 250, 255),
		Material = Enum.Material.Snow})
	eggVisual(model, opts.EggId, cf * CFrame.new(0, s * 0.45, 0), s * 0.55)
end
function BUILD.LavaBomb(model, cf, s, colors)
	local ball = part(model, {Name = "Rock", Shape = Enum.PartType.Ball, Size = Vector3.one * s, CFrame = cf * CFrame.new(0, s * 0.4, 0),
		Color = Color3.fromRGB(46, 40, 42), Material = Enum.Material.Basalt, CanCollide = true})
	for i = 1, 5 do
		part(model, {Name = "Crack", Size = Vector3.new(s * 0.08, s * 0.7, s * 0.08), Color = Color3.fromRGB(255, 110, 30), Material = Enum.Material.Neon,
			CFrame = ball.CFrame * CFrame.Angles(rng:NextNumber(0, 6), i, rng:NextNumber(0, 6)) * CFrame.new(0, 0, s * 0.47)})
	end
	local fire = Instance.new("Fire"); fire.Size = s * 0.6; fire.Heat = 6; fire.Color = Color3.fromRGB(255, 120, 40); fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
	fire.Parent = ball
	light(ball, Color3.fromRGB(255, 120, 40), 18, 2)
end
function BUILD.Wall(model, cf, s, colors, opts)
	local w, h = opts.Width or s, opts.Height or s
	local slab = part(model, {Name = "Wall", Size = Vector3.new(w, h, 3), CFrame = cf * CFrame.new(0, h / 2, 0), Color = colors.Rock:Lerp(Color3.fromRGB(120, 110, 100), 0.3),
		Material = Enum.Material.Slate, CanCollide = true, CanQuery = true, CastShadow = true})
	for i = 1, 6 do
		part(model, {Name = "Crack", Size = Vector3.new(0.35, h * rng:NextNumber(0.25, 0.55), 0.2), Color = Color3.fromRGB(20, 16, 14), Material = Enum.Material.SmoothPlastic,
			CFrame = slab.CFrame * CFrame.new(rng:NextNumber(-0.4, 0.4) * w, rng:NextNumber(-0.3, 0.3) * h, -1.55) * CFrame.Angles(0, 0, rng:NextNumber(-0.9, 0.9))})
	end
	-- a faint glow seeping through the cracks: something is behind it
	local glow = part(model, {Name = "Glow", Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = slab.CFrame * CFrame.new(0, 0, -2.2)})
	light(glow, colors.Accent, 12, 0.9)
end
function BUILD.Chest(model, cf, s, colors, opts)
	local vault = opts.Kind == "Vault"
	local trim = vault and Color3.fromRGB(190, 120, 255) or Color3.fromRGB(255, 200, 50)
	local body = part(model, {Name = "Body", Size = Vector3.new(s * 0.9, s * 0.5, s * 0.6), CFrame = cf * CFrame.new(0, s * 0.25, 0), Color = Color3.fromRGB(120, 72, 36),
		Material = Enum.Material.WoodPlanks, CanCollide = true})
	part(model, {Name = "Lid", Size = Vector3.new(s * 0.92, s * 0.22, s * 0.62), CFrame = cf * CFrame.new(0, s * 0.6, 0), Color = Color3.fromRGB(140, 86, 44),
		Material = Enum.Material.WoodPlanks})
	for _, x in ipairs({-0.3, 0.3}) do
		part(model, {Name = "Band", Size = Vector3.new(s * 0.1, s * 0.74, s * 0.64), CFrame = cf * CFrame.new(x * s, s * 0.37, 0), Color = trim, Material = Enum.Material.Foil})
	end
	local lock = part(model, {Name = "Lock", Size = Vector3.new(s * 0.16, s * 0.18, 0.3), CFrame = cf * CFrame.new(0, s * 0.45, -s * 0.31), Color = trim, Material = Enum.Material.Neon})
	light(lock, trim, vault and 26 or 16, vault and 2.5 or 1.6)
	emitter(body, {Texture = SPARK, Rate = vault and 10 or 4, Lifetime = NumberRange.new(0.8, 1.5), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.5, 0), Color = ColorSequence.new(trim), LightEmission = 1})
end
BUILD.Vault = BUILD.Chest
function BUILD.CometCore(model, cf, s, colors)
	BUILD.Geode(model, cf, s, {Rock = Color3.fromRGB(60, 50, 70), Accent = Color3.fromRGB(255, 200, 90)})
	local core = model:FindFirstChild("Shell")
	if core then
		emitter(core, {Texture = FIRE, Rate = 25, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(2, 5), Size = NumberSequence.new(3, 0),
			Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 90, 30)), LightEmission = 1})
	end
end

-- a breakable thing on `planetId` standing at `cf` (on the ground). opts: Kind override, EggId (pre-rolled), Zone, BoostMult,
-- CoinMult, HPMult, Eggs, Life (s), Cave (true: in a cave), Depth, OnBreak(profile), Name, Width / Height (walls)
function PlanetLife.Breakable(planetId, kind, cf, opts)
	opts = opts or {}
	local spec = Life.Breakables[kind]
	local planet = planetOf(planetId)
	if not spec or not planet or not BUILD[kind] then return nil end
	local s = (opts.Size or spec.Size or 7)
	local model = Instance.new("Model")
	model.Name = spec.Name
	opts.Kind = kind
	-- an ice block / bomb shows the egg it holds: rolled now, laid when it breaks
	if (kind == "IceBlock") and not opts.EggId then
		local info = ctx.Expeditions.RollEgg(nil, planetId, opts.Zone or 3, spec.Boost)
		opts.EggId = info and info.Id
	end
	local colors = {Rock = planet.RockColor or Color3.fromRGB(110, 110, 120), Accent = planet.Accent or Color3.fromRGB(120, 230, 255)}
	BUILD[kind](model, cf, s, colors, opts)
	local core = part(model, {Name = "Core", Size = Vector3.new(opts.Width or s, opts.Height or s * 1.1, math.max(3, opts.Width and 3 or s)),
		CFrame = cf * CFrame.new(0, (opts.Height or s * 1.1) / 2, 0), Transparency = 1})
	model.PrimaryPart = core
	local hp = math.floor(spec.HP * (opts.HPMult or 1) + 0.5)
	model:SetAttribute("Kind", kind); model:SetAttribute("HP", hp); model:SetAttribute("MaxHP", hp)
	model:SetAttribute("Planet", planetId); model:SetAttribute("Label", opts.Name or spec.Name)
	model.Parent = opts.Parent or planetFolder(planetId)
	local record = {Model = model, Kind = kind, Spec = spec, HP = hp, Max = hp, Planet = planetId, Position = cf.Position, Opts = opts,
		Radius = math.max(3, (opts.Width or s) * 0.55), Born = now()}
	breakables[model] = record
	PlanetLife.AddTarget(model, {Planet = planetId, Radius = record.Radius, Center = function() return core.Position end,
		Hit = function(amount, profile, how) PlanetLife.HitBreakable(record, amount, profile, how) end})
	if opts.Life then
		task.delay(opts.Life, function()
			if breakables[model] == record and model.Parent then PlanetLife.RemoveBreakable(record, true) end
		end)
	end
	return record
end

function PlanetLife.RemoveBreakable(record, fade)
	breakables[record.Model] = nil
	PlanetLife.RemoveTarget(record.Model)
	if fade then tell(record.Planet, record.Position, "LifeShatter", {Position = record.Position, Kind = record.Kind, Fade = true}, 400) end
	if record.Model.Parent then record.Model:Destroy() end
end
function PlanetLife.Breakables() return breakables end

local function coinsFor(planetId, mult)
	local planet = planetOf(planetId)
	return math.max(25, math.floor((planet and planet.Reward or 100) * mult))
end
PlanetLife.CoinsFor = coinsFor

function PlanetLife.HitBreakable(record, amount, profile, how)
	if breakables[record.Model] ~= record or record.HP <= 0 then return end
	record.HP = math.max(0, record.HP - amount)
	record.Model:SetAttribute("HP", math.ceil(record.HP))
	local at = record.Model.PrimaryPart and record.Model.PrimaryPart.Position or record.Position
	tell(record.Planet, at, "LifeHit", {Position = at, Kind = record.Kind, Ratio = record.HP / record.Max, How = how}, 300)
	if record.HP > 0 then return end
	-- broken: what was inside comes out
	breakables[record.Model] = nil
	PlanetLife.RemoveTarget(record.Model)
	local spec, opts = record.Spec, record.Opts
	tell(record.Planet, at, "LifeShatter", {Position = at, Kind = record.Kind}, 400)
	if profile and ctx.profiles[profile.Player] == profile then
		local coins = (spec.Coins or 0) > 0 and coinsFor(record.Planet, spec.Coins * (opts.CoinMult or 1)) or 0
		if coins > 0 then
			profile.Data.Coins = math.min(1e15, profile.Data.Coins + coins)
			ctx.effect(profile.Player, "Coins", {Amount = coins})
		end
		profile.Data.Stats.CrystalsBroken = (profile.Data.Stats.CrystalsBroken or 0) + 1
		ctx.markDirty(profile)
	end
	local eggChance = (spec.Egg or 0) * (opts.EggMult or 1)
	local count = opts.Eggs or spec.Eggs or 1
	if eggChance > 0 and rng:NextNumber() < eggChance then
		for i = 1, count do
			local offset = count > 1 and Vector3.new(math.cos(i * 2.1) * 5, 0, math.sin(i * 2.1) * 5) or Vector3.zero
			local spot = Vector3.new(record.Position.X, record.Position.Y, record.Position.Z) + offset
			local item = ctx.Expeditions.SpawnEventEgg(record.Planet, spot, {Zone = opts.Zone or 3, Boost = (spec.Boost or 2) * (opts.BoostMult or 1),
				Super = spec.Super, EggId = i == 1 and opts.EggId or nil, Life = opts.Cave and 240 or 120, MinMutation = opts.MinMutation})
			if item then
				local proxy = item:FindFirstChild("Pickup")
				tell(record.Planet, at, "EventStrike", {Kind = "EggDrop", Position = proxy and proxy.Position - Vector3.new(0, 1.9, 0) or spot, Delay = 0.5,
					EggId = item:GetAttribute("EggId")}, 400)
			end
		end
	end
	if opts.OnBreak then task.spawn(opts.OnBreak, profile, record) end
	record.Model:Destroy()
end

-- ---------------------------------------------------------------- strikes
-- a telegraphed impact: the clients draw the warning circle and the meteor / bolt / bomb; after Delay everybody inside
-- Radius takes Damage and a shove; opts: Egg (chance), Boost, MutationStep, Break (chance), BreakKind, Reason, From, Range
local pending = {} -- the strikes on their way (the bots see the red circles too and get out of them)
function PlanetLife.Strike(planetId, kind, position, spec, opts)
	opts = opts or {}
	local delay = spec.Delay or 1.5
	tell(planetId, position, "LifeStrike", {Kind = kind, Position = position, Delay = delay, Radius = spec.Radius, From = opts.From}, opts.Range or 600)
	local warning = {Planet = planetId, Position = position, Radius = spec.Radius or 8, At = now() + delay}
	pending[warning] = true
	task.delay(delay, function()
		pending[warning] = nil
		local radius = spec.Radius or 8
		if (spec.Damage or 0) > 0 or (spec.Knock or 0) > 0 then
			for _, p in pairs(ctx.profiles) do
				if p.Planet == planetId and not p.Busy and not p.InDungeon then
					local r = ctx.root(p.Player)
					if r and flat(r.Position, position) <= radius and math.abs(r.Position.Y - position.Y) < radius + 10 then
						local safe = not opts.Cave and flat(r.Position, planetOf(planetId).Origin) < Life.SafeRadius
						if not safe then hurt(p, spec.Damage or 0, opts.Reason or ("The " .. string.lower(kind) .. " got you!"), position, spec.Knock) end
					end
				end
			end
		end
		if spec.Egg and rng:NextNumber() < spec.Egg then
			local item = ctx.Expeditions.SpawnEventEgg(planetId, position, {Zone = 4, Boost = spec.Boost or 3, MutationStep = spec.MutationStep, Life = 75})
			if item then item:SetAttribute("Crater", true) end
		elseif spec.Break and rng:NextNumber() < spec.Break then
			PlanetLife.Breakable(planetId, spec.BreakKind or "Crystal", CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), {Life = 90})
		end
		if opts.OnLand then opts.OnLand() end
	end)
end

-- ---------------------------------------------------------------- shelters
local shelters = {} -- model -> {Planet, Position, Radius, Kind, Heal}
local SHELTER = {}
function SHELTER.Campfire(model, at, radius)
	for i = 1, 4 do
		part(model, {Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.5, 0.9, 0.9), Color = Color3.fromRGB(96, 62, 34), Material = Enum.Material.Wood,
			CFrame = CFrame.new(at + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, i * math.pi / 4, math.rad(18))})
	end
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		part(model, {Name = "Stone", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, Color = Color3.fromRGB(120, 120, 128), Material = Enum.Material.Slate,
			CFrame = CFrame.new(at + Vector3.new(math.cos(a) * 2.8, 0.3, math.sin(a) * 2.8))})
	end
	local flame = part(model, {Name = "Flame", Size = Vector3.new(2, 2, 2), Transparency = 1, CFrame = CFrame.new(at + Vector3.new(0, 1.6, 0))})
	local fire = Instance.new("Fire"); fire.Size = 7; fire.Heat = 12; fire.Color = Color3.fromRGB(255, 150, 40); fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
	fire.Parent = flame
	local smoke = Instance.new("Smoke"); smoke.Size = 3; smoke.RiseVelocity = 6; smoke.Opacity = 0.12; smoke.Parent = flame
	light(flame, Color3.fromRGB(255, 160, 70), radius + 10, 2.6)
end
function SHELTER.Mushroom(model, at, radius, colors)
	part(model, {Name = "Stem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(11, 2.6, 2.6), Color = Color3.fromRGB(235, 225, 210), Material = Enum.Material.SmoothPlastic,
		CFrame = CFrame.new(at + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), CanCollide = true})
	local cap = part(model, {Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.one * radius * 1.9, Color = colors.Accent:Lerp(Color3.fromRGB(255, 80, 160), 0.4),
		Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(at + Vector3.new(0, 11.5, 0))})
	local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Scale = Vector3.new(1, 0.28, 1); mesh.Parent = cap
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		part(model, {Name = "Spot", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, Color = Color3.fromRGB(255, 250, 220), Material = Enum.Material.Neon,
			CFrame = CFrame.new(at + Vector3.new(math.cos(a) * radius * 0.5, 13, math.sin(a) * radius * 0.5))})
	end
	light(cap, colors.Accent, radius + 6, 1)
end
function SHELTER.ShadeRock(model, at, radius, colors)
	local rock = colors.Rock or Color3.fromRGB(110, 110, 120)
	local yaw = CFrame.Angles(0, rng:NextNumber(0, 6), 0)
	for _, x in ipairs({-1, 1}) do
		part(model, {Name = "Pillar", Size = Vector3.new(3.5, 11, 4), Color = rock, Material = Enum.Material.Slate, CanCollide = true,
			CFrame = CFrame.new(at) * yaw * CFrame.new(x * radius * 0.62, 5.5, 0) * CFrame.Angles(0, 0, x * 0.08)})
	end
	part(model, {Name = "Roof", Size = Vector3.new(radius * 1.8, 2.6, radius * 1.3), Color = rock:Lerp(Color3.new(0, 0, 0), 0.15), Material = Enum.Material.Slate,
		CanCollide = true, CastShadow = true, CFrame = CFrame.new(at) * yaw * CFrame.new(0, 12, 0) * CFrame.Angles(0.05, 0, 0.04)})
end
-- the round patch a shelter covers (so you can see where you're safe)
local function ring(model, at, radius, color)
	part(model, {Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, radius * 2, radius * 2), Color = color, Material = Enum.Material.Neon,
		Transparency = 0.82, CFrame = CFrame.new(at + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.pi / 2)})
end
function PlanetLife.Shelter(planetId, kind, at, spec)
	local planet = planetOf(planetId)
	if not planet or not SHELTER[kind] then return nil end
	local model = Instance.new("Model")
	model.Name = kind
	local radius = spec.Radius or 14
	SHELTER[kind](model, at, radius, {Rock = planet.RockColor, Accent = planet.Accent})
	ring(model, at, radius, kind == "Campfire" and Color3.fromRGB(255, 170, 60) or kind == "Mushroom" and Color3.fromRGB(255, 120, 220) or Color3.fromRGB(80, 90, 120))
	model:SetAttribute("Shelter", kind); model:SetAttribute("Radius", radius); model:SetAttribute("Planet", planetId)
	model.Parent = planetFolder(planetId)
	shelters[model] = {Planet = planetId, Position = at, Radius = radius, Kind = kind, Heal = spec.Heal, Weather = spec.Weather, Expires = now() + (spec.Life or 70)}
	return model
end
local function shelteredBy(profile)
	local r = ctx.root(profile.Player)
	if not r then return nil end
	for model, s in pairs(shelters) do
		if s.Planet == profile.Planet and flat(r.Position, s.Position) <= s.Radius and model.Parent then return s end
	end
	return nil
end
PlanetLife.ShelteredBy = shelteredBy

-- ---------------------------------------------------------------- hazard zones (fissures, spore clouds, glitches, pads)
local zones = {} -- model -> {Planet, Position, Spec, Kind, ArmedAt, Expires, CF}
local ZONE = {}
function ZONE.Fissure(model, cf, spec)
	local crack = part(model, {Name = "Crack", Size = Vector3.new(spec.Length or 30, 0.5, (spec.Radius or 5) * 2), CFrame = cf * CFrame.new(0, 0.1, 0),
		Color = Color3.fromRGB(255, 90, 20), Material = Enum.Material.Neon, Transparency = 0.85})
	emitter(crack, {Texture = SMOKE, Rate = 14, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(4, 8), Size = NumberSequence.new(3, 8),
		Color = ColorSequence.new(Color3.fromRGB(90, 70, 60)), Transparency = NumberSequence.new(0.4, 1), Shape = Enum.ParticleEmitterShape.Box,
		EmissionDirection = Enum.NormalId.Top})
	return crack
end
function ZONE.SporeCloud(model, cf, spec)
	local ball = part(model, {Name = "Cloud", Shape = Enum.PartType.Ball, Size = Vector3.one * (spec.Radius or 14) * 2, CFrame = cf * CFrame.new(0, (spec.Radius or 14) * 0.5, 0),
		Color = Color3.fromRGB(200, 120, 255), Material = Enum.Material.ForceField, Transparency = 0.3})
	emitter(ball, {Texture = SPARK, Rate = 30, Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(1, 3), Size = NumberSequence.new(0.8, 0),
		Color = ColorSequence.new(Color3.fromRGB(220, 255, 120), Color3.fromRGB(255, 120, 220)), Shape = Enum.ParticleEmitterShape.Sphere, LightEmission = 0.8})
	return ball
end
function ZONE.Glitch(model, cf, spec)
	local box = part(model, {Name = "Glitch", Size = Vector3.new((spec.Radius or 12) * 2, 12, (spec.Radius or 12) * 2), CFrame = cf * CFrame.new(0, 6, 0),
		Color = Color3.fromRGB(60, 240, 255), Material = Enum.Material.ForceField, Transparency = 0.2})
	emitter(box, {Texture = "rbxasset://textures/particles/SquareParticle.png", Rate = 25, Lifetime = NumberRange.new(0.5, 1.2), Speed = NumberRange.new(0, 2),
		Size = NumberSequence.new(0.6, 0), Color = ColorSequence.new(Color3.fromRGB(60, 240, 255), Color3.fromRGB(255, 60, 200)), Shape = Enum.ParticleEmitterShape.Box,
		LightEmission = 1})
	return box
end
function ZONE.SporePod(model, cf, spec)
	local r = spec.Radius or 5
	part(model, {Name = "Stem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, r * 1.2, r * 1.2), CFrame = cf * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(240, 220, 230), Material = Enum.Material.SmoothPlastic, CanCollide = true})
	local pad = part(model, {Name = "Pad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, r * 2, r * 2), CFrame = cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 90, 200), Material = Enum.Material.Neon, CanCollide = true})
	emitter(pad, {Texture = SPARK, Rate = 8, Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(6, 12), Size = NumberSequence.new(0.6, 0),
		Color = ColorSequence.new(Color3.fromRGB(255, 160, 230)), EmissionDirection = Enum.NormalId.Right, LightEmission = 1})
	return pad
end
function ZONE.Tornado(model, cf, spec)
	local r = spec.Radius or 10
	local funnel = part(model, {Name = "Funnel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(60, r * 2, r * 2), CFrame = cf * CFrame.new(0, 30, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(190, 220, 255), Material = Enum.Material.ForceField, Transparency = 0.25})
	emitter(funnel, {Texture = SMOKE, Rate = 40, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(8, 14), Size = NumberSequence.new(4, 10),
		Color = ColorSequence.new(Color3.fromRGB(200, 215, 235)), Transparency = NumberSequence.new(0.35, 1), Shape = Enum.ParticleEmitterShape.Cylinder,
		RotSpeed = NumberRange.new(-200, 200), Rotation = NumberRange.new(0, 360), SpreadAngle = Vector2.new(20, 20)})
	return funnel
end
-- a hazard patch at `at` (lies on the ground); armed after `arm` seconds (fissures glow up first)
function PlanetLife.Zone(planetId, spec, at, opts)
	opts = opts or {}
	local kind = spec.Kind
	if not ZONE[kind] then return nil end
	local model = Instance.new("Model")
	model.Name = kind
	local cf = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local main = ZONE[kind](model, cf, spec)
	model:SetAttribute("Zone", kind); model:SetAttribute("Planet", planetId); model:SetAttribute("Radius", spec.Radius or 10)
	model.Parent = planetFolder(planetId)
	local arm = kind == "Fissure" and 1.6 or 0
	local record = {Planet = planetId, Position = at, Spec = spec, Kind = kind, ArmedAt = now() + arm, Expires = now() + (spec.Life or 15), CF = cf, Main = main,
		Weather = opts.Weather, Model = model}
	zones[model] = record
	if kind == "Fissure" then
		task.delay(arm, function() if main.Parent then main.Transparency = 0.15; light(main, Color3.fromRGB(255, 100, 30), 18, 2) end end)
	end
	if spec.Egg and rng:NextNumber() < spec.Egg then
		task.delay(arm + 1, function()
			if not model.Parent then return end
			local spot = kind == "Fissure" and (cf * CFrame.new((spec.Length or 30) * 0.5 + 3, 0, 0)).Position or at
			local rainbow = spec.Rainbow and rng:NextNumber() < spec.Rainbow
			local item = ctx.Expeditions.SpawnEventEgg(planetId, spot, {Zone = 4, Boost = spec.Boost or 3, MinMutation = rainbow and "Rainbow" or nil, Life = 70})
			if item then tell(planetId, spot, "EventStrike", {Kind = "Pumpkin", Position = spot, Delay = 0.4, EggId = item:GetAttribute("EggId")}, 400) end
		end)
	end
	return record
end
local function insideZone(z, position)
	if z.Kind == "Fissure" then
		local rel = z.CF:PointToObjectSpace(position)
		return math.abs(rel.X) <= (z.Spec.Length or 30) / 2 and math.abs(rel.Z) <= (z.Spec.Radius or 5) and rel.Y < 8
	end
	local r = z.Spec.Radius or 10
	local d = position - z.Position
	if z.Kind == "SporePod" then return Vector2.new(d.X, d.Z).Magnitude <= r + 1 and d.Y < 9 and d.Y > -2 end
	return Vector2.new(d.X, d.Z).Magnitude <= r and d.Y < r * 1.5 + 4 and d.Y > -4
end
function PlanetLife.Zones() return zones end
function PlanetLife.RemoveZone(model)
	zones[model] = nil
	if model.Parent then model:Destroy() end
end

-- ---------------------------------------------------------------- coins (Coin Rain)
local coins = {} -- part -> {Planet, Value, Expires}
function PlanetLife.Coin(planetId, at, value)
	local coin = part(planetFolder(planetId), {Name = "Coin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 3.2, 3.2), Color = Color3.fromRGB(255, 205, 50),
		Material = Enum.Material.Foil, CFrame = CFrame.new(at + Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)})
	coin:SetAttribute("Coin", true)
	light(coin, Color3.fromRGB(255, 210, 80), 9, 1)
	coins[coin] = {Planet = planetId, Value = value, Expires = now() + 25}
	tell(planetId, at, "LifeCoinDrop", {Position = at + Vector3.new(0, 2.2, 0)}, 300)
	return coin
end

-- ---------------------------------------------------------------- the weather engine
local weatherNow = {} -- planetId -> {Id, Def, EndsAt, Clock = {}, Owned = {}}
local function pickWeather(planetId, current)
	local list = Life.PlanetWeather[planetId] or {"MeteorRain"}
	local pick = list[rng:NextInteger(1, #list)]
	for _ = 1, 6 do
		if pick ~= current or #list == 1 then break end
		pick = list[rng:NextInteger(1, #list)]
	end
	return pick
end
local function clearWeatherThings(planetId, weatherId)
	for model, s in pairs(shelters) do
		if s.Planet == planetId and s.Weather == weatherId then shelters[model] = nil; if model.Parent then model:Destroy() end end
	end
	for model, z in pairs(zones) do
		if z.Planet == planetId and z.Weather == weatherId then PlanetLife.RemoveZone(model) end
	end
end
local function startWeather(planetId)
	local old = weatherNow[planetId]
	local id = pickWeather(planetId, old and old.Id)
	if old then clearWeatherThings(planetId, old.Id) end
	local d = Life.WeatherDuration
	local state = {Id = id, Def = Life.Weather[id], EndsAt = now() + rng:NextNumber(d[1], d[2]), Clock = {}, Eggs = {}}
	weatherNow[planetId] = state
	workspace:SetAttribute("PFEWeather_" .. planetId, id)
	workspace:SetAttribute("PFEWeatherEnds_" .. planetId, state.EndsAt)
	for _, p in ipairs(surfaceExplorers(planetId)) do
		ctx.notice(p, string.upper(state.Def.Name) .. "! " .. state.Def.Hint, "Purple")
	end
	return state
end
function PlanetLife.Weather(planetId)
	local s = weatherNow[planetId]
	return s and s.Def, s and s.Id
end
-- (admin / tests) this weather on that planet now, for `seconds`
function PlanetLife.ForceWeather(planetId, id, seconds)
	if not Life.Weather[id] or not Config.Planets[planetId] then return false end
	local old = weatherNow[planetId]
	if old then clearWeatherThings(planetId, old.Id) end
	local state = {Id = id, Def = Life.Weather[id], EndsAt = now() + (seconds or 90), Clock = {}, Eggs = {}}
	weatherNow[planetId] = state
	workspace:SetAttribute("PFEWeather_" .. planetId, id)
	workspace:SetAttribute("PFEWeatherEnds_" .. planetId, state.EndsAt)
	return true
end

-- ---------------------------------------------------------------- for the bots (Bots/Brain, Bots/Wanderer)
-- a red circle (or a hazard patch) over `position` on `planetId`: the thing (its .Position), the radius to get out of
function PlanetLife.Danger(planetId, position, margin)
	margin = margin or 3
	local best, bestT
	for w in pairs(pending) do
		if w.Planet == planetId and flat(position, w.Position) <= w.Radius + margin and (not bestT or w.At < bestT) then best, bestT = w, w.At end
	end
	if best then return best, best.Radius end
	for _, z in pairs(zones) do
		if z.Planet == planetId and ((z.Spec.Damage or 0) > 0 or z.Spec.Air) and insideZone(z, position) then
			return z, (z.Kind == "Fissure" and (z.Spec.Length or 30) / 2 or (z.Spec.Radius or 10)) + 2
		end
	end
	return nil
end
-- the weather on `planetId` wants you under shelter: the nearest one to `position` (nil: no need / none about)
function PlanetLife.ShelterFor(planetId, position, range)
	local state = weatherNow[planetId]
	if not state or not state.Def.Shelter then return nil end
	local best, bestD
	for model, sh in pairs(shelters) do
		if sh.Planet == planetId and model.Parent then
			local d = flat(position, sh.Position)
			if d <= (range or 220) and (not bestD or d < bestD) then best, bestD = sh, d end
		end
	end
	return best
end
-- the things on `planetId` within `radius` of `position` a bat or a raygun can hit: {Model, Center, Breakable?, Boss?}
function PlanetLife.ThingsNear(planetId, position, radius)
	local list = {}
	for model, record in pairs(targets) do
		if model.Parent and record.Planet == planetId and canHit(record) then
			local c = record.Center()
			if (c - position).Magnitude <= radius + record.Radius then
				table.insert(list, {Model = model, Center = c, Radius = record.Radius, Breakable = breakables[model], Boss = model:GetAttribute("Boss") ~= nil})
			end
		end
	end
	return list
end
-- a bot's bat lands on one of them (the same reach as a player's; bots hit softer - the players do the real work)
function PlanetLife.BotSmash(profile, model)
	local record = targets[model]
	local r = ctx.root(profile.Player)
	if not record or not r or not model.Parent or record.Planet ~= profile.Planet or not canHit(record) then return false end
	local centre = record.Center()
	if (centre - r.Position).Magnitude > Config.Bat.Range + Config.Bat.Tolerance + record.Radius + 2 then return false end
	for _, p in ipairs(viewers(profile.Planet, centre, 120)) do ctx.effect(p.Player, "BatHit", {Position = centre:Lerp(r.Position, 0.4)}) end
	record.Hit(Life.BatDamage * (Life.BotDamage or 0.6), profile, "Bat")
	return true
end

-- how many of these things stand within `range` of a point
local function countNear(list, planetId, position, range, filter)
	local n = 0
	for key, rec in pairs(list) do
		if rec.Planet == planetId and (not filter or filter(key, rec)) and flat(rec.Position, position) < range then n += 1 end
	end
	return n
end

local function weatherEggsAlive(state)
	local n = 0
	for i = #state.Eggs, 1, -1 do
		if state.Eggs[i].Parent then n += 1 else table.remove(state.Eggs, i) end
	end
	return n
end

local function timer(state, key, every)
	local t = now()
	local at = state.Clock[key]
	if not at then state.Clock[key] = t + (type(every) == "table" and rng:NextNumber(every[1], every[2]) or every) * rng:NextNumber(0.4, 1); return false end
	if t < at then return false end
	state.Clock[key] = t + (type(every) == "table" and rng:NextNumber(every[1], every[2]) or every)
	return true
end

local function runWeather(planetId, state, explorers)
	local def = state.Def
	local n = #explorers
	if n == 0 then return end
	local pickOne = function() return explorers[rng:NextInteger(1, n)] end
	-- strikes: a planet-wide rhythm, a bit faster with more explorers
	local strike = def.Strike
	if strike then
		local every = {strike.Every[1] / n ^ 0.6, strike.Every[2] / n ^ 0.6}
		if timer(state, "Strike", every) then
			local p = pickOne()
			local r = ctx.root(p.Player)
			local at = r and spotNear(planetId, r.Position, strike.Near[1], strike.Near[2])
			if at then PlanetLife.Strike(planetId, strike.Kind, at, strike, {Reason = "The " .. string.lower(def.Name) .. " got you!"}) end
		end
	end
	-- shelters round every explorer
	local shelter = def.Shelter
	if shelter and timer(state, "Shelter", 1.5) then
		for _, p in ipairs(explorers) do
			local r = ctx.root(p.Player)
			if r and countNear(shelters, planetId, r.Position, shelter.Near[2] + 30) < shelter.PerExplorer then
				local at = spotNear(planetId, r.Position, shelter.Near[1], shelter.Near[2])
				if at then PlanetLife.Shelter(planetId, shelter.Kind, at, {Radius = shelter.Radius, Life = shelter.Life, Heal = shelter.Heal, Weather = state.Id}) end
			end
		end
	end
	-- hazard patches and pads
	for _, key in ipairs({"Zone", "Pads"}) do
		local spec = def[key]
		if spec and timer(state, key, spec.Every) then
			local p = pickOne()
			local r = ctx.root(p.Player)
			if r and countNear(zones, planetId, r.Position, 140, function(_, z) return z.Kind == spec.Kind end) < (spec.Max or 4) then
				local at = spotNear(planetId, r.Position, spec.Near[1], spec.Near[2])
				if at then PlanetLife.Zone(planetId, spec, at, {Weather = state.Id}) end
			end
		end
	end
	-- breakables
	local brk = def.Breakables
	if brk and timer(state, "Breakables", brk.Every / math.max(1, n ^ 0.5)) then
		local p = pickOne()
		local r = ctx.root(p.Player)
		if r and countNear(breakables, planetId, r.Position, 140, function(_, b) return b.Kind == brk.Kind end) < brk.Max then
			local at = spotNear(planetId, r.Position, brk.Near[1], brk.Near[2])
			if at then
				local rec = PlanetLife.Breakable(planetId, brk.Kind, CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), {Life = 90, Zone = 3,
					EggMult = brk.Egg and brk.Egg / math.max(0.01, Life.Breakables[brk.Kind].Egg) or 1})
				if rec then tell(planetId, at, "LifeSprout", {Position = at, Kind = brk.Kind}, 300) end
			end
		end
	end
	-- eggs the weather brings
	local eggs = def.Eggs
	if eggs and timer(state, "Eggs", eggs.Every / math.max(1, n ^ 0.5)) and weatherEggsAlive(state) < Life.MaxWeatherEggs * n then
		local p = pickOne()
		local r = ctx.root(p.Player)
		local at = r and spotNear(planetId, r.Position, eggs.Near[1], eggs.Near[2])
		if at then
			local height = eggs.Height and rng:NextNumber(eggs.Height[1], eggs.Height[2]) or 0
			local item = ctx.Expeditions.SpawnEventEgg(planetId, at + Vector3.new(0, height, 0), {Zone = 3, Boost = eggs.Boost, MutationStep = eggs.MutationStep,
				MinMutation = eggs.MinMutation, Life = eggs.Life or 60})
			if item then
				table.insert(state.Eggs, item)
				if eggs.Look then item:SetAttribute("Look", eggs.Look) end
				if eggs.Look == "Dig" or eggs.Look == "Grow" then
					tell(planetId, at, "EventStrike", {Kind = "Pumpkin", Position = at, Delay = 0.5, EggId = item:GetAttribute("EggId")}, 400)
				end
			end
		end
	end
	-- the flare: a warning, then everybody out of the shade gets burned; golden eggs after it
	local flare = def.Flare
	if flare then
		local t = now()
		state.FlareAt = state.FlareAt or (t + flare.Every)
		if not state.Warned and t >= state.FlareAt - flare.Warn then
			state.Warned = true
			workspace:SetAttribute("PFEFlareAt_" .. planetId, state.FlareAt)
			for _, p in ipairs(explorers) do ctx.effect(p.Player, "FlareWarn", {At = state.FlareAt}) end
		end
		if t >= state.FlareAt then
			state.FlareAt = t + flare.Every
			state.Warned = false
			for _, p in ipairs(explorers) do
				ctx.effect(p.Player, "Flare", {})
				if not shelteredBy(p) then hurt(p, flare.Damage, "The solar flare burned you!") end
				for _ = 1, flare.GoldenEggs or 0 do
					local r = ctx.root(p.Player)
					local at = r and spotNear(planetId, r.Position, 20, 70)
					if at then ctx.Expeditions.SpawnEventEgg(planetId, at, {Zone = 3, Boost = 2, MinMutation = "Golden", Life = 60}) end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- per-explorer effects (twice a second)
local function explorerEffects(profile, dt)
	local def = weatherNow[profile.Planet] and weatherNow[profile.Planet].Def
	local onSurface = profile.Expedition and not profile.Busy and not profile.InDungeon and not profile.InCave and Config.Planets[profile.Planet]
	local shelter = onSurface and shelteredBy(profile) or nil
	-- walk speed (blizzard, heatwave)
	local speed = 1
	if onSurface and def and def.Speed and not shelter then speed = def.Speed end
	if profile.WeatherSpeed ~= speed then
		profile.WeatherSpeed = speed
		ctx.setMovement(profile)
	end
	-- the HUD: under shelter or not (only while the weather has shelters)
	local value = nil
	if onSurface and def and (def.Shelter ~= nil or def.Flare ~= nil) then value = shelter ~= nil end
	if profile.Player:GetAttribute("PFESheltered") ~= value then profile.Player:SetAttribute("PFESheltered", value) end
	profile.ZoneAir = nil
	if not onSurface then return end
	-- burning (acid rain, the blizzard's cold) / warming up at the fire
	if def and def.Burn and not shelter then hurt(profile, def.Burn * dt, "The " .. string.lower(def.Name) .. " got you!") end
	if shelter and shelter.Heal then
		local humanoid = ctx.humanoid(profile.Player)
		if humanoid and humanoid.Health > 0 then humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + shelter.Heal * dt) end
	end
	-- hazard patches
	local r = ctx.root(profile.Player)
	if not r then return end
	local t = now()
	for model, z in pairs(zones) do
		if z.Planet == profile.Planet and t >= z.ArmedAt and model.Parent and insideZone(z, r.Position) then
			local spec = z.Spec
			if spec.Damage then hurt(profile, spec.Damage * dt, "You fell into a " .. string.lower(z.Kind) .. "!") end
			if spec.Air then profile.ZoneAir = math.max(profile.ZoneAir or 1, spec.Air) end
			if spec.Launch and t >= (profile.LaunchReady or 0) then
				profile.LaunchReady = t + 1.2
				ctx.effect(profile.Player, "Launch", {Velocity = Vector3.new(0, spec.Launch, 0), Kind = z.Kind})
			end
			if spec.Teleport and t >= (profile.GlitchReady or 0) then
				profile.GlitchReady = t + 2.5
				local to = spotNear(profile.Planet, r.Position, spec.Teleport[1], spec.Teleport[2])
				if to and profile.Player.Character then
					profile.Player.Character:PivotTo(CFrame.new(to + Vector3.new(0, 4, 0)) * (r.CFrame - r.CFrame.Position))
					ctx.effect(profile.Player, "Glitch", {})
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- geodes around the explorers (any weather)
local function runGeodes(planetId, explorers, state)
	local g = Life.Geodes
	if not timer(state, "Geodes", g.Every) then return end
	for _, p in ipairs(explorers) do
		local r = ctx.root(p.Player)
		if r and countNear(breakables, planetId, r.Position, g.Near[2] + 40, function(_, b) return b.Opts.Geode end) < g.PerExplorer then
			local at = spotNear(planetId, r.Position, g.Near[1], g.Near[2])
			if at then
				local kind = g.Kinds[rng:NextInteger(1, #g.Kinds)]
				PlanetLife.Breakable(planetId, kind, CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), {Geode = true, Life = 240, Zone = 3})
				break
			end
		end
	end
end

-- ---------------------------------------------------------------- the loop
local function step(dt)
	local t = now()
	-- every planet always has weather (the schedule runs everywhere; the things only where somebody explores)
	for _, planet in ipairs(Config.PlanetOrder) do
		local state = weatherNow[planet.Id]
		if not state or t >= state.EndsAt then state = startWeather(planet.Id) end
		local explorers = surfaceExplorers(planet.Id)
		if #explorers > 0 then
			local ok, err = pcall(runWeather, planet.Id, state, explorers)
			if not ok then warn("[PFE] weather", state.Id, "failed:", err) end
			ok, err = pcall(runGeodes, planet.Id, explorers, state)
			if not ok then warn("[PFE] geodes failed:", err) end
		end
	end
	-- leftovers: shelters past their time, zones, coins; things nobody is near any more
	for model, s in pairs(shelters) do
		if t >= s.Expires or not model.Parent then shelters[model] = nil; if model.Parent then model:Destroy() end end
	end
	for model, z in pairs(zones) do
		if (t >= z.Expires and not z.Moving) or not model.Parent then PlanetLife.RemoveZone(model) end
	end
	for coin, c in pairs(coins) do
		if t >= c.Expires or not coin.Parent then coins[coin] = nil; if coin.Parent then coin:Destroy() end end
	end
	-- geodes far from everybody go away (the next explorer gets fresh ones)
	for model, b in pairs(breakables) do
		if b.Opts.Geode and t - b.Born > 30 then
			local close = false
			for _, p in pairs(ctx.profiles) do
				local r = p.Planet == b.Planet and ctx.root(p.Player)
				if r and flat(r.Position, b.Position) < 500 then close = true; break end
			end
			if not close then PlanetLife.RemoveBreakable(b) end
		end
	end
end

local function fastStep(dt)
	for _, profile in pairs(ctx.profiles) do
		local ok, err = pcall(explorerEffects, profile, dt)
		if not ok then warn("[PFE] weather effects failed:", err) end
	end
	-- coins: picked up by walking over them
	for coin, c in pairs(coins) do
		if coin.Parent then
			for _, p in pairs(ctx.profiles) do
				local r = p.Planet == c.Planet and ctx.root(p.Player)
				if r and (r.Position - coin.Position).Magnitude < 7 then
					coins[coin] = nil
					p.Data.Coins = math.min(1e15, p.Data.Coins + c.Value)
					ctx.effect(p.Player, "Coins", {Amount = c.Value})
					tell(c.Planet, coin.Position, "LifeCoinTaken", {Position = coin.Position}, 200)
					coin:Destroy()
					ctx.markDirty(p)
					break
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- the bat on things
local lastSmash = {}
local function smash(player, model)
	local profile = ctx.profiles[player]
	if not profile or typeof(model) ~= "Instance" or profile.Busy then return end
	local record = targets[model]
	if not record or not model.Parent or record.Planet ~= profile.Planet or not canHit(record) then return end
	if profile.Stolen or (profile.Expedition and profile.Expedition.CarryingEgg) then return end
	local character = player.Character
	if not character or not character:FindFirstChild("Bat") then return end
	local t = os.clock()
	if t - (lastSmash[player] or 0) < Config.Bat.Cooldown * 0.9 then return end
	local r = ctx.root(player)
	if not r then return end
	local centre = record.Center()
	local reach = Config.Bat.Range + Config.Bat.Tolerance + record.Radius
	if (centre - r.Position).Magnitude > reach + 4 then return end
	lastSmash[player] = t
	for _, p in ipairs(viewers(profile.Planet, centre, 120)) do ctx.effect(p.Player, "BatHit", {Position = centre:Lerp(r.Position, 0.4)}) end
	record.Hit(Life.BatDamage, profile, "Bat")
end

-- ---------------------------------------------------------------- hooks for the rest of the game
local function airMultiplier(profile)
	if profile.InCave then return Life.Caves.AirRate end
	local m = 1
	local def = weatherNow[profile.Planet] and weatherNow[profile.Planet].Def
	if def and def.Air and not shelteredBy(profile) then m *= def.Air end
	if profile.ZoneAir then m *= profile.ZoneAir end
	return m
end

function PlanetLife.OnLeft(profile)
	lastSmash[profile.Player] = nil
end

function PlanetLife.Init(context)
	ctx = context
	Config = ctx.Config
	Life = require(ctx.network:WaitForChild("LifeConfig"))
	ctx.Life = Life
	ctx.PlanetLife = PlanetLife
	PlanetLife.Ctx = ctx   -- (the admin commands and the offline tests reach the game through it)
	root = workspace:FindFirstChild("PFE_PlanetLife") or Instance.new("Folder")
	root.Name = "PFE_PlanetLife"; root.Parent = workspace
	for _, planet in ipairs(Config.PlanetOrder) do planetFolder(planet.Id) end
	ctx.AirMultiplier = airMultiplier
	ctx.LaserTargets = PlanetLife.LaserTarget
	ctx.remotes.Smash = ctx.remotes.Smash or (function()
		local r = ctx.network:FindFirstChild("Smash") or Instance.new("RemoteEvent")
		r.Name = "Smash"; r.Parent = ctx.network
		return r
	end)()
	ctx.remotes.Smash.OnServerEvent:Connect(function(player, model)
		local ok, err = pcall(smash, player, model)
		if not ok then warn("[PFE] smash failed", err) end
	end)
	Players.PlayerRemoving:Connect(function(player) lastSmash[player] = nil end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.25)
			local t = os.clock()
			local ok, err = pcall(step, t - last)
			if not ok then warn("[PFE] planet life step failed", err) end
			last = t
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.5)
			local t = os.clock()
			local ok, err = pcall(fastStep, math.min(1, t - last))
			if not ok then warn("[PFE] planet life effects failed", err) end
			last = t
		end
	end)
	-- the bosses, the Golden Egg race
	for _, name in ipairs({"Bosses", "GoldenRace"}) do
		local ok, module = pcall(require, script:WaitForChild(name))
		if ok then
			local okInit, err = pcall(module.Init, ctx, PlanetLife)
			if not okInit then warn("[PFE] " .. name .. " init failed", err) end
			PlanetLife[name] = module
		else
			warn("[PFE] " .. name .. " failed to load", module)
		end
	end
end

return PlanetLife
