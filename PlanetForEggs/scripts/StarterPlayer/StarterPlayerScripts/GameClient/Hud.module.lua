--!nocheck
-- Always-on HUD, kept deliberately small: coins and (v28) the speed under them, the menu buttons (the trail
-- shop on its own under all the others), and (on planets only) the planet name plus a compact expedition
-- bar: air, cargo, parts and the egg scanner.
-- Aboard an alien ship the name is the ship's and the line under it the level; game passes won in
-- the ships show as chips with the time they have left.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")

local Hud = {}

function Hud.Init(store)
	local UI, Config, player = store.UI, store.Config, store.player
	local C = UI.C
	local root = UI.new("Frame", {Name = "HUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)}, store.gui)
	Hud.Root = root

	local function corner(name, anchor, pos, size)
		local frame = UI.new("Frame", {Name = name, BackgroundTransparency = 1, AnchorPoint = anchor, Position = pos, Size = size}, root)
		return frame, UI.new("UIScale", {}, frame)
	end
	local topLeft, tlScale = corner("TopLeft", Vector2.new(0, 0), UDim2.fromOffset(14, 8), UDim2.fromOffset(300, 560))
	local topCenter, tcScale = corner("TopCenter", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 4), UDim2.fromOffset(440, 220))
	local bottomRight, brScale = corner("BottomRight", Vector2.new(1, 1), UDim2.new(1, -14, 1, -14), UDim2.fromOffset(260, 260))
	Hud.TopCenter = topCenter

	-- ---------------------------------------------------------------- coins
	local wallet = UI.new("Frame", {Name = "Wallet", BackgroundTransparency = 1, Size = UDim2.fromOffset(280, 104)}, topLeft)
	local coin = UI.icon(wallet, "Coin", UDim2.fromOffset(58, 58), UDim2.fromOffset(0, 6), {Name = "Coin", Rotation = -8, ZIndex = 5})
	local money = UI.text(wallet, "0", UDim2.fromOffset(214, 44), UDim2.fromOffset(64, 2), 42, C.White)
	money.Name = "Money"; money.TextWrapped = false
	UI.new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 250, 200), Color3.fromRGB(255, 196, 30))}, money)
	local income = UI.text(wallet, "+0/s", UDim2.fromOffset(200, 24), UDim2.fromOffset(66, 44), 21, Color3.fromRGB(120, 255, 90))
	income.Name = "Income"; income.TextWrapped = false
	-- v28: the speed trained on the treadmill, right under the coins (and what the treadmill adds while you run)
	local speedRow = UI.new("Frame", {Name = "Speed", BackgroundTransparency = 1, Size = UDim2.fromOffset(280, 34), Position = UDim2.fromOffset(0, 70)}, wallet)
	UI.icon(speedRow, "Shoe", UDim2.fromOffset(34, 34), UDim2.fromOffset(12, 0), {Name = "ShoeIcon", Rotation = -8, ZIndex = 5})
	local speedText = UI.text(speedRow, "22 speed", UDim2.fromOffset(150, 30), UDim2.fromOffset(52, 2), 27, C.White)
	speedText.Name = "SpeedValue"; speedText.TextWrapped = false; speedText.AutomaticSize = Enum.AutomaticSize.X
	UI.new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(210, 250, 255), Color3.fromRGB(60, 190, 255))}, speedText)
	local speedGain = UI.text(speedRow, "", UDim2.fromOffset(120, 24), UDim2.fromOffset(176, 6), 19, Color3.fromRGB(120, 255, 90))
	speedGain.Name = "SpeedGain"; speedGain.TextWrapped = false
	Hud.Speed = speedText

	-- ---------------------------------------------------------------- menu buttons
	local tiles = UI.new("Frame", {Name = "Menu", BackgroundTransparency = 1, Size = UDim2.fromOffset(86, 440), Position = UDim2.fromOffset(2, 126)}, topLeft)
	local tileList = UI.list(tiles, 22)
	local tileButtons = {}
	local function addTile(key, icon, caption, color, order)
		local button, badge = UI.tile(tiles, icon, caption, color, UDim2.fromOffset(76, 76), function()
			if store.Menus then store.Menus.Toggle(key) end
		end, "Tile" .. key)
		button.LayoutOrder = order
		tileButtons[key] = {Button = button, Badge = badge}
	end
	addTile("Daily", "GiftPink", "Daily", Color3.fromRGB(255, 120, 200), 0)
	addTile("Shop", "Shop", "Shop", Color3.fromRGB(80, 226, 70), 1)
	addTile("Pets", "Pets", "Pets", Color3.fromRGB(255, 170, 50), 2)
	addTile("Index", "Index", "Index", Color3.fromRGB(60, 170, 255), 3)
	addTile("Upgrades", "Upgrade", "Upgrade", Color3.fromRGB(176, 104, 255), 4)
	addTile("Fusion", "Sparkle", "Fuse", Color3.fromRGB(255, 96, 196), 5)
	addTile("Codes", "Ticket", "Codes", Color3.fromRGB(64, 200, 255), 6)
	addTile("Free", "Gift", "Free", Color3.fromRGB(255, 196, 40), 7)
	addTile("Test", "Dice", "Studio", Color3.fromRGB(140, 146, 170), 8)
	tileButtons.Test.Button.Visible = false
	-- v28: the trail shop, its own button under all the others
	addTile("Trails", "Wing", "Trails", Color3.fromRGB(120, 90, 255), 99)
	Hud.Tiles = tileButtons

	-- ---------------------------------------------------------------- planet name + expedition bar
	local location = UI.new("Frame", {Name = "Location", BackgroundTransparency = 1, Size = UDim2.fromOffset(440, 64), Visible = false}, topCenter)
	local locName = UI.text(location, "", UDim2.new(1, 0, 0, 42), UDim2.fromOffset(0, 0), 38)
	locName.Name = "PlanetName"; locName.TextXAlignment = Enum.TextXAlignment.Center; locName.TextWrapped = false
	local locGradient = UI.new("UIGradient", {Rotation = 90}, locName)
	local locRegion = UI.text(location, "", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 40), 19, C.Soft)
	locRegion.Name = "Region"; locRegion.TextXAlignment = Enum.TextXAlignment.Center

	local expedition = UI.new("Frame", {Name = "Expedition", BackgroundTransparency = 1, Size = UDim2.fromOffset(360, 84),
		Position = UDim2.new(0.5, -180, 0, 68), Visible = false}, topCenter)
	-- air
	local bubble = UI.new("Frame", {Name = "AirIcon", BackgroundColor3 = C.Cyan, Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(0, 0), ZIndex = 7}, expedition)
	UI.round(bubble, 18); UI.stroke(bubble, 3, C.Ink)
	UI.gradient(bubble, Color3.fromRGB(200, 250, 255), Color3.fromRGB(40, 150, 255), 135)
	local shine = UI.new("Frame", {BackgroundColor3 = C.White, BackgroundTransparency = 0.25, Size = UDim2.fromOffset(10, 7), Position = UDim2.fromOffset(8, 7), Rotation = -30, ZIndex = 8}, bubble)
	UI.round(shine, 4)
	local airBar, setAir = UI.bar(expedition, UDim2.fromOffset(318, 26), UDim2.fromOffset(40, 5), C.Cyan)
	local airText = UI.text(airBar, "60", UDim2.fromScale(1, 1), nil, 19)
	airText.TextXAlignment = Enum.TextXAlignment.Center; airText.ZIndex = 9
	-- chips: cargo, scanner
	local chips = UI.new("Frame", {Name = "Chips", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 44)}, expedition)
	UI.list(chips, 10, true, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Center
	local function chip(name, iconKey, order, width)
		local frame = UI.new("Frame", {Name = name, BackgroundColor3 = C.Ink, BackgroundTransparency = 0.35, Size = UDim2.fromOffset(width or 84, 32), LayoutOrder = order}, chips)
		UI.round(frame, 16); UI.stroke(frame, 2.5, C.Ink)
		local icon = UI.icon(frame, iconKey, UDim2.fromOffset(30, 30), UDim2.fromOffset(2, 1), {ZIndex = 7})
		local label = UI.text(frame, "0", UDim2.new(1, -38, 1, 0), UDim2.fromOffset(34, 0), 20)
		label.TextWrapped = false
		return frame, label, icon
	end
	local _, cargoText = chip("Cargo", "Egg", 1)
	local scanner, scanText = chip("Scanner", "Pulse", 4, 118)
	-- game passes won in the alien ships, with the time they have left
	local passRow = UI.new("Frame", {Name = "TempPasses", BackgroundTransparency = 1, Size = UDim2.fromOffset(440, 30)}, topCenter)
	UI.list(passRow, 8, true, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Center
	local passChips = {}
	scanner:FindFirstChild("Icon").Visible = false
	local bars = {}
	for i = 1, 4 do
		local b = UI.new("Frame", {BackgroundColor3 = C.Muted, BorderSizePixel = 0, Size = UDim2.fromOffset(5, 5 + i * 4),
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(8 + (i - 1) * 7, 27), ZIndex = 7}, scanner)
		UI.round(b, 2)
		bars[i] = b
	end
	scanText.Position = UDim2.fromOffset(40, 0); scanText.Size = UDim2.new(1, -44, 1, 0); scanText.TextSize = 18
	-- Egg Radar Pro: the arrow right of the scanner turns smoothly towards the nearest egg (as seen from
	-- the camera, flat on the ground), in the egg's rarity colour
	local arrow = UI.icon(scanner, "Next", UDim2.fromOffset(24, 24), UDim2.new(1, 13, 0.5, 0), {ZIndex = 8, Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5)})
	arrow.Name = "RadarArrow"
	local radarTarget = nil
	Hud.Expedition = expedition

	-- ---------------------------------------------------------------- actions (touch / planets)
	local actions = UI.new("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)}, bottomRight)
	local function actionButton(name, icon, color, size)
		local b, badge = UI.tile(actions, icon, name, color, size or UDim2.fromOffset(70, 70), nil, name)
		b.AnchorPoint = Vector2.new(1, 1)
		return b, badge
	end
	local tankButton = actionButton("Air", "Potion", Color3.fromRGB(80, 220, 255))
	tankButton.Visible = false
	Hud.Actions = {Tank = tankButton}
	tankButton.Activated:Connect(function() store.send("UseOxygen") end)

	-- (v29: no sprinting - the speed comes from the treadmills)

	-- ---------------------------------------------------------------- layout
	local function layout()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local vp = camera.ViewportSize
		local s = UI.scaleFor(vp)
		local touch = UI.isTouch()
		-- phones: the menu buttons and the planet panel a little smaller, hugging the edges
		tlScale.Scale = touch and s * 0.88 or s; tcScale.Scale = touch and s * 0.85 or s; brScale.Scale = s
		if touch then
			local ok, top = pcall(function() return GuiService.TopbarInset.Height end)
			top = ok and type(top) == "number" and top > 0 and top or 58
			topLeft.Position = UDim2.fromOffset(4, top + 2)
			topCenter.Position = UDim2.new(0.5, 0, 0, 2)
		else
			topLeft.Position = UDim2.fromOffset(14, 8)
			topCenter.Position = UDim2.new(0.5, 0, 0, 4)
		end
		-- phones: stay above Roblox's jump button and left of the planet tracker
		local lift = touch and -178 or -16 -- (phones: above the timers row too)
		-- phones: the planet tracker owns the right edge, so the action buttons sit left of it
		local shift = (touch and store.TrackerWidth and store.TrackerWidth() or 0) / math.max(0.1, s) -- this frame is scaled by s
		tankButton.Position = UDim2.new(1, (touch and -140 or -56) - shift, 1, lift)
		-- two columns of menu buttons when the screen is too short for one
		local count = 0
		for _, t in pairs(tileButtons) do if t.Button.Visible then count += 1 end end
		local ok, inset = pcall(function() return GuiService:GetGuiInset() end)
		local usable = vp.Y - (ok and inset and inset.Y or 58) - 16
		local twoColumns = (126 + count * 98) * s > usable
		local grid = tiles:FindFirstChildOfClass("UIGridLayout")
		if twoColumns and not grid then
			tileList.Parent = nil
			UI.new("UIGridLayout", {CellSize = UDim2.fromOffset(76, 76), CellPadding = UDim2.fromOffset(14, 22), SortOrder = Enum.SortOrder.LayoutOrder}, tiles)
			tiles.Size = UDim2.fromOffset(180, 440)
		elseif not twoColumns and grid then
			grid:Destroy(); tileList.Parent = tiles
			tiles.Size = UDim2.fromOffset(86, 440)
		end
	end
	Hud.Layout = layout
	store.HudLayout = layout
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
	layout()

	-- ---------------------------------------------------------------- alien ships
	local BEAM = Color3.fromRGB(120, 255, 170)
	local function shipName()
		local ship = player:GetAttribute("PFEDungeon")
		return type(ship) == "string" and ship ~= "" and ship or nil
	end
	local function shipLine()
		local level, levels = player:GetAttribute("PFEDungeonLevel") or 1, player:GetAttribute("PFEDungeonLevels") or 1
		local phase = player:GetAttribute("PFEDungeonState")
		if phase == "Vault" then return "The vault - open the alien chest!" end
		local prefix = "Level " .. level .. "/" .. levels .. "  -  "
		if phase == "Open" then return prefix .. "walk into the lit airlock!" end
		local aliens = player:GetAttribute("PFEDungeonAliens") or 0
		if aliens > 0 then return prefix .. aliens .. (aliens == 1 and " alien left" or " aliens left") end
		local left = math.ceil((player:GetAttribute("PFEDungeonOpenAt") or 0) - workspace:GetServerTimeNow())
		return prefix .. (left > 0 and ("airlock opens in " .. left .. "s") or "airlock opening...")
	end
	local function passChip(key)
		local info = Config.GamePasses[key]
		local frame = UI.new("Frame", {Name = key, BackgroundColor3 = C.Ink, BackgroundTransparency = 0.3, Size = UDim2.fromOffset(170, 28)}, passRow)
		UI.round(frame, 14); UI.stroke(frame, 2, info and info.Color or C.Gold)
		frame.LayoutOrder = key == "Immortal" and 0 or 1
		local emoji = UI.text(frame, info and info.Icon or (key == "Immortal" and "🛡️" or "*"), UDim2.fromOffset(26, 26), UDim2.fromOffset(4, 1), 18)
		emoji.TextXAlignment = Enum.TextXAlignment.Center
		local label = UI.text(frame, "", UDim2.new(1, -36, 1, 0), UDim2.fromOffset(32, 0), 16)
		label.Name = "Label"; label.TextWrapped = false; label.TextScaled = true
		UI.new("UITextSizeConstraint", {MaxTextSize = 16}, label)
		return {Frame = frame, Label = label, Name = info and info.Name or key}
	end
	local function renderPasses(state)
		local temp = state and state.TempPasses
		if type(temp) ~= "table" then return end
		local now = workspace:GetServerTimeNow() -- (the server stamps unix time)
		for key, untilTime in pairs(temp) do
			if untilTime > now and not passChips[key] and Config.GamePasses[key] then passChips[key] = passChip(key) end
		end
		for key, entry in pairs(passChips) do
			if key == "Immortal" then continue end -- (its own attribute, handled by tickPasses)
			local untilTime = temp[key]
			if not untilTime or untilTime <= now then entry.Frame:Destroy(); passChips[key] = nil end
		end
	end
	local function tickPasses()
		local temp = table.clone(store.state.TempPasses or {})
		local now = workspace:GetServerTimeNow() -- (the server stamps unix time)
		-- immortality (the product) shows like a pass, with its time left
		local immortal = player:GetAttribute("PFEImmortalUntil")
		if type(immortal) == "number" and immortal > now then
			temp.Immortal = immortal
			if not passChips.Immortal then
				local chipInfo = passChip("Immortal")
				chipInfo.Name = "Immortal"
				passChips.Immortal = chipInfo
			end
		end
		for key, entry in pairs(passChips) do
			local left = math.max(0, math.floor((temp[key] or 0) - now))
			entry.Label.Text = entry.Name .. "  " .. string.format("%d:%02d", left // 60, left % 60)
			if left <= 0 then entry.Frame:Destroy(); passChips[key] = nil end
		end
		passRow.Visible = next(passChips) ~= nil
		passRow.Position = UDim2.new(0.5, -220, 0, expedition.Visible and 156 or (location.Visible and 68 or 4))
	end

	-- ---------------------------------------------------------------- state rendering
	local shownCoins, targetCoins = 0, 0
	local function refresh(own)
		local state = store.spectate or own   -- (admin "view": the watched player's numbers)
		targetCoins = state.Coins or 0
		income.Text = "+" .. Config.Format(state.Income or 0) .. "/s"
		local walk = state.WalkSpeed or Config.WalkSpeedFor(state.SpeedPower or 0)
		speedText.Text = Config.Format(math.floor(state.SpeedPower or 0)) .. " speed"
		speedGain.Text = state.OnTreadmill and ("+" .. Config.FormatRate(state.TreadmillGain or 1) .. " speed/s") or ""
		speedGain.Position = UDim2.fromOffset(60 + speedText.TextBounds.X, 6)
		local planet = Config.Planets[state.Planet]
		local flying = state.Busy == true
		local inRun = state.Minigame ~= nil -- Meteor Run: its banner takes the top
		location.Visible = ((planet ~= nil) or flying) and not inRun
		if location.Visible then
			locName.Text = flying and "IN FLIGHT" or string.upper(planet.Name)
			local tint = planet and planet.Accent or C.Cyan
			locGradient.Color = ColorSequence.new(C.White, tint:Lerp(C.White, 0.35))
			local region = player:GetAttribute("PFERegion")
			locRegion.Text = (not flying and type(region) == "string") and region or (planet and Config.Galaxies[planet.Galaxy].Name or "")
			local ship = not flying and shipName()
			if ship then
				locName.Text = string.upper(ship)
				locGradient.Color = ColorSequence.new(C.White, BEAM)
				locRegion.Text = shipLine()
			end
		end
		if not state.Light then renderPasses(state) end
		tickPasses()
		local onPlanet = planet ~= nil and not flying and not inRun
		expedition.Visible = onPlanet
		if onPlanet then
			local ratio = (state.Oxygen or 0) / math.max(1, state.MaxOxygen or 1)
			setAir(ratio, ratio < 0.25 and C.Red or ratio < 0.5 and C.Orange or C.Cyan)
			airText.Text = tostring(math.floor(state.Oxygen or 0))
			local exp = state.Expedition
			cargoText.Text = ((exp and exp.Eggs and #exp.Eggs) or state.EggCount or 0) .. "/" .. (state.Capacity or 1)
		end
		tankButton.Visible = onPlanet and (state.OxygenTanks or 0) > 0
		tileButtons.Test.Button.Visible = state.DevMode == true
		own = store.state or own
		local nextRocket = Config.Rockets[(own.RocketLevel or 1) + 1]
		local nextTread = Config.Treadmills[(own.TreadmillLevel or 1) + 1]
		tileButtons.Upgrades.Badge.Visible = (nextRocket ~= nil and (own.Coins or 0) >= nextRocket.Cost)
			or (nextTread ~= nil and (own.Coins or 0) >= nextTread.Cost)
		local cheapest
		for _, trail in ipairs(Config.TrailList) do
			if not (own.Trails and own.Trails[trail.Id]) then cheapest = trail; break end
		end
		tileButtons.Trails.Badge.Visible = cheapest ~= nil and (own.Coins or 0) >= cheapest.Cost
		tileButtons.Fusion.Badge.Visible = #(own.Eggs or {}) >= Config.FusionCost
		tileButtons.Free.Badge.Visible = (own.FreeStage or 0) < 2
		tileButtons.Daily.Badge.Visible = own.Daily ~= nil and own.Daily.Claimable == true
		layout()
	end
	store.on(refresh)
	store.onLight(refresh)
	store.onSpectate(function() refresh(store.state) end)
	for _, key in ipairs({"PFEDungeon", "PFEDungeonLevel", "PFEDungeonState", "PFEDungeonAliens", "PFEDungeonOpenAt"}) do
		player:GetAttributeChangedSignal(key):Connect(function() if store.state then refresh(store.state) end end)
	end
	-- the flight cinematic owns the whole screen
	local function flightVisibility() root.Visible = not store.flying() end
	player:GetAttributeChangedSignal("PFEFlightActive"):Connect(flightVisibility)
	flightVisibility()

	-- ---------------------------------------------------------------- per-frame: coins, scanner
	local beep = UI.new("Sound", {Name = "ScannerBeep", SoundId = "rbxasset://sounds/volume_slider.ogg", Volume = 0.2, PlaybackSpeed = 1.2}, SoundService)
	local beep2 = UI.new("Sound", {Name = "ScannerBeep2", SoundId = "rbxasset://sounds/volume_slider.ogg", Volume = 0.32, PlaybackSpeed = 1.6}, SoundService)
	local scanClock, beepClock, slowClock = 0, 0, 0
	RunService.RenderStepped:Connect(function(dt)
		slowClock += dt
		if slowClock >= 0.5 then
			slowClock = 0
			tickPasses()
			if location.Visible and shipName() then locRegion.Text = shipLine() end
		if store.spectate then refresh(store.state) end
		end
		if math.abs(targetCoins - shownCoins) > 0.5 then
			shownCoins += (targetCoins - shownCoins) * math.min(1, dt * 8)
			if math.abs(targetCoins - shownCoins) < 1 then shownCoins = targetCoins end
			money.Text = Config.Format(shownCoins)
		elseif money.Text == "0" and targetCoins > 0 then
			shownCoins = targetCoins; money.Text = Config.Format(shownCoins)
		end
		-- the compass arrow turns every frame (the nearest egg is looked up ten times a second below)
		if radarTarget and radarTarget.Parent and workspace.CurrentCamera then
			local cam = workspace.CurrentCamera.CFrame
			local look = Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z)
			local right = Vector3.new(cam.RightVector.X, 0, cam.RightVector.Z)
			if look.Magnitude > 0.01 and right.Magnitude > 0.01 then
				local d = (radarTarget.Position - cam.Position) * Vector3.new(1, 0, 1)
				local want = math.deg(math.atan2(d:Dot(right.Unit), d:Dot(look.Unit))) - 90 -- (the icon points right)
				local diff = (want - arrow.Rotation + 540) % 360 - 180
				arrow.Rotation += diff * math.min(1, dt * 12)
			end
		end
		if not expedition.Visible then return end
		scanClock += dt
		if scanClock < 0.1 then return end
		scanClock = 0
		local view = store.spectate or store.state
		local watched = store.spectate and Players:GetPlayerByUserId(store.spectate.UserId or 0)
		local character = watched and watched.Character or player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local folder = workspace:FindFirstChild("PFE_Pickups") and workspace.PFE_Pickups:FindFirstChild(tostring(view.Planet))
		local nearest, nearestPart, rare
		if rootPart and folder then
			for _, item in ipairs(folder:GetChildren()) do
				if item:GetAttribute("EggId") then
					local part = item.PrimaryPart or item:FindFirstChild("Pickup")
					if part then
						local d = (part.Position - rootPart.Position).Magnitude
						if not nearest or d < nearest then nearest, nearestPart = d, part; rare = item:GetAttribute("Rarity") end
					end
				end
			end
		end
		local level = nearest and (nearest < 20 and 4 or nearest < 50 and 3 or nearest < 100 and 2 or 1) or 0
		for i, b in ipairs(bars) do b.BackgroundColor3 = i <= level and (level >= 4 and C.Green or level >= 3 and C.Gold or C.Orange) or C.Muted end
		scanText.Text = nearest and (math.floor(nearest) .. "m") or "--"
		local radar = view.Passes and view.Passes.RadarPro
		arrow.Visible = radar == true and nearestPart ~= nil
		radarTarget = arrow.Visible and nearestPart or nil
		if arrow.Visible then arrow.ImageColor3 = rare and Config.EggGlow and Config.EggGlow[rare] or C.White end
		beepClock += 0.1
		local interval = level >= 4 and 0.4 or level == 3 and 0.9 or 99
		if beepClock >= interval then
			beepClock = 0
			local sound = level >= 4 and beep2 or beep
			sound.PlaybackSpeed = level >= 4 and 1.9 or 1.5
			sound:Play()
		end
	end)
end

return Hud
