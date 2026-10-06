--!nocheck
-- (v35) Where a bot can walk.
--  * The island: PathfindingService routes (round the pens' fences, through their gates, past the decor), so a bot
--    never walks off the edge or into a wall.
--  * The planets: their trees, rocks and landmarks are built on every client (PlanetClient streams them) and players
--    collide with them - the server has only the flat ground. Every solid piece of the planet's layout (PlanetGen,
--    the same seed the clients build from) goes into a grid of circles, and bots steer round them like players do,
--    instead of walking through trees on everyone's screen.
--  * Ground checks for the kill plane and for the end of a lag spike.
local Nav = {}
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ctx, Config, PrefabInfo
local CELL = 24
local grids = {}       -- "planet:seed" -> {Cells, Origin, Radius}
local gridOrder = {}

function Nav.Init(context)
	ctx = context
	Config = ctx.Config
	local ok, info = pcall(function() return require(ReplicatedStorage:WaitForChild("PFE"):WaitForChild("PrefabInfo")) end)
	PrefabInfo = ok and info or {}
end

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- ---------------------------------------------------------------- the island
local agent = {AgentRadius = 2.2, AgentHeight = 5.4, AgentCanJump = true, AgentCanClimb = false, WaypointSpacing = 5}
function Nav.IslandPath(from, to)
	local ok, path = pcall(function()
		local p = PathfindingService:CreatePath(agent)
		p:ComputeAsync(from, to)
		return p
	end)
	if not ok or not path then return nil end
	local okStatus, status = pcall(function() return path.Status end)
	if not okStatus or status ~= Enum.PathStatus.Success then return nil end
	local okList, list = pcall(function() return path:GetWaypoints() end)
	if not okList or type(list) ~= "table" or #list == 0 then return nil end
	local out = {}
	for _, w in ipairs(list) do
		table.insert(out, {Position = w.Position, Jump = w.Action == Enum.PathWaypointAction.Jump})
	end
	return out
end

-- ---------------------------------------------------------------- planets: the solid decor every client collides with
local function footprint(info, scale)
	local r = (info.Radius or 4) * scale
	if info.Kind == "Tree" then r *= 0.45 end
	return math.max(0.8, r)
end
-- (built in the background, a slice at a time: the steering goes straight until it's ready)
local building, failed = {}, {}
function Nav.PlanetGrid(planetId)
	if not ctx or not ctx.PlanetGen or not Config.Planets[planetId] then return nil end
	local seed = ctx.mapSeed and ctx.mapSeed() or 0
	local key = planetId .. ":" .. seed
	local grid = grids[key]
	if grid then return grid end
	if building[key] then return nil end
	if failed[key] and os.clock() - failed[key] < 10 then return nil end
	building[key] = true
	task.spawn(function()
		local ok, layout = pcall(ctx.PlanetGen.Generate, planetId, seed)
		if ok and layout then
			local made = {Cells = {}, Origin = layout.Origin, Radius = layout.Radius, Planet = planetId}
			for index, item in ipairs(layout.Items) do
				local info = PrefabInfo[item.Prefab]
				if item.Solid and info then
					local r = math.clamp(footprint(info, item.Scale or 1) * 0.85, 0.8, 16)
					local x, z = layout.Origin.X + item.X, layout.Origin.Z + item.Z
					local k = math.floor(x / CELL) .. ":" .. math.floor(z / CELL)
					local cell = made.Cells[k]
					if not cell then cell = {}; made.Cells[k] = cell end
					table.insert(cell, {x, z, r})
				end
				if index % 4000 == 0 then task.wait() end
			end
			grids[key] = made
			table.insert(gridOrder, key)
			while #gridOrder > 6 do grids[table.remove(gridOrder, 1)] = nil end
		else
			failed[key] = os.clock()
		end
		building[key] = nil
	end)
	return nil
end

-- does the walk from p along dir for `length` studs hit a solid (circles grown by `radius`)? returns the distance
local function hit(grid, p, dir, length, radius)
	local best
	local x0, z0 = p.X, p.Z
	local dx, dz = dir.X, dir.Z
	local minX, maxX = math.min(x0, x0 + dx * length) - 18, math.max(x0, x0 + dx * length) + 18
	local minZ, maxZ = math.min(z0, z0 + dz * length) - 18, math.max(z0, z0 + dz * length) + 18
	for cx = math.floor(minX / CELL), math.floor(maxX / CELL) do
		for cz = math.floor(minZ / CELL), math.floor(maxZ / CELL) do
			local cell = grid.Cells[cx .. ":" .. cz]
			if cell then
				for _, s in ipairs(cell) do
					local ox, oz = s[1] - x0, s[2] - z0
					local t = ox * dx + oz * dz
					local r = s[3] + radius
					if t > -r and t < length + r then
						local tc = math.clamp(t, 0, length)
						local mx, mz = ox - dx * tc, oz - dz * tc
						if mx * mx + mz * mz < r * r then
							local d = math.max(0, t - math.sqrt(math.max(0, r * r - (ox * ox + oz * oz - t * t))))
							if not best or d < best then best = d end
						end
					end
				end
			end
		end
	end
	return best
end
Nav.Hit = hit

-- inside a solid right now? (a bot that spawned or was knocked into a tree steps out)
function Nav.Inside(planetId, p, radius)
	local grid = Nav.PlanetGrid(planetId)
	if not grid then return false end
	local cell = grid.Cells[math.floor(p.X / CELL) .. ":" .. math.floor(p.Z / CELL)]
	for _, s in ipairs(cell or {}) do
		local dx, dz = p.X - s[1], p.Z - s[2]
		if dx * dx + dz * dz < (s[3] + radius) ^ 2 then return true, Vector3.new(dx, 0, dz) end
	end
	return false
end

-- steer round the planet's solids: the heading closest to `dir` whose next `look` studs are clear, on the side it took
-- last time (no dithering left-right in front of a trunk). Returns the direction and the side used (-1 / 1 / 0).
local OFFSETS = {0, 18, -18, 36, -36, 54, -54, 72, -72, 95, -95, 125, -125}
function Nav.Steer(planetId, p, dir, look, side, radius)
	local grid = Nav.PlanetGrid(planetId)
	if not grid or dir.Magnitude < 0.01 then return dir, 0 end
	radius = radius or 1.8
	local unit = flat(dir).Unit
	if not hit(grid, p, unit, look, radius) then return unit, 0 end
	for _, deg in ipairs(OFFSETS) do
		local s = deg == 0 and 0 or (deg > 0 and 1 or -1)
		local a = math.rad(math.abs(deg)) * ((side ~= 0 and side or 1) * (s ~= 0 and s or 1))
		local c, sn = math.cos(a), math.sin(a)
		local candidate = Vector3.new(unit.X * c - unit.Z * sn, 0, unit.X * sn + unit.Z * c)
		if not hit(grid, p, candidate, look, radius) then return candidate, (a > 0 and 1 or a < 0 and -1 or 0) end
	end
	return unit, side
end

-- a free spot on the planet near `near` (not inside decor, inside the map)
function Nav.PlanetSpot(planetId, near, minR, maxR)
	local planet = Config.Planets[planetId]
	if not planet then return near end
	local grid = Nav.PlanetGrid(planetId)
	local origin, radius = planet.Origin, (grid and grid.Radius) or planet.Radius or 500
	for _ = 1, 24 do
		local a = math.random() * math.pi * 2
		local d = minR + math.random() * (maxR - minR)
		local p = near + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local fromCentre = flat(p - origin).Magnitude
		if fromCentre < radius - 30 and not Nav.Inside(planetId, p, 3) then return Vector3.new(p.X, near.Y, p.Z) end
	end
	return near
end

-- ---------------------------------------------------------------- ground
local params
function Nav.Ground(position, depth, ignore)
	if not params then params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.RespectCanCollide = true end
	params.FilterDescendantsInstances = ignore or {}
	local ok, result = pcall(function() return workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -(depth or 20) - 3, 0), params) end)
	return ok and result or nil
end
-- is the way from a to b clear at waist height (for a lag spike's catch-up jump)
function Nav.Clear(a, b, ignore)
	if not params then params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.RespectCanCollide = true end
	params.FilterDescendantsInstances = ignore or {}
	local d = b - a
	if d.Magnitude < 0.1 then return true end
	local ok, result = pcall(function() return workspace:Raycast(a, d, params) end)
	return ok and result == nil
end

return Nav
