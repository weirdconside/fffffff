--!nocheck
-- The alien raygun (99 Nights' first, endless gun) and everything the aliens do on screen.
--  * The Raygun tile sits left of the bat in the hotbar row (R / gamepad Y takes it out). With it out,
--    click / tap to shoot; hold to keep firing. Shots lock on to an alien near where you aim.
--    Not while an egg is in your hands.
--  * Laser bolts are 99 Nights' LaserBullet (green for players, the alien's colour for theirs);
--    the server decides hits, the bolts are shown to everyone on the planet.
--  * Aliens shout "!" when they spot you, flash when hit and burst when defeated; their hits knock
--    you back a little.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local UI = require(api:WaitForChild("UIKit"))
local C = UI.C
local player = Players.LocalPlayer
local R = Config.Raygun
local gear = api:WaitForChild("Gear", 10)
local fxFolder = Instance.new("Folder")
fxFolder.Name = "PFE_LaserFX"
fxFolder.Parent = workspace

-- ---------------------------------------------------------------- the tile
local gui = UI.new("ScreenGui", {Name = "PFE_Raygun", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 21}, player:WaitForChild("PlayerGui"))
local holder = UI.new("Frame", {Name = "EquipRaygun", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -320, 1, -8), Size = UDim2.fromOffset(78, 78),
	BackgroundTransparency = 1}, gui)
local scale = UI.new("UIScale", {}, holder)
local button = UI.tile(holder, R.Icon, "Raygun", Color3.fromRGB(24, 150, 118), UDim2.fromOffset(78, 78), nil, "EquipRaygun")
local handsShade = UI.new("Frame", {Name = "HandsFull", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
	Size = UDim2.fromScale(1, 1), ZIndex = 12, Visible = false}, button)
UI.round(handsShade, 18)
local keyHint = UI.text(holder, "1", UDim2.fromOffset(20, 20), UDim2.fromOffset(6, 3), 16, C.White)
keyHint.TextXAlignment = Enum.TextXAlignment.Center; keyHint.ZIndex = 20 -- over the tile, like the hotbar slot numbers
keyHint.Visible = not UI.isTouch()

local function tool()
	local character = player.Character
	return (character and character:FindFirstChild("Raygun")) or player:FindFirstChildOfClass("Backpack") and player.Backpack:FindFirstChild("Raygun")
end
local function equipped()
	local character = player.Character
	return character ~= nil and character:FindFirstChild("Raygun") ~= nil
end
local function handsFull()
	return player:GetAttribute("PFECarrying") == true or player:GetAttribute("PFEHoldingStoredEgg") == true
end
local function toggle()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local gun = tool()
	if not humanoid or not gun then return end
	if equipped() then humanoid:UnequipTools() elseif not handsFull() then humanoid:EquipTool(gun) end
end
button.Activated:Connect(toggle)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or player:GetAttribute("PFEPlanetMapOpen") then return end
	if input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonY then toggle() end -- (1 works too, via the hotbar)
end)

-- ---------------------------------------------------------------- the AlienBar (99 Nights' energy bar)
-- Shown while the raygun is out (EnergyResourceClient's ShowEnergyBar / HideEnergyBar): a big upright
-- bar on the right of the screen (left of the planet tracker), cyan on navy, filling from the bottom;
-- it flashes green when energy comes back, pulses red while overheated, and a warning segment shows
-- the cost when there isn't enough for a shot. The number under it is the energy left.
local NAVY, CYAN, RED, GREEN = Color3.fromRGB(0, 10, 104), Color3.fromRGB(0, 234, 255), Color3.fromRGB(255, 0, 6), Color3.fromRGB(55, 255, 0)
local barHolder = UI.new("Frame", {Name = "EnergyHolder", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -100, 0.5, 0),
	Size = UDim2.fromOffset(44, 320), BackgroundTransparency = 1, Visible = false, ZIndex = 30}, gui)
local barScale = UI.new("UIScale", {}, barHolder)
local alienBar = UI.new("Frame", {Name = "AlienBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.new(0, 30, 1, -76),
	BackgroundColor3 = NAVY, BorderSizePixel = 0, ZIndex = 30}, barHolder)
UI.round(alienBar, 15)
local barStroke = UI.new("UIStroke", {Color = Color3.fromRGB(10, 10, 30), Thickness = 3}, alienBar)
local barFill = UI.new("Frame", {Name = "Bar", BackgroundColor3 = CYAN, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 1), ZIndex = 31}, alienBar)
UI.round(barFill, 15)
local warningBar = UI.new("Frame", {Name = "WarningBar", BackgroundColor3 = RED, BackgroundTransparency = 0.2, BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromScale(1, 0), Visible = false, ZIndex = 32}, alienBar)
UI.round(warningBar, 15)
local iconHolder = UI.new("Frame", {Name = "IconHolder", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0),
	Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, ZIndex = 33}, barHolder)
UI.new("ImageLabel", {Name = "Icon1", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = R.Icon, ImageColor3 = CYAN, ZIndex = 33}, iconHolder)
local barLabel = UI.text(barHolder, "", UDim2.new(1, 30, 0, 26), UDim2.new(0, -15, 1, -28), 18, C.White)
barLabel.Name = "EnergyText"; barLabel.TextXAlignment = Enum.TextXAlignment.Center; barLabel.TextWrapped = false; barLabel.ZIndex = 34
local function layoutBar()
	local camera = workspace.CurrentCamera
	if not camera then return end
	barScale.Scale = math.clamp(camera.ViewportSize.Y / 720, 0.55, 1.25)
	-- phones: higher up, clear of the Sprint and jump buttons at the bottom right
	barHolder.Position = UI.isTouch() and UDim2.new(1, -100, 0.27, 0) or UDim2.new(1, -100, 0.5, 0)
end
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutBar) end
layoutBar()
local lastEnergy, flashUntil, warnUntil = nil, 0, 0
local function energy() return player:GetAttribute("EnergyAmmo") or R.EnergyMax end
local function energyMax() return player:GetAttribute("EnergyMax") or R.EnergyMax end
local function overheated() return player:GetAttribute("EnergyOverheat") == true end
-- EnergyTooLowIndicator: the missing part of the next shot blinks red on the bar
local function tooLow()
	warnUntil = os.clock() + 0.6
end
local function updateBar()
	local e, m = energy(), energyMax()
	local now = os.clock()
	barFill.Size = UDim2.fromScale(1, math.clamp(e / m, 0, 1))
	if overheated() then
		local pulse = (math.sin(now * 10) + 1) / 2
		barFill.BackgroundColor3 = RED
		barFill.Size = UDim2.fromScale(1, 1)
		alienBar.BackgroundColor3 = Color3.fromRGB(35, 0, 1):Lerp(Color3.fromRGB(106, 27, 29), pulse)
		barFill.BackgroundTransparency = 0.2 + 0.5 * pulse
		barLabel.Text = "HOT!"; barLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
	else
		alienBar.BackgroundColor3 = NAVY
		barFill.BackgroundTransparency = 0
		barFill.BackgroundColor3 = now < flashUntil and GREEN or CYAN
		barLabel.Text = tostring(math.floor(e + 0.5)); barLabel.TextColor3 = C.White
	end
	if lastEnergy and e >= m and lastEnergy < m and not overheated() then flashUntil = now + 0.35 end -- EnergyRegainedEffect
	lastEnergy = e
	warningBar.Visible = now < warnUntil
	if warningBar.Visible then
		warningBar.Position = UDim2.fromScale(0, 1 - math.clamp(e / m, 0, 1))
		warningBar.Size = UDim2.fromScale(1, math.clamp((R.EnergyCost - e) / m, 0.02, 1))
		warningBar.BackgroundTransparency = 0.2 + 0.6 * ((math.sin(now * 20) + 1) / 2)
	end
end

-- ---------------------------------------------------------------- bolts
local boltTemplate = gear and gear:FindFirstChild("LaserBullet")
local PLAYER_GREEN = Color3.fromRGB(120, 255, 90)
local ENEMY_RED = Color3.fromRGB(255, 60, 70)
local function sound(id, position, volume, speed)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Transparency = 1; p.Size = Vector3.one
	p.Position = position; p.Parent = fxFolder
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = volume or 0.6; s.PlaybackSpeed = speed or 1; s.RollOffMaxDistance = 160; s.Parent = p
	s:Play()
	Debris:AddItem(p, 2)
end
local function burst(position, color, count)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Transparency = 1; p.Size = Vector3.one
	p.Position = position; p.Parent = fxFolder
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"; e.LightEmission = 1; e.Rate = 0
	e.Speed = NumberRange.new(8, 20); e.SpreadAngle = Vector2.new(180, 180); e.Lifetime = NumberRange.new(0.25, 0.6)
	e.Size = NumberSequence.new(0.9, 0); e.Color = ColorSequence.new(color); e.Parent = p
	e:Emit(count or 14)
	Debris:AddItem(p, 1.5)
end
-- a laser bolt flying from -> to, then a small flash where it lands
local function bolt(from, to, color, big)
	local distance = (to - from).Magnitude
	if distance < 0.5 then return end
	local model
	if boltTemplate then
		model = boltTemplate:Clone()
	else
		model = Instance.new("Model")
		local p = Instance.new("Part"); p.Size = Vector3.new(0.3, 0.3, 2.1); p.Material = Enum.Material.Neon; p.Parent = model
	end
	local part = model:FindFirstChildWhichIsA("BasePart", true)
	if not part then model:Destroy(); return end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.Color = color end
		if d:IsA("Trail") then d.Color = ColorSequence.new(color) end
	end
	if big then part.Size = part.Size * 1.8 end
	model.Parent = fxFolder
	local light = Instance.new("PointLight"); light.Color = color; light.Range = 8; light.Brightness = 2; light.Parent = part
	local direction = (to - from).Unit
	local travel = distance / R.BoltSpeed
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - started) / travel, 0, 1)
		part.CFrame = CFrame.lookAt(from + direction * distance * k, to)
		if k >= 1 then
			connection:Disconnect()
			burst(to, color, big and 22 or 10)
			model:Destroy()
		end
	end)
end

-- ---------------------------------------------------------------- aiming & firing
local mouse
pcall(function() mouse = player:GetMouse() end)
local aliensFolder = workspace:WaitForChild("PFE_Aliens", 10)
-- snap to an alien close to where the player aimed (so touch players can hit them too)
local function assist(origin, aim)
	if not aliensFolder then return aim end
	local direction = (aim - origin)
	if direction.Magnitude < 0.1 then return aim end
	local unit = direction.Unit
	local best, bestScore
	for _, alien in ipairs(aliensFolder:GetChildren()) do
		local torso = alien:FindFirstChild("Torso")
		local humanoid = alien:FindFirstChildOfClass("Humanoid")
		if torso and humanoid and humanoid.Health > 0 then
			local rel = torso.Position - origin
			local along = rel:Dot(unit)
			if along > 0 and along < R.Range then
				local miss = (rel - unit * along).Magnitude
				local nearAim = (torso.Position - aim).Magnitude
				local score = math.min(miss / math.max(4, along * 0.12), nearAim / 10)
				if score < 1 and (not bestScore or score < bestScore) then best, bestScore = torso.Position, score end
			end
		end
	end
	return best or aim
end
local lastFire, holding = 0, false
-- is the trigger really still held? (on phones the release can get lost in a camera swipe or a second
-- finger; the gun then kept firing on its own at wherever the last touch was)
local touchesOnWorld = {}
UserInputService.TouchStarted:Connect(function(touch, processed) if not processed then touchesOnWorld[touch] = true end end)
UserInputService.TouchEnded:Connect(function(touch) touchesOnWorld[touch] = nil end)
local function triggerHeld()
	local ok, mouseDown = pcall(function() return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end)
	if not ok then return true end
	if mouseDown or next(touchesOnWorld) ~= nil then return true end
	local okPad, pad = pcall(function() return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2) end)
	return okPad and pad == true
end
local function fireOnce()
	local character = player.Character
	local gun = character and character:FindFirstChild("Raygun")
	if not gun or handsFull() then return end
	local now = os.clock()
	if now - lastFire < R.Cooldown then return end
	-- 99 Nights' energy check (the server has the final word)
	if overheated() or energy() < R.EnergyCost then
		if not overheated() then tooLow() end
		return
	end
	lastFire = now
	local muzzle = gun:FindFirstChild("MuzzlePart") or gun:FindFirstChild("Muzzle") or gun:FindFirstChild("Handle")
	if not muzzle then return end
	local origin = muzzle.Position
	-- 99 Nights' muzzle flash: its two emitters burst on every shot
	for _, name in ipairs({"ParticleOuter", "ParticleInner"}) do
		local emitter = muzzle:FindFirstChild(name)
		if emitter and emitter:IsA("ParticleEmitter") then emitter:Emit(emitter:GetAttribute("EmitCount") or (name == "ParticleOuter" and 20 or 10)) end
	end
	local aim = (mouse and mouse.Hit and mouse.Hit.Position) or (origin + workspace.CurrentCamera.CFrame.LookVector * 60)
	aim = assist(origin, aim)
	local direction = aim - origin
	if direction.Magnitude > R.Range then aim = origin + direction.Unit * R.Range end
	bolt(origin, aim, PLAYER_GREEN)
	sound(Config.Sounds.Laser, origin, 0.5, 0.95 + math.random() * 0.12)
	api:WaitForChild("Raygun"):FireServer(aim)
end
local function hookTool(gun)
	if not gun:IsA("Tool") or gun.Name ~= "Raygun" or gun:GetAttribute("PFEHooked") then return end
	gun:SetAttribute("PFEHooked", true)
	gun.Activated:Connect(function()
		holding = true
		fireOnce()
	end)
	gun.Deactivated:Connect(function() holding = false end)
	gun.Unequipped:Connect(function() holding = false end)
end
local function watchContainer(container)
	if not container then return end
	for _, child in ipairs(container:GetChildren()) do hookTool(child) end
	container.ChildAdded:Connect(hookTool)
end
watchContainer(player:WaitForChild("Backpack", 10))
player.CharacterAdded:Connect(function(character)
	watchContainer(character)
	task.defer(function() watchContainer(player:FindFirstChildOfClass("Backpack")) end)
end)
if player.Character then watchContainer(player.Character) end

RunService.RenderStepped:Connect(function()
	if holding and os.clock() - lastFire > 0.3 and not triggerHeld() then holding = false end
	if holding then fireOnce() end
	local out = equipped()
	-- ShowEnergyBar / HideEnergyBar: the energy bar sits over the raygun tile while the gun is out
	barHolder.Visible = out and holder.Visible
	if barHolder.Visible then updateBar() end
	if out and handsFull() then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:UnequipTools() end
		out = false
	end
	handsShade.Visible = handsFull()
	holder.Visible = player:GetAttribute("PFEFlightActive") ~= true and player:GetAttribute("PFEMenuOpen") ~= true
		and player:GetAttribute("PFEPlanetMapOpen") ~= true
	-- one slot left of the bat, which sits just left of the egg slots
	local inventory = player.PlayerGui:FindFirstChild("EggInventory")
	local backpack = inventory and inventory:FindFirstChild("Backpack")
	local hotbar = backpack and backpack:FindFirstChild("Hotbar")
	local bag = backpack and backpack:FindFirstChild("OpenInventory")
	if hotbar and bag and hotbar.Size.Y.Offset > 8 then
		local slot = hotbar.Size.Y.Offset - 8
		local s = math.clamp(slot / 78, 0.5, 1.3)
		local half = math.max(0, bag.Position.X.Offset - 7)
		holder.Position = UDim2.new(0.5, -half - 6 - 78 * s - 6, 1, hotbar.Position.Y.Offset + hotbar.Size.Y.Offset - 4)
		scale.Scale = s
	else
		holder.Position = UDim2.new(0.5, -320, 1, -8 - UI.bottomMargin())
		local camera = workspace.CurrentCamera
		if camera then scale.Scale = math.clamp(UI.scaleFor(camera.ViewportSize), UI.minScale(), 1.1) end
	end
end)

-- ---------------------------------------------------------------- what the server says happened
api:WaitForChild("Effect").OnClientEvent:Connect(function(kind, payload)
	if type(payload) ~= "table" then return end
	if kind == "RaygunShot" and typeof(payload.From) == "Vector3" and typeof(payload.To) == "Vector3" then
		bolt(payload.From, payload.To, PLAYER_GREEN)
		sound(Config.Sounds.Laser, payload.From, 0.35, 1 + math.random() * 0.1)
		if payload.Hit then sound(Config.Sounds.LaserHit, payload.To, 0.45, 1) end
	elseif kind == "AlienShot" and typeof(payload.From) == "Vector3" and typeof(payload.To) == "Vector3" then
		-- the aliens' bolts are red (never the players' green): a stray one can't pass for your own shot
		bolt(payload.From, payload.To, ENEMY_RED, payload.Big)
		sound(Config.Sounds.Laser, payload.From, 0.45, payload.Big and 0.6 or 0.75)
	elseif kind == "AlienDied" and typeof(payload.Position) == "Vector3" then
		burst(payload.Position, typeof(payload.Color) == "Color3" and payload.Color or PLAYER_GREEN, 40)
		sound(Config.Sounds.AlienDeath, payload.Position, 0.7, 0.9 + math.random() * 0.2)
	elseif kind == "AlienAlert" and typeof(payload.Alien) == "Instance" then
		local head = payload.Alien:FindFirstChild("Head")
		if not head then return end
		local bubble = Instance.new("BillboardGui")
		bubble.Name = "AlienAlert"; bubble.Adornee = head; bubble.Size = UDim2.fromOffset(40, 50); bubble.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
		bubble.AlwaysOnTop = true; bubble.MaxDistance = 120; bubble.Parent = fxFolder
		local text = Instance.new("TextLabel"); text.BackgroundTransparency = 1; text.Size = UDim2.fromScale(1, 1); text.Text = "!"
		text.Font = Enum.Font.FredokaOne; text.TextScaled = true; text.TextColor3 = Color3.fromRGB(255, 70, 70); text.Parent = bubble
		local stroke = Instance.new("UIStroke"); stroke.Thickness = 3; stroke.Color = Color3.fromRGB(20, 10, 20); stroke.Parent = text
		local pop = Instance.new("UIScale"); pop.Scale = 0.2; pop.Parent = text
		sound(Config.Sounds.AlienAlert, head.Position, 0.35, 1.1)
		TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Scale = 1}):Play()
		Debris:AddItem(bubble, 1.4)
	elseif kind == "AlienHit" then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		-- a red flash on screen, and a shove for the big hitters
		local flash = UI.new("Frame", {Name = "AlienHitFlash", BackgroundColor3 = Color3.fromRGB(255, 40, 40), BackgroundTransparency = 0.6,
			Size = UDim2.fromScale(1, 1), ZIndex = 50}, gui)
		UI.tween(flash, {BackgroundTransparency = 1}, 0.35)
		Debris:AddItem(flash, 0.4)
		local force = tonumber(payload.Force) or 0
		if force > 0 and typeof(payload.From) == "Vector3" then
			local away = root.Position - payload.From
			away = Vector3.new(away.X, 0, away.Z)
			away = away.Magnitude > 0.01 and away.Unit or Vector3.new(0, 0, 1)
			root.AssemblyLinearVelocity = away * force * 1.6 + Vector3.new(0, force * 0.6, 0)
		end
	end
end)
