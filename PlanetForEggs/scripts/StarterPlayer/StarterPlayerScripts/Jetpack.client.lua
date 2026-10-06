--!nocheck
-- Jetpacks. Your own: hold jump in the air (Space, the mobile jump button or gamepad A) to fly.
-- A charge lasts Config.Jetpacks[level].FlightTime seconds; when it runs out the pack switches off
-- and refills in Recharge seconds (it also refills whenever you are not flying). The fuel gauge
-- sits at the right edge. Everyone's pack shows flames while its owner flies.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local UI = require(api:WaitForChild("UIKit"))
local C = UI.C
local player = Players.LocalPlayer

local state = {JetpackLevel = 1}
api:WaitForChild("State").OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	if payload.Light then
		state.Stolen = payload.Stolen
		return
	end
	state.JetpackLevel = payload.JetpackLevel or state.JetpackLevel
	state.Minigame = payload.Minigame
	state.Stolen = payload.Stolen
end)
local function pack() return Config.Jetpacks[state.JetpackLevel] or Config.Jetpacks[1] end

-- ---------------------------------------------------------------- flames for every character
local flames = {}
local function setFlames(character, on)
	local rig = flames[character]
	if not rig then
		local jet = character:FindFirstChild("PFEJetpack")
		if not jet then return end
		rig = {}
		for _, name in ipairs({"NozzleL", "NozzleR"}) do
			local nozzle = jet:FindFirstChild(name)
			if nozzle then
				local attachment = Instance.new("Attachment"); attachment.Parent = nozzle
				local fire = Instance.new("ParticleEmitter")
				fire.Texture = "rbxasset://textures/particles/fire_main.dds"; fire.EmissionDirection = Enum.NormalId.Top
				fire.Rate = 70; fire.Lifetime = NumberRange.new(0.12, 0.26); fire.Speed = NumberRange.new(10, 16)
				fire.SpreadAngle = Vector2.new(8, 8); fire.LightEmission = 1; fire.LightInfluence = 0
				fire.Color = ColorSequence.new(Color3.fromRGB(255, 244, 170), Color3.fromRGB(255, 96, 24))
				fire.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.5, 1.2), NumberSequenceKeypoint.new(1, 0)})
				fire.Transparency = NumberSequence.new(0.05, 1); fire.Enabled = false; fire.Parent = attachment
				local smoke = Instance.new("ParticleEmitter")
				smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"; smoke.EmissionDirection = Enum.NormalId.Top
				smoke.Rate = 14; smoke.Lifetime = NumberRange.new(0.5, 0.9); smoke.Speed = NumberRange.new(4, 7)
				smoke.Color = ColorSequence.new(Color3.fromRGB(230, 230, 236)); smoke.Size = NumberSequence.new(0.8, 2.6)
				smoke.Transparency = NumberSequence.new(0.55, 1); smoke.Enabled = false; smoke.Parent = attachment
				table.insert(rig, fire); table.insert(rig, smoke)
			end
		end
		local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(255, 170, 80); light.Range = 12; light.Brightness = 0
		light.Parent = jet:FindFirstChild("Engine") or jet:FindFirstChildWhichIsA("BasePart")
		rig.Light = light
		flames[character] = rig
	end
	for _, emitter in ipairs(rig) do emitter.Enabled = on end
	if rig.Light then rig.Light.Brightness = on and 2 or 0 end
end
-- (v35) whose flames are burning: your own follow your own thrust straight away (no round trip to the server); everyone
-- else's follow their PFEJetting - but never under someone who is standing on the ground (a lost "off" can't leave a
-- pack burning under a player who walks about any more)
local watched = {}       -- character -> {Root, Grounded = seconds on the ground}
local function update(character)
	if character == player.Character then return end
	local record = watched[character]
	local on = character:GetAttribute("PFEJetting") == true and not (record and record.Grounded > 0.3)
	setFlames(character, on)
end
local function watchCharacter(character)
	if not character or watched[character] then return end
	watched[character] = {Grounded = 0}
	character:GetAttributeChangedSignal("PFEJetting"):Connect(function()
		local record = watched[character]
		if record then record.Grounded = 0 end
		update(character)
	end)
	character.AncestryChanged:Connect(function()
		if not character.Parent then flames[character] = nil; watched[character] = nil end
	end)
	task.defer(update, character)
end
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local groundClock = 0
RunService.Heartbeat:Connect(function(dt)
	groundClock += dt
	if groundClock < 0.1 then return end
	local step = groundClock
	groundClock = 0
	for character, record in pairs(watched) do
		if character ~= player.Character and character:GetAttribute("PFEJetting") == true then
			local root = character:FindFirstChild("HumanoidRootPart")
			local grounded = false
			if root then
				groundParams.FilterDescendantsInstances = {character}
				local hit = workspace:Raycast(root.Position, Vector3.new(0, -4.2, 0), groundParams)
				grounded = hit ~= nil and math.abs(root.AssemblyLinearVelocity.Y) < 3
			end
			local before = record.Grounded > 0.3
			record.Grounded = grounded and record.Grounded + step or 0
			if (record.Grounded > 0.3) ~= before then update(character) end
		end
	end
end)
local function watchPlayer(other)
	if other.Character then watchCharacter(other.Character) end
	other.CharacterAdded:Connect(watchCharacter)
end
for _, other in ipairs(Players:GetPlayers()) do watchPlayer(other) end
Players.PlayerAdded:Connect(watchPlayer)
-- (v30) the bots' jetpacks flame too
task.spawn(function()
	local botFolder = workspace:WaitForChild("PFE_Bots", 30)
	if not botFolder then return end
	local seen = {}
	local function watchBot(bot)
		if seen[bot] then return end
		seen[bot] = true
		watchCharacter(bot)
	end
	for _, bot in ipairs(botFolder:GetChildren()) do watchBot(bot) end
	botFolder.ChildAdded:Connect(watchBot)
end)

-- ---------------------------------------------------------------- fuel gauge
local gui = UI.new("ScreenGui", {Name = "PFE_Jetpack", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 21}, player:WaitForChild("PlayerGui"))
-- a flat fuel bar in the middle above the hotbar (the raygun's energy is the upright bar on the right)
local gauge = UI.new("Frame", {Name = "Fuel", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -190), Size = UDim2.fromOffset(220, 16),
	BackgroundColor3 = Color3.fromRGB(24, 26, 44), BackgroundTransparency = 0.15, Visible = false}, gui)
UI.round(gauge, 8); UI.stroke(gauge, 2.5, C.Ink)
local gaugeScale = UI.new("UIScale", {}, gauge)
local fill = UI.new("Frame", {Name = "Fill", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.new(1, -6, 1, -6),
	BackgroundColor3 = C.White, BorderSizePixel = 0}, gauge)
UI.round(fill, 6)
local fillGradient = UI.new("UIGradient", {Rotation = 0}, fill)
local caption = UI.text(gauge, "", UDim2.fromOffset(120, 20), UDim2.new(1, 8, 0.5, -10), 14, C.White)
caption.TextWrapped = false
local icon = UI.text(gauge, "JET", UDim2.fromOffset(40, 18), UDim2.new(0, -46, 0.5, -9), 14, C.White)
icon.TextXAlignment = Enum.TextXAlignment.Right
local function layoutGauge()
	local camera = workspace.CurrentCamera
	if not camera then return end
	gaugeScale.Scale = math.clamp(camera.ViewportSize.Y / 720, 0.5, 1.1)
	gauge.Position = UDim2.new(0.5, 0, 1, UI.isTouch() and -(96 + UI.bottomMargin()) or -190)
end
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutGauge) end
layoutGauge()

-- ---------------------------------------------------------------- flight
local charge = pack().FlightTime
local locked, jetting, sent = false, false, false
local airTime = 0
local jetSound = Instance.new("Sound")
jetSound.SoundId = "rbxasset://sounds/action_falling.ogg"; jetSound.Looped = true; jetSound.Volume = 0; jetSound.PlaybackSpeed = 1.6
jetSound.Parent = SoundService
local thrustSound -- the jetpack's roar while it pushes (Config.Sounds.Jetpack)
local function holdingJump(humanoid)
	local ok, key = pcall(function() return UserInputService:IsKeyDown(Enum.KeyCode.Space) end)
	if ok and key then return true end
	local okPad, pad = pcall(function() return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA) end)
	if okPad and pad then return true end
	return UserInputService.TouchEnabled and humanoid.Jump == true
end
local lastSent = 0
local function report(on)
	local character = player.Character
	-- (v35) say it again if the server's copy disagrees for a moment (a message can still get lost)
	local stale = character and character:GetAttribute("PFEJetting") ~= nil and character:GetAttribute("PFEJetting") ~= on
		and os.clock() - lastSent > 0.35
	if on ~= sent or stale then
		sent = on
		lastSent = os.clock()
		api:WaitForChild("Jet"):FireServer(on)
	end
	if character then setFlames(character, on) end
end

RunService.Heartbeat:Connect(function(dt)
	local stats = pack()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 or not character:FindFirstChild("PFEJetpack") then
		if jetting then jetting = false; report(false) end
		if thrustSound and thrustSound.IsPlaying then thrustSound:Stop() end
		gauge.Visible = false
		return
	end
	local airborne = humanoid.FloorMaterial == Enum.Material.Air
	airTime = airborne and airTime + dt or 0
	local blocked = player:GetAttribute("PFEFlightActive") == true or state.Stolen ~= nil or humanoid.Sit or root.Anchored
	local want = not blocked and not locked and charge > 0 and airborne and airTime > 0.2 and holdingJump(humanoid)
	if want then
		jetting = true
		if not thrustSound or thrustSound.Parent ~= root then
			if thrustSound then thrustSound:Destroy() end
			thrustSound = Instance.new("Sound"); thrustSound.Name = "JetpackThrust"; thrustSound.SoundId = Config.Sounds.Jetpack
			thrustSound.Looped = true; thrustSound.Volume = 0.45; thrustSound.Parent = root
		end
		if not thrustSound.IsPlaying then thrustSound:Play() end
		charge = math.max(0, charge - dt)
		local v = root.AssemblyLinearVelocity
		-- towards the pack's climb speed, plus what gravity takes away this frame (without it the
		-- pack could never lift you on the bases' island or the heavier planets)
		local rise = v.Y + (stats.Thrust - v.Y) * math.min(1, dt * 7) + workspace.Gravity * dt
		root.AssemblyLinearVelocity = Vector3.new(v.X, rise, v.Z)
		if charge <= 0 then locked = true end
	else
		jetting = false
		if thrustSound and thrustSound.IsPlaying then thrustSound:Stop() end
		-- refills between flights; an empty pack stays off until it is full again (Meteor Run: 3x faster)
		local refill = stats.FlightTime / stats.Recharge * (state.Minigame and 3 or 1)
		charge = math.min(stats.FlightTime, charge + dt * refill)
		if locked and charge >= stats.FlightTime then locked = false end
	end
	report(jetting)
	-- (the thrust sound above is the pack's only sound)
	-- gauge: shows while flying or refilling
	local ratio = charge / stats.FlightTime
	gauge.Visible = ratio < 0.999 or jetting
	fill.Size = UDim2.new(ratio, -6 * ratio, 1, -6)
	local color = locked and Color3.fromRGB(255, 80, 80) or stats.Glow
	fillGradient.Color = ColorSequence.new(color:Lerp(C.White, 0.35), color)
	caption.Text = locked and "RECHARGING" or (UserInputService.TouchEnabled and "HOLD JUMP" or "HOLD SPACE")
	caption.TextColor3 = locked and Color3.fromRGB(255, 120, 120) or C.White
end)
player.CharacterAdded:Connect(function()
	charge = pack().FlightTime; locked = false; jetting = false; sent = false
end)
