--!nocheck
-- Only the space helmet on every character (its glass dome, lamp and neck ring - SuitData), no suit:
-- the avatar keeps its own clothes and colours (the jetpack is on the back, see Gear). Hats and
-- face accessories are hidden so nothing pokes through the glass; the hair stays (nobody bald inside). Pieces are stored as fractions of their bone
-- size, so they fit R15 and R6 avatars of any proportions. Colours follow each player's suit level.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local api = ReplicatedStorage:WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local SuitData = require(api:WaitForChild("SuitData"))

local R6 = {
	Head = "Head", UpperTorso = "Torso", LowerTorso = "Torso",
	LeftUpperArm = "Left Arm", LeftLowerArm = "Left Arm", LeftHand = "Left Arm",
	RightUpperArm = "Right Arm", RightLowerArm = "Right Arm", RightHand = "Right Arm",
	LeftUpperLeg = "Left Leg", LeftLowerLeg = "Left Leg", LeftFoot = "Left Leg",
	RightUpperLeg = "Right Leg", RightLowerLeg = "Right Leg", RightFoot = "Right Leg",
}
-- where an R15 bone sits inside the matching R6 limb (fraction of the R6 part, centre offset, size fraction)
local R6Slice = {
	UpperTorso = {0.2, 0.8}, LowerTorso = {-0.4, 0.2},
	LeftUpperArm = {0.3, 0.6}, LeftLowerArm = {-0.2, 0.5}, LeftHand = {-0.42, 0.16},
	RightUpperArm = {0.3, 0.6}, RightLowerArm = {-0.2, 0.5}, RightHand = {-0.42, 0.16},
	LeftUpperLeg = {0.3, 0.6}, LeftLowerLeg = {-0.15, 0.5}, LeftFoot = {-0.42, 0.16},
	RightUpperLeg = {0.3, 0.6}, RightLowerLeg = {-0.15, 0.5}, RightFoot = {-0.42, 0.16},
}
local MATERIALS = {SmoothPlastic = Enum.Material.SmoothPlastic, Neon = Enum.Material.Neon, Glass = Enum.Material.Glass,
	Foil = Enum.Material.Foil, Metal = Enum.Material.Metal, Plastic = Enum.Material.Plastic}

local function colorFor(role, suit, super)
	if role == "Glass" then return Color3.fromRGB(190, 230, 255) end
	if role == "Visor" then return Color3.fromRGB(255, 200, 90) end
	if role == "Glow" then return super and Color3.fromRGB(255, 220, 90) or suit.Glow end
	return suit[role] or suit.Primary
end

local function buildSuit(character, owner)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local head = character:WaitForChild("Head", 10)
	if not humanoid or not head then return end
	local old = character:FindFirstChild("PFE_Suit")
	if old then old:Destroy() end
	local r15 = humanoid.RigType == Enum.HumanoidRigType.R15
	if r15 then character:WaitForChild("LowerTorso", 5) else character:WaitForChild("Torso", 5) end
	local level = owner:GetAttribute("PFESuitLevel") or 1
	local suit = Config.Suits[math.clamp(level, 1, #Config.Suits)]
	local super = owner:GetAttribute("PFESuperSuit") == true
	local folder = Instance.new("Model")
	folder.Name = "PFE_Suit"
	for _, piece in ipairs(SuitData.Pieces) do
		if piece.Bone ~= "Head" and piece.Name ~= "Collar" and piece.Name ~= "CollarRing" then continue end -- (the helmet only)
		local boneName = r15 and piece.Bone or R6[piece.Bone]
		local bone = boneName and character:FindFirstChild(boneName)
		local refSize = SuitData.Bones[piece.Bone] and SuitData.Bones[piece.Bone].Size
		if bone and bone:IsA("BasePart") and refSize then
			local size = bone.Size
			local frac = Vector3.new(piece.Frac[1], piece.Frac[2], piece.Frac[3])
			local boneSize = size
			local centre = CFrame.new()
			if not r15 and R6Slice[piece.Bone] then
				local slice = R6Slice[piece.Bone]
				centre = CFrame.new(0, slice[1] * size.Y, 0)
				boneSize = Vector3.new(size.X, size.Y * slice[2], size.Z)
			end
			local k = Vector3.new(boneSize.X / refSize[1], boneSize.Y / refSize[2], boneSize.Z / refSize[3])
			local uniform = (k.X + k.Z) * 0.5
			local offset = Vector3.new(frac.X * boneSize.X, frac.Y * boneSize.Y, frac.Z * boneSize.Z)
			local r = piece.Rot
			local rotation = CFrame.new(0, 0, 0, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
			local p = Instance.new("Part")
			p.Name = piece.Name
			p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.Massless = true; p.Anchored = false
			p.CastShadow = piece.Role ~= "Glass"
			p.Material = MATERIALS[piece.Material] or Enum.Material.SmoothPlastic
			p.Color = colorFor(piece.Role, suit, super)
			p.Transparency = piece.Transparency or 0
			local s = Vector3.new(piece.Size[1], piece.Size[2], piece.Size[3]) * math.clamp(uniform, 0.4, 3)
			if piece.Shape == "Ball" then p.Shape = Enum.PartType.Ball
			elseif piece.Shape == "Cylinder" then p.Shape = Enum.PartType.Cylinder end
			p.Size = s
			if piece.Shape == "Sphere" then
				local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = p
			end
			p.CFrame = bone.CFrame * centre * CFrame.new(offset) * rotation
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = bone; weld.Part1 = p; weld.Parent = p
			p.Parent = folder
		end
	end
	folder.Parent = character
	-- hats and face accessories would poke through the glass: hidden. Hair stays (nobody is bald under
	-- the helmet): an accessory of the Hair type, or one hung on the HairAttachment, is never hidden.
	local HEAD_SLOTS = {HatAttachment = true, FaceFrontAttachment = true, FaceCenterAttachment = true}
	local function cover(item)
		if not item:IsA("Accessory") then return end
		local ok, isHair = pcall(function() return item.AccessoryType == Enum.AccessoryType.Hair end)
		if ok and isHair then return end
		for _, a in ipairs(item:GetDescendants()) do if a:IsA("Attachment") and a.Name == "HairAttachment" then return end end
		local onHead = false
		for _, a in ipairs(item:GetDescendants()) do if a:IsA("Attachment") and HEAD_SLOTS[a.Name] then onHead = true end end
		if onHead then
			for _, part in ipairs(item:GetDescendants()) do if part:IsA("BasePart") then part.Transparency = 1 end end
		end
	end
	for _, item in ipairs(character:GetChildren()) do cover(item) end
	character.ChildAdded:Connect(function(item) task.defer(cover, item) end)
end

local function watch(other)
	local function onCharacter(character)
		task.spawn(buildSuit, character, other)
	end
	if other.Character then onCharacter(other.Character) end
	other.CharacterAdded:Connect(onCharacter)
	other:GetAttributeChangedSignal("PFESuitLevel"):Connect(function()
		if other.Character then task.spawn(buildSuit, other.Character, other) end
	end)
end
for _, other in ipairs(Players:GetPlayers()) do watch(other) end
Players.PlayerAdded:Connect(watch)
-- (v35) the bot explorers wear the helmet like everyone (their suit level is an attribute on the body itself)
task.spawn(function()
	local botFolder = workspace:WaitForChild("PFE_Bots", 60)
	if not botFolder then return end
	local seen = setmetatable({}, {__mode = "k"})
	local function watchBot(model)
		if not model:IsA("Model") or seen[model] then return end
		seen[model] = true
		task.spawn(buildSuit, model, model)
		model:GetAttributeChangedSignal("PFESuitLevel"):Connect(function() task.spawn(buildSuit, model, model) end)
	end
	for _, model in ipairs(botFolder:GetChildren()) do watchBot(model) end
	botFolder.ChildAdded:Connect(watchBot)
end)
