-- Adapted source StarterPlayer.StarterPlayerScripts.Game.Plots.ActiveAssetsController.AssetPersonalityMotion.luau; original motion and personality constants retained.
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local Player = {Optional = {PrimaryPart = function(player)
 local character = player and player.Character
 return character and character:FindFirstChild("HumanoidRootPart") or nil
end}}
local AssetWanderArea = require(script.Parent.AssetWanderArea)
local t1 = {}

local function isolatedPointFromOwner(p1, p2, vector3: Vector3) -- line: 22
	local v9, v10 = AssetWanderArea.HalfExtents(p1)
	local v11 = p1.CFrame:PointToObjectSpace(vector3)
	local v12 = if not (v11.X >= 0.0) then p2:NextNumber(0.0, v9) else p2:NextNumber(-v9, 0.0)
	local v13 = if not (v11.Z >= 0.0) then p2:NextNumber(0.0, v10) else p2:NextNumber(-v10, 0.0)

	return (p1.CFrame * CFrame.new(v12, 0.0, v13)).Position
end

function t1.StepIdle(n1: number, n2: number, n3: number, cFrame: CFrame, p3) -- line: 35
	local v19 = math.max(n2 - n1, 0.0)
	local v20 = n3 + n1

	if p3 ~= nil and v19 > 0.0 then
		local v21 = v20 * p3.CyclesPerSecond * 3.141592653589793 * 2.0
		local v22 = math.sin(v21) * p3.Amplitude
		local v23 = math.sin(v21 * 1.37 + 1.0471975511965976) * p3.Amplitude

		cFrame *= CFrame.new(v22, 0.0, v23)
	end

	return cFrame, v19, v20, v19 <= 0.0
end
function t1.ChooseDestination(p4, p5, p6, vector3: Vector3?) -- line: 55
	if vector3 ~= nil and p5:NextNumber() < p6.IsolationPreference then
		return (isolatedPointFromOwner(p4, p5, vector3))
	end

	if vector3 ~= nil and p5:NextNumber() < p6.NearOwnerPreference then
		return AssetWanderArea.ClampedPointToward(p4, vector3)
	end

	return AssetWanderArea.RandomPoint(p4, p5)
end
function t1.RandomOwnerOffset(p7, p8, n4: number) -- line: 71
	local v31 = p8:NextNumber(0.0, 6.283185307179586)
	local vector3 = Vector3.new(math.cos(v31) * n4, 0.0, math.sin(v31) * n4)

	return p7.CFrame:VectorToWorldSpace(vector3)
end
function t1.RollChance(p9, n5: number) -- line: 78
	if n5 <= 0.0 then
		return false
	end

	if n5 >= 1.0 then
		return true
	end

	return n5 >= p9:NextNumber()
end
function t1.RandomConfiguredText(p10, t2: {[any]: any}, p11, s1: string) -- line: 89
	assert(#t2 > 0.0, `Personality { p11 } requires at least one { s1 } text`)

	return t2[p10:NextInteger(1.0, #t2)]
end
function t1.OwnerRootPosition(p12) -- line: 99
	local v40 = Player.Optional.PrimaryPart(p12)

	if v40 ~= nil then
		return v40.Position
	end

	return nil
end
function t1.DistanceFromPlayerToAreaCenter(p13, p14) -- line: 104
	local v43 = t1.OwnerRootPosition(p13)

	if v43 ~= nil then
		return (v43 - p14.Position).Magnitude
	end

	return nil
end
function t1.ShouldStartAmbientJump(p15, n6: number, n7: number, b1: boolean) -- line: 109
	if n6 <= 0.0 or b1 then
		return false
	end

	return 1.0 - math.exp(-n6 * n7) >= p15:NextNumber()
end

return t1

