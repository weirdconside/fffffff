--!strict
-- Floating sky islands above a planet, shared by the server (egg spawns, pickup checks) and the
-- clients (they build and move the islands locally). Everything follows from the planet, the map
-- cycle seed and the server clock, so every player sees the islands in the same place without
-- any replication. Islands drift very slowly along a circle and bob a little.
local Config = require(script.Parent:WaitForChild("Config"))
local Rng = require(script.Parent:WaitForChild("Rng"))

local SkyPaths = {}

export type Island = {Id: number, Model: string, Band: number, CenterX: number, CenterZ: number, Radius: number,
	Height: number, Period: number, Phase: number, Bob: number, Spin: number}

local MODELS = {"SkyIsland_A", "SkyIsland_B", "SkyIsland_C"}
local cache: {[string]: {Island}} = {}

function SkyPaths.Islands(planetId: string, seed: number?): {Island}
	local key = planetId .. ":" .. tostring(seed or 0)
	if cache[key] then return cache[key] end
	local planet = Config.Planets[planetId]
	local list: {Island} = {}
	if not planet then return list end
	local rng = Rng.new(777 + planet.Order * 1009 + (seed or 0) * 7919)
	local radius = planet.Radius or 560
	for band, info in ipairs(Config.SkyIslands.Bands) do
		for _ = 1, info.Count do
			local a = rng:Range(0, math.pi * 2)
			local d = math.sqrt(rng:Range(0.04, 1)) * radius * 0.72
			table.insert(list, {Id = #list + 1, Model = MODELS[rng:Int(1, #MODELS)], Band = band,
				CenterX = math.cos(a) * d, CenterZ = math.sin(a) * d, Radius = rng:Range(24, 70),
				Height = rng:Range(info.Min, info.Max), Period = rng:Range(160, 320) * (rng:Next() < 0.5 and -1 or 1),
				Phase = rng:Range(0, math.pi * 2), Bob = rng:Range(1.2, 3), Spin = rng:Range(-0.02, 0.02)})
		end
	end
	cache[key] = list
	return list
end

-- island pivot (top-surface centre) relative to the planet origin at server time t
function SkyPaths.Offset(island: Island, t: number): CFrame
	local angle = island.Phase + t * math.pi * 2 / island.Period
	local x = island.CenterX + math.cos(angle) * island.Radius
	local z = island.CenterZ + math.sin(angle) * island.Radius
	local y = island.Height + math.sin(t * 0.45 + island.Phase) * island.Bob
	return CFrame.new(x, y, z) * CFrame.Angles(0, island.Phase + t * island.Spin, 0)
end

-- linear velocity of the island at time t (studs/s), used to carry players standing on it
function SkyPaths.Velocity(island: Island, t: number): Vector3
	local w = math.pi * 2 / island.Period
	local angle = island.Phase + t * w
	return Vector3.new(-math.sin(angle) * island.Radius * w, math.cos(t * 0.45 + island.Phase) * island.Bob * 0.45,
		math.cos(angle) * island.Radius * w)
end

function SkyPaths.EggPoint(planetId: string, island: Island, t: number): Vector3
	local planet = Config.Planets[planetId]
	return planet.Origin + SkyPaths.Offset(island, t).Position + Vector3.new(0, 0.05, 0)
end

return SkyPaths
