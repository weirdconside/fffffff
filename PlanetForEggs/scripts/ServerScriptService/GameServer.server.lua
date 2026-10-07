--!nocheck
-- Planet for Eggs server. Economy, expeditions, bases, stealing and purchases are all
-- server-owned; clients only request actions and render.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
Players.CharacterAutoLoads = false -- characters spawn at their own base
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local network = ReplicatedStorage:WaitForChild("PFE")
local Config = require(network:WaitForChild("Config"))
local PlanetGen = require(network:WaitForChild("PlanetGen"))
local ModelUtil = require(network:WaitForChild("ModelUtil"))
local Data = require(script:WaitForChild("Data"))
local Shop = require(script:WaitForChild("Shop"))
local Expeditions = require(script:WaitForChild("Expeditions"))
local Bases = require(script:WaitForChild("Bases"))
local Gear = require(script:WaitForChild("Gear"))
local Events = require(script:WaitForChild("Events"))
local Minigame = require(script:WaitForChild("Minigame"))
local Aliens = require(script:WaitForChild("Aliens"))
local Dungeons = require(script:WaitForChild("Dungeons"))
local Admin = require(script:WaitForChild("Admin"))
local Fusion = require(script:WaitForChild("Fusion"))
local Limited = require(script:WaitForChild("Limited"))
local Rewards = require(script:WaitForChild("Rewards"))
local Speed = require(script:WaitForChild("Speed"))
local Bots = require(script:WaitForChild("Bots"))
local PlanetLife = require(script:WaitForChild("PlanetLife"))   -- (v41) weather, breakables, bosses, the Golden Egg
local Caves = require(script:WaitForChild("Caves"))             -- (v41) the caves under every planet
local PetModels = require(network:WaitForChild("PetModels"))
local SkyPaths = require(network:WaitForChild("SkyPaths"))

local function remote(name, class)
	local object = network:FindFirstChild(name)
	if not object then
		object = Instance.new(class or "RemoteEvent")
		object.Name = name
		object.Parent = network
	end
	return object
end

local world = workspace:WaitForChild("PlanetForEggs")
local assets = ServerStorage:FindFirstChild("PFEAssets")
local uiAssets = network:WaitForChild("UIAssets")
local devMode = RunService:IsStudio() and Config.DevShowcase == true

local ctx = {
	Config = Config, Data = Data, Shop = Shop, PlanetGen = PlanetGen, ModelUtil = ModelUtil, SkyPaths = SkyPaths, network = network,
	profiles = {}, devMode = devMode, world = world, bases = world:WaitForChild("Bases"),
	planets = world:WaitForChild("Planets"),
	remotes = {
		Action = remote("Action"), State = remote("State"), Notice = remote("Notice"), Flight = remote("Flight"),
		OpenMenu = remote("OpenMenu"), Sprint = remote("Sprint"), EggHatched = remote("EggHatched"),
		Effect = remote("Effect"), PlanetLayout = remote("PlanetLayout", "RemoteFunction"), PlanetChunks = remote("PlanetChunks", "RemoteFunction"),
		Jet = remote("Jet"), Bat = remote("Bat"), Minigame = remote("Minigame"), MinigameGrab = remote("MinigameGrab"), MinigameJoin = remote("MinigameJoin"),
		Raygun = remote("Raygun"), Smash = remote("Smash"),
	},
}
local profiles = ctx.profiles
local closing = false

-- ---------------------------------------------------------------- map cycle
-- Every Config.MapCycle seconds all planets get a new seed: forests, regions, landmarks and eggs
-- are laid out anew. Clients read the seed and the next reset time from workspace attributes.
local mapSeed = Random.new():NextInteger(1, 999999)
local nextMapReset = workspace:GetServerTimeNow() + Config.MapCycle
function ctx.mapSeed() return mapSeed end
local function publishMapCycle()
	workspace:SetAttribute("PFEMapSeed", mapSeed)
	workspace:SetAttribute("PFEMapResetAt", nextMapReset)
end
publishMapCycle()

local pickups = workspace:FindFirstChild("PFE_Pickups") or Instance.new("Folder")
pickups.Name = "PFE_Pickups"; pickups.Parent = workspace
ctx.pickups = pickups

-- ---------------------------------------------------------------- templates
local EggForge = require(ReplicatedStorage:WaitForChild("PFE"):WaitForChild("EggForge"))
function ctx.eggTemplate(eggId)
	if EggForge.IsGen(eggId) then return EggForge.Template(eggId) end
	local eggs = assets and assets:FindFirstChild("Eggs")
	return uiAssets.Eggs:FindFirstChild(eggId) or (eggs and eggs:FindFirstChild(eggId))
end
-- (v28) a pet record (or a species): Chimeras are stitched together out of their parts' models (PetModels)
function ctx.petTemplate(species, record)
	if species == "Chimera" or (type(record) == "table" and record.Species == "Chimera") then
		return PetModels.Template(record)
	end
	local pets = assets and assets:FindFirstChild("Pets")
	return uiAssets.Pets:FindFirstChild(species) or (pets and pets:FindFirstChild(species))
end

-- ---------------------------------------------------------------- helpers
function ctx.root(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") or nil
end
function ctx.humanoid(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end
function ctx.partOf(object)
	if not object then return nil end
	if object:IsA("BasePart") then return object end
	if object:IsA("Model") and object.PrimaryPart then return object.PrimaryPart end
	return object:FindFirstChildWhichIsA("BasePart", true)
end
function ctx.near(profile, object, distance)
	local characterRoot, part = ctx.root(profile.Player), ctx.partOf(object)
	return characterRoot ~= nil and part ~= nil and (characterRoot.Position - part.Position).Magnitude <= (distance or Config.InteractionDistance) * (Config.PromptReach or 1)
end
function ctx.notice(profile, message, color)
	if profile.Player.Parent then ctx.remotes.Notice:FireClient(profile.Player, message, color) end
end
function ctx.markDirty(profile)
	profile.Dirty = true
end
function ctx.effect(player, kind, payload)
	if player and player.Parent then ctx.remotes.Effect:FireClient(player, kind, payload) end
end
function ctx.hasPass(profile, key)
	return Shop.Has(profile, key)
end
function ctx.eventActive(id)
	return ctx.Events ~= nil and ctx.Events.Active(id)
end
function ctx.luck(profile)
	local luck = 1
	if Shop.Has(profile, "Lucky") then luck *= 2 end
	if (profile.Data.LuckUntil or 0) > os.time() then luck *= 2 end
	if ctx.eventActive("Starfall") then luck *= 2 end
	-- admin abuse: luck for everyone for a while
	if (workspace:GetAttribute("PFEAdminLuckUntil") or 0) > os.time() then luck *= workspace:GetAttribute("PFEAdminLuck") or 2 end
	return luck
end
function ctx.maxOxygen(profile)
	local base = Config.Suits[profile.Data.SuitLevel].Oxygen
	if Shop.Has(profile, "SuperSuit") then base = math.floor(base * 1.6) end
	if Shop.Has(profile, "VIP") then base = math.floor(base * Config.VipOxygen) end
	return base
end
function ctx.capacity(profile)
	return Config.Cargo[profile.Data.CargoLevel].Capacity + (Shop.Has(profile, "BigCargo") and 2 or 0)
end
-- (v28) the speed trained on the treadmill (Speed Power) sets the walk speed
function ctx.walkSpeed(profile)
	if profile.AdminWalkSpeed then return profile.AdminWalkSpeed end -- (;speed)
	return Config.WalkSpeedFor(profile.Data.SpeedPower) * (Shop.Has(profile, "SpeedBoots") and 1.15 or 1)
end
function ctx.setMovement(profile)
	local humanoid = ctx.humanoid(profile.Player)
	if not humanoid then return end
	local speed = ctx.walkSpeed(profile)
	profile.SpeedApplied = speed
	profile.Player:SetAttribute("PFEWalkSpeed", math.floor(speed * 10 + 0.5) / 10)
	if profile.Stolen then
		speed = Config.StealWalkSpeed
	elseif profile.Sprinting and not profile.Busy then
		speed = Config.SprintSpeed(speed)
	end
	-- (v41) the weather (a blizzard, a heatwave) slows you down away from shelter (PlanetLife)
	if not profile.Stolen then speed *= profile.WeatherSpeed or 1 end
	humanoid.WalkSpeed = speed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = profile.AdminJump or (Shop.Has(profile, "SpeedBoots") and 58 or 48)
end
function ctx.setSprint(profile, enabled)
	-- (v29: there is no sprint any more)
	profile.Sprinting = false
end
function ctx.petList(profile)
	local list = {}
	for _, item in ipairs(profile.Data.Pets) do
		local info = Config.PetInfo(item)
		if info then
			table.insert(list, {Id = item.Id, Species = item.Species, Name = info.Name, Rarity = info.Rarity,
				Scale = Config.AssetScale(item.Scale), Mutation = item.Mutation or "Normal",
				Income = Config.PetIncome(info, item.Scale, item.Mutation),
				Parts = item.Parts, Multiplier = item.Multiplier})   -- (a Chimera's pets / the multiplier that made it)
		end
	end
	table.sort(list, function(a, b) if a.Income == b.Income then return a.Id < b.Id end return a.Income > b.Income end)
	local income = 0
	for index, item in ipairs(list) do
		item.Equipped = index <= Config.MaxActivePets
		if item.Equipped then income += item.Income end
	end
	local multiplier = 1
	if Shop.Has(profile, "DoubleMoney") then multiplier *= 2 end
	if Shop.Has(profile, "VIP") then multiplier *= Config.VipIncome end
	if (workspace:GetAttribute("PFEAdminCoinsUntil") or 0) > os.time() then multiplier *= workspace:GetAttribute("PFEAdminCoins") or 2 end
	return list, math.floor(income * multiplier)
end
local LABEL_FONT = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
function ctx.label(parent, title, subtitle, color, height)
	local anchor = ctx.partOf(parent)
	if not anchor then return end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PFELabel"; gui.Size = UDim2.fromOffset(200, 56); gui.StudsOffsetWorldSpace = Vector3.new(0, height or 4.5, 0)
	gui.AlwaysOnTop = false; gui.MaxDistance = 70; gui.LightInfluence = 0; gui.Adornee = anchor; gui.Parent = parent
	local text = Instance.new("TextLabel")
	text.Name = "Title"; text.BackgroundTransparency = 1; text.Size = UDim2.fromScale(1, 0.6); text.FontFace = LABEL_FONT
	text.Text = title; text.TextScaled = true; text.TextColor3 = color or Color3.new(1, 1, 1); text.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5; stroke.Color = Color3.fromRGB(14, 12, 28); stroke.LineJoinMode = Enum.LineJoinMode.Round; stroke.Parent = text
	local sub = text:Clone(); sub.Name = "Subtitle"; sub.Text = subtitle or ""; sub.Size = UDim2.fromScale(1, 0.4)
	sub.Position = UDim2.fromScale(0, 0.6); sub.TextColor3 = Color3.fromRGB(235, 235, 245); sub.Parent = gui
	return gui
end
function ctx.makePrompt(parent, name, text, handler, opts)
	local part = ctx.partOf(parent)
	if not part then return end
	opts = opts or {}
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name; prompt.ActionText = text; prompt.ObjectText = opts.ObjectText or ""
	prompt.HoldDuration = opts.Hold or 0.35
	-- every prompt pops up within Config.PromptDistance of the character (about two R6 players lying head to toe);
	-- only very big things (grown giant eggs, eggs on moving sky islands) ask for more
	prompt.MaxActivationDistance = math.max(Config.PromptDistance, (opts.Distance or 0) > 16 and opts.Distance or 0)
	prompt.RequiresLineOfSight = false; prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = opts.Key or Enum.KeyCode.E
	prompt.Enabled = true; prompt.Parent = part
	if handler then prompt.Triggered:Connect(handler) end
	return prompt
end
function ctx.teleport(profile, target, offset)
	local character = profile.Player.Character
	local part = ctx.partOf(target)
	if character and part then character:PivotTo(part.CFrame + (offset or Vector3.new(0, 5, 0))) end
end

-- ---------------------------------------------------------------- state
local function trackerPlanetName(name) return name == "Base" and "Earth" or name end
local function publishTracker(profile)
	local target = profile.Player
	if not target.Parent then return end
	target:SetAttribute("PFETrackerPlanet", trackerPlanetName(profile.Planet))
	if profile.Busy and profile.FlightDestination then
		target:SetAttribute("PFETrackerFlightFrom", trackerPlanetName(profile.FlightFrom or profile.Planet))
		target:SetAttribute("PFETrackerFlightTo", trackerPlanetName(profile.FlightDestination))
		target:SetAttribute("PFETrackerFlightStartedAt", (profile.FlightStartedAt or 0) + 3.2)
		target:SetAttribute("PFETrackerFlightDuration", math.max(0.1, (profile.FlightDuration or Config.FlightDuration) - 3.2))
	else
		target:SetAttribute("PFETrackerFlightFrom", "")
		target:SetAttribute("PFETrackerFlightTo", "")
		target:SetAttribute("PFETrackerFlightStartedAt", 0)
		target:SetAttribute("PFETrackerFlightDuration", 0)
	end
	target:SetAttribute("PFEStealing", profile.Stolen ~= nil)
end
ctx.publishTracker = publishTracker

local function passesTable(profile)
	local out = {}
	for _, pass in ipairs(Config.GamePassList) do if Shop.Has(profile, pass.Key) then out[pass.Key] = true end end
	return out
end

local function lightState(profile)
	local _, income = ctx.petList(profile)
	local expedition = profile.Expedition
	return {
		Light = true, Coins = math.floor(profile.Data.Coins), Income = income,
		Oxygen = math.max(0, math.ceil(profile.Oxygen)), MaxOxygen = ctx.maxOxygen(profile), Planet = profile.Planet,
		Busy = profile.Busy, ShieldUntil = profile.ShieldUntil or 0, ServerTime = workspace:GetServerTimeNow(),
		LuckLeft = math.max(0, (profile.Data.LuckUntil or 0) - os.time()),
		SpeedPower = math.floor(profile.Data.SpeedPower or 0), WalkSpeed = ctx.walkSpeed(profile), OnTreadmill = profile.OnTreadmill == true,
		TreadmillGain = Speed.Gain(profile),
		CarryingEgg = expedition and expedition.CarryingEgg and Data.Copy(expedition.CarryingEgg) or nil,
		Stolen = profile.Stolen and {EggId = profile.Stolen.Egg.EggId, From = profile.Stolen.FromName} or nil,
	}
end

-- what an admin's HUD shows while spectating this player (Admin "view"): the light state plus passes,
-- cargo and the run, and who it is
function ctx.spectateState(profile)
	local state = lightState(profile)
	state.Light = nil
	state.Passes = passesTable(profile)
	state.TempPasses = {}
	for key, untilTime in pairs(profile.Data.TempPasses or {}) do
		if untilTime > os.time() then state.TempPasses[key] = untilTime end
	end
	state.Capacity = ctx.capacity(profile)
	state.Minigame = profile.Minigame and {Planet = profile.Minigame.Planet, EndsAt = profile.Minigame.EndsAt} or nil
	state.Expedition = profile.Expedition and {Planet = profile.Expedition.Planet, Eggs = Data.Copy(profile.Expedition.Eggs)} or nil
	state.EggCount = #profile.Data.Eggs
	state.Name = profile.Player.DisplayName; state.UserId = profile.Player.UserId
	return state
end

function ctx.sendState(profile)
	if not profile.Player.Parent then return end
	profile.Dirty = false
	publishTracker(profile)
	local pets, income = ctx.petList(profile)
	local expedition = profile.Expedition
	local areaCF, areaSize = Bases.PlantArea(profile)
	local state = lightState(profile)
	state.Light = nil
	state.Passes = passesTable(profile)
	state.TempPasses = {}
	for key, untilTime in pairs(profile.Data.TempPasses or {}) do
		if untilTime > os.time() then state.TempPasses[key] = untilTime end
	end
	state.SuitLevel = profile.Data.SuitLevel; state.RocketLevel = profile.Data.RocketLevel; state.CargoLevel = profile.Data.CargoLevel
	state.JetpackLevel = profile.Data.JetpackLevel
	state.TreadmillLevel = profile.Data.TreadmillLevel
	state.Trails = Data.Copy(profile.Data.Trails); state.Trail = profile.Data.Trail
	state.Minigame = profile.Minigame and {Planet = profile.Minigame.Planet, EndsAt = profile.Minigame.EndsAt} or nil
	state.Capacity = ctx.capacity(profile)
	state.OxygenTanks = profile.Data.OxygenTanks
	state.Expedition = expedition and {Eggs = Data.Copy(expedition.Eggs),
		Planet = expedition.Planet} or nil
	state.EggCount = expedition and #expedition.Eggs or 0
	state.Eggs = Data.Copy(profile.Data.Eggs)
	state.GrowingEggs = Bases.GrowingState(profile)
	state.Pets = pets; state.Income = income
	state.PlantArea = areaCF and {CFrame = areaCF, Size = areaSize, GridSize = Config.PlantGridSize, MinSpacing = Config.PlantMinSpacing} or nil
	state.BaseIndex = profile.BaseIndex; state.SaveStatus = profile.SaveStatus; state.Sprinting = profile.Sprinting == true
	state.Result = profile.Result; state.TutorialStep = profile.Data.TutorialStep
	state.DiscoveredEggs = Data.Copy(profile.Data.DiscoveredEggs); state.DiscoveredPets = Data.Copy(profile.Data.DiscoveredPets)
	state.VisitedPlanets = Data.Copy(profile.Data.VisitedPlanets); state.Stats = Data.Copy(profile.Data.Stats)
	state.Protected = Bases.IsProtected(profile)
	state.FreeStage = profile.Data.FreeStage
	state.Codes = Data.Copy(profile.Data.Codes)
	state.Daily = Rewards.DailyState(profile)   -- (v38) the daily calendar
	state.DevMode = devMode; state.DevTravel = profile.DevTravel == true
	ctx.remotes.State:FireClient(profile.Player, state)
end
function ctx.sendLight(profile)
	if profile.Player.Parent then ctx.remotes.State:FireClient(profile.Player, lightState(profile)) end
end

-- ---------------------------------------------------------------- products & passes
function ctx.OnPassGranted(profile, key)
	if key == "SuperSuit" then
		profile.Player:SetAttribute("PFESuperSuit", true)
		if profile.Planet == "Base" then profile.Oxygen = ctx.maxOxygen(profile) end
	end
	if key == "VIP" then
		profile.Player:SetAttribute("PFEVIP", true)
		task.defer(function() pcall(Rewards.Daily, profile) end) -- (the daily present as soon as VIP is known)
	end
	ctx.setMovement(profile)
	Bases.RefreshBaseInfo(profile)
end
-- immortality (the product): a force field while it lasts (aliens can't hurt you), no air used;
-- kept across deaths and rejoins (Data.ImmortalUntil). Called every tick and on spawn.
function ctx.immortal(profile)
	return (profile.Data.ImmortalUntil or 0) > os.time()
end
function ctx.updateImmortal(profile)
	local on = ctx.immortal(profile)
	local player = profile.Player
	player:SetAttribute("PFEImmortalUntil", on and profile.Data.ImmortalUntil or nil)
	local character = player.Character
	if not character then return end
	local field = character:FindFirstChild("PFEImmortal")
	if on and not field then
		field = Instance.new("ForceField"); field.Name = "PFEImmortal"; field.Visible = true; field.Parent = character
	elseif not on and field then
		field:Destroy()
		ctx.notice(profile, "Immortality is over.", "Red")
	end
end
function ctx.GrantProduct(profile, product)
	local data = profile.Data
	if product.Kind == "Credits" then
		local _, income = ctx.petList(profile)
		local amount = math.max(product.Min or 1000, math.floor(income * 60 * (product.Minutes or 10)))
		data.Coins = math.min(1e15, data.Coins + amount)
		ctx.notice(profile, "+" .. Config.Format(amount) .. " coins!", "Gold")
		ctx.effect(profile.Player, "Coins", {Amount = amount})
	elseif product.Kind == "Shield" then
		Bases.ActivateShield(profile, product.Seconds or 900, true)
		ctx.notice(profile, "Base shielded for " .. math.floor((product.Seconds or 900) / 60) .. " min!", "Blue")
	elseif product.Kind == "InstantHatch" then
		local now = os.time()
		for _, egg in ipairs(data.GrowingEggs) do egg.ReadyAt = math.min(egg.ReadyAt, now) end
		Bases.UpdateGrowing(profile)
		ctx.notice(profile, "All eggs are ready!", "Gold")
	elseif product.Kind == "Luck" then
		data.LuckUntil = math.max(os.time(), data.LuckUntil or 0) + (product.Seconds or 1800)
		ctx.notice(profile, "Luck x2 active!", "Purple")
	elseif product.Kind == "Immortal" then
		-- stacks: bought while one runs, the time adds on
		data.ImmortalUntil = math.max(os.time(), data.ImmortalUntil or 0) + (product.Seconds or 300)
		ctx.updateImmortal(profile)
		ctx.notice(profile, "IMMORTAL for " .. math.floor((product.Seconds or 300) / 60) .. " min!", "Gold")
	elseif product.Kind == "SkipGrowth" then
		Bases.ApplySkip(profile, product.Seconds or 300)
	elseif product.Kind == "LimitedEgg" then
		-- a limited egg (v28: the Haunted Pumpkin Egg): into the backpack even when it is full, one more sold everywhere
		local left = Limited.Remaining(product.Key)
		Limited.Sell(product.Key)
		table.insert(data.Eggs, {Id = Data.Guid(), EggId = product.EggId, Scale = Expeditions.RollSize(), Mutation = "Normal"})
		data.DiscoveredEggs[product.EggId] = true
		ctx.notice(profile, (product.Icon or "🥚") .. " " .. product.Name .. " is yours! (" .. math.max(0, left - 1) .. " left in the world)", "Orange")
		ctx.effect(profile.Player, "LimitedEgg", {EggId = product.EggId, Name = product.Name})
		ctx.sendState(profile)
	elseif product.Kind == "Oxygen" then
		if profile.Expedition then
			profile.Oxygen = ctx.maxOxygen(profile); profile.WarnLow, profile.WarnCritical = false, false
			ctx.notice(profile, "Air refilled!", "Blue")
		else
			data.OxygenTanks += 1
			ctx.notice(profile, "Air tank stored!", "Blue")
		end
	end
	ctx.markDirty(profile)
end

Data.Init(Config)
Shop.Init(ctx)
Expeditions.Init(ctx)
Bases.Init(ctx)
Gear.Init(ctx)
Events.Init(ctx)
Minigame.Init(ctx)
Aliens.Init(ctx)
Dungeons.Init(ctx)
ctx.Minigame = Minigame
Admin.Init(ctx)
Fusion.Init(ctx)
Limited.Init(ctx)
ctx.Shop = ctx.Shop or Shop
Rewards.Init(ctx)
Speed.Init(ctx)
Bots.Init(ctx)
PlanetLife.Init(ctx)
Caves.Init(ctx)
ctx.Fusion = Fusion
ctx.Limited = Limited

function ctx.ResetMaps()
	mapSeed += 1
	nextMapReset = workspace:GetServerTimeNow() + Config.MapCycle
	publishMapCycle()
	local ok, err = pcall(Expeditions.ResetPools)
	if not ok then warn("[PFE] map reset failed", err) end
	-- (v41) the caves' eggs went with the planets' eggs: the chambers get new ones
	ok, err = pcall(Caves.OnMapReset)
	if not ok then warn("[PFE] cave reset failed", err) end
end
-- layouts generate a slice at a time (never one long stall), and the next cycle's planets are
-- prepared in the background shortly before the reset, so the reset itself costs nothing
do
	local sliceStart = os.clock()
	ctx.PlanetGen.Yield = function()
		if os.clock() - sliceStart > 0.006 then task.wait(); sliceStart = os.clock() end
	end
end
local preparedSeed = nil
task.spawn(function()
	while not closing do
		task.wait(0.5)
		local now = workspace:GetServerTimeNow()
		if now >= nextMapReset - 25 and preparedSeed ~= mapSeed + 1 then
			preparedSeed = mapSeed + 1
			local seed = preparedSeed
			task.spawn(function()
				-- (v28: only the planets someone is exploring - a 5x layout is ~45K pieces)
				local busy = {}
				for _, other in pairs(profiles) do if Config.Planets[other.Planet] then busy[other.Planet] = true end end
				for _, planet in ipairs(Config.PlanetOrder) do
					if mapSeed + 1 ~= seed then return end
					if busy[planet.Id] then pcall(ctx.PlanetGen.Generate, planet.Id, seed) end
				end
			end)
		end
		if now >= nextMapReset then ctx.ResetMaps() end
	end
end)

-- ---------------------------------------------------------------- remotes
local dispatch
dispatch = function(profile, action, argument)
	if action == "Sync" then ctx.sendState(profile); return end
	if devMode and action == "DevEvent" then
		Events.Start(type(argument) == "string" and Config.Events[argument] and argument or Config.EventList[1].Id); return
	elseif devMode and action == "DevMinigame" then
		Minigame.DevStart(argument); return
	elseif devMode and action == "DevMinigameEnd" then
		Minigame.DevEnd(); return
	elseif devMode and action == "DevRejoin" then
		profile.JoinedAt = os.time() + 1; Rewards.OnJoin(profile); return -- (the Free reward's "came back" in tests)
	elseif devMode and string.sub(action, 1, 3) == "Dev" then
		Expeditions.DevAction(profile, action, argument); ctx.sendState(profile); return
	end
	-- (v37) the join cutscene: the bots leave you alone while it plays (a minute at most); then it's remembered
	if action == "Cutscene" then
		profile.Cutscene = argument == true or nil
		if profile.Cutscene then
			local token = os.clock()
			profile.CutsceneToken = token
			task.delay(70, function() if profile.CutsceneToken == token then profile.Cutscene = nil end end)
		end
		return
	elseif action == "IntroDone" then
		profile.Cutscene = nil
		local version = Config.HalloweenIntro and Config.HalloweenIntro.Version or 1
		if (profile.Data.IntroSeen or 0) < version then
			profile.Data.IntroSeen = version
			profile.Player:SetAttribute("PFEIntroSeen", version)
			ctx.markDirty(profile)
		end
		return
	end
	if profile.Busy or not ctx.root(profile.Player) then return end
	if action == "Launch" then Expeditions.RequestLaunch(profile, argument)
	elseif action == "Return" then Expeditions.RequestReturn(profile)
	elseif action == "PlantEgg" then Bases.PlantEgg(profile, argument)
	elseif action == "Hatch" then Bases.Hatch(profile, argument)
	elseif action == "Fuse" then Fusion.Fuse(profile, argument)
	elseif action == "RedeemCode" then Rewards.Redeem(profile, argument)
	elseif action == "FreeClaim" then Rewards.Free(profile, type(argument) == "table" and argument.Favorited == true, true)
	elseif action == "ClaimDaily" then Rewards.ClaimDaily(profile)
	elseif action == "FreeCheck" then Rewards.Free(profile, type(argument) == "table" and argument.Favorited == true, false)
	elseif action == "BuyLimited" then
		-- the purchase prompt only while there are some left
		local product = type(argument) == "string" and Config.Products[argument]
		if product and product.Kind == "LimitedEgg" then
			if Limited.SoldOut(product.Key) then ctx.notice(profile, product.Name .. " is sold out!", "Red")
			elseif (product.Id or 0) > 0 then pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, profile.Player, product.Id) end
		end
	elseif action == "UpgradeSuit" then Expeditions.Upgrade(profile, "Suit")
	elseif action == "UpgradeRocket" then Expeditions.Upgrade(profile, "Rocket")
	elseif action == "UpgradeCargo" then Expeditions.Upgrade(profile, "Cargo")
	elseif action == "UpgradeJetpack" then Expeditions.Upgrade(profile, "Jetpack")
	elseif action == "UpgradeTreadmill" then Speed.Upgrade(profile)
	elseif action == "Treadmill" then profile.TreadmillClaim = argument == true
	elseif action == "BuyTrail" then Speed.BuyTrail(profile, argument)
	elseif action == "EquipTrail" then Speed.EquipTrail(profile, type(argument) == "string" and argument or "")
	elseif action == "UseOxygen" then Expeditions.UseOxygenTank(profile)
	end
	ctx.markDirty(profile)
end
ctx.dispatch = dispatch

ctx.remotes.Action.OnServerEvent:Connect(function(player, action, argument)
	local profile = profiles[player]
	if not profile or type(action) ~= "string" or #action > 32 then return end
	local now = os.clock()
	if now - profile.LastAction < 0.12 then return end
	profile.LastAction = now
	local ok, err = pcall(dispatch, profile, action, argument)
	if not ok then warn("[PFE] action", action, "failed:", err) end
end)
ctx.remotes.Sprint.OnServerEvent:Connect(function(player, enabled)
	local profile = profiles[player]
	if profile and type(enabled) == "boolean" then ctx.setSprint(profile, enabled) end
end)
-- (v28) a client asks for the header of its planet's layout, then streams the chunks around it
ctx.remotes.PlanetLayout.OnServerInvoke = function(player, planetId)
	if type(planetId) ~= "string" or not Config.Planets[planetId] then return nil end
	local layout = PlanetGen.Generate(planetId, mapSeed)
	return layout and PlanetGen.Header(layout) or nil
end
local chunkCalls = {}
ctx.remotes.PlanetChunks.OnServerInvoke = function(player, planetId, seed, keys)
	if type(planetId) ~= "string" or not Config.Planets[planetId] or type(keys) ~= "table" then return nil end
	-- (a client asks a few times a second at most, for at most 48 chunks)
	if os.clock() - (chunkCalls[player] or 0) < 0.08 then task.wait(0.08) end
	chunkCalls[player] = os.clock()
	local wanted = {}
	for i, key in ipairs(keys) do
		if i > 48 then break end
		if type(key) == "string" and #key < 16 then table.insert(wanted, key) end
	end
	local layout = PlanetGen.Generate(planetId, mapSeed)
	return layout and PlanetGen.PackChunks(layout, wanted) or nil
end
Players.PlayerRemoving:Connect(function(player) chunkCalls[player] = nil end)

-- ---------------------------------------------------------------- (v41) offline income
-- The pets kept earning while you were away (Config.OfflineIncome): their income now (with the passes you have) times
-- the time since your last save, capped. Settled once per visit; until it is, the saves keep the old LastSeen (leaving
-- within seconds of joining loses nothing).
function ctx.payOffline(profile)
	if profile.OfflineSettled then return end
	local cfg = Config.OfflineIncome
	local data = profile.Data
	local last = data.LastSeen or 0
	profile.OfflineSettled = true
	if not cfg or last <= 0 or not profile.Persistent then data.LastSeen = os.time(); return end
	local away = math.clamp(os.time() - last, 0, (cfg.MaxHours or 24) * 3600)
	data.LastSeen = os.time()
	if away < (cfg.MinSeconds or 60) then return end
	local _, income = ctx.petList(profile)
	local earned = math.floor(income * away * (cfg.Share or 1))
	if earned <= 0 then return end
	data.Coins = math.min(1e15, data.Coins + earned)
	ctx.effect(profile.Player, "OfflineIncome", {Coins = earned, Seconds = away, Income = income, Capped = os.time() - last > (cfg.MaxHours or 24) * 3600})
	ctx.effect(profile.Player, "Coins", {Amount = earned})
	ctx.markDirty(profile)
end

-- ---------------------------------------------------------------- players
local function loadCharacter(profile)
	if closing or profiles[profile.Player] ~= profile or not profile.Player.Parent or profile.Spawning then return end
	profile.Spawning = true
	profile.Player.RespawnLocation = profile.Base:FindFirstChild("Spawn")
	local ok, failure = pcall(function() profile.Player:LoadCharacterAsync() end)
	profile.Spawning = false
	if not ok and profiles[profile.Player] == profile and profile.Player.Parent then
		warn("[PFE] character load failed", failure)
		task.delay(3, function() loadCharacter(profile) end)
	end
end
ctx.loadCharacter = loadCharacter

local function characterAdded(profile, character)
	local characterRoot = character:WaitForChild("HumanoidRootPart", 10)
	if not characterRoot or profiles[profile.Player] ~= profile then return end
	Dungeons.OnLeft(profile)
	Caves.OnLeft(profile)
	Expeditions.OnCharacterReset(profile)
	Bases.OnCharacterReset(profile)
	characterRoot.Anchored = false
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		ctx.setMovement(profile)
		humanoid.Died:Connect(function()
			if profiles[profile.Player] ~= profile then return end
			Minigame.Leave(profile, "died")
			Dungeons.OnLeft(profile)
			Caves.OnLeft(profile)
			Expeditions.OnDied(profile)
			Bases.OnDied(profile)
			ctx.sendState(profile)
			task.delay(Players.RespawnTime, function()
				if profile.Player.Character == character then loadCharacter(profile) end
			end)
		end)
	end
	ctx.teleport(profile, profile.Base:FindFirstChild("Spawn"))
	Gear.OnCharacter(profile)
	Speed.OnCharacter(profile)
	ctx.updateImmortal(profile)
	ctx.sendState(profile)
end

local function playerAdded(player)
	-- no Shift Lock in this game (Shift does nothing at all)
	pcall(function() player.DevEnableMouseLock = false end)
	if profiles[player] or closing then return end
	local data, status, persistent = Data.Load(player)
	if not data then if player.Parent then player:Kick(status) end; return end
	if ctx.Bots then ctx.Bots.MakeRoom() end   -- (v29) a bot gives its base up for a real player
	local assigned, baseIndex
	for index = 1, #ctx.bases:GetChildren() do
		local base = ctx.bases:FindFirstChild("Base" .. index)
		if base and (base:GetAttribute("OwnerUserId") or 0) == 0 then
			assigned, baseIndex = base, index
			base:SetAttribute("OwnerUserId", player.UserId)
			break
		end
	end
	local profile = {Player = player, Data = data, Persistent = persistent, SaveStatus = status, Base = assigned, BaseIndex = baseIndex,
		Planet = "Base", Oxygen = 60, Busy = false, Sprinting = false, FlightToken = 0, LastAction = 0, LastSave = os.clock(),
		Passes = {}, Dirty = true, JoinedAt = os.time()}
	if not assigned then Data.Save(profile, true); player:Kick("This server is full. Please join another server."); return end
	if not player.Parent or closing then assigned:SetAttribute("OwnerUserId", 0); Data.Save(profile, true); return end
	profiles[player] = profile
	profile.Oxygen = ctx.maxOxygen(profile)
	Bases.SetupBase(profile)
	Speed.RenderTreadmill(assigned, data.TreadmillLevel)
	player:SetAttribute("PFESpeedPower", math.floor(data.SpeedPower or 0))
	player:SetAttribute("PFEIntroSeen", data.IntroSeen or 0)   -- (v37) HalloweenIntro.client plays the cutscene if it's new
	Shop.RefreshPasses(profile)
	Shop.SyncFlags(profile) -- (a temporary VIP from an earlier visit shows at once)
	player.RespawnLocation = assigned:FindFirstChild("Spawn")
	player.CharacterAdded:Connect(function(character) characterAdded(profile, character) end)
	if player.Character then task.spawn(characterAdded, profile, player.Character) else task.spawn(loadCharacter, profile) end
	ctx.sendState(profile)
	task.delay(6, function()
		if profiles[player] ~= profile then return end
		pcall(Rewards.Daily, profile)
		pcall(Rewards.OnJoin, profile)
		local ok, err = pcall(ctx.payOffline, profile)
		if not ok then warn("[PFE] offline income failed", err); profile.OfflineSettled = true end
	end)
	task.delay(4, function()
		if profiles[player] == profile then
			ctx.notice(profile, "Plant your egg in the pen, then fly to the Moon!", "Purple")
		end
	end)
end
Players.PlayerAdded:Connect(playerAdded)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(playerAdded, player) end

Players.PlayerRemoving:Connect(function(player)
	local leaving = profiles[player]
	if leaving then pcall(Minigame.Leave, leaving, "left") end
	local profile = profiles[player]
	if not profile then return end
	Bases.OnPlayerLeaving(profile)   -- returns eggs in transit before saving
	pcall(Dungeons.OnLeft, profile)
	pcall(Caves.OnLeft, profile)
	pcall(PlanetLife.OnLeft, profile)
	Expeditions.OnPlayerLeaving(profile)
	profiles[player] = nil
	profile.FlightToken += 1
	Bases.ClearBase(profile)
	Speed.RenderTreadmill(profile.Base, 1)
	Data.Save(profile, true)
end)

-- ---------------------------------------------------------------- tick
task.spawn(function()
	local previous = os.clock()
	while not closing do
		task.wait(1)
		local now = os.clock()
		local dt = math.min(now - previous, 2)
		previous = now
		for _, profile in pairs(profiles) do
			local ok, err = pcall(function()
				Bases.Tick(profile, dt)
				Expeditions.Tick(profile, dt)
				Shop.ExpireTemp(profile) -- game passes won in alien ships run out
				Shop.SyncFlags(profile) -- the VIP plate / super helmet flags follow what they have now
				ctx.updateImmortal(profile)
				if profile.Dirty then ctx.sendState(profile) else ctx.sendLight(profile) end
				if Data.HasStore() and profile.Persistent and now - (profile.LastSave or 0) >= 60 and now >= (profile.NextSaveAttempt or 0) and not profile.Saving then
					task.spawn(Data.Save, profile, false)
				end
			end)
			if not ok then warn("[PFE] tick failed for", profile.Player.Name, err) end
		end
	end
end)

game:BindToClose(function()
	closing = true
	local pending = 0
	for _, profile in pairs(profiles) do
		pending += 1
		task.spawn(function()
			pcall(Bases.OnPlayerLeaving, profile)
			Data.Save(profile, true)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do task.wait(0.1) end
end)
