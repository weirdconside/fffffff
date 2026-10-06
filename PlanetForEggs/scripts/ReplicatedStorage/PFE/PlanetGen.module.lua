--!strict
-- Planet layout generator. The server runs this once per planet and map cycle (seed) and
-- sends the result to clients (they build the decor locally), so every player sees the same
-- forests and the eggs sit exactly inside the hiding spots of that decor. Every seed turns the
-- whole composition (regions, landmarks, groves) so each map cycle looks different.
-- Recipes are authored for a 430-stud planet and scaled to the planet's real radius.
-- v28: the planets are 2800 studs across the radius (5x). Positions scale fully, the AMOUNT of decor only up to
-- DECOR_K (the old full-density scaling would make ~170K models a planet): ~45K models per planet, a bit under
-- half the old density, forests kept as dense groves. Clients never build all of it: PlanetClient streams the
-- chunks (CHUNK studs square) around the player from the server's copy (PlanetGen.PackChunks).
local ContentData = require(script.Parent:WaitForChild("ContentData"))
local PrefabInfo = require(script.Parent:WaitForChild("PrefabInfo"))
local Rng = require(script.Parent:WaitForChild("Rng"))

local PlanetGen = {}

export type Item = {Prefab: string, X: number, Z: number, Rot: number, Scale: number, Solid: boolean, Region: string?}
export type Spot = {Id: number, Kind: string, Position: Vector3, Zone: number, Region: string?}
export type Layout = {Planet: string, Origin: Vector3, Radius: number, Items: {Item}, Spots: {Spot}, Regions: {any}, Seed: number,
	Chunks: {[string]: {number}}, SpotsByZone: {[number]: {Spot}}}

local LANDING_CLEAR = 44
local FILL_SOLID = 14            -- (v29) the fewest trees / rocks in a 192-stud chunk
local FILL_DETAIL = 16           -- ... and bits of grass / pebbles
local CELL = 24
local AUTHORED_RADIUS = 430
local DECOR_K = 4.4            -- the decor count scales like a planet of DECOR_K * 430 studs at most
local OLD_K2 = (560 / 430) ^ 2 -- the v27 count factor (clusters keep its density)
local CHUNK = 192
PlanetGen.Chunk = CHUNK
local ZONE_EDGES = {0.25, 0.45, 0.65, 0.83} -- (Config.ZoneEdges)
local cache: {[string]: Layout} = {}
local seedsOf: {[string]: {number}} = {}     -- the cycles kept per planet (the current one and the next)
local pending: {[string]: boolean} = {}

-- The server sets this to a function that yields now and then (task.wait on a time budget), so
-- generating a planet (~80 ms of work) never stalls the game in one go. Nil = run straight through.
PlanetGen.Yield = nil :: (() -> ())?

local function planetDef(id: string): any
	for _, planet in ipairs(ContentData.Planets) do
		if planet.Id == id then return planet end
	end
	return nil
end

local function footprint(info: any, scale: number): number
	local r = (info.Radius or 4) * scale
	if info.Kind == "Tree" then r *= 0.45 end
	if info.Kind == "Detail" then r *= 0.6 end
	return math.max(0.8, r)
end

function PlanetGen.ZoneOf(distance: number, radius: number?): number
	-- five rings, the rarer (and the fewer) eggs further out (Config.ZoneTierWeights / Config.ZoneShare)
	local share = distance / (radius or AUTHORED_RADIUS)
	for i, edge in ipairs(ZONE_EDGES) do
		if share < edge then return i end
	end
	return #ZONE_EDGES + 1
end

function PlanetGen.ChunkKey(x: number, z: number): string
	return math.floor(x / CHUNK) .. "," .. math.floor(z / CHUNK)
end

function PlanetGen.Generate(planetId: string, seed: number?): Layout?
	local cycle = seed or 0
	local cacheKey = planetId .. ":" .. cycle
	if cache[cacheKey] then return cache[cacheKey] end
	local def = planetDef(planetId)
	if not def then return nil end
	-- someone else is generating this one right now: wait for their result
	if pending[cacheKey] then
		while pending[cacheKey] do task.wait() end
		if cache[cacheKey] then return cache[cacheKey] end
	end
	pending[cacheKey] = true
	local yielder = PlanetGen.Yield
	local steps = 0
	local function step()
		steps += 1
		if yielder and steps % 48 == 0 then yielder() end
	end
	local recipe = ContentData.Recipes and ContentData.Recipes[planetId] or {}
	local origin = Vector3.new(def.Origin[1], def.Origin[2], def.Origin[3])
	local radius = def.Radius or AUTHORED_RADIUS
	local k = radius / AUTHORED_RADIUS
	local countK2 = math.min(k, DECOR_K) ^ 2           -- how many times the authored counts
	local clusterK = math.max(1, countK2 / OLD_K2)     -- how many times the authored groves
	local rng = Rng.new(1000 + (def.Order or 1) * 7919 + cycle * 104729)
	local turn = rng:Range(0, 360) -- the whole composition turns every cycle
	local items: {Item} = {}
	local grid: {[number]: {any}} = {}

	local function key(cx: number, cz: number): number
		return (cx + 512) * 4096 + (cz + 512)
	end
	local function addSolid(x: number, z: number, r: number)
		local cx, cz = math.floor(x / CELL), math.floor(z / CELL)
		local k = key(cx, cz)
		local bucket = grid[k]
		if not bucket then bucket = {}; grid[k] = bucket end
		table.insert(bucket, {x, z, r})
	end
	local function blocked(x: number, z: number, r: number, spacing: number, detail: boolean): boolean
		local reach = math.ceil((r + 30) / CELL)
		local cx, cz = math.floor(x / CELL), math.floor(z / CELL)
		for gx = cx - reach, cx + reach do
			for gz = cz - reach, cz + reach do
				local bucket = grid[key(gx, gz)]
				if bucket then
					for _, s in ipairs(bucket) do
						local dx, dz = s[1] - x, s[2] - z
						local limit = if detail then s[3] * 0.7 + r * 0.3 else (s[3] + r) * spacing * 0.82
						if dx * dx + dz * dz < limit * limit then return true end
					end
				end
			end
		end
		return false
	end
	-- dungeon entrances (the tractor beam pad, the crashed UFO) keep a clearing
	local clearings = {}
	local okConfig, Config = pcall(require, script.Parent:WaitForChild("Config"))
	if okConfig and Config.DungeonClearings then clearings = Config.DungeonClearings(planetId) end
	local function inside(x: number, z: number, r: number): boolean
		local d = math.sqrt(x * x + z * z)
		if not (d + r < radius - 4 and d - r > LANDING_CLEAR) then return false end
		for _, c in ipairs(clearings) do
			local dx, dz = x - c[1], z - c[2]
			if dx * dx + dz * dz < (c[3] + r) * (c[3] + r) then return false end
		end
		return true
	end
	local function place(prefab: string, x: number, z: number, rot: number, scale: number, region: string?, force: boolean?): boolean
		local info = PrefabInfo[prefab]
		if not info then return false end
		local r = footprint(info, scale)
		local detail = info.Kind == "Detail"
		if not force then
			if not inside(x, z, r) then return false end
			if blocked(x, z, r, 1, detail) then return false end
		end
		if not detail then addSolid(x, z, r) end
		table.insert(items, {Prefab = prefab, X = math.round(x * 100) / 100, Z = math.round(z * 100) / 100,
			Rot = math.round(rot), Scale = math.round(scale * 1000) / 1000, Solid = info.Solid ~= false and not detail, Region = region})
		return true
	end

	-- 1. landmarks near their authored spots (turned and jittered per cycle)
	for _, mark in ipairs(recipe.Landmarks or {}) do
		local a = math.rad((mark.Angle or 0) + turn + rng:Range(-35, 35))
		local d = math.max(LANDING_CLEAR + 16, (mark.Dist or 0) * k * rng:Range(0.8, 1.12))
		local x, z = math.cos(a) * d, math.sin(a) * d
		place(mark.Prefab, x, z, rng:Range(0, 360), mark.Scale or 1, mark.Region, true)
	end

	-- 2. regions (groves, fields, ridges)
	local regions = {}
	local groups: {[string]: {any}} = {} -- items with the same Group share their cluster centres (one forest)
	local function fill(item: any, regionName: string?, cx: number, cz: number, rad: number, zone: {number}?)
		local prefabs = item.Prefabs
		local smin, smax = item.Scale and item.Scale[1] or 1, item.Scale and item.Scale[2] or 1
		local spacing = item.Spacing or 1
		local centers = item.Group and groups[item.Group] or {}
		if item.Cluster and #centers == 0 then
			for _ = 1, math.round(item.Cluster[1] * clusterK) do
				local a, d = rng:Range(0, math.pi * 2), math.sqrt(rng:Next()) * rad * 0.78
				if zone then d = math.sqrt(rng:Range(zone[1] * zone[1], zone[2] * zone[2])) end
				table.insert(centers, {cx + math.cos(a) * d, cz + math.sin(a) * d})
			end
			if item.Group then groups[item.Group] = centers end
		end
		-- counts are authored for a 430-stud planet: more on bigger ones (up to DECOR_K, see the top)
		for _ = 1, math.round((item.Count or 0) * countK2) do
			step()
			for _try = 1, 14 do
				local x, z
				if #centers > 0 and item.Cluster and rng:Next() < 0.85 then
					local c = centers[rng:Int(1, #centers)]
					local a, d = rng:Range(0, math.pi * 2), math.sqrt(rng:Next()) * item.Cluster[2]
					x, z = c[1] + math.cos(a) * d, c[2] + math.sin(a) * d
				elseif zone then
					local a = rng:Range(0, math.pi * 2)
					local d = math.sqrt(rng:Range(zone[1] * zone[1], zone[2] * zone[2]))
					x, z = math.cos(a) * d, math.sin(a) * d
				else
					local a, d = rng:Range(0, math.pi * 2), math.sqrt(rng:Next()) * rad
					x, z = cx + math.cos(a) * d, cz + math.sin(a) * d
				end
				local prefab = prefabs[rng:Int(1, #prefabs)]
				local scale = rng:Range(smin, smax)
				local info = PrefabInfo[prefab]
				if info then
					local r = footprint(info, scale)
					local detail = info.Kind == "Detail"
					if inside(x, z, r) and not blocked(x, z, r, spacing, detail) then
						place(prefab, x, z, rng:Range(0, 360), scale, regionName, true)
						break
					end
				end
			end
		end
	end
	local function scaled(zone: {number}?, fallback: {number}): {number}
		local z = zone or fallback
		return {math.max(LANDING_CLEAR + 12, z[1]), math.min(radius, z[2] * k)}
	end
	for _, region in ipairs(recipe.Regions or {}) do
		local a = math.rad((region.Angle or 0) + turn + rng:Range(-25, 25))
		local d = (region.Dist or 0) * k * rng:Range(0.85, 1.1)
		table.insert(regions, {Name = region.Name, X = math.cos(a) * d, Z = math.sin(a) * d, Radius = (region.Radius or 100) * k})
	end
	for index, region in ipairs(recipe.Regions or {}) do
		local r = regions[index]
		for _, item in ipairs(region.Items or {}) do
			if not item.Detail then fill(item, region.Name, r.X, r.Z, r.Radius, nil) end
		end
	end
	for _, item in ipairs(recipe.Scatter or {}) do
		if not item.Detail then fill(item, nil, 0, 0, radius, scaled(item.Zone, {60, AUTHORED_RADIUS})) end
	end
	-- details last so they never block solid decor
	for index, region in ipairs(recipe.Regions or {}) do
		local r = regions[index]
		for _, item in ipairs(region.Items or {}) do
			if item.Detail then fill(item, region.Name, r.X, r.Z, r.Radius, nil) end
		end
	end
	for _, item in ipairs(recipe.Scatter or {}) do
		if item.Detail then fill(item, nil, 0, 0, radius, scaled(item.Zone, {30, AUTHORED_RADIUS})) end
	end

	-- 2b. (v29) no bare patches: every chunk of the map gets at least FILL_SOLID trees / rocks and FILL_DETAIL bits of
	-- grass from the planet's scatter lists (the groves were spread apart when the maps grew 5x)
	do
		local solidsList, detailsList = {}, {}
		for _, item in ipairs(recipe.Scatter or {}) do
			for _, prefab in ipairs(item.Prefabs or {}) do
				if PrefabInfo[prefab] and not string.find(prefab, "Crate", 1, true) then
					table.insert(if item.Detail then detailsList else solidsList, {prefab, item.Scale or {0.8, 1.3}})
				end
			end
		end
		local solidCount, detailCount = {}, {}
		for _, item in ipairs(items) do
			local key = PlanetGen.ChunkKey(item.X, item.Z)
			if item.Solid then solidCount[key] = (solidCount[key] or 0) + 1 else detailCount[key] = (detailCount[key] or 0) + 1 end
		end
		local n = math.ceil(radius / CHUNK)
		for cx = -n, n - 1 do
			for cz = -n, n - 1 do
				local x0, z0 = cx * CHUNK, cz * CHUNK
				local mx, mz = x0 + CHUNK / 2, z0 + CHUNK / 2
				if mx * mx + mz * mz < (radius + CHUNK) ^ 2 then
					local key = cx .. "," .. cz
					for pass = 1, 2 do
						local list = pass == 1 and solidsList or detailsList
						local want = pass == 1 and FILL_SOLID or FILL_DETAIL
						local have = (pass == 1 and solidCount or detailCount)[key] or 0
						local tries = 0
						while #list > 0 and have < want and tries < want * 4 do
							tries += 1
							step()
							local pick = list[rng:Int(1, #list)]
							if place(pick[1], x0 + rng:Range(4, CHUNK - 4), z0 + rng:Range(4, CHUNK - 4), rng:Range(0, 360),
								rng:Range(pick[2][1], pick[2][2])) then
								have += 1
							end
						end
					end
				end
			end
		end
	end

	-- 3. hiding spots from prefab nooks
	local spots: {Spot} = {}
	for _, item in ipairs(items) do
		local info = PrefabInfo[item.Prefab]
		if info and info.Nooks then
			local cf = CFrame.new(item.X, 0, item.Z) * CFrame.Angles(0, math.rad(item.Rot), 0)
			for _, nook in ipairs(info.Nooks) do
				local p = nook.Pos
				local world = cf:PointToWorldSpace(Vector3.new(p[1], p[2], p[3]) * item.Scale)
				local d = math.sqrt(world.X * world.X + world.Z * world.Z)
				if d > LANDING_CLEAR * 0.8 and d < radius - 3 then
					table.insert(spots, {Id = #spots + 1, Kind = nook.Kind or "Egg", Position = origin + world,
						Zone = PlanetGen.ZoneOf(d, radius), Region = item.Region})
				end
			end
		end
	end
	-- the streaming chunks (item indices per CHUNK square) and the hiding spots per distance ring
	local chunks: {[string]: {number}} = {}
	for index, item in ipairs(items) do
		local key = PlanetGen.ChunkKey(item.X, item.Z)
		local list = chunks[key]
		if not list then list = {}; chunks[key] = list end
		table.insert(list, index)
	end
	local byZone: {[number]: {Spot}} = {}
	for _, spot in ipairs(spots) do
		local list = byZone[spot.Zone]
		if not list then list = {}; byZone[spot.Zone] = list end
		table.insert(list, spot)
	end
	local layout: Layout = {Planet = planetId, Origin = origin, Radius = radius, Items = items, Spots = spots, Regions = regions, Seed = cycle,
		Chunks = chunks, SpotsByZone = byZone}
	cache[cacheKey] = layout
	pending[cacheKey] = nil
	-- keep the two newest cycles of each planet (the live one and the one prepared ahead)
	local seeds = seedsOf[planetId] or {}
	seedsOf[planetId] = seeds
	table.insert(seeds, cycle)
	table.sort(seeds)
	while #seeds > 2 do
		local oldest = table.remove(seeds, 1) :: number
		cache[planetId .. ":" .. oldest] = nil
	end
	return layout
end

-- Compact form for RemoteFunction transfer (arrays instead of keyed tables).
function PlanetGen.Pack(layout: Layout): any
	local names, index = {}, {}
	local rows = table.create(#layout.Items)
	for _, item in ipairs(layout.Items) do
		local i = index[item.Prefab]
		if not i then table.insert(names, item.Prefab); i = #names; index[item.Prefab] = i end
		table.insert(rows, {i, item.X, item.Z, item.Rot, item.Scale})
	end
	return {Planet = layout.Planet, Names = names, Rows = rows, Regions = layout.Regions, Seed = layout.Seed}
end

-- the header a client needs before it streams chunks (regions, seed, chunk size)
function PlanetGen.Header(layout: Layout): any
	return {Planet = layout.Planet, Regions = layout.Regions, Seed = layout.Seed, Chunk = CHUNK, Count = #layout.Items}
end

-- the rows of some chunks (keys "cx,cz"), compact for a RemoteFunction: {Names, Chunks = {[key] = rows}}
function PlanetGen.PackChunks(layout: Layout, keys: {string}): any
	local names, index = {}, {}
	local out = {}
	for _, key in ipairs(keys) do
		local list = layout.Chunks[key]
		local rows = {}
		for _, i in ipairs(list or {}) do
			local item = layout.Items[i]
			local n = index[item.Prefab]
			if not n then table.insert(names, item.Prefab); n = #names; index[item.Prefab] = n end
			table.insert(rows, {n, item.X, item.Z, item.Rot, item.Scale})
		end
		out[key] = rows
	end
	return {Names = names, Chunks = out, Seed = layout.Seed}
end

function PlanetGen.Unpack(packed: any): {Item}
	local out = {}
	for _, row in ipairs(packed.Rows or {}) do
		local name = packed.Names[row[1]]
		local info = PrefabInfo[name]
		table.insert(out, {Prefab = name, X = row[2], Z = row[3], Rot = row[4], Scale = row[5],
			Solid = info ~= nil and info.Kind ~= "Detail"})
	end
	return out
end

return PlanetGen
