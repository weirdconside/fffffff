--!nocheck
-- (v41) WANDERERS: Config.Bots.Ambient bots that live on the island for good - no base, no pen, no Tab-list entry, never
-- off to the planets, never gone to make room for a player. They keep the island busy, each in its own way (a Style:
-- the jogger, the socialite, the guard, the prankster, the sightseer), with everything a player does there:
--  * strolling about (a stop on the way now and then), jogging laps round the middle, bunny-hopping across;
--  * a tour of the pens (a look at people's eggs and pets over the fence), a look out over the island's edge, the sights;
--  * standing about with people and bots (two wanderers meet up and stand together), tagging along behind a player,
--    walking over to greet somebody who just arrived;
--  * the Meteor Run: everybody at the circle's edge to watch (and cheer) - they never go in;
--  * the bat: thieves running past get it (the egg flies back to its pen - they have no pen to take it to), friendly
--    hit-and-run with the others, payback for a hit (now and then a game of tag breaks out);
--  * playing with the raygun and the bat, shift-lock spins, jumping about, AFK now and then.
-- Bodies, moving and the bat are the other bots' (Bots, Bots/Motor, Bots/Brain's hands and feet: Brain.H).
local Wanderer = {}
local B, H, ctx
local rng = Random.new()
Wanderer.Stats = {}
local function count(key) Wanderer.Stats[key] = (Wanderer.Stats[key] or 0) + 1 end

function Wanderer.Init(api, brain)
	B, H = api, brain.H
	ctx = B.ctx
end

local function between(a, b) return a + (b - a) * rng:NextNumber() end
local function chance(p) return rng:NextNumber() < p end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function now() return os.clock() end
local function myRoot(bot) return B.Root(bot) end

-- each one has a way about it
local STYLES = {
	Jogger = {Jog = 3, Hop = 1.6, Stroll = 0.8, AFK = 0.3},
	Socialite = {Hangout = 2.6, Follow = 1.8, Greet = 2.2, Spectate = 1.5},
	Guard = {Patrol = 3, Catch = 2.5, Bonk = 1.3, AFK = 0.6},
	Prankster = {Bonk = 2.6, Tag = 2.4, Hop = 1.5, Fidget = 1.4},
	Sightseer = {Tour = 2.4, Lookout = 2.6, Sights = 2.2, Stroll = 1.3},
}
local STYLE_ORDER = {"Jogger", "Socialite", "Guard", "Prankster", "Sightseer"}
local nextStyle = rng:NextInteger(1, #STYLE_ORDER)

-- ---------------------------------------------------------------- the island's places
local function centre() return H.zoneCenter() end
local function spotAround(around, minR, maxR)
	for _ = 1, 10 do
		local a, d = between(0, math.pi * 2), between(minR, maxR)
		local g = H.ground(around + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d))
		if g then return g + Vector3.new(0, 3, 0) end
	end
	return nil
end
function Wanderer.SpawnPoint(bot)
	local p = spotAround(centre(), 12, 80) or (centre() + Vector3.new(0, 4, 0))
	return CFrame.new(p) * CFrame.Angles(0, between(0, math.pi * 2), 0)
end
local function randomBase()
	local bases = ctx.bases:GetChildren()
	return #bases > 0 and bases[rng:NextInteger(1, #bases)] or nil
end
-- in front of a base (between it and the middle of the island)
local function frontOf(base)
	local spawnPart = base and base:FindFirstChild("Spawn")
	if not spawnPart then return nil end
	local inward = flat(centre() - spawnPart.Position)
	inward = inward.Magnitude > 1 and inward.Unit or Vector3.zero
	local g = H.ground(spawnPart.Position + inward * between(8, 30) + Vector3.new(between(-8, 8), 0, between(-8, 8)))
	return g and g + Vector3.new(0, 3, 0)
end
local function anywhere(bot)
	local roll = rng:NextNumber()
	if roll < 0.45 then return spotAround(centre(), 8, 75) end
	return frontOf(randomBase()) or spotAround(centre(), 8, 75)
end
-- the island's own decorations to go and look at (the Halloween things, the greenery)
local sights
local function sightsList()
	if sights then return sights end
	sights = {}
	local island = ctx.world and ctx.world:FindFirstChild("OriginalIsland")
	-- (models and parts only: the folders hold more of them - a Folder has no pivot)
	local function add(list)
		for _, m in ipairs(list) do
			if m:IsA("PVInstance") then
				table.insert(sights, m:GetPivot().Position)
			elseif m:IsA("Folder") then
				for _, inner in ipairs(m:GetChildren()) do
					if inner:IsA("PVInstance") then table.insert(sights, inner:GetPivot().Position) end
				end
			end
		end
	end
	for _, folderName in ipairs({"Halloween", "EarthGreenery"}) do
		local f = island and island:FindFirstChild(folderName)
		if f then add(f:GetChildren()) end
	end
	return sights
end

-- ---------------------------------------------------------------- what they do
local function stroll(bot)
	local destination = anywhere(bot)
	if not destination then return H.wait(bot, 1) end
	local r = myRoot(bot)
	if r and chance(0.4) then
		local g = H.ground(r.Position:Lerp(destination, between(0.35, 0.7)))
		if g and H.goTo(bot, g + Vector3.new(0, 3, 0), {Near = 4}) then
			if chance(0.5) then H.fidget(bot) else H.wait(bot, between(0.6, 3)) end
		end
	end
	H.goTo(bot, destination, {Near = 4})
	if chance(0.35) then H.fidget(bot) end
end
-- laps round the middle (a circle of points, the odd jump)
local function jog(bot)
	local c = centre()
	local radius = between(30, 85)
	local n = rng:NextInteger(7, 11)
	local dir = chance(0.5) and 1 or -1
	local r = myRoot(bot)
	local start = r and math.atan2(r.Position.Z - c.Z, r.Position.X - c.X) or 0
	local laps = between(0.6, 1.8)
	for i = 1, math.floor(n * laps) do
		local a = start + dir * i / n * math.pi * 2
		local g = H.ground(c + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius))
		if g then
			if not H.goTo(bot, g + Vector3.new(0, 3, 0), {Near = 6, Path = false, Timeout = 8}) then return end
			if chance(0.15) and bot.Humanoid then bot.Humanoid.Jump = true end
		end
	end
	if chance(0.5) then H.wait(bot, between(1, 4)) end
end
-- bunny-hopping somewhere
local function hop(bot)
	local destination = anywhere(bot)
	if not destination then return end
	local goal = bot.Motor:GoTo(destination, {Near = 5, Timeout = 20})
	while not goal.Done do
		if bot.Gone or bot.Dead or bot.Interrupt then bot.Motor:Cancel(goal); return end
		if bot.Humanoid and bot.Humanoid.FloorMaterial ~= Enum.Material.Air then bot.Humanoid.Jump = true end
		task.wait(0.1)
	end
end
-- a look at people's pens and pets over the fence (two to four of them)
local function tour(bot)
	for _ = 1, rng:NextInteger(2, 4) do
		local base = randomBase()
		local area = base and base:FindFirstChild("PlantArea")
		local r = myRoot(bot)
		if not area or not r then return end
		local out = flat(centre() - area.Position)
		out = out.Magnitude > 1 and out.Unit or Vector3.new(1, 0, 0)
		local side = Vector3.new(-out.Z, 0, out.X) * between(-8, 8)
		local edge = area.Position + out * (math.max(area.Size.X, area.Size.Z) * 0.5 + between(3, 7)) + side
		local g = H.ground(edge)
		if not g or not H.goTo(bot, g + Vector3.new(0, 3, 0), {Near = 4}) then return end
		H.face(bot, area.Position)
		if not H.wait(bot, between(2.5, 8)) then return end
		if chance(0.25) then H.fidget(bot) end
	end
end
-- a patrol past the pens (the guard): quick looks, on the watch for thieves
local function patrol(bot)
	for _ = 1, rng:NextInteger(3, 6) do
		local p = frontOf(randomBase())
		if not p or not H.goTo(bot, p, {Near = 5}) then return end
		local r = myRoot(bot)
		if r then H.face(bot, r.Position + bot.Humanoid.MoveDirection * 10 + Vector3.new(between(-20, 20), 0, between(-20, 20))) end
		if not H.wait(bot, between(0.8, 3)) then return end
	end
end
-- out to the edge of the island to look at the view
local function lookout(bot)
	local c = centre()
	local a = between(0, math.pi * 2)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local best
	for d = 40, 260, 12 do
		local g = H.ground(c + dir * d)
		if g then best = g elseif best then break end
	end
	if not best or not H.goTo(bot, best - dir * 4 + Vector3.new(0, 3, 0), {Near = 5}) then return end
	H.face(bot, best + dir * 100)
	H.wait(bot, between(4, 12))
	if chance(0.3) then H.toolPlay(bot) end
end
local function sightsee(bot)
	local list = sightsList()
	if #list == 0 then return stroll(bot) end
	local target = list[rng:NextInteger(1, #list)]
	local spot = spotAround(target, 5, 12)
	if not spot or not H.goTo(bot, spot, {Near = 4}) then return end
	H.face(bot, target)
	H.wait(bot, between(3, 9))
end
-- a game of tag / a friendly bonk with another bot (people now and then: once in a long while each)
local function bonk(bot, humansToo)
	local r = myRoot(bot)
	if not r then return end
	local list = {}
	for _, person in ipairs(H.people("Base", bot)) do
		if (person.Bot or (humansToo and chance(0.5))) and (person.Root.Position - r.Position).Magnitude < 90 and H.canBonk(bot, person)
			and not person.Profile.Stolen then
			table.insert(list, person)
		end
	end
	if #list == 0 then return stroll(bot) end
	count("Bonk")
	H.hitAndRun(bot, list[rng:NextInteger(1, #list)])
end
-- meet another wanderer: both walk over and stand together a while
local function meet(bot)
	local others = {}
	for _, w in ipairs(B.Wanderers()) do
		if w ~= bot and not w.Gone and not w.Dead and w.Shown and not w.Meet then table.insert(others, w) end
	end
	if #others == 0 then return false end
	local other = others[rng:NextInteger(1, #others)]
	count("Meet")
	other.Meet = {With = bot, Until = now() + 40}
	H.hangOut(bot, {Profile = other.P, Bot = other})
	other.Meet = nil
	return true
end
-- someone just came to the island (joined): a walk over to say hello (a jump or two, the bat out for a moment)
local greeted = setmetatable({}, {__mode = "k"})
local function newcomer(bot)
	for player, profile in pairs(ctx.profiles) do
		if not greeted[player] and profile.Planet == "Base" and profile.JoinedAt and os.time() - profile.JoinedAt < 90 then
			return player, profile
		end
	end
	return nil
end
local function greet(bot, player, profile)
	greeted[player] = true
	count("Greet")
	local function spot()
		local r = H.rootOf(profile)
		if not r then return nil end
		return r.Position + r.CFrame.LookVector * 7
	end
	if not H.goTo(bot, spot, {Near = 4, Timeout = 25}) then return end
	local r = H.rootOf(profile)
	if r then H.face(bot, r.Position) end
	for _ = 1, rng:NextInteger(1, 3) do
		if bot.Humanoid then bot.Humanoid.Jump = true end
		if not H.wait(bot, between(0.5, 0.9)) then return end
	end
	if chance(0.5) then H.toolPlay(bot) end
	H.wait(bot, between(1, 3))
end

-- ---------------------------------------------------------------- reactions
local function react(bot, event)
	if event.Kind == "Hit" then
		local t0 = now()
		while bot.Humanoid and bot.Humanoid.PlatformStand and now() - t0 < 3 do task.wait(0.1) end
		H.wait(bot, between(0.2, 0.7), true)
		local who = event.By and event.By.Profile and H.entityOf(event.By.Profile)
		if not who or who.Profile.Planet ~= "Base" then return end
		local roll = rng:NextNumber()
		local style = STYLES[bot.Style] or {}
		local payback = 0.2 + bot.Persona.Aggression * 0.5 + ((style.Tag or 0) > 1 and 0.3 or 0)
		if roll < payback then
			-- payback (with another bot that's a game of tag now)
			count("Payback")
			H.chaseAndHit(bot, who, between(4, 9))
			local tr = H.rootOf(who.Profile)
			if tr and chance(0.6) then H.flee(bot, tr.Position) end
			bot.Motor:SetShiftLock(false)
		elseif roll < 0.8 then
			local tr = H.rootOf(who.Profile)
			if tr then H.flee(bot, tr.Position) end
		end
	elseif event.Kind == "Catch" then
		local who = event.Thief and H.entityOf(event.Thief)
		if who and event.Thief.Stolen then
			count("Catch")
			H.snatch(bot, who)
		end
	elseif event.Kind == "Respawned" then
		bot.Motor:Reset()
		H.wait(bot, between(0.5, 2), true)
	end
end
-- somebody ran off with an egg from a pen nearby (Bots.OnRobbed)
function Wanderer.OnThief(bot, thief)
	if bot.Dead or bot.Afk or not thief or not thief.Stolen or bot.Interrupt then return end
	local r, tr = myRoot(bot), ctx.root(thief.Player)
	if not r or not tr or (r.Position - tr.Position).Magnitude > 140 then return end
	local style = STYLES[bot.Style] or {}
	if not chance(0.3 + bot.Persona.Aggression * 0.35 + (style.Catch and 0.3 or 0)) then return end
	task.delay(bot.Persona.Reaction + between(0.2, 1), function()
		if bot.Gone or bot.Dead or bot.Interrupt or not thief.Stolen then return end
		bot.Interrupt = {Kind = "Catch", Thief = thief}
	end)
end

-- ---------------------------------------------------------------- choosing
local function weighted(options)
	local total = 0
	for _, o in ipairs(options) do total += math.max(0, o[2]) end
	if total <= 0 then return nil end
	local roll = rng:NextNumber() * total
	for _, o in ipairs(options) do
		roll -= math.max(0, o[2])
		if roll <= 0 then return o[1] end
	end
	return options[#options][1]
end
local function decide(bot)
	local persona = bot.Persona
	local style = STYLES[bot.Style] or {}
	local function w(key, base) return base * (style[key] or 1) end
	if not bot.Shown then B.Place(bot, Wanderer.SpawnPoint(bot)) end
	-- another wanderer wants to meet: over there
	if bot.Meet and bot.Meet.With and not bot.Meet.With.Gone and now() < bot.Meet.Until then
		local with = bot.Meet.With
		H.hangOut(bot, {Profile = with.P, Bot = with})
		bot.Meet = nil
		return
	end
	bot.Meet = nil
	-- a thief running past (the guard first of all)
	local r = myRoot(bot)
	if r then
		for _, person in ipairs(H.people("Base", bot)) do
			local stolen = person.Profile.Stolen
			if stolen and (person.Root.Position - r.Position).Magnitude < 60 and chance(w("Catch", 0.25 + persona.Aggression * 0.3)) then
				count("Catch")
				return H.snatch(bot, person)
			end
		end
	end
	local t = now()
	local runOn = ctx.Minigame and ((ctx.Minigame.Current and ctx.Minigame.Current() ~= nil) or H.inviteOpen())
	local player, profile = newcomer(bot)
	local humans = H.companion(bot, 150, true)
	local options = {
		{"Stroll", w("Stroll", 0.3)},
		{"Jog", w("Jog", 0.14)},
		{"Hop", w("Hop", 0.04 + persona.Jumpiness * 0.08)},
		{"Tour", w("Tour", 0.16)},
		{"Patrol", (style.Patrol and 0.3 or 0)},
		{"Lookout", w("Lookout", 0.08)},
		{"Sights", w("Sights", 0.08)},
		{"Hangout", w("Hangout", 0.16)},
		{"Meet", w("Hangout", 0.1)},
		{"Follow", humans and w("Follow", 0.06) or 0},
		{"Greet", player and w("Greet", 0.5) or 0},
		{"Spectate", runOn and w("Spectate", 1.2) or 0},
		{"Bonk", t >= (bot.BonkReady or 0) and w("Bonk", persona.Aggression * 0.14) or 0},
		{"Tag", t >= (bot.BonkReady or 0) and (style.Tag and 0.12 or 0) or 0},
		{"Fidget", w("Fidget", 0.2)},
		{"AFK", w("AFK", (1 - persona.Focus) * 0.12)},
	}
	local choice = weighted(options)
	if choice then count(choice) end
	if choice == "Stroll" then stroll(bot)
	elseif choice == "Jog" then jog(bot)
	elseif choice == "Hop" then hop(bot)
	elseif choice == "Tour" then tour(bot)
	elseif choice == "Patrol" then patrol(bot)
	elseif choice == "Lookout" then lookout(bot)
	elseif choice == "Sights" then sightsee(bot)
	elseif choice == "Hangout" then
		local buddy = H.companion(bot, 120)
		if buddy then H.hangOut(bot, buddy) else stroll(bot) end
	elseif choice == "Meet" then
		if not meet(bot) then stroll(bot) end
	elseif choice == "Follow" then H.tagAlong(bot, humans)
	elseif choice == "Greet" then greet(bot, player, profile)
	elseif choice == "Spectate" then H.spectate(bot)
	elseif choice == "Bonk" then
		bot.BonkReady = t + between(40, 140)
		bonk(bot, true)
	elseif choice == "Tag" then
		bot.BonkReady = t + between(30, 90)
		bonk(bot, false)
	elseif choice == "Fidget" then H.fidget(bot)
	elseif choice == "AFK" then H.afk(bot, between(8, 50))
	end
	if not bot.Interrupt then H.wait(bot, between(0.1, 0.8)) end
end

function Wanderer.Run(bot)
	bot.Style = bot.Style or STYLE_ORDER[nextStyle]
	nextStyle = nextStyle % #STYLE_ORDER + 1
	H.wait(bot, between(0.5, 2), true)
	while not bot.Gone do
		local ok, err = pcall(function()
			if bot.Dead then task.wait(0.2); return end
			local event = bot.Interrupt
			bot.Interrupt = nil
			-- (never off the island)
			if bot.P.Planet ~= "Base" then bot.P.Planet = "Base" end
			if event then return react(bot, event) end
			return decide(bot)
		end)
		if not ok then
			warn("[PFE] wanderer " .. tostring(bot.Name) .. ": " .. tostring(err))
			pcall(function() bot.Motor:Stop() end)
			task.wait(2)
		end
		task.wait(between(0.05, 0.3))
	end
end

return Wanderer
