--!nocheck
-- Alien NPCs on the planets and in the alien ships, and the players' raygun that fights them.
--  * The aliens are the models in ReplicatedStorage.PFE.Aliens: Dead Rails' melee alien and raygun
--    alien (build_assets.py). A model named after a kind (AlienScout, AlienGunner...) or with an
--    AlienType attribute plays that kind; otherwise a model's AlienRole ("Melee" / "Ranged") picks
--    the kinds it plays (scouts and brutes melee, the rest shoot). The big kinds are the same aliens,
--    scaled up and tinted. A model with its own Humanoid is used as it is (its Tool becomes a gun
--    welded to the hand); a plain model of parts is rigged as R6 here. No models, no aliens.
--  * A planet with explorers on it gets a handful of aliens scattered around its map (never on the
--    landing pad). The cooler the planet, the tougher the kinds that show up (Scout -> Commander)
--    and the more health and damage they have. They despawn a while after the last explorer left.
--  * They stroll from side to side around their spot. Come within Config.Aliens.AggroRange and they
--    come for you: the melee kinds hit you up close, the others shoot laser bolts. They give up
--    past LeashRange, when you reach the landing pad, fly off or die.
--  * Groups: the waves of the alien ships (Aliens.SpawnGroup). They only go for that ship's crew,
--    never respawn, and the ship opens its airlock once Aliens.GroupAlive is 0.
--  * The raygun (every player has one, 99 Nights' energy rules): the client sends where it aimed,
--    the server finds the first alien along that line (with a little tolerance for lag), damages it
--    and shows the shot to everyone around. A kill pays a bounty scaled by the planet.
local Players = game:GetService("Players")
local Aliens = {}
local ctx, Config, A, R
local rng = Random.new()
local folder
local templates = {}      -- type id -> rigged template (false: no model for it)
local planets = {}        -- planetId -> {Aliens = {record}, EmptySince = t, Pending = n}
local groups = {}         -- tag -> {Aliens = {record}, Planet, Members = fn -> {profile}}
local byModel = {}        -- model -> record
local lastShot = {}

local ANIM = {Walk = "rbxassetid://180426354", Idle = "rbxassetid://180435571", Hold = "rbxassetid://182393478", Slash = "rbxassetid://129967390"}
local ANIM_R15 = {Walk = "rbxassetid://507777826", Idle = "rbxassetid://507766666", Hold = "rbxassetid://507768375"}
local R6 = {
	Torso = {Vector3.new(2, 2, 1), CFrame.new(0, 3, 0)}, Head = {Vector3.new(2, 1, 1), CFrame.new(0, 4.5, 0)},
	["Left Arm"] = {Vector3.new(1, 2, 1), CFrame.new(-1.5, 3, 0)}, ["Right Arm"] = {Vector3.new(1, 2, 1), CFrame.new(1.5, 3, 0)},
	["Left Leg"] = {Vector3.new(1, 2, 1), CFrame.new(-0.5, 1, 0)}, ["Right Leg"] = {Vector3.new(1, 2, 1), CFrame.new(0.5, 1, 0)},
}
local JOINTS = {
	{"RootJoint", "HumanoidRootPart", "Torso", CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)},
	{"Neck", "Torso", "Head", CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)},
	{"Left Shoulder", "Torso", "Left Arm", CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)},
	{"Right Shoulder", "Torso", "Right Arm", CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)},
	{"Left Hip", "Torso", "Left Leg", CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)},
	{"Right Hip", "Torso", "Right Leg", CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)},
}

-- ---------------------------------------------------------------- models
local function modelBox() return ctx.network:FindFirstChild("Aliens") end
local function alienModels()
	local list = {}
	local box = modelBox()
	for _, m in ipairs(box and box:GetChildren() or {}) do
		if m:IsA("Model") then table.insert(list, m) end
	end
	table.sort(list, function(a, b) return a.Name < b.Name end)
	return list
end
function Aliens.HasModels() return #alienModels() > 0 end

-- the model a kind uses: its own (by name or AlienType), else one of its role (melee / ranged),
-- else the kinds take turns on the models there are
local function sourceFor(info)
	local models = alienModels()
	if #models == 0 then return nil end
	for _, m in ipairs(models) do if m.Name == info.Id or m:GetAttribute("AlienType") == info.Id then return m end end
	local role = info.Ranged and "Ranged" or "Melee"
	for _, m in ipairs(models) do if m:GetAttribute("AlienRole") == role then return m end end
	local index = 1
	for i, t in ipairs(A.Types) do if t.Id == info.Id then index = i end end
	return models[(index - 1) % #models + 1]
end

local function finishRig(rig, humanoid, info)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = info.Speed
	if not humanoid:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = humanoid end
	rig.Name = info.Id
	rig:SetAttribute("AlienType", info.Id)
	return rig
end

-- the tougher kinds wear their colour (the scouts and gunners keep the alien green)
local TINTED = {AlienBrute = 0.45, AlienElite = 0.4, AlienCommander = 0.35}
local function tint(rig, info)
	local k = TINTED[info.Id]
	local colors = rig:FindFirstChildOfClass("BodyColors")
	if not k or not colors or not info.Color then return end
	for _, prop in ipairs({"HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3"}) do
		local c = colors[prop]
		if typeof(c) == "Color3" then colors[prop] = c:Lerp(info.Color, k) end
	end
end

-- a model that already is a character (Dead Rails' aliens are): used as it is
local function useRigged(source, info)
	local rig = source:Clone()
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then d:Destroy() end
	end
	-- a Tool it holds (Dead Rails' raygun alien) becomes a gun welded to its hand, where it already is
	local hand = rig:FindFirstChild("Right Arm") or rig:FindFirstChild("RightHand")
	for _, tool in ipairs(rig:GetChildren()) do
		if tool:IsA("Tool") then
			local gun = Instance.new("Model")
			gun.Name = "Gun"
			local handle = tool:FindFirstChild("Handle")
			for _, part in ipairs(tool:GetChildren()) do
				if part:IsA("BasePart") then part.CanCollide = false; part.Massless = true; part.Parent = gun end
			end
			if handle and hand then
				local weld = Instance.new("WeldConstraint"); weld.Name = "GunGrip"; weld.Part0 = hand; weld.Part1 = handle; weld.Parent = handle
			end
			gun.Parent = rig
			tool:Destroy()
		end
	end
	tint(rig, info)
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local root = rig:FindFirstChild("HumanoidRootPart") or rig.PrimaryPart
	if not root then return nil end
	rig.PrimaryPart = root
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = false; d.CanTouch = false end
	end
	if math.abs((info.Scale or 1) - 1) > 0.01 then pcall(function() rig:ScaleTo(rig:GetScale() * info.Scale) end) end
	return finishRig(rig, humanoid, info)
end

-- a plain model of parts: rigged as a standard R6 character around its pivot
local function rigR6(source, info)
	local visual = source:Clone()
	local base = visual:GetPivot()
	local rig = Instance.new("Model")
	local limbs = {}
	for name, spec in pairs(R6) do
		local p = visual:FindFirstChild(name)
		if not (p and p:IsA("BasePart")) then p = Instance.new("Part"); p.Transparency = 1 end
		p.Name = name; p.Size = spec[1]; p.CFrame = base * spec[2]
		p.Anchored = false; p.CanCollide = name == "Torso" or name == "Head"; p.CanTouch = false; p.CanQuery = true
		p.Parent = rig
		limbs[name] = p
	end
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"; root.Size = Vector3.new(2, 2, 1); root.CFrame = base * CFrame.new(0, 3, 0)
	root.Transparency = 1; root.CanCollide = false; root.CanTouch = false; root.CanQuery = true; root.Anchored = false
	root.Parent = rig
	limbs.HumanoidRootPart = root
	rig.PrimaryPart = root
	for _, j in ipairs(JOINTS) do
		local m = Instance.new("Motor6D")
		m.Name = j[1]; m.Part0 = limbs[j[2]]; m.Part1 = limbs[j[3]]; m.C0 = j[4]; m.C1 = j[5]
		m.Parent = limbs[j[2]]
	end
	for _, d in ipairs(visual:GetDescendants()) do
		if d:IsA("BasePart") and not limbs[d.Name] then
			local limb = limbs[d:GetAttribute("Role") or ""] or (d.Name == "Muzzle" and limbs["Right Arm"]) or limbs.Torso
			d.Anchored = false; d.CanCollide = false; d.CanTouch = false; d.CanQuery = true; d.Massless = true
			local weld = Instance.new("WeldConstraint"); weld.Part0 = limb; weld.Part1 = d; weld.Parent = d
			d.Parent = rig
		end
	end
	visual:Destroy()
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = rig
	if math.abs((info.Scale or 1) - 1) > 0.01 then pcall(function() rig:ScaleTo(info.Scale) end) end
	return finishRig(rig, humanoid, info)
end

local function templateFor(info)
	if templates[info.Id] == nil then
		local source = sourceFor(info)
		local rig
		if source then
			local ok, result = pcall(function()
				if source:FindFirstChildOfClass("Humanoid") then return useRigged(source, info) end
				return rigR6(source, info)
			end)
			if ok then rig = result else warn("[PFE] alien model " .. source.Name .. " failed: " .. tostring(result)) end
		end
		templates[info.Id] = rig or false
	end
	return templates[info.Id] or nil
end

-- ---------------------------------------------------------------- helpers
local function now() return os.clock() end
local function planetCentre(planetId)
	local planet = Config.Planets[planetId]
	return planet and planet.Origin
end
local function inSafeZone(planetId, position)
	local centre = planetCentre(planetId)
	if not centre then return true end
	local d = position - centre
	return Vector2.new(d.X, d.Z).Magnitude < A.SafeRadius
end
local function explorersOn(planetId)
	local list = {}
	for _, p in pairs(ctx.profiles) do
		if p.Expedition and p.Expedition.Planet == planetId and p.Planet == planetId and not p.Busy and not p.InDungeon and ctx.root(p.Player) then
			table.insert(list, p)
		end
	end
	return list
end
local function groundY(planetId, x, z)
	local planet = ctx.planets:FindFirstChild(planetId)
	local centre = planetCentre(planetId)
	local fallback = centre.Y
	local landing = planet and planet:FindFirstChild("Landing")
	if landing then fallback = landing.Position.Y - landing.Size.Y / 2 end
	if planet then
		local ok, result = pcall(function()
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = {planet}
			return workspace:Raycast(Vector3.new(x, centre.Y + 400, z), Vector3.new(0, -900, 0), params)
		end)
		if ok and result then return result.Position.Y end
	end
	return fallback
end
-- a spot on the planet, off the landing pad
local function randomSpot(planetId, near, radius)
	local planet = Config.Planets[planetId]
	local centre = planet.Origin
	local size = (planet.Radius or 560) - 40
	for _ = 1, 12 do
		local x, z
		if near then
			local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(6, radius)
			x, z = near.X + math.cos(a) * d, near.Z + math.sin(a) * d
		else
			local a, d = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber((A.SafeRadius + 30) ^ 2 / size ^ 2, 1)) * size
			x, z = centre.X + math.cos(a) * d, centre.Z + math.sin(a) * d
		end
		local rel = Vector2.new(x - centre.X, z - centre.Z)
		if rel.Magnitude > A.SafeRadius + 8 and rel.Magnitude < size then
			return Vector3.new(x, groundY(planetId, x, z), z)
		end
	end
	return nil
end

local function pickType(order)
	local total, list = 0, {}
	for _, t in ipairs(A.Types) do
		if order >= t.MinPlanet then
			local w = t.Weight * math.min(3, order - t.MinPlanet + 1)
			total += w; table.insert(list, {t, w})
		end
	end
	local roll = rng:NextNumber() * total
	for _, entry in ipairs(list) do
		roll -= entry[2]
		if roll <= 0 then return entry[1] end
	end
	return list[#list] and list[#list][1] or A.Types[1]
end

local function send(planetId, kind, payload, except)
	for _, p in pairs(ctx.profiles) do
		if p.Planet == planetId and p.Player ~= except then ctx.effect(p.Player, kind, payload) end
	end
end
-- the players who see what an alien does: the ship's crew for a group, the planet otherwise
local function sendFor(record, kind, payload)
	local group = record.Group and groups[record.Group]
	if group then
		for _, p in ipairs(group.Members()) do ctx.effect(p.Player, kind, payload) end
	elseif not record.Group then
		send(record.Planet, kind, payload)
	end
end
local function holderOf(record)
	if record.Group then return groups[record.Group] end
	return planets[record.Planet]
end

-- an animation for this rig: the model's own (an Animation named like Walk / Idle / Attack) first
local function animationId(record, key)
	record.OwnAnims = record.OwnAnims or {}
	if record.OwnAnims[key] == nil then
		local wanted = key == "Slash" and "attack" or string.lower(key)
		local found = false
		for _, d in ipairs(record.Model:GetDescendants()) do
			if d:IsA("Animation") and string.find(string.lower(d.Name), wanted, 1, true) then found = d.AnimationId; break end
		end
		record.OwnAnims[key] = found
	end
	if record.OwnAnims[key] then return record.OwnAnims[key] end
	if record.Humanoid.RigType == Enum.HumanoidRigType.R15 then return ANIM_R15[key] end
	return ANIM[key]
end
local function play(record, key, looped, priority)
	local ok = pcall(function()
		record.Tracks = record.Tracks or {}
		local track = record.Tracks[key]
		if not track then
			local id = animationId(record, key)
			if not id then return end
			local animation = Instance.new("Animation"); animation.AnimationId = id
			local animator = record.Humanoid:FindFirstChildOfClass("Animator")
			track = animator:LoadAnimation(animation)
			track.Looped = looped
			if priority then track.Priority = priority end
			record.Tracks[key] = track
		end
		if not track.IsPlaying then track:Play(0.2) end
	end)
	return ok
end
local function stop(record, key)
	pcall(function()
		local track = record.Tracks and record.Tracks[key]
		if track and track.IsPlaying then track:Stop(0.2) end
	end)
end

-- the health bar over the head: 99 Nights' enemy HealthBar (a 4 x 0.8 stud billboard, dark frame),
-- one solid green bar
local BAR_DARK = Color3.fromRGB(43, 43, 43)
local function makeBar(record)
	local head = record.Model:FindFirstChild("Head") or record.Root
	if not head then return end
	local scale = record.Type.Scale or 1
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"; gui.Size = UDim2.fromScale(4 * scale, 0.8 * scale); gui.StudsOffsetWorldSpace = Vector3.new(0, 3 * scale, 0)
	gui.AlwaysOnTop = true; gui.MaxDistance = 400; gui.LightInfluence = 0; gui.Adornee = head; gui.Parent = record.Model
	local frame = Instance.new("Frame")
	frame.Name = "HealthBar"; frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.Position = UDim2.fromScale(0.5, 0.5); frame.Size = UDim2.fromScale(0.8, 0.8)
	frame.BackgroundColor3 = BAR_DARK; frame.BorderSizePixel = 0; frame.Parent = gui
	local stroke = Instance.new("UIStroke"); stroke.Color = BAR_DARK; stroke.Thickness = 2; stroke.Parent = frame
	local fill = Instance.new("Frame")
	fill.Name = "Bar"; fill.AnchorPoint = Vector2.new(0, 0.5); fill.Position = UDim2.fromScale(0, 0.5); fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(0, 170, 0); fill.BorderSizePixel = 0; fill.Parent = frame
	record.Bar = fill
end
local function refreshBar(record)
	if not record.Bar then return end
	local h = record.Humanoid
	record.Bar.Size = UDim2.fromScale(math.clamp(h.Health / math.max(1, h.MaxHealth), 0, 1), 1)
end

-- ---------------------------------------------------------------- spawning
-- one alien on a planet (spot: a random one) or in a ship's group (tier: how tough, beyond the planet's)
local function spawnAlien(planetId, spot, groupTag, extraTier)
	local planet = Config.Planets[planetId]
	spot = spot or randomSpot(planetId)
	if not spot then return nil end
	-- out on the planet: 0 by the landing pad .. 1 at the edge of the map (tougher aliens out there)
	local edge = 0
	if not groupTag then
		local d = Vector2.new(spot.X - planet.Origin.X, spot.Z - planet.Origin.Z).Magnitude
		edge = math.clamp((d - A.SafeRadius) / math.max(1, (planet.Radius or 560) - 40 - A.SafeRadius), 0, 1)
	end
	local tier = (planet.Order or 1) - 1 + (extraTier or 0)
	local info = pickType((planet.Order or 1) + (extraTier or 0) + math.floor(edge * (A.EdgeTiers or 0) + 0.5))
	local template = templateFor(info)
	if not template then return nil end
	local model = template:Clone()
	local _, size = model:GetBoundingBox()
	local lift = math.max(3 * (info.Scale or 1), size and size.Y / 2 or 0) + 0.2
	model:PivotTo(CFrame.new(spot + Vector3.new(0, lift, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.MaxHealth = math.floor(info.Health * (1 + tier * A.HealthPerPlanet) * (1 + edge * (A.EdgeHealth or 0)) + 0.5)
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = info.Speed
	model:SetAttribute("Planet", planetId)
	if groupTag then model:SetAttribute("Dungeon", groupTag) end
	model.Parent = folder
	local root = model.PrimaryPart
	pcall(function() root:SetNetworkOwner(nil) end)
	local record = {Model = model, Humanoid = humanoid, Root = root, Type = info, Planet = planetId, Home = spot, Group = groupTag,
		Damage = math.floor(info.Damage * (1 + tier * A.DamagePerPlanet) * (1 + edge * (A.EdgeDamage or 0)) + 0.5), Edge = edge,
		NextAttack = 0, NextWander = now() + rng:NextNumber(0.5, 3)}
	byModel[model] = record
	makeBar(record)
	play(record, "Idle", true)
	if info.Ranged then play(record, "Hold", true, Enum.AnimationPriority.Action) end
	humanoid.Running:Connect(function(speed)
		if speed > 0.6 then play(record, "Walk", true, Enum.AnimationPriority.Movement) else stop(record, "Walk") end
	end)
	humanoid.HealthChanged:Connect(function() refreshBar(record) end)
	table.insert(holderOf(record).Aliens, record)
	return record
end

local function removeAlien(record)
	byModel[record.Model] = nil
	local holder = holderOf(record)
	if holder then
		for i, r in ipairs(holder.Aliens) do if r == record then table.remove(holder.Aliens, i); break end end
	end
	if record.Model.Parent then record.Model:Destroy() end
end

local function targetCount(planetId, explorers)
	local planet = Config.Planets[planetId]
	return math.min(A.Max, A.Base + math.ceil((planet.Order or 1) * A.PerPlanet) + math.max(0, explorers - 1) * A.PerExtraExplorer)
end

-- ---------------------------------------------------------------- combat
local function die(record, killer)
	if record.Dead then return end
	record.Dead = true
	record.Humanoid.Health = 0
	local position = record.Root.Position
	sendFor(record, "AlienDied", {Position = position, Color = record.Type.Color})
	if killer and ctx.profiles[killer.Player] == killer then
		local planet = Config.Planets[record.Planet]
		local bounty = math.max(1, math.floor((planet.Reward or 100) * record.Type.Bounty * (1 + (record.Edge or 0))))
		killer.Data.Coins += bounty
		killer.Data.Stats.AliensDefeated = (killer.Data.Stats.AliensDefeated or 0) + 1
		ctx.notice(killer, record.Type.Name .. " defeated! +" .. Config.Format(bounty) .. " coins", "Green")
		ctx.markDirty(killer)
	end
	task.delay(1.2, function() removeAlien(record) end)
	if record.Group then return end -- a ship's wave doesn't come back
	local state = planets[record.Planet]
	if state then state.Pending = (state.Pending or 0) + 1 end
	task.delay(rng:NextNumber(A.RespawnDelay[1], A.RespawnDelay[2]), function()
		local s = planets[record.Planet]
		if s then
			s.Pending = math.max(0, (s.Pending or 1) - 1)
			local explorers = #explorersOn(record.Planet)
			if explorers > 0 and #s.Aliens < targetCount(record.Planet, explorers) then spawnAlien(record.Planet) end
		end
	end)
end

function Aliens.Damage(record, amount, attacker)
	if record.Dead or record.Humanoid.Health <= 0 then return end
	record.Humanoid:TakeDamage(amount)
	refreshBar(record)
	if attacker then record.Target = attacker end
	if record.Humanoid.Health <= 0 then die(record, attacker) end
end

local function hurtPlayer(record, target, amount, knockback)
	local humanoid = ctx.humanoid(target.Player)
	if not humanoid or humanoid.Health <= 0 then return end
	if humanoid.Health - amount <= 0 then target.DeathReason = "A " .. record.Type.Name .. " got you!" end
	humanoid:TakeDamage(amount)
	ctx.effect(target.Player, "AlienHit", {From = record.Root.Position, Force = knockback or 0, Damage = amount})
end

local function face(record, position)
	local root = record.Root
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude > 0.1 then root.CFrame = CFrame.lookAt(root.Position, flat) end
end

-- can this alien go after this player? (a ship's aliens: its crew; a planet's: explorers off the pad)
local function fairGame(record, p, troot)
	if not troot or ctx.profiles[p.Player] ~= p or p.Busy then return false end
	-- (v41) a cave's aliens go for the explorers in that planet's cave
	if record.Group and string.sub(record.Group, 1, 5) == "Cave_" then return p.InCave == record.Planet and p.Planet == record.Planet end
	if record.Group then return p.InDungeon == record.Group end
	return p.Planet == record.Planet and p.Expedition ~= nil and not p.InDungeon and not p.InCave and not inSafeZone(record.Planet, troot.Position)
end

-- nothing solid between the alien's eyes and the player (crates, walls, rocks, trees stop its shots)
local function clearShot(record, target, troot)
	local from = record.Root.Position + Vector3.new(0, 1.5, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local ignore = {record.Model}
	if folder then table.insert(ignore, folder) end
	local character = target.Player.Character
	if character then table.insert(ignore, character) end
	params.FilterDescendantsInstances = ignore
	local to = troot.Position + Vector3.new(0, 0.5, 0)
	local hit = workspace:Raycast(from, to - from, params)
	return hit == nil
end

local function shoot(record, target, troot)
	record.NextAttack = now() + record.Type.Cooldown * rng:NextNumber(0.85, 1.2)
	local gun = record.Model:FindFirstChild("Gun")
	local muzzle = record.Model:FindFirstChild("Muzzle", true) or (gun and (gun:FindFirstChild("Glass") or gun:FindFirstChild("Handle")))
	local from = muzzle and muzzle:IsA("BasePart") and muzzle.Position or (record.Root.Position + Vector3.new(0, 1.5, 0))
	local d = (troot.Position - from).Magnitude
	local chance = (record.Type.Accuracy or 0.7) * (1 - 0.35 * math.clamp(d / A.ShootRange, 0, 1))
	local hit = rng:NextNumber() < chance
	local to = troot.Position
	if not hit then to += Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(-1, 3), rng:NextNumber(-5, 5)) end
	sendFor(record, "AlienShot", {From = from, To = to, Color = record.Type.Color, Hit = hit, Big = record.Type.Id == "AlienCommander"})
	if hit then
		local flight = d / 120
		task.delay(flight, function()
			local now_root = ctx.root(target.Player)
			if now_root and record.Root.Parent and not clearShot(record, target, now_root) then return end -- (hid behind something)
			if fairGame(record, target, now_root) or (record.Group == nil and ctx.profiles[target.Player] == target and target.Planet == record.Planet) then
				hurtPlayer(record, target, record.Damage)
			end
		end)
	end
end

local function melee(record, target)
	record.NextAttack = now() + record.Type.Cooldown
	play(record, "Slash", false, Enum.AnimationPriority.Action)
	hurtPlayer(record, target, record.Damage, record.Type.Knockback)
end

-- one AI step for one alien
local function think(record, explorers)
	local root, humanoid = record.Root, record.Humanoid
	if record.Dead or not root.Parent or humanoid.Health <= 0 then return end
	local position = root.Position
	local scale = record.Type.Scale or 1
	-- aboard a ship the aliens see the whole hall and never give up (v41: in a cave they see as far as the dark lets them)
	local ship = record.Group and string.sub(record.Group, 1, 5) ~= "Cave_"
	local aggro = ship and A.ShipAggroRange or A.AggroRange * scale
	local leash = ship and math.huge or (record.Group and 90 or A.LeashRange) * scale
	local target = record.Target
	if target then
		local troot = ctx.root(target.Player)
		if not fairGame(record, target, troot) or (troot.Position - position).Magnitude > leash then
			target = nil; record.Target = nil
			record.NextWander = 0
		end
	end
	if not target then
		for _, p in ipairs(explorers) do
			local troot = ctx.root(p.Player)
			if fairGame(record, p, troot) and (troot.Position - position).Magnitude <= aggro then
				target = p; record.Target = p
				sendFor(record, "AlienAlert", {Alien = record.Model})
				break
			end
		end
	end
	if target then
		local troot = ctx.root(target.Player)
		local d = (troot.Position - position).Magnitude
		local reach = A.MeleeRange * scale
		if record.Type.Ranged and d <= A.ShootRange and clearShot(record, target, troot) then
			humanoid:MoveTo(position)
			face(record, troot.Position)
			if now() >= record.NextAttack then shoot(record, target, troot) end
		elseif not record.Type.Ranged and d <= reach then
			humanoid:MoveTo(position)
			face(record, troot.Position)
			if now() >= record.NextAttack then melee(record, target) end
		else
			humanoid:MoveTo(troot.Position)
		end
		return
	end
	-- stroll from side to side around its spot
	if now() >= record.NextWander then
		record.NextWander = now() + rng:NextNumber(3.5, 7.5)
		if rng:NextNumber() < 0.75 then
			local spot
			if record.Group then
				local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(3, 9)
				spot = record.Home + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
			else
				spot = randomSpot(record.Planet, record.Home, A.WanderRadius)
			end
			if spot then humanoid:MoveTo(spot) end
		end
	end
end

-- ---------------------------------------------------------------- the raygun
-- the first alien along the shot (closest to the muzzle), within the tolerance of the line
local function alienAlong(list, origin, direction, length)
	local best, bestT
	local unit = direction.Unit
	for _, record in ipairs(list) do
		if not record.Dead and record.Root.Parent then
			local scale = record.Type.Scale or 1
			for _, point in ipairs({record.Root.Position, record.Root.Position + Vector3.new(0, 1.8 * scale, 0)}) do
				local rel = point - origin
				local t = rel:Dot(unit)
				if t > 0 and t < length then
					local miss = (rel - unit * t).Magnitude
					if miss <= R.HitTolerance * scale and (not bestT or t < bestT) then best, bestT = record, t end
				end
			end
		end
	end
	return best, bestT
end

-- ---------------------------------------------------------------- raygun energy (99 Nights rules)
-- player attributes the AlienBar reads: EnergyAmmo (0..EnergyMax) and EnergyOverheat
local energy = {} -- player -> {Value, OverheatUntil}
local function energyOf(player)
	local e = energy[player]
	if not e then
		e = {Value = R.EnergyMax, OverheatUntil = 0}
		energy[player] = e
		player:SetAttribute("EnergyMax", R.EnergyMax)
		player:SetAttribute("EnergyAmmo", R.EnergyMax)
		player:SetAttribute("EnergyOverheat", false)
	end
	return e
end
local function publishEnergy(player, e)
	player:SetAttribute("EnergyAmmo", math.floor(e.Value * 10 + 0.5) / 10)
	player:SetAttribute("EnergyOverheat", os.clock() < e.OverheatUntil)
end
function Aliens.Energy(player) return energyOf(player).Value end

local function fire(player, aim)
	local profile = ctx.profiles[player]
	if not profile or typeof(aim) ~= "Vector3" or aim ~= aim then return end
	if profile.Busy or profile.Stolen or (profile.Expedition and profile.Expedition.CarryingEgg) then return end
	local character = player.Character
	local gun = character and character:FindFirstChild("Raygun")
	local head = character and character:FindFirstChild("Head")
	if not gun or not head or not ctx.root(player) then return end
	local t = os.clock()
	if t - (lastShot[player] or 0) < R.Cooldown * 0.8 then return end
	local e = energyOf(player)
	if t < e.OverheatUntil or e.Value < R.EnergyCost then return end
	lastShot[player] = t
	e.Value -= R.EnergyCost
	if e.Value < R.EnergyCost then
		-- run dry: overheat, then back to full
		e.Value = 0
		e.OverheatUntil = t + R.OverheatDuration
	end
	publishEnergy(player, e)
	local muzzle = gun:FindFirstChild("MuzzlePart") or gun:FindFirstChild("Muzzle")
	local origin = head.Position
	if muzzle and (muzzle.Position - head.Position).Magnitude < 8 then origin = muzzle.Position end
	local direction = aim - origin
	if direction.Magnitude < 0.5 then return end
	local length = math.min(direction.Magnitude + 6, R.Range)
	local group = profile.InDungeon and groups[profile.InDungeon]
	local list = group and group.Aliens or (planets[profile.Planet] and planets[profile.Planet].Aliens) or {}
	-- (v41) in a cave: its aliens too
	if not group and profile.InCave then
		list = table.clone(list)
		for tag, g in pairs(groups) do
			if string.sub(tag, 1, 5) == "Cave_" and g.Planet == profile.Planet then
				for _, r in ipairs(g.Aliens) do table.insert(list, r) end
			end
		end
	end
	local record, along = alienAlong(list, origin, direction, length)
	-- (v41) the bosses, crystals, rocks, chests... (PlanetLife) - whichever is first along the bolt
	local thing, thingAt
	if not group and ctx.LaserTargets then thing, thingAt = ctx.LaserTargets(profile, origin, direction.Unit, length) end
	if thing and (not along or thingAt < along) then record = nil; along = thingAt else thing = nil end
	-- walls, crates and rocks stop the bolt (both ways: the aliens can't shoot through them either)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local ignore = {character}
	if folder then table.insert(ignore, folder) end
	local life = workspace:FindFirstChild("PFE_PlanetLife")
	if life then table.insert(ignore, life) end
	params.FilterDescendantsInstances = ignore
	local wall = workspace:Raycast(origin, direction.Unit * (along or length), params)
	if wall then record = nil; thing = nil; along = (wall.Position - origin).Magnitude end
	local hitPosition = origin + direction.Unit * (along or length)
	if record then Aliens.Damage(record, R.Damage, profile) end
	if thing then thing.Hit(R.Damage * ((ctx.Life and ctx.Life.LaserScale) or 1), profile, "Laser") end
	if thing then record = true end -- (the bolt shows as a hit)
	local payload = {From = origin, To = hitPosition, Hit = record ~= nil, Shooter = player.UserId}
	if group then
		for _, p in ipairs(group.Members()) do if p.Player ~= player then ctx.effect(p.Player, "RaygunShot", payload) end end
	else
		send(profile.Planet, "RaygunShot", payload, player)
	end
end

-- (v35) a bot fires its raygun: the same bolt, the same hit, the same rules as fire() (no energy bar: it can't see one)
local botShot = setmetatable({}, {__mode = "k"})
function Aliens.BotShoot(profile, origin, aim)
	if typeof(aim) ~= "Vector3" or typeof(origin) ~= "Vector3" or profile.Busy or profile.Stolen then return false end
	if profile.Expedition and profile.Expedition.CarryingEgg then return false end
	local t = os.clock()
	if t - (botShot[profile] or 0) < R.Cooldown then return false end
	botShot[profile] = t
	local direction = aim - origin
	if direction.Magnitude < 0.5 then return false end
	local length = math.min(direction.Magnitude + 6, R.Range)
	local list = planets[profile.Planet] and planets[profile.Planet].Aliens or {}
	local record, along = alienAlong(list, origin, direction, length)
	-- (v41) the bosses, crystals and rocks too (PlanetLife), like a player's bolt (a bot's hit is softer)
	local thing, thingAt
	if ctx.LaserTargets then thing, thingAt = ctx.LaserTargets(profile, origin, direction.Unit, length) end
	if thing and (not along or thingAt < along) then record = nil; along = thingAt else thing = nil end
	local character = profile.Player.Character
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local ignore = {character}
	if folder then table.insert(ignore, folder) end
	local life = workspace:FindFirstChild("PFE_PlanetLife")
	if life then table.insert(ignore, life) end
	params.FilterDescendantsInstances = ignore
	local wall = workspace:Raycast(origin, direction.Unit * (along or length), params)
	if wall then record = nil; thing = nil; along = (wall.Position - origin).Magnitude end
	local hitPosition = origin + direction.Unit * (along or length)
	if record then Aliens.Damage(record, R.Damage, nil) end
	if thing then
		local Life = ctx.Life
		thing.Hit(R.Damage * (Life and Life.LaserScale or 1) * (Life and Life.BotDamage or 0.6), profile, "Laser")
	end
	send(profile.Planet, "RaygunShot", {From = origin, To = hitPosition, Hit = record ~= nil or thing ~= nil, Shooter = profile.Player.UserId})
	return record ~= nil or thing ~= nil
end

-- ---------------------------------------------------------------- groups (the alien ships' waves)
-- `count` aliens around `points` (Vector3s on the floor) that only go for members() (a list of
-- profiles); `tier` makes them tougher than the planet's own. Returns how many came (0: no models).
function Aliens.SpawnGroup(tag, planetId, points, count, members, tier)
	if not Config.Planets[planetId] or #points == 0 or not Aliens.HasModels() then return 0 end
	groups[tag] = groups[tag] or {Aliens = {}, Planet = planetId, Members = members}
	groups[tag].Members = members
	local spawned = 0
	for i = 1, count do
		local base = points[(i - 1) % #points + 1]
		local spot = base + Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
		if spawnAlien(planetId, spot, tag, (tier or 1) - 1) then spawned += 1 end
	end
	return spawned
end
function Aliens.GroupAlive(tag)
	local n = 0
	for _, r in ipairs(groups[tag] and groups[tag].Aliens or {}) do if not r.Dead then n += 1 end end
	return n
end
function Aliens.ClearGroup(tag)
	local group = groups[tag]
	if not group then return end
	for i = #group.Aliens, 1, -1 do removeAlien(group.Aliens[i]) end
	groups[tag] = nil
end

-- ---------------------------------------------------------------- lifecycle
function Aliens.Count(planetId)
	local state = planets[planetId]
	local n = 0
	for _, r in ipairs(state and state.Aliens or {}) do if not r.Dead then n += 1 end end
	return n
end
function Aliens.List(planetId)
	return planets[planetId] and planets[planetId].Aliens or {}
end
function Aliens.RecordOf(model) return byModel[model] end

local function step()
	local t = now()
	-- planets with explorers get aliens; empty ones lose them after a while
	local active = {}
	for _, p in pairs(ctx.profiles) do
		if p.Expedition and p.Planet == p.Expedition.Planet and not p.InDungeon then active[p.Planet] = true end
	end
	for planetId in pairs(active) do
		if not planets[planetId] then planets[planetId] = {Aliens = {}, Pending = 0} end
	end
	for planetId, state in pairs(planets) do
		local explorers = explorersOn(planetId)
		if #explorers == 0 and not active[planetId] then
			state.EmptySince = state.EmptySince or t
			if t - state.EmptySince > A.DespawnAfter then
				for i = #state.Aliens, 1, -1 do removeAlien(state.Aliens[i]) end
				planets[planetId] = nil
			end
		else
			state.EmptySince = nil
			local alive = 0
			for _, r in ipairs(state.Aliens) do if not r.Dead then alive += 1 end end
			if alive + (state.Pending or 0) < targetCount(planetId, #explorers) then spawnAlien(planetId) end
			for _, record in ipairs(state.Aliens) do
				local ok, err = pcall(think, record, explorers)
				if not ok then warn("[PFE] alien AI failed", err) end
			end
		end
	end
	for _, group in pairs(groups) do
		local crew = group.Members()
		for _, record in ipairs(group.Aliens) do
			local ok, err = pcall(think, record, crew)
			if not ok then warn("[PFE] alien AI failed", err) end
		end
	end
end

function Aliens.Init(context)
	ctx = context
	Config = ctx.Config
	A, R = Config.Aliens, Config.Raygun
	ctx.Aliens = Aliens
	folder = workspace:FindFirstChild("PFE_Aliens") or Instance.new("Folder")
	folder.Name = "PFE_Aliens"; folder.Parent = workspace
	ctx.remotes.Raygun.OnServerEvent:Connect(function(player, aim)
		local ok, err = pcall(fire, player, aim)
		if not ok then warn("[PFE] raygun failed", err) end
	end)
	Players.PlayerRemoving:Connect(function(player) lastShot[player] = nil; energy[player] = nil end)
	-- energy comes back by itself; an overheated gun refills completely when it cools down
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local t = os.clock()
			local dt = t - last
			last = t
			for _, player in ipairs(Players:GetPlayers()) do
				local e = energyOf(player)
				local overheated = e.OverheatUntil > 0
				if overheated and t >= e.OverheatUntil then
					e.OverheatUntil = 0; e.Value = R.EnergyMax; publishEnergy(player, e)
				elseif not overheated and e.Value < R.EnergyMax then
					e.Value = math.min(R.EnergyMax, e.Value + R.EnergyReturnPerSecond * dt)
					publishEnergy(player, e)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(A.Tick)
			local ok, err = pcall(step)
			if not ok then warn("[PFE] aliens step failed", err) end
		end
	end)
end

return Aliens
