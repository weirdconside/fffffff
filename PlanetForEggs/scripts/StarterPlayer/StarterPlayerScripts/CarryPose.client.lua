-- Procedural two-arm grip for AnimationConstraint and legacy Motor6D rigs.
-- Animator transforms are restored before its next
-- evaluation and overridden after animation in PreSimulation. No animation
-- asset permission or custom avatar animation is required.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local GuiService=game:GetService("GuiService")
local player=Players.LocalPlayer
local api=ReplicatedStorage:WaitForChild("PFE")
local Config=require(api:WaitForChild("Config"))
local states={}
local carryState=false
local busy=false
local localCharacter
local alive=true

local function restore(rig)
	for motor,transform in pairs(rig.Saved) do
		if motor.Parent then motor.Transform=transform end
	end
	table.clear(rig.Saved)
	rig.Active=false
end
local function findMotor(character,partName)
	local part=character:FindFirstChild(partName)
	if not part then return nil end
	local legacy
	for _,node in ipairs(character:GetDescendants()) do
		-- AvatarJointUpgrade R15 uses AnimationConstraint. Its read-only Part0,
		-- Part1, C0 and C1 aliases expose the same joint equation as Motor6D.
		-- Only Transform is written; RigAttachment.CFrame is never modified.
		if node:IsA("AnimationConstraint") and node.Part1==part then return node end
		if node:IsA("Motor6D") and node.Part1==part then legacy=node end
	end
	return legacy
end
local function getRig(character)
	local cached=states[character]
	if cached and cached.Complete then return cached end
	local rig=cached or {Saved={},Arms={},Joints={},Active=false,Complete=false}
	states[character]=rig
	local humanoid=character:FindFirstChildOfClass("Humanoid")
	local root=character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return rig end
	rig.Humanoid=humanoid;rig.Root=root;rig.R15=humanoid.RigType==Enum.HumanoidRigType.R15
	for _,node in ipairs(character:GetDescendants()) do
		if (node:IsA("AnimationConstraint") or node:IsA("Motor6D")) and node.Part1 then
			local previous=rig.Joints[node.Part1]
			if not previous or node:IsA("AnimationConstraint") then rig.Joints[node.Part1]=node end
		end
	end
	for _,side in ipairs({-1,1}) do
		local prefix=side<0 and "Left" or "Right"
		local shoulder=findMotor(character,rig.R15 and prefix.."UpperArm" or prefix.." Arm")
		local elbow=rig.R15 and findMotor(character,prefix.."LowerArm")
		local wrist=rig.R15 and findMotor(character,prefix.."Hand")
		if shoulder then rig.Arms[side]={Shoulder=shoulder,Elbow=elbow,Wrist=wrist,Side=side} end
	end
	rig.Complete=rig.Arms[-1]~=nil and rig.Arms[1]~=nil
	if rig.R15 then rig.Complete=rig.Complete and rig.Arms[-1].Wrist~=nil and rig.Arms[1].Wrist~=nil end
	if rig.Complete then character:SetAttribute("PFECarryPoseJointType",rig.Arms[1].Shoulder.ClassName) end
	return rig
end
local function limbOrientation(from,to,preferredRight)
	local delta=from-to
	if delta.Magnitude<.001 then return CFrame.new(from) end
	local up=delta.Unit
	local right=preferredRight-up*preferredRight:Dot(up)
	if right.Magnitude<.001 then right=up:Cross(Vector3.zAxis) end
	if right.Magnitude<.001 then right=up:Cross(Vector3.xAxis) end
	right=right.Unit
	return CFrame.fromMatrix(from,right,up,right:Cross(up))
end
local function jointTransform(motor,parentCF,childCF)
	return motor.C0:Inverse()*parentCF:Inverse()*childCF*motor.C1
end
local function animatedBodyCFrame(rig,part,depth)
	if part==rig.Root or depth>8 then return part.CFrame end
	local motor=rig.Joints[part]
	if not motor or not motor.Part0 then return part.CFrame end
	-- Motor transforms are batched after PreSimulation. Read the Animator's new
	-- torso chain explicitly rather than compensating against last frame's torso.
	return animatedBodyCFrame(rig,motor.Part0,depth+1)*motor.C0*motor.Transform*motor.C1:Inverse()
end
local function apply(rig,motor,parentCF,childCF)
	if not motor or not motor.Parent or not motor.Part0 or not motor.Part1 then return end
	-- Save the fresh Animator pose, not our previous carry override.
	if rig.Saved[motor]==nil then rig.Saved[motor]=motor.Transform end
	motor.Transform=jointTransform(motor,parentCF,childCF)
end
local function solveElbow(shoulder,wrist,upperLength,lowerLength,bendDirection)
	local offset=wrist-shoulder
	if offset.Magnitude<.001 then return shoulder+Vector3.new(0,-upperLength,0) end
	local forward=offset.Unit
	local distance=math.clamp(offset.Magnitude,math.abs(upperLength-lowerLength)+.001,upperLength+lowerLength-.001)
	local along=(upperLength*upperLength-lowerLength*lowerLength+distance*distance)/(2*distance)
	local height=math.sqrt(math.max(0,upperLength*upperLength-along*along))
	local bend=bendDirection-forward*bendDirection:Dot(forward)
	if bend.Magnitude<.001 then bend=forward:Cross(Vector3.yAxis) end
	if bend.Magnitude<.001 then bend=Vector3.xAxis end
	return shoulder+forward*along+bend.Unit*height
end
-- A limb placed so that its joint point `localFrom` (in the part's space) sits at `fromPoint` and its
-- next joint `localTo` points at `toPoint`. (R15 shoulders sit on the torso's edge, not on the arm's
-- axis: aiming the arm's own Y axis instead tilted it and left the forearm hanging apart.)
local function placeLimb(fromPoint,toPoint,localFrom,localTo,preferredRight)
	local frame=limbOrientation(fromPoint,toPoint,preferredRight)
	local v=localTo-localFrom
	local turn=CFrame.identity
	if v.Magnitude>.001 then
		local a,b=v.Unit,-Vector3.yAxis
		local axis=a:Cross(b)
		local angle=math.acos(math.clamp(a:Dot(b),-1,1))
		if axis.Magnitude>.0001 then turn=CFrame.fromAxisAngle(axis.Unit,angle)
		elseif a:Dot(b)<0 then turn=CFrame.fromAxisAngle(Vector3.zAxis,math.pi) end
	end
	return frame*turn*CFrame.new(-localFrom)
end
-- the egg in these hands: its centre and half sizes in the root's space (cached per egg model)
local eggShapes=setmetatable({},{__mode="k"})
local function eggFor(character)
	local model=character:FindFirstChild("CarriedPlanetEgg")
	if not model and character==player.Character then model=workspace:FindFirstChild("LocalEquippedEgg") end
	if not model or not model:IsA("Model") then return nil end
	local shape=eggShapes[model]
	if not shape then
		local lo,hi=Vector3.one*math.huge,-Vector3.one*math.huge
		local pivot=model:GetPivot()
		for _,part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part.Transparency<.98 then
				for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
					local corner=pivot:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z)*.5))
					lo=lo:Min(corner);hi=hi:Max(corner)
				end end end
			end
		end
		if lo.X==math.huge then return nil end
		shape={Center=(lo+hi)*.5,Size=hi-lo}
		eggShapes[model]=shape
	end
	return model:GetPivot():PointToWorldSpace(shape.Center),shape.Size
end
-- where a hand goes. At the chest: on the egg's side at its middle, or further round towards the chest
-- when the egg is too big for the arm to reach its side (the palm half a stud off the shell). Over the
-- head: under the egg's lower sides, further underneath while out of reach.
local function gripPoint(rootCF,start,reach,side,eggCenter,eggSize,overhead)
	local c=rootCF:PointToObjectSpace(eggCenter)
	local r=Vector3.new(math.max(eggSize.X,eggSize.Z)*.5,eggSize.Y*.5,math.max(eggSize.X,eggSize.Z)*.5)
	local startLocal=rootCF:PointToObjectSpace(start)
	local best
	for k=0,8 do
		local t=k/8
		local n,off
		if overhead then
			n=Vector3.new(side*(.6-t*.45),-(.8+t*.18),0).Unit;off=.3
		else
			n=Vector3.new(side*(1-t*.45),.1,.05+t*.85).Unit;off=.5
		end
		local surface=c+Vector3.new(r.X*n.X,r.Y*n.Y,r.Z*n.Z)
		local normal=Vector3.new(n.X/r.X,n.Y/r.Y,n.Z/r.Z).Unit
		local target=surface+normal*off
		if not overhead and target.Z>-.6 then target=Vector3.new(target.X,target.Y,-.6) end -- never inside the chest
		best=target
		if (target-startLocal).Magnitude<=reach*.97 then break end
	end
	local offset=best-startLocal
	if offset.Magnitude>reach*.97 then best=startLocal+offset.Unit*reach*.97 end
	return rootCF:PointToWorldSpace(best)
end
local DEFAULT_EGG=Vector3.new(1.6,2.2,1.6)
local function poseArm(rig,arm,character)
	local rootCF=rig.Root.CFrame
	local shoulder=arm.Shoulder
	if not shoulder.Part0 or not shoulder.Part1 then return end
	local parentCF=animatedBodyCFrame(rig,shoulder.Part0,0)
	local start=(parentCF*shoulder.C0).Position
	local eggCenter,eggSize=eggFor(character)
	if not eggCenter then
		eggSize=DEFAULT_EGG
		eggCenter=(rootCF*Config.HeldEggOffset(eggSize,Config.HeadTop(character))).Position
	end
	local overhead=Config.HeldEggOverhead(eggSize)
	local right=rootCF.RightVector
	if not rig.R15 or not arm.Elbow or not arm.Wrist then
		-- one-piece arm: its lower end on the egg
		local tip=Vector3.new(0,-shoulder.Part1.Size.Y*.5+.1,0)
		local reach=(tip-shoulder.C1.Position).Magnitude
		local grip=gripPoint(rootCF,start,reach,arm.Side,eggCenter,eggSize,overhead)
		apply(rig,shoulder,parentCF,placeLimb(start,grip,shoulder.C1.Position,tip,right))
		return
	end
	local elbow,wrist=arm.Elbow,arm.Wrist
	if not elbow.Part1 or not wrist.Part1 then return end
	local upperLength=math.max(.25,(elbow.C0.Position-shoulder.C1.Position).Magnitude)
	local lowerLength=math.max(.25,(wrist.C0.Position-elbow.C1.Position).Magnitude)
	local wristPoint=gripPoint(rootCF,start,upperLength+lowerLength,arm.Side,eggCenter,eggSize,overhead)
	-- elbows out to the sides and a little down (hugging), or out to the sides (holding it up)
	local elbowPoint=solveElbow(start,wristPoint,upperLength,lowerLength,right*arm.Side-rootCF.UpVector*.55)
	local upperCF=placeLimb(start,elbowPoint,shoulder.C1.Position,elbow.C0.Position,right)
	local elbowAt=(upperCF*elbow.C0).Position -- (the very point the upper arm ends)
	local lowerCF=placeLimb(elbowAt,wristPoint,elbow.C1.Position,wrist.C0.Position,right)
	-- the hand simply continues the forearm (no twisted wrist)
	local handCF=lowerCF*wrist.C0*wrist.C1:Inverse()
	apply(rig,shoulder,parentCF,upperCF)
	apply(rig,elbow,upperCF,lowerCF)
	apply(rig,wrist,lowerCF,handCF)
end
local function shouldPose(character,rig)
	if not rig.Complete or not rig.Humanoid or rig.Humanoid.Health<=0 or not rig.Root.Parent then return false end
	if character==player.Character then
		if busy or player:GetAttribute("PFEFlightActive") or player:GetAttribute("PFEMenuOpen")
			or player:GetAttribute("PFEPlanetMapOpen") or player:GetAttribute("PFEInventoryOpen") or GuiService.MenuIsOpen then return false end
		return carryState or player:GetAttribute("PFEHoldingStoredEgg")==true
	end
	return character:FindFirstChild("CarriedPlanetEgg")~=nil
end
-- Clear our previous Transform before Animator evaluates this frame. This avoids
-- leaving a carry pose behind if an idle animation does not key every joint.
RunService.PreAnimation:Connect(function()
	if not alive then return end
	for character,rig in pairs(states) do
		if rig.Active then restore(rig) end
		if not character.Parent then states[character]=nil end
	end
end)
RunService.PreSimulation:Connect(function()
	if not alive then return end
	-- players, and the bot explorers (v30: they carry their eggs the same way)
	local characters={}
	for _,owner in ipairs(Players:GetPlayers()) do
		if owner.Character then table.insert(characters,owner.Character) end
	end
	local botFolder=workspace:FindFirstChild("PFE_Bots")
	if botFolder then
		for _,bot in ipairs(botFolder:GetChildren()) do
			if bot:FindFirstChild("CarriedPlanetEgg") or states[bot] then table.insert(characters,bot) end
		end
	end
	for _,character in ipairs(characters) do
		if character then
			local rig=getRig(character)
			if shouldPose(character,rig) then
				for _,arm in pairs(rig.Arms) do poseArm(rig,arm,character) end
				rig.Active=true
				if character:GetAttribute("PFECarryPoseActive")~=true then character:SetAttribute("PFECarryPoseActive",true) end
			else
				if rig.Active then restore(rig) end
				if character:GetAttribute("PFECarryPoseActive")~=false then character:SetAttribute("PFECarryPoseActive",false) end
			end
		end
	end
end)
local function restoreLocal()
	local rig=localCharacter and states[localCharacter]
	if rig then restore(rig) end
	if localCharacter and localCharacter.Parent then localCharacter:SetAttribute("PFECarryPoseActive",false) end
end
local function characterAdded(character)
	restoreLocal();localCharacter=character;carryState=false
	local humanoid=character:WaitForChild("Humanoid",10)
	if humanoid then humanoid.Died:Connect(restoreLocal) end
end
player.CharacterAdded:Connect(characterAdded)
player.CharacterRemoving:Connect(function(character)
	local rig=states[character];if rig then restore(rig);states[character]=nil end
end)
if player.Character then task.spawn(characterAdded,player.Character) end
for _,attribute in ipairs({"PFEHoldingStoredEgg","PFEMenuOpen","PFEPlanetMapOpen","PFEInventoryOpen","PFEFlightActive"}) do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		local rig=player.Character and states[player.Character]
		if rig and not shouldPose(player.Character,rig) then restore(rig) end
	end)
end
GuiService.MenuOpened:Connect(restoreLocal)
api:WaitForChild("State").OnClientEvent:Connect(function(state)
	if type(state)~="table" then return end
	carryState=state.CarryingEgg~=nil or state.Stolen~=nil;busy=state.Busy==true
	if not carryState and not player:GetAttribute("PFEHoldingStoredEgg") then restoreLocal() end
end)
script.Destroying:Connect(function() alive=false;for _,rig in pairs(states) do restore(rig) end end)
