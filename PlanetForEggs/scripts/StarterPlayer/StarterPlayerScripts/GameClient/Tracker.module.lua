--!nocheck
-- Planet tracker, Tower of Hell style: one slim vertical bar on the right edge with Earth at the
-- bottom and the planets stacked above it. Every segment takes the colour of the planet it leads
-- to, a small planet icon sits beside each stop and the players' headshots ride the bar, gliding
-- along it while they fly. Your own headshot has a gold ring, a thief's a red one; locked planets
-- are dimmed.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tracker = {}

function Tracker.Init(store)
	local UI, Config, player = store.UI, store.Config, store.player
	local C = UI.C
	local STEP, BAR, ICON, HEAD, PAD = 34, 12, 24, 26, 16
	local stops = {{Key = "Earth", Range = 0, Color = Color3.fromRGB(80, 170, 255)}}
	for _, planet in ipairs(Config.PlanetOrder) do
		table.insert(stops, {Key = planet.Id, Range = planet.RequiredRange, Color = planet.Accent})
	end
	local height = (#stops - 1) * STEP + PAD * 2
	local WIDTH = 92
	local BAR_X = 58                       -- bar centre; headshots to its left, icons to its right
	local function yOf(index) return height - PAD - (index - 1) * STEP end
	local ys = {}
	for i, stop in ipairs(stops) do ys[stop.Key] = yOf(i) end

	local holder = UI.new("Frame", {Name = "JourneyTracker", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(WIDTH, height), BackgroundTransparency = 1, ZIndex = 10}, store.gui)
	local scale = UI.new("UIScale", {}, holder)

	-- the bar: an outlined capsule with one coloured segment per leg of the journey
	local bar = UI.new("Frame", {Name = "Bar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(BAR_X, PAD - BAR / 2),
		Size = UDim2.fromOffset(BAR, height - PAD * 2 + BAR), BackgroundColor3 = Color3.fromRGB(30, 32, 52), ZIndex = 11}, holder)
	UI.round(bar, UDim.new(0.5, 0))
	UI.stroke(bar, 2.5, C.Ink)
	local segments = {}
	for i = 2, #stops do
		local top, bottom = yOf(i), yOf(i - 1)
		local segment = UI.new("Frame", {Name = "Leg_" .. stops[i].Key, AnchorPoint = Vector2.new(0.5, 0), BorderSizePixel = 0,
			Position = UDim2.fromOffset(BAR_X, top), Size = UDim2.fromOffset(BAR - 4, bottom - top), BackgroundColor3 = C.White, ZIndex = 12}, holder)
		UI.new("UIGradient", {Rotation = 90, Color = ColorSequence.new(stops[i].Color, stops[i - 1].Color)}, segment)
		segments[stops[i].Key] = segment
	end

	local entries = {}
	for i, stop in ipairs(stops) do
		local y = yOf(i)
		local notch = UI.new("Frame", {Name = "Notch", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(BAR_X, y),
			Size = UDim2.fromOffset(BAR + 4, 4), BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 13}, holder)
		UI.round(notch, 2)
		UI.new("UIStroke", {Thickness = 1.5, Color = C.Ink}, notch)
		local art = Config.MapArt[stop.Key]
		local grow = 0.82 / (art and art.Fill or 0.82)
		local icon = UI.new("ImageLabel", {Name = "Stop_" .. stop.Key, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(BAR_X + BAR / 2 + 6 + ICON / 2, y), Size = UDim2.fromOffset(ICON * grow, ICON * grow),
			BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 13, Image = art and ("rbxassetid://" .. tostring(art.Image)) or ""}, holder)
		if art and art.Rect then
			icon.ImageRectOffset = Vector2.new(art.Rect[1], art.Rect[2]); icon.ImageRectSize = Vector2.new(art.Rect[3], art.Rect[4])
		end
		local lock = UI.icon(holder, "LockWhite", UDim2.fromOffset(12, 12), UDim2.fromOffset(BAR_X + BAR / 2 + 6 + ICON - 8, y + 2), {ZIndex = 15, Visible = false})
		entries[stop.Key] = {Icon = icon, Lock = lock, Stop = stop}
	end

	-- (v41) the Golden Egg and the planet boss: a marker beside their planet's stop
	local function badge(name, iconKey, color)
		local b = UI.icon(holder, iconKey, UDim2.fromOffset(22, 22), UDim2.fromOffset(0, 0), {Name = name, ZIndex = 26, Visible = false,
			AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = color})
		UI.new("UIStroke", {Thickness = 0}, b)
		return b
	end
	local goldBadge = badge("GoldenEgg", "EggBig", Color3.fromRGB(255, 214, 60))
	local bossBadge = badge("Boss", "Volcano", Color3.fromRGB(255, 120, 100))
	bossBadge.Size = UDim2.fromOffset(18, 18)
	local function planetY(planetId)
		local key = planetId == "Base" and "Earth" or planetId
		return ys[key]
	end
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local gold = workspace:GetAttribute("PFEGoldenPlanet")
		local gy = type(gold) == "string" and gold ~= "" and planetY(gold)
		goldBadge.Visible = gy ~= nil and gy ~= false
		if goldBadge.Visible then
			-- (on the planet's own icon: the bar sits at the right edge of the screen, there is no room beside it)
			goldBadge.Position = UDim2.fromOffset(BAR_X + BAR / 2 + 6 + ICON / 2 - 6, gy - 8)
			goldBadge.Rotation = math.sin(t * 4) * 12
			goldBadge.Size = UDim2.fromOffset(20 + math.sin(t * 6) * 2, 20 + math.sin(t * 6) * 2)
		end
		local boss = workspace:GetAttribute("PFEBossPlanet")
		local by = type(boss) == "string" and boss ~= "" and planetY(boss)
		bossBadge.Visible = by ~= nil and by ~= false
		if bossBadge.Visible then
			bossBadge.Position = UDim2.fromOffset(BAR_X + BAR / 2 + 6 + ICON / 2 + 7, by + 7)
			bossBadge.ImageTransparency = 0.15 + 0.15 * math.sin(t * 5)
		end
	end)

	-- headshots
	local markers = {}
	local function addPlayer(other)
		if markers[other] then return end
		local mine = other == player
		local frame = UI.new("Frame", {Name = "Player_" .. other.UserId, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(HEAD, HEAD),
			BackgroundColor3 = Color3.fromRGB(70, 78, 110), ZIndex = mine and 24 or 20}, holder)
		UI.round(frame, UDim.new(0.5, 0))
		local stroke = UI.new("UIStroke", {Thickness = mine and 3 or 2.5, Color = mine and C.Gold or C.White}, frame)
		local image = UI.new("ImageLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = "", ZIndex = frame.ZIndex + 1}, frame)
		UI.round(image, UDim.new(0.5, 0))
		-- a little pointer from the headshot to the bar
		UI.new("Frame", {Name = "Tip", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(6, 3),
			BackgroundColor3 = mine and C.Gold or C.White, BorderSizePixel = 0, ZIndex = frame.ZIndex}, frame)
		markers[other] = {Frame = frame, Stroke = stroke, Mine = mine, Order = other.UserId}
		task.spawn(function()
			local ok, thumb = pcall(function()
				return Players:GetUserThumbnailAsync(other.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
			end)
			if ok and image.Parent then image.Image = thumb end
		end)
	end
	local function removePlayer(other)
		local marker = markers[other]
		if marker then marker.Frame:Destroy(); markers[other] = nil end
	end
	for _, other in ipairs(Players:GetPlayers()) do addPlayer(other) end
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	-- (v30) the bot explorers ride the bar too (an entry per bot in PFE.BotTracker; the headshot is a copy of its head)
	local function addBot(entry)
		if markers[entry] or not entry:IsA("Configuration") then return end
		local frame = UI.new("Frame", {Name = "Bot_" .. entry.Name, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(HEAD, HEAD),
			BackgroundColor3 = Color3.fromRGB(70, 78, 110), ZIndex = 20}, holder)
		UI.round(frame, UDim.new(0.5, 0))
		local stroke = UI.new("UIStroke", {Thickness = 2.5, Color = C.White}, frame)
		UI.new("Frame", {Name = "Tip", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(6, 3),
			BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 20}, frame)
		local head = entry:FindFirstChild("Headshot") or entry:FindFirstChildWhichIsA("BasePart")
		local realId = entry:GetAttribute("UserId")
		if realId then   -- (v32 Studio preview) the borrowed account's own headshot
			local image = UI.new("ImageLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = "", ZIndex = 21}, frame)
			UI.round(image, UDim.new(0.5, 0))
			task.spawn(function()
				local ok, thumb = pcall(function()
					return Players:GetUserThumbnailAsync(realId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
				end)
				if ok and image.Parent then image.Image = thumb end
			end)
		elseif head then
			local view = UI.new("ViewportFrame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 21,
				Ambient = Color3.fromRGB(170, 170, 170), LightColor = Color3.fromRGB(255, 255, 255), LightDirection = Vector3.new(-0.4, -0.6, 0.7)}, frame)
			UI.round(view, UDim.new(0.5, 0))
			local copy = head:Clone(); copy.Parent = view
			local camera = Instance.new("Camera"); camera.FieldOfView = 30
			-- (v35) a bot's avatar head with its hair and hat, at a headshot's angle
			camera.CFrame = head:IsA("Model") and CFrame.lookAt(Vector3.new(1.3, 0.35, -4.4), Vector3.new(0, -0.2, 0))
				or CFrame.lookAt(Vector3.new(0, 0.1, -4.2), Vector3.new(0, 0.05, 0))
			camera.Parent = view; view.CurrentCamera = camera
		end
		markers[entry] = {Frame = frame, Stroke = stroke, Mine = false, Order = 1e12 + #entry.Name}
	end
	local botTracker = store.api and store.api:FindFirstChild("BotTracker") or game:GetService("ReplicatedStorage"):WaitForChild("PFE"):FindFirstChild("BotTracker")
	if botTracker then
		for _, entry in ipairs(botTracker:GetChildren()) do addBot(entry) end
		botTracker.ChildAdded:Connect(addBot)
		botTracker.ChildRemoved:Connect(removePlayer)
	end

	local function where(other)
		local planet = tostring(other:GetAttribute("PFETrackerPlanet") or "Earth")
		local from = tostring(other:GetAttribute("PFETrackerFlightFrom") or "")
		local to = tostring(other:GetAttribute("PFETrackerFlightTo") or "")
		local started = tonumber(other:GetAttribute("PFETrackerFlightStartedAt")) or 0
		local duration = tonumber(other:GetAttribute("PFETrackerFlightDuration")) or 0
		if from ~= "" and to ~= "" and ys[from] and ys[to] and started > 0 and duration > 0 then
			local t = math.clamp((workspace:GetServerTimeNow() - started) / duration, 0, 1)
			t = t * t * (3 - 2 * t)
			return ys[from] + (ys[to] - ys[from]) * t, nil
		end
		return ys[planet] or ys.Earth, planet
	end

	local function refresh(state)
		local range = Config.Rockets[state.RocketLevel or 1] and Config.Rockets[state.RocketLevel or 1].Range or 1
		for key, entry in pairs(entries) do
			local locked = entry.Stop.Range > range and not state.DevTravel
			entry.Lock.Visible = locked
			entry.Icon.ImageColor3 = locked and Color3.fromRGB(90, 92, 112) or C.White
			local segment = segments[key]
			if segment then segment.BackgroundTransparency = locked and 0.55 or 0 end
		end
	end
	store.on(refresh)

	-- (v34) step down below the Tab list (top right) when it is open, so they never overlap
	local baseY, dodge = 0, 0
	local function avoidList()
		local listGui = player.PlayerGui:FindFirstChild("PFE_PlayerList")
		local list = listGui and listGui.Enabled and listGui:FindFirstChild("List")
		local want = 0
		local camera = workspace.CurrentCamera
		if list and list.Visible and camera then
			-- both GUIs sit below the top bar: work in that space (no AbsolutePosition needed)
			local inset = game:GetService("GuiService"):GetGuiInset()
			local screenH = camera.ViewportSize.Y - inset.Y
			local tall = height * scale.Scale
			local top = screenH / 2 + baseY - tall / 2
			local bottom = (listGui:GetAttribute("ListBottom") or 0) + 6
			want = math.max(0, bottom - top)
			-- never off the bottom of the screen (above the hotbar)
			want = math.min(want, math.max(0, screenH - 90 - (top + tall)))
		end
		if math.abs(want - dodge) > 0.5 then
			dodge = want
			holder.Position = UDim2.new(1, -6, 0.5, baseY + dodge)
		end
	end
	local function layout()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local vp = camera.ViewportSize
		local room = vp.Y * (UI.isTouch() and 0.52 or 0.6)
		scale.Scale = math.clamp(math.min(UI.scaleFor(vp) * 1.05, room / height), 0.45, 1.2)
		baseY = UI.isTouch() and -30 or 0
		holder.Position = UDim2.new(1, -6, 0.5, baseY + dodge)
		if store.HudLayout then store.HudLayout() end
	end
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
	layout()
	store.TrackerLayout = layout
	function store.TrackerWidth() return WIDTH * scale.Scale + 10 end

	RunService.RenderStepped:Connect(function()
		holder.Visible = not store.flying() and player:GetAttribute("PFEPlanetMapOpen") ~= true
		if not holder.Visible then return end
		avoidList()
		local rows = {}
		for other, marker in pairs(markers) do
			if other.Parent then
				local y, at = where(other)
				table.insert(rows, {Player = other, Marker = marker, Y = y, At = at})
			end
		end
		table.sort(rows, function(a, b)
			if a.Marker.Mine ~= b.Marker.Mine then return a.Marker.Mine end
			return a.Marker.Order < b.Marker.Order
		end)
		local perStop = {}
		for _, row in ipairs(rows) do
			local slot = 0
			if row.At then slot = perStop[row.At] or 0; perStop[row.At] = slot + 1 end
			local marker = row.Marker
			marker.Frame.Visible = slot < 2
			marker.Frame.Position = UDim2.fromOffset(BAR_X - BAR / 2 - 8 - HEAD / 2 - slot * (HEAD - 10), row.Y)
			local stealing = row.Player:GetAttribute("PFEStealing") == true
			marker.Stroke.Color = stealing and C.Red or (marker.Mine and C.Gold or C.White)
		end
	end)
end

return Tracker
