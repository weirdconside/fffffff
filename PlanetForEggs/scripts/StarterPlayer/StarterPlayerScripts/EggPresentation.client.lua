--!nocheck
-- Hatch show: the egg shakes three times (harder each time), glows, bursts into a
-- poof with rarity-coloured sparks and the pet pops out with an elastic bounce.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local EggForge = require(api:WaitForChild("EggForge"))
local ModelUtil = require(api:WaitForChild("ModelUtil"))
local PetModels = require(api:WaitForChild("PetModels"))
local library = api:WaitForChild("UIAssets")
local world = workspace:WaitForChild("PlanetForEggs")
local active = {}
local function sfx(id, volume, speed, parent)
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = volume; s.PlaybackSpeed = speed or 1; s.Parent = parent or SoundService
	s:Play(); Debris:AddItem(s, 4)
end

local function step(duration, callback)
	local started = os.clock()
	repeat
		local elapsed = math.min(os.clock() - started, duration)
		callback(elapsed / duration, elapsed)
		if elapsed >= duration then break end
		RunService.RenderStepped:Wait()
	until false
end
local function findPet(id)
	for _, base in ipairs(world.Bases:GetChildren()) do
		local pets = base:FindFirstChild("ActivePets")
		if pets then for _, pet in ipairs(pets:GetChildren()) do if pet:GetAttribute("PetId") == id then return pet end end end
	end
	return nil
end
local function burst(point, color)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Transparency = 1; p.Size = Vector3.one
	p.CFrame = CFrame.new(point + Vector3.new(0, 2, 0)); p.Parent = workspace
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"; sparks.Color = ColorSequence.new(color)
	sparks.LightEmission = 1; sparks.LightInfluence = 0; sparks.Speed = NumberRange.new(12, 24); sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Lifetime = NumberRange.new(0.6, 1.2); sparks.Size = NumberSequence.new(1, 0); sparks.Drag = 4; sparks.Enabled = false; sparks.Parent = p
	sparks:Emit(40)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"; smoke.Color = ColorSequence.new(Color3.new(1, 1, 1))
	smoke.Speed = NumberRange.new(4, 9); smoke.SpreadAngle = Vector2.new(180, 180); smoke.Lifetime = NumberRange.new(0.5, 0.9)
	smoke.Size = NumberSequence.new(2, 6); smoke.Transparency = NumberSequence.new(0.3, 1); smoke.Enabled = false; smoke.Parent = p
	smoke:Emit(18)
	local poof = library:FindFirstChild("HatchPoof")
	if poof then
		local effect = poof:Clone(); effect.CFrame = p.CFrame; effect.Anchored = true; effect.Transparency = 1; effect.CanCollide = false; effect.Parent = workspace
		for _, d in ipairs(effect:GetDescendants()) do if d:IsA("ParticleEmitter") then d.Enabled = false; d:Emit(d:GetAttribute("EmitCount") or 24) end end
		Debris:AddItem(effect, 4)
	end
	sfx(Config.Sfx.EggOpen, 1.2, 1, p)
	Debris:AddItem(p, 3)
end

api:WaitForChild("EggHatched").OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or active[payload.PetId] or typeof(payload.Position) ~= "Vector3" then return end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - payload.Position).Magnitude > 160 then return end
	local eggTemplate = EggForge.Template(payload.EggId)
	-- (v28: a Chimera is stitched out of its three pets)
	local record = payload.Species == "Chimera" and {Species = "Chimera", Parts = payload.Parts, Name = payload.Name} or payload.Species
	local petTemplate = PetModels.Template(record)
	if not eggTemplate or not petTemplate then return end
	local pet = Config.PetInfo(record)
	local rarityColor = pet and Config.Rarities[pet.Rarity] and Config.Rarities[pet.Rarity].Color or Color3.new(1, 1, 1)
	active[payload.PetId] = true
	task.spawn(function()
		local egg, reveal, hidden, watch
		local hiddenParts = {}
		local function hidePet()
			local replacement = findPet(payload.PetId)
			if replacement and replacement ~= hidden then hidden = replacement end
			if hidden and hidden.Parent and not hidden:GetAttribute("PFEHatching") then
				hidden:SetAttribute("PFEHatching", true)
				for _, p in ipairs(hidden:GetDescendants()) do
					if p:IsA("BasePart") then hiddenParts[p] = p.LocalTransparencyModifier; p.LocalTransparencyModifier = 1
					elseif p:IsA("BillboardGui") then p.Enabled = false end
				end
			end
		end
		local ok, err = xpcall(function()
			hidePet(); watch = RunService.RenderStepped:Connect(hidePet)
			egg = eggTemplate:Clone(); egg.Name = "OpeningEgg"
			ModelUtil.PrepareVisual(egg, true)
			local _, nativeSize = ModelUtil.VisibleBounds(egg)
			local eggInfo = Config.Eggs[payload.EggId]
			local _, grown = Config.EggGrowthScales(ModelUtil.GetScale(egg), payload.Scale, math.max(nativeSize.X, nativeSize.Y, nativeSize.Z), eggInfo and eggInfo.Rarity)
			ModelUtil.SetScale(egg, grown)
			ModelUtil.ApplyMutation(egg, payload.Mutation)
			egg.Parent = workspace
			ModelUtil.PlaceOnGround(egg, payload.Position, 0)
			ModelUtil.AttachEggFX(egg, eggInfo and eggInfo.Rarity, payload.Scale)
			local base = egg:GetPivot()
			local center = ModelUtil.VisibleBounds(egg)
			local offset = base:ToObjectSpace(center)
			local glow = Instance.new("PointLight"); glow.Color = rarityColor; glow.Range = 0; glow.Brightness = 3
			glow.Parent = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart", true)
			for pass, amplitude in ipairs({7, 11, 16}) do
				sfx(Config.Sfx.Tick, 2, 0.9 + pass * 0.12)
				step(0.45, function(t, elapsed)
					local shake = (1 - t) * math.sin(elapsed * 90) * math.rad(amplitude)
					egg:PivotTo(base * offset * CFrame.Angles(0, 0, shake) * offset:Inverse())
					glow.Range = pass * 4 + t * 4
				end)
				if pass < 3 then task.wait(0.25) end
			end
			burst(payload.Position, rarityColor)
			egg:Destroy(); egg = nil
			reveal = petTemplate:Clone(); reveal.Name = "HatchedPetReveal"
			ModelUtil.PrepareVisual(reveal, true)
			-- straight away the size it has in the pen (its rarity's size times its size roll)
			local _, native = ModelUtil.VisibleBounds(reveal)
			local largest = math.max(native.X, native.Y, native.Z, 0.1)
			local scale = reveal:GetScale() * Config.BasePetTarget(pet and pet.Rarity, payload.Scale, payload.Species) / largest
			ModelUtil.ApplyMutation(reveal, payload.Mutation)
			-- rigs pivot at their root part, well above the feet: lift by pivot-to-sole so the
			-- pet stands on the ground instead of half inside it (scales with the pop-in)
			reveal:ScaleTo(scale)
			local soleBounds, soleSize = ModelUtil.VisibleBounds(reveal)
			local lift = reveal:GetPivot().Position.Y - (soleBounds.Position.Y - soleSize.Y / 2)
			reveal.Parent = workspace
			sfx(Config.Sfx.Reward, 0.7, 1)
			local origin = CFrame.new(payload.Position)
			step(1.2, function(t)
				local eased = TweenService:GetValue(t, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
				local s = math.max(0.01, scale * (0.4 + 0.6 * eased))
				reveal:ScaleTo(s)
				reveal:PivotTo((origin + Vector3.new(0, lift * s / scale, 0)) * CFrame.Angles(0, t * math.pi * 2, 0))
			end)
			local owner = Players:GetPlayerByUserId(payload.OwnerUserId)
			local ownerBody = owner and owner.Character
			if not owner and (tonumber(payload.OwnerUserId) or 0) < 0 then
				-- (v35) a bot's pet looks at the bot that hatched it
				local bots = workspace:FindFirstChild("PFE_Bots")
				for _, model in ipairs(bots and bots:GetChildren() or {}) do if model:GetAttribute("BotId") == -payload.OwnerUserId then ownerBody = model end end
			end
			step(1.6, function(t)
				local ownerRoot = ownerBody and ownerBody.Parent and ownerBody:FindFirstChild("HumanoidRootPart")
				local cf = origin
				if ownerRoot then
					local target = Vector3.new(ownerRoot.Position.X, payload.Position.Y, ownerRoot.Position.Z)
					if (target - payload.Position).Magnitude > 0.01 then cf = CFrame.lookAt(payload.Position, target) end
				end
				reveal:PivotTo(cf + Vector3.new(0, lift + math.abs(math.sin(t * math.pi * 2)) * 1.4, 0))
			end)
			local start = reveal:GetPivot()
			local target = hidden and hidden:GetPivot() or (origin + Vector3.new(0, lift, 0))
			step(0.6, function(t)
				local ease = TweenService:GetValue(t, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
				reveal:PivotTo(start:Lerp(target, ease) + Vector3.new(0, math.sin(t * math.pi) * 2, 0))
			end)
		end, debug.traceback)
		if watch then watch:Disconnect() end
		if egg then egg:Destroy() end
		if reveal then reveal:Destroy() end
		if hidden and hidden.Parent then
			hidden:SetAttribute("PFEHatching", nil)
			for _, p in ipairs(hidden:GetDescendants()) do if p:IsA("BillboardGui") then p.Enabled = true end end
		end
		for p, old in pairs(hiddenParts) do if p.Parent then p.LocalTransparencyModifier = old end end
		active[payload.PetId] = nil
		if not ok then warn("[PFE] hatch show: " .. tostring(err)) end
	end)
end)
