-- Adapted source StarterPlayer.StarterPlayerScripts.Game.Plots.ActiveAssetsController.AssetWanderSimulator.luau; original motion and personality constants retained.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetItem = {AssetItemData = function(item) return type(item) == "table" and type(item.Personality) == "string" end}
local Personalities = require(script.Parent.Personalities)




local AssetMutationWalkSpeed = require(script.Parent.AssetMutationWalkSpeed)
local AssetPersonalityMotion = require(script.Parent.AssetPersonalityMotion)
local AssetWanderArea = require(script.Parent.AssetWanderArea)
local AssetWanderMotion = require(script.Parent.AssetWanderMotion)
local AssetRetreatMotion = require(script.Parent.AssetRetreatMotion)

local t1 = {}

t1.__index = t1
t1.__class = "AssetWanderSimulator"

function t1.new(n1: number, p1, p2, p3, b1: boolean, n2: number, n3: number) -- line: 114
	assert(AssetItem.AssetItemData(p3), "Invalid asset item data")

	local random = Random.new(n1)
	local LocalPlayer = Players.LocalPlayer

	assert(LocalPlayer ~= nil, "Asset wander simulator requires a local player")

	local v23 = Personalities.GetConfig(p3.Personality)
	local self = setmetatable({}, t1)

	self._random = random
	self._owner = p1
	self._localPlayer = LocalPlayer
	self._assetArea = p2
	self._itemData = p3
	self._config = v23
	self._greetingOrbitRadius = math.max(n2, 2.5)
	self._jumpHeight = math.min(math.max(n3, 1.0) * 2.0, 20.0)
	self._destination = p2.Position
	self._idleRemaining = 0.0
	self._idleAnchorCFrame = nil
	self._idleElapsed = 0.0
	self._walkSpeed = self:_rollWalkSpeed()
	self._mode = "Destination"
	self._phase = "Normal"
	self._greetRemaining = 0.0
	self._randomOrbitInsideSeconds = 0.0
	self._farSeconds = 0.0
	self._farRequiredSeconds = random:NextNumber(105.0, 180.0)
	self._joinGreetingPending = true
	self._finishJumpsRemaining = 0.0
	self._finishJumpCooldown = 0.0
	self._returnGreetingHoldRemaining = 0.0
	self._returnGreetingJumpsRemaining = 0.0
	self._returnGreetingJumpCooldown = 0.0
	self._returnGreetingOwnerOffset = nil
	self._affectionInsideSeconds = 0.0
	self._affectionHoldRemaining = 0.0
	self._affectionJumpsRemaining = 0.0
	self._affectionJumpCooldown = 0.0
	self._affectionOwnerOffset = nil
	self._loyalOwnerOffset = AssetPersonalityMotion.RandomOwnerOffset(p2, random, self._greetingOrbitRadius)
	self._pendingBubbleText = nil
	self._jumpRemaining = 0.0
	self._jumpElapsed = 0.0
	self._spinYaw = 0.0
	self._spinAppliedYaw = 0.0
	self._curveAngle = random:NextNumber(-3.141592653589793, 3.141592653589793)
	self._curveRotationSpeed = random:NextNumber(-0.8, 0.8)
	self._nextCurveChangeSeconds = random:NextNumber(5.0, 10.0)
	self._curveChangeElapsed = 0.0
	self._retreatOwnerWasClose = false
	self._retreatActive = false
	self._lastOwnerPosition = nil
	self:_chooseNextDestination()

	if b1 then
		self:_tryStartFirstPlacementGreeting()
	end


	return self
end
function t1._rollWalkSpeed(p4) -- line: 197
	local Movement = p4._config.Movement

	return math.max(p4._random:NextNumber(Movement.WalkSpeedMin, Movement.WalkSpeedMax), 4.5) * AssetMutationWalkSpeed.GetMultiplier(p4._itemData)
end
function t1._ownerRootPosition(p5) -- line: 204
	return AssetPersonalityMotion.OwnerRootPosition(p5._owner)
end
function t1._distanceFromLocalPlayerToAreaCenter(p6) -- line: 208
	return AssetPersonalityMotion.DistanceFromPlayerToAreaCenter(p6._localPlayer, p6._assetArea)
end
function t1._chooseNextDestination(p7) -- line: 212
	local v30 = p7:_ownerRootPosition()
	local Movement = p7._config.Movement

	p7._walkSpeed = p7:_rollWalkSpeed()
	p7._destination = AssetPersonalityMotion.ChooseDestination(p7._assetArea, p7._random, Movement, v30)
	p7._mode = not (p7._random:NextNumber() < Movement.CurvedWanderChance) and "Destination" or "Curve"
end
function t1._tryRetreatFromOwner(p8, vector3: Vector3, vector3_2: Vector3) -- line: 222
	local Retreat = p8._config.Movement.Retreat

	if Retreat == nil then
		p8._retreatOwnerWasClose = false
		p8._retreatActive = false

		return false
	end

	if not (Vector3.new(vector3.X - vector3_2.X, 0.0, vector3.Z - vector3_2.Z).Magnitude <= Retreat.TriggerDistance) then
		p8._retreatOwnerWasClose = false
		p8._retreatActive = false

		return false
	end

	if p8._retreatActive then
		p8._destination = AssetRetreatMotion.Destination(p8._assetArea, p8._random, Retreat, vector3_2, vector3)
		p8._mode = "Destination"
		p8._idleRemaining = 0.0
		p8._idleAnchorCFrame = nil

		return true
	end

	if p8._retreatOwnerWasClose then
		return false
	end

	p8._retreatOwnerWasClose = true

	if not AssetPersonalityMotion.RollChance(p8._random, Retreat.Chance) then
		return false
	end

	p8._retreatActive = true
	p8._destination = AssetRetreatMotion.Destination(p8._assetArea, p8._random, Retreat, vector3_2, vector3)
	p8._mode = "Destination"
	p8._idleRemaining = 0.0
	p8._idleAnchorCFrame = nil
	p8._walkSpeed = p8:_rollWalkSpeed()

	return true
end
function t1._beginIdle(p9, cFrame: CFrame) -- line: 269
	local Movement = p9._config.Movement

	p9._idleRemaining = p9._random:NextNumber(Movement.IdleSecondsMin, Movement.IdleSecondsMax)
	p9._idleAnchorCFrame = cFrame
	p9._idleElapsed = 0.0
end
function t1._stepIdle(p10, n4: number) -- line: 276
	local _idleAnchorCFrame = p10._idleAnchorCFrame

	assert(_idleAnchorCFrame ~= nil, "Idle phase requires a stable anchor CFrame")

	local v42, v43, v44, v45 = AssetPersonalityMotion.StepIdle(n4, p10._idleRemaining, p10._idleElapsed, _idleAnchorCFrame, p10._config.Movement.IdleTremble)

	p10._idleRemaining = v43
	p10._idleElapsed = v44

	if v45 then
		p10._idleAnchorCFrame = nil
		p10._idleElapsed = 0.0
	end

	return p10:_applyJump(n4, v42)
end
function t1._tryAmbientJump(p11, n5: number) -- line: 296
	local Movement = p11._config.Movement

	if AssetPersonalityMotion.ShouldStartAmbientJump(p11._random, Movement.AmbientJumpRatePerSecond, n5, p11._jumpRemaining > 0.0) then
		p11:_startJump(Movement.AmbientSpinJumpChance)
	end
end
function t1._startJump(p12, n6: number?) -- line: 310
	if p12._jumpRemaining > 0.0 then
		return
	end

	local v51 = if n6 == nil then p12._config.Greeting.SpinJumpChance else n6

	p12._jumpRemaining = 0.45
	p12._jumpElapsed = 0.0
	p12._spinAppliedYaw = 0.0

	local v52 = not (p12._random:NextNumber() < 0.5) and 1.0 or -1.0

	p12._spinYaw = not (v51 > p12._random:NextNumber()) and 0.0 or 6.283185307179586 * v52
end
function t1._resetGreetingFinish(p13) -- line: 323
	p13._finishJumpsRemaining = 0.0
	p13._finishJumpCooldown = 0.0
end
function t1._resetReturnGreeting(p14) -- line: 328
	p14._returnGreetingHoldRemaining = 0.0
	p14._returnGreetingJumpsRemaining = 0.0
	p14._returnGreetingJumpCooldown = 0.0
	p14._returnGreetingOwnerOffset = nil
end
function t1._resetAffection(p15) -- line: 335
	p15._affectionHoldRemaining = 0.0
	p15._affectionJumpsRemaining = 0.0
	p15._affectionJumpCooldown = 0.0
	p15._affectionOwnerOffset = nil
	p15._pendingBubbleText = nil
end
function t1._popBubbleText(p16) -- line: 343
	local _pendingBubbleText = p16._pendingBubbleText

	p16._pendingBubbleText = nil

	return _pendingBubbleText
end
function t1._beginGreetingFinish(p17) -- line: 350
	p17._phase = "GreetingFinish"
	p17._greetRemaining = 1.2
	p17._finishJumpsRemaining = 2.0
	p17._finishJumpCooldown = 0.0
	p17._lastOwnerPosition = nil
end
function t1._beginGreetingOrbit(p18, b2: boolean) -- line: 358

	local Greeting = p18._config.Greeting

	p18._phase = "GreetingOrbit"
	p18._greetRemaining = math.min(Greeting.DurationSeconds, 3.0)
	p18._randomOrbitInsideSeconds = 0.0
	p18._idleRemaining = 0.0
	p18._lastOwnerPosition = nil
	p18:_resetGreetingFinish()
	p18:_resetReturnGreeting()
	p18:_resetAffection()

	if b2 then
		p18._pendingBubbleText = AssetPersonalityMotion.RandomConfiguredText(p18._random, Greeting.Texts, p18._config._id, "greeting")
	end
end
function t1._tryStartGreetingOrbit(p19, n7: number, b3: boolean) -- line: 376

	local Greeting = p19._config.Greeting

	if n7 <= 0.0 or Greeting.DurationSeconds <= 0.0 then
		return false
	end

	if not AssetPersonalityMotion.RollChance(p19._random, n7) then
		return false
	end

	p19:_beginGreetingOrbit(b3)

	return true
end
function t1._beginNormalGreeting(p20, vector3: Vector3, n8: number, n9: number, b4: boolean) -- line: 393

	local v71 = AssetPersonalityMotion.RandomOwnerOffset(p20._assetArea, p20._random, p20._greetingOrbitRadius)

	p20._phase = "ReturnGreetingApproach"
	p20._returnGreetingOwnerOffset = v71
	p20._returnGreetingHoldRemaining = math.min(n9, 20.0)
	p20._returnGreetingJumpsRemaining = n8
	p20._returnGreetingJumpCooldown = 0.0
	p20._destination = AssetWanderArea.PointNearOwner(p20._assetArea, vector3, v71)
	p20._idleRemaining = 0.0
	p20._walkSpeed = p20:_rollWalkSpeed()
	p20._lastOwnerPosition = nil
	p20:_resetGreetingFinish()
	p20:_resetAffection()

	if b4 then
		p20._pendingBubbleText = AssetPersonalityMotion.RandomConfiguredText(p20._random, p20._config.Greeting.Texts, p20._config._id, "greeting")
	end
end
function t1._tryStartFirstPlacementGreeting(p21) -- line: 426
	p21._joinGreetingPending = false

	local Greeting = p21._config.Greeting

	if p21:_tryStartGreetingOrbit(Greeting.FirstPlacementChance, true) then
		return
	end

	local FirstPlacementBubbleChance = Greeting.FirstPlacementBubbleChance

	if FirstPlacementBubbleChance ~= nil and FirstPlacementBubbleChance > 0.0 and AssetPersonalityMotion.RollChance(p21._random, FirstPlacementBubbleChance) then
		p21._pendingBubbleText = AssetPersonalityMotion.RandomConfiguredText(p21._random, Greeting.Texts, p21._config._id, "greeting")

		return
	end

	local v75 = p21:_ownerRootPosition()

	if v75 == nil or not AssetPersonalityMotion.RollChance(p21._random, Greeting.FirstPlacementNormalChance) then
		return
	end

	local FirstPlacementNormalJumpCount = Greeting.FirstPlacementNormalJumpCount

	if FirstPlacementNormalJumpCount <= 0.0 then
		return
	end

	p21:_beginNormalGreeting(v75, FirstPlacementNormalJumpCount, 0.6 * FirstPlacementNormalJumpCount, true)
end
function t1._tryStartReturnGreeting(p22, vector3: Vector3, b5: boolean) -- line: 454

	local Greeting = p22._config.Greeting

	if Greeting.Chance <= 0.0 or Greeting.DurationSeconds <= 0.0 then
		return
	end

	if not AssetPersonalityMotion.RollChance(p22._random, Greeting.Chance) then
		return
	end

	if b5 and p22:_tryStartGreetingOrbit(Greeting.ReturnOrbitChance, false) then
		return
	end

	p22:_beginNormalGreeting(vector3, Greeting.ReturnNormalJumpCount, math.min(Greeting.DurationSeconds, 20.0), false)
end
function t1._beginAffection(p23, vector3: Vector3) -- line: 479
	local Affection = p23._config.Affection
	local v84 = AssetPersonalityMotion.RandomOwnerOffset(p23._assetArea, p23._random, p23._greetingOrbitRadius)

	p23._phase = "AffectionApproach"
	p23._affectionOwnerOffset = v84
	p23._destination = AssetWanderArea.PointNearOwner(p23._assetArea, vector3, v84)
	p23._idleRemaining = 0.0
	p23._walkSpeed = p23:_rollWalkSpeed()
	p23._affectionHoldRemaining = Affection.DurationSeconds
	p23._affectionJumpsRemaining = Affection.JumpCount
	p23._affectionJumpCooldown = 0.0
	p23._pendingBubbleText = nil
	p23._lastOwnerPosition = nil
	p23:_resetGreetingFinish()
end
function t1._updateAffectionTrigger(p24, n10: number, vector3: Vector3?) -- line: 497
	if p24._phase ~= "Normal" then
		return
	end

	local Affection = p24._config.Affection

	if not Affection.Enabled or Affection.IntervalSeconds <= 0.0 or vector3 == nil then
		p24._affectionInsideSeconds = 0.0

		return
	end

	if not AssetWanderArea.IsPositionInside(p24._assetArea, vector3) then
		p24._affectionInsideSeconds = 0.0

		return
	end

	p24._affectionInsideSeconds = p24._affectionInsideSeconds + n10

	if p24._affectionInsideSeconds < Affection.IntervalSeconds then
		return
	end

	p24._affectionInsideSeconds = 0.0

	if AssetPersonalityMotion.RollChance(p24._random, Affection.Chance) then
		p24:_beginAffection(vector3)
	end
end
function t1._updateOrbitGreetingTrigger(p25, n11: number, vector3: Vector3?) -- line: 528
	if p25._phase ~= "Normal" then
		return
	end

	local Greeting = p25._config.Greeting

	if Greeting.RandomOrbitChance <= 0.0 or Greeting.RandomOrbitIntervalSeconds <= 0.0 or Greeting.DurationSeconds <= 0.0 or vector3 == nil then
		p25._randomOrbitInsideSeconds = 0.0

		return
	end

	if not AssetWanderArea.IsPositionInside(p25._assetArea, vector3) then
		p25._randomOrbitInsideSeconds = 0.0

		return
	end

	p25._randomOrbitInsideSeconds = p25._randomOrbitInsideSeconds + n11

	if p25._randomOrbitInsideSeconds < Greeting.RandomOrbitIntervalSeconds then
		return
	end

	p25._randomOrbitInsideSeconds = 0.0
	p25:_tryStartGreetingOrbit(Greeting.RandomOrbitChance, false)
end
function t1._updateReturnGreeting(p26, n12: number) -- line: 562
	if p26._phase ~= "Normal" then
		return
	end

	if p26._joinGreetingPending then
		local v95 = p26:_ownerRootPosition()

		if v95 == nil then
			return
		end

		p26._joinGreetingPending = false
		p26._farSeconds = 0.0
		p26._farRequiredSeconds = p26._random:NextNumber(105.0, 180.0)
		p26:_tryStartReturnGreeting(v95, AssetWanderArea.IsPositionInside(p26._assetArea, v95))

		return
	end

	local v96 = p26:_distanceFromLocalPlayerToAreaCenter()

	if v96 == nil then
		return
	end

	if v96 >= 200.0 then
		p26._farSeconds = p26._farSeconds + n12

		return
	end

	if p26._farSeconds >= p26._farRequiredSeconds and v96 <= 200.0 then
		p26._farSeconds = 0.0
		p26._farRequiredSeconds = p26._random:NextNumber(105.0, 180.0)

		local v97 = p26:_ownerRootPosition()

		if v97 ~= nil and AssetWanderArea.IsPositionInside(p26._assetArea, v97) then
			p26:_tryStartReturnGreeting(v97, true)

			return
		end
	else
		p26._farSeconds = 0.0
	end
end
function t1._updateGreeting(p27, n13: number) -- line: 598
	if p27._phase ~= "GreetingOrbit" and p27._phase ~= "GreetingFinish" then
		return
	end

	local v100 = p27:_distanceFromLocalPlayerToAreaCenter()

	if v100 ~= nil and v100 > 300.0 then
		p27._phase = "Normal"
		p27._greetRemaining = 0.0
		p27:_resetGreetingFinish()
		p27:_resetReturnGreeting()
		p27:_resetAffection()
		p27:_chooseNextDestination()

		return
	end

	p27._greetRemaining = math.max(p27._greetRemaining - n13, 0.0)

	if p27._phase == "GreetingOrbit" then
		if p27._greetRemaining <= 0.0 then
			p27:_beginGreetingFinish()

			return
		end

		if p27._random:NextNumber() < p27._config.Greeting.JumpChancePerSecond * n13 then
			p27:_startJump()
		end

		return
	end

	p27._finishJumpCooldown = math.max(p27._finishJumpCooldown - n13, 0.0)

	if p27._finishJumpsRemaining > 0.0 and p27._finishJumpCooldown <= 0.0 then
		p27:_startJump(0.0)
		p27._finishJumpsRemaining = p27._finishJumpsRemaining - 1.0
		p27._finishJumpCooldown = 0.6
	end

	if p27._finishJumpsRemaining <= 0.0 and p27._jumpRemaining <= 0.0 and p27._greetRemaining <= 0.0 then
		p27._phase = "Normal"
		p27:_resetGreetingFinish()
		p27:_resetReturnGreeting()
		p27:_resetAffection()
		p27:_chooseNextDestination()
	end
end
function t1._stepReturnGreeting(p28, n14: number, cFrame: CFrame, vector3: Vector3) -- line: 642
	if p28._phase == "ReturnGreetingApproach" then
		local _returnGreetingOwnerOffset = p28._returnGreetingOwnerOffset

		assert(_returnGreetingOwnerOffset ~= nil, "Return greeting approach requires a stable owner offset")
		p28._destination = AssetWanderArea.PointNearOwner(p28._assetArea, vector3, _returnGreetingOwnerOffset)

		local v106, v107, v108 = AssetWanderMotion.StepMoveToward(n14, cFrame, p28._destination, p28._walkSpeed)

		if Vector3.new(p28._destination.X - v106.Position.X, 0.0, p28._destination.Z - v106.Position.Z).Magnitude > 2.25 then
			local v109, v110 = p28:_applyJump(n14, v106)

			return v109, v107 or p28._jumpRemaining > 0.0, v110, v108
		end

		p28._phase = "ReturnGreetingHold"
		p28._returnGreetingJumpCooldown = 0.0

		if p28._returnGreetingJumpsRemaining > 0.0 then
			p28:_startJump(0.0)
			p28._returnGreetingJumpsRemaining = p28._returnGreetingJumpsRemaining - 1.0
			p28._returnGreetingJumpCooldown = 0.6
		end

		local v111, v112 = p28:_applyJump(n14, (AssetWanderMotion.FaceOwnerCFrame(v106, vector3, n14, true)))

		return v111, v107 or p28._jumpRemaining > 0.0, v112, v108
	end

	p28._returnGreetingHoldRemaining = math.max(p28._returnGreetingHoldRemaining - n14, 0.0)
	p28._returnGreetingJumpCooldown = math.max(p28._returnGreetingJumpCooldown - n14, 0.0)

	if p28._returnGreetingJumpsRemaining > 0.0 and p28._returnGreetingJumpCooldown <= 0.0 then
		p28:_startJump(0.0)
		p28._returnGreetingJumpsRemaining = p28._returnGreetingJumpsRemaining - 1.0
		p28._returnGreetingJumpCooldown = 0.6
	end

	local v113, v114 = p28:_applyJump(n14, (AssetWanderMotion.FaceOwnerCFrame(cFrame, vector3, n14)))

	if p28._returnGreetingHoldRemaining <= 0.0 and p28._returnGreetingJumpsRemaining <= 0.0 and p28._jumpRemaining <= 0.0 then
		p28._phase = "Normal"
		p28:_resetReturnGreeting()
		p28:_chooseNextDestination()
	end

	return v113, p28._jumpRemaining > 0.0, v114, p28._walkSpeed
end
function t1._stepAffection(p29, n15: number, cFrame: CFrame, vector3: Vector3) -- line: 699
	if p29._phase == "AffectionApproach" then
		local _affectionOwnerOffset = p29._affectionOwnerOffset

		assert(_affectionOwnerOffset ~= nil, "Affection approach requires a stable owner offset")
		p29._destination = AssetWanderArea.PointNearOwner(p29._assetArea, vector3, _affectionOwnerOffset)

		local v120, v121, v122 = AssetWanderMotion.StepMoveToward(n15, cFrame, p29._destination, p29._walkSpeed)

		if Vector3.new(p29._destination.X - v120.Position.X, 0.0, p29._destination.Z - v120.Position.Z).Magnitude > 2.25 then
			local v123, v124 = p29:_applyJump(n15, v120)

			return v123, v121 or p29._jumpRemaining > 0.0, v124, v122
		end

		p29._phase = "AffectionHold"
		p29._affectionJumpCooldown = 0.6
		p29._pendingBubbleText = AssetPersonalityMotion.RandomConfiguredText(p29._random, p29._config.Affection.Texts, p29._config._id, "affection")

		if p29._affectionJumpsRemaining > 0.0 then
			p29:_startJump(0.0)
			p29._affectionJumpsRemaining = p29._affectionJumpsRemaining - 1.0
		end

		local v125, v126 = p29:_applyJump(n15, (AssetWanderMotion.FaceOwnerCFrame(v120, vector3, n15, true)))

		return v125, v121 or p29._jumpRemaining > 0.0, v126, v122
	end

	p29._affectionHoldRemaining = math.max(p29._affectionHoldRemaining - n15, 0.0)
	p29._affectionJumpCooldown = math.max(p29._affectionJumpCooldown - n15, 0.0)

	if p29._affectionJumpsRemaining > 0.0 and p29._affectionJumpCooldown <= 0.0 then
		p29:_startJump(0.0)
		p29._affectionJumpsRemaining = p29._affectionJumpsRemaining - 1.0
		p29._affectionJumpCooldown = 0.6
	end

	local v127, v128 = p29:_applyJump(n15, (AssetWanderMotion.FaceOwnerCFrame(cFrame, vector3, n15)))

	if p29._affectionHoldRemaining <= 0.0 and p29._affectionJumpsRemaining <= 0.0 and p29._jumpRemaining <= 0.0 then
		p29._phase = "Normal"
		p29:_resetAffection()
		p29:_chooseNextDestination()
	end

	return v127, p29._jumpRemaining > 0.0, v128, p29._walkSpeed
end
function t1._updateCurve(p30, n16: number, vector3: Vector3) -- line: 755
	p30._curveChangeElapsed = p30._curveChangeElapsed + n16

	if p30._curveChangeElapsed >= p30._nextCurveChangeSeconds then
		p30._curveChangeElapsed = 0.0
		p30._nextCurveChangeSeconds = p30._random:NextNumber(5.0, 10.0)
		p30._curveAngle = p30._random:NextNumber(-3.141592653589793, 3.141592653589793)
		p30._curveRotationSpeed = p30._random:NextNumber(-0.8, 0.8)
	end

	p30._curveAngle = p30._curveAngle + p30._curveRotationSpeed * n16

	local v132 = vector3 + Vector3.new(math.cos(p30._curveAngle), 0.0, (math.sin(p30._curveAngle))) * 9.0

	p30._destination = AssetWanderArea.ClampedPointToward(p30._assetArea, v132)
end
function t1._orbitGreetingCFrame(p31, n17: number, cFrame: CFrame, vector3: Vector3) -- line: 770
	local v137, v138 = AssetWanderMotion.OwnerMoveVector(n17, vector3, p31._lastOwnerPosition)

	p31._lastOwnerPosition = v138

	return AssetWanderMotion.OrbitGreetingCFrame(p31._assetArea, n17, cFrame, vector3, v137, p31._greetingOrbitRadius, 22.0, 0.75)
end
function t1._applyJump(p32, n18: number, cFrame: CFrame) -- line: 791
	if p32._jumpRemaining <= 0.0 then
		return cFrame, true
	end

	p32._jumpRemaining = math.max(p32._jumpRemaining - n18, 0.0)
	p32._jumpElapsed = math.min(p32._jumpElapsed + n18, 0.45)

	local v142 = p32._jumpElapsed / 0.45
	local v143 = math.sin(v142 * 3.141592653589793) * p32._jumpHeight
	local v144 = p32._spinYaw == 0.0 and 0.0 or p32._spinYaw * v142
	local v145 = v144 - p32._spinAppliedYaw

	p32._spinAppliedYaw = v144

	local v146 = CFrame.new(cFrame.Position + Vector3.new(0.0, v143, 0.0)) * cFrame.Rotation

	if v145 ~= 0.0 then
		v146 *= CFrame.Angles(0.0, v145, 0.0)
	end

	if p32._jumpRemaining <= 0.0 then
		p32._spinAppliedYaw = 0.0
	end

	return v146, p32._jumpRemaining <= 0.0
end
function t1.SetAssetArea(p33, p34) -- line: 818

	local v149 = p34 ~= p33._assetArea

	p33._assetArea = p34

	if v149 then
		p33._loyalOwnerOffset = AssetPersonalityMotion.RandomOwnerOffset(p34, p33._random, p33._greetingOrbitRadius)
		p33._returnGreetingOwnerOffset = if p33._returnGreetingOwnerOffset == nil then nil else AssetPersonalityMotion.RandomOwnerOffset(p34, p33._random, p33._greetingOrbitRadius)
		p33._affectionOwnerOffset = if p33._affectionOwnerOffset == nil then nil else AssetPersonalityMotion.RandomOwnerOffset(p34, p33._random, p33._greetingOrbitRadius)
	end

	p33:_chooseNextDestination()
end
function t1.SetItemData(p35, p36, b6: boolean) -- line: 836
	assert(AssetItem.AssetItemData(p36), "Invalid asset item data")
	p35._itemData = p36
	p35._config = Personalities.GetConfig(p36.Personality)

	if b6 then
		p35:_tryStartFirstPlacementGreeting()
	end
end
function t1.Step(p37, n19: number, cFrame: CFrame) -- line: 851
	p37:_updateReturnGreeting(n19)
	p37:_updateGreeting(n19)

	local cFramePosition = cFrame.Position
	local v157 = p37:_ownerRootPosition()

	if p37._phase ~= "Normal" and v157 == nil then
		p37._phase = "Normal"
		p37._greetRemaining = 0.0
		p37:_resetGreetingFinish()
		p37:_resetReturnGreeting()
		p37:_resetAffection()
		p37:_chooseNextDestination()
	end

	p37:_updateAffectionTrigger(n19, v157)
	p37:_updateOrbitGreetingTrigger(n19, v157)

	local v158 = p37._phase == "Normal" and (v157 == nil or p37:_tryRetreatFromOwner(cFramePosition, v157))

	if p37._phase == "Normal" then
		p37:_tryAmbientJump(n19)
	end

	if p37._idleRemaining > 0.0 and p37._phase == "Normal" then
		local v159, v160 = p37:_stepIdle(n19)

		return v159, p37._jumpRemaining > 0.0, v160, 0.0, false, p37:_popBubbleText()
	end

	if p37._phase == "GreetingOrbit" and v157 ~= nil then
		local v161, v162, v163 = p37:_orbitGreetingCFrame(n19, cFrame, v157)
		local v164, v165 = p37:_applyJump(n19, v161)

		return v164, v162 or p37._jumpRemaining > 0.0, v165, v163, true, p37:_popBubbleText()
	end

	if p37._phase == "GreetingFinish" and v157 ~= nil then
		local v166, v167 = p37:_applyJump(n19, (AssetWanderMotion.FaceOwnerCFrame(cFrame, v157, n19)))

		return v166, p37._jumpRemaining > 0.0, v167, p37._walkSpeed, true, p37:_popBubbleText()
	end

	if (p37._phase == "ReturnGreetingApproach" or p37._phase == "ReturnGreetingHold") and v157 ~= nil then
		local v168, v169, v170, v171 = p37:_stepReturnGreeting(n19, cFrame, v157)

		return v168, v169, v170, v171, false, p37:_popBubbleText()
	end

	if (p37._phase == "AffectionApproach" or p37._phase == "AffectionHold") and v157 ~= nil then
		local v172, v173, v174, v175 = p37:_stepAffection(n19, cFrame, v157)

		return v172, v173, v174, v175, false, p37:_popBubbleText()
	end

	if p37._config.Movement.FollowOwnerInPen and v157 ~= nil and AssetWanderArea.IsPositionInside(p37._assetArea, v157) then
		local v176, v177, v178 = AssetWanderMotion.StepFollowOwner(p37._assetArea, n19, cFrame, v157, p37._loyalOwnerOffset, p37._walkSpeed, 2.25)
		local v179, v180 = p37:_applyJump(n19, v176)

		return v179, v177 or p37._jumpRemaining > 0.0, v180, v178, false, p37:_popBubbleText()
	end

	if p37._mode == "Curve" then
		p37:_updateCurve(n19, cFrame.Position)
	end

	local _destination = p37._destination
	local v182 = _destination - cFramePosition

	if Vector3.new(v182.X, 0.0, v182.Z).Magnitude <= 0.35 and not v158 then
		p37:_beginIdle(cFrame)
		p37:_chooseNextDestination()

		local v183, v184 = p37:_applyJump(n19, cFrame)

		return v183, p37._jumpRemaining > 0.0, v184, p37._walkSpeed, false, p37:_popBubbleText()
	end

	local _walkSpeed = p37._walkSpeed

	if p37._random:NextNumber() < p37._config.Movement.BurstChance * n19 then
		_walkSpeed = p37._config.Movement.WalkSpeedMax * 1.25 * AssetMutationWalkSpeed.GetMultiplier(p37._itemData)
		p37:_startJump()
	end

	local v186, v187, v188 = AssetWanderMotion.StepMoveToward(n19, cFrame, _destination, _walkSpeed)
	local v189, v190 = p37:_applyJump(n19, v186)

	return v189, v187 or p37._jumpRemaining > 0.0, v190, v188, false, p37:_popBubbleText()
end

return t1

