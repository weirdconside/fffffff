--!nocheck
-- Steal an Egg's income popups (its ActiveAssetIncomePopup): once a second a green "+1.2K" appears
-- over each of your pets at your base - what that pet just earned - rises and fades out. The look is
-- SaE's Cash billboard: 8 x 3 studs (scaled with the pet), green heavy text with a light gradient and
-- a dark outline, fading in over 0.2 s and out from 0.85 s, gone after 1.4 s.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local player = Players.LocalPlayer
local FONT = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local GREEN = Color3.fromRGB(26, 255, 0)

local folder = Instance.new("Folder")
folder.Name = "PFE_IncomePopups"
folder.Parent = workspace

local atBase, doubled = true, false
api:WaitForChild("State").OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	if payload.Planet ~= nil then atBase = payload.Planet == "Base" end
	if not payload.Light then doubled = type(payload.Passes) == "table" and payload.Passes.DoubleMoney == true end
end)

local function myPets()
	local world = workspace:FindFirstChild("PlanetForEggs")
	local bases = world and world:FindFirstChild("Bases")
	for _, base in ipairs(bases and bases:GetChildren() or {}) do
		if base:GetAttribute("OwnerUserId") == player.UserId then
			local pets = base:FindFirstChild("ActivePets")
			return pets and pets:GetChildren() or {}
		end
	end
	return {}
end

local function popup(pet, amount)
	local ok, box, size = pcall(function() return pet:GetBoundingBox() end)
	if not ok then return end
	local camera = workspace.CurrentCamera
	local start = box.Position - Vector3.new(0, size.Y / 1.5, 0) + Vector3.new(0, size.Y, 0)
	if camera and (camera.CFrame.Position - start).Magnitude > 160 then return end
	local k = math.clamp(math.min(size.X / 2, size.Y / 5.73, size.Z / 5.3), 0.9, 5)
	local anchor = Instance.new("Part")
	anchor.Name = "IncomePopup"; anchor.Anchored = true; anchor.CanCollide = false; anchor.CanQuery = false; anchor.CanTouch = false
	anchor.Transparency = 1; anchor.Size = Vector3.new(0.2, 0.2, 0.2); anchor.CFrame = CFrame.new(start); anchor.Parent = folder
	local gui = Instance.new("BillboardGui")
	gui.Name = "Cash"; gui.Size = UDim2.fromScale(8 * k, 3 * k); gui.StudsOffset = Vector3.new(0, 2, 0); gui.AlwaysOnTop = true
	gui.MaxDistance = 160; gui.LightInfluence = 0; gui.Adornee = anchor; gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Name = "Money"; text.BackgroundTransparency = 1; text.Size = UDim2.fromScale(0.8, 0.4); text.Position = UDim2.fromScale(0.1, 0.3)
	text.FontFace = FONT; text.TextScaled = true; text.TextColor3 = GREEN; text.Text = "+" .. Config.Format(math.floor(amount + 0.5))
	text.TextTransparency = 1; text.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(171, 171, 171)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))})
	gradient.Rotation = 90; gradient.Parent = text
	local stroke = Instance.new("UIStroke"); stroke.Color = Color3.new(0, 0, 0); stroke.Thickness = 2; stroke.Transparency = 1; stroke.Parent = text
	local fadeIn, fadeOut = TweenInfo.new(0.2, Enum.EasingStyle.Quad), TweenInfo.new(0.55, Enum.EasingStyle.Quad)
	TweenService:Create(text, fadeIn, {TextTransparency = 0}):Play()
	TweenService:Create(stroke, fadeIn, {Transparency = 0}):Play()
	TweenService:Create(anchor, TweenInfo.new(1.4, Enum.EasingStyle.Quad), {CFrame = CFrame.new(start + Vector3.new(0, size.Y * 0.75, 0))}):Play()
	task.delay(0.85, function()
		if not text.Parent then return end
		TweenService:Create(text, fadeOut, {TextTransparency = 1}):Play()
		TweenService:Create(stroke, fadeOut, {Transparency = 1}):Play()
	end)
	Debris:AddItem(anchor, 1.4)
end

task.spawn(function()
	while true do
		task.wait(1)
		if atBase and player:GetAttribute("PFEFlightActive") ~= true then
			local shown = 0
			for _, pet in ipairs(myPets()) do
				local income = tonumber(pet:GetAttribute("Income")) or 0
				if income > 0 and shown < 8 then shown += 1; popup(pet, income * (doubled and 2 or 1)) end
			end
		end
	end
end)
