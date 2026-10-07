--!nocheck
-- (v35) What a bot decides to do, moment to moment - the things players do in this game, with their mistakes:
--  * home: plant the eggs it has (they grow in its pen like anyone's), hatch the ripe ones (the hatch roll, the pet
--    walks out), steal from other pens (players' and bots', never a shielded or a newcomer's: Bases.TrySteal decides)
--    and run home with it slowed down and glowing red, zig-zagging from whoever chases it; defend its own pen (chase
--    the thief, bat the egg back); bat thieves running past and take their egg; hit-and-run with the bat for fun and
--    hold grudges; the treadmill; the upgrades it can afford; idle like people: AFK, spinning in shift lock, swapping
--    tools, jumping about, looking at other people's pets;
--  * the planets: fly there like a player (stands at its rocket through the flight), hunt eggs (rarer further out),
--    carry them to the rocket, knock eggs out of other people's hands, shoot aliens with the raygun, watch its air
--    and go home in time - mostly; on a planet nobody watches it explores out of sight and turns up when someone lands;
--  * the Meteor Run: into the circle when the invitation comes, then jetpack up to the meteors and grab their eggs.
--  * (v41) the living planets: out of the red circles (meteors, lightning, bombs, a boss's slam - the good players nearly
--    always, the others not always), under a campfire / mushroom / shade rock when the weather wants it, the planet boss
--    (some with the bat, some from afar with the raygun), the Golden Egg race (grab it, run it to the rocket, bat it out of
--    the carrier's hands), crystals / rocks / ice blocks / volcanic bombs smashed for the eggs inside; flying out to the
--    boss's or the Golden Egg's planet when somebody is there; learning (more air to spare after running out once,
--    revenge on whoever robbed it, guarding its pen after a theft);
--  * (v41) the island: guarding its pen, hanging out next to people, tagging along behind somebody, watching the Meteor Run.
local Brain = {}
local B, ctx, Config
local rng = Random.new()
local claimed = {}        -- planet egg -> the bot going for it
local bonked = {}         -- bot -> {userId -> time}: nobody gets pestered over and over
local robbedAt = {}       -- real player's user id -> when a bot last stole from them
Brain.Stats = {}          -- what the bots have been up to (counts, for the tests)
local function count(key) Brain.Stats[key] = (Brain.Stats[key] or 0) + 1 end

local function now() return os.clock() end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function between(a, b) return a + (b - a) * rng:NextNumber() end
local function chance(p) return rng:NextNumber() < p end

function Brain.Init(api)
	B = api
	ctx, Config = B.ctx, B.Config
end

-- ---------------------------------------------------------------- helpers
local function rootOf(profile)
	if not profile then return nil end
	if profile.IsBot then
		local bot = profile.Bot
		return bot and not bot.Dead and bot.Model and bot.Model.Parent and B.Root(bot) or nil
	end
	return ctx.root(profile.Player)
end
local function online(profile)
	if not profile then return false end
	if profile.IsBot then return profile.Bot ~= nil and not profile.Bot.Gone end
	return ctx.profiles[profile.Player] == profile and profile.Player.Parent ~= nil
end
-- is a real player on this planet ("Base" = the island)?
function Brain.Watched(planetId)
	for _, profile in pairs(ctx.profiles) do
		if profile.Planet == planetId then return true end
	end
	return false
end
-- everyone standing on a planet: {Profile, Root, Bot?, Human?}
local function people(planetId, except)
	local list = {}
	for _, profile in pairs(ctx.profiles) do
		if profile.Planet == planetId and not profile.Busy and not profile.Cutscene then
			local r = ctx.root(profile.Player)
			if r then table.insert(list, {Profile = profile, Root = r, Human = true}) end
		end
	end
	for _, other in ipairs(B.All()) do
		if other ~= except and not other.Gone and not other.Dead and other.Shown and other.P.Planet == planetId and not other.P.Busy then
			local r = B.Root(other)
			if r then table.insert(list, {Profile = other.P, Root = r, Bot = other}) end
		end
	end
	return list
end
local function entityOf(profile)
	if not profile then return nil end
	return {Profile = profile, Bot = profile.IsBot and profile.Bot or nil, Human = not profile.IsBot}
end
local function myRoot(bot) return B.Root(bot) end
local function speedOf(bot) return bot.Humanoid and bot.Humanoid.WalkSpeed or 20 end

-- (v41) is it standing where something is about to land (a meteor's red circle, a boss's slam, a hazard patch)? A bot
-- notices a given circle or not (the better players nearly always do) - decided once per circle
local function sensesDanger(bot)
	local L = ctx.PlanetLife
	local r = myRoot(bot)
	if not L or not L.Danger or not r or not bot.Shown or bot.P.Planet == "Base" then return nil end
	local thing, radius = L.Danger(bot.P.Planet, r.Position, 2 + bot.Persona.Skill * 3)
	if not thing then return nil end
	bot.Noticed = bot.Noticed or setmetatable({}, {__mode = "k"})
	local seen = bot.Noticed[thing]
	if seen == nil then
		seen = chance(0.3 + bot.Persona.Skill * 0.65)
		bot.Noticed[thing] = seen
	end
	if not seen then return nil end
	return thing, radius
end

local dodge
-- waiting, walking: false when something more important came up
local function wait(bot, seconds, hard)
	local t0 = now()
	while now() - t0 < seconds do
		if bot.Gone or bot.Dead or (not hard and bot.Interrupt) then return false end
		task.wait(math.min(0.1, seconds))
	end
	return true
end
local function goTo(bot, target, opts)
	opts = opts or {}
	if bot.Gone or bot.Dead or not bot.Shown then return false end
	if not opts.Timeout then
		local r = myRoot(bot)
		local t = type(target) == "function" and (select(2, pcall(target))) or target
		local d = (r and typeof(t) == "Vector3") and flat(t - r.Position).Magnitude or 60
		opts.Timeout = d / math.max(8, speedOf(bot)) * 2.2 + 6
	end
	local goal = bot.Motor:GoTo(target, opts)
	local checkAt = 0
	while not goal.Done do
		if bot.Gone or bot.Dead or (bot.Interrupt and not opts.Hard) then bot.Motor:Cancel(goal); return false end
		if opts.Until and opts.Until() then bot.Motor:Cancel(goal); return true end
		-- (v41) something about to land on it out there: drop everything (the explore loop gets it out of the way)
		if not opts.NoDodge and now() >= checkAt and bot.P.Planet ~= "Base" then
			checkAt = now() + 0.25
			if sensesDanger(bot) then
				bot.Motor:Cancel(goal)
				dodge(bot)
				return false
			end
		end
		task.wait(0.05)
	end
	return goal.Result == "Reached"
end
-- (v41) out of the red circle: away from its middle, swerving a little, a jump now and then
function dodge(bot)
	local thing, radius = sensesDanger(bot)
	local r = myRoot(bot)
	if not thing or not r then return false end
	count("Dodged")
	local away = flat(r.Position - thing.Position)
	away = away.Magnitude > 0.5 and away.Unit or B.Motor.DirOf(between(-math.pi, math.pi))
	local a = math.rad(between(-35, 35))
	away = Vector3.new(away.X * math.cos(a) - away.Z * math.sin(a), 0, away.X * math.sin(a) + away.Z * math.cos(a))
	local out = thing.Position + away * (radius + between(4, 9))
	if bot.Humanoid and chance(0.35) then bot.Humanoid.Jump = true end
	goTo(bot, Vector3.new(out.X, r.Position.Y, out.Z), {Near = 3, Timeout = 2.5, Hard = true, NoDodge = true, Path = false})
	return true
end
-- turn round on the spot: shift lock users just look, everyone else taps a key
local function face(bot, point)
	local r = myRoot(bot)
	if not r then return end
	local d = flat(point - r.Position)
	if d.Magnitude < 0.5 then return end
	local yaw = B.Motor.YawOf(d)
	if bot.Motor.ShiftLock then bot.Motor.CamYaw = yaw else bot.Motor:Tap(yaw, between(0.06, 0.12)) end
end

-- ---------------------------------------------------------------- the island's places
local function myBase(bot) return bot.P.Base end
local function zoneCenter()
	return ctx.Minigame and ctx.Minigame.ZoneCenter and ctx.Minigame.ZoneCenter() or Vector3.new(0, 68, 0)
end
-- the walkable ground under a point (not the top of a fence or a tree: about the island's own height)
local function ground(point)
	local hit = B.Nav.Ground(point + Vector3.new(0, 12, 0), 40)
	if not hit then return nil end
	local reference = zoneCenter().Y
	if math.abs(hit.Position.Y - reference) > 6 then return nil end
	return hit.Position
end
-- somewhere to stroll to on the island (near a base, the middle, between bases), on solid ground
local function islandPoint(bot)
	local bases = ctx.bases:GetChildren()
	for _ = 1, 8 do
		local roll = rng:NextNumber()
		local p = nil
		if roll < 0.3 then
			local spawnPart = myBase(bot):FindFirstChild("Spawn")
			p = spawnPart and spawnPart.Position + Vector3.new(between(-18, 18), 0, between(-18, 18))
		elseif roll < 0.55 then
			local c = zoneCenter()
			local a, d = between(0, math.pi * 2), between(10, 60)
			p = c + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		else
			local base = bases[rng:NextInteger(1, #bases)]
			local spawnPart = base:FindFirstChild("Spawn")
			if spawnPart then
				local inward = flat(zoneCenter() - spawnPart.Position)
				inward = inward.Magnitude > 1 and inward.Unit or Vector3.zero
				p = spawnPart.Position + inward * between(4, 45) + Vector3.new(between(-10, 10), 0, between(-10, 10))
			end
		end
		if p then
			local g = ground(p)
			if g then return g + Vector3.new(0, 3, 0) end
		end
	end
	local spawnPart = myBase(bot):FindFirstChild("Spawn")
	return spawnPart and spawnPart.Position or zoneCenter()
end
local function ownerOfBase(base)
	for _, profile in pairs(ctx.profiles) do if profile.Base == base then return profile end end
	for _, other in ipairs(B.List()) do if other.P.Base == base and not other.Gone then return other.P end end
	return nil
end

-- ---------------------------------------------------------------- tools for fun
local function toolPlay(bot)
	local name = (bot.P.Planet ~= "Base" and chance(0.5)) and "Raygun" or (chance(0.75) and "Bat" or "Raygun")
	if not B.Equip(bot, name) then return end
	if not wait(bot, between(0.4, 1.5)) then return end
	if name == "Bat" then
		for _ = 1, rng:NextInteger(0, 3) do
			B.Swing(bot, nil)
			if not wait(bot, between(0.3, 0.9)) then return end
		end
	elseif chance(0.45) then
		-- a few shots at nothing in particular (everyone does it)
		local r = myRoot(bot)
		for _ = 1, rng:NextInteger(1, 4) do
			if not r then break end
			local aim = r.Position + r.CFrame.LookVector * between(25, 60) + Vector3.new(between(-8, 8), between(2, 18), between(-8, 8))
			B.Shoot(bot, aim)
			if not wait(bot, between(0.22, 0.6)) then return end
		end
	end
	-- some people flick between their tools
	if chance(0.3) then
		B.Equip(bot, name == "Bat" and "Raygun" or "Bat")
		if not wait(bot, between(0.3, 1)) then return end
		B.Equip(bot, name)
		wait(bot, between(0.3, 1.2))
	end
	if chance(0.75) then B.Unequip(bot) end
end
local function fidget(bot)
	local roll = rng:NextNumber()
	local motor = bot.Motor
	if roll < 0.22 then
		for _ = 1, rng:NextInteger(1, 5) do
			if bot.Humanoid then bot.Humanoid.Jump = true end
			if not wait(bot, between(0.45, 0.8)) then return end
		end
	elseif roll < 0.42 then
		toolPlay(bot)
	elseif roll < 0.55 and bot.Persona.ShiftLock then
		motor:SetShiftLock(true)
		motor:DoSpin(chance(0.3) and 2 or 1, between(0.5, 1.1))
		wait(bot, 1.2)
	elseif roll < 0.8 then
		-- turning round to look at things
		for _ = 1, rng:NextInteger(1, 3) do
			local r = myRoot(bot)
			if not r then return end
			local yaw = between(-math.pi, math.pi)
			if motor.ShiftLock then motor.CamYaw = yaw else motor:Tap(yaw, between(0.05, 0.1)) end
			if not wait(bot, between(0.6, 2)) then return end
		end
	else
		-- a few steps this way and that
		local r = myRoot(bot)
		if r then
			local a = between(0, math.pi * 2)
			local p = r.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * between(4, 10)
			if bot.P.Planet == "Base" then
				local g = ground(p)
				if g then goTo(bot, g + Vector3.new(0, 3, 0), {Near = 2, Path = false, Timeout = 3}) end
			else
				goTo(bot, p, {Near = 2, Timeout = 3})
			end
		end
	end
end
local function afk(bot, seconds)
	bot.Afk = true
	bot.Motor:Stop()
	B.Unequip(bot)
	wait(bot, seconds)
	bot.Afk = false
end

-- ---------------------------------------------------------------- the pen: planting and hatching
local function plantCap(bot) return math.min(Config.MaxGrowingEggs, 14 + bot.Persona.Tier * 2) end
local function plantEggs(bot)
	local P = bot.P
	local planted = 0
	while #P.Data.Eggs > 0 and #P.Data.GrowingEggs < plantCap(bot) and planted < 6 do
		local egg = P.Data.Eggs[1]
		local r = myRoot(bot)
		if not r then return end
		local spot = ctx.Bases.FreePlantSpot(P, egg, r.Position)
		if not spot then bot.PlantReady = now() + between(40, 90); break end
		-- next to the spot, then the click (the egg in the hand only shows on the planter's own screen)
		local away = flat(r.Position - spot)
		away = away.Magnitude > 0.5 and away.Unit or Vector3.new(1, 0, 0)
		if not goTo(bot, spot + away * between(2, 5) + Vector3.new(0, 3, 0), {Near = 3}) then return end
		if not wait(bot, between(0.25, 0.9) + bot.Persona.Reaction * 0.5) then return end
		local before = #P.Data.GrowingEggs
		ctx.Bases.PlantEgg(P, {EggId = egg.Id, Position = spot})
		if #P.Data.GrowingEggs > before then count("Planted") end
		if #P.Data.GrowingEggs == before then
			-- it didn't take (no room there after all): to the back of the queue
			table.remove(P.Data.Eggs, 1); table.insert(P.Data.Eggs, egg)
			planted += 1
		else
			planted += 1
		end
		if not wait(bot, between(0.3, 1.1)) then return end
	end
	if #P.Data.Eggs > 0 and #P.Data.GrowingEggs >= Config.MaxGrowingEggs then
		-- the pen is full: the oldest stored eggs go (a player would sell / fuse them)
		while #P.Data.Eggs > 6 do table.remove(P.Data.Eggs, 1) end
	end
end
local function readyEggs(P)
	local list = {}
	local t = os.time()
	for _, egg in ipairs(P.Data.GrowingEggs) do
		if egg.ReadyAt <= t and not (P.HatchingVisual and P.HatchingVisual[egg.Id]) then table.insert(list, egg) end
	end
	return list
end
local function hatchEggs(bot)
	local P = bot.P
	for _, egg in ipairs(readyEggs(P)) do
		local point = ctx.Bases.EggPoint(P, egg)
		if not point then continue end
		if not goTo(bot, point + Vector3.new(0, 3, 0), {Near = between(4, 7)}) then return end
		if not wait(bot, between(0.2, 0.7) + bot.Persona.Reaction * 0.4) then return end
		local pets = #P.Data.Pets
		ctx.Bases.Hatch(P, egg.Id)
		if #P.Data.Pets > pets then count("Hatched") end
		-- watching the hatch roll on its screen, then the pet walking out
		if not wait(bot, between(2.5, 6)) then return end
		if chance(0.4) then fidget(bot) end
	end
end

-- ---------------------------------------------------------------- stealing
local function eggValue(egg)
	local info = Config.Eggs[egg.EggId]
	local rarity = info and Config.Rarities[info.Rarity]
	local order = rarity and rarity.Order or 1
	return order ^ 2.2 * (0.6 + (egg.Scale or 1) * 0.4) * Config.MutationMultiplier(egg.Mutation)
end
local function stealPlan(bot)
	local P = bot.P
	local r = myRoot(bot)
	if not r then return nil end
	local best, bestScore
	local t = now()
	for _, base in ipairs(ctx.bases:GetChildren()) do
		local owner = base ~= P.Base and ownerOfBase(base)
		if owner and online(owner) and not owner.Cutscene and #owner.Data.GrowingEggs > 0 and (owner.ShieldUntil or 0) <= workspace:GetServerTimeNow()
			and not ctx.Bases.IsProtected(owner) then
			local human = not owner.IsBot
			local allowed = not human or (Config.Bots.StealFromPlayers ~= false and t - (robbedAt[owner.Player.UserId] or -1e9) >= (Config.Bots.PlayerStealCooldown or 240))
			if allowed then
				-- is the owner watching? (in or right by their pen)
				local area = base:FindFirstChild("PlantArea")
				local ownerRoot = rootOf(owner)
				local risk = 0
				if ownerRoot and area and owner.Planet == "Base" and not owner.Busy then
					local d = flat(ownerRoot.Position - area.Position).Magnitude
					risk = d < 35 and 1 or d < 80 and 0.45 or 0.15
				end
				if risk < 1 or bot.Persona.Aggression > 0.75 then
					for _, egg in ipairs(owner.Data.GrowingEggs) do
						if not (owner.HatchingVisual and owner.HatchingVisual[egg.Id]) then
							local point = ctx.Bases.EggPoint(owner, egg)
							if point then
								local d = flat(point - r.Position).Magnitude
								local score = eggValue(egg) * (1 - risk * 0.75) / (1 + d / 250) * between(0.7, 1.3)
								if human then score *= 0.8 end
								-- (v41) payback: whoever robbed it lately is the first it robs
								local robbedBy = bot.RobbedBy and bot.RobbedBy[owner]
								if robbedBy and t - robbedBy < 600 then score *= 2.5 end
								if not bestScore or score > bestScore then best, bestScore = {Owner = owner, Egg = egg, Point = point}, score end
							end
						end
					end
				end
			end
		end
	end
	return best
end
local function eggStillThere(owner, egg)
	for _, e in ipairs(owner.Data.GrowingEggs) do if e == egg then return true end end
	return false
end
-- whoever is chasing the egg in its hands (the egg's owner, close)
local function chaser(bot)
	local stolen = bot.P.Stolen
	local owner = stolen and stolen.FromProfile
	local r, o = myRoot(bot), rootOf(owner)
	if r and o and owner.Planet == "Base" and (o.Position - r.Position).Magnitude < 45 then return owner, o end
	return nil
end
local function runHome(bot)
	local P = bot.P
	local area = P.Base:FindFirstChild("PlantArea")
	if not area then return false end
	local inside = area.Position + Vector3.new(between(-area.Size.X * 0.2, area.Size.X * 0.2), 3, between(-area.Size.Z * 0.2, area.Size.Z * 0.2))
	local t0 = now()
	bot.Motor:SetShiftLock(bot.Persona.ShiftLock and chance(0.7))
	while P.Stolen and now() - t0 < Config.StealTimeout and not bot.Gone and not bot.Dead do
		local owner, ownerRoot = chaser(bot)
		bot.Motor.LookAt = (owner and bot.Motor.ShiftLock and chance(0.5)) and function() return ownerRoot.Position end or nil
		local close = ownerRoot and myRoot(bot) and (ownerRoot.Position - myRoot(bot).Position).Magnitude < 28
		goTo(bot, inside, {Near = 4, Timeout = 3, Hard = true, Evade = close and bot.Persona.Skill > 0.35})
		if bot.Interrupt and bot.Interrupt.Kind == "Hit" then bot.Interrupt = nil end
		local r = myRoot(bot)
		if r and flat(r.Position - inside).Magnitude < 6 then task.wait(0.3) end
		if not bot.Shown then break end
	end
	bot.Motor.LookAt = nil
	bot.Motor:SetShiftLock(false)
	return P.Stolen == nil
end
local function steal(bot, plan)
	local P = bot.P
	local owner, egg = plan.Owner, plan.Egg
	local point = plan.Point
	-- the careful ones stop at the fence and look round first
	if chance(0.55 - bot.Persona.Aggression * 0.3) then
		local r = myRoot(bot)
		local area = owner.Base:FindFirstChild("PlantArea")
		if r and area then
			local out = flat(r.Position - area.Position)
			out = out.Magnitude > 1 and out.Unit or Vector3.new(1, 0, 0)
			local edge = area.Position + out * (math.max(area.Size.X, area.Size.Z) * 0.5 + 6) + Vector3.new(0, 3, 0)
			if not goTo(bot, edge, {Near = 5}) then return false end
			face(bot, point)
			if not wait(bot, between(0.5, 2.5)) then return false end
			-- the owner came back: not now
			local o = rootOf(owner)
			if o and owner.Planet == "Base" and flat(o.Position - area.Position).Magnitude < 30 and bot.Persona.Aggression < 0.6 then return false end
		end
	end
	if not eggStillThere(owner, egg) then return false end
	if not goTo(bot, point + Vector3.new(0, 3, 0), {Near = between(3, 6)}) then return false end
	if not eggStillThere(owner, egg) then return false end
	-- hold F: the prompt's hold, and a person's moment to press it
	bot.Motor:Stop()
	if not wait(bot, Config.StealHoldDuration + bot.Persona.Reaction * 0.6) then return false end
	ctx.Bases.TrySteal(P, owner, egg.Id)
	if not P.Stolen then return false end
	count("Stole")
	if not owner.IsBot then robbedAt[owner.Player.UserId] = now() end
	return runHome(bot)
end

-- ---------------------------------------------------------------- the bat
local function hitRange() return Config.Bat.Range - 2 end
-- chase `target` (an entity) and swing when in reach; stop when `keepGoing` says so or time runs out
local function chaseAndHit(bot, target, seconds, keepGoing)
	local t0 = now()
	local hits = 0
	bot.Motor:SetShiftLock(bot.Persona.ShiftLock)
	local function targetRoot() return target.Bot and B.Root(target.Bot) or rootOf(target.Profile) end
	bot.Motor.LookAt = function() local tr = targetRoot(); return tr and tr.Position end
	while now() - t0 < seconds and not bot.Gone and not bot.Dead and (not keepGoing or keepGoing()) do
		local tr, r = targetRoot(), myRoot(bot)
		if not tr or not r then break end
		if target.Profile.Planet ~= bot.P.Planet or target.Profile.Busy then break end
		local d = (tr.Position - r.Position).Magnitude
		if d < 36 then B.Equip(bot, "Bat") end
		if d <= hitRange() + bot.Persona.Skill * 1.5 then
			if B.Swing(bot, target) then hits += 1; count("Hit") end
			if not keepGoing then break end
			task.wait(between(0.15, 0.4))
		else
			-- a little ahead of where it's going (better players lead their target)
			local lead = tr.AssemblyLinearVelocity * (0.2 + bot.Persona.Skill * 0.35)
			goTo(bot, function()
				local p = targetRoot()
				return p and (p.Position + flat(lead))
			end, {Near = math.max(4, hitRange() - 2), Timeout = 1.4, Hard = true, Path = d > 30, Jet = bot.P.Planet ~= "Base"})
			if bot.Interrupt and bot.Interrupt.Kind == "Hit" then bot.Interrupt = nil end
		end
	end
	bot.Motor.LookAt = nil
	return hits
end
local function flee(bot, from)
	local r = myRoot(bot)
	if not r then return end
	local away = flat(r.Position - from)
	away = away.Magnitude > 0.5 and away.Unit or B.Motor.DirOf(between(-math.pi, math.pi))
	local a = math.rad(between(-40, 40))
	local d = Vector3.new(away.X * math.cos(a) - away.Z * math.sin(a), 0, away.X * math.sin(a) + away.Z * math.cos(a))
	local target = r.Position + d * between(22, 45)
	if bot.P.Planet == "Base" then
		local g = ground(target)
		target = g and (g + Vector3.new(0, 3, 0)) or B.SpawnPoint(bot).Position
	end
	local look = bot.Motor.ShiftLock and chance(0.6)
	bot.Motor.LookAt = look and function() return from end or nil
	goTo(bot, target, {Near = 5, Evade = chance(0.6), Timeout = 5})
	bot.Motor.LookAt = nil
end
local function canBonk(bot, entity)
	local id = entity.Profile.Player.UserId
	local list = bonked[bot]
	return not list or now() - (list[id] or -1e9) > (entity.Human and between(150, 300) or 60)
end
local function markBonked(bot, entity)
	bonked[bot] = bonked[bot] or {}
	bonked[bot][entity.Profile.Player.UserId] = now()
end
-- run up, whack, run off (and sometimes come back for more)
local function hitAndRun(bot, target)
	markBonked(bot, target)
	local hits = chaseAndHit(bot, target, between(6, 12))
	local tr = target.Bot and B.Root(target.Bot) or rootOf(target.Profile)
	if hits > 0 and tr then
		flee(bot, tr.Position)
		if chance(0.22 + bot.Persona.Aggression * 0.2) then
			chaseAndHit(bot, target, between(4, 8))
			local tr2 = target.Bot and B.Root(target.Bot) or rootOf(target.Profile)
			if tr2 then flee(bot, tr2.Position) end
		end
	end
	bot.Motor:SetShiftLock(false)
	if chance(0.7) then task.delay(between(0.5, 3), function() if not bot.Gone and not bot.Interrupt then B.Unequip(bot) end end) end
end
-- someone running past with somebody else's egg: bat it out of their hands and take it home
local function snatchTarget(bot, radius)
	local r = myRoot(bot)
	if not r then return nil end
	for _, person in ipairs(people(bot.P.Planet, bot)) do
		local p = person.Profile
		if p.Stolen and p.Stolen.FromProfile ~= bot.P and (person.Root.Position - r.Position).Magnitude < radius then return person end
	end
	return nil
end
-- the egg from its own pen in somebody's hands (whoever has it now)
local function carrierOfMine(bot)
	for _, person in ipairs(people("Base", bot)) do
		local p = person.Profile
		if p.Stolen and p.Stolen.FromProfile == bot.P then return person end
	end
	return nil
end
local function defend(bot)
	local P = bot.P
	if P.Planet ~= "Base" or P.Busy then return end
	local t0 = now()
	local giveUp = 10 + bot.Persona.Aggression * 20 + bot.Persona.Focus * 10
	while now() - t0 < giveUp and not bot.Gone and not bot.Dead do
		local carrier = carrierOfMine(bot)
		if not carrier then break end
		chaseAndHit(bot, carrier, 2.5, function() return carrier.Profile.Stolen ~= nil and carrier.Profile.Stolen.FromProfile == P end)
	end
	bot.Motor:SetShiftLock(false)
	task.delay(between(1, 4), function() if not bot.Gone and not bot.Interrupt then B.Unequip(bot) end end)
end
local function snatch(bot, target)
	chaseAndHit(bot, target, between(8, 16), function() return target.Profile.Stolen ~= nil and bot.P.Stolen == nil end)
	bot.Motor:SetShiftLock(false)
	if bot.P.Stolen then B.Unequip(bot); runHome(bot) end
end

-- ---------------------------------------------------------------- the treadmill
function Brain.LeaveTreadmill(bot)
	if not bot.Treadmill then return end
	bot.Treadmill = false
	local base = bot.P.Base
	if base then base:SetAttribute("BotRunning", nil) end
	if bot.Animate then bot.Animate:SetOverlay(nil) end
	local r = B.Root(bot)
	local treadmill = base and base:FindFirstChild("Treadmill")
	local belt = treadmill and treadmill:FindFirstChild("Belt")
	if r then
		if belt then r.CFrame = r.CFrame + belt.CFrame.RightVector * (belt.Size.X / 2 + 3.5) + Vector3.new(0, 0.5, 0) end
		r.Anchored = false
		pcall(function() r:SetNetworkOwner(nil) end)
	end
	if bot.Motor then bot.Motor.Paused = false end
	if bot.Humanoid then bot.Humanoid.Jump = true end
end
local function treadmill(bot)
	local base = bot.P.Base
	local tm = base and base:FindFirstChild("Treadmill")
	local belt = tm and tm:FindFirstChild("Belt")
	if not belt then return end
	goTo(bot, belt.Position + Vector3.new(0, 3, 0), {Near = 5, Timeout = 8})
	if bot.Interrupt or bot.Dead then return end
	local r, humanoid = myRoot(bot), bot.Humanoid
	-- (it steps on from wherever it got to by the belt: rails and the frame stop a straight walk sometimes)
	if not r or not humanoid or bot.P.Stolen or flat(r.Position - belt.Position).Magnitude > 10 then return end
	-- held on the belt facing forward, running in place (Treadmill.client does the same for players)
	local hip = humanoid.HipHeight + r.Size.Y / 2
	local top = belt.CFrame * CFrame.new(0, belt.Size.Y / 2, 0)
	bot.Motor:Stop()
	bot.Motor.Paused = true
	r.Anchored = true
	r.CFrame = CFrame.lookAt(top.Position + Vector3.new(0, hip, 0), top.Position + Vector3.new(0, hip, 0) + belt.CFrame.LookVector)
	bot.Treadmill = true
	base:SetAttribute("BotRunning", true)
	base:SetAttribute("BotWalkSpeed", humanoid.WalkSpeed)
	if bot.Animate then
		bot.Animate:StopCore(0.15)
		bot.Animate:SetOverlay(type(bot.AnimSet.run) == "table" and bot.AnimSet.run[1][1] or bot.AnimSet.run, math.clamp(humanoid.WalkSpeed / 16, 1, 2.2))
	end
	local seconds = between(15, 45) * (1.6 - bot.Persona.Tier * 0.12) * (0.6 + bot.Persona.Focus * 0.6)
	wait(bot, seconds)
	Brain.LeaveTreadmill(bot)
end

-- ---------------------------------------------------------------- upgrades it can afford (coins only, like the shop)
local function shop(bot)
	local P = bot.P
	local data = P.Data
	local spawnPart = P.Base:FindFirstChild("Spawn")
	if spawnPart and not ctx.near(P, spawnPart, Config.BaseInteractionDistance - 10) then
		if not goTo(bot, spawnPart.Position + Vector3.new(0, 3, 0), {Near = 8}) then return end
	end
	if not wait(bot, between(1.5, 5)) then return end   -- the upgrades menu is open on its screen
	local options = {}
	local function can(cost) return cost and data.Coins >= cost * 1.15 end
	local nextTread = Config.Treadmills[data.TreadmillLevel + 1]
	if nextTread and can(nextTread.Cost) then table.insert(options, function() ctx.Speed.Upgrade(P) end) end
	for _, kind in ipairs({"Jetpack", "Suit", "Cargo", "Rocket"}) do
		local list = kind == "Jetpack" and Config.Jetpacks or kind == "Suit" and Config.Suits or kind == "Cargo" and Config.Cargo or Config.Rockets
		local level = data[kind == "Jetpack" and "JetpackLevel" or kind == "Suit" and "SuitLevel" or kind == "Cargo" and "CargoLevel" or "RocketLevel"]
		local nextOne = list[level + 1]
		if nextOne and can(nextOne.Cost) then table.insert(options, function() ctx.Expeditions.Upgrade(P, kind) end) end
	end
	for _, trail in ipairs(Config.TrailList) do
		if not data.Trails[trail.Id] and can(trail.Cost) and (data.Trail == "" or (Config.Trails[data.Trail] and trail.Mult > Config.Trails[data.Trail].Mult)) then
			table.insert(options, function() ctx.Speed.BuyTrail(P, trail.Id) end)
			break
		end
	end
	if #options > 0 then
		pcall(options[rng:NextInteger(1, #options)])
		if bot.Model then bot.Model:SetAttribute("PFESuitLevel", data.SuitLevel) end
	end
end

-- ---------------------------------------------------------------- flights (like a player's: at the rocket through the flight)
local function fly(bot, to)
	local P = bot.P
	local from = P.Planet
	P.Busy = true
	bot.Motor:Stop()
	B.Unequip(bot)
	local r = myRoot(bot)
	if r then r.Anchored = true end
	local fromGalaxy = from ~= "Base" and Config.Planets[from] and Config.Planets[from].Galaxy or "MilkyWay"
	local toGalaxy = to ~= "Base" and Config.Planets[to] and Config.Planets[to].Galaxy or "MilkyWay"
	local duration = Config.FlightDuration + (fromGalaxy ~= toGalaxy and Config.GalaxyJumpBonus or 0)
	bot.Flight = {From = from, To = to, At = workspace:GetServerTimeNow(), Duration = duration}
	B.Publish(bot)
	wait(bot, duration, true)
	if bot.Gone then return end
	bot.Flight = nil
	P.Planet = to
	if to == "Base" then
		B.Place(bot, B.SpawnPoint(bot))
		if ctx.Expeditions.BotEnd then ctx.Expeditions.BotEnd(P) end
	else
		P.Oxygen = ctx.maxOxygen(P)
		P.Expedition = {Planet = to, Eggs = {}, Id = ctx.Data.Guid(), UsedSpots = {}, Seed = ctx.mapSeed()}
		P.Data.VisitedPlanets[to] = true
		local model = ctx.planets:FindFirstChild(to)
		local landing = model and model:FindFirstChild("Landing")
		if Brain.Watched(to) and landing then
			B.Place(bot, CFrame.new(landing.Position + Vector3.new(0, 4, 0)) * CFrame.Angles(0, between(0, math.pi * 2), 0))
		else
			B.Hide(bot)
		end
	end
	local nr = myRoot(bot)
	if nr and bot.Shown then nr.Anchored = true end
	B.Publish(bot)
	wait(bot, Config.LandingDuration, true)
	nr = myRoot(bot)
	if nr and bot.Shown then
		nr.Anchored = false
		pcall(function() nr:SetNetworkOwner(nil) end)
	end
	P.Busy = false
	pcall(ctx.setMovement, P)
end
Brain.Fly = fly

-- (v41) where the action is: the boss's / the Golden Egg's planet - if its rocket reaches and somebody's there to see it
local function hotPlanet(bot)
	local L = ctx.PlanetLife
	if not L then return nil end
	local range = Config.Rockets[bot.P.Data.RocketLevel] and Config.Rockets[bot.P.Data.RocketLevel].Range or 1
	local function ok(id) return Config.Planets[id] ~= nil and (Config.Planets[id].RequiredRange or 0) <= range and Brain.Watched(id) end
	local b = L.Bosses and L.Bosses.Current()
	if b and not b.Dead and ok(b.Planet) and (bot.Persona.Aggression > 0.25 or bot.Persona.Skill > 0.6) then return b.Planet end
	local race = L.GoldenRace and L.GoldenRace.Current()
	if race and ok(race.Planet) and bot.Persona.Greed > 0.35 then return race.Planet end
	return nil
end
-- where to: within the rocket's reach, mostly where the people are
local function choosePlanet(bot)
	local P = bot.P
	local range = Config.Rockets[P.Data.RocketLevel] and Config.Rockets[P.Data.RocketLevel].Range or 1
	local list = {}
	for _, planet in ipairs(Config.PlanetOrder) do
		if planet.RequiredRange <= range then table.insert(list, planet.Id) end
	end
	if #list == 0 then return nil end
	local hot = hotPlanet(bot)
	if hot and chance(0.8) then return hot end
	local crowded = {}
	for _, profile in pairs(ctx.profiles) do
		if Config.Planets[profile.Planet] and table.find(list, profile.Planet) then table.insert(crowded, profile.Planet) end
	end
	if #crowded > 0 and chance(0.72) then return crowded[rng:NextInteger(1, #crowded)] end
	-- the further it can reach, the further it likes to go
	local pickFrom = math.max(1, #list - rng:NextInteger(0, 2))
	return list[rng:NextInteger(math.max(1, pickFrom - 1), #list)]
end
local function trip(bot, destination)
	local P = bot.P
	local planetId = destination or choosePlanet(bot)
	local launch = P.Base:FindFirstChild("Launch")
	if not planetId or not launch then return end
	if not goTo(bot, launch.Position + Vector3.new(0, 1, 0), {Near = 5}) then return end
	-- the launch prompt, the planet map, a choice
	if not wait(bot, between(0.8, 3.2)) then return end
	if P.Stolen then return end
	fly(bot, planetId)
end

-- ---------------------------------------------------------------- on a planet
local function deckOf(planetId)
	local model = ctx.planets:FindFirstChild(planetId)
	return model and (model:FindFirstChild("LandingDeck") or model:FindFirstChild("Landing"))
end
local function cargoFull(P)
	local e = P.Expedition
	return e and #e.Eggs >= ctx.capacity(P)
end
-- enough air to get back? (the careful ones turn round earlier; now and then somebody cuts it too fine)
local function airLow(bot)
	local P = bot.P
	local planet = Config.Planets[P.Planet]
	if not planet then return false end
	local deck = deckOf(P.Planet)
	local r = myRoot(bot)
	local d = (deck and r and bot.Shown) and flat(deck.Position - r.Position).Magnitude or 120
	local seconds = d / math.max(10, speedOf(bot)) + 5
	local margin = bot.AirMargin or 1.3
	-- (v41) the weather eats air faster (sandstorm, blizzard...): the ones who can judge it count it in
	local weather = 1
	if ctx.AirMultiplier and bot.Persona.Skill > 0.3 then
		local ok, m = pcall(ctx.AirMultiplier, P)
		if ok and type(m) == "number" then weather = math.max(1, m) end
	end
	return P.Oxygen <= seconds * planet.OxygenMultiplier * weather * margin + 6
end
local function pickEgg(bot, planetId)
	local r = myRoot(bot)
	if not r then return nil end
	local humans = {}
	for _, p in pairs(ctx.profiles) do
		local hr = p.Planet == planetId and ctx.root(p.Player)
		if hr then table.insert(humans, hr.Position) end
	end
	local best, bestScore
	for _, item in ipairs(ctx.Expeditions.PlanetEggs(planetId)) do
		local proxy = item:FindFirstChild("Pickup")
		local owner = claimed[item]
		if proxy and not item:GetAttribute("IslandId") and (owner == nil or owner == bot or owner.Gone) then
			local d = (proxy.Position - r.Position).Magnitude
			local free = true
			for _, h in ipairs(humans) do if (h - proxy.Position).Magnitude < 14 then free = false; break end end
			if (free or bot.Persona.Greed > 0.8) and d < 360 then
				local rarity = Config.Rarities[item:GetAttribute("Rarity") or ""]
				local value = (rarity and rarity.Order or 1) ^ (0.6 + bot.Persona.Greed)
				local score = d / (1 + value * 0.35) + rng:NextNumber(0, 70) * (1.2 - bot.Persona.Skill)
				if not bestScore or score < bestScore then best, bestScore = item, score end
			end
		end
	end
	if best then
		for item, b in pairs(claimed) do if b == bot then claimed[item] = nil end end
		claimed[best] = bot
	end
	return best
end
local function nearAlien(bot, radius)
	local r = myRoot(bot)
	if not r or not ctx.Aliens or not ctx.Aliens.List then return nil end
	local best, bestD
	for _, record in ipairs(ctx.Aliens.List(bot.P.Planet) or {}) do
		if not record.Dead and record.Root and record.Root.Parent then
			local d = (record.Root.Position - r.Position).Magnitude
			if d < radius and (not bestD or d < bestD) then best, bestD = record, d end
		end
	end
	return best
end
local function shootAlien(bot, record)
	if not B.Equip(bot, "Raygun") then return end
	local shots = rng:NextInteger(3, 9)
	for _ = 1, shots do
		if record.Dead or not record.Root or not record.Root.Parent then break end
		face(bot, record.Root.Position)
		if not wait(bot, between(0.2, 0.45)) then return end
		-- aim: good players hit, others miss a bit
		local miss = (1 - bot.Persona.Skill) * 6
		B.Shoot(bot, record.Root.Position + Vector3.new(between(-miss, miss), between(0, 2.2), between(-miss, miss)))
	end
	if chance(0.6) then B.Unequip(bot) end
end
-- someone near carrying an egg on this planet (fair game for the bat)
local function prey(bot, radius)
	local r = myRoot(bot)
	if not r then return nil end
	for _, person in ipairs(people(bot.P.Planet, bot)) do
		local e = person.Profile.Expedition
		if e and e.CarryingEgg and (person.Root.Position - r.Position).Magnitude < radius then return person end
	end
	return nil
end
-- a plausible place to be when someone lands and sees it (out exploring, not standing on the pad)
local function showOnPlanet(bot)
	local P = bot.P
	local deck = deckOf(P.Planet)
	if not deck then return end
	local at = B.Nav.PlanetSpot(P.Planet, deck.Position + Vector3.new(0, 4, 0), 70, 260)
	B.Place(bot, CFrame.new(at) * CFrame.Angles(0, between(0, math.pi * 2), 0))
end
local function loadAtRocket(bot)
	local P = bot.P
	local deck = deckOf(P.Planet)
	if not deck then return end
	-- (v41) with THE GOLDEN EGG everybody is after it: zig-zag (the better ones)
	local golden = P.Expedition and P.Expedition.CarryingEgg and P.Expedition.CarryingEgg.GoldenRace
	goTo(bot, function() return deck.Position + Vector3.new(0, 4, 0) end, {Near = 9, Jet = true, Timeout = 80, Evade = golden and bot.Persona.Skill > 0.35 or nil})
	-- standing on the pad loads it (Expeditions.Tick, like a player)
	local t0 = now()
	while P.Expedition and P.Expedition.CarryingEgg and now() - t0 < 2.5 do
		ctx.Expeditions.BotLoad(P)
		task.wait(0.25)
	end
end
local function flyHome(bot)
	local P = bot.P
	if bot.Shown then
		local deck = deckOf(P.Planet)
		if deck then goTo(bot, function() return deck.Position + Vector3.new(0, 4, 0) end, {Near = 9, Jet = true, Timeout = 90, Hard = true}) end
		if P.Expedition and P.Expedition.CarryingEgg then ctx.Expeditions.BotLoad(P) end
		wait(bot, 0.6 + bot.Persona.Reaction, true)       -- hold "Fly home"
	elseif P.Expedition and P.Expedition.CarryingEgg then
		-- (out of sight it had made it back with the egg)
		table.insert(P.Expedition.Eggs, P.Expedition.CarryingEgg)
		P.Expedition.CarryingEgg = nil
	end
	if P.Expedition and P.Expedition.CarryingEgg then
		if P.Expedition.CarryingEgg.GoldenRace and bot.Shown then
			-- (v41) never home with the race's egg unloaded: it falls where it stood
			pcall(ctx.Expeditions.DropCarry, P)
		else
			ctx.Expeditions.ClearCarry(P)
		end
		if P.Expedition then P.Expedition.CarryingEgg = nil end
	end
	for item, b in pairs(claimed) do if b == bot then claimed[item] = nil end end
	fly(bot, "Base")
end
-- out of sight: it keeps exploring (an egg every so often, the air going down)
local function exploreUnseen(bot, planetId)
	local P = bot.P
	local e = P.Expedition
	if e and not cargoFull(P) and chance(0.035 + bot.Persona.Skill * 0.04) then
		local zone = math.clamp(rng:NextInteger(1, 3) + (bot.Persona.Greed > 0.6 and 1 or 0), 1, 5)
		local info = ctx.Expeditions.RollEgg(1, planetId, zone)
		if info then table.insert(e.Eggs, {Id = ctx.Data.Guid(), EggId = info.Id, Scale = ctx.Expeditions.RollSize(), Mutation = ctx.Expeditions.RollMutation(1, planetId)}) end
	end
	task.wait(1)
end
-- ---------------------------------------------------------------- (v41) the living planets
local smashing = {}       -- a crystal / rock / chest -> the bot breaking it (two don't crowd one)
local function lifeOf() return ctx.PlanetLife end
local function bossOn(planetId)
	local L = lifeOf()
	local b = L and L.Bosses and L.Bosses.Current()
	if b and not b.Dead and (not planetId or b.Planet == planetId) then return b end
	return nil
end
local function goldenOn(planetId)
	local L = lifeOf()
	local race = L and L.GoldenRace and L.GoldenRace.Current()
	if race and (not planetId or race.Planet == planetId) then return race end
	return nil
end
-- the Golden Egg race: does this bot go for it? (decided once a race; a few seconds to notice; never more than 3 at once)
local function goldenHunter(bot, race)
	if bot.GoldenFor ~= race then
		bot.GoldenFor = race
		local rallied = bot.Rallied and bot.Rallied.For == "Golden" and bot.Rallied.Planet == race.Planet
		bot.GoldenWish = rallied or chance(0.3 + bot.Persona.Greed * 0.45)
		bot.GoldenAfter = (race.StartedAt or 0) + between(5, 16) * (1.3 - bot.Persona.Skill * 0.5)
	end
	if not bot.GoldenWish or workspace:GetServerTimeNow() < bot.GoldenAfter then return false end
	local hunters = 0
	for _, other in ipairs(B.List()) do if other ~= bot and other.GoldenHunting == race then hunters += 1 end end
	return hunters < 3
end
local function goldenHunt(bot, race)
	local P = bot.P
	count("Golden")
	bot.GoldenHunting = race
	local t0 = now()
	while now() - t0 < 150 and not bot.Gone and not bot.Dead and bot.Shown and not P.Busy and goldenOn(P.Planet) == race do
		if airLow(bot) or (bot.Interrupt and bot.Interrupt.Kind ~= "Hit") then break end
		if P.Expedition and P.Expedition.CarryingEgg then break end   -- got it: explore's loop runs it to the rocket
		if dodge(bot) then continue end
		local carrier = race.Carrier
		if carrier and carrier ~= P then
			-- bat it out of their hands (it falls, or lands in this bot's)
			local who = entityOf(carrier)
			if not who or not rootOf(carrier) or carrier.Planet ~= P.Planet then
				wait(bot, 0.5)
			else
				chaseAndHit(bot, who, between(4, 8), function() return race.Carrier == carrier and goldenOn(P.Planet) == race end)
				bot.Motor:SetShiftLock(false)
			end
		elseif race.Item and race.Item.Parent then
			local item = race.Item
			local proxy = item:FindFirstChild("Pickup")
			if not proxy then break end
			B.Unequip(bot)
			goTo(bot, function() return item.Parent and proxy.Position or nil end, {Near = 4.5, Jet = true, Hard = true})
			local r = myRoot(bot)
			if item.Parent and r and (proxy.Position - r.Position).Magnitude < 12 then
				if wait(bot, 0.25 + bot.Persona.Reaction * 0.4, true) and item.Parent and ctx.Expeditions.BotPickup(P, item) then count("GoldenPickup") end
			end
		else
			wait(bot, 0.5)
		end
		if bot.Interrupt and bot.Interrupt.Kind == "Hit" then bot.Interrupt = nil end
	end
	bot.GoldenHunting = nil
end
-- the boss: everybody's fight. Some go in with the bat, the rest keep their distance and shoot
local function fightBoss(bot, b)
	local P = bot.P
	count("Boss")
	if bot.Ranged == nil then bot.Ranged = chance(0.45) end
	local fight = between(25, 70) * (0.6 + bot.Persona.Aggression * 0.8)
	local stopAt = now() + fight
	local giveUp = now() + fight + 120     -- (the walk over there doesn't count - up to a point)
	bot.Motor:SetShiftLock(bot.Persona.ShiftLock)
	while now() < stopAt and now() < giveUp and bossOn(P.Planet) == b and not bot.Gone and not bot.Dead and bot.Shown and not P.Busy do
		if airLow(bot) or (P.Expedition and P.Expedition.CarryingEgg) then break end
		if bot.Interrupt and bot.Interrupt.Kind ~= "Hit" then break end
		bot.Interrupt = nil
		if dodge(bot) then continue end
		local r = myRoot(bot)
		if not r or not b.Hitbox or not b.Hitbox.Parent then break end
		local centre = b.Hitbox.Position
		local d = flat(centre - r.Position).Magnitude
		local reach = math.max(b.Size.X, b.Size.Z) * 0.55
		bot.Motor.LookAt = d < 150 and function() return b.Hitbox.Position end or nil
		if d > reach + 90 then
			-- still on the way there
			stopAt = math.max(stopAt, now() + fight * 0.5)
			goTo(bot, function() return b.Hitbox.Parent and b.Hitbox.Position or nil end, {Near = reach + 60, Timeout = 6, Jet = true})
		elseif b.Under or workspace:GetServerTimeNow() < (b.WakeAt or 0) then
			-- underground / still getting up: keep away and wait for it
			if d < reach + 14 then
				local away = flat(r.Position - centre)
				away = away.Magnitude > 0.5 and away.Unit or Vector3.new(1, 0, 0)
				local spot = centre + away * (reach + between(20, 34))
				goTo(bot, Vector3.new(spot.X, r.Position.Y, spot.Z), {Near = 4, Timeout = 2.5, Path = false})
			else
				wait(bot, between(0.3, 0.7))
			end
		elseif bot.Ranged then
			-- the raygun from 25-55 studs out, circling a bit
			if d > reach + 60 or d < reach + 16 then
				local away = flat(r.Position - centre)
				away = away.Magnitude > 0.5 and away.Unit or Vector3.new(1, 0, 0)
				local a = math.rad(between(-40, 40))
				away = Vector3.new(away.X * math.cos(a) - away.Z * math.sin(a), 0, away.X * math.sin(a) + away.Z * math.cos(a))
				local spot = centre + away * (reach + between(25, 50))
				goTo(bot, Vector3.new(spot.X, r.Position.Y, spot.Z), {Near = 5, Timeout = 3, Jet = d > 120, Path = false})
			elseif B.Equip(bot, "Raygun") then
				face(bot, centre)
				local miss = (1 - bot.Persona.Skill) * 6
				if B.Shoot(bot, centre + Vector3.new(between(-miss, miss), between(-1, b.Size.Y * 0.3), between(-miss, miss))) then count("BossShot") end
				wait(bot, between(0.25, 0.55))
			else
				wait(bot, 0.3)
			end
		else
			-- the bat: right up to it, a few swings, back off now and then
			B.Equip(bot, "Bat")
			if d > reach + Config.Bat.Range - 1 then
				goTo(bot, function() return b.Hitbox.Parent and b.Hitbox.Position or nil end,
					{Near = reach + Config.Bat.Range - 2.5, Timeout = 2.5, Hard = true, Jet = d > 120, Path = false})
			else
				face(bot, centre)
				if B.SwingAt(bot, b.Model) then count("BossHit") end
				wait(bot, between(0.12, 0.35))
				if chance(0.08 + (1 - bot.Persona.Aggression) * 0.1) then flee(bot, centre) end
			end
		end
	end
	bot.Motor.LookAt = nil
	bot.Motor:SetShiftLock(false)
	if chance(0.6) then B.Unequip(bot) end
end
-- crystals, ore rocks, geodes, frozen eggs, volcanic bombs, chests: bat them open
local function smashable(bot, radius)
	local L = lifeOf()
	local r = myRoot(bot)
	if not L or not L.ThingsNear or not r then return nil end
	local best, bestD
	for _, thing in ipairs(L.ThingsNear(bot.P.Planet, r.Position, radius)) do
		local br = thing.Breakable
		local owner = smashing[thing.Model]
		if br and br.Kind ~= "Wall" and (owner == nil or owner == bot or owner.Gone) then
			local d = (thing.Center - r.Position).Magnitude
			if not bestD or d < bestD then best, bestD = thing, d end
		end
	end
	return best
end
local function smash(bot, thing)
	local P = bot.P
	local model = thing.Model
	smashing[model] = bot
	count("Smash")
	local t0 = now()
	B.Equip(bot, "Bat")
	while model.Parent and now() - t0 < 16 and not bot.Gone and not bot.Dead and bot.Shown and not P.Busy do
		if bot.Interrupt or airLow(bot) then break end
		if dodge(bot) then continue end
		local r = myRoot(bot)
		if not r then break end
		local c = model.PrimaryPart and model.PrimaryPart.Position or thing.Center
		local d = (c - r.Position).Magnitude
		if d > Config.Bat.Range + thing.Radius then
			goTo(bot, c, {Near = Config.Bat.Range + thing.Radius - 2.5, Timeout = 5, Jet = true})
		else
			face(bot, c)
			B.SwingAt(bot, model)
			wait(bot, between(0.12, 0.4))
		end
	end
	if smashing[model] == bot then smashing[model] = nil end
	if not model.Parent then count("Smashed") end
end
-- the weather wants shelter (a blizzard's campfire, acid rain's mushroom, a flare's shade rock): in under it for a while,
-- then out again for the eggs (and back) - the ones who know the planet (decided once a weather)
local function shelterNeed(bot)
	local L = lifeOf()
	local r = myRoot(bot)
	if not L or not L.ShelterFor or not r then return nil end
	local _, weatherId = L.Weather(bot.P.Planet)
	if bot.ShelterWeather ~= weatherId then
		bot.ShelterWeather = weatherId
		bot.ShelterWish = chance(0.35 + bot.Persona.Skill * 0.55)
		bot.ShelterRest = 0
	end
	if not bot.ShelterWish or now() < (bot.ShelterRest or 0) then return nil end
	return L.ShelterFor(bot.P.Planet, r.Position, 170)
end
local function takeShelter(bot, shelter)
	count("Shelter")
	local a, d = between(0, math.pi * 2), between(0, shelter.Radius * 0.55)
	local spot = shelter.Position + Vector3.new(math.cos(a) * d, 4, math.sin(a) * d)
	B.Unequip(bot)
	if goTo(bot, spot, {Near = 3, Jet = true, Timeout = 20}) then
		face(bot, shelter.Position)
		local stay = between(5, 14)
		local t0 = now()
		while now() - t0 < stay and not bot.Interrupt do
			if dodge(bot) then break end
			if chance(0.15) then fidget(bot) else wait(bot, between(0.5, 1.5)) end
		end
	end
	bot.ShelterRest = now() + between(8, 25)
end

local function inviteOpen()
	return ctx.Minigame and ctx.Minigame.InviteOpen and ctx.Minigame.InviteOpen()
end
-- JOIN on the Meteor Run invitation from a planet: straight into the circle (the egg in its hands is lost, the rocket's
-- cargo goes home), like a player pressing JOIN out there
local function joinRunFromPlanet(bot)
	local P = bot.P
	if P.Busy then return end
	if P.Expedition and P.Expedition.CarryingEgg then ctx.Expeditions.ClearCarry(P); P.Expedition.CarryingEgg = nil end
	B.Unequip(bot)
	ctx.Expeditions.BotEnd(P)
	P.Planet = "Base"
	for item, b in pairs(claimed) do if b == bot then claimed[item] = nil end end
	local c = zoneCenter()
	local a, d = between(0, math.pi * 2), between(0, Config.Minigame.ZoneRadius * 0.45)
	B.Place(bot, CFrame.new(c + Vector3.new(math.cos(a) * d, 4, math.sin(a) * d)) * CFrame.Angles(0, between(0, math.pi * 2), 0))
	B.Publish(bot)
end
local function explore(bot)
	local P = bot.P
	local planetId = P.Planet
	local stay = between(80, 240) * (0.7 + bot.Persona.Greed * 0.6)
	-- (it learns: every time it ran out of air out there it turns back a little sooner)
	bot.AirMargin = 1.05 + bot.Persona.Skill * 0.7 + between(-0.15, 0.25) + math.min(0.9, (bot.AirLessons or 0) * 0.3)
	local t0 = now()
	while P.Planet == planetId and not P.Busy and not bot.Gone and not bot.Dead and not P.Minigame do
		-- someone landed / everyone left
		local watched = Brain.Watched(planetId)
		if watched and not bot.Shown then showOnPlanet(bot)
		elseif not watched and bot.Shown then
			if P.Expedition and P.Expedition.CarryingEgg then
				if P.Expedition.CarryingEgg.GoldenRace then
					-- (v41) the race's egg stays on the planet for the next people there
					pcall(ctx.Expeditions.DropCarry, P)
					if P.Expedition then P.Expedition.CarryingEgg = nil end
				else
					table.insert(P.Expedition.Eggs, P.Expedition.CarryingEgg)
					P.Expedition.CarryingEgg = nil
					ctx.Expeditions.ClearCarry(P)
				end
			end
			B.Unequip(bot)
			B.Hide(bot)
		end
		if bot.Interrupt then return end
		if inviteOpen() then
			if bot.MeteorWish == nil then bot.MeteorWish = chance(0.55 + bot.Persona.Greed * 0.25) end
			if bot.MeteorWish then return joinRunFromPlanet(bot) end
		end
		local carrying = P.Expedition and P.Expedition.CarryingEgg
		-- (the boss / the Golden Egg keep it out there a bit longer)
		local hot = bossOn(planetId) or goldenOn(planetId)
		if cargoFull(P) or airLow(bot) or (now() - t0 > stay and not (hot and now() - t0 < stay + 90)) then
			if not (carrying and carrying.GoldenRace and not airLow(bot) and not cargoFull(P)) then return flyHome(bot) end
		end
		if not bot.Shown then
			bot.Doing = "unseen"
			exploreUnseen(bot, planetId)
			continue
		end
		if dodge(bot) then continue end
		if carrying then
			bot.Doing = "load"
			B.Unequip(bot)
			loadAtRocket(bot)
		else
			local alien = nearAlien(bot, 42)
			local victim = prey(bot, bot.Persona.Aggression > 0.55 and 90 or 40)
			local boss = bossOn(planetId)
			if boss and bot.BossFor ~= boss then
				bot.BossFor = boss
				-- (it flew out because of the boss: of course it fights)
				local rallied = bot.Rallied and bot.Rallied.For == "Boss" and bot.Rallied.Planet == planetId
				bot.BossWish = rallied or chance(0.4 + bot.Persona.Aggression * 0.45 + bot.Persona.Skill * 0.1)
			end
			local race = goldenOn(planetId)
			local shelter = shelterNeed(bot)
			local r = myRoot(bot)
			if shelter and r and flat(shelter.Position - r.Position).Magnitude > shelter.Radius - 2 then
				bot.Doing = "shelter"
				takeShelter(bot, shelter)
			elseif race and race.Carrier ~= P and (race.Carrier or (race.Item and race.Item.Parent)) and goldenHunter(bot, race) then
				bot.Doing = "golden"
				goldenHunt(bot, race)
			elseif boss and bot.BossWish and r and flat(boss.Position - r.Position).Magnitude < 1800 then
				bot.Doing = "boss"
				fightBoss(bot, boss)
			elseif alien and chance(0.35 + bot.Persona.Skill * 0.4) then
				bot.Doing = "alien"
				shootAlien(bot, alien)
			elseif victim and chance(bot.Persona.Aggression * 0.9) and canBonk(bot, victim) then
				bot.Doing = "prey"
				markBonked(bot, victim)
				chaseAndHit(bot, victim, between(6, 12), function() return victim.Profile.Expedition ~= nil and victim.Profile.Expedition.CarryingEgg ~= nil and not P.Expedition.CarryingEgg end)
				bot.Motor:SetShiftLock(false)
			else
				local thing = chance(0.3 + bot.Persona.Greed * 0.5) and smashable(bot, 55 + bot.Persona.Greed * 40) or nil
				local item = not thing and pickEgg(bot, planetId)
				if thing then
					bot.Doing = "smash"
					smash(bot, thing)
				elseif item then
					bot.Doing = "egg"
					local proxy = item:FindFirstChild("Pickup")
					goTo(bot, function() return item.Parent and proxy.Position or nil end, {Near = 4.5, Jet = true})
					local r = myRoot(bot)
					if item.Parent and r and (proxy.Position - r.Position).Magnitude < 12 then
						-- hold E
						if wait(bot, 0.3 + bot.Persona.Reaction * 0.5) and item.Parent then
							B.Unequip(bot)
							if ctx.Expeditions.BotPickup(P, item) then count("PickedUp") end
						end
					end
					claimed[item] = nil
				else
					-- nothing close: off exploring (further out for the greedy ones)
					bot.Doing = "roam"
					local r = myRoot(bot)
					if r then
						local deck = deckOf(planetId)
						local origin = deck and deck.Position or r.Position
						local spot = B.Nav.PlanetSpot(planetId, origin + Vector3.new(0, 4, 0), 80 + bot.Persona.Greed * 200, 220 + bot.Persona.Greed * 500)
						goTo(bot, spot, {Near = 8, Jet = true, Timeout = 25})
					end
				end
				if chance(0.08) then fidget(bot) end
			end
		end
		task.wait(between(0.1, 0.5))
	end
	for item, b in pairs(claimed) do if b == bot then claimed[item] = nil end end
end
function Brain.DevExplore(bot, planetId)
	local P = bot.P
	P.Planet = planetId
	P.Oxygen = ctx.maxOxygen(P)
	P.Expedition = {Planet = planetId, Eggs = {}, Id = ctx.Data.Guid(), UsedSpots = {}, Seed = ctx.mapSeed()}
	B.Publish(bot)
end

-- ---------------------------------------------------------------- the Meteor Run
local function meteorQueue(bot)
	local MG = Config.Minigame
	local c = zoneCenter()
	local a, d = between(0, math.pi * 2), between(4, MG.ZoneRadius * 0.6)
	local spot = c + Vector3.new(math.cos(a) * d, 3, math.sin(a) * d)
	if not goTo(bot, spot, {Near = 5}) then return end
	count("Queued")
	while inviteOpen() and not bot.P.Minigame and not bot.Gone do
		if chance(0.35) then fidget(bot) end
		if not wait(bot, between(0.6, 2.2)) then return end
	end
end
-- the meteor it can reach soonest: run under where it will be, jetpack up as it arrives
local function planMeteor(bot, run)
	local r = myRoot(bot)
	if not r then return nil end
	local Minigame = ctx.Minigame
	local pack = bot.Motor:Pack()
	local ws = speedOf(bot)
	local t = workspace:GetServerTimeNow()
	local groundY = r.Position.Y - 3
	local best, bestT
	for _, meteor in pairs(run.Meteors) do
		if not meteor.Taken and t >= meteor.T0 - 0.5 then
			for k = 1, 24 do
				local at = t + k * 0.5
				if at > meteor.T0 + meteor.Life - 0.5 then break end
				local egg = Minigame.MeteorPosition(meteor, at) + Vector3.new(0, 2, 0)
				local climb = math.max(0, egg.Y - groundY - 7) / pack.Thrust
				local runTime = flat(egg - r.Position).Magnitude / ws
				if climb < bot.Motor.Jet.Charge - 0.5 and runTime + climb * 0.6 + 0.6 <= at - t then
					if not bestT or at < bestT then best, bestT = meteor, at end
					break
				end
			end
		end
	end
	return best, bestT
end
local function chaseMeteor(bot, run, meteor, at)
	local Minigame = ctx.Minigame
	local P = bot.P
	local entry = Minigame.BotEntry(P)
	local count = entry and #entry.Eggs or 0
	local function eggAt(time) return Minigame.MeteorPosition(meteor, time) + Vector3.new(0, 2, 0) end
	-- under it
	local function under()
		local p = eggAt(math.max(workspace:GetServerTimeNow(), at - 0.4))
		local r = myRoot(bot)
		return Vector3.new(p.X, r and r.Position.Y or p.Y, p.Z)
	end
	local pack = bot.Motor:Pack()
	local function climbTime()
		local r = myRoot(bot)
		return r and math.max(0, eggAt(at).Y - r.Position.Y - 5) / pack.Thrust or 1
	end
	goTo(bot, under, {Near = 8, Path = false, Timeout = math.max(1, at - workspace:GetServerTimeNow()),
		Until = function() return meteor.Taken or workspace:GetServerTimeNow() >= at - climbTime() - 0.3 end})
	if meteor.Taken or P.Minigame ~= run then return end
	-- up
	if bot.Humanoid then bot.Humanoid.Jump = true end
	bot.Motor:JetFor(climbTime() + 2)
	local t0 = now()
	goTo(bot, function()
		local p = eggAt(workspace:GetServerTimeNow() + 0.25)
		return p
	end, {Near = 2.5, Path = false, Timeout = climbTime() + 3, Exact = true,
		Until = function()
			local e = Minigame.BotEntry(P)
			return meteor.Taken or (e and #e.Eggs > count) or P.Minigame ~= run
		end})
	bot.Motor:JetOff()
	local e = Minigame.BotEntry(P)
	if e and #e.Eggs > count then
		Brain.Stats.MeteorEgg = (Brain.Stats.MeteorEgg or 0) + 1
		-- got it: stand on the rock a little while, like everyone does
		local top = Minigame.MeteorTop and Minigame.MeteorTop(meteor) or 2
		bot.Motor:StartRide(function()
			if workspace:GetServerTimeNow() > meteor.T0 + meteor.Life - 1 then return nil end
			return Minigame.MeteorPosition(meteor, workspace:GetServerTimeNow()) + Vector3.new(0, top + 3, 0), meteor.Velocity
		end)
		wait(bot, between(1, 3.5), true)
		bot.Motor:StopRide()
		if chance(0.5) and bot.Humanoid then bot.Humanoid.Jump = true end
	end
	return now() - t0
end
local function meteorRun(bot)
	local P = bot.P
	local run = P.Minigame
	local MG = Config.Minigame
	bot.Motor:SetShiftLock(bot.Persona.ShiftLock)
	count("MeteorRun")
	wait(bot, between(2.5, 4), true)    -- the countdown
	while P.Minigame == run and run and not bot.Gone and not bot.Dead do
		local entry = ctx.Minigame.BotEntry(P)
		if entry and #entry.Eggs >= MG.MaxEggs then
			if chance(0.5) then fidget(bot) else wait(bot, between(1, 3), true) end
		else
			local meteor, at = planMeteor(bot, run)
			if meteor and (bot.Persona.Skill > 0.25 or chance(0.6)) then
				chaseMeteor(bot, run, meteor, at)
			else
				local r = myRoot(bot)
				local planet = Config.Planets[run.Planet]
				if r and planet then
					local a, d = between(0, math.pi * 2), between(10, 80)
					goTo(bot, planet.Origin + Vector3.new(math.cos(a) * d, r.Position.Y - planet.Origin.Y, math.sin(a) * d), {Near = 6, Path = false, Timeout = 3})
				end
				wait(bot, between(0.2, 0.8), true)
			end
		end
		if bot.Interrupt and bot.Interrupt.Kind ~= "MeteorEnd" then bot.Interrupt = nil end
	end
	bot.Motor:SetShiftLock(false)
end

-- ---------------------------------------------------------------- reactions
function Brain.OnHit(bot, by)
	bot.LastHitAt = now()
	if by and by.Profile then bot.Grudges[by.Profile] = now() + between(15, 45) end
	if bot.Afk or bot.P.Stolen or bot.P.Minigame then return end
	if not bot.Interrupt then bot.Interrupt = {Kind = "Hit", By = by} end
end
function Brain.OnRobbed(bot, thief)
	local P = bot.P
	-- (v41) it remembers: a while of guarding its pen, and the thief is first in line for payback
	bot.GuardUntil = now() + between(120, 320)
	if thief then
		bot.RobbedBy = bot.RobbedBy or setmetatable({}, {__mode = "k"})
		bot.RobbedBy[thief] = now()
	end
	if P.Busy or bot.Dead or P.Minigame then return end
	-- (v36) out on a planet the alarm still rings: most fly straight home to get it back
	if P.Planet ~= "Base" then
		if chance(0.7) then
			task.delay(between(0.4, 1.5), function()
				if bot.Gone or bot.Dead or P.Busy or not carrierOfMine(bot) then return end
				bot.Interrupt = {Kind = "RushHome", Thief = thief}
			end)
		end
		return
	end
	-- AFK people sometimes miss it; the rest notice after a moment
	if bot.Afk and chance(0.3) then return end
	task.delay(bot.Persona.Reaction * 0.6 + between(0.1, 0.6), function()
		if bot.Gone or bot.Dead or not carrierOfMine(bot) then return end
		bot.Interrupt = {Kind = "Robbed", Thief = thief}
	end)
end
-- (v41) "BOSS!" / "THE GOLDEN EGG!" on the screen: the ones at home who care drop what they're doing and fly out
-- (if their rocket reaches and somebody's out there - hotPlanet)
function Brain.OnRally(bot, planetId, kind)
	local P = bot.P
	if P.Planet ~= "Base" or P.Busy or P.Stolen or P.Minigame then return end
	task.delay(bot.Persona.Reaction * 4 + between(0.5, 6), function()
		if bot.Gone or bot.Dead or bot.Interrupt or P.Planet ~= "Base" or P.Busy or P.Stolen or P.Minigame then return end
		if hotPlanet(bot) ~= planetId then return end
		local want = kind == "Boss" and 0.35 + bot.Persona.Aggression * 0.45 or 0.3 + bot.Persona.Greed * 0.45
		if bot.Afk then want *= 0.5 end
		if chance(want) then bot.Interrupt = {Kind = "Rally", Planet = planetId, For = kind} end
	end)
end
-- (v36) somebody nearby ran off with an egg from someone else's pen: like players, a bot may bat it out of their hands
function Brain.OnThief(bot, thief)
	local P = bot.P
	if P.Planet ~= "Base" or P.Busy or bot.Dead or P.Minigame or P.Stolen or bot.Treadmill and chance(0.5) then return end
	if not thief or thief == P or not thief.Stolen or thief.Stolen.FromProfile == P then return end
	local r, tr = myRoot(bot), ctx.root(thief.Player)
	if not r or not tr or (r.Position - tr.Position).Magnitude > 160 then return end
	if bot.Afk or not chance(0.45 + bot.Persona.Aggression * 0.45) then return end
	task.delay(bot.Persona.Reaction + between(0.2, 1.2), function()
		if bot.Gone or bot.Dead or bot.Interrupt or not thief.Stolen then return end
		bot.Interrupt = {Kind = "Catch", Thief = thief}
	end)
end
local function react(bot, event)
	local kind = event.Kind
	if kind == "Robbed" then
		if bot.Treadmill then Brain.LeaveTreadmill(bot) end
		return defend(bot)
	elseif kind == "RushHome" then
		if bot.P.Planet ~= "Base" and not bot.P.Busy then flyHome(bot) end
		if carrierOfMine(bot) then return defend(bot) end
		return
	elseif kind == "Catch" then
		if bot.Treadmill then Brain.LeaveTreadmill(bot) end
		local who = event.Thief and entityOf(event.Thief)
		if who and event.Thief.Stolen then return snatch(bot, who) end
		return
	elseif kind == "Hit" then
		-- wait to get back on its feet
		local t0 = now()
		while bot.Humanoid and bot.Humanoid.PlatformStand and now() - t0 < 3 do task.wait(0.1) end
		wait(bot, between(0.2, 0.7) * (1.3 - bot.Persona.Skill), true)
		local by = event.By
		local who = by and by.Profile and entityOf(by.Profile)
		local roll = rng:NextNumber()
		if who and who.Profile.Planet == bot.P.Planet and roll < 0.2 + bot.Persona.Aggression * 0.6 then
			-- revenge
			chaseAndHit(bot, who, between(5, 10))
			local tr = rootOf(who.Profile)
			if tr and chance(0.5) then flee(bot, tr.Position) end
			bot.Motor:SetShiftLock(false)
		elseif who and roll < 0.75 then
			local tr = rootOf(who.Profile)
			if tr then flee(bot, tr.Position) end
		end
	elseif kind == "Respawned" then
		bot.Motor:Reset()
		wait(bot, between(0.5, 2.5), true)
	elseif kind == "Rally" then
		if bot.Treadmill then Brain.LeaveTreadmill(bot) end
		if bot.P.Planet == "Base" and not bot.P.Busy and not bot.P.Stolen then
			count("Rally")
			bot.Rallied = {Planet = event.Planet, For = event.For}
			trip(bot, event.Planet)
		end
	end
end

-- ---------------------------------------------------------------- (v41) more of island life
-- someone about the island to be with (a person or a bot; `humansOnly`: people only)
local function companion(bot, radius, humansOnly)
	local r = myRoot(bot)
	if not r then return nil end
	local list = {}
	for _, person in ipairs(people("Base", bot)) do
		local d = (person.Root.Position - r.Position).Magnitude
		if d < radius and (person.Human or not humansOnly) and not person.Profile.Stolen then table.insert(list, person) end
	end
	return #list > 0 and list[rng:NextInteger(1, #list)] or nil
end
local function bodyOf(person) return person.Bot and B.Root(person.Bot) or rootOf(person.Profile) end
-- a few steps from somebody, facing them, a while (the way people stand about together)
local function hangOut(bot, person)
	count("Hangout")
	local function spot()
		local tr, r = bodyOf(person), myRoot(bot)
		if not tr or not r then return nil end
		local off = flat(r.Position - tr.Position)
		off = off.Magnitude > 0.5 and off.Unit or Vector3.new(1, 0, 0)
		return tr.Position + off * between(4, 6)
	end
	if not goTo(bot, spot, {Near = 3, Timeout = 15}) then return end
	local t0, stay = now(), between(6, 22)
	while now() - t0 < stay do
		local tr, r = bodyOf(person), myRoot(bot)
		if not tr or not r or person.Profile.Planet ~= "Base" or person.Profile.Busy then break end
		if (tr.Position - r.Position).Magnitude > 16 then
			if not goTo(bot, spot, {Near = 4, Timeout = 6}) then return end
		else
			face(bot, tr.Position)
			local roll = rng:NextNumber()
			if roll < 0.12 and bot.Humanoid then bot.Humanoid.Jump = true end
			if roll > 0.93 then toolPlay(bot) end
			if not wait(bot, between(0.8, 2.2)) then return end
		end
	end
end
-- tag along behind somebody for a while (curious, or a fan)
local function tagAlong(bot, person)
	count("Follow")
	local t0, stay = now(), between(12, 35)
	local keep = between(7, 13)
	while now() - t0 < stay and not bot.Gone and not bot.Dead do
		local tr, r = bodyOf(person), myRoot(bot)
		if not tr or not r or person.Profile.Planet ~= "Base" or person.Profile.Busy then break end
		local d = (tr.Position - r.Position).Magnitude
		if d > keep + 4 then
			local back = flat(r.Position - tr.Position)
			back = back.Magnitude > 0.5 and back.Unit or Vector3.new(1, 0, 0)
			if not goTo(bot, tr.Position + back * keep, {Near = 3, Timeout = 3, Path = d > 40}) then return end
		else
			face(bot, tr.Position)
			if not wait(bot, between(0.3, 0.9)) then return end
		end
	end
	if chance(0.4) then fidget(bot) end
end
-- stand watch at its own pen a while (after a theft more than ever): anybody stepping in gets the bat (the bolder ones)
local function guardPen(bot)
	local P = bot.P
	local area = P.Base and P.Base:FindFirstChild("PlantArea")
	if not area then return end
	count("Guard")
	local r = myRoot(bot)
	local out = r and flat(r.Position - area.Position) or Vector3.new(1, 0, 0)
	out = out.Magnitude > 1 and out.Unit or Vector3.new(1, 0, 0)
	local post = area.Position + out * (math.max(area.Size.X, area.Size.Z) * 0.35) + Vector3.new(0, 3, 0)
	if not goTo(bot, post, {Near = 4}) then return end
	local t0, stay = now(), between(15, 45) * (now() < (bot.GuardUntil or 0) and 1.8 or 1)
	local reach = math.max(area.Size.X, area.Size.Z) * 0.5 + 8
	while now() - t0 < stay do
		-- somebody at its eggs?
		for _, person in ipairs(people("Base", bot)) do
			if person.Profile ~= P and flat(person.Root.Position - area.Position).Magnitude < reach and canBonk(bot, person)
				and chance(0.25 + bot.Persona.Aggression * 0.6) then
				count("Guarded")
				hitAndRun(bot, person)
				return
			end
		end
		local roll = rng:NextNumber()
		if roll < 0.35 then face(bot, area.Position + out * between(20, 60) + Vector3.new(between(-30, 30), 0, between(-30, 30)))
		elseif roll < 0.42 then fidget(bot) end
		if not wait(bot, between(0.8, 2)) then return end
	end
end
-- the Meteor Run going on without it: over to the circle's edge to watch (and cheer)
local function spectate(bot)
	local c = zoneCenter()
	local MG = Config.Minigame
	local a = between(0, math.pi * 2)
	local edge = c + Vector3.new(math.cos(a), 0, math.sin(a)) * ((MG and MG.ZoneRadius or 30) + between(4, 12))
	local g = ground(edge)
	if not g or not goTo(bot, g + Vector3.new(0, 3, 0), {Near = 4}) then return end
	count("Spectate")
	local t0, stay = now(), between(15, 45)
	while now() - t0 < stay and ctx.Minigame and ((ctx.Minigame.Current and ctx.Minigame.Current()) or inviteOpen()) do
		face(bot, c)
		if chance(0.2) and bot.Humanoid then bot.Humanoid.Jump = true end
		if not wait(bot, between(1, 3)) then return end
	end
end

-- ---------------------------------------------------------------- choosing what to do at home
local function weighted(options)
	local total = 0
	for _, o in ipairs(options) do total += math.max(0, o[2]) end
	if total <= 0 then return nil end
	local r = rng:NextNumber() * total
	for _, o in ipairs(options) do
		r -= math.max(0, o[2])
		if r <= 0 then return o[1] end
	end
	return options[#options][1]
end
local function island(bot)
	local P = bot.P
	local persona = bot.Persona
	if not bot.Shown then B.Place(bot, B.SpawnPoint(bot)) end
	-- first the musts: eggs to plant, eggs to hatch, an egg in its hands to get home
	if P.Stolen then return runHome(bot) end
	if #P.Data.Eggs > 0 and #P.Data.GrowingEggs < plantCap(bot) and now() >= (bot.PlantReady or 0) and chance(0.85) then return plantEggs(bot) end
	if #readyEggs(P) > 0 and now() >= (bot.HatchReady or 0) and chance(0.7) then
		bot.HatchReady = now() + between(6, 20)
		return hatchEggs(bot)
	end
	-- the Meteor Run invitation is out: most people go
	if inviteOpen() then
		if bot.MeteorWish == nil then bot.MeteorWish = chance(0.72 + persona.Greed * 0.2) end
		if bot.MeteorWish then return meteorQueue(bot) end
	else
		bot.MeteorWish = nil
	end
	local t = now()
	local r = myRoot(bot)
	local near, thief = nil, snatchTarget(bot, 45)
	if r then
		local list = {}
		for _, person in ipairs(people("Base", bot)) do
			if (person.Root.Position - r.Position).Magnitude < 70 and canBonk(bot, person) then table.insert(list, person) end
		end
		-- (people it has a grudge against first)
		for _, person in ipairs(list) do if (bot.Grudges[person.Profile] or 0) > t then near = person end end
		near = near or list[rng:NextInteger(1, math.max(1, #list))]
	end
	local plan = (t >= (bot.StealReady or 0)) and stealPlan(bot) or nil
	local hot = hotPlanet(bot)
	local buddy = chance(0.5) and companion(bot, 90) or nil
	local fan = not buddy and chance(0.3) and companion(bot, 120, true) or nil
	local runOn = ctx.Minigame and ctx.Minigame.Current and ctx.Minigame.Current() ~= nil and not P.Minigame
	local options = {
		{"Steal", plan and (0.25 + persona.Greed * 0.9) or 0},
		{"Snatch", thief and (0.3 + persona.Aggression * 1.3) or 0},
		{"Bonk", (near and t >= (bot.BonkReady or 0)) and persona.Aggression * (near.Human and 0.3 or 0.45) or 0},
		{"Treadmill", 0.3 + (persona.Tier <= 2 and 0.2 or 0)},
		{"Trip", 0.42 + (hot and 0.9 or 0)},
		{"Wander", 0.32},
		{"Visit", 0.18},
		{"Fidget", 0.26},
		{"AFK", (1 - persona.Focus) * 0.22},
		{"Shop", t >= (bot.ShopReady or 0) and 0.12 or 0},
		{"Guard", 0.06 + persona.Aggression * 0.06 + (t < (bot.GuardUntil or 0) and 0.6 or 0)},
		{"Hangout", buddy and 0.2 or 0},
		{"Follow", fan and 0.07 or 0},
		{"Spectate", runOn and 0.7 or 0},
	}
	local choice = weighted(options)
	if choice then count(choice) end
	if choice == "Steal" then
		bot.StealReady = t + between(40, 120) * (1.4 - persona.Greed)
		steal(bot, plan)
	elseif choice == "Snatch" then
		snatch(bot, thief)
	elseif choice == "Bonk" then
		bot.BonkReady = t + between(35, 120)
		hitAndRun(bot, near)
	elseif choice == "Treadmill" then
		treadmill(bot)
	elseif choice == "Trip" then
		trip(bot)
	elseif choice == "Wander" then
		local destination = islandPoint(bot)
		if r and chance(0.45) then
			-- walking, walking ... a stop on the way to do something (look round, the bat, a jump), then on again
			local part = r.Position:Lerp(destination, between(0.35, 0.7))
			local g = ground(part)
			if g and goTo(bot, g + Vector3.new(0, 3, 0), {Near = 4}) then
				if chance(0.6) then fidget(bot) else wait(bot, between(0.6, 3)) end
			end
		end
		goTo(bot, destination, {Near = 4})
		if chance(0.45) then fidget(bot) end
	elseif choice == "Visit" then
		-- a look at somebody's pets over their fence
		local bases = ctx.bases:GetChildren()
		local base = bases[rng:NextInteger(1, #bases)]
		local area = base:FindFirstChild("PlantArea")
		if area and r then
			local out = flat(r.Position - area.Position)
			out = out.Magnitude > 1 and out.Unit or Vector3.new(1, 0, 0)
			local edge = area.Position + out * (math.max(area.Size.X, area.Size.Z) * 0.5 + between(3, 8)) + Vector3.new(0, 3, 0)
			if goTo(bot, edge, {Near = 4}) then
				face(bot, area.Position)
				wait(bot, between(3, 12))
			end
		end
	elseif choice == "Fidget" then
		fidget(bot)
	elseif choice == "AFK" then
		afk(bot, between(15, 110))
	elseif choice == "Shop" then
		bot.ShopReady = t + between(60, 200)
		shop(bot)
	elseif choice == "Guard" then
		guardPen(bot)
	elseif choice == "Hangout" then
		hangOut(bot, buddy)
	elseif choice == "Follow" then
		tagAlong(bot, fan)
	elseif choice == "Spectate" then
		spectate(bot)
	end
	if not bot.Interrupt then wait(bot, between(0.1, 0.9)) end
end

-- ---------------------------------------------------------------- the loop
function Brain.Run(bot)
	wait(bot, between(0.8, 2.5), true)    -- just joined: a look round
	while not bot.Gone do
		local ok, err = pcall(function()
			if bot.Dead or bot.DevHold then task.wait(0.2); return end
			local P = bot.P
			local event = bot.Interrupt
			bot.Interrupt = nil
			if event and event.Kind ~= "MeteorStart" and event.Kind ~= "MeteorEnd" then return react(bot, event) end
			if P.Busy then task.wait(0.3); return end
			if P.Minigame then return meteorRun(bot) end
			if P.Planet ~= "Base" then return explore(bot) end
			return island(bot)
		end)
		if not ok then
			warn("[PFE] bot " .. tostring(bot.Name) .. ": " .. tostring(err))
			pcall(function() bot.Motor:Stop() end)
			task.wait(2)
		end
		task.wait(between(0.05, 0.3))
	end
end

-- once a second (Bots' tick): what a player's profile gets from the game's own tick
function Brain.Tick1(bot, dt)
	if bot.Gone then return end
	local P = bot.P
	if P.Base then ctx.Bases.Tick(P, dt) end
	if not bot.Dead and bot.Humanoid and math.abs(ctx.walkSpeed(P) - (P.SpeedApplied or 0)) > 0.05 then pcall(ctx.setMovement, P) end
	if bot.Treadmill then
		P.Data.SpeedPower = math.min(1e15, (P.Data.SpeedPower or 0) + ctx.Speed.Gain(P) * dt)
		if P.Base and bot.Humanoid then P.Base:SetAttribute("BotWalkSpeed", bot.Humanoid.WalkSpeed) end
	end
	if bot.Tracker then
		bot.Tracker:SetAttribute("PFECoins", math.floor(P.Data.Coins or 0))
		bot.Tracker:SetAttribute("PFESpeedPower", math.floor(P.Data.SpeedPower or 0))
	end
	-- the air on a planet (the game's own expedition tick while it's there to be seen)
	if P.Expedition and not P.Busy and Config.Planets[P.Planet] and not P.Minigame then
		if bot.Shown and not bot.Dead then
			ctx.Expeditions.Tick(P, dt)
		else
			P.Oxygen = math.max(0, (P.Oxygen or 0) - Config.Planets[P.Planet].OxygenMultiplier * dt)
			if P.Oxygen <= 0 and not bot.Dead then B.Kill(bot, "air") end
		end
	end
	-- shift lock comes and goes for the people who use it
	if bot.Persona.ShiftLock and bot.Motor and not bot.Motor.Spin and chance(dt / 40) and P.Planet == "Base" then
		bot.Motor:SetShiftLock(not bot.Motor.ShiftLock)
	end
end

-- (studio tests) one activity at a time, by hand (bot.DevHold = true stops the brain choosing for itself)
Brain.Dev = {GoTo = goTo, Steal = steal, StealPlan = stealPlan, Plant = plantEggs, Hatch = hatchEggs, Defend = defend, RunHome = runHome,
	Fly = fly, Treadmill = treadmill, MeteorRun = meteorRun, MeteorQueue = meteorQueue, Explore = explore, HitAndRun = hitAndRun,
	People = people, Fidget = fidget}

-- (v41) the same hands and feet for the wanderers (Bots/Wanderer)
Brain.H = {wait = wait, goTo = goTo, face = face, fidget = fidget, toolPlay = toolPlay, afk = afk, chaseAndHit = chaseAndHit,
	flee = flee, hitAndRun = hitAndRun, canBonk = canBonk, markBonked = markBonked, people = people, entityOf = entityOf,
	rootOf = rootOf, ground = ground, zoneCenter = zoneCenter, inviteOpen = inviteOpen, hangOut = hangOut, tagAlong = tagAlong,
	spectate = spectate, companion = companion, snatch = snatch, now = now, flat = flat, between = between, chance = chance}

function Brain.Forget(bot)
	for item, b in pairs(claimed) do if b == bot then claimed[item] = nil end end
	bonked[bot] = nil
end

return Brain
