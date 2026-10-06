--!nocheck
-- The admin's side (server: Admin.lua).
--  * For everyone: the [OWNER] chat tag of the owners; the powers an admin gave you (fly, noclip,
--    infinite jump, gravity - your own character moves, so it's real for everyone); announcements,
--    disco and lighting from the admins.
--  * For admins only (the PFEAdmin attribute, set by the server): an Infinite Yield-style command bar
--    at the top (";" to type, Enter to run, suggestions as you type), the command list, and the admin
--    abuse board (every server). On phones a crown button opens it. Every command runs on the server.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local UI = require(api:WaitForChild("UIKit"))
local player = Players.LocalPlayer
local C = UI.C
local GOLD = Color3.fromRGB(255, 200, 60)

-- ---------------------------------------------------------------- the owners' chat tag
pcall(function()
	TextChatService.OnIncomingMessage = function(message)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local sender = source and Players:GetPlayerByUserId(source.UserId)
		if source and (Config.Owners[source.UserId] or (sender and Config.IsOwner(sender))) then
			props.PrefixText = "<font color='#FFC83C'><b>[OWNER]</b></font> " .. message.PrefixText
		else
			if sender and sender:GetAttribute("PFEVIP") == true then
				props.PrefixText = "<font color='#FFD24A'><b>[VIP]</b></font> " .. message.PrefixText
			end
		end
		return props
	end
end)

-- ---------------------------------------------------------------- powers on your own character
local flyMover, flyGyro
local function stopFly(humanoid)
	if flyMover then flyMover:Destroy(); flyMover = nil end
	if flyGyro then flyGyro:Destroy(); flyGyro = nil end
	if humanoid then humanoid.PlatformStand = false end
end
RunService.RenderStepped:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local speed = player:GetAttribute("PFEAdminFly")
	if not (speed and humanoid and root and humanoid.Health > 0) then
		if flyMover then stopFly(humanoid) end
		return
	end
	if not flyMover or flyMover.Parent ~= root then
		stopFly(humanoid)
		flyMover = Instance.new("BodyVelocity"); flyMover.MaxForce = Vector3.new(1e9, 1e9, 1e9); flyMover.P = 1e4; flyMover.Parent = root
		flyGyro = Instance.new("BodyGyro"); flyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9); flyGyro.P = 1e4; flyGyro.Parent = root
	end
	humanoid.PlatformStand = true
	local camera = workspace.CurrentCamera
	local move = humanoid.MoveDirection
	local up = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) or humanoid.Jump then up += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then up -= 1 end
	local velocity = move * speed + Vector3.new(0, up * speed, 0)
	if move.Magnitude > 0.1 and camera then velocity += Vector3.new(0, camera.CFrame.LookVector.Y * move.Magnitude * speed, 0) end
	flyMover.Velocity = velocity
	if camera then flyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + camera.CFrame.LookVector * Vector3.new(1, 0, 1) + Vector3.new(0, 0, 0.001)) end
end)
RunService.Stepped:Connect(function()
	if player:GetAttribute("PFEAdminNoclip") ~= true then return end
	local character = player.Character
	for _, part in ipairs(character and character:GetDescendants() or {}) do
		if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
	end
end)
UserInputService.JumpRequest:Connect(function()
	if player:GetAttribute("PFEAdminInfJump") ~= true then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
end)
local savedGravity
player:GetAttributeChangedSignal("PFEAdminGravity"):Connect(function()
	local g = player:GetAttribute("PFEAdminGravity")
	if g then
		savedGravity = savedGravity or workspace.Gravity
		workspace.Gravity = g
	elseif savedGravity then
		workspace.Gravity = savedGravity; savedGravity = nil
	end
end)

-- ---------------------------------------------------------------- what the admins do to everyone's screen
local gui = UI.new("ScreenGui", {Name = "PFE_Admin", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets}, player:WaitForChild("PlayerGui"))
local function announce(text, from, style)
	local band = UI.new("Frame", {Name = "Announcement", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -120),
		Size = UDim2.new(0.8, 0, 0, style == "Giant" and 110 or 92), BackgroundColor3 = Color3.fromRGB(16, 14, 30), BackgroundTransparency = 0.1, ZIndex = 60}, gui)
	UI.round(band, 18); UI.stroke(band, 3, GOLD)
	UI.new("UISizeConstraint", {MaxSize = Vector2.new(760, 200)}, band)
	local head = UI.text(band, "📢 " .. (from and ("ADMIN " .. string.upper(from)) or "ADMIN"), UDim2.new(1, -20, 0, 30), UDim2.fromOffset(10, 6), 24, GOLD)
	head.TextXAlignment = Enum.TextXAlignment.Center; head.ZIndex = 61; head.TextWrapped = false
	local body = UI.text(band, text, UDim2.new(1, -20, 1, -44), UDim2.fromOffset(10, 38), style == "Giant" and 34 or 26, C.White)
	body.TextXAlignment = Enum.TextXAlignment.Center; body.ZIndex = 61; body.TextScaled = true
	UI.new("UITextSizeConstraint", {MaxTextSize = style == "Giant" and 38 or 28}, body)
	UI.tween(band, {Position = UDim2.new(0.5, 0, 0, 70)}, 0.4, Enum.EasingStyle.Back)
	task.delay(7, function()
		UI.tween(band, {Position = UDim2.new(0.5, 0, 0, -140)}, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.4, function() band:Destroy() end)
	end)
end
local discoUntil = 0
local function disco(seconds)
	discoUntil = os.clock() + seconds
	local grade = Lighting:FindFirstChild("PFEDisco") or Instance.new("ColorCorrectionEffect")
	grade.Name = "PFEDisco"; grade.Parent = Lighting
	task.spawn(function()
		while os.clock() < discoUntil and grade.Parent do
			local hue = (os.clock() * 0.6) % 1
			grade.TintColor = Color3.fromHSV(hue, 0.55, 1); grade.Saturation = 0.4
			task.wait(0.05)
		end
		grade:Destroy()
	end)
end
api:WaitForChild("Effect").OnClientEvent:Connect(function(kind, payload)
	payload = type(payload) == "table" and payload or {}
	if kind == "AdminAnnounce" then
		announce(tostring(payload.Text or ""), payload.From, payload.Style)
	elseif kind == "AdminLighting" then
		if payload.ClockTime then Lighting.ClockTime = payload.ClockTime end
		if payload.FogEnd then Lighting.FogEnd = payload.FogEnd end
	elseif kind == "AdminDisco" then
		disco(tonumber(payload.Seconds) or 30)
	end
end)

-- ---------------------------------------------------------------- the admin panel
local remote = api:WaitForChild("Admin", 30)
local built = false
local function buildPanel()
	if built or not remote then return end
	built = true
	local DARK, MID, LINE = Color3.fromRGB(24, 25, 32), Color3.fromRGB(36, 38, 48), Color3.fromRGB(70, 74, 92)
	local panel = UI.new("Frame", {Name = "AdminBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(360, 30), BackgroundColor3 = DARK, BackgroundTransparency = 0.05, Visible = not UI.isTouch(), ZIndex = 50}, gui)
	UI.round(panel, 8); UI.stroke(panel, 1.5, LINE)
	local scale = UI.new("UIScale", {}, panel)
	local crown = UI.new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromOffset(26, 30), Text = "👑", TextSize = 16, ZIndex = 51}, panel)
	local box = UI.new("TextBox", {Name = "Command", BackgroundColor3 = MID, Position = UDim2.fromOffset(26, 4), Size = UDim2.new(1, -130, 0, 22),
		Text = "", PlaceholderText = "command  ( ; to type )", TextColor3 = C.White, PlaceholderColor3 = Color3.fromRGB(140, 145, 165),
		Font = Enum.Font.Code, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 51}, panel)
	UI.round(box, 5); UI.new("UIPadding", {PaddingLeft = UDim.new(0, 6)}, box)
	local function smallButton(text, x, name, width)
		local b = UI.new("TextButton", {Name = name, BackgroundColor3 = MID, Position = UDim2.new(1, x, 0, 4), Size = UDim2.fromOffset(width, 22),
			Text = text, TextColor3 = C.White, Font = Enum.Font.GothamBold, TextSize = 12, ZIndex = 51, AutoButtonColor = true}, panel)
		UI.round(b, 5)
		return b
	end
	local listButton = smallButton("CMD", -100, "Cmds", 40)
	local abuseButton = smallButton("ABUSE", -56, "Abuse", 52)
	abuseButton.TextColor3 = GOLD
	local output = UI.new("TextLabel", {Name = "Output", BackgroundTransparency = 1, Position = UDim2.new(0, 6, 1, 2), Size = UDim2.new(1, -12, 0, 18),
		Text = "", TextColor3 = Color3.fromRGB(150, 255, 170), Font = Enum.Font.Code, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.4, ZIndex = 51}, panel)
	local suggest = UI.new("Frame", {Name = "Suggestions", BackgroundColor3 = DARK, Position = UDim2.new(0, 26, 1, 2), Size = UDim2.new(1, -130, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 55}, panel)
	UI.round(suggest, 5); UI.stroke(suggest, 1, LINE); UI.list(suggest, 0)

	local commands = {}
	task.spawn(function()
		local ok, result = pcall(function() return remote:InvokeServer("!list") end)
		if ok and type(result) == "table" and result.List then commands = result.List end
	end)
	local function say(text, good)
		output.Text = text or ""
		output.TextColor3 = good == false and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(150, 255, 170)
		local stamp = os.clock(); output:SetAttribute("Stamp", stamp)
		task.delay(5, function() if output:GetAttribute("Stamp") == stamp then output.Text = "" end end)
	end

	-- the admin's own screen
	local esp = {}
	local function setEsp(on)
		for _, h in pairs(esp) do h:Destroy() end
		esp = {}
		if not on then return end
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and other.Character then
				local h = Instance.new("Highlight"); h.FillColor = Color3.fromRGB(255, 80, 80); h.FillTransparency = 0.6
				h.OutlineColor = Color3.new(1, 1, 1); h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; h.Adornee = other.Character; h.Parent = gui
				esp[other] = h
			end
		end
	end
	local listWindow, abuseWindow
	-- view: the camera follows the watched player, and comes back to them each time they respawn
	-- (and each time you do: Roblox puts the camera back on your own character then)
	local watching, watchLinks = nil, {}
	local function aimAt(target)
		local camera = workspace.CurrentCamera
		local character = target and target.Character
		local humanoid = character and (character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5))
		if watching == target and humanoid and camera then camera.CameraSubject = humanoid end
	end
	local function stopWatching()
		watching = nil
		for _, link in ipairs(watchLinks) do link:Disconnect() end
		watchLinks = {}
		local camera = workspace.CurrentCamera
		if camera then camera.CameraSubject = player.Character and player.Character:FindFirstChildOfClass("Humanoid") end
	end
	local function watch(target)
		stopWatching()
		watching = target
		table.insert(watchLinks, target.CharacterAdded:Connect(function() task.wait(0.1); aimAt(target) end))
		table.insert(watchLinks, player.CharacterAdded:Connect(function() task.wait(0.3); aimAt(target) end))
		table.insert(watchLinks, Players.PlayerRemoving:Connect(function(p) if p == target then stopWatching() end end))
		task.spawn(aimAt, target)
	end
	local function clientAction(action)
		if type(action) ~= "table" then return end
		local camera = workspace.CurrentCamera
		if action.Action == "view" and action.Target then
			watch(action.Target)
		elseif action.Action == "unview" then
			stopWatching()
		elseif action.Action == "esp" then setEsp(action.On)
		elseif action.Action == "fov" then camera.FieldOfView = action.Value
		elseif action.Action == "cmds" and listWindow then listWindow.Visible = true
		end
	end
	local function run(line)
		if line == "" then return end
		local ok, result = pcall(function() return remote:InvokeServer(line) end)
		if not ok or type(result) ~= "table" then say("No answer from the server", false); return end
		say(result.Text, result.Ok)
		clientAction(result.Client)
	end

	-- suggestions: commands starting with what you type
	local function refreshSuggest()
		for _, c in ipairs(suggest:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		local typed = string.lower(string.match(box.Text, "^[;:]?(%S*)") or "")
		local hasArgs = string.find(box.Text, "%s") ~= nil
		if typed == "" or hasArgs then suggest.Visible = false; return end
		local shown = 0
		for _, c in ipairs(commands) do
			local match
			for _, n in ipairs(c.Names) do if string.sub(n, 1, #typed) == typed then match = n; break end end
			if match and shown < 6 then
				shown += 1
				local b = UI.new("TextButton", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Text = "  " .. match .. " " .. c.Args .. "  —  " .. c.Desc,
					TextColor3 = C.White, Font = Enum.Font.Code, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
					LayoutOrder = shown, ZIndex = 56}, suggest)
				b.Activated:Connect(function() box.Text = match .. " "; box:CaptureFocus(); box.CursorPosition = #box.Text + 1 end)
			end
		end
		suggest.Visible = shown > 0
	end
	box:GetPropertyChangedSignal("Text"):Connect(refreshSuggest)
	box.FocusLost:Connect(function(enter)
		task.delay(0.15, function() suggest.Visible = false end)
		if enter then
			local line = box.Text
			box.Text = ""
			run(line)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.Semicolon then
			panel.Visible = true
			task.defer(function() box:CaptureFocus(); box.Text = "" end)
		end
	end)

	-- windows
	local function window(title, size)
		local w = UI.new("Frame", {Name = title, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = size,
			BackgroundColor3 = DARK, Visible = false, ZIndex = 52}, gui)
		UI.round(w, 10); UI.stroke(w, 1.5, LINE)
		UI.new("UIScale", {}, w)
		local t = UI.new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -50, 0, 26), Text = title,
			TextColor3 = GOLD, Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53}, w)
		local close = UI.new("TextButton", {BackgroundColor3 = MID, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 5), Size = UDim2.fromOffset(24, 22),
			Text = "×", TextColor3 = C.White, Font = Enum.Font.GothamBold, TextSize = 16, ZIndex = 53}, w)
		UI.round(close, 5)
		close.Activated:Connect(function() w.Visible = false end)
		local scroll = UI.new("ScrollingFrame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 34), Size = UDim2.new(1, -16, 1, -42),
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5, ZIndex = 53, BorderSizePixel = 0}, w)
		return w, scroll
	end
	local listScroll
	listWindow, listScroll = window("Commands", UDim2.fromOffset(420, 330))
	UI.list(listScroll, 1)
	local function fillList()
		for _, c in ipairs(listScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		for i, c in ipairs(commands) do
			local b = UI.new("TextButton", {BackgroundColor3 = i % 2 == 0 and MID or DARK, BackgroundTransparency = 0.2, Size = UDim2.new(1, -6, 0, 20),
				Text = " " .. table.concat(c.Names, " / ") .. " " .. c.Args .. "  —  " .. c.Desc, TextColor3 = C.White, Font = Enum.Font.Code, TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = i, ZIndex = 54}, listScroll)
			b.Activated:Connect(function() box.Text = c.Names[1] .. " "; panel.Visible = true; box:CaptureFocus(); listWindow.Visible = false end)
		end
	end
	listButton.Activated:Connect(function() fillList(); listWindow.Visible = not listWindow.Visible; abuseWindow.Visible = false end)

	local abuseScroll
	abuseWindow, abuseScroll = window("Admin Abuse  (every server)", UDim2.fromOffset(420, 360))
	UI.new("UIGridLayout", {CellSize = UDim2.fromOffset(128, 44), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder}, abuseScroll)
	local function abuse(label, color, kind, args, order)
		local b = UI.new("TextButton", {BackgroundColor3 = color, Text = label, TextColor3 = C.White, Font = Enum.Font.GothamBold, TextSize = 13,
			TextWrapped = true, LayoutOrder = order, ZIndex = 54}, abuseScroll)
		UI.round(b, 8); UI.stroke(b, 1.5, Color3.fromRGB(10, 10, 20))
		local armed = false
		b.Activated:Connect(function()
			if kind == "Restart" and not armed then
				armed = true; b.Text = "Sure? tap again"
				task.delay(3, function() armed = false; b.Text = label end)
				return
			end
			local a = typeof(args) == "function" and args() or args
			local ok, result = pcall(function() return remote:InvokeServer("!abuse", kind, a) end)
			say(ok and type(result) == "table" and result.Text or "Failed", ok and type(result) == "table" and result.Ok)
		end)
	end
	local PURPLE, GREEN, ORANGE, BLUE, RED, PINK = Color3.fromRGB(120, 70, 220), Color3.fromRGB(40, 160, 80), Color3.fromRGB(230, 140, 30),
		Color3.fromRGB(40, 110, 220), Color3.fromRGB(200, 50, 60), Color3.fromRGB(220, 70, 160)
	local o = 0
	local function nextOrder() o += 1; return o end
	abuse("📢 Announce (the text in the bar)", BLUE, "Announce", function() return {Text = box.Text ~= "" and box.Text or "Admin abuse!"} end, nextOrder())
	abuse("👤 Giant admins in the sky", PURPLE, "Silhouettes", {Seconds = 90}, nextOrder())
	abuse("🍀 Luck x2 · 15 min", GREEN, "Luck", {Multiplier = 2, Minutes = 15}, nextOrder())
	abuse("🍀 Luck x5 · 10 min", GREEN, "Luck", {Multiplier = 5, Minutes = 10}, nextOrder())
	abuse("💰 Coins x2 · 15 min", ORANGE, "Coins", {Multiplier = 2, Minutes = 15}, nextOrder())
	abuse("💰 Coins x5 · 10 min", ORANGE, "Coins", {Multiplier = 5, Minutes = 10}, nextOrder())
	abuse("🥚 Egg rain", PINK, "EggRain", {Count = 2}, nextOrder())
	abuse("🪙 Coin rain (10 min income)", ORANGE, "CoinRain", {Minutes = 10}, nextOrder())
	abuse("☄️ Meteor Run now", RED, "MeteorRun", {}, nextOrder())
	for _, e in ipairs(Config.EventList) do abuse("⭐ " .. e.Name, PURPLE, "Event", {Id = e.Id}, nextOrder()) end
	for _, key in ipairs(Config.TempPassKeys) do
		local pass = Config.GamePasses[key]
		if pass then abuse((pass.Icon or "🎟") .. " " .. pass.Name .. " for all · 15 min", BLUE, "Pass", {Key = key, Minutes = 15}, nextOrder()) end
	end
	abuse("🪩 Disco · 30 s", PINK, "Disco", {Seconds = 30}, nextOrder())
	abuse("🌙 Night", MID, "Night", {ClockTime = 0}, nextOrder())
	abuse("☀️ Day", MID, "Night", {ClockTime = 14}, nextOrder())
	abuse("🔄 Restart all servers", RED, "Restart", {Text = "Update! Join again for the new version"}, nextOrder())
	abuseButton.Activated:Connect(function() abuseWindow.Visible = not abuseWindow.Visible; listWindow.Visible = false end)

	-- phones: a crown button opens the bar
	-- (top-right corner: clear of the menu buttons, the tracker and the joystick)
	local open = UI.new("TextButton", {Name = "AdminToggle", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = DARK, Text = "👑", TextSize = 22, Visible = UI.isTouch(), ZIndex = 50}, gui)
	UI.round(open, 20); UI.stroke(open, 2, GOLD)
	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if not panel.Visible then listWindow.Visible = false; abuseWindow.Visible = false end
	end)
	local function layout()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local s = math.clamp(camera.ViewportSize.X / 900, 0.75, 1.15)
		scale.Scale = s
		for _, w in ipairs({listWindow, abuseWindow}) do
			w.UIScale.Scale = math.clamp(math.min(camera.ViewportSize.X / 460, (camera.ViewportSize.Y - 70) / 380), 0.6, 1.1)
		end
	end
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
	layout()
end
if player:GetAttribute("PFEAdmin") then buildPanel() end
player:GetAttributeChangedSignal("PFEAdmin"):Connect(function() if player:GetAttribute("PFEAdmin") then buildPanel() end end)
