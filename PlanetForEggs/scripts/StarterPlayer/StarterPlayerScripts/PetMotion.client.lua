-- Pet wandering in the pen (source wander simulator), procedural rig animation (PetRig: legs, tails,
-- heads and wings found by geometry, plus a gait for the whole body), idle performances, floating pets hover.
-- Gameplay ownership and income remain server-owned; these positions are presentation only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("PFE")
local Config = require(network:WaitForChild("Config"))
local ModelUtil = require(network:WaitForChild("ModelUtil"))
local behavior = network:WaitForChild("PetBehavior")
local Simulator = require(behavior:WaitForChild("AssetWanderSimulator"))
local Area = require(behavior:WaitForChild("AssetWanderArea"))
local Personalities = require(behavior:WaitForChild("Personalities"))
local PetRig = require(behavior:WaitForChild("PetRig"))
local PetAnimations = require(behavior:WaitForChild("PetAnimations"))
local bases = workspace:WaitForChild("PlanetForEggs"):WaitForChild("Bases")
local records = {}
local function seedFor(text)
	local value = 17
	for index = 1, #text do value = (value * 31 + string.byte(text, index)) % 2147483647 end
	return value
end
local function remove(model)
	local record = records[model]
	if not record then return end
	if record.PoseDriver then record.PoseDriver:Destroy() end
	if record.Bubble then record.Bubble:Destroy() end
	records[model] = nil
end
local function register(model, base, owner)
	if records[model] or model:GetAttribute("PFEHatching") then return end
	local species = model:GetAttribute("Species")
	local info = species and Config.Pets[species]
	local area = base:FindFirstChild("PlantArea")
	if not info or not area or not model.PrimaryPart then return end
	-- wait until every part has replicated (the server says how many): measuring half a rig puts it
	-- in the ground or in the air at the wrong size
	local expected = model:GetAttribute("PartCount")
	if expected then
		local count = 0
		for _, part in ipairs(model:GetDescendants()) do if part:IsA("BasePart") then count += 1 end end
		if count < expected then return end
	end
	local cf, size = ModelUtil.VisibleBounds(model)
	local modelPivot = model:GetPivot()
	local bottom = cf.Position.Y - size.Y / 2 - modelPivot.Position.Y
	local floorY = area.Position.Y - bottom + 0.04
	-- The source margin was 1.75. Account for each imported pet's body width as well.
	local width = math.max(size.X, size.Z)
	local inset = math.max(0, width - 3.5)
	local walkingArea = {CFrame = CFrame.new(area.Position.X, floorY, area.Position.Z) * area.CFrame.Rotation,
		Size = Vector3.new(math.max(4, area.Size.X - inset), area.Size.Y, math.max(4, area.Size.Z - inset))}
	walkingArea.Position = walkingArea.CFrame.Position
	local personality = model:GetAttribute("Personality") or "Normal"
	if not Personalities.IsPersonality(personality) then personality = "Normal" end
	local item = {Category = species, Personality = personality, Mutations = {}, Scale = model:GetAttribute("Scale") or 1}
	local simulator = Simulator.new(seedFor(model:GetAttribute("PetId") or model.Name), owner, walkingArea, item, true,
		math.max(3.5, width * 0.6), math.clamp(size.Y * 0.17, 0.5, 1.75))
	local start = Area.ClampedPointToward(walkingArea, modelPivot.Position)
	local pose = CFrame.new(start) * modelPivot.Rotation
	model:PivotTo(pose)
	local record = {Model = model, Base = base, Owner = owner, Area = walkingArea, Simulator = simulator, Pose = pose,
		Moving = false, FloorY = floorY, Float = model:GetAttribute("Float") == true,
		Phase = (seedFor(model:GetAttribute("PetId") or model.Name) % 628) / 100}
	local seed = seedFor(model:GetAttribute("PetId") or model.Name)
	record.PoseDriver = PetRig.new(model, species, {Float = record.Float, Seed = (seed % 628) / 100})
	record.Anim = PetAnimations.new(model, seed, size.Y)
	records[model] = record
	model:SetAttribute("PFEAnimationMode", "LocalMotorPoses")
	model:SetAttribute("PFESourceWander", true)
end
local function bubble(record, message)
	if type(message) ~= "string" or message == "" then return end
	if record.Bubble then record.Bubble:Destroy() end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PetGreeting"; gui.Adornee = record.Model.PrimaryPart; gui.Size = UDim2.fromOffset(62,52)
	gui.StudsOffsetWorldSpace = Vector3.new(2,6,0); gui.AlwaysOnTop = true; gui.MaxDistance = 90; gui.Parent = record.Model
	local text = Instance.new("TextLabel"); text.Size = UDim2.fromScale(1,1); text.BackgroundColor3 = Color3.fromRGB(138,62,241)
	text.Text = message; text.TextSize = 28; text.Font = Enum.Font.FredokaOne; text.TextColor3 = Color3.new(1,1,1)
	text.TextStrokeTransparency = 0; text.TextStrokeColor3 = Color3.fromRGB(19,12,32); text.Parent = gui
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(.4,0); corner.Parent = text
	local stroke = Instance.new("UIStroke"); stroke.Thickness = 3; stroke.Color = Color3.fromRGB(19,12,32); stroke.Parent = text
	record.Bubble = gui
	TweenService:Create(gui, TweenInfo.new(.28,Enum.EasingStyle.Back), {StudsOffsetWorldSpace=Vector3.new(2,7,0)}):Play()
	task.delay(2.3, function()
		if gui.Parent then gui:Destroy() end
		if record.Bubble == gui then record.Bubble = nil end
	end)
end
-- walk/idle gait for the rig, the pet's own performance on top; returns the body offset for the pivot
local function animate(record, moving, speed, dt)
	record.Anim:Advance(dt, moving)
	record.PoseDriver:SetMoving(moving, speed)
	local gait = record.PoseDriver:Step(dt, record.Anim)
	return gait * record.Anim:Body()
end
local scanElapsed = 1
local botOwners = {}
RunService.Heartbeat:Connect(function(dt)
	scanElapsed += dt
	if scanElapsed < .5 then return end
	scanElapsed = 0
	for _, base in ipairs(bases:GetChildren()) do
		local ownerId = base:GetAttribute("OwnerUserId") or 0
		local owner = Players:GetPlayerByUserId(ownerId)
		if not owner and ownerId < 0 then
			-- (v29) a bot's base: its pets wander too (the bot's body stands in for the owner's character)
			botOwners[ownerId] = botOwners[ownerId] or {UserId = ownerId}
			local bots = workspace:FindFirstChild("PFE_Bots")
			local body
			for _, m in ipairs(bots and bots:GetChildren() or {}) do if m:GetAttribute("BotId") == -ownerId then body = m end end
			botOwners[ownerId].Character = body
			owner = botOwners[ownerId]
		end
		local folder = base:FindFirstChild("ActivePets")
		if owner and folder then for _, model in ipairs(folder:GetChildren()) do
			if model:IsA("Model") then register(model, base, owner) end
		end end
	end
	for model, record in pairs(records) do
		if not model.Parent or record.Base:GetAttribute("OwnerUserId") ~= record.Owner.UserId then remove(model) end
	end
end)
RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, .06)
	local camera = workspace.CurrentCamera
	for model, record in pairs(records) do
		if not model.Parent or model:GetAttribute("PFEHatching") then continue end
		local distance = camera and (camera.CFrame.Position - record.Area.Position).Magnitude or math.huge
		if distance > 340 then continue end
		-- (v36) level of detail: the further the pen, the fewer steps a second (the time saved up is used at once)
		record.Acc = (record.Acc or 0) + dt
		local every = distance > 200 and 1 / 15 or (distance > 110 and 1 / 30 or 0)
		if record.Acc < every then continue end
		-- a pen behind the camera rests (checked a few times a second)
		record.ViewClock = (record.ViewClock or 1) + record.Acc
		if record.ViewClock > 0.25 then
			record.ViewClock = 0
			local _, onScreen = camera:WorldToViewportPoint(record.Area.Position)
			local look = camera.CFrame.LookVector:Dot((record.Area.Position - camera.CFrame.Position).Unit)
			record.Seen = onScreen or look > -0.2 or distance < 60
		end
		if not record.Seen then record.Acc = 0; continue end
		local step = math.min(record.Acc, 0.12)
		record.Acc = 0
		-- Feed ground-level position back into the source simulator: jump displacement is visual.
		local previous = record.Pose
		local grounded = CFrame.new(previous.Position.X, record.FloorY, previous.Position.Z) * previous.Rotation
		local pose, moving, _, speed, _, text = record.Simulator:Step(step, grounded)
		local clamped = Area.ClampedPointToward(record.Area, pose.Position)
		pose = CFrame.new(clamped.X, pose.Position.Y, clamped.Z) * pose.Rotation
		record.Pose = pose
		local offset = animate(record, moving and speed > .1, speed, step)
		if record.Float then
			model:PivotTo(pose * offset + Vector3.new(0, 1.6 + math.sin(os.clock() * 2 + record.Phase) * 0.45, 0))
		else
			model:PivotTo(pose * offset)
		end
		if text then bubble(record, text) end
	end
end)

