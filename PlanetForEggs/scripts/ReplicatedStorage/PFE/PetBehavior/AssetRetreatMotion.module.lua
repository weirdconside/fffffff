-- Adapted source StarterPlayer.StarterPlayerScripts.Game.Plots.ActiveAssetsController.AssetRetreatMotion.luau; original motion and personality constants retained.
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local AssetWanderArea = require(script.Parent.AssetWanderArea)
local v3 = table.freeze({
	0.0,
	0.6108652381980153,
	-0.6108652381980153,
	1.2217304763960306,
	-1.2217304763960306,
	1.8325957145940461,
	-1.8325957145940461,
	2.443460952792061,
	-2.443460952792061,
	3.141592653589793
})
local t1 = {}

local function rotateLocalFlatDirection(vector3: Vector3, n1: number) -- line: 35
	local v10 = math.cos(n1)
	local v11 = math.sin(n1)

	return (Vector3.new(vector3.X * v10 - vector3.Z * v11, 0.0, vector3.X * v11 + vector3.Z * v10))
end
local function distanceToAreaEdge(p1, vector3: Vector3, vector3_2: Vector3) -- line: 41
	local v15, v16 = AssetWanderArea.HalfExtents(p1)
	local n2 = 1e999
	local n3 = 1e999

	if vector3_2.X > 0.0 then
		n2 = (v15 - vector3.X) / vector3_2.X
	elseif vector3_2.X < 0.0 then
		n2 = (-v15 - vector3.X) / vector3_2.X
	end

	if vector3_2.Z > 0.0 then
		n3 = (v16 - vector3.Z) / vector3_2.Z
	elseif vector3_2.Z < 0.0 then
		n3 = (-v16 - vector3.Z) / vector3_2.Z
	end

	return (math.max(math.min(n2, n3) - 2.0, 0.0))
end
local function ownerAwayDirection(p2, vector3: Vector3, vector3_3: Vector3) -- line: 60
	local vector3_4 = Vector3.new(vector3_3.X - vector3.X, 0.0, vector3_3.Z - vector3.Z)

	if vector3_4.Magnitude > 0.0 then
		return vector3_4.Unit
	end

	local vector3_5 = Vector3.new(vector3_3.X - p2.Position.X, 0.0, vector3_3.Z - p2.Position.Z)

	if vector3_5.Magnitude > 0.0 then
		return vector3_5.Unit
	end

	local LookVector = p2.CFrame.LookVector
	local vector3_6 = Vector3.new(LookVector.X, 0.0, LookVector.Z)

	assert(vector3_6.Magnitude > 0.0, "Asset area must provide a horizontal retreat direction")

	return vector3_6.Unit
end

function t1.Destination(p3, p4, p5, vector3: Vector3, vector3_7: Vector3) -- line: 81
	local v31 = p3.CFrame:PointToObjectSpace(vector3_7)
	local v32 = ownerAwayDirection(p3, vector3, vector3_7)
	local v33 = p3.CFrame:VectorToObjectSpace(v32)
	local vector3_8 = Vector3.new(v33.X, 0.0, v33.Z)

	assert(vector3_8.Magnitude > 0.0, "Retreat direction must be horizontal")

	local Unit = vector3_8.Unit
	local v36 = Unit
	local n4 = 0.0
	local n5 = -1e999

	for _, v in ipairs(v3) do
		local v41 = math.cos(v)
		local v42 = math.sin(v)
		local Unit2 = Vector3.new(Unit.X * v41 - Unit.Z * v42, 0.0, Unit.X * v42 + Unit.Z * v41).Unit
		local v44 = distanceToAreaEdge(p3, v31, Unit2)
		local v45 = v44 * (math.max(Unit2:Dot(Unit), 0.0) + 0.6)

		if n5 < v45 then
			n5 = v45
			n4 = v44
			v36 = Unit2
		end
	end

	if n4 <= 0.0 then
		return AssetWanderArea.RandomPoint(p3, p4)
	end

	local v46 = v31 + v36 * if p5.MaxTravelDistance == nil then n4 else math.min(p5.MaxTravelDistance, n4)

	return (p3.CFrame * CFrame.new(v46.X, 0.0, v46.Z)).Position
end

return t1

