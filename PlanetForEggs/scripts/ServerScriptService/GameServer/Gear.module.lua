--!nocheck
-- Player gear.
--  Jetpack: every character wears one, tinted by its level. The owner's client flies it (charge,
--  recharge and thrust come from Config.Jetpacks) and reports thrust on/off, so everyone sees the
--  flames. Better packs are bought with coins like the suit.
--  Bat (from Steal an Egg): every player carries one. A hit flings the target (the target's own
--  client applies the knockback) and takes the egg out of their hands (Egg Arena rules).
--  Raygun (99 Nights' first, endless alien gun, its own model): every player carries one; the Tool is
--  assembled here from the 99 Nights model (its Main part is the handle, held by its RightGripAttachment).
local Players = game:GetService("Players")
local Gear = {}
local ctx, Config
local lastHit, lastJet = {}, {}

local function gearFolder()
	return ctx.network:FindFirstChild("Gear")
end

function Gear.Tint(model, level)
	local pack = Config.Jetpacks[level] or Config.Jetpacks[1]
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local role = part:GetAttribute("Role")
			if role and pack[role] then part.Color = pack[role] end
		end
	end
end

-- (v30) the same pack on a bot's body
function Gear.AttachJetpackTo(character, level)
	return Gear.AttachJetpack({Player = {Character = character}, Data = {JetpackLevel = level or 1}})
end

function Gear.AttachJetpack(profile)
	local character = profile.Player.Character
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
	local folder = gearFolder()
	local template = folder and folder:FindFirstChild("Jetpack")
	if not torso or not template then return end
	local old = character:FindFirstChild("PFEJetpack")
	if old then old:Destroy() end
	local pack = template:Clone()
	pack.Name = "PFEJetpack"
	Gear.Tint(pack, profile.Data.JetpackLevel)
	local fit = torso.Size.X / 2
	if math.abs(fit - 1) > 0.02 then pcall(function() pack:ScaleTo(pack:GetScale() * fit) end) end
	-- the pack's pivot is the centre of the back it sits on
	pack:PivotTo(torso.CFrame * CFrame.new(0, 0.05 * fit, 0))
	for _, part in ipairs(pack:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false; part.CanCollide = false; part.CanTouch = false; part.CanQuery = false; part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = torso; weld.Part1 = part; weld.Parent = part
		end
	end
	pack.Parent = character
	character:SetAttribute("PFEJetLevel", profile.Data.JetpackLevel)
	character:SetAttribute("PFEJetting", false)
end

local function giveBat(profile)
	local player = profile.Player
	local folder = gearFolder()
	local template = folder and folder:FindFirstChild("Bat")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not template or not backpack then return end
	if backpack:FindFirstChild("Bat") or (player.Character and player.Character:FindFirstChild("Bat")) then return end
	template:Clone().Parent = backpack
end

local raygunTemplate
-- the grip, from the gun's own shape: barrel forward (body -> muzzle), handle down. (99 Nights'
-- RightGripAttachment is turned for their R15 hand; on an R6 arm it points the barrel at the ground.)
local function gripFor(handle, model, fallback)
	local muzzle = model:FindFirstChild("MuzzlePart") or model:FindFirstChild("Muzzle")
	local body = model:FindFirstChild("Body1") or model:FindFirstChild("Barrel")
	local gripPart = model:FindFirstChild("Grip") or model:FindFirstChild("GripMain")
	if not (muzzle and body and gripPart) then return fallback end
	local forward = handle.CFrame:VectorToObjectSpace(muzzle.Position - body.Position)
	local down = handle.CFrame:VectorToObjectSpace(gripPart.Position - body.Position)
	if forward.Magnitude < 0.05 then return fallback end
	forward = forward.Unit
	local up = -(down - forward * down:Dot(forward))
	if up.Magnitude < 0.05 then return fallback end
	up = up.Unit
	local at = fallback and fallback.Position or handle.CFrame:PointToObjectSpace(gripPart.Position)
	return CFrame.fromMatrix(at, forward:Cross(up), up, -forward)
end

local function makeRaygun()
	if raygunTemplate then return raygunTemplate:Clone() end
	local folder = gearFolder()
	local source = folder and folder:FindFirstChild("RaygunModel")
	if not source then return nil end
	local tool = Instance.new("Tool")
	tool.Name = "Raygun"; tool.CanBeDropped = false; tool.RequiresHandle = true; tool.ToolTip = "Raygun"
	tool.TextureId = Config.Raygun.Icon
	local model = source:Clone()
	-- the 99 Nights stats ride along as attributes (AmmoType, EnergyCost, FireRate, ProjectileDamage...)
	for key, value in pairs(model:GetAttributes()) do tool:SetAttribute(key, value) end
	local handle = model:FindFirstChild("Handle") or model:FindFirstChild("Main")
	if not handle then model:Destroy(); return nil end
	handle.Name = "Handle"
	local grip = handle:FindFirstChild("RightGripAttachment")
	tool.Grip = gripFor(handle, model, grip and grip.CFrame or CFrame.new(0, -0.15, 0))
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			part.Anchored = false; part.CanCollide = false; part.CanTouch = false; part.CanQuery = false; part.Massless = true
			if part ~= handle then
				-- keep the model's own welds; add one to the handle as well so nothing hangs loose
				local weld = Instance.new("WeldConstraint"); weld.Name = "ToHandle"; weld.Part0 = handle; weld.Part1 = part; weld.Parent = part
			end
			part.Parent = tool
		end
	end
	model:Destroy()
	raygunTemplate = tool
	return tool:Clone()
end
Gear.MakeRaygun = makeRaygun   -- (v35) the bots carry one too

local function giveRaygun(profile)
	local player = profile.Player
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or backpack:FindFirstChild("Raygun") or (player.Character and player.Character:FindFirstChild("Raygun")) then return end
	local tool = makeRaygun()
	if tool then tool.Parent = backpack end
end

-- (v41) the flashlight everybody carries (the caves are pitch dark): a torch built from parts, its beam a shadow-casting
-- SpotLight in the lens. Built along the handle's -Z (lens forward) with the grip under it, so its Grip is like the
-- raygun's computed one: barrel forward, handle down.
local flashlightTemplate
local function makeFlashlight()
	if flashlightTemplate then return flashlightTemplate:Clone() end
	local tool = Instance.new("Tool")
	tool.Name = "Flashlight"; tool.CanBeDropped = false; tool.RequiresHandle = true; tool.ToolTip = "Flashlight"
	tool.TextureId = "rbxassetid://119275771957836"
	local function piece(name, size, offset, color, material, shape)
		local p = Instance.new("Part")
		p.Name = name; p.Size = size; p.Color = color; p.Material = material or Enum.Material.SmoothPlastic
		if shape then p.Shape = shape end
		p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.Massless = true; p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = CFrame.new(offset)
		p.Parent = tool
		return p
	end
	local handle = piece("Handle", Vector3.new(0.62, 0.62, 2.1), Vector3.zero, Color3.fromRGB(40, 44, 56), Enum.Material.Metal)
	local head = piece("Head", Vector3.new(0.95, 0.95, 0.55), Vector3.new(0, 0, -1.25), Color3.fromRGB(60, 64, 80), Enum.Material.Metal)
	local lens = piece("Lens", Vector3.new(0.78, 0.78, 0.12), Vector3.new(0, 0, -1.56), Color3.fromRGB(255, 246, 200), Enum.Material.Neon)
	local band = piece("Band", Vector3.new(0.68, 0.68, 0.18), Vector3.new(0, 0, 0.55), Color3.fromRGB(255, 200, 40), Enum.Material.SmoothPlastic)
	local grip = piece("Grip", Vector3.new(0.42, 0.75, 0.55), Vector3.new(0, -0.62, 0.35), Color3.fromRGB(26, 26, 30), Enum.Material.Fabric)
	for _, p in ipairs({head, lens, band, grip}) do
		local weld = Instance.new("WeldConstraint"); weld.Part0 = handle; weld.Part1 = p; weld.Parent = p
	end
	local beam = Instance.new("SpotLight")
	beam.Name = "Beam"; beam.Face = Enum.NormalId.Front; beam.Angle = 62; beam.Range = 60; beam.Brightness = 3.2
	beam.Color = Color3.fromRGB(255, 244, 214); beam.Shadows = true; beam.Parent = lens
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"; glow.Range = 7; glow.Brightness = 0.6; glow.Color = Color3.fromRGB(255, 240, 200); glow.Shadows = false; glow.Parent = lens
	tool.Grip = CFrame.new(0, -0.62, 0.35)
	flashlightTemplate = tool
	return tool:Clone()
end
local function giveFlashlight(profile)
	local player = profile.Player
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or backpack:FindFirstChild("Flashlight") or (player.Character and player.Character:FindFirstChild("Flashlight")) then return end
	makeFlashlight().Parent = backpack
end

function Gear.OnCharacter(profile)
	Gear.AttachJetpack(profile)
	giveBat(profile)
	giveRaygun(profile)
	giveFlashlight(profile)
end

-- a bat swing from `attacker` at the player with `targetUserId`
local function batHit(attacker, targetUserId)
	-- (v30) bots have negative ids: Bots.Hit knocks them back
	if type(targetUserId) == "number" and targetUserId < 0 and ctx.Bots and ctx.Bots.Hit then
		local me = ctx.profiles[attacker]
		local now = os.clock()
		if not me or me.Busy or now - (lastHit[attacker] or 0) < Config.Bat.Cooldown then return end
		if not attacker.Character or not attacker.Character:FindFirstChild("Bat") then return end
		if ctx.Bots.Hit(attacker, -targetUserId) then lastHit[attacker] = now end
		return
	end
	local profile = ctx.profiles[attacker]
	local target = type(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId)
	local targetProfile = target and ctx.profiles[target]
	if not profile or not targetProfile or target == attacker or profile.Busy or targetProfile.Busy then return end
	-- hands full: no swinging while carrying an egg
	if profile.Stolen or (profile.Expedition and profile.Expedition.CarryingEgg) then return end
	if profile.Planet ~= targetProfile.Planet then return end
	local now = os.clock()
	if now - (lastHit[attacker] or 0) < Config.Bat.Cooldown then return end
	local character = attacker.Character
	if not character or not character:FindFirstChild("Bat") then return end
	local from, to = ctx.root(attacker), ctx.root(target)
	local humanoid = ctx.humanoid(target)
	if not from or not to or not humanoid or humanoid.Health <= 0 then return end
	if (from.Position - to.Position).Magnitude > Config.Bat.Range + Config.Bat.Tolerance then return end
	lastHit[attacker] = now
	ctx.effect(target, "Knockback", {From = from.Position, Force = Config.Bat.Force, Duration = Config.Bat.Duration})
	for _, player in ipairs(Players:GetPlayers()) do
		local root = ctx.root(player)
		if root and (root.Position - to.Position).Magnitude < 120 then ctx.effect(player, "BatHit", {Position = to.Position}) end
	end
	-- Egg Arena rules: the egg in the target's hands goes to whoever hit them (and on, round and round)
	if targetProfile.Stolen then
		ctx.Bases.TransferSteal(targetProfile, profile)
	elseif targetProfile.Expedition and targetProfile.Expedition.CarryingEgg then
		ctx.Expeditions.TakeCarry(targetProfile, profile)
	end
end

-- is the pack on this character, welded to its current torso?
local function packOk(character)
	local pack = character and character:FindFirstChild("PFEJetpack")
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
	if not pack or not torso then return false end
	for _, weld in ipairs(pack:GetDescendants()) do
		if weld:IsA("WeldConstraint") then return weld.Part0 == torso and weld.Part0.Parent == character end
	end
	return false
end

function Gear.Init(context)
	ctx = context
	Config = ctx.Config
	ctx.Gear = Gear
	-- a watchdog: every character keeps its jetpack (and its appearance finishing loads re-fits it)
	task.spawn(function()
		while true do
			task.wait(2)
			for _, profile in pairs(ctx.profiles) do
				local character = profile.Player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 and not packOk(character) then pcall(Gear.AttachJetpack, profile) end
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		pcall(function()
			player.CharacterAppearanceLoaded:Connect(function()
				local profile = ctx.profiles[player]
				if profile then task.defer(Gear.AttachJetpack, profile) end
			end)
		end)
	end)
	-- (v35) the flames follow the LAST thing the pack's owner said. Before, a message within 0.05 s of the previous one
	-- was thrown away - so a short burst ("on", then "off" a frame later) left the flames burning under someone
	-- standing or walking about. Now a message that comes too soon is held and applied once the gap is over.
	local pendingJet = {}
	local function applyJet(player, on)
		local character = player.Character
		if character and character:GetAttribute("PFEJetting") ~= on then character:SetAttribute("PFEJetting", on) end
	end
	ctx.remotes.Jet.OnServerEvent:Connect(function(player, on)
		if type(on) ~= "boolean" then return end
		local now = os.clock()
		local wait = 0.05 - (now - (lastJet[player] or 0))
		if wait <= 0 then
			lastJet[player] = now
			pendingJet[player] = nil
			applyJet(player, on)
			return
		end
		local first = pendingJet[player] == nil
		pendingJet[player] = on
		if first then
			task.delay(wait, function()
				local value = pendingJet[player]
				pendingJet[player] = nil
				if value == nil or not player.Parent then return end
				lastJet[player] = os.clock()
				applyJet(player, value)
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player) pendingJet[player] = nil end)
	ctx.remotes.Bat.OnServerEvent:Connect(function(player, targetUserId)
		local ok, err = pcall(batHit, player, targetUserId)
		if not ok then warn("[PFE] bat hit failed", err) end
	end)
	Players.PlayerRemoving:Connect(function(player) lastHit[player] = nil; lastJet[player] = nil end)
end

return Gear
