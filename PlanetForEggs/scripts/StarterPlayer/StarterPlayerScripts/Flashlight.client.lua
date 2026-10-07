--!nocheck
-- (v41) The flashlight every player carries (Gear gives it with the bat and the raygun): its tile sits one slot left of the
-- raygun in the hotbar row (F / gamepad D-pad up takes it out or puts it away). Down in a cave you also give off a faint
-- glow of your own, so the dark is never solid black around you - but you need the torch to see where you're going.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local UI = require(api:WaitForChild("UIKit"))
local C = UI.C
local player = Players.LocalPlayer

local gui = UI.new("ScreenGui", {Name = "PFE_Flashlight", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 21}, player:WaitForChild("PlayerGui"))
local holder = UI.new("Frame", {Name = "EquipFlashlight", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -410, 1, -8), Size = UDim2.fromOffset(78, 78),
	BackgroundTransparency = 1}, gui)
local scale = UI.new("UIScale", {}, holder)
local button = UI.tile(holder, "Bolt2", "Light", Color3.fromRGB(255, 196, 60), UDim2.fromOffset(78, 78), nil, "EquipFlashlight")
local handsShade = UI.new("Frame", {Name = "HandsFull", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
	Size = UDim2.fromScale(1, 1), ZIndex = 12, Visible = false}, button)
UI.round(handsShade, 18)
local keyHint = UI.text(holder, "F", UDim2.fromOffset(20, 20), UDim2.fromOffset(6, 3), 16, C.White)
keyHint.TextXAlignment = Enum.TextXAlignment.Center; keyHint.ZIndex = 20
keyHint.Visible = not UI.isTouch()
-- a pulsing hint over the tile while you are in a cave without the light out
local caveHint = UI.text(holder, "DARK!", UDim2.new(1, 30, 0, 22), UDim2.new(0, -15, 0, -26), 18, Color3.fromRGB(255, 220, 110))
caveHint.TextXAlignment = Enum.TextXAlignment.Center; caveHint.TextWrapped = false; caveHint.Visible = false; caveHint.ZIndex = 20

local function tool()
	local character = player.Character
	return (character and character:FindFirstChild("Flashlight")) or player:FindFirstChildOfClass("Backpack") and player.Backpack:FindFirstChild("Flashlight")
end
local function equipped()
	local character = player.Character
	return character ~= nil and character:FindFirstChild("Flashlight") ~= nil
end
local function handsFull()
	return player:GetAttribute("PFECarrying") == true or player:GetAttribute("PFEHoldingStoredEgg") == true
end
local function click()
	local s = Instance.new("Sound"); s.SoundId = "rbxasset://sounds/switch.wav"; s.Volume = 0.5; s.Parent = SoundService
	s:Play(); game:GetService("Debris"):AddItem(s, 2)
end
local function toggle()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local light = tool()
	if not humanoid or not light then return end
	if equipped() then humanoid:UnequipTools() elseif not handsFull() then humanoid:EquipTool(light) end
	click()
end
button.Activated:Connect(toggle)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or player:GetAttribute("PFEPlanetMapOpen") then return end
	if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.DPadUp then toggle() end
end)

-- your own faint glow in the caves
local selfGlow = Instance.new("PointLight")
selfGlow.Name = "PFE_CaveGlow"; selfGlow.Range = 13; selfGlow.Brightness = 0.35; selfGlow.Color = Color3.fromRGB(200, 210, 255); selfGlow.Shadows = false

RunService.RenderStepped:Connect(function()
	local out = equipped()
	if out and handsFull() then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:UnequipTools() end
		out = false
	end
	local inCave = player:GetAttribute("PFECave") ~= nil
	button.BackgroundColor3 = out and Color3.fromRGB(255, 220, 90) or C.White
	handsShade.Visible = handsFull()
	holder.Visible = player:GetAttribute("PFEFlightActive") ~= true and player:GetAttribute("PFEMenuOpen") ~= true
		and player:GetAttribute("PFEPlanetMapOpen") ~= true
	caveHint.Visible = inCave and not out and holder.Visible
	if caveHint.Visible then caveHint.TextTransparency = 0.3 + 0.3 * math.sin(os.clock() * 5) end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	selfGlow.Parent = (inCave and root) or nil
	-- one slot left of the raygun (which sits one left of the bat, just left of the egg slots)
	local inventory = player.PlayerGui:FindFirstChild("EggInventory")
	local backpack = inventory and inventory:FindFirstChild("Backpack")
	local hotbar = backpack and backpack:FindFirstChild("Hotbar")
	local bag = backpack and backpack:FindFirstChild("OpenInventory")
	if hotbar and bag and hotbar.Size.Y.Offset > 8 then
		local slot = hotbar.Size.Y.Offset - 8
		local s = math.clamp(slot / 78, 0.5, 1.3)
		local half = math.max(0, bag.Position.X.Offset - 7)
		holder.Position = UDim2.new(0.5, -half - 6 - (78 * s + 6) * 2, 1, hotbar.Position.Y.Offset + hotbar.Size.Y.Offset - 4)
		scale.Scale = s
	else
		holder.Position = UDim2.new(0.5, -410, 1, -8 - UI.bottomMargin())
		local camera = workspace.CurrentCamera
		if camera then scale.Scale = math.clamp(UI.scaleFor(camera.ViewportSize), UI.minScale(), 1.1) end
	end
end)
