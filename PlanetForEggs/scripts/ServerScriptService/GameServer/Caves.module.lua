--!nocheck
-- (v41) Caves. Every planet has two cave mouths (LifeConfig.CaveSites): the Shallow Cave leads into the top of the planet's
-- cave system, the Deep Cavern drops you halfway down it. A cave system is a long winding chain of chambers going down and
-- down (Life.Caves.MainLength), with side passages; some side passages are sealed by a cracked wall (smash it: a secret room
-- with a treasure chest), and at the very bottom waits the Deep Vault. It is pitch dark down there: everybody carries a
-- flashlight (Gear). The deeper the chamber, the better what is in it:
--  * crystals and ore rocks to smash (coins, and the deeper the likelier an egg inside), eggs lying about (rarer and rarer),
--  * air vents every few chambers (a breath of air: +Life.Caves.VentAir), the air goes slower down there anyway,
--  * cave aliens from Life.Caves.AliensFrom down, falling stalactites from Stalactites.From down.
-- Eggs found down there are planet eggs like any other: carry them out (Climb out) and to your rocket.
-- The systems are built (from a seed per planet, always the same) the first time somebody goes in, far from everything
-- (Life.Caves.Space); a chamber's crystals, rocks and eggs come back a while after it was cleared.
local Players = game:GetService("Players")
local Caves = {}
local ctx, Config, Life, L
local rng = Random.new()
local folder
local systems = {}   -- planetId -> system
local sites = {}     -- key -> site
local inside = {}    -- profile -> {Planet, Site, Room}

local function now() return workspace:GetServerTimeNow() end
local function flat(a, b) return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude end
local function angleDiff(a, b) return math.abs((a - b + math.pi) % (math.pi * 2) - math.pi) end

-- ---------------------------------------------------------------- looks per planet
local THEMES = {
	Moon = {Wall = Enum.Material.Slate, Floor = Enum.Material.Slate, Decor = "Crystal"},
	Mars = {Wall = Enum.Material.Sandstone, Floor = Enum.Material.Sand, Decor = "Crystal"},
	Frostia = {Wall = Enum.Material.Glacier, Floor = Enum.Material.Ice, Decor = "Ice"},
	Verdantis = {Wall = Enum.Material.Rock, Floor = Enum.Material.Ground, Decor = "Mushroom"},
	Magmara = {Wall = Enum.Material.Basalt, Floor = Enum.Material.Basalt, Decor = "Lava"},
	Crystalis = {Wall = Enum.Material.Slate, Floor = Enum.Material.Pavement, Decor = "Crystal"},
	Mycelia = {Wall = Enum.Material.Mud, Floor = Enum.Material.Mud, Decor = "Mushroom"},
	Neonix = {Wall = Enum.Material.DiamondPlate, Floor = Enum.Material.DiamondPlate, Decor = "Circuit"},
	Nebulon = {Wall = Enum.Material.Slate, Floor = Enum.Material.Slate, Decor = "Crystal"},
}

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanTouch = false; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end
local function wedge(parent, props)
	local p = Instance.new("WedgePart")
	p.Anchored = true; p.CanTouch = false; p.CanCollide = false; p.CanQuery = false; p.CastShadow = false
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end
local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color; l.Range = range; l.Brightness = brightness; l.Shadows = false; l.Parent = parent
	return l
end

-- ---------------------------------------------------------------- the layout (the same for a planet every time)
local function layoutFor(planetId)
	local C = Life.Caves
	local planet = Config.Planets[planetId]
	local r = Random.new(7000 + (planet.Order or 1) * 131)
	local origin = Life.CaveOrigin(planetId)
	local rooms, tunnels = {}, {}
	local function fits(center, radius, except)
		for _, other in ipairs(rooms) do
			if other ~= except and flat(other.Center, center) < other.Radius + radius + 18 then return false end
		end
		return true
	end
	local function openAt(room, angle)
		for _, a in ipairs(room.Openings) do if angleDiff(a, angle) < 0.85 then return false end end
		return true
	end
	local function newRoom(center, radius, height, depth, kind)
		local room = {Index = #rooms + 1, Center = center, Radius = radius, Height = height, Depth = depth, Kind = kind, Openings = {}, Links = {}}
		table.insert(rooms, room)
		return room
	end
	local function link(a, b, sealed)
		local d = (b.Center - a.Center) * Vector3.new(1, 0, 1)
		local angle = math.atan2(d.Z, d.X)
		table.insert(a.Openings, angle)
		table.insert(b.Openings, angle + math.pi)
		local tunnel = {A = a, B = b, Sealed = sealed, Dir = d.Unit}
		table.insert(tunnels, tunnel)
		table.insert(a.Links, tunnel); table.insert(b.Links, tunnel)
		return tunnel
	end
	-- a chamber `from` leads on to, heading roughly `heading`
	local function grow(from, heading, depth, kind, spread)
		for try = 1, 40 do
			local turn = heading + r:NextNumber(-spread, spread) * (1 + try / 20)
			local radius = kind == "Vault" and 32 or r:NextNumber(C.Room.Radius[1], C.Room.Radius[2])
			local height = kind == "Vault" and 32 or r:NextNumber(C.Room.Height[1], C.Room.Height[2])
			local dist = from.Radius + radius + r:NextNumber(C.Tunnel.Length[1], C.Tunnel.Length[2])
			local drop = r:NextNumber(3, 8)
			local center = from.Center + Vector3.new(math.cos(turn) * dist, -drop, math.sin(turn) * dist)
			if fits(center, radius, from) and openAt(from, turn) then
				return newRoom(center, radius, height, depth, kind), turn
			end
		end
		return nil
	end
	local entry = newRoom(origin, 24, 24, 0, "Entry")
	local heading = r:NextNumber(0, math.pi * 2)
	local previous = entry
	local main = {entry}
	for depth = 1, C.MainLength do
		local room, turn = grow(previous, heading, depth, depth == C.MainLength and "Vault" or "Room", 0.8)
		if not room then
			-- boxed in: the chain ends here (this one becomes the vault)
			previous.Kind = previous ~= entry and "Vault" or previous.Kind
			break
		end
		link(previous, room)
		heading = turn
		previous = room
		table.insert(main, room)
	end
	-- the Deep Cavern's mouth comes out halfway down
	local shortcut = main[math.max(2, math.floor(#main / 2))]
	shortcut.Shortcut = true
	-- side passages: a few chambers off the main way, ending in a treasure room (sometimes behind a cracked wall)
	for i = 3, #main - 1 do
		local room = main[i]
		if r:NextNumber() < C.Branches then
			local sealed = r:NextNumber() < C.Secret
			local length = r:NextInteger(C.BranchLength[1], C.BranchLength[2])
			local side = (r:NextNumber() < 0.5 and 1 or -1) * math.pi / 2
			local from = room
			local base = math.atan2(room.Links[1].Dir.Z, room.Links[1].Dir.X)
			for k = 1, length do
				local kind = k == length and (sealed and "Secret" or "Treasure") or "Branch"
				local nextRoom = grow(from, base + side, room.Depth + k * 0.5, kind, 0.6)
				if not nextRoom then
					if from ~= room then from.Kind = sealed and "Secret" or "Treasure" end
					break
				end
				link(from, nextRoom, k == 1 and sealed)
				from = nextRoom
			end
		end
	end
	return rooms, tunnels, main
end

-- ---------------------------------------------------------------- building it
local function buildRoom(system, room, model, theme, colors, budget)
	local C, H, R = room.Center, room.Height, room.Radius
	local W = Life.Caves.Tunnel.Width
	part(model, {Name = "Floor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, R * 2 + 6, R * 2 + 6), CFrame = CFrame.new(C - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = colors.Floor, Material = theme.Floor})
	part(model, {Name = "Ceiling", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, R * 2 + 6, R * 2 + 6), CFrame = CFrame.new(C + Vector3.new(0, H + 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = colors.Wall, Material = theme.Wall})
	-- the round wall, open where the tunnels come in (and pillars on both sides of every opening)
	local segments = 28
	local half = (W / 2 + 1) / R
	for i = 1, segments do
		local a = (i - 0.5) / segments * math.pi * 2
		local open = false
		for _, o in ipairs(room.Openings) do if angleDiff(a, o) < half then open = true end end
		if not open then
			local at = C + Vector3.new(math.cos(a) * (R + 1), H / 2, math.sin(a) * (R + 1))
			local length = 2 * (R + 1) * math.tan(math.pi / segments) + 1.2
			part(model, {Name = "Wall", Size = Vector3.new(length, H + 3, 2.5), CFrame = CFrame.lookAt(at, Vector3.new(C.X, at.Y, C.Z)),
				Color = colors.Wall, Material = theme.Wall})
		end
		budget()
	end
	for _, o in ipairs(room.Openings) do
		for _, side in ipairs({-1, 1}) do
			local a = o + side * (W / 2 + 3.2) / R
			local at = C + Vector3.new(math.cos(a) * (R + 0.5), H / 2, math.sin(a) * (R + 0.5))
			part(model, {Name = "Jamb", Size = Vector3.new(6.5, H + 3, 6.5), CFrame = CFrame.lookAt(at, Vector3.new(C.X, at.Y, C.Z)),
				Color = colors.Wall:Lerp(Color3.new(0, 0, 0), 0.1), Material = theme.Wall})
		end
	end
	-- boulders along the walls, stalactites and stalagmites
	local rr = Random.new(room.Index * 977 + system.Seed)
	local function clearOfOpenings(a, pad)
		for _, o in ipairs(room.Openings) do if angleDiff(a, o) < half + (pad or 0.25) then return false end end
		return true
	end
	for _ = 1, 9 do
		local a = rr:NextNumber(0, math.pi * 2)
		if clearOfOpenings(a, 0.3) then
			local s = rr:NextNumber(4, 9)
			local at = C + Vector3.new(math.cos(a) * (R - s * 0.25), s * 0.3, math.sin(a) * (R - s * 0.25))
			part(model, {Name = "Boulder", Size = Vector3.new(s, s * rr:NextNumber(0.6, 1.2), s * rr:NextNumber(0.7, 1.1)),
				CFrame = CFrame.new(at) * CFrame.Angles(rr:NextNumber(-0.5, 0.5), rr:NextNumber(0, 6), rr:NextNumber(-0.5, 0.5)),
				Color = colors.Wall:Lerp(colors.Floor, 0.4), Material = theme.Wall, CanCollide = true})
		end
		budget()
	end
	for _ = 1, 7 do
		local a, d = rr:NextNumber(0, math.pi * 2), rr:NextNumber(0, R - 4)
		local len = rr:NextNumber(3, math.min(9, H * 0.35))
		local at = C + Vector3.new(math.cos(a) * d, H - len / 2, math.sin(a) * d)
		local yaw = CFrame.Angles(0, rr:NextNumber(0, 6), 0)
		local w = rr:NextNumber(1.6, 3)
		wedge(model, {Name = "Stalactite", Size = Vector3.new(w, len, w), CFrame = CFrame.new(at) * yaw * CFrame.Angles(math.pi, 0, 0), Color = colors.Wall, Material = theme.Wall})
		wedge(model, {Name = "Stalactite", Size = Vector3.new(w, len, w), CFrame = CFrame.new(at) * yaw * CFrame.Angles(math.pi, math.pi, 0), Color = colors.Wall, Material = theme.Wall})
		budget()
	end
	for _ = 1, 4 do
		local a, d = rr:NextNumber(0, math.pi * 2), rr:NextNumber(R * 0.45, R - 5)
		if clearOfOpenings(a, 0.35) then
			local len = rr:NextNumber(3, 7)
			local at = C + Vector3.new(math.cos(a) * d, len / 2, math.sin(a) * d)
			local yaw = CFrame.Angles(0, rr:NextNumber(0, 6), 0)
			wedge(model, {Name = "Stalagmite", Size = Vector3.new(2.4, len, 2.4), CFrame = CFrame.new(at) * yaw, Color = colors.Wall:Lerp(colors.Floor, 0.5), Material = theme.Wall})
			wedge(model, {Name = "Stalagmite", Size = Vector3.new(2.4, len, 2.4), CFrame = CFrame.new(at) * yaw * CFrame.Angles(0, math.pi, 0), Color = colors.Wall:Lerp(colors.Floor, 0.5), Material = theme.Wall})
		end
	end
	-- a little light of their own: glowing crystals / ice / mushrooms / lava / circuits (never enough to see far)
	for k = 1, (room.Kind == "Vault" and 5 or 2) do
		local a = rr:NextNumber(0, math.pi * 2)
		if clearOfOpenings(a, 0.2) then
			local at = C + Vector3.new(math.cos(a) * (R - 2.5), 0, math.sin(a) * (R - 2.5))
			if theme.Decor == "Mushroom" then
				part(model, {Name = "GlowStem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 0.8, 0.8), CFrame = CFrame.new(at + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
					Color = Color3.fromRGB(230, 220, 210), Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false})
				local cap = part(model, {Name = "GlowCap", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.6, CFrame = CFrame.new(at + Vector3.new(0, 3.2, 0)),
					Color = colors.Accent, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false})
				light(cap, colors.Accent, 14, 0.7)
			elseif theme.Decor == "Lava" then
				local pool = part(model, {Name = "LavaPool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 7, 7), CFrame = CFrame.new(at + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
					Color = Color3.fromRGB(255, 100, 20), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false})
				light(pool, Color3.fromRGB(255, 110, 30), 18, 1)
			elseif theme.Decor == "Circuit" then
				local strip = part(model, {Name = "Circuit", Size = Vector3.new(0.4, H * 0.7, 1), CFrame = CFrame.new(at + Vector3.new(0, H * 0.35, 0)),
					Color = colors.Accent, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false})
				light(strip, colors.Accent, 14, 0.8)
			else
				local tint = theme.Decor == "Ice" and Color3.fromRGB(150, 220, 255) or colors.Accent
				local first
				for j = 1, 3 do
					local shard = part(model, {Name = "GlowCrystal", Size = Vector3.new(0.9, 2 + j, 0.9), CFrame = CFrame.new(at + Vector3.new(j * 0.6 - 1.2, 1 + j * 0.5, 0)) * CFrame.Angles(0.3 * (j - 2), j, 0.2),
						Color = tint, Material = Enum.Material.Neon, Transparency = 0.15, CanCollide = false, CanQuery = false})
					first = first or shard
				end
				light(first, tint, 14, 0.7)
			end
		end
		budget(k)
	end
end

local function buildTunnel(model, tunnel, theme, colors)
	local W, H = Life.Caves.Tunnel.Width, Life.Caves.Tunnel.Height
	local a, b = tunnel.A, tunnel.B
	local dir = tunnel.Dir
	local from = a.Center + dir * (a.Radius - 2)
	local to = b.Center - dir * (b.Radius - 2)
	local length = (to - from).Magnitude
	local cf = CFrame.lookAt((from + to) / 2, to)
	part(model, {Name = "TunnelFloor", Size = Vector3.new(W + 3, 2, length + 6), CFrame = cf * CFrame.new(0, -1, 0), Color = colors.Floor, Material = theme.Floor})
	part(model, {Name = "TunnelRoof", Size = Vector3.new(W + 7, 3, length + 6), CFrame = cf * CFrame.new(0, H + 1.5, 0), Color = colors.Wall, Material = theme.Wall})
	for _, side in ipairs({-1, 1}) do
		part(model, {Name = "TunnelWall", Size = Vector3.new(2.5, H + 4, length + 6), CFrame = cf * CFrame.new(side * (W / 2 + 1.25), H / 2, 0),
			Color = colors.Wall, Material = theme.Wall})
		-- a rib of rock now and then (it looks dug, not built)
		for k = 1, math.floor(length / 14) do
			local z = -length / 2 + k * 14
			part(model, {Name = "Rib", Size = Vector3.new(3, H * 0.6, 3), CFrame = cf * CFrame.new(side * (W / 2 - 0.2), H * 0.3, z) * CFrame.Angles(0, 0.4 * side, 0.2 * side),
				Color = colors.Wall:Lerp(Color3.new(0, 0, 0), 0.15), Material = theme.Wall})
		end
	end
	tunnel.From, tunnel.To, tunnel.CF, tunnel.Length = from, to, cf, length
end

-- the planet's cave system: built the first time somebody goes in (a few hundred parts a frame)
local function build(planetId)
	local system = systems[planetId]
	if system then
		while system.Building do task.wait(0.1) end
		return system
	end
	local planet = Config.Planets[planetId]
	system = {Planet = planetId, Building = true, Seed = (planet.Order or 1) * 31}
	systems[planetId] = system
	local rooms, tunnels, main = layoutFor(planetId)
	system.Rooms, system.Tunnels, system.Main = rooms, tunnels, main
	local theme = THEMES[planetId] or THEMES.Moon
	local rock = planet.RockColor or Color3.fromRGB(110, 110, 120)
	local colors = {Wall = rock:Lerp(Color3.new(0, 0, 0), 0.25), Floor = (planet.GroundColor or rock):Lerp(Color3.new(0, 0, 0), 0.35), Accent = planet.Accent}
	local model = Instance.new("Model")
	model.Name = planetId .. "_Caves"
	model:SetAttribute("Planet", planetId)
	model.Parent = folder
	system.Model = model
	local count, started = 0, os.clock()
	local function budget()
		count += 1
		if count % 40 == 0 and os.clock() - started > 0.008 then task.wait(); started = os.clock() end
	end
	for _, room in ipairs(rooms) do
		local roomModel = Instance.new("Model")
		roomModel.Name = "Chamber" .. room.Index
		buildRoom(system, room, roomModel, theme, colors, budget)
		roomModel.Parent = model
		room.Model = roomModel
	end
	for _, tunnel in ipairs(tunnels) do
		buildTunnel(model, tunnel, theme, colors)
		budget()
	end
	system.Building = false
	return system
end

-- ---------------------------------------------------------------- what is down there
local function roomPoint(room, minR, maxR)
	for _ = 1, 20 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(minR, maxR)
		local ok = true
		for _, o in ipairs(room.Openings) do if angleDiff(a, o) < 0.45 and d > room.Radius * 0.5 then ok = false end end
		if ok then return room.Center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d) end
	end
	return room.Center
end

local function zoneFor(depth) return math.clamp(2 + math.floor(depth / 4), 2, 5) end

-- eggs lying about (rarer the deeper); a map reset takes them away with the planet's others, then they come again
local function stockEggs(system, room)
	local planetId, depth = system.Planet, room.Depth
	if room.Kind == "Entry" or not ctx.Expeditions.HasPool(planetId) or not (depth >= 2 or rng:NextNumber() < 0.4) then return end
	room.Loot = room.Loot or {}
	local eggs = depth >= 8 and 2 or 1
	for _ = 1, eggs do
		local at = roomPoint(room, 4, room.Radius * 0.6)
		local item = ctx.Expeditions.SpawnEventEgg(planetId, at, {Zone = zoneFor(depth), Boost = 1 + depth * 0.35,
			Super = depth >= Life.Caves.MainLength - 2 and 0.03 or nil, Tag = "Cave"})
		if item then table.insert(room.Loot, item) end
	end
end

local function stock(system, room)
	room.Loot = room.Loot or {}
	room.StockedAt = now()
	local planetId = system.Planet
	local depth = room.Depth
	local function keep(record) if record then table.insert(room.Loot, record.Model) end end
	if room.Kind == "Entry" then return end
	-- crystals and ore
	local crystals = math.min(4, 1 + math.floor(depth / 4) + rng:NextInteger(0, 1))
	for _ = 1, crystals do
		local at = roomPoint(room, room.Radius * 0.55, room.Radius - 5)
		keep(L.Breakable(planetId, "Crystal", CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), {Cave = true, Zone = zoneFor(depth),
			EggMult = math.min(2, (0.35 + depth * 0.06) / 0.4), BoostMult = 1 + depth * 0.12, CoinMult = 1 + depth * 0.25, HPMult = 1 + depth * 0.06}))
	end
	if rng:NextNumber() < 0.7 then
		local at = roomPoint(room, room.Radius * 0.4, room.Radius - 6)
		keep(L.Breakable(planetId, "Ore", CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), {Cave = true, Zone = zoneFor(depth),
			CoinMult = 1 + depth * 0.3, HPMult = 1 + depth * 0.05}))
	end
	stockEggs(system, room)
	-- treasure: the chests of the side passages, the vault at the bottom
	if room.Kind == "Secret" or room.Kind == "Treasure" then
		keep(L.Breakable(planetId, "Chest", CFrame.lookAt(room.Center, room.Center + Vector3.new(0, 0, -1)), {Cave = true, Zone = zoneFor(depth + 2),
			BoostMult = (room.Kind == "Secret" and 1.4 or 1) * (1 + depth * 0.08), CoinMult = 1 + depth * 0.3, Name = room.Kind == "Secret" and "Secret Chest" or "Treasure Chest"}))
	elseif room.Kind == "Vault" then
		keep(L.Breakable(planetId, "Vault", CFrame.lookAt(room.Center, room.Center + Vector3.new(0, 0, -1)), {Cave = true, Zone = 5, CoinMult = 1 + depth * 0.2,
			Eggs = 2, MinMutation = rng:NextNumber() < 0.3 and "Golden" or nil,
			OnBreak = function(profile)
				if profile and ctx.profiles[profile.Player] == profile then
					profile.Data.Stats.CavesExplored = (profile.Data.Stats.CavesExplored or 0) + 1
					for _, player in ipairs(Players:GetPlayers()) do
						ctx.remotes.Notice:FireClient(player, profile.Player.DisplayName .. " opened the Deep Vault of " .. Config.Planets[planetId].Name .. "!", "Gold")
					end
				end
			end}))
	end
end

-- the cracked walls sealing the secret passages (they come back with the loot)
local function seal(system, tunnel)
	if tunnel.Wall and tunnel.Wall.Parent then return end
	local W, H = Life.Caves.Tunnel.Width, Life.Caves.Tunnel.Height
	local at = tunnel.From + tunnel.Dir * 7
	local floorY = tunnel.From.Y + (tunnel.To.Y - tunnel.From.Y) * (7 / math.max(1, tunnel.Length))
	local base = Vector3.new(at.X, floorY, at.Z)
	local record = L.Breakable(system.Planet, "Wall", CFrame.lookAt(base, base + tunnel.Dir), {Cave = true, Width = W + 2, Height = H + 1,
		OnBreak = function(profile)
			tunnel.OpenedAt = now()
			if profile and profile.Player.Parent then ctx.notice(profile, "You broke through - a SECRET PASSAGE!", "Gold") end
		end})
	tunnel.Wall = record and record.Model
	tunnel.OpenedAt = nil
end

-- air vents: every few chambers a vent of fresh air
local function addVent(system, room)
	if room.Vent then return end
	local at = roomPoint(room, 3, room.Radius * 0.35)
	local vent = part(system.Model, {Name = "AirVent", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 6, 6), CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(90, 220, 255), Material = Enum.Material.Neon, Transparency = 0.2, CanCollide = false, CanQuery = false})
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"; e.Rate = 18; e.Lifetime = NumberRange.new(1.2, 2)
	e.Speed = NumberRange.new(6, 10); e.EmissionDirection = Enum.NormalId.Right; e.SpreadAngle = Vector2.new(12, 12)
	e.Size = NumberSequence.new(0.9, 0.2); e.Color = ColorSequence.new(Color3.fromRGB(170, 240, 255)); e.LightEmission = 1; e.LightInfluence = 0
	e.Parent = vent
	light(vent, Color3.fromRGB(110, 220, 255), 16, 1)
	vent:SetAttribute("AirVent", true)
	room.Vent = {Part = vent, Position = at, Used = {}}
end

local function prepare(system)
	if system.Prepared then return end
	system.Prepared = true
	for _, room in ipairs(system.Rooms) do
		if room.Depth > 0 and math.floor(room.Depth) % Life.Caves.VentEvery == 0 and room.Kind ~= "Branch" then addVent(system, room) end
		if room.Kind == "Entry" or room.Shortcut or room.Kind == "Vault" then
			-- the way out: a rope of light up to the surface
			local at = room.Kind == "Entry" and room.Center or roomPoint(room, 4, room.Radius * 0.4)
			local rope = part(system.Model, {Name = "WayOut", Size = Vector3.new(1, room.Height, 1), CFrame = CFrame.new(at + Vector3.new(0, room.Height / 2, 0)),
				Color = Color3.fromRGB(255, 230, 150), Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false, CanQuery = false})
			light(rope, Color3.fromRGB(255, 230, 160), 22, 1.4)
			local siteIndex = room.Kind == "Entry" and 1 or 2
			ctx.makePrompt(rope, "ClimbOut", "Climb out", function(player)
				local profile = ctx.profiles[player]
				if profile and inside[profile] and inside[profile].Planet == system.Planet then Caves.Leave(profile, siteIndex) end
			end, {Hold = 0.5, Distance = 12, ObjectText = "Way up"})
			local label = ctx.label(rope, "WAY OUT", "Climb back up to the surface", Color3.fromRGB(255, 230, 150), 3)
			if label then label.MaxDistance = 60 end
			room.Exit = rope
		end
	end
	for _, tunnel in ipairs(system.Tunnels) do if tunnel.Sealed then seal(system, tunnel) end end
end

-- ---------------------------------------------------------------- going in and out
local function members(planetId)
	return function()
		local list = {}
		for profile, at in pairs(inside) do
			if at.Planet == planetId and ctx.profiles[profile.Player] == profile then table.insert(list, profile) end
		end
		return list
	end
end

local function publish(profile)
	local at = inside[profile]
	local player = profile.Player
	if not player.Parent then return end
	if not at then
		for _, key in ipairs({"PFECave", "PFECaveDepth", "PFECaveMax", "PFECaveRoom"}) do player:SetAttribute(key, nil) end
		return
	end
	local system = systems[at.Planet]
	local room = at.Room
	player:SetAttribute("PFECave", sites[at.Planet .. ":Cave" .. at.Site] and sites[at.Planet .. ":Cave" .. at.Site].Name or "Cave")
	player:SetAttribute("PFECaveDepth", room and math.floor(room.Depth) or 0)
	player:SetAttribute("PFECaveMax", system and #system.Main - 1 or Life.Caves.MainLength)
	player:SetAttribute("PFECaveRoom", room and room.Kind or "Entry")
end

function Caves.Enter(profile, site)
	if inside[profile] or profile.Busy or profile.InDungeon then return end
	local expedition = profile.Expedition
	if not expedition or expedition.Planet ~= site.Planet or profile.Planet ~= site.Planet then
		ctx.notice(profile, "Land on this planet to go into its caves.", "Red"); return
	end
	if not ctx.near(profile, site.Pad, 22) then return end
	if not systems[site.Planet] then ctx.notice(profile, "Lighting the way into the cave...", "Purple") end
	local system = build(site.Planet)
	if ctx.profiles[profile.Player] ~= profile or profile.Busy or not profile.Expedition then return end
	prepare(system)
	local room = site.Index == 1 and system.Rooms[1] or system.Main[math.max(2, math.floor(#system.Main / 2))]
	local link = room.Links[1]
	local look = link and (room.Center + (link.A == room and link.Dir or -link.Dir) * 10) or (room.Center + Vector3.new(0, 0, -10))
	local at = room.Center + Vector3.new(0, 4, 0) + (room.Kind == "Entry" and Vector3.zero or Vector3.new(3, 0, 3))
	inside[profile] = {Planet = site.Planet, Site = site.Index, Room = room, Visited = {}}
	profile.InCave = site.Planet
	local character = profile.Player.Character
	if character then character:PivotTo(CFrame.lookAt(at, Vector3.new(look.X, at.Y, look.Z))) end
	publish(profile)
	ctx.effect(profile.Player, "CaveEnter", {Name = site.Name, Planet = site.Planet})
	ctx.markDirty(profile)
	-- the chambers are stocked the first time anybody comes down (and again after a while, see step)
	for _, r in ipairs(system.Rooms) do if not r.StockedAt then stock(system, r) end end
end

function Caves.Leave(profile, siteIndex)
	local at = inside[profile]
	if not at then return end
	inside[profile] = nil
	profile.InCave = nil
	local site = sites[at.Planet .. ":Cave" .. (siteIndex or at.Site)]
	if siteIndex ~= false and site and profile.Player.Character then
		profile.Player.Character:PivotTo(site.Exit)
		ctx.effect(profile.Player, "CaveExit", {Name = site.Name})
	end
	publish(profile)
	ctx.markDirty(profile)
end
-- died, respawned, left the game: out of the cave (no teleport)
function Caves.OnLeft(profile)
	if inside[profile] then Caves.Leave(profile, false) end
	profile.InCave = nil
end

-- ---------------------------------------------------------------- the cave mouths on the planets
local function buildSite(planet, entry)
	local ground = Vector3.new(planet.Origin.X + entry.X, planet.Origin.Y, planet.Origin.Z + entry.Z)
	local toCentre = Vector3.new(planet.Origin.X - ground.X, 0, planet.Origin.Z - ground.Z)
	toCentre = toCentre.Magnitude > 1 and toCentre.Unit or Vector3.new(1, 0, 0)
	local model = Instance.new("Model")
	model.Name = planet.Id .. "_CaveMouth" .. entry.Index
	local rock = (planet.RockColor or Color3.fromRGB(110, 110, 120))
	local back = ground - toCentre * 10
	-- the hill: a few big boulders melted together
	for i, spec in ipairs({{0, 30, 0}, {-11, 22, 5}, {12, 20, 4}, {2, 18, -9}}) do
		local side = Vector3.new(toCentre.Z, 0, -toCentre.X)
		local at = back + side * spec[1] - toCentre * spec[3] + Vector3.new(0, spec[2] * 0.12, 0)
		part(model, {Name = "Hill", Shape = Enum.PartType.Ball, Size = Vector3.one * spec[2], CFrame = CFrame.new(at), Color = rock:Lerp(Color3.new(0, 0, 0), 0.08 * i),
			Material = Enum.Material.Slate, CanCollide = true, CastShadow = true})
	end
	-- the dark mouth facing the rocket
	local mouthAt = ground - toCentre * 0.5 + Vector3.new(0, 4.5, 0)
	part(model, {Name = "Mouth", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 11, 13), CFrame = CFrame.lookAt(mouthAt, mouthAt + toCentre) * CFrame.Angles(0, math.pi / 2, 0),
		Color = Color3.fromRGB(6, 6, 10), Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false})
	-- torches on both sides
	for _, s in ipairs({-1, 1}) do
		local side = Vector3.new(toCentre.Z, 0, -toCentre.X)
		local at = ground + toCentre * 2 + side * s * 8
		part(model, {Name = "TorchPole", Size = Vector3.new(0.6, 6, 0.6), CFrame = CFrame.new(at + Vector3.new(0, 3, 0)), Color = Color3.fromRGB(90, 60, 30),
			Material = Enum.Material.Wood, CanCollide = false, CanQuery = false})
		local head = part(model, {Name = "TorchHead", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(at + Vector3.new(0, 6.3, 0)), Transparency = 1,
			CanCollide = false, CanQuery = false})
		local fire = Instance.new("Fire"); fire.Size = 3; fire.Heat = 6; fire.Parent = head
		light(head, Color3.fromRGB(255, 160, 70), 22, 2)
	end
	local pad = part(model, {Name = "CavePad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 10, 10),
		CFrame = CFrame.new(ground + toCentre * 3 + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 190, 90), Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, CanQuery = false})
	model:SetAttribute("Planet", planet.Id)
	model:SetAttribute("CaveMouth", entry.Name)
	model.Parent = L.Folder(planet.Id)
	local site = {Key = entry.Key, Planet = planet.Id, Index = entry.Index, Name = entry.Name, Model = model, Pad = pad,
		Exit = CFrame.lookAt(ground + toCentre * 12 + Vector3.new(0, 4, 0), ground + toCentre * 30 + Vector3.new(0, 4, 0))}
	sites[entry.Key] = site
	ctx.makePrompt(pad, "EnterCave", "Enter cave", function(player)
		local profile = ctx.profiles[player]
		if profile then task.spawn(Caves.Enter, profile, site) end
	end, {Hold = 0.6, Distance = 14, ObjectText = entry.Name})
	local label = ctx.label(pad, string.upper(entry.Name), entry.Index == 1 and "Dark caves - the deeper, the better the loot. Bring your flashlight!"
		or "Drops you deep down - rare eggs, aliens, the Deep Vault", Color3.fromRGB(255, 200, 110), 9)
	if label then label.MaxDistance = 220; label.Size = UDim2.fromOffset(300, 64) end
	return site
end

-- ---------------------------------------------------------------- the loop (twice a second)
local function nearestRoom(system, position)
	local best, bestD
	for _, room in ipairs(system.Rooms) do
		local d = flat(room.Center, position)
		if math.abs(position.Y - room.Center.Y) < room.Height + 8 and d < room.Radius + 4 and (not bestD or d < bestD) then best, bestD = room, d end
	end
	return best
end

local stalactiteAt = {}
local function step()
	local t = now()
	local occupied = {}
	for profile, at in pairs(inside) do
		if ctx.profiles[profile.Player] ~= profile or not profile.Expedition or profile.Planet ~= at.Planet or profile.InDungeon then
			Caves.Leave(profile, false)
		else
			local system = systems[at.Planet]
			local r = ctx.root(profile.Player)
			if system and r then
				-- fell out somehow (a gap, a glitch): back to the chamber they were last in
				if r.Position.Y < Life.Caves.Space.Y - 400 then
					local room = at.Room or system.Rooms[1]
					profile.Player.Character:PivotTo(CFrame.new(room.Center + Vector3.new(0, 4, 0)))
				end
				local room = nearestRoom(system, r.Position)
				if room and room ~= at.Room then
					at.Room = room
					publish(profile)
					if not at.Visited[room] then
						at.Visited[room] = true
						if room.Kind == "Vault" then ctx.notice(profile, "THE DEEP VAULT! Smash the chest!", "Gold")
						elseif room.Kind == "Secret" then ctx.notice(profile, "A secret room!", "Gold") end
					end
				end
				if room then occupied[room] = occupied[room] or {}; table.insert(occupied[room], profile) end
				-- air vents
				for _, rm in ipairs(system.Rooms) do
					local vent = rm.Vent
					if vent and (r.Position - vent.Position).Magnitude < 8 and t >= (vent.Used[profile] or 0) then
						vent.Used[profile] = t + Life.Caves.VentCooldown
						local max = ctx.maxOxygen(profile)
						profile.Oxygen = math.min(max, profile.Oxygen + Life.Caves.VentAir)
						profile.WarnLow, profile.WarnCritical = false, false
						ctx.effect(profile.Player, "AirVent", {Amount = Life.Caves.VentAir})
						ctx.notice(profile, "+" .. Life.Caves.VentAir .. " air!", "Blue")
						ctx.markDirty(profile)
					end
				end
			end
		end
	end
	-- the occupied chambers: aliens, falling stalactites
	for room, list in pairs(occupied) do
		local planetId = list[1].InCave
		local depth = room.Depth
		if depth >= Life.Caves.AliensFrom and ctx.Aliens and ctx.Aliens.SpawnGroup then
			local tag = "Cave_" .. planetId .. "_" .. room.Index
			if (not room.AliensAt or t - room.AliensAt > Life.Caves.AlienRespawn) and ctx.Aliens.GroupAlive(tag) == 0 then
				room.AliensAt = t
				local points = {}
				for _ = 1, 4 do table.insert(points, roomPoint(room, room.Radius * 0.4, room.Radius - 6)) end
				ctx.Aliens.ClearGroup(tag)
				ctx.Aliens.SpawnGroup(tag, planetId, points, 1 + math.floor(depth / 5), members(planetId), 1 + math.floor(depth / 6))
			end
		end
		local S = Life.Caves.Stalactites
		if depth >= S.From and t >= (stalactiteAt[room] or 0) then
			stalactiteAt[room] = t + rng:NextNumber(S.Every[1], S.Every[2])
			local victim = list[rng:NextInteger(1, #list)]
			local r = ctx.root(victim.Player)
			if r then
				local at = Vector3.new(r.Position.X + rng:NextNumber(-3, 3), room.Center.Y, r.Position.Z + rng:NextNumber(-3, 3))
				L.Strike(planetId, "Stalactite", at, {Delay = 1.3, Radius = 5, Damage = S.Damage, Knock = 20}, {Cave = true, Reason = "A falling stalactite got you!", Range = 300})
			end
		end
	end
	-- loot comes back in cleared chambers nobody is in; empty caves lose their aliens
	for planetId, system in pairs(systems) do
		if system.Prepared then
			local anyone = false
			for _, at in pairs(inside) do if at.Planet == planetId then anyone = true end end
			for _, room in ipairs(system.Rooms) do
				if room.StockedAt and not occupied[room] and t - room.StockedAt > Life.Caves.LootRespawn then
					local alive = 0
					for i = #(room.Loot or {}), 1, -1 do
						if room.Loot[i].Parent then alive += 1 else table.remove(room.Loot, i) end
					end
					if alive == 0 and anyone then stock(system, room) end
				end
				if not anyone and ctx.Aliens and room.AliensAt then
					ctx.Aliens.ClearGroup("Cave_" .. planetId .. "_" .. room.Index)
					room.AliensAt = nil
				end
			end
			-- a secret wall that was broken long ago grows back (while nobody is down there)
			if not anyone then
				for _, tunnel in ipairs(system.Tunnels) do
					if tunnel.Sealed and tunnel.OpenedAt and t - tunnel.OpenedAt > Life.Caves.LootRespawn * 2 then seal(system, tunnel) end
				end
			end
		end
	end
end

-- a new map cycle: the eggs lying in the caves went with the planet's other eggs - the chambers get new ones
function Caves.OnMapReset()
	for _, system in pairs(systems) do
		if system.Prepared then
			for _, room in ipairs(system.Rooms or {}) do
				if room.StockedAt then
					for i = #(room.Loot or {}), 1, -1 do if not room.Loot[i].Parent then table.remove(room.Loot, i) end end
					stockEggs(system, room)
				end
			end
		end
	end
end

function Caves.Init(context)
	ctx = context
	Config = ctx.Config
	Life = ctx.Life
	L = ctx.PlanetLife
	ctx.Caves = Caves
	-- a planet everybody had left lost its eggs with its pool: when the pool comes back, so do the caves' eggs
	local previous = ctx.OnPoolReady
	ctx.OnPoolReady = function(planetId)
		if previous then pcall(previous, planetId) end
		local system = systems[planetId]
		if not system or not system.Prepared then return end
		for _, room in ipairs(system.Rooms) do
			if room.StockedAt then
				for i = #(room.Loot or {}), 1, -1 do if not room.Loot[i].Parent then table.remove(room.Loot, i) end end
				stockEggs(system, room)
			end
		end
	end
	folder = workspace:FindFirstChild("PFE_Caves") or Instance.new("Folder")
	folder.Name = "PFE_Caves"; folder.Parent = workspace
	for _, planet in ipairs(Config.PlanetOrder) do
		for _, entry in ipairs(Life.CaveSites(planet.Id)) do
			local ok, err = pcall(buildSite, planet, entry)
			if not ok then warn("[PFE] cave mouth failed", entry.Key, err) end
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		for profile in pairs(inside) do if profile.Player == player then inside[profile] = nil end end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(step)
			if not ok then warn("[PFE] caves step failed", err) end
		end
	end)
end

return Caves
