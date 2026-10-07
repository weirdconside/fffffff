--!nocheck
-- (v35) BOTS that play the game the way people do. The server is never empty: every base nobody uses gets a bot
-- explorer, and a bot is a player in everything but the account:
--  * it has a profile like a player's (Data, Base, Planet, Stolen, Expedition, Minigame ...) and goes through the
--    game's own code: Bases.TrySteal / PlantEgg / Hatch / TransferSteal, Expeditions.TakeCarry / ShowCarry,
--    ctx.setMovement (its walk speed comes from its Speed stat), Speed.ApplyTrail, the Meteor Run - so its eggs grow
--    in its pen exactly like a player's (anyone can steal them), the eggs it steals grow there too, it hatches them,
--    catches and bats thieves, gets batted and loses eggs by the same rules;
--  * an avatar from Roblox's free catalog, the default R15 animations or a Roblox animation pack, played by a server
--    copy of Roblox's own Animate script (Bots/Animate); it moves like a person at a keyboard / phone / gamepad, shift
--    lock included, lags now and then (Bots/Motor); no emotes, ever;
--  * its brain (Bots/Brain): stealing, planting and hatching, defending its pen, hit-and-run with the bat, the
--    treadmill, trips to the planets (eggs, aliens, air), the Meteor Run, idling like people do;
--  * falls off the island or out of the world: it "dies" and respawns at its base after Players.RespawnTime, like
--    anyone (the old bots that fell stayed gone for good);
--  * the Tab list, the planet tracker, the helmet, the trail and the jetpack flames like everyone else's.
-- Never a real account's name or face outside the Studio-only preview (Config.Bots.StudioPreview), and no paid perks.
-- (v41) Wanderers (Bots/Wanderer): Config.Bots.Ambient more bots with no base and no Tab-list entry that live on the
-- island for good - they never leave to make room for a player, and come back at once if they fall off.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Bots = {}
local here = script
local Looks = require(here:WaitForChild("Looks"))
local Animate = require(here:WaitForChild("Animate"))
local Motor = require(here:WaitForChild("Motor"))
local Nav = require(here:WaitForChild("Nav"))
local Brain = require(here:WaitForChild("Brain"))
local Wanderer = require(here:WaitForChild("Wanderer"))
local ctx, Config, ModelUtil
local rng = Random.new()
local preview = false     -- Studio-only look-preview (Config.Bots.StudioPreview): see Bots.Init

local bots = {}          -- the bot records (the ones with a base, in the Tab list)
local wanderers = {}     -- (v41) the island's wanderers: no base, not in the Tab list, never leave
local LISTS = {bots, wanderers}
local byId = {}
local nextId = 1
local folder, trackerFolder, toolStore
local lastSwing = {}

local function root(bot) return bot.Model and bot.Model:FindFirstChild("HumanoidRootPart") end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function between(a, b) return a + (b - a) * rng:NextNumber() end

-- ---------------------------------------------------------------- the player stand-in
-- What the game's code reads from profile.Player: UserId, Name, DisplayName, Character, attributes. Parent is nil,
-- so ctx.notice / ctx.effect / sendState skip it (nothing to send to a bot).
local TRACKED = {PFETrackerPlanet = true, PFETrackerFlightFrom = true, PFETrackerFlightTo = true, PFETrackerFlightStartedAt = true,
	PFETrackerFlightDuration = true, PFECoins = true, PFESpeedPower = true}
local Fake = {}
Fake.__index = Fake
function Fake:SetAttribute(key, value)
	self.Attributes[key] = value
	local bot = self.Bot
	if TRACKED[key] and bot.Tracker then pcall(bot.Tracker.SetAttribute, bot.Tracker, key, value) end
	if (key == "PFESuitLevel" or key == "PFEWalkSpeed") and bot.Model then pcall(bot.Model.SetAttribute, bot.Model, key, value) end
end
function Fake:GetAttribute(key) return self.Attributes[key] end
function Fake:FindFirstChildOfClass() return nil end
function Fake:FindFirstChild() return nil end
function Fake:IsA() return false end
local dummy = {Connect = function() return {Disconnect = function() end} end}
function Fake:GetAttributeChangedSignal() return dummy end

-- ---------------------------------------------------------------- the avatar
-- Studio preview: a borrowed username and that account's own avatar (never in a published game)
local usedNames = {}
local function previewIdentity()
	local names = Config.Bots.PreviewNames or {}
	local start = rng:NextInteger(1, math.max(1, #names))
	for i = 0, #names - 1 do
		local name = names[(start + i - 1) % #names + 1]
		if not usedNames[name] then
			usedNames[name] = true
			local okId, userId = pcall(function() return Players:GetUserIdFromNameAsync(name) end)
			local desc
			if okId and userId then pcall(function() desc = Players:GetHumanoidDescriptionFromUserId(userId) end) end
			local display = name
			if okId and userId then
				pcall(function()
					local info = game:GetService("UserService"):GetUserInfosByUserIdsAsync({userId})
					if info and info[1] and info[1].DisplayName then display = info[1].DisplayName end
				end)
			end
			return name, display, okId and userId or nil, desc
		end
	end
	return nil
end

local function makeBody(bot)
	local desc = bot.Description
	local ok, model = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15) end)
	if not ok or not model then
		ok, model = pcall(function() return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15) end)
	end
	if not ok or not model then return nil end
	model.Name = bot.Name
	-- (its Animate LocalScript would never run in an NPC: Bots/Animate plays the same animations from the server)
	local animateScript = model:FindFirstChild("Animate")
	if animateScript and animateScript:IsA("LuaSourceContainer") then animateScript:Destroy() end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = bot.DisplayName or bot.Name
	-- what a player's humanoid has (StarterPlayer: names and health bars from 100 studs)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = 100
	humanoid.HealthDisplayDistance = 100
	humanoid.BreakJointsOnDeath = true
	humanoid.RequiresNeck = true
	model:SetAttribute("PFEBot", true)
	model:SetAttribute("BotId", bot.Id)
	model:SetAttribute("PFESuitLevel", bot.P.Data.SuitLevel)
	model:SetAttribute("PFESuperSuit", false)
	bot.Model, bot.Humanoid = model, humanoid
	bot.P.Player.Character = model
	-- the gear everyone has: the jetpack on the back (its level's colours), the trail they bought
	if ctx.Gear and ctx.Gear.AttachJetpackTo then pcall(ctx.Gear.AttachJetpackTo, model, bot.P.Data.JetpackLevel) end
	if bot.Animate then bot.Animate:Destroy() end
	bot.Animate = Animate.new(model, humanoid, bot.AnimSet)
	pcall(ctx.setMovement, bot.P)
	humanoid.Died:Connect(function()
		if bot.Model == model and not bot.Dead then task.defer(Bots.Kill, bot, "died") end
	end)
	return model, humanoid
end

-- the bat and the raygun (kept here while not in the hand)
local function makeTools(bot)
	for _, tool in pairs(bot.Tools or {}) do pcall(function() tool:Destroy() end) end
	bot.Tools = {}
	local gear = ctx.network:FindFirstChild("Gear")
	local bat = gear and gear:FindFirstChild("Bat")
	if bat then bot.Tools.Bat = bat:Clone() end
	if ctx.Gear and ctx.Gear.MakeRaygun then
		local ok, gun = pcall(ctx.Gear.MakeRaygun)
		if ok and gun then bot.Tools.Raygun = gun end
	end
	for _, tool in pairs(bot.Tools) do tool.Parent = toolStore end
end

-- ---------------------------------------------------------------- placing the body
local function place(bot, cf)
	local model = bot.Model
	if not model then return end
	model.Parent = folder
	local r = root(bot)
	if r then r.Anchored = false end
	model:PivotTo(cf)
	if r then
		pcall(function() r.AssemblyLinearVelocity = Vector3.zero end)
		-- the server moves its bots: without this the nearest player's client would take the body over
		pcall(function() r:SetNetworkOwner(nil) end)
	end
	bot.Shown = true
	bot.LastGround = os.clock()
end
local function hide(bot)
	if bot.Model then bot.Model.Parent = nil end
	bot.Shown = false
	if bot.Motor then bot.Motor:Stop() end
end
local function spawnPoint(bot)
	if bot.Wanderer then return Wanderer.SpawnPoint(bot) end
	local spawnPart = bot.P.Base and bot.P.Base:FindFirstChild("Spawn")
	local p = spawnPart and spawnPart.Position or (bot.P.Base and bot.P.Base:GetPivot().Position) or Vector3.new(0, 80, 0)
	-- the base's SpawnLocation, like a player's respawn (a little scatter so two never stack)
	return CFrame.new(p + Vector3.new(between(-1.5, 1.5), 3.5, between(-1.5, 1.5))) * CFrame.Angles(0, between(0, math.pi * 2), 0)
end

-- ---------------------------------------------------------------- the planet tracker (right side of the screen)
local function publish(bot)
	local entry = bot.Tracker
	if not entry then return end
	local function name(p) return p == "Base" and "Earth" or p end
	entry:SetAttribute("PFETrackerPlanet", name(bot.P.Planet))
	local flight = bot.Flight
	if flight then
		-- (the same timing a player's entry gets: the bar starts moving after lift-off)
		entry:SetAttribute("PFETrackerFlightFrom", name(flight.From))
		entry:SetAttribute("PFETrackerFlightTo", name(flight.To))
		entry:SetAttribute("PFETrackerFlightStartedAt", flight.At + 3.2)
		entry:SetAttribute("PFETrackerFlightDuration", math.max(0.1, flight.Duration - 3.2))
	else
		entry:SetAttribute("PFETrackerFlightFrom", ""); entry:SetAttribute("PFETrackerFlightTo", "")
		entry:SetAttribute("PFETrackerFlightStartedAt", 0); entry:SetAttribute("PFETrackerFlightDuration", 0)
	end
end

-- the headshot for the Tab list and the tracker: the head with its hair and hat (a little avatar, like a thumbnail)
local function headshot(bot, entry)
	local model = bot.Model
	if not model then return end
	local old = entry:FindFirstChild("Headshot")
	if old then old:Destroy() end
	local shot = Instance.new("Model")
	shot.Name = "Headshot"
	local head = model:FindFirstChild("Head")
	if not head then return end
	local anchor = head.CFrame
	local function copy(part)
		local c = part:Clone()
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("LuaSourceContainer") or d:IsA("Attachment") or d:IsA("WrapLayer") then d:Destroy() end
		end
		c.Anchored = true; c.CanCollide = false
		c.CFrame = anchor:ToObjectSpace(part.CFrame)
		c.Parent = shot
		return c
	end
	local headCopy = copy(head)
	for _, name in ipairs({"UpperTorso", "LeftUpperArm", "RightUpperArm"}) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then copy(part) end
	end
	for _, accessory in ipairs(model:GetChildren()) do
		if accessory:IsA("Accessory") then
			local handle = accessory:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") and (handle.Position - head.Position).Magnitude < 4 then copy(handle) end
		end
	end
	shot.PrimaryPart = headCopy
	shot.Parent = entry
end

-- ---------------------------------------------------------------- tools in the hand
function Bots.Equip(bot, name)
	local tool = bot.Tools and bot.Tools[name]
	local humanoid = bot.Humanoid
	if not tool or not humanoid or not bot.Model or bot.Dead then return false end
	if bot.Equipped == name and tool.Parent == bot.Model then return true end
	Bots.Unequip(bot)
	local ok = pcall(function() humanoid:EquipTool(tool) end)
	if not ok or tool.Parent ~= bot.Model then tool.Parent = bot.Model end
	-- the grip the engine makes for a player's hand (made here too if it didn't)
	task.defer(function()
		local hand = bot.Model and bot.Model:FindFirstChild("RightHand")
		local handle = tool:FindFirstChild("Handle")
		if tool.Parent ~= bot.Model or not hand or not handle then return end
		if not hand:FindFirstChild("RightGrip") then
			local grip = hand:FindFirstChild("RightGripAttachment")
			local weld = Instance.new("Weld")
			weld.Name = "RightGrip"; weld.Part0 = hand; weld.Part1 = handle
			weld.C0 = grip and grip.CFrame or CFrame.new(0, -hand.Size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
			weld.C1 = tool.Grip
			weld.Parent = hand
		end
	end)
	bot.Equipped = name
	return true
end
function Bots.Unequip(bot)
	if not bot.Tools then return end
	for _, tool in pairs(bot.Tools) do
		if tool.Parent ~= toolStore then pcall(function() tool.Parent = toolStore end) end
	end
	local hand = bot.Model and bot.Model:FindFirstChild("RightHand")
	local grip = hand and hand:FindFirstChild("RightGrip")
	if grip then grip:Destroy() end
	bot.Equipped = nil
end

-- ---------------------------------------------------------------- the bat
local function batFx(at)
	for _, player in ipairs(Players:GetPlayers()) do
		local r = ctx.root(player)
		if r and (r.Position - at).Magnitude < 120 then ctx.effect(player, "BatHit", {Position = at}) end
	end
end
-- knocked back the way a player's own client throws them (Bat.client: away x2, up x1.1, off their feet a moment)
local function knock(bot, from, force, duration)
	local r = root(bot)
	local humanoid = bot.Humanoid
	if not r or not humanoid or bot.Dead then return end
	force = force or Config.Bat.Force
	local away = flat(r.Position - from)
	away = away.Magnitude > 0.01 and away.Unit or Vector3.new(0, 0, 1)
	if bot.Motor then bot.Motor:StopRide(); bot.Motor:JetOff() end
	if r.Anchored then
		if bot.Treadmill then Brain.LeaveTreadmill(bot) end
		if r.Anchored then return end
	end
	humanoid.PlatformStand = true
	r.AssemblyLinearVelocity = away * force * 2 + Vector3.new(0, force * 1.1, 0)
	r.AssemblyAngularVelocity = Vector3.new(away.Z, 0, -away.X) * 8
	bot.KnockedUntil = os.clock() + (duration or Config.Bat.Duration) + 0.45
	task.delay((duration or Config.Bat.Duration) + 0.45, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
		end
	end)
end
Bots.Knock = knock

-- a player bats a bot (Gear's bat remote): the same rules as a hit on a player
function Bots.Hit(attacker, botId)
	local bot = byId[botId]
	local r = bot and root(bot)
	local from = ctx.root(attacker)
	if not r or not from or not bot.Model.Parent or bot.Dead or bot.P.Busy then return false end
	if (from.Position - r.Position).Magnitude > Config.Bat.Range + Config.Bat.Tolerance then return false end
	local hitter = ctx.profiles[attacker]
	if hitter and (hitter.Busy or hitter.Stolen or (hitter.Expedition and hitter.Expedition.CarryingEgg)) then return false end
	if hitter and hitter.Planet ~= bot.P.Planet then return false end
	knock(bot, from.Position)
	batFx(r.Position)
	-- Egg Arena rules: the egg in its hands goes to whoever hit it
	if hitter then
		if bot.P.Stolen then ctx.Bases.TransferSteal(bot.P, hitter)
		elseif bot.P.Expedition and bot.P.Expedition.CarryingEgg then ctx.Expeditions.TakeCarry(bot.P, hitter) end
	end
	Brain.OnHit(bot, {Profile = hitter, Player = attacker})
	return true
end

-- a bot swings at someone (a person, or another bot): its arm, the hit, the rules
function Bots.Swing(bot, target)
	local tool = bot.Tools and bot.Tools.Bat
	if not tool or tool.Parent ~= bot.Model or bot.Dead then return false end
	local now = os.clock()
	if now - (lastSwing[bot] or 0) < Config.Bat.Cooldown then return false end
	lastSwing[bot] = now
	local message = Instance.new("StringValue"); message.Name = "toolanim"; message.Value = "Slash"; message.Parent = tool
	task.delay(0.3, function() if message.Parent then message:Destroy() end end)
	local P = bot.P
	if not target or P.Stolen or (P.Expedition and P.Expedition.CarryingEgg) then return false end
	local r = root(bot)
	local targetRoot = target.Bot and root(target.Bot) or (target.Profile and ctx.root(target.Profile.Player))
	if not r or not targetRoot then return false end
	if (r.Position - targetRoot.Position).Magnitude > Config.Bat.Range + Config.Bat.Tolerance then return false end
	local victim = target.Profile
	if not victim or victim.Busy or victim.Planet ~= P.Planet then return false end
	if target.Bot then
		knock(target.Bot, r.Position)
	else
		ctx.effect(victim.Player, "Knockback", {From = r.Position, Force = Config.Bat.Force, Duration = Config.Bat.Duration})
	end
	batFx(targetRoot.Position)
	if victim.Stolen then ctx.Bases.TransferSteal(victim, P)
	elseif victim.Expedition and victim.Expedition.CarryingEgg then ctx.Expeditions.TakeCarry(victim, P) end
	if target.Bot then Brain.OnHit(target.Bot, {Profile = P, Bot = bot}) end
	return true
end

-- (v41) a swing at a thing - a crystal, a rock, a chest, the boss (PlanetLife.BotSmash: the reach and the hit)
function Bots.SwingAt(bot, model)
	local tool = bot.Tools and bot.Tools.Bat
	if not tool or tool.Parent ~= bot.Model or bot.Dead then return false end
	local now = os.clock()
	if now - (lastSwing[bot] or 0) < Config.Bat.Cooldown then return false end
	lastSwing[bot] = now
	local message = Instance.new("StringValue"); message.Name = "toolanim"; message.Value = "Slash"; message.Parent = tool
	task.delay(0.3, function() if message.Parent then message:Destroy() end end)
	if bot.P.Stolen or (bot.P.Expedition and bot.P.Expedition.CarryingEgg) or not ctx.PlanetLife or not ctx.PlanetLife.BotSmash then return false end
	return ctx.PlanetLife.BotSmash(bot.P, model)
end

-- the raygun at an alien (Aliens.BotShoot: the hit and the green bolt everyone on the planet sees)
function Bots.Shoot(bot, aim)
	local gun = bot.Tools and bot.Tools.Raygun
	if not gun or gun.Parent ~= bot.Model or bot.Dead or not ctx.Aliens or not ctx.Aliens.BotShoot then return false end
	local muzzle = gun:FindFirstChild("MuzzlePart") or gun:FindFirstChild("Muzzle") or gun:FindFirstChild("Handle")
	local head = bot.Model:FindFirstChild("Head")
	local origin = (muzzle and head and (muzzle.Position - head.Position).Magnitude < 8 and muzzle.Position) or (head and head.Position)
	if not origin then return false end
	return ctx.Aliens.BotShoot(bot.P, origin, aim)
end

-- ---------------------------------------------------------------- the pen (its eggs grow like a player's)
local function petPool(maxPlanet)
	local list = {}
	for _, pet in ipairs(Config.PetList) do
		if not pet.Limited and not pet.Special and Config.Planets[pet.Planet] and (Config.Planets[pet.Planet].Order or 1) <= maxPlanet then
			local order = Config.Rarities[pet.Rarity] and Config.Rarities[pet.Rarity].Order or 1
			table.insert(list, {pet.Species, 1 / (order ^ 2.2)})
		end
	end
	return list
end
local function rollFrom(pool)
	local total = 0
	for _, e in ipairs(pool) do total += e[2] end
	local r = rng:NextNumber() * total
	for _, e in ipairs(pool) do r -= e[2]; if r <= 0 then return e[1] end end
	return pool[#pool][1]
end
local function rollEggFor(maxPlanet)
	local planets = {}
	for _, p in ipairs(Config.PlanetOrder) do if (p.Order or 1) <= maxPlanet then table.insert(planets, p.Id) end end
	local planetId = planets[rng:NextInteger(1, #planets)]
	local info = ctx.Expeditions.RollEgg(1, planetId, rng:NextInteger(1, 4))
	return info and {Id = ctx.Data.Guid(), EggId = info.Id, Scale = ctx.Expeditions.RollSize(), Mutation = ctx.Expeditions.RollMutation(1, planetId)} or nil
end

-- what a player this far into the game has (a fresh "save" for each bot; nothing of theirs is stored)
local TIERS = {
	-- {suit, rocket, cargo, jetpack, treadmill, SP range (log10), coins (log10), pets, growing eggs, planets reached}
	[1] = {1, 1, 1, 1, 1, {0.3, 1.5}, {2.3, 3.6}, {3, 4}, {1, 3}, 1},
	[2] = {1, 2, 2, 2, 2, {1.2, 2.3}, {3.4, 4.6}, {4, 6}, {2, 4}, 2},
	[3] = {2, 3, 3, 3, 3, {2, 3}, {4.3, 5.6}, {6, 8}, {2, 5}, 3},
	[4] = {3, 4, 4, 4, 4, {2.7, 3.6}, {5.4, 6.7}, {8, 11}, {3, 6}, 4},
	[5] = {4, 5, 5, 5, 5, {3.3, 4.2}, {6.4, 7.8}, {10, 14}, {3, 7}, 5},
	[6] = {5, 6, 6, 6, 6, {3.9, 4.9}, {7.5, 9}, {13, 18}, {4, 8}, 6},
}
local TRAIL_ORDER = {"", "", "Ghost", "CandyCorn", "Slime", "PumpkinFire", "BloodMoon"}
local function newData(persona)
	local t = TIERS[persona.Tier] or TIERS[2]
	local data = ctx.Data.Default()
	data.Eggs = {}
	data.DiscoveredEggs = {}
	data.SuitLevel = math.min(#Config.Suits, t[1])
	data.RocketLevel = math.min(#Config.Rockets, t[2])
	data.CargoLevel = math.min(#Config.Cargo, t[3])
	data.JetpackLevel = math.min(#Config.Jetpacks, t[4])
	data.TreadmillLevel = math.min(#Config.Treadmills, t[5])
	data.SpeedPower = math.floor(10 ^ between(t[6][1], t[6][2]))
	data.Coins = math.floor(10 ^ between(t[7][1], t[7][2]))
	data.TutorialStep = 8
	-- a trail now and then (bought with coins in the game's own trail shop)
	local trail = TRAIL_ORDER[math.clamp(persona.Tier + rng:NextInteger(-1, 1), 1, #TRAIL_ORDER)]
	if trail ~= "" and Config.Trails[trail] and rng:NextNumber() < 0.6 then data.Trails[trail] = true; data.Trail = trail end
	local pool = petPool(t[10])
	for _ = 1, rng:NextInteger(t[8][1], t[8][2]) do
		local mutation = rng:NextNumber() < 0.08 and "Golden" or (rng:NextNumber() < 0.02 and "Diamond" or "Normal")
		table.insert(data.Pets, {Id = ctx.Data.Guid(), Species = rollFrom(pool), Scale = ctx.Expeditions.RollSize(), Mutation = mutation})
	end
	return data, t
end

-- ---------------------------------------------------------------- join / leave
local function freeBases()
	local list = {}
	for index = 1, #ctx.bases:GetChildren() do
		local base = ctx.bases:FindFirstChild("Base" .. index)
		if base and (base:GetAttribute("OwnerUserId") or 0) == 0 then table.insert(list, {base, index}) end
	end
	return list
end

local function despawn(bot, reason)
	if bot.Gone then return end
	local P = bot.P
	-- a stolen egg flies back to its owner, a run leaves, the base is free again
	pcall(function() if P.Stolen then ctx.Bases.CancelSteal(P, "left the game") end end)
	pcall(function() if P.Minigame and ctx.Minigame and ctx.Minigame.LeaveBot then ctx.Minigame.LeaveBot(P, "left") end end)
	pcall(function() if P.Expedition and P.Expedition.CarryingEgg then ctx.Expeditions.ClearCarry(P); P.Expedition.CarryingEgg = nil end end)
	bot.Gone = true
	for i, b in ipairs(bots) do if b == bot then table.remove(bots, i); break end end
	byId[bot.Id] = nil
	lastSwing[bot] = nil
	Brain.Forget(bot)
	if bot.Motor then pcall(function() bot.Motor:Reset() end) end
	if bot.Animate then pcall(function() bot.Animate:Destroy() end) end
	if bot.Model then bot.Model:Destroy() end
	for _, tool in pairs(bot.Tools or {}) do tool:Destroy() end
	if bot.Tracker then bot.Tracker:Destroy() end
	usedNames[bot.Name] = nil
	local base = P.Base
	if base and base:GetAttribute("OwnerUserId") == P.Player.UserId then
		base:SetAttribute("BotRunning", nil); base:SetAttribute("BotWalkSpeed", nil)
		pcall(ctx.Bases.ClearBase, P)
		if ctx.Speed then pcall(ctx.Speed.RenderTreadmill, base, 1) end
	end
end
Bots.Despawn = despawn

local function spawnBot()
	local free = freeBases()
	if #free == 0 then return nil end
	local slot = free[rng:NextInteger(1, #free)]
	local persona = Looks.Persona()
	local name = Looks.Name()
	for _ = 1, 5 do if not usedNames[name] then break end; name = Looks.Name() end
	local bot = {Id = nextId, Name = name, Persona = persona, Tools = {}, Grudges = {}, Seen = {}, Shown = false}
	nextId += 1
	bot.DisplayName = Looks.DisplayName(name)
	bot.AnimSet, bot.AnimPack = Looks.Animations()
	if preview then
		local pname, display, realId, desc = previewIdentity()
		if pname then bot.Name, bot.DisplayName, bot.RealUserId, bot.Description = pname, display, realId, desc end
	end
	usedNames[bot.Name] = true
	bot.Description = bot.Description or Looks.Describe()
	local data = newData(persona)
	local fake = setmetatable({UserId = -bot.Id, Name = bot.Name, DisplayName = bot.DisplayName, Character = nil, Attributes = {},
		IsBot = true, Bot = bot}, Fake)
	local P = {IsBot = true, Bot = bot, Player = fake, Data = data, Base = slot[1], BaseIndex = slot[2], Planet = "Base", Busy = false,
		Passes = {}, ShieldUntil = 0, Oxygen = 60, FlightToken = 0, LastAction = 0, Dirty = false, Sprinting = false, JoinedAt = os.time()}
	bot.P = P
	bot.UserId = fake.UserId
	-- claim the base before the avatar loads (a player joining meanwhile gets another one)
	slot[1]:SetAttribute("OwnerUserId", fake.UserId)
	slot[1]:SetAttribute("OwnerName", bot.DisplayName)
	local model = makeBody(bot)
	if not model then
		slot[1]:SetAttribute("OwnerUserId", 0); slot[1]:SetAttribute("OwnerName", "")
		usedNames[bot.Name] = nil
		return nil
	end
	makeTools(bot)
	byId[bot.Id] = bot
	P.Oxygen = ctx.maxOxygen(P)
	-- its base: pets, the eggs it has growing (some nearly ready), its treadmill and rocket
	ctx.Bases.SetupBotBase(P)
	if ctx.Speed then pcall(ctx.Speed.RenderTreadmill, P.Base, data.TreadmillLevel) end
	local t = TIERS[persona.Tier] or TIERS[2]
	for _ = 1, rng:NextInteger(t[9][1], t[9][2]) do
		local egg = rollEggFor(t[10])
		if egg then pcall(ctx.Bases.SeedGrowing, P, egg, rng:NextNumber(0.05, 0.95)) end
	end
	ctx.Bases.RenderGrowing(P)
	-- the Tab list / tracker entry
	local entry = Instance.new("Configuration")
	entry.Name = "Bot" .. bot.Id
	entry:SetAttribute("DisplayName", bot.DisplayName)
	entry:SetAttribute("UserName", bot.Name)
	if bot.RealUserId then entry:SetAttribute("UserId", bot.RealUserId) end
	headshot(bot, entry)
	entry:SetAttribute("PFECoins", math.floor(data.Coins)); entry:SetAttribute("PFESpeedPower", math.floor(data.SpeedPower))
	entry.Parent = trackerFolder
	bot.Tracker = entry
	publish(bot)
	bot.Motor = Motor.new(bot, {Config = Config, Nav = Nav, Watched = function(b) return Brain.Watched(b.P.Planet) end})
	place(bot, spawnPoint(bot))
	pcall(ctx.Speed.ApplyTrail, P)
	table.insert(bots, bot)
	task.spawn(Brain.Run, bot)
	return bot
end

-- (v41) a wanderer: a body, the bat and the raygun, a made-up name - no base, no Tab-list entry, no pen
local function spawnWanderer()
	local persona = Looks.Persona()
	persona.Tier = math.clamp(persona.Tier, 2, 5)
	local name = Looks.Name()
	for _ = 1, 5 do if not usedNames[name] then break end; name = Looks.Name() end
	local bot = {Id = nextId, Name = name, Persona = persona, Tools = {}, Grudges = {}, Seen = {}, Shown = false, Wanderer = true}
	nextId += 1
	bot.DisplayName = Looks.DisplayName(name)
	bot.AnimSet, bot.AnimPack = Looks.Animations()
	usedNames[bot.Name] = true
	bot.Description = Looks.Describe()
	local data = ctx.Data.Default()
	local t = TIERS[persona.Tier] or TIERS[2]
	data.SuitLevel = math.min(#Config.Suits, t[1])
	data.JetpackLevel = math.min(#Config.Jetpacks, t[4])
	data.SpeedPower = math.floor(10 ^ between(t[6][1], t[6][2]))
	data.TutorialStep = 8
	local trail = TRAIL_ORDER[math.clamp(persona.Tier + rng:NextInteger(-1, 1), 1, #TRAIL_ORDER)]
	if trail ~= "" and Config.Trails[trail] and rng:NextNumber() < 0.5 then data.Trails[trail] = true; data.Trail = trail end
	local fake = setmetatable({UserId = -bot.Id, Name = bot.Name, DisplayName = bot.DisplayName, Character = nil, Attributes = {},
		IsBot = true, Bot = bot}, Fake)
	local P = {IsBot = true, Wanderer = true, Bot = bot, Player = fake, Data = data, Base = nil, Planet = "Base", Busy = false,
		Passes = {}, ShieldUntil = 0, Oxygen = 60, FlightToken = 0, LastAction = 0, Dirty = false, Sprinting = false, JoinedAt = os.time()}
	bot.P = P
	bot.UserId = fake.UserId
	if not makeBody(bot) then usedNames[bot.Name] = nil; return nil end
	makeTools(bot)
	byId[bot.Id] = bot
	P.Oxygen = ctx.maxOxygen(P)
	bot.Motor = Motor.new(bot, {Config = Config, Nav = Nav, Watched = function(b) return Brain.Watched(b.P.Planet) end})
	place(bot, spawnPoint(bot))
	pcall(ctx.Speed.ApplyTrail, P)
	table.insert(wanderers, bot)
	task.spawn(Wanderer.Run, bot)
	return bot
end

-- a real player needs a base: a bot leaves (called before the server hands out bases). The one with the least going on
-- goes: not carrying anything, not in the air, at home.
local function leaveOne()
	if #bots == 0 then return end
	local best, bestScore
	for _, bot in ipairs(bots) do
		local P = bot.P
		local score = (P.Stolen and 5 or 0) + (P.Busy and 4 or 0) + (P.Minigame and 4 or 0) + (P.Planet ~= "Base" and 2 or 0)
			+ (bot.Treadmill and 1 or 0) + rng:NextNumber()
		if not bestScore or score < bestScore then best, bestScore = bot, score end
	end
	despawn(best or bots[#bots], "room")
end
function Bots.MakeRoom()
	if #freeBases() > 0 or #bots == 0 then return end
	leaveOne()
end

-- ---------------------------------------------------------------- dying and coming back (like a player)
function Bots.Kill(bot, reason)
	if bot.Gone or bot.Dead then return end
	bot.Dead = true
	bot.Interrupt = nil
	local P = bot.P
	-- (v41) ran out of air out there: it learns to turn back sooner (Brain's explore)
	if Config.Planets[P.Planet] and (P.Oxygen or 1) <= 0 then bot.AirLessons = (bot.AirLessons or 0) + 1 end
	pcall(function() if P.Stolen then ctx.Bases.CancelSteal(P, "knocked out") end end)
	pcall(function() if P.Minigame and ctx.Minigame and ctx.Minigame.LeaveBot then ctx.Minigame.LeaveBot(P, "left") end end)
	pcall(function()
		if P.Expedition then
			if P.Expedition.CarryingEgg then ctx.Expeditions.DropCarry(P) end
			P.Expedition = nil
		end
		ctx.Expeditions.ClearCarry(P)
	end)
	if bot.Treadmill then pcall(Brain.LeaveTreadmill, bot) end
	Bots.Unequip(bot)
	if bot.Motor then bot.Motor:Reset() end
	local humanoid = bot.Humanoid
	if humanoid and humanoid.Health > 0 then pcall(function() humanoid.Health = 0 end) end
	local old = bot.Model
	task.delay(Players.RespawnTime or 5, function()
		if bot.Gone then return end
		if old and old.Parent then old:Destroy() end
		bot.Model = nil
		P.Planet, P.Busy, P.Minigame = "Base", false, nil
		bot.Flight = nil
		P.Oxygen = ctx.maxOxygen(P)
		local model = makeBody(bot)
		if not model then task.delay(5, function() if not bot.Gone then bot.Dead = false; Bots.Kill(bot, "retry") end end); return end
		local broken = false
		for _, tool in pairs(bot.Tools or {}) do if not tool:FindFirstChild("Handle") or tool.Parent == nil then broken = true end end
		if broken or not bot.Tools.Bat then makeTools(bot) end
		bot.Dead = false
		place(bot, spawnPoint(bot))
		pcall(ctx.Speed.ApplyTrail, P)
		publish(bot)
		bot.Interrupt = {Kind = "Respawned"}
	end)
end

-- every half second: is the body still in the world? (fell off the island, flung out, broken)
local function watchdog(bot)
	if bot.Dead or bot.Gone or not bot.Shown or bot.P.Busy then return end
	local model, humanoid = bot.Model, bot.Humanoid
	local r = root(bot)
	if not model or not model.Parent or not r or not r.Parent or not humanoid or humanoid.Health <= 0 then Bots.Kill(bot, "lost"); return end
	local p = r.Position
	local floor
	if bot.P.Planet == "Base" then floor = (ctx.IslandFloor or 20)
	else
		local planet = Config.Planets[bot.P.Planet]
		floor = planet and planet.Origin.Y - 60 or -100
	end
	if p.Y < floor or p.Y < workspace.FallenPartsDestroyHeight + 20 or p.Y ~= p.Y then Bots.Kill(bot, "fell") end
end

-- ---------------------------------------------------------------- the API the brain uses
local B = {}
B.Looks, B.Nav, B.Motor = Looks, Nav, Motor
B.Root = root
B.Place, B.Hide, B.SpawnPoint, B.Publish = place, hide, spawnPoint, publish
B.Equip, B.Unequip, B.Swing, B.Shoot, B.Knock = Bots.Equip, Bots.Unequip, Bots.Swing, Bots.Shoot, knock
B.Kill = function(bot, reason) Bots.Kill(bot, reason) end
function B.List() return bots end
function B.Wanderers() return wanderers end
-- (v41) every bot on the server: the ones with a base and the wanderers
function B.All()
	local list = table.clone(bots)
	for _, w in ipairs(wanderers) do table.insert(list, w) end
	return list
end
function B.ById(id) return byId[id] end
function B.Alive(bot) return not bot.Gone and not bot.Dead and bot.Model ~= nil and bot.Model.Parent ~= nil end

-- ---------------------------------------------------------------- studio tests
function Bots.DevSpawn()
	if not folder then folder = Instance.new("Folder"); folder.Name = "PFE_Bots"; folder.Parent = workspace end
	return spawnBot()
end
function Bots.DevSpawnWanderer()
	if not folder then folder = Instance.new("Folder"); folder.Name = "PFE_Bots"; folder.Parent = workspace end
	return spawnWanderer()
end
function Bots.DevClear()
	for i = #bots, 1, -1 do despawn(bots[i], "clear") end
end
Bots.DevExplore = function(bot, planetId) return Brain.DevExplore(bot, planetId) end
Bots.DevCarry = function(bot, egg)
	if egg then ctx.Expeditions.ShowCarry(bot.P, egg) else ctx.Expeditions.ClearCarry(bot.P) end
end
Bots.Brain = Brain
Bots.Looks = Looks
function Bots.DevContext() return ctx end

-- ---------------------------------------------------------------- hooks for the rest of the game
function Bots.Count() return #bots end
function Bots.List() return bots end
function Bots.Wanderers() return wanderers end
function Bots.Profiles()
	local list = {}
	for _, bot in ipairs(bots) do if not bot.Gone then table.insert(list, bot.P) end end
	return list
end
-- someone took an egg out of this bot's pen (Bases.TrySteal)
function Bots.OnRobbed(owner, thief)
	local bot = owner and owner.Bot
	if bot and not bot.Gone then Brain.OnRobbed(bot, thief) end
	-- (v36) and the bots around may go after the thief as well
	for _, other in ipairs(bots) do
		if other ~= bot and not other.Gone and other.P ~= thief then pcall(Brain.OnThief, other, thief) end
	end
	-- (v41) the wanderers catch thieves too (the egg flies back to its pen: they have no pen to take it to)
	for _, other in ipairs(wanderers) do
		if not other.Gone and other.P ~= thief then pcall(Wanderer.OnThief, other, thief) end
	end
end
-- (v41) a boss woke up / the Golden Egg appeared on `planetId`: the bots at home hear the news too (Brain: who goes)
function Bots.OnRally(planetId, kind)
	for _, bot in ipairs(bots) do
		if not bot.Gone and not bot.Dead then pcall(Brain.OnRally, bot, planetId, kind) end
	end
end
-- the Meteor Run took this bot along / ended for it
function Bots.OnMinigameStart(P, cf)
	local bot = P.Bot
	if not bot or bot.Gone then return end
	if bot.Treadmill then pcall(Brain.LeaveTreadmill, bot) end
	if bot.Motor then bot.Motor:Stop() end
	if cf then place(bot, cf) end
	publish(bot)
	bot.Interrupt = {Kind = "MeteorStart"}
end
function Bots.OnMinigameEnd(P)
	local bot = P.Bot
	if not bot or bot.Gone or bot.Dead then return end
	if bot.Motor then bot.Motor:StopRide(); bot.Motor:JetOff(); bot.Motor:Stop() end
	place(bot, spawnPoint(bot))
	publish(bot)
	bot.Interrupt = {Kind = "MeteorEnd"}
end

-- ---------------------------------------------------------------- keep the server full
function Bots.Init(context)
	ctx = context
	Config = ctx.Config
	ModelUtil = require(ReplicatedStorage:WaitForChild("PFE"):WaitForChild("ModelUtil"))
	ctx.Bots = Bots
	Nav.Init(ctx)
	trackerFolder = Instance.new("Folder"); trackerFolder.Name = "BotTracker"; trackerFolder.Parent = ctx.network
	toolStore = Instance.new("Folder"); toolStore.Name = "PFE_BotTools"; toolStore.Parent = game:GetService("ServerStorage")
	B.ctx, B.Config, B.ModelUtil = ctx, Config, ModelUtil
	B.SwingAt = Bots.SwingAt
	Brain.Init(B)
	Wanderer.Init(B, Brain)
	-- the island's lowest walkable height: falling below it means falling off
	do
		local island = ctx.world:FindFirstChild("OriginalIsland")
		local ok, cf, size = pcall(function() return island:GetBoundingBox() end)
		ctx.IslandFloor = ok and cf and (cf.Position.Y - size.Y / 2 - 30) or 20
	end
	preview = RunService:IsStudio() and Config.Bots.StudioPreview == true
	workspace:SetAttribute("PFEBotPreview", preview)
	workspace:SetAttribute("PFEBotList", Config.Bots.Enabled == true)   -- (v33) the bots show in the Tab list
	-- every frame: the hands on the keys and the animations
	local animClock = 0
	RunService.Heartbeat:Connect(function(dt)
		animClock += dt
		local animate = animClock >= 1 / 30
		for _, list in ipairs(LISTS) do
			for _, bot in ipairs(list) do
				if bot.Shown and not bot.Dead and bot.Model and bot.Model.Parent then
					local ok, err = pcall(bot.Motor.Step, bot.Motor, dt)
					if not ok and not bot.Warned then bot.Warned = true; warn("[PFE] bot motor " .. bot.Name .. ": " .. tostring(err)) end
					if animate and bot.Animate then
						local okA, errA = pcall(bot.Animate.Step, bot.Animate, animClock)
						if not okA and not bot.WarnedA then bot.WarnedA = true; warn("[PFE] bot animate " .. bot.Name .. ": " .. tostring(errA)) end
					end
				end
			end
		end
		if animate then animClock = 0 end
	end)
	-- once a second: their bases tick like a player's (income, the thief's run home, the growing eggs), their stats,
	-- the air on a planet; twice a second the watchdog
	task.spawn(function()
		local previous = os.clock()
		local half = false
		while true do
			task.wait(0.5)
			for _, list in ipairs(LISTS) do
				for _, bot in ipairs(table.clone(list)) do pcall(watchdog, bot) end
			end
			half = not half
			if half then continue end
			local now = os.clock()
			local dt = math.min(2, now - previous)
			previous = now
			for _, list in ipairs(LISTS) do
				for _, bot in ipairs(table.clone(list)) do
					local ok, err = pcall(Brain.Tick1, bot, dt)
					if not ok then warn("[PFE] bot tick " .. bot.Name .. ": " .. tostring(err)) end
				end
			end
		end
	end)
	if not (Config.Bots and Config.Bots.Enabled) then return end
	folder = Instance.new("Folder"); folder.Name = "PFE_Bots"; folder.Parent = workspace
	-- (v41) the wanderers: on the island from the start, for good (one comes back if one is ever lost)
	task.spawn(function()
		task.wait(2)
		while true do
			if #wanderers < (Config.Bots.Ambient or 0) then
				local ok, err = pcall(spawnWanderer)
				if not ok then warn("[PFE] wanderer spawn failed: " .. tostring(err)) end
				task.wait(rng:NextNumber(0.5, 2))
			else
				task.wait(5)
			end
		end
	end)
	task.spawn(function()
		task.wait(3)
		while true do
			local capacity = math.min(#ctx.bases:GetChildren(), Config.Bots.Capacity or 9)
			local humans = #Players:GetPlayers()
			local want = math.clamp(capacity - humans, 0, Config.Bots.Max or 8)
			if #bots < want then
				local ok, err = pcall(spawnBot)
				if not ok then warn("[PFE] bot spawn failed: " .. tostring(err)) end
				task.wait(rng:NextNumber(Config.Bots.JoinDelay[1], Config.Bots.JoinDelay[2]))   -- they drop in one by one
			elseif #bots > want then
				leaveOne()
				task.wait(1)
			else
				task.wait(2)
			end
		end
	end)
end

return Bots
