--!nocheck
-- (v34) our own Tab list - Roblox's player list is switched off for good (here and in the title screen). Like Roblox's
-- list, top right, with two stat columns - Coins and Speed - for the players and the bot explorers alike. Fits every
-- screen: it scales with the window, scrolls when the server is full, and phones get a small toggle button (no Tab key).
-- The planet tracker on the right steps down below it (Tracker.lua reads PFE_PlayerList.List).
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local UI = require(api:WaitForChild("UIKit"))

-- Roblox's list off, and kept off (anything that re-enables the core GUI is undone within a second)
local function hideCore()
	pcall(function()
		if StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList) then StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end
	end)
end
hideCore()

local W_NAME, W_STAT, ROW, HEAD = 168, 66, 28, 26
local WIDTH = W_NAME + W_STAT * 2
local gui = Instance.new("ScreenGui")
gui.Name = "PFE_PlayerList"; gui.ResetOnSpawn = false; gui.DisplayOrder = 30; gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local touch = UI.isTouch()
local panel = Instance.new("Frame")
panel.Name = "List"; panel.AnchorPoint = Vector2.new(1, 0); panel.Position = UDim2.new(1, -8, 0, 8)
panel.Size = UDim2.fromOffset(WIDTH, HEAD); panel.BackgroundTransparency = 1
panel.Parent = gui
local scale = Instance.new("UIScale"); scale.Parent = panel

local function cell(parent, text, x, w, bold, align)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1; label.Position = UDim2.fromOffset(x, 0); label.Size = UDim2.new(0, w, 1, 0)
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium; label.TextSize = 14; label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = align or Enum.TextXAlignment.Left; label.TextTruncate = Enum.TextTruncate.AtEnd; label.Text = text
	label.Parent = parent
	return label
end
local function bar(parent, order, height)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, height); f.BackgroundColor3 = Color3.fromRGB(25, 27, 32); f.BackgroundTransparency = 0.25; f.LayoutOrder = order
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 6); corner.Parent = f
	f.Parent = parent
	return f
end
-- the header (column names), then a scrolling list of rows
local header = bar(panel, 0, HEAD)
header.Name = "Header"
cell(header, "  Players", 4, W_NAME - 8, true)
cell(header, "Coins", W_NAME, W_STAT - 6, true, Enum.TextXAlignment.Right)
cell(header, "Speed", W_NAME + W_STAT, W_STAT - 8, true, Enum.TextXAlignment.Right)
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Rows"; scroll.Position = UDim2.fromOffset(0, HEAD + 2); scroll.Size = UDim2.new(1, 0, 0, 0)
scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0; scroll.ScrollBarThickness = 4; scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.CanvasSize = UDim2.new(); scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = panel
local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 2); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = scroll

-- phones: a small round button toggles the list (left of the corner, under the top bar)
local toggle
if touch then
	toggle = Instance.new("ImageButton")
	toggle.Name = "ListToggle"; toggle.AnchorPoint = Vector2.new(1, 0); toggle.Size = UDim2.fromOffset(40, 40)
	toggle.BackgroundColor3 = Color3.fromRGB(25, 27, 32); toggle.BackgroundTransparency = 0.25; toggle.AutoButtonColor = true
	toggle.Image = ""; toggle.Parent = gui
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = toggle
	for i = -1, 1 do   -- a "list" icon: three white bars
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5); line.Position = UDim2.new(0.5, 0, 0.5, i * 7); line.Size = UDim2.fromOffset(20, 3)
		line.BackgroundColor3 = Color3.new(1, 1, 1); line.BorderSizePixel = 0; line.Parent = toggle
	end
	panel.Visible = false
	toggle.Activated:Connect(function() panel.Visible = not panel.Visible end)
end

local rows = {}
local function row(key, name, userId, headPart)
	local r = rows[key]
	if r then return r end
	local frame = bar(scroll, 1, ROW)
	frame.Size = UDim2.new(1, -6, 0, ROW)
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1; icon.Size = UDim2.fromOffset(ROW - 6, ROW - 6); icon.Position = UDim2.fromOffset(4, 3); icon.Parent = frame
	local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(0.5, 0); ic.Parent = icon
	if userId and userId > 0 then
		task.spawn(function()
			local ok, thumb = pcall(function()
				return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
			end)
			if ok and icon.Parent then icon.Image = thumb end
		end)
	elseif headPart then   -- a bot: its avatar's head (hair, hat, shoulders) in a little viewport, framed like a headshot
		local view = Instance.new("ViewportFrame")
		view.BackgroundTransparency = 1; view.Size = UDim2.fromScale(1, 1); view.Parent = icon
		view.Ambient = Color3.fromRGB(170, 170, 170); view.LightColor = Color3.fromRGB(255, 255, 255); view.LightDirection = Vector3.new(-0.4, -0.6, 0.7)
		local vc = Instance.new("UICorner"); vc.CornerRadius = UDim.new(0.5, 0); vc.Parent = view
		local copy = headPart:Clone(); copy.Parent = view
		local camera = Instance.new("Camera"); camera.FieldOfView = 30
		if headPart:IsA("Model") then
			camera.CFrame = CFrame.lookAt(Vector3.new(1.3, 0.35, -4.4), Vector3.new(0, -0.2, 0))
		else
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.1, -4.2), Vector3.new(0, 0.05, 0))
		end
		camera.Parent = view; view.CurrentCamera = camera
	end
	local nameLabel = cell(frame, name, ROW + 4, W_NAME - ROW - 8, false)
	if key == player then nameLabel.TextColor3 = Color3.fromRGB(255, 220, 90) end
	r = {Frame = frame, Coins = cell(frame, "0", W_NAME, W_STAT - 6, false, Enum.TextXAlignment.Right),
		Speed = cell(frame, "0", W_NAME + W_STAT, W_STAT - 12, false, Enum.TextXAlignment.Right)}
	rows[key] = r
	return r
end

-- size and place for this screen
local function fit()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local vp = camera.ViewportSize
	local s = math.clamp(math.min(vp.X / 1150, vp.Y / 660), touch and 0.5 or 0.6, 1)
	scale.Scale = s
	local count = 0
	for _ in pairs(rows) do count += 1 end
	local want = count * (ROW + 2)
	local room = (vp.Y * (touch and 0.55 or 0.5)) / s - HEAD - 2
	local h = math.max(ROW, math.min(want, room))
	scroll.Size = UDim2.new(1, 0, 0, h)
	panel.Size = UDim2.fromOffset(WIDTH, HEAD + 2 + h)
	local top = touch and 50 or 8
	if touch then toggle.Position = UDim2.new(1, -62, 0, 4) end
	panel.Position = UDim2.new(1, -8, 0, top)
	-- where the list ends (gui space, below the top bar): the planet tracker steps down below it
	gui:SetAttribute("ListBottom", top + (HEAD + 2 + h) * s)
end

local function refresh()
	hideCore()
	local alive, list = {}, {}
	for _, other in ipairs(Players:GetPlayers()) do
		alive[other] = true
		local r = row(other, other.DisplayName, other.UserId)
		table.insert(list, {Row = r, Coins = other:GetAttribute("PFECoins") or 0, Speed = other:GetAttribute("PFESpeedPower") or 0})
	end
	local tracker = api:FindFirstChild("BotTracker")
	for _, entry in ipairs(tracker and tracker:GetChildren() or {}) do
		alive[entry] = true
		local r = row(entry, entry:GetAttribute("DisplayName") or entry.Name, entry:GetAttribute("UserId"),
			entry:FindFirstChild("Headshot") or entry:FindFirstChildWhichIsA("BasePart"))
		table.insert(list, {Row = r, Coins = entry:GetAttribute("PFECoins") or 0, Speed = entry:GetAttribute("PFESpeedPower") or 0})
	end
	-- richest first (like a leaderboard)
	table.sort(list, function(a, b) return a.Coins > b.Coins end)
	for i, item in ipairs(list) do
		item.Row.Frame.LayoutOrder = i
		item.Row.Coins.Text = Config.Format(math.floor(item.Coins))
		item.Row.Speed.Text = Config.Format(math.floor(item.Speed))
	end
	for key, r in pairs(rows) do
		if not alive[key] then r.Frame:Destroy(); rows[key] = nil end
	end
	fit()
end
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Tab then panel.Visible = not panel.Visible end
end)
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
-- hidden while a menu, the planet map, a flight or (v37) the Halloween join cutscene covers the screen
local function covered()
	local cutscene = player:GetAttribute("PFECutscene")
	return player:GetAttribute("PFEMenuOpen") == true or player:GetAttribute("PFEPlanetMapOpen") == true
		or player:GetAttribute("PFEFlightActive") == true or (cutscene ~= nil and cutscene ~= false)
end
task.spawn(function()
	while gui.Parent do
		local ok, err = pcall(refresh)
		if not ok then warn("[PFE] player list", err) end
		gui.Enabled = not covered()
		task.wait(1)
	end
end)
for _, key in ipairs({"PFEMenuOpen", "PFEPlanetMapOpen", "PFEFlightActive", "PFECutscene"}) do
	player:GetAttributeChangedSignal(key):Connect(function() gui.Enabled = not covered() end)
end
