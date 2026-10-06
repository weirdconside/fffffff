--!nocheck
-- (v36) EggForge: one-of-a-kind eggs made by Fusion. An egg id like "Gen_5_918273645" (rarity index, seed) says
-- everything: the server and every client rebuild the same egg from it - its name, colours, pattern, topper and
-- glow, and the HYBRID pets inside it (each one stitched from three pets, like the Chimera, with its own name and an
-- income set by the egg's rarity). Nothing extra has to be saved or sent: an egg record only keeps its EggId.
--   EggForge.IsGen(id)        is this a forged egg id?
--   EggForge.NewId(rarity, r) a fresh id of that rarity
--   EggForge.Info(id)         the egg's info, like a Config.Eggs entry (+ Generated, Hybrids, Color, Color2)
--   EggForge.Template(id)     its model (Config.Eggs / UIAssets work for it too: Config.Eggs[id] finds it)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent:WaitForChild("Config"))

local EggForge = {}
local infos, templates = {}, {}

function EggForge.IsGen(id)
	return type(id) == "string" and string.sub(id, 1, 4) == "Gen_"
end
local function parse(id)
	local r, seed = string.match(id, "^Gen_(%d+)_(%d+)$")
	if not r then return nil end
	return tonumber(r), tonumber(seed)
end

function EggForge.NewId(rarity, random)
	local index = 1
	for i, id in ipairs(Config.RarityOrder) do if id == rarity then index = i end end
	local seed = (random or Random.new()):NextInteger(1, 899999999)   -- (v38: the daily calendar's eggs use 900000001+)
	return string.format("Gen_%d_%d", index, seed)
end

-- ---------------------------------------------------------------- names
local ADJ = {"Nebula", "Prism", "Void", "Solar", "Frost", "Ember", "Astral", "Quantum", "Crystal", "Thunder", "Shadow", "Aurora", "Cosmic",
	"Mythril", "Phantom", "Starlit", "Inferno", "Tidal", "Emerald", "Obsidian", "Celestial", "Plasma", "Lunar", "Radiant", "Galactic",
	"Venom", "Golden", "Abyssal", "Sakura", "Storm", "Rune", "Chrono", "Glitch", "Neon", "Ancient", "Hyper"}
local NOUN = {"Core", "Heart", "Bloom", "Shard", "Storm", "Crown", "Pulse", "Rift", "Nova", "Spire", "Dream", "Fang", "Halo", "Echo",
	"Vortex", "Comet", "Seed", "Prism", "Flare", "Relic", "Orb", "Gem", "Wing", "Soul", "Spark", "Titan", "Oracle", "Dynasty"}

-- ---------------------------------------------------------------- the hybrids inside
local incomeCache = {}
local function medianIncome(rarity)
	if incomeCache[rarity] then return incomeCache[rarity] end
	local list = {}
	for _, pet in ipairs(Config.PetList) do
		if pet.Rarity == rarity and not pet.Limited and not pet.Special then table.insert(list, pet.Income) end
	end
	table.sort(list)
	local value = #list > 0 and list[math.ceil(#list / 2)] or 10
	incomeCache[rarity] = value
	return value
end
local growthCache = {}
local function growthTime(rarity)
	if growthCache[rarity] then return growthCache[rarity] end
	local list = {}
	for _, egg in pairs(Config.Eggs) do
		if egg.Rarity == rarity and type(egg.GrowthTime) == "number" then table.insert(list, egg.GrowthTime) end
	end
	table.sort(list)
	local value = #list > 0 and list[math.ceil(#list / 2)] or 120
	growthCache[rarity] = value
	return value
end
local WEIGHTS = {52, 30, 13, 5}
local BONUS = {1.2, 1.5, 1.95, 2.6}      -- each hybrid out-earns a normal pet of the egg's rarity, the rarer the more

local function makeHybrids(r, rarity, rng)
	local pool = {}
	for _, pet in ipairs(Config.PetList) do
		local order = Config.Rarities[pet.Rarity] and Config.Rarities[pet.Rarity].Order or 1
		if not pet.Limited and not pet.Special and order >= r - 2 and order <= r then table.insert(pool, pet.Species) end
	end
	if #pool < 6 then
		pool = {}
		for _, pet in ipairs(Config.PetList) do if not pet.Limited and not pet.Special then table.insert(pool, pet.Species) end end
	end
	local count = r >= 5 and 4 or 3
	local base = medianIncome(rarity)
	local list, used = {}, {}
	for i = 1, count do
		local parts = {}
		for _ = 1, 3 do
			local species
			for _ = 1, 12 do
				species = pool[rng:NextInteger(1, #pool)]
				if not used[species] then break end
			end
			used[species] = true
			table.insert(parts, species)
		end
		table.insert(list, {Parts = parts, Name = Config.ChimeraName(parts[1], parts[2]),
			Income = math.max(1, math.floor(base * BONUS[i] * rng:NextNumber(0.92, 1.1) + 0.5)), Weight = WEIGHTS[i] or 3})
	end
	return list
end

-- ---------------------------------------------------------------- the info (like a Config.Eggs entry)
-- (v38) the daily calendar's eggs: seeds from Config.Daily.EggSeedBase on; their name, colours and the income
-- of their hybrids come from Config.Daily (about Income coins a second, a little more for the rarer hybrids)
local DAILY_SPREAD = {0.85, 1.05, 1.35, 1.8}
local function dailyInfo(id, r, seed)
	local daily = Config.Daily
	local day = daily and seed - daily.EggSeedBase
	local entry = day and daily.Days[day]
	if not entry or entry.Kind ~= "Egg" then return nil end
	local rarity = Config.RarityOrder[r]
	local rng = Random.new(seed)
	local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end
	local info = {Id = id, Name = entry.Name, Rarity = rarity, Planet = "Daily", Tier = r, Weight = 0, GrowthTime = entry.Growth or 60,
		Drops = {}, Fusion = true, Generated = true, Daily = day, Seed = seed, Color = rgb(entry.Colors[1]), Color2 = rgb(entry.Colors[2]),
		Glow = rgb(entry.Colors[3]), Pattern = 3, Topper = entry.Topper or 5}
	local hybrids = makeHybrids(r, rarity, rng)
	for i, h in ipairs(hybrids) do
		h.Income = math.max(1, math.floor(entry.Income * (DAILY_SPREAD[i] or 1) * rng:NextNumber(0.95, 1.05) + 0.5))
	end
	info.Hybrids = hybrids
	return info
end

function EggForge.Info(id)
	local cached = infos[id]
	if cached then return cached end
	local r, seed = parse(id)
	if not r then return nil end
	r = math.clamp(r, 1, math.min(8, #Config.RarityOrder))
	if Config.Daily and seed > Config.Daily.EggSeedBase and seed <= Config.Daily.EggSeedBase + #Config.Daily.Days then
		local info = dailyInfo(id, r, seed)
		if info then infos[id] = info; return info end
	end
	local rarity = Config.RarityOrder[r]
	local rng = Random.new(seed)
	local name = ADJ[rng:NextInteger(1, #ADJ)] .. " " .. NOUN[rng:NextInteger(1, #NOUN)] .. " Egg"
	local hue = rng:NextNumber()
	local c1 = Color3.fromHSV(hue, rng:NextNumber(0.45, 0.85), rng:NextNumber(0.75, 1))
	local c2 = Color3.fromHSV((hue + rng:NextNumber(0.12, 0.5)) % 1, rng:NextNumber(0.4, 0.9), rng:NextNumber(0.55, 1))
	local glow = Color3.fromHSV((hue + 0.5) % 1, 0.6, 1)
	local info = {Id = id, Name = name, Rarity = rarity, Planet = "Fusion", Tier = r, Weight = 0, GrowthTime = growthTime(rarity),
		Drops = {}, Fusion = true, Generated = true, Seed = seed, Color = c1, Color2 = c2, Glow = glow,
		Pattern = rng:NextInteger(1, 7), Topper = rng:NextInteger(1, 6)}
	info.Hybrids = makeHybrids(r, rarity, rng)
	info.Species = nil
	infos[id] = info
	return info
end

-- ---------------------------------------------------------------- the model (a stepped voxel egg like the others)
local W, H, N = 1.2, 1.56, 10
local function block(model, name, size, cf, color, material, extra)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
	p.Material = material or Enum.Material.Plastic
	if p.Material == Enum.Material.Plastic then pcall(function() p.MaterialVariant = "Studs" end) end
	p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if extra then for k, v in pairs(extra) do p[k] = v end end
	p.Parent = model
	return p
end
local function radiusAt(t)
	local mid = 0.42
	local k = t < mid and (t - mid) / mid or (t - mid) / (1 - mid)
	return W / 2 * math.sqrt(math.max(0.02, 1 - k * k))
end

function EggForge.Build(id)
	local info = EggForge.Info(id)
	if not info then return nil end
	local rng = Random.new(info.Seed + 7)
	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("EggId", id)
	model:SetAttribute("Generated", true)
	local c1, c2, glow = info.Color, info.Color2, info.Glow
	local h = H / N
	local order = info.Tier
	for i = 1, N do
		local t = (i - 0.5) / N
		local w = math.max(0.16, radiusAt(t) * 2)
		local y = (i - 0.5) * h
		local color = c1
		local pattern = info.Pattern
		if pattern == 1 then color = (i % 2 == 0) and c2 or c1                      -- bands
		elseif pattern == 2 then color = t > 0.5 and c2 or c1                        -- halves
		elseif pattern == 3 then color = c1:Lerp(c2, t)                              -- gradient
		elseif pattern == 4 then color = (i % 3 == 0) and c2 or c1                   -- stripes
		elseif pattern == 7 then color = c1:Lerp(c2, (math.sin(t * 9) + 1) / 2) end  -- waves
		local name = (i == 4) and "Core" or "Slab"
		block(model, name, Vector3.new(w, h + 0.002, w * 0.76), CFrame.new(0, y, 0), color)
		block(model, name == "Core" and "Slab" or "Slab", Vector3.new(w * 0.76, h, w), CFrame.new(0, y, 0), color)
		-- spots / sparkles on the faces
		if (pattern == 5 or pattern == 6) and i > 1 and i < N and rng:NextNumber() < 0.75 then
			local spot = pattern == 6 and glow or c2
			local mat = pattern == 6 and Enum.Material.Neon or nil
			for _ = 1, 2 do
				local side = rng:NextInteger(1, 4)
				local s = math.min(0.22, w * 0.25)
				local off = rng:NextNumber(-w * 0.25, w * 0.25)
				local p = ({Vector3.new(w / 2, 0, off), Vector3.new(-w / 2, 0, off), Vector3.new(off, 0, w / 2), Vector3.new(off, 0, -w / 2)})[side]
				local size = (side <= 2) and Vector3.new(0.05, s, s) or Vector3.new(s, s, 0.05)
				block(model, "Spot", size, CFrame.new(p + Vector3.new(0, y, 0)), spot, mat)
			end
		end
	end
	-- the rarer, the more it shines: a glowing belt, then rings round it (decor: never counts for its size)
	if order >= 3 then
		local w = radiusAt(0.42) * 2 + 0.03
		block(model, "Belt", Vector3.new(w, 0.07, w * 0.78), CFrame.new(0, H * 0.42, 0), order >= 4 and glow or c2,
			order >= 4 and Enum.Material.Neon or nil)
		block(model, "Belt", Vector3.new(w * 0.78, 0.07, w), CFrame.new(0, H * 0.42, 0), order >= 4 and glow or c2,
			order >= 4 and Enum.Material.Neon or nil)
	end
	if order >= 5 then
		local rings = order >= 7 and 2 or 1
		for k = 1, rings do
			local radius = W * (0.85 + k * 0.18)
			local tilt = CFrame.Angles(math.rad(k == 1 and 18 or -24), 0, math.rad(k == 1 and -10 or 14))
			for j = 0, 15 do
				local a = j / 16 * math.pi * 2
				local p = block(model, "Ring", Vector3.new(radius * 0.4, 0.05, 0.08),
					CFrame.new(0, H * 0.48, 0) * tilt * CFrame.new(math.cos(a) * radius, 0, math.sin(a) * radius) * CFrame.Angles(0, -a + math.pi / 2, 0),
					glow, Enum.Material.Neon)
				p:SetAttribute("PFEFx", true)
			end
		end
	end
	-- the topper
	local top = H + 0.02
	local tp = info.Topper
	if tp == 1 then          -- a crystal
		block(model, "Topper", Vector3.new(0.22, 0.42, 0.22), CFrame.new(0, top + 0.18, 0) * CFrame.Angles(0, math.rad(45), math.rad(12)), glow,
			Enum.Material.Neon)
	elseif tp == 2 then      -- a little crown
		block(model, "Topper", Vector3.new(0.4, 0.1, 0.4), CFrame.new(0, top + 0.03, 0), Color3.fromRGB(255, 205, 60), Enum.Material.Foil)
		for j = 0, 3 do
			local a = j / 4 * math.pi * 2 + math.pi / 4
			block(model, "Topper", Vector3.new(0.08, 0.16, 0.08), CFrame.new(math.cos(a) * 0.16, top + 0.15, math.sin(a) * 0.16),
				Color3.fromRGB(255, 205, 60), Enum.Material.Foil)
		end
	elseif tp == 3 then      -- a flame
		block(model, "Topper", Vector3.new(0.18, 0.3, 0.18), CFrame.new(0, top + 0.12, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(255, 120, 30),
			Enum.Material.Neon)
		block(model, "Topper", Vector3.new(0.1, 0.18, 0.1), CFrame.new(0, top + 0.3, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(255, 230, 120),
			Enum.Material.Neon)
	elseif tp == 4 then      -- two horns
		for side = -1, 1, 2 do
			block(model, "Topper", Vector3.new(0.08, 0.3, 0.08), CFrame.new(side * 0.14, top + 0.08, 0) * CFrame.Angles(0, 0, math.rad(-side * 25)), c2)
		end
	elseif tp == 5 then      -- a star
		for _, rz in ipairs({0, 90}) do
			block(model, "Topper", Vector3.new(0.34, 0.08, 0.06), CFrame.new(0, top + 0.17, 0) * CFrame.Angles(0, 0, math.rad(rz + 45)), glow, Enum.Material.Neon)
		end
	else                     -- an antenna with a bulb
		block(model, "Topper", Vector3.new(0.05, 0.28, 0.05), CFrame.new(0, top + 0.1, 0), Color3.fromRGB(200, 200, 210))
		block(model, "Topper", Vector3.new(0.14, 0.14, 0.14), CFrame.new(0, top + 0.27, 0), glow, Enum.Material.Neon)
	end
	-- the root: an upright invisible pivot at the bottom centre (like the built eggs' EggRoot)
	local root = block(model, "EggRoot", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic,
		{Transparency = 1})
	model.PrimaryPart = root
	return model
end

-- the template: the server keeps it in UIAssets.Eggs (so it reaches every client); a client that has not got it yet
-- builds the very same egg locally
local localFolder
function EggForge.Template(id)
	if type(id) ~= "string" then return nil end
	local assets = ReplicatedStorage:FindFirstChild("PFE") and ReplicatedStorage.PFE:FindFirstChild("UIAssets")
	local folder = assets and assets:FindFirstChild("Eggs")
	local found = folder and folder:FindFirstChild(id)
	if found then return found end
	if not EggForge.IsGen(id) then return nil end
	if templates[id] and templates[id].Parent then return templates[id] end
	local model = EggForge.Build(id)
	if not model then return nil end
	if RunService:IsServer() and folder then
		model.Parent = folder
	else
		if not localFolder then
			localFolder = Instance.new("Folder"); localFolder.Name = "PFE_ForgedEggs"
			localFolder.Parent = ReplicatedStorage
		end
		model.Parent = localFolder
	end
	templates[id] = model
	return model
end

return EggForge
