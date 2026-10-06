--!nocheck
-- v28 pet models, for the server (pens) and the clients (menus, hatch shows):
--  * PetModels.Template(record or species) -> a template Model to :Clone(). A species is its model in
--    UIAssets.Pets; a Chimera record ({Species = "Chimera", Parts = {a, b, c}}) is stitched together here:
--    the body of its first pet, the head of the second and the tail (or wings) of the third, sized to fit,
--    with a shimmering outline. Templates are cached per combination.
--  * Every pet model is rigged the same way (AssetPivot -Root-> Body -Head/Tail/LF_Leg/LeftWing...-> parts, the
--    decorations welded to their part), whether it is a part-built voxel pet or a Blender mesh pet
--    (PetMeshes), so the stitching works on both.
local Config = require(script.Parent:WaitForChild("Config"))
local PetModels = {}

local cache = {}
local CACHE_MAX = 64
local cacheOrder = {}

local function petsFolder()
	local ui = script.Parent:FindFirstChild("UIAssets")
	return ui and ui:FindFirstChild("Pets")
end
function PetModels.Base(species)
	local folder = petsFolder()
	return folder and folder:FindFirstChild(species)
end

-- the Motor6D that drives `part` (nil for parts welded to another)
local function motorOf(model, part)
	for _, m in ipairs(model:GetDescendants()) do
		if m:IsA("Motor6D") and m.Part1 == part then return m end
	end
	return nil
end
-- a rig group: the group's main part (driven by a Motor6D named `group` off the body) and everything welded to it
local function groupOf(model, group)
	local main
	for _, m in ipairs(model:GetDescendants()) do
		if m:IsA("Motor6D") and m.Name == group and m.Part1 then main = m.Part1; break end
	end
	if not main then return nil end
	local parts = {main}
	local seen = {[main] = true}
	local changed = true
	while changed do
		changed = false
		for _, w in ipairs(model:GetDescendants()) do
			if (w:IsA("WeldConstraint") or w:IsA("Weld")) and w.Part0 and w.Part1 then
				if seen[w.Part0] and not seen[w.Part1] then seen[w.Part1] = true; table.insert(parts, w.Part1); changed = true
				elseif seen[w.Part1] and not seen[w.Part0] and w.Part0.Name ~= "Body" and not motorOf(model, w.Part0) then
					seen[w.Part0] = true; table.insert(parts, w.Part0); changed = true
				end
			end
		end
	end
	return main, parts, seen
end

local function bounds(parts)
	local lo, hi
	for _, p in ipairs(parts) do
		if p.Transparency < 0.95 then
			local cf, h = p.CFrame, p.Size * 0.5
			for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
				local c = cf:PointToWorldSpace(Vector3.new(h.X * x, h.Y * y, h.Z * z))
				lo = lo and lo:Min(c) or c; hi = hi and hi:Max(c) or c
			end end end
		end
	end
	if not lo then return Vector3.zero, Vector3.one end
	return (lo + hi) / 2, hi - lo
end

-- scale a set of parts about a point (sizes, positions, special meshes, attachments)
local function scaleParts(parts, about, k)
	for _, p in ipairs(parts) do
		local rel = p.CFrame - about
		p.Size *= k
		p.CFrame = CFrame.new(about + rel.Position * k) * rel.Rotation
		for _, d in ipairs(p:GetChildren()) do
			if d:IsA("SpecialMesh") then
				d.Offset *= k
				if d.MeshType == Enum.MeshType.FileMesh then d.Scale *= k end
			elseif d:IsA("Attachment") then
				d.Position *= k
			end
		end
	end
end

-- move the `group` of donor model `from` onto `into` (replacing its own group of that name)
local function graft(into, from, group, intoBody)
	local donorMain, donorParts = groupOf(from, group)
	if not donorMain then return false end
	local donorMotor = motorOf(from, donorMain)
	local ownMain, ownParts = groupOf(into, group)
	local ownMotor = ownMain and motorOf(into, ownMain)
	-- where the donor's group must sit: on the receiver's joint for it, or (no such group) at the donor's
	-- joint relative to the body, scaled to the receiver's body
	local donorBody = donorMotor and donorMotor.Part0
	local jointWorld, targetSize
	if ownMotor then
		jointWorld = ownMotor.Part0.CFrame * ownMotor.C0
		local _, size = bounds(ownParts)
		targetSize = size
	elseif donorBody then
		local _, ownBodySize = bounds({intoBody})
		local _, donorBodySize = bounds({donorBody})
		local k = ownBodySize.Magnitude / math.max(0.01, donorBodySize.Magnitude)
		local rel = donorBody.CFrame:ToObjectSpace(donorBody.CFrame * donorMotor.C0)
		jointWorld = intoBody.CFrame * (CFrame.new(rel.Position * k) * rel.Rotation)
		local _, size = bounds(donorParts)
		targetSize = size * k
	else
		return false
	end
	-- the donor group, cloned into the receiver
	local copies, map = {}, {}
	for _, p in ipairs(donorParts) do
		local c = p:Clone()
		for _, d in ipairs(c:GetChildren()) do if d:IsA("JointInstance") or d:IsA("WeldConstraint") then d:Destroy() end end
		map[p] = c
		table.insert(copies, c)
	end
	-- place: the donor joint frame goes onto the receiver's joint frame, then scale to the receiver's size
	local donorJoint = donorMotor and (donorMotor.Part0.CFrame * donorMotor.C0) or donorMain.CFrame
	local move = jointWorld * donorJoint:Inverse()
	for p, c in pairs(map) do c.CFrame = move * p.CFrame end
	local _, size = bounds(copies)
	local k = math.clamp(math.max(targetSize.X, targetSize.Y, targetSize.Z) / math.max(0.05, math.max(size.X, size.Y, size.Z)), 0.35, 2.5)
	scaleParts(copies, jointWorld.Position, k)
	-- out with the receiver's own group, in with the copy (the rig: a Motor6D off the receiver's body)
	if ownMotor then ownMotor:Destroy() end
	if ownParts then for _, p in ipairs(ownParts) do p:Destroy() end end
	local newMain = map[donorMain]
	for _, c in ipairs(copies) do c.Parent = into end
	for _, c in ipairs(copies) do
		if c ~= newMain then
			local w = Instance.new("WeldConstraint"); w.Part0 = newMain; w.Part1 = c; w.Parent = newMain
		end
	end
	local motor = Instance.new("Motor6D")
	motor.Name = group; motor.Part0 = intoBody; motor.Part1 = newMain
	motor.C0 = intoBody.CFrame:ToObjectSpace(jointWorld)
	motor.C1 = newMain.CFrame:ToObjectSpace(jointWorld)
	motor.Parent = intoBody
	return true
end

local function rainbowOutline(model)
	local hl = Instance.new("Highlight")
	hl.Name = "ChimeraGlow"; hl.FillTransparency = 0.88; hl.OutlineTransparency = 0.1
	hl.FillColor = Color3.fromRGB(255, 70, 255); hl.OutlineColor = Color3.fromRGB(120, 255, 240)
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = model
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if anchor then
		local a = Instance.new("Attachment"); a.Name = "ChimeraFx"; a.Parent = anchor
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"; e.Rate = 8; e.LightEmission = 1; e.LightInfluence = 0
		e.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 200)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 255, 240)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 230, 90))})
		e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0)})
		e.Lifetime = NumberRange.new(0.8, 1.6); e.Speed = NumberRange.new(1, 3); e.SpreadAngle = Vector2.new(180, 180)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.Parent = a
	end
end

local function buildChimera(parts)
	local bodyT, headT, tailT = PetModels.Base(parts[1]), PetModels.Base(parts[2] or parts[1]), PetModels.Base(parts[3] or parts[2] or parts[1])
	if not bodyT then return nil end
	local model = bodyT:Clone()
	model.Name = "Chimera"
	local body
	for _, m in ipairs(model:GetDescendants()) do
		if m:IsA("Motor6D") and m.Name == "Root" then body = m.Part1; break end
	end
	body = body or model:FindFirstChild("Body", true)
	if body and headT and parts[2] then pcall(graft, model, headT, "Head", body) end
	if body and tailT and parts[3] then
		local donorHasWings = false
		for _, m in ipairs(tailT:GetDescendants()) do if m:IsA("Motor6D") and m.Name == "LeftWing" then donorHasWings = true; break end end
		if donorHasWings then
			pcall(graft, model, tailT, "LeftWing", body)
			pcall(graft, model, tailT, "RightWing", body)
		else
			pcall(graft, model, tailT, "Tail", body)
		end
	end
	model:SetAttribute("Species", "Chimera")
	model:SetAttribute("Chimera", table.concat(parts, "+"))
	rainbowOutline(model)
	return model
end

function PetModels.Template(record)
	if type(record) == "string" then
		if record ~= "Chimera" then return PetModels.Base(record) end
		record = {Species = "Chimera", Parts = {"Chicken", "Dog", "Dragon"}}
	end
	if type(record) ~= "table" then return nil end
	if record.Species ~= "Chimera" then return PetModels.Base(record.Species) end
	local parts = type(record.Parts) == "table" and record.Parts or {}
	if #parts < 1 then return PetModels.Base("Chicken") end
	local key = table.concat(parts, "+")
	local hit = cache[key]
	if hit then return hit end
	local ok, model = pcall(buildChimera, parts)
	if not ok or not model then
		if not ok then warn("[PFE] chimera build failed: " .. tostring(model)) end
		return PetModels.Base(parts[1])
	end
	-- (kept out of the world, parented to nothing: only ever cloned)
	cache[key] = model
	table.insert(cacheOrder, key)
	while #cacheOrder > CACHE_MAX do
		local old = table.remove(cacheOrder, 1)
		if cache[old] then cache[old]:Destroy(); cache[old] = nil end
	end
	return model
end

-- the display name / rarity / income of a pet record (a species id works too)
function PetModels.Info(record) return Config.PetInfo(record) end

return PetModels
