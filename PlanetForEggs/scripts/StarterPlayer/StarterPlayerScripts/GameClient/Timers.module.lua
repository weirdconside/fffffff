--!nocheck
-- The timers along the bottom of the screen, side by side above the hotbar, styled like Steal an
-- Egg's reset timer (a black band that fades out at both ends, an icon and white outlined text):
--   * planets reset in 3m 30s        (every Config.MapCycle; the last ten seconds pulse red)
--   * Meteor Run in 24m 10s          (the minigame; "you're in the circle!" while queued)
--   * the next / running world event (Meteor Shower, Golden Hour, Starfall, Egg Storm, Aurora)
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Timers = {}

local ICONS = {
	Reset = "Stopwatch",
	Meteor = "rbxassetid://74741161145180",
	MeteorShower = "rbxassetid://74741161145180",
	GoldenHour = "rbxassetid://86038047961937",
	Starfall = "rbxassetid://127455440418221",
	EggStorm = "EggBig",
	Aurora = "rbxassetid://83627475909869",
	PumpkinNight = "rbxassetid://127455440418221",
}
local FALLBACK_ICON = "rbxassetid://127455440418221"

local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 60 then return string.format("%dm %02ds", seconds // 60, seconds % 60) end
	return seconds .. "s"
end

function Timers.Init(store)
	local UI, Config, player = store.UI, store.Config, store.player
	local C = UI.C
	local PILL_W, PILL_H, GAP = 290, 42, 8

	local row = UI.new("Frame", {Name = "BottomTimers", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -84),
		Size = UDim2.fromOffset(PILL_W * 3 + GAP * 2, PILL_H), BackgroundTransparency = 1, ZIndex = 10}, store.gui)
	local scale = UI.new("UIScale", {}, row)
	UI.new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder}, row)

	local function pill(name, order, icon)
		local frame = UI.new("Frame", {Name = name, Size = UDim2.fromOffset(PILL_W, PILL_H), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 10}, row)
		local pulse = UI.new("UIScale", {}, frame)
		local band = UI.new("Frame", {Name = "Band", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.12, 1), ZIndex = 10}, frame)
		local fade = UI.new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.16, 0.42),
			NumberSequenceKeypoint.new(0.84, 0.42), NumberSequenceKeypoint.new(1, 1)})}, band)
		local image = UI.icon(frame, icon, UDim2.fromOffset(36, 36), UDim2.new(0, 10, 0.5, -18), {ZIndex = 12})
		local text = UI.text(frame, "", UDim2.new(1, -62, 1, 0), UDim2.fromOffset(52, 0), 19, C.White)
		text.TextWrapped = false; text.TextScaled = true; text.ZIndex = 12
		UI.new("UITextSizeConstraint", {MaxTextSize = 19}, text)
		local stroke = text:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color = Color3.new(0, 0, 0); stroke.Thickness = 2.2 end
		return {Frame = frame, Pulse = pulse, Band = band, Fade = fade, Icon = image, Text = text}
	end
	local reset = pill("PlanetReset", 1, ICONS.Reset)
	local meteor = pill("MeteorRun", 2, ICONS.Meteor)
	local event = pill("WorldEvent", 3, ICONS.Starfall)

	function store.TimersTop()
		return row.AbsolutePosition.Y
	end

	local function layout()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local vp = camera.ViewportSize
		local s = math.clamp(math.min(UI.scaleFor(vp), (vp.X - 24) / (PILL_W * 3 + GAP * 2)), 0.48, 1.05)
		scale.Scale = s
		row.Position = UDim2.new(0.5, 0, 1, UI.isTouch() and -(58 + UI.bottomMargin()) or -86)
	end
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
	layout()

	local function sound(id, volume, speed)
		local s = Instance.new("Sound"); s.SoundId = id; s.Volume = volume; s.PlaybackSpeed = speed or 1; s.Parent = SoundService
		s:Play(); Debris:AddItem(s, 3)
	end

	-- "NEW PLANETS!" splash when the maps change
	local function splash(title, subtitle, color)
		local frame = UI.new("Frame", {Name = "MapResetSplash", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromOffset(560, 120), BackgroundTransparency = 1, ZIndex = 40}, store.overlay)
		local s = UI.new("UIScale", {Scale = 0.3}, frame)
		local burst = UI.sunburst(frame, UDim2.fromOffset(360, 360), color, 0.45)
		burst.ZIndex = 40
		local head = UI.text(frame, title, UDim2.fromScale(1, 0.62), UDim2.fromScale(0, 0.05), 54, C.Gold)
		head.TextXAlignment = Enum.TextXAlignment.Center; head.TextWrapped = false; head.ZIndex = 42
		local sub = UI.text(frame, subtitle, UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.66), 22, C.White)
		sub.TextXAlignment = Enum.TextXAlignment.Center; sub.ZIndex = 42
		UI.tween(s, {Scale = 1}, 0.35, Enum.EasingStyle.Back)
		sound(Config.Sfx.Sparkle, 0.8, 1)
		task.delay(2.2, function()
			if not frame.Parent then return end
			UI.tween(s, {Scale = 0.2}, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.delay(0.26, function() frame:Destroy() end)
		end)
	end
	workspace:GetAttributeChangedSignal("PFEMapSeed"):Connect(function()
		if store.flying() then return end
		local ok, err = pcall(splash, "NEW PLANETS!", "Forests moved - fresh eggs are hidden", Color3.fromRGB(122, 84, 255))
		if not ok then warn("[PFE] reset splash: " .. tostring(err)) end
	end)
	workspace:GetAttributeChangedSignal("PFEEvent"):Connect(function()
		local id = workspace:GetAttribute("PFEEvent")
		local info = Config.Events[id]
		if info and not store.flying() then splash(string.upper(info.Name) .. "!", info.Buff, info.Color) end
	end)

	local function set(p, text, color)
		if p.Text.Text ~= text then p.Text.Text = text end
		if color and p.Text.TextColor3 ~= color then p.Text.TextColor3 = color end
	end
	local lastSecond, hurry = -1, false
	RunService.RenderStepped:Connect(function()
		row.Visible = not store.flying() and player:GetAttribute("PFEPlanetMapOpen") ~= true and not store.menuOpen()
		if not row.Visible then return end
		local now = workspace:GetServerTimeNow()
		-- planets reset
		local resetAt = workspace:GetAttribute("PFEMapResetAt")
		if type(resetAt) == "number" then
			local left = resetAt - now
			local seconds = math.ceil(math.max(0, left))
			set(reset, "Planets reset in " .. clock(left), seconds <= 10 and Color3.fromRGB(255, 110, 110) or C.White)
			if seconds ~= lastSecond then
				lastSecond = seconds
				hurry = seconds <= 10 and seconds > 0
				if hurry then
					reset.Pulse.Scale = 1.08; UI.tween(reset.Pulse, {Scale = 1}, 0.35, Enum.EasingStyle.Back)
					sound(Config.Sfx.Tick, 0.3, 1.2)
				end
			end
		end
		-- Meteor Run
		local runEnds = workspace:GetAttribute("PFEMinigameEndsAt") or 0
		local runAt = workspace:GetAttribute("PFEMinigameAt") or 0
		if runEnds > now then
			set(meteor, "Meteor Run LIVE " .. clock(runEnds - now), Color3.fromRGB(255, 190, 80))
		elseif player:GetAttribute("PFEQueued") then
			set(meteor, "In the circle! " .. clock(runAt - now), Color3.fromRGB(120, 255, 150))
		else
			set(meteor, "Meteor Run in " .. clock(runAt - now), C.White)
		end
		-- world event
		local current = workspace:GetAttribute("PFEEvent")
		local info = Config.Events[current]
		if info and (workspace:GetAttribute("PFEEventEndsAt") or 0) > now then
			set(event, info.Name .. " LIVE " .. clock(workspace:GetAttribute("PFEEventEndsAt") - now), info.Color)
			local icon = ICONS[info.Id]; icon = UI.Icons[icon] or icon or FALLBACK_ICON
			if event.Icon.Image ~= icon then event.Icon.Image = icon end
		else
			local nextInfo = Config.Events[workspace:GetAttribute("PFEEventNext")]
			if nextInfo then
				set(event, nextInfo.Name .. " in " .. clock((workspace:GetAttribute("PFEEventNextAt") or now) - now), C.White)
				local icon = ICONS[nextInfo.Id]; icon = UI.Icons[icon] or icon or FALLBACK_ICON
				if event.Icon.Image ~= icon then event.Icon.Image = icon end
			end
		end
	end)
end

return Timers
