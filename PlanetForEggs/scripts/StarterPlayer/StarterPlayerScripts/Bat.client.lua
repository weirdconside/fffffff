--!nocheck
-- The Steal an Egg bat. The EquipBat button (Q / gamepad X) takes it out or puts it away; with the
-- bat out the closest player in reach is outlined red (like the source) and clicking swings at them.
-- The server checks the hit; the target's own client plays the knockback (their character is
-- theirs to move), and a thief who gets hit drops the stolen egg.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local UI = require(api:WaitForChild("UIKit"))
local C = UI.C
local player = Players.LocalPlayer
local BAT_ICON = "rbxassetid://131099804712161"
local reach = Config.Bat.Range + Config.Bat.Tolerance

local gui = UI.new("ScreenGui", {Name = "PFE_Bat", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 21}, player:WaitForChild("PlayerGui"))
local holder = UI.new("Frame", {Name = "EquipBat", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -230, 1, -8), Size = UDim2.fromOffset(78, 78),
	BackgroundTransparency = 1}, gui)
local scale = UI.new("UIScale", {}, holder)
local button = UI.tile(holder, BAT_ICON, "Bat", Color3.fromRGB(255, 150, 60), UDim2.fromOffset(78, 78), nil, "EquipBat")
-- darkened while both hands hold an egg
local handsShade = UI.new("Frame", {Name = "HandsFull", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
	Size = UDim2.fromScale(1, 1), ZIndex = 12, Visible = false}, button)
UI.round(handsShade, 18)
local keyHint = UI.text(holder, "2", UDim2.fromOffset(20, 20), UDim2.fromOffset(6, 3), 16, C.White)
keyHint.TextXAlignment = Enum.TextXAlignment.Center; keyHint.ZIndex = 20 -- over the tile, like the hotbar slot numbers
keyHint.Visible = not UI.isTouch()

local function tool()
	local character = player.Character
	return (character and character:FindFirstChild("Bat")) or player:FindFirstChildOfClass("Backpack") and player.Backpack:FindFirstChild("Bat")
end
local function equipped()
	local character = player.Character
	return character ~= nil and character:FindFirstChild("Bat") ~= nil
end
-- both hands are busy with an egg (carried from a planet, stolen, or held from the hotbar)
local function handsFull()
	return player:GetAttribute("PFECarrying") == true or player:GetAttribute("PFEHoldingStoredEgg") == true
end
local function toggle()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local bat = tool()
	if not humanoid or not bat then return end
	if handsFull() and not equipped() then return end
	if equipped() then humanoid:UnequipTools() else humanoid:EquipTool(bat) end
end
button.Activated:Connect(toggle)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or player:GetAttribute("PFEPlanetMapOpen") then return end
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonX then toggle() end
end)

-- the closest other player in reach, outlined red while the bat is out
local highlight = Instance.new("Highlight")
highlight.Name = "BatTargetHighlight"; highlight.FillColor = Color3.fromRGB(255, 0, 0); highlight.OutlineColor = Color3.fromRGB(107, 0, 0)
highlight.FillTransparency = 0.5; highlight.OutlineTransparency = 0.15; highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.Enabled = false; highlight.Parent = gui
local target
local function closest()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local best, bestDistance = nil, reach
	for _, other in ipairs(Players:GetPlayers()) do
		local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		local humanoid = otherRoot and other.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			local d = (otherRoot.Position - root.Position).Magnitude
			if d < bestDistance then best, bestDistance = other, d end
		end
	end
	-- (v30) the bot explorers can be batted too
	local botFolder = workspace:FindFirstChild("PFE_Bots")
	for _, bot in ipairs(botFolder and botFolder:GetChildren() or {}) do
		local botRoot = bot:FindFirstChild("HumanoidRootPart")
		local id = bot:GetAttribute("BotId")
		if botRoot and id then
			local d = (botRoot.Position - root.Position).Magnitude
			if d < bestDistance then best, bestDistance = {UserId = -id, Character = bot}, d end
		end
	end
	-- (v41) and everything that can be smashed: crystals, rocks, ice blocks, volcanic bombs, cave walls, chests, the bosses
	for _, model in ipairs(CollectionService:GetTagged("PFESmashable")) do
		local core = model.Parent and (model:FindFirstChild("Hitbox") or model.PrimaryPart or model:FindFirstChild("Core"))
		if core and model:IsDescendantOf(workspace) and not model:GetAttribute("Dead") and not model:GetAttribute("Under") then
			local size = math.max(core.Size.X, core.Size.Z) * 0.5
			local d = math.max(0, (core.Position - root.Position).Magnitude - size)
			if d < bestDistance then best, bestDistance = {Smash = model, Character = model}, d end
		end
	end
	return best
end
RunService.RenderStepped:Connect(function()
	local out = equipped()
	if out and handsFull() then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:UnequipTools() end
		out = false
	end
	button.BackgroundColor3 = out and Color3.fromRGB(255, 90, 60) or C.White
	handsShade.Visible = handsFull()
	holder.Visible = player:GetAttribute("PFEFlightActive") ~= true and player:GetAttribute("PFEMenuOpen") ~= true
		and player:GetAttribute("PFEPlanetMapOpen") ~= true
	-- sits just left of the egg slots like one more slot (Steal an Egg keeps its bat in the hotbar);
	-- mirrors Inventory's layout: the slots are centred and its bag button sits right after them
	local inventory = player.PlayerGui:FindFirstChild("EggInventory")
	local backpack = inventory and inventory:FindFirstChild("Backpack")
	local hotbar = backpack and backpack:FindFirstChild("Hotbar")
	local bag = backpack and backpack:FindFirstChild("OpenInventory")
	if hotbar and bag and hotbar.Size.Y.Offset > 8 then
		local slot = hotbar.Size.Y.Offset - 8
		local half = math.max(0, bag.Position.X.Offset - 7)
		holder.Position = UDim2.new(0.5, -half - 6, 1, hotbar.Position.Y.Offset + hotbar.Size.Y.Offset - 4)
		scale.Scale = math.clamp(slot / 78, 0.5, 1.3)
	else
		holder.Position = UDim2.new(0.5, -230, 1, -8 - UI.bottomMargin())
		local camera = workspace.CurrentCamera
		if camera then scale.Scale = math.clamp(UI.scaleFor(camera.ViewportSize), UI.minScale(), 1.1) end
	end
	target = out and closest() or nil
	highlight.Adornee = target and target.Character or nil
	highlight.Enabled = target ~= nil
	-- (v41) things to smash light up gold, people red
	local thing = target ~= nil and target.Smash ~= nil
	highlight.FillColor = thing and Color3.fromRGB(255, 210, 60) or Color3.fromRGB(255, 0, 0)
	highlight.OutlineColor = thing and Color3.fromRGB(255, 255, 200) or Color3.fromRGB(107, 0, 0)
end)

-- swings (the default Animate script plays its slash for a "toolanim" value)
local lastSwing = 0
local function hookTool(bat)
	if not bat:IsA("Tool") or bat.Name ~= "Bat" or bat:GetAttribute("PFEHooked") then return end
	bat:SetAttribute("PFEHooked", true)
	bat.Activated:Connect(function()
		local now = os.clock()
		if now - lastSwing < Config.Bat.Cooldown then return end
		lastSwing = now
		local anim = Instance.new("StringValue"); anim.Name = "toolanim"; anim.Value = "Slash"; anim.Parent = bat
		task.delay(0.3, function() anim:Destroy() end)
		local handle = bat:FindFirstChild("Handle")
		local slash = handle and handle:FindFirstChild("Slash")
		if slash then slash:Play() end
		-- the swing's whoosh (Config.Sounds.BatSwing)
		if handle then
			local whoosh = Instance.new("Sound"); whoosh.SoundId = Config.Sounds.BatSwing; whoosh.Volume = 0.55
			whoosh.PlaybackSpeed = 0.95 + math.random() * 0.15; whoosh.Parent = handle; whoosh:Play()
			game:GetService("Debris"):AddItem(whoosh, 2)
		end
		if target and target.Smash then api:WaitForChild("Smash"):FireServer(target.Smash)
		elseif target then api:WaitForChild("Bat"):FireServer(target.UserId) end
	end)
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

-- getting hit: knocked back and briefly off your feet; everyone near hears the whack
api:WaitForChild("Effect").OnClientEvent:Connect(function(kind, payload)
	if type(payload) ~= "table" then return end
	if kind == "Knockback" and typeof(payload.From) == "Vector3" then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid then return end
		local away = root.Position - payload.From
		away = Vector3.new(away.X, 0, away.Z)
		away = away.Magnitude > 0.01 and away.Unit or Vector3.new(0, 0, 1)
		local force = tonumber(payload.Force) or 35
		humanoid.PlatformStand = true
		root.AssemblyLinearVelocity = away * force * 2 + Vector3.new(0, force * 1.1, 0)
		root.AssemblyAngularVelocity = Vector3.new(away.Z, 0, -away.X) * 8
		task.delay((tonumber(payload.Duration) or 0.5) + 0.45, function()
			if humanoid.Parent then
				humanoid.PlatformStand = false
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	elseif kind == "BatHit" and typeof(payload.Position) == "Vector3" then
		local part = Instance.new("Part")
		part.Anchored = true; part.CanCollide = false; part.CanQuery = false; part.Transparency = 1; part.Position = payload.Position
		part.Parent = workspace
		local s = Instance.new("Sound"); s.SoundId = Config.Sounds.BatHit; s.Volume = 0.9; s.Parent = part; s:Play()
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"; sparks.LightEmission = 1; sparks.Speed = NumberRange.new(12, 22)
		sparks.SpreadAngle = Vector2.new(180, 180); sparks.Lifetime = NumberRange.new(0.3, 0.6); sparks.Size = NumberSequence.new(1, 0)
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120)); sparks.Enabled = false; sparks.Parent = part
		sparks:Emit(18)
		game:GetService("Debris"):AddItem(part, 2)
	end
end)
