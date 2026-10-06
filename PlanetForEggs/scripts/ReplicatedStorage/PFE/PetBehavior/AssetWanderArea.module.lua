-- Adapted source StarterPlayer.StarterPlayerScripts.Game.Plots.ActiveAssetsController.AssetWanderArea.luau; original motion and personality constants retained.
local t1 = {
	HalfExtents = function(p1) -- line: 13
		local p1Size = p1.Size

		return math.max(p1Size.X * 0.5 - 1.75, 0.0), (math.max(p1Size.Z * 0.5 - 1.75, 0.0))
	end
}

function t1.ClampedPointToward(p2, vector3: Vector3) -- line: 19
	local v6, v7 = t1.HalfExtents(p2)
	local v8 = p2.CFrame:PointToObjectSpace(vector3)
	local v9 = math.clamp(v8.X, -v6, v6)
	local v10 = math.clamp(v8.Z, -v7, v7)

	return (p2.CFrame * CFrame.new(v9, 0.0, v10)).Position
end
function t1.RandomPoint(p3, p4) -- line: 28
	local v13, v14 = t1.HalfExtents(p3)
	local v15 = p4:NextNumber(-v13, v13)
	local v16 = p4:NextNumber(-v14, v14)

	return (p3.CFrame * CFrame.new(v15, 0.0, v16)).Position
end
function t1.IsPositionInside(p5, vector3: Vector3) -- line: 36
	local v19, v20 = t1.HalfExtents(p5)
	local v21 = p5.CFrame:PointToObjectSpace(vector3)

	return v19 >= math.abs(v21.X) and v20 >= math.abs(v21.Z)
end
function t1.PointNearOwner(p6, vector3: Vector3, vector3_2: Vector3) -- line: 43
	return t1.ClampedPointToward(p6, vector3 + vector3_2)
end

return t1

