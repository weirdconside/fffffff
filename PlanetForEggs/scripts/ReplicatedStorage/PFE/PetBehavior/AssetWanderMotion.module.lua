-- Adapted source StarterPlayer.StarterPlayerScripts.Game.Plots.ActiveAssetsController.AssetWanderMotion.luau; original motion and personality constants retained.
local AssetWanderArea = require(script.Parent.AssetWanderArea)
local t1 = {
	YawFromFlatDirection = function(vector3: Vector3) -- line: 18
		return (math.atan2(-vector3.X, -vector3.Z))
	end,
	ShortestYawDelta = function(n1: number, n2: number) -- line: 22
		local v6 = n2 - n1

		return (math.atan2(math.sin(v6), (math.cos(v6))))
	end
}

function t1.StepYawToward(n3: number, n4: number, n5: number) -- line: 28
	local v10 = t1.ShortestYawDelta(n3, n4)
	local v11 = n5 * 3.839724354387525
	local v12 = math.clamp(v10, -v11, v11)

	return n3 + v12, v12
end
function t1.StepMoveToward(n6: number, cFrame: CFrame, vector3: Vector3, n7: number) -- line: 36
	local cFramePosition = cFrame.Position
	local v18 = vector3 - cFramePosition
	local vector3_2 = Vector3.new(v18.X, 0.0, v18.Z)
	local Magnitude = vector3_2.Magnitude

	if Magnitude <= 0.0 then
		return cFrame, false, 0.0
	end

	local v21 = math.min(Magnitude, n7 * n6)
	local Unit = vector3_2.Unit
	local LookVector = cFrame.LookVector
	local vector3_3 = Vector3.new(LookVector.X, 0.0, LookVector.Z)
	local v25 = if not (vector3_3.Magnitude > 0.0) then Unit else vector3_3.Unit
	local v26 = t1.YawFromFlatDirection(v25)
	local v27 = t1.YawFromFlatDirection(Unit)
	local v28, v29 = t1.StepYawToward(v26, v27, n6)
	local v30 = math.clamp((math.cos((math.abs((t1.ShortestYawDelta(v28, v27))))) - 0.2) / 0.8, 0.0, 1.0)
	local v31 = cFramePosition + Unit * v21 * v30

	return CFrame.new(v31) * CFrame.Angles(0.0, v28, 0.0), v30 > 0.0 or math.abs(v29) > 0.008726646259971648, n7 * v30
end
function t1.FaceOwnerCFrame(cFrame: CFrame, vector3: Vector3, n8: number, b1: boolean?) -- line: 69
	local cFramePosition = cFrame.Position
	local vector3_4 = Vector3.new(vector3.X - cFramePosition.X, 0.0, vector3.Z - cFramePosition.Z)

	if vector3_4.Magnitude <= 0.0 then
		return cFrame
	end

	local LookVector = cFrame.LookVector
	local vector3_5 = Vector3.new(LookVector.X, 0.0, LookVector.Z)

	assert(vector3_5.Magnitude > 0.0, "Asset wander CFrame must have a horizontal facing direction")

	local v40 = t1.YawFromFlatDirection(vector3_5.Unit)
	local v41 = t1.YawFromFlatDirection(vector3_4.Unit)
	local v42 = if b1 ~= true then t1.StepYawToward(v40, v41, n8) else v41

	return CFrame.new(cFramePosition) * CFrame.Angles(0.0, v42, 0.0)
end
function t1.StepFollowOwner(p1, n9: number, cFrame: CFrame, vector3: Vector3, vector3_6: Vector3, n10: number, n11: number) -- line: 92
	local v50 = AssetWanderArea.PointNearOwner(p1, vector3, vector3_6)
	local v51, v52, v53 = t1.StepMoveToward(n9, cFrame, v50, n10)

	if n11 >= Vector3.new(v50.X - v51.Position.X, 0.0, v50.Z - v51.Position.Z).Magnitude then
		v51 = t1.FaceOwnerCFrame(v51, vector3, n9)
	end

	return v51, v52, v53
end
function t1.OwnerMoveVector(n12: number, vector3: Vector3?, vector3_7: Vector3?) -- line: 111
	if vector3 == nil then
		return Vector3.new(0.0, 0.0, 0.0), nil
	end

	if vector3_7 == nil or n12 <= 0.0 then
		return Vector3.new(0.0, 0.0, 0.0), vector3
	end

	local v57 = vector3 - vector3_7

	return Vector3.new(v57.X, 0.0, v57.Z) / n12, vector3
end
function t1.OrbitGreetingCFrame(p2, n13: number, cFrame: CFrame, vector3: Vector3, vector3_8: Vector3, n14: number, n15: number, n16: number) -- line: 127
	local cFramePosition = cFrame.Position
	local vector3_9 = Vector3.new(cFramePosition.X - vector3.X, 0.0, cFramePosition.Z - vector3.Z)
	local Unit

	if vector3_9.Magnitude == 0.0 then
		local LookVector = p2.CFrame.LookVector
		local vector3_10 = Vector3.new(LookVector.X, 0.0, LookVector.Z)

		assert(vector3_10.Magnitude > 0.0, "Asset area must provide a horizontal orbit greeting direction")
		Unit = vector3_10.Unit
	else
		local Unit2 = vector3_9.Unit

		Unit = (Vector3.new(-Unit2.Z, 0.0, Unit2.X) + Unit2 * math.clamp((n14 - vector3_9.Magnitude) / n14, -n16, n16)).Unit
	end

	local v72 = Unit * n15 + vector3_8
	local vector3_11 = Vector3.new(v72.X, 0.0, v72.Z)
	local Magnitude = v72.Magnitude

	if vector3_11.Magnitude <= 0.0 then
		return cFrame, false, 0.0
	end

	local v75 = AssetWanderArea.ClampedPointToward(p2, cFramePosition + v72 * n13)
	local vector3_12 = Vector3.new(v75.X - cFramePosition.X, 0.0, v75.Z - cFramePosition.Z)

	if vector3_12.Magnitude <= 0.0 then
		return cFrame, false, 0.0
	end

	local v77 = t1.YawFromFlatDirection(vector3_12.Unit)

	return CFrame.new(v75) * CFrame.Angles(0.0, v77, 0.0), true, Magnitude
end

return t1

