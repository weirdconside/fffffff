--!nocheck
-- Alien dungeons: 99 Nights' alien ships, over and in the planets.
--  * Every planet has 99 Nights' UFO hovering high above it with a tractor beam down to a glowing
--    pad on the ground: hold E on the pad and you are beamed aboard. Every planet also has two
--    saucers that already came down, smoking: 99 Nights' crashed UFO and Dead Rails' UFO (tilted, its
--    rim in the ground). A glowing pad at each leads into a shorter ship.
--  * Aboard: one hall of 99 Nights' alien mothership per level, put together far out in space
--    (Config.Dungeons.Space), with the view out of its command window (stars, the Earth), lamps and
--    99 Nights' alien crates and desks. Each level has a wave of Dead Rails' aliens; once they are all
--    down the far airlock lights up: walk into it (or hold E) and the crew is taken to the next hall.
--    The airlocks never open onto space. (No alien models: it lights up after Config.Dungeons.ClearDelay.)
--  * High over every planet (above the sky islands) our own saucer stands still: the alien stronghold
--    (blender/lib_saucer.py: SaucerHull). No beam goes up there - fly to its landing platform with the
--    jetpack. Inside it is nothing like the other ships: three decks round a glowing reactor (SaucerDecks:
--    the hangar, the lab, the bridge), one deck per level; clear a deck and the energy barrier over the
--    ramp up switches off; the chest waits inside the energy fence on the bridge. Its markers (M_*) say
--    where the crew comes in, where the aliens come from, where the lamps and the ways out are.
--  * The last hall is the vault with the alien chest (ours, SaucerChest): a game pass for a while (at most
--    Config.TempPassMax, never VIP) or a great egg straight into the egg storage at home. A player
--    loots at most Config.Dungeons.LootMax chests (any ships) per Config.Dungeons.LootCooldown.
--  * Players who beam up together (while the first level is on) share the ship. The entry airlock
--    takes you back down. No air is used aboard; dying aboard ends the expedition as anywhere else.
local Players = game:GetService("Players")
local Dungeons = {}
local ctx, Config, D
local rng = Random.new()
local folder, sitesFolder, runsFolder, pieces

local BEAM = Color3.fromRGB(120, 255, 170)
local ALERT = Color3.fromRGB(255, 90, 90)
-- the mothership hall (its pivot is the middle of its footprint at the bottom, see build_assets.py):
-- floor top 16 up, entry airlock on the -X wall, exit airlock on the -Z wall, open floor in between
local FLOOR = 16
local CENTRE = Vector3.new(4, FLOOR, -14.5)
local BACK_DOOR = Vector3.new(-33.5, FLOOR + 4, -14.2)
local NEXT_DOOR = Vector3.new(7.8, FLOOR + 4, -66.7)
local SPAWN_POINTS = {
	Vector3.new(12, FLOOR, -14.5), Vector3.new(22, FLOOR, -2), Vector3.new(22, FLOOR, -28), Vector3.new(6, FLOOR, 10),
	Vector3.new(6, FLOOR, -40), Vector3.new(-8, FLOOR, 4), Vector3.new(-8, FLOOR, -34), Vector3.new(28, FLOOR, -14.5),
}
local HALL_STEP = 320 -- halls (and the view out of their window) stay well apart
-- lamps under the ceiling and props along the walls (hall coordinates, clear of the doors and the middle)
local LAMPS = {Vector3.new(-12, FLOOR + 20, -40), Vector3.new(20, FLOOR + 20, -40), Vector3.new(-12, FLOOR + 20, -14.5),
	Vector3.new(20, FLOOR + 20, -14.5), Vector3.new(-12, FLOOR + 20, 12), Vector3.new(20, FLOOR + 20, 12), Vector3.new(4, FLOOR + 20, -52)}
local PROPS = {{"Crates", Vector3.new(-10, FLOOR, 16), 0}, {"Crates", Vector3.new(26, FLOOR, -44), 180},
	{"Desk", Vector3.new(26, FLOOR, 14), 180}, {"Desk", Vector3.new(-10, FLOOR, -42), 0}}

local DECK = 22 -- the stronghold's deck height (its M_Floor markers say it exactly)

local sites = {}      -- key -> site
local runs = {}       -- id -> run
local runOf = {}      -- profile -> run
local freeSlots, slotCount, runCounter = {}, 0, 0

local function members(run)
	local list = {}
	for profile in pairs(run.Players) do
		if ctx.profiles[profile.Player] == profile then table.insert(list, profile) end
	end
	return list
end
local function count(t) local n = 0; for _ in pairs(t) do n += 1 end; return n end
-- the chests a player looted lately (any ships): at most D.LootMax per D.LootCooldown seconds
local function recentLoots(profile)
	local now, list = os.time(), {}
	for key, at in pairs(profile.Data.DungeonLoot) do
		if now - at < D.LootCooldown then table.insert(list, at) else profile.Data.DungeonLoot[key] = nil end
	end
	table.sort(list)
	return list
end
-- seconds until this player may loot another chest (0: now)
local function lootWait(profile)
	local list, max = recentLoots(profile), D.LootMax or 2
	if #list < max then return 0 end
	return math.max(1, D.LootCooldown - (os.time() - list[#list - max + 1]))
end
local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- ---------------------------------------------------------------- pieces
-- no foreign code or prompts: every 99 Nights piece is scenery here
local function strip(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then d:Destroy() end
	end
end
local function anchor(model, collide)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			if collide == false then d.CanCollide = false; d.CanTouch = false; d.CanQuery = false end
		end
	end
end
local function piece(name)
	local source = pieces and pieces:FindFirstChild(name)
	if not source then return nil end
	local model = source:Clone()
	strip(model)
	return model
end
local function biggestPart(model)
	local best, size = nil, -1
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Size.Magnitude > size then best, size = d, d.Size.Magnitude end
	end
	return best
end
local function marker(parent, name, cframe, size)
	local part = Instance.new("Part")
	part.Name = name; part.Size = size or Vector3.new(4, 6, 4); part.CFrame = cframe
	part.Anchored = true; part.CanCollide = false; part.CanTouch = false; part.CanQuery = false; part.Transparency = 1
	part.Parent = parent
	return part
end

-- put a model's bounding box on the floor at `point`, turned by yaw (degrees)
local function onFloor(model, point, yaw, parent)
	model:PivotTo(CFrame.new(point) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	local box, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(point.X - box.Position.X, point.Y - (box.Position.Y - size.Y / 2), point.Z - box.Position.Z))
	model.Parent = parent
	return model
end

-- a column of smoke (and a green fire) over a crash site, seen from across the planet
local function smoke(parent, at)
	local part = marker(parent, "SmokePlume", CFrame.new(at), Vector3.new(6, 1, 6))
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Smoke"; emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(60, 64, 72), Color3.fromRGB(150, 155, 165))
	emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 28)})
	emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1)})
	emitter.Lifetime = NumberRange.new(9, 13); emitter.Rate = 5; emitter.Speed = NumberRange.new(7, 11)
	emitter.SpreadAngle = Vector2.new(10, 10); emitter.Rotation = NumberRange.new(0, 360); emitter.RotSpeed = NumberRange.new(-15, 15)
	emitter.Acceleration = Vector3.new(1.2, 0, 0.6)
	emitter.Parent = part
	local fire = Instance.new("Fire")
	fire.Size = 7; fire.Heat = 10; fire.Color = Color3.fromRGB(120, 255, 170); fire.SecondaryColor = Color3.fromRGB(30, 110, 80)
	fire.Parent = part
	return part
end

-- the glowing pad you stand on to go in (like the tractor beam's)
local function entrancePad(parent, at, size)
	local pad = Instance.new("Part")
	pad.Name = "EntrancePad"; pad.Shape = Enum.PartType.Cylinder; pad.Size = Vector3.new(0.5, size or 12, size or 12)
	pad.CFrame = CFrame.new(at + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	pad.Anchored = true; pad.CanCollide = false; pad.CanTouch = false; pad.CanQuery = false
	pad.Material = Enum.Material.Neon; pad.Color = BEAM; pad.Transparency = 0.3
	pad.Parent = parent
	return pad
end

-- ---------------------------------------------------------------- entrances on the planets
local function groundAt(planet) return planet.Origin.Y end -- the planet discs are flat, their surface at the origin's height

local enter -- (profile, site)
local function onEnterPrompt(site)
	return function(player)
		local profile = ctx.profiles[player]
		if profile then enter(profile, site) end
	end
end

local function buildSky(planet, entry)
	local d = D.Sky
	local ground = Vector3.new(planet.Origin.X + entry.X, groundAt(planet), planet.Origin.Z + entry.Z)
	local model = Instance.new("Model")
	model.Name = planet.Id .. "_Sky"
	-- the UFO itself (99 Nights' UFOAnimate), high over the pad
	local ufo = piece("UFO")
	if ufo then
		ufo.Name = "UFO"
		anchor(ufo, false)
		if math.abs(d.UFOScale - 1) > 0.01 then pcall(function() ufo:ScaleTo(d.UFOScale) end) end
		ufo:PivotTo(CFrame.new(ground + Vector3.new(0, d.Height, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		ufo:SetAttribute("Hover", true)
		ufo.Parent = model
	end
	-- its tractor beam down to the ground
	local beam = Instance.new("Part")
	beam.Name = "TractorBeam"; beam.Shape = Enum.PartType.Cylinder; beam.Size = Vector3.new(d.Height, 16, 16)
	beam.CFrame = CFrame.new(ground + Vector3.new(0, d.Height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beam.Anchored = true; beam.CanCollide = false; beam.CanTouch = false; beam.CanQuery = false; beam.CastShadow = false
	beam.Material = Enum.Material.Neon; beam.Color = BEAM; beam.Transparency = 0.8
	beam.Parent = model
	-- the pad you stand on to be beamed up
	local pad = Instance.new("Part")
	pad.Name = "BeamPad"; pad.Shape = Enum.PartType.Cylinder; pad.Size = Vector3.new(0.6, 20, 20)
	pad.CFrame = CFrame.new(ground + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	pad.Anchored = true; pad.CanCollide = false; pad.CanTouch = false; pad.CanQuery = false
	pad.Material = Enum.Material.Neon; pad.Color = BEAM; pad.Transparency = 0.3
	pad.Parent = model
	model:SetAttribute("Planet", planet.Id); model:SetAttribute("Kind", "Sky"); model:SetAttribute("DungeonName", d.Name)
	model.Parent = sitesFolder
	local site = {Key = entry.Key, Planet = planet.Id, Kind = "Sky", Name = d.Name, Model = model,
		Exit = CFrame.new(ground + Vector3.new(15, 4, 0), ground + Vector3.new(30, 4, 0))}
	ctx.makePrompt(pad, "EnterDungeon", "Beam up", onEnterPrompt(site), {Hold = 0.6, Distance = 14, ObjectText = d.Name})
	local label = ctx.label(pad, d.Name, d.Levels .. " levels of aliens - loot a game pass or a great egg", BEAM, 7)
	if label then label.MaxDistance = 160; label.Size = UDim2.fromOffset(260, 60) end
	return site
end

local function buildGround(planet, entry)
	local d, spec = D.Ground, entry.Spec
	local ground = Vector3.new(planet.Origin.X + entry.X, groundAt(planet), planet.Origin.Z + entry.Z)
	-- the side facing the planet centre (where explorers come from) is the way in
	local toCentre = Vector3.new(planet.Origin.X - ground.X, 0, planet.Origin.Z - ground.Z)
	toCentre = toCentre.Magnitude > 1 and toCentre.Unit or Vector3.new(1, 0, 0)
	local model = piece(spec.Piece)
	local hull = 12 -- how far from the middle the hull reaches (the entrance is just past it)
	if model then
		-- 99 Nights' own ground (grass blocks) stays behind: this is our planet
		for _, name in ipairs({"GrassFolder", "ClearZone"}) do
			local extra = model:FindFirstChild(name)
			if extra then extra:Destroy() end
		end
		anchor(model)
		if spec.Scale and math.abs(spec.Scale - 1) > 0.01 then pcall(function() model:ScaleTo(spec.Scale) end) end
		if spec.Tilt then
			-- Dead Rails' UFO: nose-up towards the planet centre, its far rim dug into the ground
			local box, size = model:GetBoundingBox()
			local offset = box:ToObjectSpace(model:GetPivot())
			local flat = CFrame.lookAt(ground, ground + toCentre)
			model:PivotTo(flat * CFrame.new(0, size.Y * 0.35, 0) * CFrame.Angles(math.rad(spec.Tilt), 0, 0) * offset)
			hull = math.max(size.X, size.Z) * 0.5
		else
			model:PivotTo(CFrame.new(ground) * CFrame.Angles(0, math.rad(40 + (planet.Order or 1) * 53), 0))
			local _, size = model:GetBoundingBox()
			hull = math.min(math.max(size.X, size.Z) * 0.5, 30)
		end
	else
		model = Instance.new("Model")
		marker(model, "Main", CFrame.new(ground + Vector3.new(0, 3, 0)), Vector3.new(10, 6, 10)).Transparency = 0
	end
	model.Name = planet.Id .. "_Ground" .. entry.Index
	model:SetAttribute("Planet", planet.Id); model:SetAttribute("Kind", "Ground"); model:SetAttribute("DungeonName", d.Name)
	model:SetAttribute("Piece", spec.Piece)
	model.Parent = sitesFolder
	-- 99 Nights' crashed UFO: its hatch is the way in; Dead Rails' UFO: under the raised rim
	local functional = model:FindFirstChild("Functional")
	local ship = functional and functional:FindFirstChild("UFO")
	local hatch = ship and ship:FindFirstChild("Hatch")
	local door = hatch and biggestPart(hatch)
	local at
	if door then
		local toward = (door.Position - ground) * Vector3.new(1, 0, 1)
		local out = toward.Magnitude > 0.5 and toward.Unit or toCentre
		at = Vector3.new(door.Position.X, ground.Y, door.Position.Z) + out * 4
		toCentre = out
	else
		at = ground + toCentre * (hull + 5)
	end
	smoke(model, ground + Vector3.new(0, 4, 0))
	local pad = entrancePad(model, at)
	local site = {Key = entry.Key, Planet = planet.Id, Kind = "Ground", Name = d.Name, Model = model,
		Exit = CFrame.lookAt(at + toCentre * 10 + Vector3.new(0, 4, 0), at + toCentre * 20 + Vector3.new(0, 4, 0))}
	ctx.makePrompt(pad, "EnterDungeon", "Enter", onEnterPrompt(site), {Hold = 0.6, Distance = 14, ObjectText = d.Name})
	local label = ctx.label(pad, d.Name, d.Levels .. " levels of aliens - loot a game pass or a great egg", BEAM, 6)
	if label then label.MaxDistance = 160; label.Size = UDim2.fromOffset(260, 60) end
	return site
end

-- the alien stronghold's saucer (ours), standing still high up; the way in on its landing platform
local function buildHigh(planet, entry)
	local d = D.High
	local ground = Vector3.new(planet.Origin.X + entry.X, groundAt(planet), planet.Origin.Z + entry.Z)
	local model = Instance.new("Model")
	model.Name = planet.Id .. "_High"
	local top = ground + Vector3.new(0, d.Height, 0)
	local ship = piece("SaucerHull")
	if ship then
		ship.Name = "Saucer"
		anchor(ship)
		ship:PivotTo(CFrame.new(ground + Vector3.new(0, d.Height, 0)) * CFrame.Angles(0, math.rad(entry.Index * 47), 0))
		local pad = ship:FindFirstChild("M_Pad")
		if pad then top = pad.Position; pad.CanQuery = false; pad.CanTouch = false end
		ship.Parent = model
	else
		local deck = Instance.new("Part")
		deck.Name = "Deck"; deck.Shape = Enum.PartType.Cylinder; deck.Size = Vector3.new(1.2, 34, 34)
		deck.CFrame = CFrame.new(top + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		deck.Anchored = true; deck.Material = Enum.Material.DiamondPlate; deck.Color = Color3.fromRGB(70, 74, 90)
		deck.Parent = model
		top += Vector3.new(0, 1.2, 0)
	end
	local pad = entrancePad(model, top, 16)
	local light = Instance.new("PointLight"); light.Color = BEAM; light.Range = 40; light.Brightness = 2; light.Parent = pad
	model:SetAttribute("Planet", planet.Id); model:SetAttribute("Kind", "High"); model:SetAttribute("DungeonName", d.Name)
	model.Parent = sitesFolder
	local site = {Key = entry.Key, Planet = planet.Id, Kind = "High", Name = d.Name, Model = model,
		Exit = CFrame.new(top + Vector3.new(11, 4, 0), top + Vector3.new(20, 4, 0))}
	ctx.makePrompt(pad, "EnterDungeon", "Enter", onEnterPrompt(site), {Hold = 0.6, Distance = 14, ObjectText = d.Name})
	local label = ctx.label(pad, d.Name, "Fly up with your jetpack - 4 hard levels, the best loot", BEAM, 9)
	if label then label.MaxDistance = 420; label.Size = UDim2.fromOffset(280, 64) end
	return site
end

-- ---------------------------------------------------------------- the ship's halls
local function slotOrigin(slot, level) return D.Space + Vector3.new((level - 1) * HALL_STEP, 0, slot * HALL_STEP) end

-- the two airlocks of a hall (their iris pieces) as {Pieces, Centre}: the one on the -X wall is the way out
local function airlocks(hall, origin)
	local found = {}
	local functional = hall:FindFirstChild("Functional")
	local doors = functional and functional:FindFirstChild("Doors")
	for _, door in ipairs(doors and doors:GetChildren() or {}) do
		local list, sum = {}, Vector3.zero
		for _, p in ipairs(door:GetDescendants()) do
			if p:IsA("BasePart") and p.Name == "DoorPiece" then table.insert(list, p); sum += p.Position end
		end
		if #list > 0 then table.insert(found, {Pieces = list, Centre = sum / #list}) end
	end
	table.sort(found, function(a, b) return a.Centre.X < b.Centre.X end)
	local back = found[1] or {Pieces = {}, Centre = origin + BACK_DOOR}
	local nextDoor = found[2] or {Pieces = {}, Centre = origin + NEXT_DOOR}
	return back, nextDoor
end

-- a stand-in room when the 99 Nights hall is missing: a floor and four walls with the same layout
local function plainHall(origin)
	local hall = Instance.new("Model")
	local function slab(name, size, offset)
		local part = Instance.new("Part")
		part.Name = name; part.Size = size; part.CFrame = CFrame.new(origin + offset); part.Anchored = true
		part.Material = Enum.Material.Metal; part.Color = Color3.fromRGB(70, 76, 96); part.Parent = hall
	end
	slab("Floor", Vector3.new(70, 2, 96), Vector3.new(4, FLOOR - 1, -14.5))
	slab("WallW", Vector3.new(2, 30, 96), Vector3.new(-32, FLOOR + 15, -14.5))
	slab("WallE", Vector3.new(2, 30, 96), Vector3.new(40, FLOOR + 15, -14.5))
	slab("WallN", Vector3.new(70, 30, 2), Vector3.new(4, FLOOR + 15, 34))
	slab("WallS", Vector3.new(70, 30, 2), Vector3.new(4, FLOOR + 15, -63))
	return hall
end

-- the alien chest (ours: blender/lib_saucer.py), its pivot the bottom centre, its front -Z
local function makeChest(parent, at)
	local chest = piece("SaucerChest")
	if chest then
		anchor(chest)
		chest:PivotTo(at)
	else
		chest = Instance.new("Model")
		marker(chest, "Main", at + Vector3.new(0, 2, 0), Vector3.new(7, 4, 4.4)).Transparency = 0
	end
	chest.Name = "AlienChest"
	chest:SetAttribute("AlienChest", true)
	chest.Parent = parent
	return chest
end

local leave, nextLevel, openChest
local function buildHall(run, level)
	local origin = slotOrigin(run.Slot, level)
	local hall = piece("Hall")
	if hall then
		anchor(hall)
		hall:PivotTo(CFrame.new(origin))
	else
		hall = plainHall(origin)
	end
	hall.Name = "Level" .. level
	hall.Parent = run.Folder
	local back, nextDoor = airlocks(hall, origin)
	-- the view out of the command window: 99 Nights' stars and Earth, in place behind the glass
	local view = piece("HallView")
	if view then
		anchor(view, false)
		view:PivotTo(CFrame.new(origin))
		view.Name = "View"
		view.Parent = hall
	end
	-- light: lamps under the ceiling (the client also brightens the whole ship, see PlanetClient)
	for i, offset in ipairs(LAMPS) do
		local lamp = marker(hall, "Lamp" .. i, CFrame.new(origin + offset), Vector3.new(1, 1, 1))
		local light = Instance.new("PointLight")
		light.Range = 38; light.Brightness = 1.6; light.Color = Color3.fromRGB(215, 255, 230); light.Shadows = false
		light.Parent = lamp
	end
	-- 99 Nights' alien crates and desks along the walls
	for _, prop in ipairs(PROPS) do
		local model = piece(prop[1])
		if model then
			anchor(model)
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") and d.Name == "Main" then d.Transparency = 1; d.CanCollide = false end
			end
			onFloor(model, origin + prop[2], prop[3], hall)
		end
	end
	local inward = ((origin + CENTRE) - back.Centre) * Vector3.new(1, 0, 1)
	inward = inward.Magnitude > 0.1 and inward.Unit or Vector3.new(1, 0, 0)
	local spawnAt = Vector3.new(back.Centre.X, origin.Y + FLOOR + 3, back.Centre.Z) + inward * 11
	local info = {Model = hall, Origin = origin, Next = nextDoor,
		Spawn = CFrame.lookAt(spawnAt, spawnAt + inward), Points = {}}
	for _, p in ipairs(SPAWN_POINTS) do table.insert(info.Points, origin + p) end
	-- the entry airlock: back down to the planet
	local out = marker(hall, "Exit", CFrame.new(Vector3.new(back.Centre.X, origin.Y + FLOOR + 3, back.Centre.Z) + inward * 4))
	ctx.makePrompt(out, "LeaveShip", "Leave ship", function(player)
		local profile = ctx.profiles[player]
		if profile and runOf[profile] == run then leave(profile, true) end
	end, {Hold = 0.5, Distance = 10, ObjectText = run.Site.Name})
	if level <= run.Levels then
		-- the far airlock opens once the level is clear
		local toward = ((origin + CENTRE) - nextDoor.Centre) * Vector3.new(1, 0, 1)
		toward = toward.Magnitude > 0.1 and toward.Unit or Vector3.new(0, 0, 1)
		local door = marker(hall, "Airlock", CFrame.new(Vector3.new(nextDoor.Centre.X, origin.Y + FLOOR + 3, nextDoor.Centre.Z) + toward * 5))
		info.NextPrompt = ctx.makePrompt(door, "NextLevel", "Next level", function(player)
			local profile = ctx.profiles[player]
			if profile and runOf[profile] == run then nextLevel(run) end
		end, {Hold = 0.3, Distance = 12, ObjectText = "Airlock"})
		info.NextPrompt.Enabled = false
		-- walking into the lit airlock takes the crew through as well
		local trigger = marker(hall, "AirlockTrigger", CFrame.new(Vector3.new(nextDoor.Centre.X, origin.Y + FLOOR + 3, nextDoor.Centre.Z) + toward * 2),
			Vector3.new(9, 7, 5))
		trigger.CanTouch = false
		trigger.Touched:Connect(function(hit)
			if run.State ~= "Open" or run.Level ~= level then return end
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			local profile = player and ctx.profiles[player]
			if profile and runOf[profile] == run then nextLevel(run) end
		end)
		info.Trigger = trigger
	else
		-- the vault: the alien chest in the middle, its front towards the way in
		local chest = makeChest(hall, CFrame.lookAt(origin + CENTRE, origin + CENTRE - inward))
		local main = chest:FindFirstChild("Main") or biggestPart(chest)
		info.Chest = chest
		info.ChestPrompt = ctx.makePrompt(main, "OpenChest", "Open", function(player)
			local profile = ctx.profiles[player]
			if profile and runOf[profile] == run then openChest(run, profile) end
		end, {Hold = 1, Distance = 14, ObjectText = "Alien Chest"})
		local label = ctx.label(chest, "Alien Chest", "A game pass or a great egg", BEAM, 6)
		if label then label.MaxDistance = 90 end
	end
	return info
end

-- the stronghold: our saucer's three decks, a deck per level; the barrier over each ramp up (and the
-- fence round the chest on the bridge) are the airlocks
local function buildFort(run)
	local origin = slotOrigin(run.Slot, 1)
	local ship = piece("SaucerDecks")
	if ship then
		anchor(ship)
		ship:PivotTo(CFrame.new(origin))
	else
		ship = plainHall(origin)
	end
	ship.Name = "Stronghold"
	ship.Parent = run.Folder
	for _, d in ipairs(ship:GetChildren()) do
		if d:IsA("BasePart") and d.Name:sub(1, 2) == "M_" then d.CanQuery = false; d.CanTouch = false; d.CanCollide = false end
	end
	local function spot(name, default)
		local m = ship:FindFirstChild(name)
		return m and m.Position or origin + default
	end
	local spawnAt = spot("M_Spawn", Vector3.new(0, FLOOR + 3, 0))
	local info = {Model = ship, Origin = origin, Spawn = CFrame.lookAt(spawnAt, spot("M_Look", Vector3.new(0, FLOOR + 3, -20))),
		Points = {}, Doors = {}, Floors = {}}
	for level = 1, run.Levels do
		local deck = math.min(level, 3)
		info.Floors[level] = spot("M_Floor" .. deck, Vector3.new(0, (deck - 1) * DECK, 0)).Y - origin.Y
		local list = {}
		for i = 1, 16 do
			local m = ship:FindFirstChild("M_P" .. deck .. "_" .. i)
			if not m then break end
			table.insert(list, m.Position)
		end
		if #list == 0 then
			for _, p in ipairs(SPAWN_POINTS) do table.insert(list, origin + p) end
		end
		info.Points[level] = list
		-- what opens once this deck is clear: the barrier over the ramp up; after the top deck the fence
		local seal = level >= run.Levels and "Gate" or ("Barrier" .. level)
		local parts = {}
		for _, d in ipairs(ship:GetChildren()) do
			if d:IsA("BasePart") and d.Name == seal then table.insert(parts, d) end
		end
		info.Doors[level] = parts
	end
	for i = 1, 32 do
		local m = ship:FindFirstChild("M_Lamp" .. i)
		if not m then break end
		local light = Instance.new("PointLight")
		light.Range = 36; light.Brightness = 1.5; light.Color = Color3.fromRGB(225, 235, 255); light.Shadows = false
		light.Parent = m
	end
	-- the ways out: by the hatch on the hangar deck, and on the bridge
	for i = 1, 2 do
		local at = spot("M_Exit" .. i, i == 1 and Vector3.new(-5, 3, 30) or Vector3.new(6, 2 * DECK + 3, 30))
		local out = marker(ship, "Exit" .. i, CFrame.new(at))
		ctx.makePrompt(out, "LeaveShip", "Leave", function(player)
			local profile = ctx.profiles[player]
			if profile and runOf[profile] == run then leave(profile, true) end
		end, {Hold = 0.5, Distance = 10, ObjectText = run.Site.Name})
	end
	-- the chest on its pedestal inside the bridge's fence (its prompt wakes up once the deck is clear)
	local mark = ship:FindFirstChild("M_Chest")
	local chest = makeChest(ship, mark and mark.CFrame or CFrame.new(origin + Vector3.new(16, 2 * DECK + 1.2, 22)))
	info.Chest = chest
	info.ChestPrompt = ctx.makePrompt(chest:FindFirstChild("Main") or biggestPart(chest), "OpenChest", "Open", function(player)
		local profile = ctx.profiles[player]
		if profile and runOf[profile] == run then openChest(run, profile) end
	end, {Hold = 1, Distance = 14, ObjectText = "Alien Chest"})
	info.ChestPrompt.Enabled = false
	return info
end

-- ---------------------------------------------------------------- runs
local function publish(run)
	for _, profile in ipairs(members(run)) do
		local player = profile.Player
		player:SetAttribute("PFEDungeon", run.Site.Name)
		player:SetAttribute("PFEDungeonRun", run.Id)
		player:SetAttribute("PFEDungeonLevel", run.Level)
		player:SetAttribute("PFEDungeonLevels", run.Levels)
		player:SetAttribute("PFEDungeonState", run.State)
		player:SetAttribute("PFEDungeonAliens", run.Alive or 0)
		player:SetAttribute("PFEDungeonOpenAt", run.OpenAt or 0)
		player:SetAttribute("PFEDungeonKind", run.Fort and "Fort" or "Ship")
	end
end
local function clearAttributes(player)
	for _, key in ipairs({"PFEDungeon", "PFEDungeonRun", "PFEDungeonLevel", "PFEDungeonLevels", "PFEDungeonState", "PFEDungeonAliens", "PFEDungeonOpenAt", "PFEDungeonKind"}) do
		player:SetAttribute(key, nil)
	end
end

local function placeIn(run, profile)
	local hall = run.Fort or run.Halls[run.Level]
	local character = profile.Player.Character
	if not hall or not character then return end
	local jitter = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
	if workspace.StreamingEnabled then
		pcall(function() profile.Player:RequestStreamAroundAsync(hall.Spawn.Position, 2) end)
	end
	character:PivotTo(hall.Spawn + jitter)
end

local function startLevel(run, level)
	run.Level = level
	local list = members(run)
	local points
	if run.Interior == "Fort" then
		-- the stronghold: built once; the crew walks up from floor to floor
		if not run.Fort then
			run.Fort = buildFort(run)
			for _, profile in ipairs(list) do placeIn(run, profile) end
		end
		points = run.Fort.Points[level]
	else
		run.Halls[level] = run.Halls[level] or buildHall(run, level)
		for _, profile in ipairs(list) do placeIn(run, profile) end
		points = run.Halls[level] and run.Halls[level].Points
	end
	run.OpenAt = nil
	if level > run.Levels then
		run.State = "Vault"; run.Alive = 0
		for _, profile in ipairs(list) do ctx.effect(profile.Player, "DungeonLevel", {Level = level, Levels = run.Levels, Vault = true, Name = run.Site.Name}) end
		publish(run)
		return
	end
	run.State = "Fight"
	local wave = D.WaveBase + D.WavePerLevel * (level - 1) + math.max(0, #list - 1)
	local aliens = ctx.Aliens
	-- the stronghold high up: the same ship's halls, but more of them, more aliens and tougher ones
	local high = run.Site.Kind == "High"
	if high then wave += D.High.ExtraAliens or 3 end
	run.Spawned = aliens and aliens.SpawnGroup and aliens.SpawnGroup(run.Tag, run.Site.Planet, points or {}, wave, function()
		return members(run)
	end, level + (high and (D.High.ExtraTier or 2) or 0)) or 0
	run.Alive = run.Spawned
	for _, profile in ipairs(list) do
		ctx.effect(profile.Player, "DungeonLevel", {Level = level, Levels = run.Levels, Aliens = run.Spawned, Name = run.Site.Name, Fort = run.Fort ~= nil})
	end
	publish(run)
end

local function openAirlock(run)
	if run.Fort then
		-- the stronghold: that deck's barrier switches off (the ramp up is free - inside the ship, never
		-- outside); after the top deck the fence round the chest goes down
		for _, d in ipairs(run.Fort.Doors[run.Level] or {}) do
			d.Transparency = 1; d.CanCollide = false; d.CanQuery = false
		end
		local last = run.Level >= run.Levels
		run.State = last and "Vault" or "Open"
		if last then run.Fort.ChestPrompt.Enabled = true end
		for _, profile in ipairs(members(run)) do
			ctx.effect(profile.Player, "DungeonClear", {Level = run.Level, Vault = last, Fort = true})
		end
		publish(run)
		return
	end
	local hall = run.Halls[run.Level]
	run.State = "Open"
	-- the airlock doesn't open onto space: it lights up and leads to the next hall
	for _, p in ipairs(hall.Next.Pieces) do
		p.Material = Enum.Material.Neon; p.Color = BEAM
	end
	if hall.NextPrompt then hall.NextPrompt.Enabled = true end
	if hall.Trigger then hall.Trigger.CanTouch = true end
	-- (the client shows a "LEVEL CLEAR!" splash)
	for _, profile in ipairs(members(run)) do ctx.effect(profile.Player, "DungeonClear", {Level = run.Level, Vault = run.Level >= run.Levels}) end
	publish(run)
end

function nextLevel(run)
	if run.State ~= "Open" or run.Level > run.Levels then return end
	startLevel(run, run.Level + 1)
end

local function closeRun(run)
	if ctx.Aliens and ctx.Aliens.ClearGroup then ctx.Aliens.ClearGroup(run.Tag) end
	for _, profile in ipairs(members(run)) do leave(profile, true) end
	runs[run.Id] = nil
	if run.Folder then run.Folder:Destroy() end
	table.insert(freeSlots, run.Slot)
end

local function newRun(site)
	runCounter += 1
	local slot = table.remove(freeSlots)
	if not slot then slotCount += 1; slot = slotCount end
	local runFolder = Instance.new("Folder")
	runFolder.Name = "Run" .. runCounter
	runFolder:SetAttribute("SiteKey", site.Key)
	runFolder.Parent = runsFolder
	local run = {Id = runCounter, Tag = "Dungeon" .. runCounter, Site = site, Slot = slot, Levels = D[site.Kind].Levels,
		Level = 0, Halls = {}, Players = {}, Looted = {}, State = "Fight", Folder = runFolder,
		Interior = "Hall"} -- (every ship is the mothership's halls; the stronghold's are harder, see startLevel)
	runs[run.Id] = run
	return run
end

-- why this explorer can't go aboard right now (nil when they can)
local function refusal(profile, site)
	local expedition = profile.Expedition
	if profile.Busy or runOf[profile] then return "busy" end
	if profile.Stolen then return "You can't go aboard with a stolen egg!" end
	if not expedition or expedition.Planet ~= site.Planet or profile.Planet ~= site.Planet then return "Land on this planet to go aboard." end
	if expedition.CarryingEgg then return "Take the egg to your rocket first - you need your hands free in there!" end
	if not ctx.near(profile, site.Model:FindFirstChild("BeamPad") or site.Model:FindFirstChild("EntrancePad"), 20) then return "Get closer." end
	local wait = lootWait(profile)
	if wait > 0 then
		return "You looted " .. (D.LootMax or 2) .. " alien ships already. The chests refill in " .. clock(wait) .. "."
	end
	return nil
end

function enter(profile, site)
	local reason = refusal(profile, site)
	if reason then
		if reason ~= "busy" then ctx.notice(profile, reason, "Red") end
		return false
	end
	-- join the crew of this ship that is still on its first level, or take a new ship
	local run
	for _, r in pairs(runs) do
		if r.Site == site and r.Level == 1 and r.State == "Fight" and count(r.Players) < D.MaxCrew then run = r; break end
	end
	local fresh = run == nil
	run = run or newRun(site)
	run.Players[profile] = true
	runOf[profile] = run
	profile.InDungeon = run.Tag
	ctx.setSprint(profile, false)
	ctx.effect(profile.Player, "DungeonEnter", {Name = site.Name, Kind = site.Kind})
	if fresh then
		startLevel(run, 1)
	else
		placeIn(run, profile)
		publish(run)
	end
	ctx.markDirty(profile)
	return true
end

-- off the ship: back to the entrance on the planet (toSurface), or just out of the crew (died, left)
function leave(profile, toSurface)
	local run = runOf[profile]
	if not run then return end
	runOf[profile] = nil
	run.Players[profile] = nil
	profile.InDungeon = nil
	if profile.Player.Parent then clearAttributes(profile.Player) end
	if toSurface and profile.Player.Character then
		profile.Player.Character:PivotTo(run.Site.Exit)
		ctx.effect(profile.Player, "DungeonExit", {Name = run.Site.Name})
	end
	ctx.markDirty(profile)
end

-- 99 Nights' alien chest: a game pass for a while, or a great egg
function openChest(run, profile)
	if run.State ~= "Vault" or run.Looted[profile] then return end
	local site = run.Site
	local loot = D[site.Kind].Loot
	local data = profile.Data
	if lootWait(profile) > 0 then
		ctx.notice(profile, "You looted " .. (D.LootMax or 2) .. " alien ships already - wait for the chests to refill.", "Red"); return
	end
	run.Looted[profile] = true
	local lootId = "L" .. os.time() .. "_" .. rng:NextInteger(100, 999)
	data.DungeonLoot[lootId] = os.time()
	-- passes the player doesn't own for good
	local keys = {}
	for _, key in ipairs(Config.TempPassKeys) do
		if Config.GamePasses[key] and profile.Passes[key] ~= true then table.insert(keys, key) end
	end
	local eggRoom = #data.Eggs < Config.MaxStoredEggs
	local givePass = #keys > 0 and (rng:NextNumber() < loot.PassChance or not eggRoom)
	if givePass then
		local key = keys[rng:NextInteger(1, #keys)]
		local seconds = math.max(1, math.floor(rng:NextNumber(loot.PassMinutes[1], loot.PassMinutes[2]) * 60 + 0.5))
		local left = ctx.Shop.GrantTemp(profile, key, seconds, seconds)
		local pass = Config.GamePasses[key]
		ctx.effect(profile.Player, "DungeonLoot", {Kind = "Pass", Key = key, Name = pass.Name, Seconds = left, Left = D.LootMax - #recentLoots(profile)})
	elseif eggRoom then
		local Expeditions = ctx.Expeditions
		local info = Expeditions.RollEgg(profile, site.Planet, 4, loot.EggRare, loot.EggSuper)
		if not info then return end
		local egg = {Id = ctx.Data.Guid(), EggId = info.Id, Scale = Expeditions.RollSize(), Mutation = Expeditions.RollMutation(profile, site.Planet)}
		table.insert(data.Eggs, egg)
		data.DiscoveredEggs[info.Id] = true
		data.Stats.EggsFound += 1
		ctx.effect(profile.Player, "DungeonLoot", {Kind = "Egg", EggId = info.Id, Mutation = egg.Mutation, Scale = egg.Scale, Left = D.LootMax - #recentLoots(profile)})
		local rarity = Config.Rarities[info.Rarity]
		if rarity and rarity.Order >= 5 then
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= profile.Player then
					ctx.remotes.Notice:FireClient(other, profile.Player.DisplayName .. " found " .. Config.EggDisplayName(egg) .. " in an alien ship!", info.Rarity)
				end
			end
		end
	else
		ctx.notice(profile, "Your egg storage is full - plant some eggs first!", "Red")
		run.Looted[profile] = nil
		data.DungeonLoot[lootId] = nil
		return
	end
	local wait = lootWait(profile)
	if wait > 0 then
		ctx.notice(profile, "That was your " .. (D.LootMax or 2) .. "nd alien chest - the chests refill in " .. clock(wait) .. ".", "Purple")
	end
	ctx.markDirty(profile)
end

-- ---------------------------------------------------------------- lifecycle
local function step()
	local t = os.clock()
	for _, run in pairs(runs) do
		for profile in pairs(run.Players) do
			-- gone, or no longer exploring this planet (died, reset): out of the crew
			if ctx.profiles[profile.Player] ~= profile or not profile.Expedition or profile.Planet ~= run.Site.Planet then
				leave(profile, false)
			end
		end
		if next(run.Players) == nil then
			run.EmptySince = run.EmptySince or t
			if t - run.EmptySince >= D.IdleClose then closeRun(run) end
		else
			run.EmptySince = nil
			if run.Fort and run.State == "Open" then
				local floor = run.Fort.Floors[run.Level + 1]
				for _, profile in ipairs(members(run)) do
					local root = ctx.root(profile.Player)
					if floor and root and root.Position.Y >= run.Fort.Origin.Y + floor - 2 then startLevel(run, run.Level + 1); break end
				end
			end
			if run.State == "Fight" and run.Level >= 1 then
				local alive = ctx.Aliens and ctx.Aliens.GroupAlive and ctx.Aliens.GroupAlive(run.Tag) or 0
				if alive ~= run.Alive then run.Alive = alive; publish(run) end
				if alive == 0 then
					if not run.OpenAt then
						run.OpenAt = workspace:GetServerTimeNow() + D.ClearDelay
						publish(run)
					elseif workspace:GetServerTimeNow() >= run.OpenAt then
						openAirlock(run)
					end
				end
			end
		end
	end
end

function Dungeons.InDungeon(profile) return runOf[profile] ~= nil end
function Dungeons.Sites() return sites end
function Dungeons.OnLeft(profile) leave(profile, false) end

function Dungeons.Init(context)
	ctx = context
	Config = ctx.Config
	D = Config.Dungeons
	ctx.Dungeons = Dungeons
	pieces = ctx.network:FindFirstChild("Dungeon")
	folder = workspace:FindFirstChild("PFE_Dungeons") or Instance.new("Folder")
	folder.Name = "PFE_Dungeons"; folder.Parent = workspace
	sitesFolder = Instance.new("Folder"); sitesFolder.Name = "Sites"; sitesFolder.Parent = folder
	runsFolder = Instance.new("Folder"); runsFolder.Name = "Runs"; runsFolder.Parent = folder
	for _, planet in ipairs(Config.PlanetOrder) do
		for _, entry in ipairs(Config.DungeonSites(planet.Id)) do
			local build = entry.Kind == "Sky" and buildSky or entry.Kind == "High" and buildHigh or buildGround
			local ok, result = pcall(build, planet, entry)
			if ok and result then sites[result.Key] = result else warn("[PFE] dungeon entrance failed", entry.Key, result) end
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		for profile, run in pairs(runOf) do
			if profile.Player == player then run.Players[profile] = nil; runOf[profile] = nil end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(step)
			if not ok then warn("[PFE] dungeons step failed", err) end
		end
	end)
end

return Dungeons
