--!nocheck
-- Earth bases: planting, growing, hatching, pet income, shields and Steal-an-Egg style
-- theft (carry an egg from another pen back to your own; the owner catches thieves by touch).
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local Bases = {}
local ctx, Config, Data, ModelUtil
local rng = Random.new()
local zones = {}          -- base -> {CFrame, HalfX, HalfZ, Index, Shield}
local bound = {}          -- player -> {Group, Character, Previous = {}}

local function ownerGroup(i) return "PFE_Owner" .. i end
local function shieldGroup(i) return "PFE_Shield" .. i end

-- ---------------------------------------------------------------- geometry
function Bases.PlantArea(profile)
	local area = profile.Base and profile.Base:FindFirstChild("PlantArea")
	if area and area:IsA("BasePart") then return area.CFrame, area.Size end
	return nil
end
local function plantedPosition(profile, egg)
	local cf = Bases.PlantArea(profile)
	if not cf then return nil end
	return cf:PointToWorldSpace(Vector3.new(egg.LocalPosition[1], 0, egg.LocalPosition[3]))
end
local function inside(zone, position, padding)
	local p = zone.CFrame:PointToObjectSpace(position)
	return math.abs(p.X) < zone.HalfX + padding and math.abs(p.Z) < zone.HalfZ + padding and p.Y > -6 and p.Y < 40
end
function Bases.GrowingState(profile)
	local list = {}
	for _, egg in ipairs(profile.Data.GrowingEggs) do
		local item = Data.Copy(egg)
		item.Position = plantedPosition(profile, egg)
		table.insert(list, item)
	end
	return list
end
function Bases.IsProtected(profile)
	return #profile.Data.Pets < Config.NoviceProtectionPets
end
local function shielded(profile)
	return (profile.ShieldUntil or 0) > workspace:GetServerTimeNow()
end
local function profileOfBase(base)
	for _, profile in pairs(ctx.profiles) do if profile.Base == base then return profile end end
	return nil
end
-- (v35) is this player still in the game? A bot's profile counts while the bot is here (Bots.lua: profile.IsBot)
local function online(profile)
	if not profile then return false end
	if profile.IsBot then return profile.Bot ~= nil and not profile.Bot.Gone end
	return ctx.profiles[profile.Player] == profile and profile.Player.Parent ~= nil
end
Bases.Online = online
-- where an egg growing in this pen stands (world space)
function Bases.EggPoint(profile, egg)
	return plantedPosition(profile, egg)
end

-- ---------------------------------------------------------------- collision groups
local function bindCharacter(player, character)
	local record = bound[player]
	if not record then return end
	for part, previous in pairs(record.Previous) do
		if part.Parent and part.CollisionGroup == record.Group then part.CollisionGroup = previous end
	end
	record.Previous = {}
	if record.Connection then record.Connection:Disconnect() end
	local function assign(part)
		if part:IsA("BasePart") then
			if record.Previous[part] == nil then record.Previous[part] = part.CollisionGroup end
			part.CollisionGroup = record.Group
		end
	end
	for _, part in ipairs(character:GetDescendants()) do assign(part) end
	record.Connection = character.DescendantAdded:Connect(assign)
end

-- ---------------------------------------------------------------- billboards
local RUBIK = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
local function billboard(part, name, size, offset)
	local gui = Instance.new("BillboardGui")
	gui.Name = name; gui.Size = size; gui.StudsOffsetWorldSpace = offset; gui.AlwaysOnTop = false
	gui.MaxDistance = 140; gui.LightInfluence = 0; gui.Adornee = part; gui.Parent = part
	local title = Instance.new("TextLabel")
	title.Name = "Title"; title.BackgroundTransparency = 1; title.Size = UDim2.fromScale(1, 1); title.FontFace = RUBIK
	title.TextScaled = true; title.TextColor3 = Color3.new(1, 1, 1); title.Text = ""; title.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3; stroke.Color = Color3.fromRGB(14, 12, 28); stroke.LineJoinMode = Enum.LineJoinMode.Round; stroke.Parent = title
	return gui
end
local function setBoard(gui, title, color)
	if not gui then return end
	if gui.Title.Text ~= title then gui.Title.Text = title end
	if color and gui.Title.TextColor3 ~= color then gui.Title.TextColor3 = color end
end

-- (v29) the sign over a base (bots use it too)
function Bases.SetSign(base, text, color)
	local sign = base:FindFirstChild("SignAnchor")
	setBoard(sign and sign:FindFirstChild("OwnerSign"), text, color)
end

function Bases.RefreshBaseInfo(profile)
	local base = profile.Base
	if not base then return end
	local now = workspace:GetServerTimeNow()
	base:SetAttribute("ShieldUntil", profile.ShieldUntil or 0)
	base:SetAttribute("Protected", Bases.IsProtected(profile))
	local sign = base:FindFirstChild("SignAnchor")
	setBoard(sign and sign:FindFirstChild("OwnerSign"), profile.Player.DisplayName .. "'s Base",
		ctx.hasPass(profile, "VIP") and Color3.fromRGB(255, 210, 70) or Color3.new(1, 1, 1))
end

-- ---------------------------------------------------------------- garden rendering
-- Only what changed is rebuilt: a pet that stays in the pen keeps its model (no flicker, no
-- re-replication). Each model carries PartCount, so clients start animating it only once every
-- part has arrived (a half-replicated rig measures wrong: sunk, floating or the wrong size).
local function petKey(pet) return pet.Id .. ":" .. tostring(pet.Scale) .. ":" .. tostring(pet.Mutation) end
function Bases.RenderGarden(profile)
	local folder = profile.Base:FindFirstChild("ActivePets")
	if not folder then
		folder = Instance.new("Folder"); folder.Name = "ActivePets"; folder.Parent = profile.Base
	end
	local anchor = ctx.partOf(profile.Base:FindFirstChild("GardenAnchor"))
	if not anchor then return end
	local pets = ctx.petList(profile)
	local wanted = {}
	for index = 1, math.min(#pets, Config.MaxActivePets) do wanted[petKey(pets[index])] = index end
	local have = {}
	for _, model in ipairs(folder:GetChildren()) do
		local key = model:GetAttribute("PetKey")
		if key and wanted[key] and not have[key] then have[key] = model else model:Destroy() end
	end
	for index = 1, math.min(#pets, Config.MaxActivePets) do
		local pet = pets[index]
		local key = petKey(pet)
		local existing = have[key]
		if existing then
			if existing:GetAttribute("Income") ~= pet.Income then
				existing:SetAttribute("Income", pet.Income)
				local label = existing:FindFirstChild("PFELabel", true)
				if label and label:FindFirstChild("Subtitle") then label.Subtitle.Text = "+" .. Config.Format(pet.Income) .. " /s" end
			end
			continue
		end
		local template = ctx.petTemplate(pet.Species, pet)
		if template then
			local model = template:Clone()
			model.Name = pet.Name
			-- the cooler the pet, the bigger (its rarity's size times its size roll)
			local info = Config.PetInfo(pet)
			local _, native = ModelUtil.VisibleBounds(model)
			local largest = math.max(native.X, native.Y, native.Z, 0.1)
			local target = Config.BasePetTarget(info and info.Rarity, pet.Scale, pet.Species)
			local ok = pcall(function() model:ScaleTo(model:GetScale() * target / largest) end)
			if not ok then warn("[PFE] could not scale pet", pet.Species) end
			ModelUtil.ApplyMutation(model, pet.Mutation)
			model:SetAttribute("Species", pet.Species); model:SetAttribute("PetId", pet.Id); model:SetAttribute("PetKey", key)
			model:SetAttribute("Income", pet.Income); model:SetAttribute("Scale", pet.Scale); model:SetAttribute("TargetSize", target)
			local col, row = (index - 1) % 3 - 1, math.floor((index - 1) / 3)
			local areaCf, areaSize = Bases.PlantArea(profile)
			local floor = areaCf and areaCf.Position.Y + areaSize.Y / 2 or anchor.Position.Y - 1
			model:PivotTo(anchor.CFrame * CFrame.new(col * 12, 0, row * 12 - 8))
			local spot = model:GetPivot().Position
			ModelUtil.PlaceOnGround(model, Vector3.new(spot.X, floor, spot.Z), 0)
			local title = (pet.Mutation ~= "Normal" and (Config.Mutations[pet.Mutation].Name .. " ") or "") .. pet.Name
			local _, grown = ModelUtil.VisibleBounds(model)
			ctx.label(model, title, "+" .. Config.Format(pet.Income) .. " /s", Config.Rarities[info.Rarity].Color, math.max(5.5, grown.Y + 1.5))
			ModelUtil.PreparePetRig(model)
			local count = 0
			for _, part in ipairs(model:GetDescendants()) do if part:IsA("BasePart") then count += 1 end end
			model:SetAttribute("PartCount", count)
			model.Parent = folder
		end
	end
end

local function growthText(egg, now)
	local remaining = math.ceil(math.max(0, egg.ReadyAt - now))
	if remaining == 0 then return "READY!" end
	return Config.FormatTime(remaining)
end

-- horizontal radius of an egg model at a given scale (template bounds are cached per egg id)
local footprints = {}
local function footprint(eggId, scale)
	local record = footprints[eggId]
	if not record then
		local template = ctx.eggTemplate(eggId)
		if not template then return 1 end
		local _, size = ModelUtil.VisibleBounds(template)
		record = {Radius = math.max(size.X, size.Z) / 2, Size = math.max(size.X, size.Y, size.Z), Scale = math.max(0.001, ModelUtil.GetScale(template))}
		footprints[eggId] = record
	end
	return record.Radius * scale / record.Scale
end
function Bases.EggRadius(egg)
	footprint(egg.EggId, 1)
	local record = footprints[egg.EggId]
	if not record then return 1 end
	local info = Config.Eggs[egg.EggId]
	local _, target = Config.EggGrowthScales(record.Scale, egg.Scale, record.Size, info and info.Rarity)
	return footprint(egg.EggId, target)
end

-- The server only keeps the timers, prompts and attributes current; EggGrowth.client
-- scales the egg smoothly from StartScale to TargetScale (no per-tick re-pivoting here).
function Bases.UpdateGrowing(profile)
	local folder = profile.Base and profile.Base:FindFirstChild("GrowingEggs")
	if not folder then return end
	local now = os.time()
	for _, egg in ipairs(profile.Data.GrowingEggs) do
		local object = folder:FindFirstChild(egg.Id)
		if object then
			local ready = now >= egg.ReadyAt
			local label = object:FindFirstChild("PFELabel")
			if label then
				local text = growthText(egg, now)
				if label.Subtitle.Text ~= text then label.Subtitle.Text = text end
			end
			if object:GetAttribute("ReadyAt") ~= egg.ReadyAt then object:SetAttribute("ReadyAt", egg.ReadyAt) end
			if object:GetAttribute("Ready") ~= ready then object:SetAttribute("Ready", ready) end
			local hatch = object:FindFirstChild("HatchGrownEgg", true)
			if hatch then hatch.Enabled = ready end
			local skip = object:FindFirstChild("SkipGrowth", true)
			if skip then
				skip.Enabled = not ready
				local product = not ready and Config.SkipProductFor(egg.ReadyAt - now)
				if product and skip:GetAttribute("ProductKey") ~= product.Key then
					skip:SetAttribute("ProductKey", product.Key); skip:SetAttribute("ProductId", product.Id); skip:SetAttribute("Price", product.Price or 0)
				end
			end
		end
	end
end

-- The egg itself is drawn by every client (EggGrowth.client, from UIAssets.Eggs): the server object is
-- a light anchor with the timers, sizes and prompts, so planting never shows a half-replicated or
-- wrongly sized egg. Only eggs that changed are rebuilt.
function Bases.RenderGrowing(profile)
	local folder = profile.Base:FindFirstChild("GrowingEggs")
	if not folder then
		folder = Instance.new("Folder"); folder.Name = "GrowingEggs"; folder.Parent = profile.Base
	end
	folder:SetAttribute("OwnerUserId", profile.Player.UserId)
	local wanted = {}
	for _, egg in ipairs(profile.Data.GrowingEggs) do wanted[egg.Id] = egg end
	for _, object in ipairs(folder:GetChildren()) do
		local egg = wanted[object.Name]
		local hatching = profile.HatchingVisual and profile.HatchingVisual[object.Name]
		if not hatching and (not egg or object:GetAttribute("EggId") ~= egg.EggId or object:GetAttribute("Mutation") ~= egg.Mutation
			or object:GetAttribute("OwnerUserId") ~= profile.Player.UserId) then
			object:Destroy()
		end
	end
	local now = os.time()
	for _, egg in ipairs(profile.Data.GrowingEggs) do
		if folder:FindFirstChild(egg.Id) then continue end
		local template = ctx.eggTemplate(egg.EggId)
		local point = plantedPosition(profile, egg)
		if template and point then
			local info = Config.Eggs[egg.EggId]
			footprint(egg.EggId, 1)
			local record = footprints[egg.EggId]
			local object = Instance.new("Model"); object.Name = egg.Id
			object:SetAttribute("OwnerUserId", profile.Player.UserId); object:SetAttribute("EggId", egg.EggId)
			object:SetAttribute("Mutation", egg.Mutation); object:SetAttribute("Scale", egg.Scale or 1)
			object:SetAttribute("PlacedAt", egg.PlacedAt); object:SetAttribute("ReadyAt", egg.ReadyAt)
			object:SetAttribute("Duration", egg.GrowthDuration); object:SetAttribute("Point", point)
			local yaw = (string.byte(egg.Id, 1) or 0) % 12 * 0.5
			object:SetAttribute("Yaw", yaw)
			-- the cooler the egg, the bigger: its rarity's size times its size roll, growing while it incubates
			local full = record.Scale
			local startScale, targetScale = Config.EggGrowthScales(full, egg.Scale, record.Size, info.Rarity)
			object:SetAttribute("FullScale", full); object:SetAttribute("StartScale", startScale); object:SetAttribute("TargetScale", targetScale)
			local reach = footprint(egg.EggId, targetScale)
			local height = record.Size * targetScale / full
			local proxy = Instance.new("Part"); proxy.Name = "GrowthAnchor"; proxy.Size = Vector3.new(2.6, 3.4, 2.6)
			proxy.Transparency = 1; proxy.Anchored = true; proxy.CanCollide = false; proxy.CanTouch = false; proxy.CanQuery = false
			proxy.CFrame = CFrame.new(point + Vector3.new(0, 1.7, 0)); proxy.Parent = object; object.PrimaryPart = proxy
			ctx.label(object, Config.EggDisplayName(egg), "", Config.Rarities[info.Rarity].Color, 3.2).MaxDistance = 45 + height
			object:SetAttribute("Radius", reach)
			local hatch = ctx.makePrompt(proxy, "HatchGrownEgg", "Hatch!", function(player)
				if player == profile.Player and ctx.profiles[player] == profile then Bases.Hatch(profile, egg.Id); ctx.markDirty(profile) end
			end, {Hold = 0, Distance = math.max(8, reach + 6), ObjectText = info.Name})
			hatch.Enabled = now >= egg.ReadyAt
			local skip = ctx.makePrompt(proxy, "SkipGrowth", "Skip Growth!", function(player)
				if player == profile.Player and ctx.profiles[player] == profile then Bases.RequestSkip(profile, egg.Id) end
			end, {Hold = 0, Distance = math.max(10, reach + 7), ObjectText = info.Name})
			skip.Enabled = now < egg.ReadyAt
			ctx.makePrompt(proxy, "StealEgg", "Steal", function(player)
				local thief = ctx.profiles[player]
				if thief and thief ~= profile then Bases.TrySteal(thief, profile, egg.Id) end
			end, {Hold = Config.StealHoldDuration, Distance = math.max(9, reach + 6), ObjectText = profile.Player.DisplayName .. "'s egg", Key = Enum.KeyCode.F})
			object.Parent = folder
		end
	end
	Bases.UpdateGrowing(profile)
end

-- ---------------------------------------------------------------- skip growth (Robux, like Steal an Egg)
local function growingEgg(profile, eggId)
	for _, egg in ipairs(profile.Data.GrowingEggs) do if egg.Id == eggId then return egg end end
	return nil
end
local function skipEgg(profile, egg, seconds)
	local now = os.time()
	egg.ReadyAt = math.max(now, egg.ReadyAt - seconds)
	Bases.UpdateGrowing(profile)
	if egg.ReadyAt <= now then ctx.notice(profile, Config.EggDisplayName(egg) .. " is ready!", "Gold") end
	ctx.markDirty(profile)
end
-- a bought skip goes to the egg the player tapped, otherwise the egg it helps most, otherwise it is banked
function Bases.ApplySkip(profile, seconds)
	local now = os.time()
	local pending = profile.PendingSkip
	profile.PendingSkip = nil
	local target = pending and os.clock() - pending.At < 900 and growingEgg(profile, pending.EggId) or nil
	if not target or target.ReadyAt <= now then
		target = nil
		local bestGain, bestLeft = 0, math.huge
		for _, egg in ipairs(profile.Data.GrowingEggs) do
			local left = egg.ReadyAt - now
			local gain = math.min(left, seconds)
			if left > 0 and (gain > bestGain or (gain == bestGain and left < bestLeft)) then target, bestGain, bestLeft = egg, gain, left end
		end
	end
	if not target then
		profile.Data.SkipBank = math.min(10000000, (profile.Data.SkipBank or 0) + seconds)
		ctx.notice(profile, "Skip saved for your next egg!", "Gold")
		ctx.markDirty(profile)
		return
	end
	skipEgg(profile, target, seconds)
end
function Bases.RequestSkip(profile, eggId)
	if type(eggId) ~= "string" or profile.Busy then return end
	local egg = growingEgg(profile, eggId)
	local now = os.time()
	if not egg or egg.ReadyAt <= now then return end
	local left = egg.ReadyAt - now
	local bank = profile.Data.SkipBank or 0
	if bank > 0 then
		local used = math.min(bank, left)
		profile.Data.SkipBank = bank - used
		skipEgg(profile, egg, used)
		return
	end
	local product = Config.SkipProductFor(left)
	if not product then return end
	profile.PendingSkip = {EggId = egg.Id, At = os.clock()}
	if product.Id > 0 then
		local ok, err = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, profile.Player, product.Id)
		if not ok then warn("[PFE] skip prompt failed", err) end
	elseif RunService:IsStudio() then
		ctx.GrantProduct(profile, product) -- product id not set yet: free in Studio so the flow can be tested
	else
		ctx.notice(profile, "Skipping opens soon!")
	end
end

-- ---------------------------------------------------------------- planting & hatching
function Bases.PlantEgg(profile, argument)
	if type(argument) ~= "table" or type(argument.EggId) ~= "string" or typeof(argument.Position) ~= "Vector3" then return end
	if profile.Planet ~= "Base" or profile.Busy then return end
	if not ctx.near(profile, profile.Base:FindFirstChild("Spawn"), Config.BaseInteractionDistance) then ctx.notice(profile, "Plant eggs inside your own pen."); return end
	if #profile.Data.GrowingEggs >= Config.MaxGrowingEggs then ctx.notice(profile, "Your pen is full of growing eggs."); return end
	local point = argument.Position
	if point.X ~= point.X or point.Y ~= point.Y or point.Z ~= point.Z then return end
	local cf, size = Bases.PlantArea(profile)
	if not cf then return end
	local localPoint = cf:PointToObjectSpace(point)
	local margin = 2
	local step = Config.PlantGridSize
	localPoint = Vector3.new(math.round(localPoint.X / step) * step, 0, math.round(localPoint.Z / step) * step)
	if math.abs(localPoint.X) > size.X / 2 - margin or math.abs(localPoint.Z) > size.Z / 2 - margin then ctx.notice(profile, "Place the egg inside your pen."); return end
	local characterRoot = ctx.root(profile.Player)
	if not characterRoot or (characterRoot.Position - cf:PointToWorldSpace(localPoint)).Magnitude > Config.PlantDistance then
		ctx.notice(profile, "Move closer to that spot."); return
	end
	local index
	for i, egg in ipairs(profile.Data.Eggs) do if egg.Id == argument.EggId then index = i; break end end
	if not index then return end
	-- eggs grow to three times their size: keep room for the grown eggs (capped so big eggs still fit)
	local mine = math.min(Bases.EggRadius(profile.Data.Eggs[index]), Config.PlantRadiusCap)
	for _, other in ipairs(profile.Data.GrowingEggs) do
		local gap = math.max(Config.PlantMinSpacing, mine + math.min(Bases.EggRadius(other), Config.PlantRadiusCap))
		if Vector2.new(localPoint.X - other.LocalPosition[1], localPoint.Z - other.LocalPosition[3]).Magnitude < gap then
			ctx.notice(profile, "Leave some space between eggs."); return
		end
	end
	local egg = table.remove(profile.Data.Eggs, index)
	local info = Config.Eggs[egg.EggId]
	egg.LocalPosition = {localPoint.X, 0, localPoint.Z}
	-- eggs found during an Aurora grow twice as fast
	egg.PlacedAt = os.time(); egg.GrowthDuration = Config.EggGrowthDuration(info, egg.Scale) * (egg.FastGrow and 0.5 or 1)
	egg.ReadyAt = egg.PlacedAt + egg.GrowthDuration
	table.insert(profile.Data.GrowingEggs, egg)
	profile.Data.TutorialStep = math.max(profile.Data.TutorialStep, 2)
	Bases.RenderGrowing(profile)
	ctx.notice(profile, Config.EggDisplayName(egg) .. " planted!", "Green")
	ctx.effect(profile.Player, "Planted", {Position = cf:PointToWorldSpace(localPoint)})
	ctx.markDirty(profile)
end

-- ---------------------------------------------------------------- v28: the hatch multiplier
-- one step up the mutation ladder (Normal -> Golden -> Diamond -> Rainbow -> Cosmic)
local function nextMutation(id)
	for i, m in ipairs(Config.MutationList) do
		if m.Id == (id or "Normal") then return (Config.MutationList[i + 1] or m).Id end
	end
	return "Golden"
end
-- two more pets for a Chimera: the cooler pets of the same planet are likelier
local function chimeraPartners(best)
	local planet = Config.Pets[best] and Config.Pets[best].Planet
	local pool, total = {}, 0
	for _, pet in ipairs(Config.PetList) do
		if pet.Species ~= best and not pet.Limited and not pet.Special and (pet.Planet == planet or not Config.Planets[planet or ""]) then
			local w = (Config.Rarities[pet.Rarity] and Config.Rarities[pet.Rarity].Order or 1) ^ 2
			table.insert(pool, {pet.Species, w}); total += w
		end
	end
	local picked = {}
	for _ = 1, 2 do
		if #pool == 0 then break end
		local roll = rng:NextNumber() * total
		for i, entry in ipairs(pool) do
			roll -= entry[2]
			if roll <= 0 or i == #pool then
				table.insert(picked, entry[1]); total -= entry[2]; table.remove(pool, i)
				break
			end
		end
	end
	return picked
end
-- what an egg hatches with multiplier m: the pet record, the drop table used and whether the mutation went up
function Bases.RollPet(egg, m)
	local info = Config.Eggs[egg.EggId]
	if info and info.Generated and info.Hybrids and #info.Hybrids > 0 then
		local luck = math.max(1, m or 1) ^ (Config.HatchRoll.LuckPower or 1)
		local n, total, weights = #info.Hybrids, 0, {}
		for i, h in ipairs(info.Hybrids) do
			weights[i] = h.Weight * luck ^ ((i - 1) / math.max(1, n - 1))
			total += weights[i]
		end
		local roll, pick = rng:NextNumber() * total, info.Hybrids[n]
		for i, h in ipairs(info.Hybrids) do
			roll -= weights[i]
			if roll <= 0 then pick = h; break end
		end
		local mutation = egg.Mutation or "Normal"
		local upgraded = false
		if m >= Config.HatchRoll.MutationFrom then
			local up = nextMutation(mutation)
			upgraded = up ~= mutation
			mutation = up
		end
		local income = pick.Income
		if m >= Config.HatchRoll.ChimeraFrom then income = math.floor(income * Config.ChimeraBonus(m) + 0.5) end
		local pet = {Id = Data.Guid(), Species = "Chimera", Parts = table.clone(pick.Parts), Name = pick.Name, Income = math.max(1, income),
			Rarity = info.Rarity, Scale = Config.AssetScale(egg.Scale), Mutation = mutation}
		if m >= 10 then pet.Multiplier = m end
		return pet, upgraded
	end
	local drops = info.Fusion and Config.FusionDrops(info.Rarity, egg.Sources) or info.Drops
	if type(drops) ~= "table" or #drops == 0 then drops = {{info.Species, 1}} end
	local species = Config.LuckyPick(drops, m, rng) or info.Species
	local mutation = egg.Mutation or "Normal"
	local upgraded = false
	if m >= Config.HatchRoll.MutationFrom then
		local up = nextMutation(mutation)
		upgraded = up ~= mutation
		mutation = up
	end
	local pet = {Id = Data.Guid(), Species = species, Scale = Config.AssetScale(egg.Scale), Mutation = mutation}
	if m >= Config.HatchRoll.ChimeraFrom then
		-- too lucky for anything in this egg: a one-of-a-kind pet stitched out of three
		local partners = chimeraPartners(species)
		if #partners >= 1 then
			local parts = {species, partners[1], partners[2]}
			local base = (Config.Pets[species] and Config.Pets[species].Income or 1)
			pet = {Id = pet.Id, Species = "Chimera", Parts = parts, Name = Config.ChimeraName(species, partners[1]),
				Income = math.max(1, math.floor(base * Config.ChimeraBonus(m) + 0.5)), Scale = pet.Scale, Mutation = mutation}
		end
	end
	if m >= 10 then pet.Multiplier = m end
	return pet, upgraded
end

function Bases.Hatch(profile, eggId)
	if type(eggId) ~= "string" or profile.Planet ~= "Base" then return end
	if #profile.Data.Pets >= Config.MaxPets then ctx.notice(profile, "Your pet collection is full."); return end
	local index
	for i, egg in ipairs(profile.Data.GrowingEggs) do if egg.Id == eggId then index = i; break end end
	if not index then return end
	local egg = profile.Data.GrowingEggs[index]
	local point, characterRoot = plantedPosition(profile, egg), ctx.root(profile.Player)
	if not point or not characterRoot or (characterRoot.Position - point).Magnitude > Config.PickupDistance * (Config.PromptReach or 1) + Bases.EggRadius(egg) then
		ctx.notice(profile, "Walk up to your egg to hatch it."); return
	end
	if os.time() < egg.ReadyAt then ctx.notice(profile, "This egg is still growing."); return end
	-- the multiplier is rolled here (the client only plays it back): the pet is decided and saved at once
	local m = Config.RollMultiplier(rng)
	local pet, upgraded = Bases.RollPet(egg, m)
	table.remove(profile.Data.GrowingEggs, index)
	table.insert(profile.Data.Pets, pet)
	profile.Data.DiscoveredPets[pet.Species] = true
	profile.Data.Stats.EggsHatched += 1
	profile.Data.TutorialStep = math.max(profile.Data.TutorialStep, 7)
	local info = Config.PetInfo(pet)
	-- the multiplier climbs on the owner's screen for T seconds; the egg stays in the pen until it stops
	local a = rng:NextNumber(Config.HatchRoll.Curve[1], Config.HatchRoll.Curve[2])
	local duration = m <= 1 and 0 or Config.HatchTime(a, m)
	profile.HatchingVisual = profile.HatchingVisual or {}
	profile.HatchingVisual[egg.Id] = true
	ctx.effect(profile.Player, "HatchRoll", {M = m, A = a, T = duration, PetId = pet.Id, Species = pet.Species, Name = info.Name,
		Rarity = info.Rarity, Income = Config.PetIncome(info, pet.Scale, pet.Mutation), Parts = pet.Parts, EggId = egg.EggId,
		Mutation = pet.Mutation, Scale = pet.Scale, Upgraded = upgraded, Chimera = pet.Species == "Chimera" and not pet.Rarity,
		Hybrid = pet.Rarity ~= nil and pet.Species == "Chimera"})
	ctx.markDirty(profile)
	task.delay(duration + 1.4, function()
		if not online(profile) then return end
		if profile.HatchingVisual then profile.HatchingVisual[egg.Id] = nil end
		Bases.RenderGarden(profile); Bases.RenderGrowing(profile)
		ctx.remotes.EggHatched:FireAllClients({OwnerUserId = profile.Player.UserId, BaseIndex = profile.BaseIndex, PetId = pet.Id,
			Species = pet.Species, Parts = pet.Parts, EggId = egg.EggId, Position = point, Scale = pet.Scale, Mutation = pet.Mutation,
			HatchingId = egg.Id, Rolled = true, Multiplier = m, Name = info.Name})
		Bases.RefreshBaseInfo(profile)
		if m >= Config.HatchRoll.Announce then
			local text = profile.Player.DisplayName .. " hit " .. Config.FormatMultiplier(m) .. " and hatched " .. info.Name .. "!"
			for _, other in ipairs(game:GetService("Players"):GetPlayers()) do
				ctx.remotes.Notice:FireClient(other, text, pet.Species == "Chimera" and "Pink" or "Gold")
			end
		end
	end)
end

-- ---------------------------------------------------------------- shields
function Bases.ActivateShield(profile, seconds, extend)
	local now = workspace:GetServerTimeNow()
	local current = math.max(now, profile.ShieldUntil or 0)
	profile.ShieldUntil = extend and current + seconds or math.max(current, now + seconds)
	local zone = zones[profile.Base]
	if zone then
		-- push visitors out before the wall becomes solid
		for _, other in pairs(ctx.profiles) do
			if other ~= profile then
				local r = ctx.root(other.Player)
				if r and inside(zone, r.Position, 1) then Bases.Eject(other, profile.Base) end
			end
		end
	end
	Bases.RefreshBaseInfo(profile)
	ctx.markDirty(profile)
end
function Bases.Eject(profile, base)
	local zone = zones[base]
	local character = profile.Player.Character
	if zone and character then
		-- out through the gate side, towards the middle of the island
		local centre = zone.CFrame.Position
		local inward = Vector3.new(-centre.X, 0, -centre.Z)
		inward = inward.Magnitude > 0.1 and inward.Unit or Vector3.new(0, 0, 1)
		character:PivotTo(CFrame.new(centre + inward * (math.max(zone.HalfX, zone.HalfZ) + 8) + Vector3.new(0, 4, 0)))
	end
end
local function updateShieldWall(base, profile)
	local zone = zones[base]
	if not zone or not zone.Shield then return end
	local active = profile ~= nil and shielded(profile)
	zone.Shield.CanCollide = active
	zone.Shield.Transparency = active and 0.55 or 1
end

-- ---------------------------------------------------------------- stealing
local function markThief(thief, egg)
	thief.Sprinting = false
	ctx.Expeditions.ShowCarry(thief, egg)
	ctx.setMovement(thief)
	local character = thief.Player.Character
	if character and not character:FindFirstChild("ThiefHighlight") then
		local highlight = Instance.new("Highlight")
		highlight.Name = "ThiefHighlight"; highlight.FillColor = Color3.fromRGB(255, 60, 90); highlight.OutlineColor = Color3.fromRGB(255, 220, 90)
		highlight.FillTransparency = 0.75; highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = character
	end
end

function Bases.TrySteal(thief, owner, eggId)
	if thief.Planet ~= "Base" or thief.Busy or thief.Stolen or not ctx.root(thief.Player) then return end
	if owner == thief or owner.Planet == nil or not online(owner) then return end
	if shielded(owner) then ctx.notice(thief, "That base is shielded!", "Red"); return end
	if Bases.IsProtected(owner) then ctx.notice(thief, "New players are protected for their first " .. Config.NoviceProtectionPets .. " pets.", "Red"); return end
	local index
	for i, egg in ipairs(owner.Data.GrowingEggs) do if egg.Id == eggId then index = i; break end end
	if not index then return end
	local egg = owner.Data.GrowingEggs[index]
	local point = plantedPosition(owner, egg)
	local r = ctx.root(thief.Player)
	if not point or (r.Position - point).Magnitude > 12 + Bases.EggRadius(egg) then return end
	table.remove(owner.Data.GrowingEggs, index)
	thief.Stolen = {Egg = egg, FromProfile = owner, FromName = owner.Player.DisplayName, StartedAt = os.clock()}
	markThief(thief, egg)
	Bases.RenderGrowing(owner)
	ctx.notice(thief, "Run to your pen before " .. owner.Player.DisplayName .. " catches you!", "Orange")
	ctx.notice(owner, thief.Player.DisplayName .. " stole your " .. Config.EggDisplayName(egg) .. "! Catch them!", "Red")
	ctx.effect(owner.Player, "Alarm", {Thief = thief.Player.UserId})
	ctx.publishTracker(thief)
	ctx.markDirty(thief); ctx.markDirty(owner)
	-- (v35) a bot whose pen was robbed goes after the thief
	if ctx.Bots and ctx.Bots.OnRobbed then task.spawn(ctx.Bots.OnRobbed, owner, thief) end
end

local function clearThief(thief)
	thief.Stolen = nil
	ctx.Expeditions.ClearCarry(thief)
	local character = thief.Player.Character
	local highlight = character and character:FindFirstChild("ThiefHighlight")
	if highlight then highlight:Destroy() end
	ctx.setMovement(thief)
	ctx.publishTracker(thief)
	ctx.markDirty(thief)
end

local function returnEgg(owner, egg)
	if not owner then return end
	local free = true
	for _, other in ipairs(owner.Data.GrowingEggs) do
		if Vector2.new(egg.LocalPosition[1] - other.LocalPosition[1], egg.LocalPosition[3] - other.LocalPosition[3]).Magnitude < Config.PlantMinSpacing then free = false; break end
	end
	if free and #owner.Data.GrowingEggs < Config.MaxGrowingEggs then
		table.insert(owner.Data.GrowingEggs, egg)
	else
		table.insert(owner.Data.Eggs, {Id = egg.Id, EggId = egg.EggId, Scale = egg.Scale, Mutation = egg.Mutation})
	end
	if owner.Base and online(owner) then Bases.RenderGrowing(owner) end
	ctx.markDirty(owner)
end

function Bases.CancelSteal(thief, reason)
	local stolen = thief.Stolen
	if not stolen then return end
	clearThief(thief)
	local owner = stolen.FromProfile
	if owner and online(owner) then
		returnEgg(owner, stolen.Egg)
		ctx.notice(owner, "Your " .. Config.EggDisplayName(stolen.Egg) .. " is back!", "Green")
	end
	ctx.notice(thief, "The stolen egg flew back home" .. (reason and (" (" .. reason .. ")") or "") .. ".", "Red")
end

-- a bat hit on a thief (Egg Arena rules): the owner knocks the egg back into the pen; anyone else
-- takes it out of the thief's hands and now has to run it to their own pen, and the owner can still
-- catch them, and someone else can hit them in turn...
function Bases.TransferSteal(thief, hitter)
	local stolen = thief.Stolen
	if not stolen then return false end
	local owner = stolen.FromProfile
	if hitter == owner then
		Bases.CancelSteal(thief, "knocked back by " .. hitter.Player.DisplayName)
		ctx.notice(hitter, "You knocked your egg back into the pen!", "Gold")
		return true
	end
	if hitter.Planet ~= "Base" or hitter.Busy or hitter.Stolen or hitter.Expedition or not hitter.Base or not ctx.root(hitter.Player) then
		Bases.CancelSteal(thief, "bat")
		return true
	end
	clearThief(thief)
	hitter.Stolen = {Egg = stolen.Egg, FromProfile = owner, FromName = stolen.FromName, StartedAt = os.clock()}
	markThief(hitter, stolen.Egg)
	local name = Config.EggDisplayName(stolen.Egg)
	ctx.notice(hitter, "You snatched " .. name .. "! Run to your pen!", "Orange")
	ctx.notice(thief, hitter.Player.DisplayName .. " knocked the egg out of your hands!", "Red")
	if owner and online(owner) then
		ctx.notice(owner, hitter.Player.DisplayName .. " grabbed your " .. name .. "! Catch them!", "Red")
		ctx.effect(owner.Player, "Alarm", {Thief = hitter.Player.UserId})
	end
	ctx.publishTracker(hitter)
	ctx.markDirty(hitter); ctx.markDirty(thief)
	return true
end

local function deliver(thief)
	local stolen = thief.Stolen
	if #thief.Data.Eggs >= Config.MaxStoredEggs then Bases.CancelSteal(thief, "your storage is full"); return end
	clearThief(thief)
	local egg = stolen.Egg
	table.insert(thief.Data.Eggs, {Id = Data.Guid(), EggId = egg.EggId, Scale = egg.Scale, Mutation = egg.Mutation})
	thief.Data.DiscoveredEggs[egg.EggId] = true
	thief.Data.Stats.EggsStolen += 1
	ctx.notice(thief, Config.EggDisplayName(egg) .. " is yours!", "Gold")
	ctx.effect(thief.Player, "StealSuccess", {EggId = egg.EggId})
	local owner = stolen.FromProfile
	if owner and online(owner) then
		ctx.notice(owner, thief.Player.DisplayName .. " got away with your " .. Config.EggDisplayName(egg) .. ".", "Red")
		owner.Data.Stats.EggsLost += 1
	end
end

-- the owner gets an egg back by running into the thief
local function tryCatch(thief)
	local stolen = thief.Stolen
	local owner = stolen and stolen.FromProfile
	if not owner or not online(owner) or owner.Planet ~= "Base" or owner.Busy then return false end
	local a, b = ctx.root(thief.Player), ctx.root(owner.Player)
	if not a or not b or (a.Position - b.Position).Magnitude > Config.CatchRange then return false end
	Bases.CancelSteal(thief, "caught by " .. owner.Player.DisplayName)
	ctx.effect(owner.Player, "Caught", {Thief = thief.Player.UserId})
	ctx.remotes.Effect:FireAllClients("Catch", {From = owner.Player.UserId, To = thief.Player.UserId})
	return true
end

-- ---------------------------------------------------------------- (v35) bots keep their pens like players
-- a free spot in this pen for `egg` (on the planting grid, spaced like PlantEgg wants it), nearest to `near`, in world space
function Bases.FreePlantSpot(profile, egg, near)
	local cf, size = Bases.PlantArea(profile)
	if not cf then return nil end
	local step = Config.PlantGridSize
	local margin = 2.5
	local mine = math.min(Bases.EggRadius(egg), Config.PlantRadiusCap)
	local hx, hz = size.X / 2 - margin, size.Z / 2 - margin
	local nearLocal = near and cf:PointToObjectSpace(near) or Vector3.zero
	local best, bestScore
	for x = -math.floor(hx / step) * step, hx, step do
		for z = -math.floor(hz / step) * step, hz, step do
			local ok = true
			for _, other in ipairs(profile.Data.GrowingEggs) do
				local gap = math.max(Config.PlantMinSpacing, mine + math.min(Bases.EggRadius(other), Config.PlantRadiusCap)) + 0.5
				if Vector2.new(x - other.LocalPosition[1], z - other.LocalPosition[3]).Magnitude < gap then ok = false; break end
			end
			if ok then
				local score = Vector2.new(x - nearLocal.X, z - nearLocal.Z).Magnitude + rng:NextNumber(0, 14)
				if not bestScore or score < bestScore then best, bestScore = Vector3.new(x, 0, z), score end
			end
		end
	end
	return best and cf:PointToWorldSpace(best) or nil
end
-- an egg that has been growing for a while already (a bot that joins has a pen going, like a returning player)
function Bases.SeedGrowing(profile, egg, progress)
	local info = Config.Eggs[egg.EggId]
	local cf = Bases.PlantArea(profile)
	local spot = info and cf and Bases.FreePlantSpot(profile, egg, nil)
	if not spot then return false end
	local localPoint = cf:PointToObjectSpace(spot)
	egg.LocalPosition = {localPoint.X, 0, localPoint.Z}
	egg.GrowthDuration = Config.EggGrowthDuration(info, egg.Scale)
	egg.PlacedAt = os.time() - math.floor(egg.GrowthDuration * math.clamp(progress or 0.5, 0, 1))
	egg.ReadyAt = egg.PlacedAt + egg.GrowthDuration
	table.insert(profile.Data.GrowingEggs, egg)
	return true
end
function Bases.SetupBotBase(profile)
	local base = profile.Base
	base:SetAttribute("OwnerUserId", profile.Player.UserId)
	base:SetAttribute("OwnerName", profile.Player.DisplayName)
	base:SetAttribute("RocketLevel", profile.Data.RocketLevel)
	base:SetAttribute("ShieldUntil", 0)
	Bases.RenderGarden(profile); Bases.RenderGrowing(profile)
	Bases.RefreshBaseInfo(profile)
end

-- ---------------------------------------------------------------- lifecycle
function Bases.SetupBase(profile)
	local base = profile.Base
	base:SetAttribute("OwnerUserId", profile.Player.UserId)
	base:SetAttribute("OwnerName", profile.Player.DisplayName)
	base:SetAttribute("RocketLevel", profile.Data.RocketLevel)
	profile.Player:SetAttribute("PFESuitLevel", profile.Data.SuitLevel)
	bound[profile.Player] = {Group = ownerGroup(zones[base] and zones[base].Index or 1), Previous = {}}
	profile.Player.CharacterAdded:Connect(function(character) bindCharacter(profile.Player, character) end)
	if profile.Player.Character then bindCharacter(profile.Player, profile.Player.Character) end
	Bases.RenderGarden(profile); Bases.RenderGrowing(profile)
	Bases.RefreshBaseInfo(profile)
end
function Bases.ClearBase(profile)
	local base = profile.Base
	if not base then return end
	base:SetAttribute("OwnerUserId", 0); base:SetAttribute("OwnerName", "")
	base:SetAttribute("RocketLevel", 1); base:SetAttribute("ShieldUntil", 0)
	base:SetAttribute("Protected", false)
	for _, name in ipairs({"ActivePets", "GrowingEggs"}) do local f = base:FindFirstChild(name); if f then f:Destroy() end end
	profile.ShieldUntil = 0
	updateShieldWall(base, nil)
	local sign = base:FindFirstChild("SignAnchor")
	setBoard(sign and sign:FindFirstChild("OwnerSign"), "Free Base", Color3.fromRGB(200, 204, 220))
	local record = bound[profile.Player]
	if record and record.Connection then record.Connection:Disconnect() end
	bound[profile.Player] = nil
end
function Bases.OnCharacterReset(profile)
	if profile.Stolen then Bases.CancelSteal(profile, "respawned") end
	if profile.Player.Character then bindCharacter(profile.Player, profile.Player.Character) end
end
function Bases.OnDied(profile)
	if profile.Stolen then Bases.CancelSteal(profile, "knocked out") end
end
function Bases.OnPlayerLeaving(profile)
	if profile.Stolen then Bases.CancelSteal(profile, "left the game") end
	-- anyone carrying this player's eggs must give them back before we save
	local carriers = {}
	for _, other in pairs(ctx.profiles) do table.insert(carriers, other) end
	if ctx.Bots and ctx.Bots.Profiles then for _, other in ipairs(ctx.Bots.Profiles()) do table.insert(carriers, other) end end
	for _, other in ipairs(carriers) do
		if other.Stolen and other.Stolen.FromProfile == profile then
			local egg = other.Stolen.Egg
			clearThief(other)
			ctx.notice(other, "The egg's owner left - it vanished from your hands.", "Red")
			table.insert(profile.Data.GrowingEggs, egg)
		end
	end
end

function Bases.Tick(profile, dt)
	local base = profile.Base
	if not base then return end
	-- income goes straight to the wallet
	local _, income = ctx.petList(profile)
	if income > 0 then
		profile.Data.Coins = math.min(1e15, profile.Data.Coins + income * dt)
	end
	local r = ctx.root(profile.Player)
	-- thief: caught by the owner, delivered home, or too slow
	if profile.Stolen and not tryCatch(profile) then
		local zone = zones[base]
		if r and zone and inside(zone, r.Position, 2) then deliver(profile)
		elseif os.clock() - profile.Stolen.StartedAt > Config.StealTimeout then Bases.CancelSteal(profile, "too slow") end
	end
	-- shield wall + intruders
	updateShieldWall(base, profile)
	if shielded(profile) then
		local zone = zones[base]
		for _, other in pairs(ctx.profiles) do
			if other ~= profile then
				local o = ctx.root(other.Player)
				if o and zone and inside(zone, o.Position, 0.5) then Bases.Eject(other, base) end
			end
		end
	end
	Bases.UpdateGrowing(profile)
	Bases.RefreshBaseInfo(profile)
end

function Bases.Init(context)
	ctx = context
	Config, Data, ModelUtil = ctx.Config, ctx.Data, ctx.ModelUtil
	ctx.Bases = Bases
	local ordered = {}
	for _, base in ipairs(ctx.bases:GetChildren()) do
		local index = tonumber(base.Name:match("^Base(%d+)$"))
		if index and base:FindFirstChild("PlantArea") then table.insert(ordered, {Base = base, Index = index}) end
	end
	for _, entry in ipairs(ordered) do
		for _, name in ipairs({ownerGroup(entry.Index), shieldGroup(entry.Index)}) do
			if not PhysicsService:IsCollisionGroupRegistered(name) then PhysicsService:RegisterCollisionGroup(name) end
		end
	end
	for _, entry in ipairs(ordered) do
		local group = shieldGroup(entry.Index)
		for _, registered in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
			PhysicsService:CollisionGroupSetCollidable(group, registered.name, false)
		end
		for _, visitor in ipairs(ordered) do
			PhysicsService:CollisionGroupSetCollidable(group, ownerGroup(visitor.Index), visitor.Index ~= entry.Index)
		end
	end
	for _, entry in ipairs(ordered) do
		local base = entry.Base
		local area = base.PlantArea
		local shield = base:FindFirstChild("ShieldWall")
		if shield then shield.CollisionGroup = shieldGroup(entry.Index); shield.CanCollide = false; shield.Transparency = 1 end
		zones[base] = {CFrame = area.CFrame, HalfX = area.Size.X / 2 + 2, HalfZ = area.Size.Z / 2 + 2, Index = entry.Index, Shield = shield}
		local old = base:FindFirstChild("PrivatePenBoundary"); if old then old:Destroy() end
		local sign = base:FindFirstChild("SignAnchor")
		if sign then setBoard(billboard(sign, "OwnerSign", UDim2.new(0, 360, 0, 64), Vector3.new(0, 2, 0)), "Free Base", Color3.fromRGB(200, 204, 220)) end
	end
end

return Bases
