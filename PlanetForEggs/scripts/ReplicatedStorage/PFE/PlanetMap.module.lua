--!nocheck
-- Galaxy map, opened from the rocket's launch prompt. Same look as the original map:
-- a photographic galaxy backdrop, twinkling stars and large realistic planets on a
-- diagonal. Three galaxies are paged with the arrows (or Q/E, shoulder buttons, swipes);
-- Earth stays bottom-left as home, where your real rocket waits and turns towards the
-- planet you pick. Click a planet to select it, click again or press LAUNCH to fly.
local Run = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local M = {}
local activeControllers = setmetatable({}, {__mode = "k"})

local function smooth(t) t = math.clamp(t, 0, 1) return t * t * (3 - 2 * t) end
local function asset(id) return "rbxassetid://" .. tostring(id) end
-- diagonal slots for a galaxy's planets (x, y, size) and Earth's home slot
local SLOTS = {{0.44, 0.57, 0.62}, {0.63, 0.39, 0.78}, {0.83, 0.23, 0.7}}
local HOME = {0.16, 0.7, 1.0}

function M.new(opts)
	assert(opts and opts.Player and opts.Config and opts.Send, "PlanetMap requires Player, Config and Send")
	local player, config, UI = opts.Player, opts.Config, opts.UI or require(script.Parent:WaitForChild("UIKit"))
	local C = UI.C
	if activeControllers[player] then activeControllers[player]:Destroy() end
	local playerGui = player:WaitForChild("PlayerGui")
	for _, name in ipairs({"PFE_GalaxyMap", "PlanetDestinationMap"}) do
		local old = playerGui:FindFirstChild(name); if old then old:Destroy() end
	end
	player:SetAttribute("PFEPlanetMapOpen", false)
	local alive, opened = true, false
	local state = {Planet = "Base", RocketLevel = 1}
	local connections = {}
	local page, pageShown = 1, 1
	local selected

	local gui = UI.new("ScreenGui", {Name = "PFE_GalaxyMap", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 60, Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, playerGui)
	local canvas = UI.new("Frame", {Name = "Space", BackgroundColor3 = Color3.fromRGB(2, 3, 10), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true}, gui)
	-- galaxy photos, cross-faded when paging
	local backdrops = {}
	for i, galaxy in ipairs(config.GalaxyOrder) do
		local art = config.GalaxyArt[galaxy.Id]
		backdrops[i] = UI.new("ImageLabel", {Name = "Galaxy_" .. galaxy.Id, BackgroundTransparency = 1, Image = art and asset(art) or "",
			ScaleType = Enum.ScaleType.Crop, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.12, 1.12),
			ImageTransparency = i == 1 and 0 or 1, ZIndex = 1}, canvas)
	end
	local rng = Random.new(220)
	local stars = {}
	for i = 1, 140 do
		local depth = i <= 60 and 0.25 or i <= 110 and 0.55 or 1
		local x, y = rng:NextNumber(), rng:NextNumber()
		local size = rng:NextNumber() < 0.07 and 3 or rng:NextNumber(1, 2)
		local star = UI.new("Frame", {Name = "Star", BorderSizePixel = 0, BackgroundColor3 = i % 9 == 0 and Color3.fromRGB(187, 184, 255) or C.White,
			BackgroundTransparency = rng:NextNumber(0.2, 0.75), Size = UDim2.fromOffset(size, size), Position = UDim2.fromScale(x, y), ZIndex = 2}, canvas)
		UI.round(star, 5)
		table.insert(stars, {object = star, x = x, y = y, depth = depth, phase = rng:NextNumber(0, math.pi * 2)})
	end
	UI.new("Frame", {Name = "SpaceDim", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3}, canvas)
	local vignette = UI.new("Frame", {Name = "Vignette", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3}, canvas)
	UI.new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.25, 1),
		NumberSequenceKeypoint.new(0.75, 1), NumberSequenceKeypoint.new(1, 0.15)})}, vignette)

	local stage = UI.new("Frame", {Name = "Stage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4}, canvas)
	local route = UI.new("Frame", {Name = "Route", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5}, stage)
	local dots = {}
	for i = 1, 22 do
		local dot = UI.new("Frame", {Name = "Dot", BackgroundColor3 = C.White, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(6, 6), Visible = false, ZIndex = 5}, route)
		UI.round(dot, 3)
		dots[i] = dot
	end

	-- ---------------------------------------------------------------- planets
	local entries = {}
	local function planetArt(parent, key, z)
		local art = config.MapArt[key]
		-- every planet disk ends up the same size (0.82 of the holder) inside the same halo ring
		local grow = 0.82 / (art and art.Fill or 0.82)
		local image = UI.new("ImageLabel", {Name = "Art", BackgroundTransparency = 1, Image = art and asset(art.Image) or "", ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(grow, grow), ZIndex = z}, parent)
		if art and art.Rect then
			image.ImageRectOffset = Vector2.new(art.Rect[1], art.Rect[2]); image.ImageRectSize = Vector2.new(art.Rect[3], art.Rect[4])
		end
		return image
	end
	local function makePlanet(key, name, slot, galaxyIndex, info)
		local holder = UI.new("Frame", {Name = key, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(200, 200), ZIndex = 6}, stage)
		local scale = UI.new("UIScale", {}, holder)
		local glow = UI.new("ImageLabel", {Name = "Glow", BackgroundTransparency = 1, Image = UI.Icons.Sunburst, ImageColor3 = info and info.Accent or Color3.fromRGB(120, 190, 255),
			ImageTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.7, 1.7), ZIndex = 6}, holder)
		local ring = UI.new("Frame", {Name = "Atmosphere", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.94, 0.94), ZIndex = 7}, holder)
		UI.round(ring, UDim.new(0.5, 0))
		local halo = UI.stroke(ring, 2.5, info and info.Accent or Color3.fromRGB(78, 159, 255), 0.55)
		local art = planetArt(holder, key, 8)
		local button = UI.new("TextButton", {Name = "Choose" .. key, Text = "", BackgroundTransparency = 1, AutoButtonColor = false, Size = UDim2.fromScale(0.95, 0.95),
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 10, Selectable = true}, holder)
		UI.round(button, UDim.new(0.5, 0))
		local label = UI.text(holder, name, UDim2.new(1, 120, 0, 40), UDim2.new(0, -60, 1, 4), 30)
		label.Name = "PlanetName"; label.TextXAlignment = Enum.TextXAlignment.Center; label.TextWrapped = false; label.ZIndex = 12
		local lock = UI.icon(holder, "LockWhite", UDim2.fromScale(0.26, 0.26), UDim2.fromScale(0.37, 0.37), {ZIndex = 11, Visible = false})
		local e = {key = key, holder = holder, scale = scale, glow = glow, halo = halo, art = art, button = button, label = label, lock = lock,
			slot = slot, galaxy = galaxyIndex, info = info, phase = rng:NextNumber(0, 6)}
		entries[key] = e
		return e
	end
	local home = makePlanet("Earth", "Earth", HOME, 0, nil)
	for g, galaxy in ipairs(config.GalaxyOrder) do
		for i, planet in ipairs(galaxy.Planets) do
			if SLOTS[i] then makePlanet(planet.Id, planet.Name, SLOTS[i], g, planet) end
		end
	end

	-- the player's real rocket, parked next to Earth
	local rocketView = UI.new("ViewportFrame", {Name = "Rocket", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(120, 150),
		Ambient = Color3.fromRGB(150, 150, 170), LightColor = Color3.fromRGB(255, 244, 225), LightDirection = Vector3.new(-1, -0.4, -0.8), ZIndex = 9}, stage)
	local rocketCamera = UI.new("Camera", {FieldOfView = 26}, rocketView)
	rocketView.CurrentCamera = rocketCamera
	local rocketFlame = UI.new("ImageLabel", {Name = "Flame", BackgroundTransparency = 1, Image = UI.Icons.Sparkle, ImageColor3 = Color3.fromRGB(255, 190, 90),
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.86, 0), Size = UDim2.fromOffset(36, 36), ZIndex = 8}, rocketView)
	local function loadRocket()
		for _, child in ipairs(rocketView:GetChildren()) do
			if child:IsA("WorldModel") or child:IsA("Camera") then child:Destroy() end
		end
		rocketCamera = UI.new("Camera", {FieldOfView = 26}, rocketView); rocketView.CurrentCamera = rocketCamera
		local world = workspace:FindFirstChild("PlanetForEggs")
		local base = world and world.Bases:FindFirstChild("Base" .. tostring(state.BaseIndex or 1))
		local rocket = base and base:FindFirstChild("Rocket")
		if not rocket then return end
		local clone = rocket:Clone()
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then d.Anchored = true; d.LocalTransparencyModifier = 0 -- Earth may be hidden while on a planet
			elseif d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("ParticleEmitter") or d:IsA("BillboardGui") then d:Destroy() end
		end
		local vp = UI.new("WorldModel", {}, rocketView)
		clone.Parent = vp
		local cf, size = clone:GetBoundingBox()
		local distance = size.Y / 2 / math.tan(math.rad(13)) * 1.08
		rocketCamera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(distance * 0.55, size.Y * 0.08, -distance * 0.84), cf.Position)
	end

	-- ---------------------------------------------------------------- chrome: title, arrows, card, close
	local title = UI.text(canvas, "", UDim2.fromOffset(700, 64), UDim2.new(0.5, -350, 0, 26), 56)
	title.Name = "GalaxyName"; title.TextXAlignment = Enum.TextXAlignment.Center; title.TextWrapped = false; title.ZIndex = 20
	local titleGradient = UI.new("UIGradient", {Rotation = 90}, title)
	local pips = UI.new("Frame", {Name = "Pages", BackgroundTransparency = 1, Size = UDim2.fromOffset(120, 16), Position = UDim2.new(0.5, -60, 0, 94), ZIndex = 20}, canvas)
	UI.list(pips, 12, true, Enum.HorizontalAlignment.Center)
	local pipFrames = {}
	for i = 1, #config.GalaxyOrder do
		local pip = UI.new("Frame", {BackgroundColor3 = C.White, Size = UDim2.fromOffset(14, 14), LayoutOrder = i, ZIndex = 20}, pips)
		UI.round(pip, 7); UI.stroke(pip, 2, C.Ink)
		pipFrames[i] = pip
	end
	local function arrowButton(name, key, pos)
		local b = UI.new("ImageButton", {Name = name, BackgroundTransparency = 1, Image = UI.Icons[key], ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(96, 96), ZIndex = 20}, canvas)
		local scale = UI.new("UIScale", {}, b)
		UI.pressFeedback(b, scale)
		return b
	end
	local prevButton = arrowButton("PrevGalaxy", "Prev", UDim2.new(0, 64, 0.5, 0))
	local nextButton = arrowButton("NextGalaxy", "Next", UDim2.new(1, -64, 0.5, 0))
	local close = UI.closeButton(canvas, function() end, UDim2.fromOffset(70, 70), UDim2.new(1, -94, 0, 22))
	close.ZIndex = 25

	local card = UI.new("Frame", {Name = "Details", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(560, 130),
		Position = UDim2.new(0.5, 0, 1, -18), ZIndex = 20}, canvas)
	local cardScale = UI.new("UIScale", {}, card)
	local cardName = UI.text(card, "", UDim2.new(1, 0, 0, 46), UDim2.fromOffset(0, 0), 44)
	cardName.TextXAlignment = Enum.TextXAlignment.Center; cardName.TextWrapped = false; cardName.ZIndex = 21
	local cardInfo = UI.text(card, "", UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 44), 20, C.Soft)
	cardInfo.TextXAlignment = Enum.TextXAlignment.Center; cardInfo.ZIndex = 21
	local launch = UI.button(card, "LAUNCH", C.Green, UDim2.fromOffset(240, 56), UDim2.new(0.5, -120, 0, 72), function() end, {TextSize = 30, Name = "Launch"})
	local launchCaption = launch:FindFirstChild("Caption", true)

	local controller = {}
	local function unlocked(key)
		if state.Busy or state.Planet == "Flight" then return false end
		local atEarth = state.Planet == nil or state.Planet == "Base" or state.Planet == "Earth"
		if key == "Earth" then return not atEarth end
		if not atEarth or state.Planet == key then return false end
		if state.DevTravel then return true end
		local required = config.Planets[key] and config.Planets[key].RequiredRange or math.huge
		local rocket = config.Rockets[math.clamp(tonumber(state.RocketLevel) or 1, 1, #config.Rockets)]
		return rocket.Range >= required
	end
	local function rocketNameFor(key)
		local required = config.Planets[key] and config.Planets[key].RequiredRange or 1
		for _, r in ipairs(config.Rockets) do if r.Range >= required then return r.Name end end
		return "a better rocket"
	end
	local function launchTo(key)
		if not opened or not key or not unlocked(key) then return end
		controller:Close()
		if key == "Earth" then opts.Send("Return") else opts.Send("Launch", key) end
	end

	local function refreshCard()
		-- the chosen planet's name is the card's big title: its own small label hides (they overlapped on phones)
		for k, entry in pairs(entries) do entry.label.Visible = k ~= selected end
		local e = selected and entries[selected]
		card.Visible = e ~= nil
		if not e then return end
		local atEarth = state.Planet == nil or state.Planet == "Base" or state.Planet == "Earth"
		local info = e.info
		cardName.Text = string.upper(e.key == "Earth" and "Earth" or info.Name)
		if e.key == "Earth" then
			cardInfo.Text = atEarth and "You are here" or "Fly home"
		elseif state.Planet == e.key then
			cardInfo.Text = "You are here"
		elseif unlocked(e.key) then
			cardInfo.Text = ""
		else
			cardInfo.Text = "Needs " .. rocketNameFor(e.key)
		end
		local can = unlocked(e.key)
		launch.Visible = true
		launchCaption.Text = can and (e.key == "Earth" and "FLY HOME" or "LAUNCH") or (state.Planet == e.key and "HERE" or "LOCKED")
		UI.disable(launch, not can)
		if can then UI.setButtonColor(launch, C.Green) end
	end
	local function choose(key)
		if selected == key then return end
		selected = key
		for k, e in pairs(entries) do
			UI.tween(e.scale, {Scale = k == key and 1.1 or 1}, 0.3, Enum.EasingStyle.Back)
			UI.tween(e.glow, {ImageTransparency = k == key and 0.62 or 1}, 0.25)
			UI.tween(e.halo, {Transparency = k == key and 0.1 or 0.55}, 0.2)
			e.halo.Color = k == key and C.White or (e.info and e.info.Accent or Color3.fromRGB(78, 159, 255))
		end
		refreshCard()
	end
	local function showPage(index, instant)
		index = ((index - 1) % #config.GalaxyOrder) + 1
		page = index
		local galaxy = config.GalaxyOrder[page]
		title.Text = string.upper(galaxy.Name)
		titleGradient.Color = ColorSequence.new(C.White, galaxy.Color:Lerp(C.White, 0.25))
		for i, pip in ipairs(pipFrames) do
			pip.BackgroundColor3 = i == page and galaxy.Color or C.Muted
			pip.Size = i == page and UDim2.fromOffset(30, 14) or UDim2.fromOffset(14, 14)
		end
		for i, image in ipairs(backdrops) do UI.tween(image, {ImageTransparency = i == page and 0 or 1}, instant and 0 or 0.45) end
		-- choose a sensible planet on this page
		local best
		for _, planet in ipairs(galaxy.Planets) do
			if not best and unlocked(planet.Id) then best = planet.Id end
		end
		choose(best or (galaxy.Planets[1] and galaxy.Planets[1].Id))
		if instant then pageShown = page end
	end

	for key, e in pairs(entries) do
		table.insert(connections, e.button.Activated:Connect(function()
			if not opened then return end
			if selected == key then launchTo(key) else choose(key) end
		end))
		table.insert(connections, e.button.MouseEnter:Connect(function()
			if opened and not Input.TouchEnabled then UI.tween(e.scale, {Scale = selected == key and 1.12 or 1.06}, 0.2) end
		end))
		table.insert(connections, e.button.MouseLeave:Connect(function()
			if opened then UI.tween(e.scale, {Scale = selected == key and 1.1 or 1}, 0.2) end
		end))
	end
	table.insert(connections, launch.Activated:Connect(function() launchTo(selected) end))
	table.insert(connections, prevButton.Activated:Connect(function() showPage(page - 1) end))
	table.insert(connections, nextButton.Activated:Connect(function() showPage(page + 1) end))

	local function closeMap()
		if not alive or not opened then return end
		opened = false; gui.Enabled = false; player:SetAttribute("PFEPlanetMapOpen", false)
		local sel = GuiService.SelectedObject
		if sel and sel:IsDescendantOf(gui) then GuiService.SelectedObject = nil end
		if opts.OnClosed then opts.OnClosed() end
	end
	table.insert(connections, close.Activated:Connect(closeMap))

	-- ---------------------------------------------------------------- layout
	local lastSize = Vector2.zero
	local planetBase = 200
	local function screenSize()
		local camera = workspace.CurrentCamera
		local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
		if size.X < 10 then size = canvas.AbsoluteSize end
		return size
	end
	local function layout()
		local size = screenSize()
		if size == lastSize then return end
		lastSize = size
		local touch = Input.TouchEnabled and not GuiService:IsTenFootInterface()
		local base = math.clamp(math.min(size.X * 0.2, size.Y * 0.34), 90, touch and 210 or 320)
		planetBase = base
		for _, e in pairs(entries) do
			e.holder.Size = UDim2.fromOffset(base * e.slot[3], base * e.slot[3])
			e.label.TextSize = math.clamp(base * 0.13, touch and 16 or 20, touch and 26 or 32)
		end
		local ui = math.clamp(math.min(size.X / 1280, size.Y / 720) * (touch and 1.15 or 1), 0.55, 1.3)
		cardScale.Scale = ui
		title.TextSize = math.floor(52 * ui)
		for _, b in ipairs({prevButton, nextButton}) do b.Size = UDim2.fromOffset(88 * ui, 88 * ui) end
		prevButton.Position = UDim2.new(0, 60 * ui, 0.5, 0); nextButton.Position = UDim2.new(1, -60 * ui, 0.5, 0)
		close.Size = UDim2.fromOffset(66 * ui, 66 * ui); close.Position = UDim2.new(1, -90 * ui, 0, 20 * ui)
		rocketView.Size = UDim2.fromOffset(base * 0.5, base * 0.62)
	end

	function controller:Update(nextState)
		if not alive then return end
		if type(nextState) == "table" then state = nextState end
		for key, e in pairs(entries) do
			local seen = key == "Earth" or unlocked(key) or state.Planet == key or state.DevTravel
			e.art.ImageColor3 = seen and C.White or Color3.fromRGB(70, 72, 90)
			e.lock.Visible = not seen
			e.label.TextTransparency = 0
		end
		refreshCard()
		if state.Busy or state.Planet == "Flight" then closeMap() end
	end
	function controller:Open(nextState)
		if not alive then return end
		self:Update(nextState)
		if state.Busy or state.Planet == "Flight" or player:GetAttribute("PFEFlightActive") then return end
		if opened then return end
		opened = true; gui.Enabled = true; player:SetAttribute("PFEPlanetMapOpen", true)
		lastSize = Vector2.zero; layout()
		loadRocket()
		-- start on the galaxy of the furthest planet the rocket can reach
		local target = 1
		for g, galaxy in ipairs(config.GalaxyOrder) do
			for _, planet in ipairs(galaxy.Planets) do if unlocked(planet.Id) then target = g end end
		end
		selected = nil
		showPage(target, true)
		for _, e in pairs(entries) do e.scale.Scale = 0.8; UI.tween(e.scale, {Scale = e.key == selected and 1.1 or 1}, 0.5, Enum.EasingStyle.Back) end
		if Input.GamepadEnabled and selected then GuiService.SelectedObject = entries[selected].button end
		if opts.OnOpened then opts.OnOpened() end
	end
	function controller:Close() closeMap() end
	function controller:IsOpen() return opened end
	function controller:Page() return page end
	function controller:Select(key) choose(key) end
	function controller:ShowPage(index) showPage(index) end
	local function dispose(destroyGui)
		if not alive then return end
		closeMap(); alive = false
		for _, connection in ipairs(connections) do connection:Disconnect() end
		if activeControllers[player] == controller then activeControllers[player] = nil end
		player:SetAttribute("PFEPlanetMapOpen", false)
		if destroyGui then gui:Destroy() end
	end
	function controller:Destroy() dispose(true) end
	table.insert(connections, gui.Destroying:Connect(function() dispose(false) end))
	table.insert(connections, player.CharacterRemoving:Connect(closeMap))
	table.insert(connections, Input.InputBegan:Connect(function(input, processed)
		if not opened or processed then return end
		local k = input.KeyCode
		if k == Enum.KeyCode.Escape or k == Enum.KeyCode.ButtonB then closeMap()
		elseif k == Enum.KeyCode.Q or k == Enum.KeyCode.Left or k == Enum.KeyCode.ButtonL1 then showPage(page - 1)
		elseif k == Enum.KeyCode.E or k == Enum.KeyCode.Right or k == Enum.KeyCode.ButtonR1 then showPage(page + 1)
		elseif k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA then launchTo(selected) end
	end))
	-- swipe between galaxies on phones
	local swipeStart
	table.insert(connections, Input.TouchStarted:Connect(function(touch) if opened then swipeStart = touch.Position end end))
	table.insert(connections, Input.TouchEnded:Connect(function(touch)
		if opened and swipeStart then
			local dx = touch.Position.X - swipeStart.X
			if math.abs(dx) > 120 then showPage(page + (dx < 0 and 1 or -1)) end
		end
		swipeStart = nil
	end))
	table.insert(connections, player:GetAttributeChangedSignal("PFEFlightActive"):Connect(function()
		if player:GetAttribute("PFEFlightActive") then closeMap() end
	end))

	-- ---------------------------------------------------------------- animation
	local time, slide = 0, 0
	table.insert(connections, Run.RenderStepped:Connect(function(dt)
		if not opened then return end
		time += dt; layout()
		local bounds = screenSize()
		local pointer = Input:GetMouseLocation()
		local px = math.clamp(pointer.X / math.max(1, bounds.X) - 0.5, -0.5, 0.5)
		local py = math.clamp(pointer.Y / math.max(1, bounds.Y) - 0.5, -0.5, 0.5)
		-- page slide: pages sit side by side, the view eases towards the current one
		slide += (page - slide) * math.min(1, dt * 7)
		if math.abs(page - slide) < 0.001 then slide = page end
		pageShown = page
		for i, image in ipairs(backdrops) do
			image.Position = UDim2.fromScale(0.5 + math.sin(time * 0.05 + i) * 0.006 - px * 0.01, 0.5 + math.cos(time * 0.04 + i) * 0.006 - py * 0.01)
		end
		for _, star in ipairs(stars) do
			star.object.Position = UDim2.new((star.x - slide * 0.05 * star.depth + time * 0.0006 * star.depth) % 1, -px * star.depth * 17, star.y, -py * star.depth * 12)
			star.object.BackgroundTransparency = 0.25 + (0.5 + 0.5 * math.sin(time * 0.65 + star.phase)) * 0.5
		end
		local W, H = bounds.X, bounds.Y
		for key, e in pairs(entries) do
			local x, y
			if e.galaxy == 0 then
				x, y = e.slot[1], e.slot[2]
			else
				x = e.slot[1] + (e.galaxy - slide)
				y = e.slot[2]
			end
			e.holder.Visible = x > -0.3 and x < 1.3
			local ox, oy = -px * (13 - e.slot[3] * 4), math.sin(time * 0.46 + e.phase) * 5 - py * 7
			e.holder.Position = UDim2.new(x, ox, y, oy)
			e.screenX, e.screenY, e.screenR = x * W + ox, y * H + oy, planetBase * e.slot[3] * 0.5
			e.glow.Rotation = (time * 12 + e.phase * 30) % 360
		end
		-- rocket next to Earth, turning towards the selection
		local target = selected and entries[selected]
		local ex, ey, er = home.screenX or 0, home.screenY or 0, home.screenR or 50
		local rx, ry = ex + er * 1.25, ey - er * 0.85
		rocketView.Position = UDim2.fromOffset(rx, ry + math.sin(time * 1.4) * 4)
		local routeVisible = target and target ~= home and target.holder.Visible
		if routeVisible then
			local tx, ty = target.screenX or 0, target.screenY or 0
			local angle = math.deg(math.atan2(tx - rx, -(ty - ry)))
			rocketView.Rotation = rocketView.Rotation + (math.clamp(angle, -80, 80) - rocketView.Rotation) * math.min(1, dt * 6)
			-- dotted arc from the rocket to the planet's edge
			local radius = (target.screenR or 50) * 1.15
			local dx, dy = tx - rx, ty - ry
			local len = math.max(1, math.sqrt(dx * dx + dy * dy))
			local endX, endY = tx - dx / len * radius, ty - dy / len * radius
			local cx, cy = (rx + endX) / 2 - dy * 0.12, (ry + endY) / 2 - math.abs(dx) * 0.12
			local can = unlocked(selected)
			for i, dot in ipairs(dots) do
				local t = (i - 1) / (#dots - 1)
				local u = 1 - t
				local x = u * u * rx + 2 * u * t * cx + t * t * endX
				local y = u * u * ry + 2 * u * t * cy + t * t * endY
				dot.Position = UDim2.fromOffset(x, y)
				dot.Visible = t > 0.08
				local pulse = 0.5 + 0.5 * math.sin(time * 6 - i * 0.6)
				dot.BackgroundColor3 = can and Color3.fromRGB(255, 230, 120) or C.Muted
				dot.BackgroundTransparency = can and (0.1 + (1 - pulse) * 0.5) or 0.5
				dot.Size = UDim2.fromOffset(can and (5 + pulse * 3) or 4, can and (5 + pulse * 3) or 4)
			end
		else
			rocketView.Rotation = rocketView.Rotation * (1 - math.min(1, dt * 4))
			for _, dot in ipairs(dots) do dot.Visible = false end
		end
		rocketFlame.ImageTransparency = 0.25 + 0.3 * math.sin(time * 20)
		rocketFlame.Size = UDim2.fromOffset(30 + math.sin(time * 17) * 5, 30 + math.cos(time * 13) * 5)
	end))
	controller:Update(state)
	showPage(1, true)
	activeControllers[player] = controller
	return controller
end
return M
