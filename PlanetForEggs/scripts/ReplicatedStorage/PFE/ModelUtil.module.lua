--!nocheck
-- Model helpers shared by server and client: bounds, scaling (part-built eggs use
-- SpecialMesh ellipsoids, so they get an explicit scaler), visual prep and mutations.
local Config = require(script.Parent:WaitForChild("Config"))
local ModelUtil = {}

function ModelUtil.VisibleBounds(model)
	local pivot = model:GetPivot()
	local basis = pivot - pivot.Position
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local found = false
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 0.98 and not part:GetAttribute("PFEFx") then
			found = true
			for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
				local corner = basis:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5))
				lo = lo:Min(corner); hi = hi:Max(corner)
			end end end
		end
	end
	if not found then return pivot, Vector3.zero end
	return basis * CFrame.new((lo + hi) * 0.5), hi - lo
end

local function hasSpecialMesh(model)
	return model:FindFirstChildWhichIsA("SpecialMesh", true) ~= nil
end

function ModelUtil.GetScale(model)
	if hasSpecialMesh(model) then return model:GetAttribute("PFEScale") or 1 end
	return model:GetScale()
end

-- Scale around the model pivot. Part-built models with SpecialMesh spheres are scaled
-- manually (all their parts are anchored visuals); everything else uses ScaleTo.
function ModelUtil.SetScale(model, target)
	target = math.max(0.01, target)
	if not hasSpecialMesh(model) then
		model:ScaleTo(target)
		return
	end
	local current = model:GetAttribute("PFEScale") or 1
	local k = target / current
	if math.abs(k - 1) < 1e-4 then return end
	local pivot = model:GetPivot()
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			local rel = pivot:ToObjectSpace(item.CFrame)
			item.Size *= k
			item.CFrame = pivot * (CFrame.new(rel.Position * k) * rel.Rotation)
		elseif item:IsA("SpecialMesh") then
			item.Offset *= k
			if item.MeshType == Enum.MeshType.FileMesh then item.Scale *= k end
		elseif item:IsA("PointLight") or item:IsA("SpotLight") then
			item.Range = math.min(60, item.Range * k)
		elseif item:IsA("Attachment") then
			item.Position *= k
		end
	end
	model:SetAttribute("PFEScale", target)
end

function ModelUtil.FitTo(model, maxSize)
	local _, size = ModelUtil.VisibleBounds(model)
	local biggest = math.max(size.X, size.Y, size.Z, 0.01)
	ModelUtil.SetScale(model, ModelUtil.GetScale(model) * maxSize / biggest)
end

function ModelUtil.PrepareVisual(object, keepEffects)
	for _, item in ipairs(object:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true; item.CanCollide = false; item.CanTouch = false; item.CanQuery = false
		elseif item:IsA("LuaSourceContainer") or item:IsA("ProximityPrompt") then
			item:Destroy()
		elseif not keepEffects and (item:IsA("ParticleEmitter") or item:IsA("Trail") or item:IsA("Beam")) then
			item.Enabled = false
		end
	end
	if object:IsA("BasePart") then
		object.Anchored = true; object.CanCollide = false; object.CanTouch = false; object.CanQuery = false
	end
	return object
end

-- Pets keep their Motor6D rig live: only parts that nothing drives are anchored.
function ModelUtil.PreparePetRig(model)
	local driven = {}
	for _, joint in ipairs(model:GetDescendants()) do
		if (joint:IsA("JointInstance") or joint:IsA("WeldConstraint")) and joint.Part1 then driven[joint.Part1] = true end
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = not driven[part]; part.Massless = true
			part.CanCollide = false; part.CanTouch = false; part.CanQuery = false
		elseif part:IsA("LuaSourceContainer") or part:IsA("ProximityPrompt") then
			part:Destroy()
		end
	end
end

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
function ModelUtil.ApplyMutation(model, mutationId)
	local mutation = Config.Mutations[mutationId or "Normal"]
	if not mutation or mutation.Id == "Normal" then return end
	model:SetAttribute("Mutation", mutation.Id)
	local strength = mutation.Id == "Golden" and 0.62 or mutation.Id == "Diamond" and 0.55 or mutation.Id == "Cosmic" and 0.6 or 0.35
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 0.95 and part.Name ~= "Pupil" and part.Name ~= "Eye" and part.Name ~= "Shine" then
			if part.Material ~= Enum.Material.Neon then
				part.Color = part.Color:Lerp(mutation.Color, strength)
				if mutation.Id == "Golden" and part:IsA("Part") then part.Material = Enum.Material.Foil end
				if mutation.Id == "Diamond" and part:IsA("Part") then part.Material = Enum.Material.Glass; part.Transparency = math.max(part.Transparency, 0.15) end
			end
			if part:IsA("MeshPart") and part.TextureID ~= "" then
				part.TextureID = ""
			end
		end
	end
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if anchor and not anchor:FindFirstChild("MutationSparkle") then
		local attachment = Instance.new("Attachment")
		attachment.Name = "MutationSparkle"
		local center, size = ModelUtil.VisibleBounds(model)
		attachment.Parent = anchor
		attachment.WorldPosition = center.Position
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = SPARKLE
		emitter.Color = ColorSequence.new(mutation.Color)
		emitter.LightEmission = 1
		emitter.LightInfluence = 0
		emitter.Rate = 6
		emitter.Lifetime = NumberRange.new(0.6, 1.2)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, math.clamp(size.Magnitude * 0.08, 0.2, 1.2)), NumberSequenceKeypoint.new(1, 0)})
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.Parent = attachment
	end
	if mutation.Id == "Rainbow" then model:SetAttribute("RainbowMutation", true) end
end

-- Steal an Egg's egg effects (UIAssets.EggFX, by rarity: Legendary glow, Mythic aura, Secret rainbow
-- crescents, Eternal halo; big size rolls add the Titanic / Gargantuan aura), scaled to this egg.
-- Call again after the egg changed size a lot: the old set is replaced.
local fxFolder
local function eggFxFolder()
	if fxFolder == nil then
		local ui = script.Parent:FindFirstChild("UIAssets")
		fxFolder = ui and ui:FindFirstChild("EggFX") or false
	end
	return fxFolder or nil
end
local function scaledSequence(sequence, k)
	local points = {}
	for _, point in ipairs(sequence.Keypoints) do
		table.insert(points, NumberSequenceKeypoint.new(point.Time, point.Value * k, point.Envelope * k))
	end
	return NumberSequence.new(points)
end
function ModelUtil.AttachEggFX(model, rarity, scale)
	for _, old in ipairs(model:GetDescendants()) do
		if old:GetAttribute("PFEEggFX") then old:Destroy() end
	end
	local folder = eggFxFolder()
	if not folder then return end
	local sets = {}
	if folder:FindFirstChild(rarity or "") then table.insert(sets, folder[rarity]) end
	scale = Config.AssetScale(scale)
	if scale >= 4 and folder:FindFirstChild("GargantuanAura") then table.insert(sets, folder.GargantuanAura)
	elseif scale >= 2.5 and folder:FindFirstChild("TitanicAura") then table.insert(sets, folder.TitanicAura) end
	if #sets == 0 then return end
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then return end
	local center, size = ModelUtil.VisibleBounds(model)
	local largest = math.max(size.X, size.Y, size.Z, 0.1)
	for _, set in ipairs(sets) do
		local k = largest / math.max(0.1, set:GetAttribute("SourceSize") or largest)
		local holder = Instance.new("Attachment")
		holder.Name = "EggFX_" .. set.Name
		holder:SetAttribute("PFEEggFX", true)
		holder.Parent = anchor
		holder.WorldPosition = center.Position
		for _, item in ipairs(set:GetDescendants()) do
			if item:IsA("ParticleEmitter") then
				local emitter = item:Clone()
				emitter.Size = scaledSequence(emitter.Size, k)
				emitter.Speed = NumberRange.new(emitter.Speed.Min * k, emitter.Speed.Max * k)
				emitter.Acceleration *= k
				emitter.Enabled = true
				emitter.Parent = holder
			end
		end
	end
end
-- Clone a template and prepare it as a static visual at a given height.
function ModelUtil.CloneVisual(template, maxSize)
	local model = template:Clone()
	ModelUtil.PrepareVisual(model, true)
	if maxSize then ModelUtil.FitTo(model, maxSize) end
	return model
end

-- Put the bottom centre of the visible bounds at a world point.
function ModelUtil.PlaceOnGround(model, point, yaw)
	local pivot = model:GetPivot()
	model:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, yaw or 0, 0) * (pivot - pivot.Position))
	local bounds, size = ModelUtil.VisibleBounds(model)
	local bottom = bounds.Position - Vector3.new(0, size.Y / 2, 0)
	model:PivotTo(model:GetPivot() + (point - bottom))
end

return ModelUtil
