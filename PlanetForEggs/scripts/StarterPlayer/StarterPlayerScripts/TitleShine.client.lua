--!nocheck
-- The OWNER / VIP rank plates over heads (the look of BattleAdminPanel's: chunky Fredoka One, a dark
-- outline, a drop shadow, a vertical gradient; OWNER gold, VIP green; they float and shimmer).
-- The server marks who gets one (player attribute PFETitle = "Owner" / "VIP", Admin.lua); this client
-- draws them all itself, in its PlayerGui, pinned (Adornee) to each player's CURRENT head and re-pinned
-- several times a second - so a respawn or Roblox swapping the head when the avatar loads can't lose it.
-- While someone carries a big egg over their head the plate rises above the egg.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FREDOKA = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local PLATES = {
	Owner = {Text = "OWNER", Top = Color3.fromRGB(255, 244, 160), Mid = Color3.fromRGB(255, 204, 58), Bottom = Color3.fromRGB(255, 120, 30),
		Shadow = Color3.fromRGB(140, 40, 10)},
	VIP = {Text = "VIP", Top = Color3.fromRGB(190, 255, 200), Mid = Color3.fromRGB(70, 220, 120), Bottom = Color3.fromRGB(20, 150, 80),
		Shadow = Color3.fromRGB(10, 70, 40)},
}
local plates = {} -- Player -> {Gui, Kind, Shine}

local function makePlate(other, kind)
	local style = PLATES[kind]
	local gui = Instance.new("BillboardGui")
	gui.Name = "PFETitle_" .. other.UserId
	gui.Size = UDim2.new(8, 0, 2, 0); gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 180; gui.AlwaysOnTop = true; gui.LightInfluence = 0; gui.ResetOnSpawn = false
	gui:SetAttribute("Kind", kind)
	local shadow = Instance.new("TextLabel")
	shadow.Name = "Shadow"; shadow.BackgroundTransparency = 1; shadow.Position = UDim2.fromScale(0.012, 0.08); shadow.Size = UDim2.fromScale(1, 0.92)
	shadow.FontFace = FREDOKA; shadow.TextScaled = true; shadow.Text = style.Text; shadow.TextColor3 = style.Shadow; shadow.Parent = gui
	local ss = Instance.new("UIStroke"); ss.Color = Color3.fromRGB(34, 27, 20); ss.Thickness = 3; ss.Parent = shadow
	local face = Instance.new("TextLabel")
	face.Name = "Title"; face.BackgroundTransparency = 1; face.Size = UDim2.fromScale(1, 0.92)
	face.FontFace = FREDOKA; face.TextScaled = true; face.Text = style.Text; face.TextColor3 = Color3.new(1, 1, 1); face.Parent = gui
	local fs = Instance.new("UIStroke"); fs.Color = Color3.fromRGB(34, 27, 20); fs.Thickness = 3.5; fs.Parent = face
	local shine = Instance.new("UIGradient")
	shine.Name = "Shine"; shine.Rotation = 90
	shine.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, style.Top), ColorSequenceKeypoint.new(0.45, style.Mid), ColorSequenceKeypoint.new(1, style.Bottom)})
	shine.Parent = face
	gui.Parent = playerGui
	return {Gui = gui, Kind = kind, Shine = shine}
end

local function drop(other)
	local plate = plates[other]
	if plate then plates[other] = nil; plate.Gui:Destroy() end
end
Players.PlayerRemoving:Connect(drop)

local function eggLift(other, character, head)
	local egg = character:FindFirstChild("CarriedPlanetEgg")
	if not egg and other == player then egg = workspace:FindFirstChild("LocalEquippedEgg") end
	if not egg or not egg:IsA("Model") then return 0 end
	local ok, cf, size = pcall(function() return egg:GetBoundingBox() end)
	if not ok then return 0 end
	return math.max(0, cf.Position.Y + size.Y * 0.5 - head.Position.Y - 2.2)
end

local clock, tick = 0, 0
RunService.RenderStepped:Connect(function(dt)
	clock += dt; tick += dt
	if tick < 0.05 then return end
	tick = 0
	for _, other in ipairs(Players:GetPlayers()) do
		local kind = other:GetAttribute("PFETitle")
		local character = other.Character
		local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
		if not PLATES[kind] or not head or other:GetAttribute("PFEHideTitle") == true then
			drop(other)
		else
			local plate = plates[other]
			if plate and (plate.Kind ~= kind or not plate.Gui.Parent) then drop(other); plate = nil end
			if not plate then plate = makePlate(other, kind); plates[other] = plate end
			if plate.Gui.Adornee ~= head then plate.Gui.Adornee = head end
			local base = head.Name == "Head" and 3.2 or 4.6
			plate.Gui.StudsOffset = Vector3.new(0, base + eggLift(other, character, head) + math.sin(clock * 2.2) * 0.15, 0)
			plate.Shine.Offset = Vector2.new(0, math.sin(clock * 3) * 0.18)
		end
	end
end)
