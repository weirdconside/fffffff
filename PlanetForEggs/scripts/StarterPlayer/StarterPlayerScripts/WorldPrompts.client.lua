--!nocheck
-- Who may see which prompt, plus a big tappable custom prompt UI:
--  * planet pickups: shared by everyone on that planet (hidden elsewhere and during Meteor Run);
--  * base prompts: Hatch/Launch only for the owner, Steal only for visitors of an
--    unlocked, unprotected base.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local api = ReplicatedStorage:WaitForChild("PFE")
local UI = require(api:WaitForChild("UIKit"))
local C = UI.C
local world = workspace:WaitForChild("PlanetForEggs")

local function ownerOf(object)
	local node = object
	while node and node ~= workspace do
		local owner = node:GetAttribute("OwnerUserId")
		if owner ~= nil then return tonumber(owner), node end
		node = node.Parent
	end
	return nil
end
local function baseOf(object)
	local node = object
	while node and node ~= workspace do
		if node.Parent == world.Bases then return node end
		node = node.Parent
	end
	return nil
end

-- ---------------------------------------------------------------- pickups
local pickupFolder = workspace:WaitForChild("PFE_Pickups")
local function pickupPlanet(object)
	local node = object
	while node and node.Parent ~= pickupFolder do node = node.Parent end
	return node and node.Name
end
local function configurePickup(object)
	local planet = pickupPlanet(object)
	if planet == nil then return end
	local here = planet == player:GetAttribute("PFETrackerPlanet") and player:GetAttribute("PFEMinigame") ~= true
	if object:IsA("BasePart") then object.LocalTransparencyModifier = here and 0 or 1
	elseif object:IsA("ProximityPrompt") then object.Enabled = here
	elseif object:IsA("BillboardGui") or object:IsA("SurfaceGui") then object.Enabled = here
	elseif object:IsA("ParticleEmitter") or object:IsA("PointLight") then object.Enabled = here end
end
local function configureAll()
	for _, object in ipairs(pickupFolder:GetDescendants()) do configurePickup(object) end
end
configureAll()
player:GetAttributeChangedSignal("PFETrackerPlanet"):Connect(configureAll)
player:GetAttributeChangedSignal("PFEMinigame"):Connect(configureAll)
pickupFolder.DescendantAdded:Connect(function(object)
	task.defer(function()
		if object.Parent then
			configurePickup(object)
			for _, child in ipairs(object:GetDescendants()) do configurePickup(child) end
		end
	end)
end)

-- ---------------------------------------------------------------- base prompts
local function stealAllowed(base)
	local owner = base:GetAttribute("OwnerUserId") or 0
	if owner == 0 or owner == player.UserId then return false end
	if (base:GetAttribute("ShieldUntil") or 0) > workspace:GetServerTimeNow() then return false end
	if base:GetAttribute("Protected") then return false end
	return true
end
-- Hatch! once the egg is ready, Skip Growth! (Robux) while it is still growing
local function eggPromptEnabled(prompt, mine)
	local model = prompt:FindFirstAncestorWhichIsA("Model")
	local ready = model == nil or model:GetAttribute("Ready") ~= false
	if prompt.Name == "SkipGrowth" then return mine and not ready end
	return mine and ready
end
local function refreshBase(base)
	local mine = base:GetAttribute("OwnerUserId") == player.UserId
	for _, prompt in ipairs(base:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") then
			if prompt.Name == "StealEgg" then
				prompt.Enabled = stealAllowed(base)
			elseif prompt.Name == "HatchGrownEgg" or prompt.Name == "SkipGrowth" then
				prompt.Enabled = eggPromptEnabled(prompt, mine)
			else
				prompt.Enabled = mine
			end
		end
	end
end
local basePrompts = {} -- prompt -> base
for _, base in ipairs(world.Bases:GetChildren()) do
	for _, item in ipairs(base:GetDescendants()) do
		if item:IsA("ProximityPrompt") then basePrompts[item] = base end
	end
	base.DescendantAdded:Connect(function(item) if item:IsA("ProximityPrompt") then basePrompts[item] = base end end)
	base.DescendantRemoving:Connect(function(item) basePrompts[item] = nil end)
	for _, attribute in ipairs({"OwnerUserId", "ShieldUntil", "Protected"}) do
		base:GetAttributeChangedSignal(attribute):Connect(function() refreshBase(base) end)
	end
	base.DescendantAdded:Connect(function(item)
		if item:IsA("ProximityPrompt") then task.defer(refreshBase, base) end
		if item:IsA("Model") then item:GetAttributeChangedSignal("Ready"):Connect(function() refreshBase(base) end) end
	end)
	refreshBase(base)
end
-- shields expire on the server clock, re-check steal prompts every second
task.spawn(function()
	while true do
		task.wait(1)
		for prompt, base in pairs(basePrompts) do
			if prompt.Name == "StealEgg" then
				local allowed = stealAllowed(base)
				if prompt.Enabled ~= allowed then prompt.Enabled = allowed end
			elseif prompt.Name == "HatchGrownEgg" or prompt.Name == "SkipGrowth" then
				local enabled = eggPromptEnabled(prompt, base:GetAttribute("OwnerUserId") == player.UserId)
				if prompt.Enabled ~= enabled then prompt.Enabled = enabled end
			end
		end
	end
end)

-- ---------------------------------------------------------------- custom prompt UI
local shown = {}
local function blocked()
	return player:GetAttribute("PFEFlightActive") or player:GetAttribute("PFEPlanetMapOpen") or player:GetAttribute("PFEMenuOpen")
end
local function hide(prompt)
	local record = shown[prompt]
	if not record then return end
	shown[prompt] = nil
	for _, link in ipairs(record.Links) do link:Disconnect() end
	if record.Tween then record.Tween:Cancel() end
	record.Gui:Destroy()
end
local colors = {StealEgg = C.Red, HatchGrownEgg = C.Green, SkipGrowth = C.Gold, OpenRocketHub = C.Orange, FlyHome = C.Orange, CollectPickup = C.Gold}
-- real Robux prices of the skip products (falls back to the configured display price)
local prices = {}
local function robuxPrice(prompt)
	local id = prompt:GetAttribute("ProductId") or 0
	if id > 0 and prices[id] == nil then
		prices[id] = false
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, Enum.InfoType.Product)
			if ok and info and info.PriceInRobux then prices[id] = info.PriceInRobux end
		end)
	end
	return prices[id] or prompt:GetAttribute("Price") or 0
end
local function promptHeight(prompt)
	local model = prompt:FindFirstAncestorWhichIsA("Model")
	local top = model and model:GetAttribute("TopOffset")
	return top and top + 3.2 or 3.4
end
ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
	local owner = ownerOf(prompt)
	if owner ~= nil and owner ~= player.UserId and prompt.Name ~= "StealEgg" and baseOf(prompt) == nil then return end
	hide(prompt)
	local part = prompt.Parent
	if part and part:IsA("Attachment") then part = part.Parent end
	if not part or not part:IsA("BasePart") then return end
	local touch = inputType == Enum.ProximityPromptInputType.Touch
	-- short (phone) screens get a smaller card: the design size times k
	local camera = workspace.CurrentCamera
	local k = (camera and camera.ViewportSize.Y < 560) and 0.8 or 1
	local width, height = touch and 230 or 250, touch and 84 or 76
	local gui = UI.new("BillboardGui", {Name = "PFEPrompt", Enabled = not blocked(), Adornee = part, Size = UDim2.fromOffset(math.floor(width * k), math.floor(height * k)),
		StudsOffsetWorldSpace = Vector3.new(0, promptHeight(prompt), 0), AlwaysOnTop = true, Active = true, MaxDistance = math.huge, LightInfluence = 0}, player.PlayerGui) -- (shown whenever the prompt is: the character is close, however far the camera is)
	local color = colors[prompt.Name] or C.Purple
	local card = UI.card(gui, color, UDim2.fromOffset(width - 8, height - 10), UDim2.fromOffset(4, 4), "Prompt")
	local fit = UI.new("UIScale", {Name = "Fit", Scale = k}, card)
	local keyText = touch and "TAP" or inputType == Enum.ProximityPromptInputType.Gamepad and "X" or UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	local keyButton = UI.button(card, keyText, C.Ink, UDim2.fromOffset(touch and 64 or 54, touch and 56 or 48), UDim2.fromOffset(8, 6), nil, {TextSize = touch and 20 or 22})
	local action = UI.text(card, prompt.ActionText, UDim2.new(1, -90, 0, 30), UDim2.fromOffset(touch and 80 or 70, 4), 22)
	action.TextWrapped = false; action.TextScaled = true
	UI.new("UITextSizeConstraint", {MaxTextSize = 22}, action)
	local object = UI.text(card, prompt.ObjectText, UDim2.new(1, -90, 0, 20), UDim2.fromOffset(touch and 80 or 70, 32), 14, C.White)
	object.TextTruncate = Enum.TextTruncate.AtEnd
	if prompt.Name == "SkipGrowth" then
		-- Steal an Egg style: the Robux price sits right on the card
		object.Visible = false
		local x = touch and 80 or 70
		UI.icon(card, "Robux", UDim2.fromOffset(24, 24), UDim2.fromOffset(x, 36), {ZIndex = 9})
		local priceLabel = UI.text(card, tostring(robuxPrice(prompt)), UDim2.new(1, -(x + 40), 0, 26), UDim2.fromOffset(x + 30, 35), 22, C.White)
		priceLabel.ZIndex = 9
		task.spawn(function()
			while priceLabel.Parent do
				local amount = tostring(robuxPrice(prompt))
				if priceLabel.Text ~= amount then priceLabel.Text = amount end
				gui.StudsOffsetWorldSpace = Vector3.new(0, promptHeight(prompt), 0)
				task.wait(0.5)
			end
		end)
	end
	local track, set = UI.bar(card, UDim2.new(1, -96, 0, 8), UDim2.new(0, touch and 80 or 70, 1, -16), C.Gold)
	set(0)
	track.Visible = prompt.HoldDuration > 0 -- instant prompts need no hold bar
	local record = {Gui = gui, Links = {}}
	shown[prompt] = record
	local function link(signal, callback) table.insert(record.Links, signal:Connect(callback)) end
	link(prompt.PromptButtonHoldBegan, function()
		if record.Tween then record.Tween:Cancel() end
		local fill = track:FindFirstChild("Fill")
		fill.Size = UDim2.fromScale(0, 1)
		record.Tween = UI.tween(fill, {Size = UDim2.fromScale(1, 1)}, math.max(0.05, prompt.HoldDuration), Enum.EasingStyle.Linear)
	end)
	link(prompt.PromptButtonHoldEnded, function()
		if record.Tween then record.Tween:Cancel() end
		local fill = track:FindFirstChild("Fill")
		if fill then fill.Size = UDim2.fromScale(0, 1) end
	end)
	link(prompt.Triggered, function()
		fit.Scale = k * 1.12; UI.tween(fit, {Scale = k}, 0.25, Enum.EasingStyle.Back)
	end)
	link(keyButton.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then prompt:InputHoldBegin() end
	end)
	link(keyButton.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then prompt:InputHoldEnd() end
	end)
end)
ProximityPromptService.PromptHidden:Connect(hide)
local function refreshVisibility()
	local visible = not blocked()
	for _, record in pairs(shown) do record.Gui.Enabled = visible end
end
for _, attribute in ipairs({"PFEFlightActive", "PFEPlanetMapOpen", "PFEMenuOpen"}) do
	player:GetAttributeChangedSignal(attribute):Connect(refreshVisibility)
end
