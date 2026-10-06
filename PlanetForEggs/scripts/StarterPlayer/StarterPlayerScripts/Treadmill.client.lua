--!nocheck
-- v28 treadmills (Steal an Egg style). Step onto your base's treadmill and you run in place on it: the
-- character is held on the belt facing forward with its own run animation, the belt slats roll, a "+SP" pops
-- over your head every second and the HUD shows what you gain (the server counts it: Speed.lua). Jump (or the
-- STOP button) to step off. Other players' treadmills roll while their owners run on them.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local UI = require(api:WaitForChild("UIKit"))
local C = UI.C
local bases = workspace:WaitForChild("PlanetForEggs"):WaitForChild("Bases")

local state = {Trail = "", TreadmillLevel = 1}
api:WaitForChild("State").OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	for k, v in pairs(payload) do state[k] = v end
end)

local function myBase()
	for _, base in ipairs(bases:GetChildren()) do
		if base:GetAttribute("OwnerUserId") == player.UserId then return base end
	end
	return nil
end

-- ---------------------------------------------------------------- the on-screen panel
local gui = UI.new("ScreenGui", {Name = "PFE_Treadmill", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 22, Enabled = false},
	player:WaitForChild("PlayerGui"))
local panel = UI.new("Frame", {Name = "Panel", BackgroundColor3 = C.Ink, BackgroundTransparency = 0.25, AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(420, 92)}, gui)
UI.round(panel, 18); UI.stroke(panel, 3, Color3.fromRGB(120, 230, 255), 0.2)
local panelScale = UI.new("UIScale", {}, panel)
local head = UI.text(panel, "TRAINING SPEED", UDim2.new(1, -20, 0, 34), UDim2.fromOffset(10, 6), 30, C.White)
head.TextXAlignment = Enum.TextXAlignment.Center; head.TextWrapped = false
UI.new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(220, 250, 255), Color3.fromRGB(60, 190, 255))}, head)
local sub = UI.text(panel, "", UDim2.new(1, -150, 0, 26), UDim2.fromOffset(12, 50), 20, Color3.fromRGB(120, 255, 90))
sub.TextWrapped = false
local stop = UI.button(panel, "STOP", C.Red, UDim2.fromOffset(120, 40), UDim2.new(1, -132, 0, 44), function() end, {TextSize = 22, Name = "Stop"})
local hint = UI.text(panel, "", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 1, -2), 14, C.Soft)
hint.TextXAlignment = Enum.TextXAlignment.Center

local function layout()
	local cam = workspace.CurrentCamera
	if cam then panelScale.Scale = math.max(UI.minScale(), UI.scaleFor(cam.ViewportSize)) end
end
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
layout()

-- ---------------------------------------------------------------- running in place
local active = nil         -- {Belt, Root, Humanoid, Track, Since, Next}
local cooldownUntil = 0

local function runAnimation(character, humanoid)
	local animate = character:FindFirstChild("Animate")
	local run = animate and animate:FindFirstChild("run")
	local anim = run and run:FindFirstChildWhichIsA("Animation")
	if not anim then
		anim = Instance.new("Animation")
		anim.AnimationId = humanoid.RigType == Enum.HumanoidRigType.R15 and "rbxassetid://913376220" or "rbxassetid://180426354"
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
	if not ok then return nil end
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	return track
end

local function popGain(root, amount)
	local gui3d = Instance.new("BillboardGui")
	gui3d.Name = "SpeedPop"; gui3d.Size = UDim2.fromOffset(140, 44); gui3d.StudsOffsetWorldSpace = Vector3.new(math.random(-10, 10) / 10, 3.2, 0)
	gui3d.AlwaysOnTop = true; gui3d.LightInfluence = 0; gui3d.MaxDistance = 80; gui3d.Adornee = root; gui3d.Parent = root
	local t = UI.text(gui3d, "+" .. Config.FormatRate(amount) .. " ⚡", UDim2.fromScale(1, 1), nil, 30, Color3.fromRGB(140, 240, 255))
	t.TextXAlignment = Enum.TextXAlignment.Center; t.TextWrapped = false
	UI.new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(240, 255, 255), Color3.fromRGB(60, 180, 255))}, t)
	TweenService:Create(gui3d, TweenInfo.new(1.1, Enum.EasingStyle.Quad), {StudsOffsetWorldSpace = gui3d.StudsOffsetWorldSpace + Vector3.new(0, 3, 0)}):Play()
	TweenService:Create(t, TweenInfo.new(1.1, Enum.EasingStyle.Quad), {TextTransparency = 1}):Play()
	task.delay(1.15, function() gui3d:Destroy() end)
end

local function leave(push)
	local run = active
	if not run then return end
	active = nil
	gui.Enabled = false
	cooldownUntil = os.clock() + 1.6
	api:WaitForChild("Action"):FireServer("Treadmill", false)
	if run.Track then run.Track:Stop(0.2) end
	if run.Root.Parent then
		run.Root.Anchored = false
		if push and run.Belt.Parent then
			local side = run.Belt.CFrame.RightVector * (run.Belt.Size.X / 2 + 3.5)
			run.Root.CFrame = run.Root.CFrame + side + Vector3.new(0, 0.5, 0)
		end
	end
end

local function enter(belt, root, humanoid)
	local character = root.Parent
	local hip = humanoid.RigType == Enum.HumanoidRigType.R15 and (humanoid.HipHeight + root.Size.Y / 2) or 3
	local top = belt.CFrame * CFrame.new(0, belt.Size.Y / 2, 0)
	local look = belt.CFrame.LookVector
	root.Anchored = true
	root.CFrame = CFrame.lookAt(top.Position + Vector3.new(0, hip, 0), top.Position + Vector3.new(0, hip, 0) + look)
	active = {Belt = belt, Root = root, Humanoid = humanoid, Track = runAnimation(character, humanoid), Since = os.clock(), Next = os.clock() + 1}
	if active.Track then active.Track:Play(0.2) end
	api:WaitForChild("Action"):FireServer("Treadmill", true)
	gui.Enabled = true
	hint.Text = UI.isTouch() and "Tap STOP to get off" or "Press SPACE (jump) or STOP to get off"
end

stop.Activated:Connect(function() leave(true) end)
UserInputService.JumpRequest:Connect(function() if active then leave(true) end end)
player.CharacterAdded:Connect(function()
	if active then api:WaitForChild("Action"):FireServer("Treadmill", false) end
	active = nil; gui.Enabled = false
end)

-- ---------------------------------------------------------------- per frame
local slatClock = 0
RunService.RenderStepped:Connect(function(dt)
	slatClock += dt
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local base = myBase()
	local treadmill = base and base:FindFirstChild("Treadmill")
	local belt = treadmill and treadmill:FindFirstChild("Belt")
	if active then
		if not root or root ~= active.Root or not humanoid or humanoid.Health <= 0 or not belt or belt ~= active.Belt
			or player:GetAttribute("PFEFlightActive") or (root.Position - belt.Position).Magnitude > 14 then
			leave(false)
		else
			local gain = Config.TreadmillGain(state.TreadmillLevel or 1, state.Trail ~= "" and state.Trail or nil, state.Passes and state.Passes.VIP)
			sub.Text = "+" .. Config.FormatRate(gain) .. " speed/s   ·   " .. Config.Format(math.floor(player:GetAttribute("PFESpeedPower") or state.SpeedPower or 0)) .. " speed"
			if active.Track then active.Track:AdjustSpeed(math.clamp((state.WalkSpeed or 20) / 16, 1, 2.2)) end
			if os.clock() >= active.Next then
				active.Next += 1
				popGain(root, gain)
			end
		end
	elseif root and humanoid and humanoid.Health > 0 and belt and os.clock() >= cooldownUntil and not root.Anchored then
		local p = belt.CFrame:PointToObjectSpace(root.Position)
		if math.abs(p.X) <= belt.Size.X / 2 + 0.3 and math.abs(p.Z) <= belt.Size.Z / 2 + 0.3 and p.Y > 0 and p.Y < 7
			and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
			enter(belt, root, humanoid)
		end
	end
	-- roll the slats of every treadmill whose owner is running on it
	for _, b in ipairs(bases:GetChildren()) do
		local owner = Players:GetPlayerByUserId(b:GetAttribute("OwnerUserId") or 0)
		local t = b:FindFirstChild("Treadmill")
		local slats = t and t:FindFirstChild("Slats")
		local bb = t and t:FindFirstChild("Belt")
		local botRunning = b:GetAttribute("BotRunning") == true
		if slats and bb and ((owner and owner:GetAttribute("PFEOnTreadmill")) or botRunning) then
			local speed = math.clamp(((owner and owner:GetAttribute("PFEWalkSpeed")) or b:GetAttribute("BotWalkSpeed") or 24) * 0.35, 4, 30)
			local list = slats:GetChildren()
			local length = bb.Size.Z
			for i, slat in ipairs(list) do
				local z = ((i - 1) / #list * length + slatClock * speed) % length - length / 2
				slat.CFrame = bb.CFrame * CFrame.new(0, bb.Size.Y / 2 + slat.Size.Y / 2, z)
			end
		end
	end
end)
