--!nocheck
-- Planet for Eggs configuration. Content (planets, eggs, pets, shop) is generated
-- into ContentData from content/content.py; this module turns it into runtime tables
-- and holds every gameplay constant.
local ContentData = require(script.Parent:WaitForChild("ContentData"))

local Config = {}

local function rgb(t)
	if typeof(t) == "Color3" then return t end
	return Color3.fromRGB(t[1], t[2], t[3])
end
Config.rgb = rgb

Config.Version = 7
Config.DataStoreName = "PlanetForEggs_v1"
Config.MoneyIcon = "rbxassetid://112678965246772"
Config.StartingCoins = 150
Config.EarthName = "Earth"

-- Economy / progression
Config.MaxActivePets = 8          -- best N pets are shown in the pen and earn credits
Config.MaxPets = 500          -- (v27: 200 species - room for every one and more)
Config.MaxStoredEggs = 100
Config.MaxGrowingEggs = 60
Config.PlantGridSize = 3
Config.PlantMinSpacing = 2.25
Config.PlantRadiusCap = 7          -- grown-egg radius counted when spacing eggs (giant eggs may overlap)
Config.PlantDistance = 34
Config.BaseInteractionDistance = 90
Config.InteractionDistance = 24
Config.PickupDistance = 16 -- (x Config.PromptReach below)
Config.SafeRadius = 36

-- Movement / survival
Config.BaseWalkSpeed = 20
Config.SprintMultiplier = 1.8     -- (base speed only: Config.SprintSpeed adds at most SprintBonusMax on top of a trained speed)
Config.SprintBonusMax = 0
Config.SprintOxygenMultiplier = 2
Config.LowOxygenThreshold = 10
Config.CriticalOxygenThreshold = 0
Config.LowOxygenDamagePerSecond = 10
Config.BaseGravity = 160
-- the game's owners (the OWNER tag over their heads and in chat) and admins (the admin panel): user ids
Config.Owners = {[10661934654] = true, [1128601858] = true}   -- zoy0m, MM2GARRY
Config.OwnerNames = {zoy0m = true, mm2garry = true}               -- the same by name (any letter case)
function Config.IsOwner(player)
	return player ~= nil and (Config.Owners[player.UserId] == true or Config.OwnerNames[string.lower(player.Name)] == true)
end
Config.Admins = {[10661934654] = true}                        -- zoy0m
-- every "hold E" prompt shows up from this many times further than it used to
Config.PromptReach = 2
Config.PromptDistance = 10 -- studs from the character at which every "Hold E" prompt shows (camera distance doesn't matter)
Config.CrabRaveFrom = 110 -- seconds into Crab Rave where the flight music starts (1:50)

-- Flights (seconds). The client cinematic uses the same numbers.
Config.FlightDuration = 6.5       -- lift off + space cruise, the player is teleported at the end
Config.LandingDuration = 2.3      -- landing shot after arrival; the player stays busy
Config.GalaxyJumpBonus = 1.5      -- extra hyperspace seconds when jumping to another galaxy

-- Planet hunt
Config.EggsPerExpedition = 240    -- (v29: eggs everywhere on the 5x maps - the far rings have fewer but rarer ones, see ZoneShare)
Config.EggsPerExtraExplorer = 24
Config.EggsMaxPerPlanet = 330
-- (v30) eggs follow the explorer: there are always at least Min eggs within Radius studs of everyone on a planet
-- (topped up every Every seconds from the free hiding spots around them; the extras far from everybody go away)
-- (v41) RocketClear: no egg ever lies within this many studs of the landing pad (the pad used to be ringed with eggs -
-- you landed, grabbed one and flew home); fewer near-eggs, topped up more slowly
Config.NearEggs = {Min = 5, Radius = 150, Inner = 30, Every = 1, PerTick = 2, Cleanup = 420, MaxPerExplorer = 30, RocketClear = 170}
-- (v29) bot explorers fill the bases nobody uses (Bots.lua); a real player always gets a base (a bot leaves)
-- (v35) they play like people: they steal from pens (players' too: StealFromPlayers, at most once per PlayerStealCooldown
-- seconds from the same player, never from a shielded or a newcomer's pen), grow and hatch what they steal, defend
-- their own pen, bat people, go to the planets and the Meteor Run (Bots/Brain.lua)
Config.Bots = {Enabled = true, Capacity = 9, Max = 8, JoinDelay = {2, 7},
	StealFromPlayers = true, PlayerStealCooldown = 240,
	-- (v32) STUDIO-ONLY look-preview: in Studio's Play the bots borrow these usernames and those accounts' avatars, have no
	-- robot icon and show in a Tab list. A published server never does this (RunService:IsStudio() is false there):
	-- live bots keep made-up names and the icon, so nobody is passed off as a real person or a real player.
	StudioPreview = true,
	PreviewNames = {"rivenrich", "MM2GARRY", "KristiBoosts", "flenimu", "111anet", "cherry_blink17", "Psina444xxx", "Mmul_97", "Sasha000_23",
		"HNKA_12913", "dbnofo_mm2", "TBOYA_MAMKA9", "rel3eff", "mussiiil112233", "klever_cayrou", "zurel84", "Wiwioop6790", "kami_amir100",
		"Roxy19669", "Acaner5", "alina56565alina", "Tirpontan161", "egr9003", "Quick_question31", "antonba55", "gago10564", "qwetrull82",
		"Taulan678", "redewart", "nvfgvxv", "Arzuagoat4", "kakaxa555568", "Be99999999990", "AnitaBo6", "matiriiiii6430", "sue13970",
		"frbdct_3546hgg", "Boy09N_2", "Makaka0_0ao", "love_mez10", "Sasha_star313", "heibeibidontstar1", "PNCYH101", "Emilkazai4",
		"bsgcxneuxnsjgj", "PATRIK_BOOST", "mny52436", "sicm588", "KOTARA_404228", "Miss_roblox1347", "kokle766", "Nastenkas5669", "kura9083"}}
Config.MapCycle = 300             -- every 5 minutes every planet is rebuilt from a new seed
Config.EventInterval = {300, 300} -- (v41) a world event starts every 5 minutes (counted from the start of the last one)

-- Floating sky islands above every planet: height bands pick the egg odds (higher = better)
Config.SkyIslands = {Count = 20, Bands = {
	{Min = 38, Max = 70, Count = 8, Rare = 1, Chance = 0.55},     -- low: mostly common eggs, not always one
	{Min = 80, Max = 125, Count = 8, Rare = 2.5, Chance = 0.7},
	{Min = 140, Max = 190, Count = 4, Rare = 6, Chance = 0.85, Super = 0.01},
}}

-- The bat everyone carries (Steal an Egg): range, knockback and the time between swings
Config.Bat = {Range = 15, Tolerance = 2.5, Cooldown = 0.75, Force = 35, Duration = 0.5}
-- the alien raygun every player carries (from 99 Nights: the first, endless one)
-- 99 Nights' energy rules: every shot costs energy, it comes back by itself (EnergyReturnPerSecond); run
-- it dry and the gun overheats for OverheatDuration seconds, then it is full again (the AlienBar shows it)
-- (the numbers are the 99 Nights Raygun's own attributes: EnergyCost 10, FireRate 0.2, ProjectileDamage 5.5,
-- ProjectileSpeed 700; GlobalSettings: EnergyReturnPerSecond 8, OverheatDuration 10)
Config.Raygun = {Damage = 5.5, Cooldown = 0.2, Range = 170, BoltSpeed = 700, HitTolerance = 3.5, Icon = "rbxassetid://75298986325495",
	EnergyMax = 100, EnergyCost = 10, EnergyReturnPerSecond = 8, OverheatDuration = 10}
-- Alien NPCs on every planet (99 Nights' aliens). Distances are studs: they notice you by themselves
-- within AggroRange, chase up to LeashRange, shoot within ShootRange; the landing pad (SafeRadius
-- around the planet centre) is always safe. Cooler planets roll the tougher kinds more often.
Config.Aliens = {
	AggroRange = 36, LeashRange = 70, ShootRange = 40, MeleeRange = 5.5, SafeRadius = 64,   -- 36 studs = 10 m (Roblox: 1 stud = 0.28 m)
	ShipAggroRange = 90,                                             -- aboard an alien ship they see the whole hall
	WanderRadius = 34, Tick = 0.2, RespawnDelay = {18, 32}, DespawnAfter = 20,
	Base = 26, PerPlanet = 2, PerExtraExplorer = 5, Max = 56,        -- count = Base + ceil(order * PerPlanet) (+ extra explorers) (v28: 5x maps)
	HealthPerPlanet = 0.15, DamagePerPlanet = 0.12,
	-- towards the edge of the map they get tougher: at the edge x(1 + EdgeHealth) health, x(1 + EdgeDamage)
	-- damage, and up to EdgeTiers kinds higher (0 at the landing pad's edge, 1 at the map's edge)
	EdgeHealth = 1.2, EdgeDamage = 0.6, EdgeTiers = 3,
	-- Health counts in 99 Nights raygun shots (5.5 damage each): the melee alien takes 7 (38), the raygun
	-- alien 10 (55); the tougher kinds as before (about 3x)
	Types = {
		{Id = "AlienScout", Name = "Alien Scout", MinPlanet = 1, Weight = 5, Health = 38, Speed = 28, Damage = 8, Melee = true, Cooldown = 1.1,
			Bounty = 0.4, Scale = 0.9, Color = Color3.fromRGB(90, 230, 255)},
		{Id = "AlienGunner", Name = "Alien Gunner", MinPlanet = 2, Weight = 4, Health = 55, Speed = 24, Damage = 9, Ranged = true, Cooldown = 1.8,
			Accuracy = 0.7, Bounty = 0.6, Scale = 1, Color = Color3.fromRGB(120, 255, 90)},
		{Id = "AlienSoldier", Name = "Alien Soldier", MinPlanet = 3, Weight = 4, Health = 100, Speed = 26, Damage = 12, Ranged = true, Cooldown = 1.6,
			Accuracy = 0.75, Bounty = 1, Scale = 1.05, Color = Color3.fromRGB(90, 200, 255)},
		{Id = "AlienBrute", Name = "Alien Brute", MinPlanet = 5, Weight = 2, Health = 205, Speed = 22, Damage = 28, Melee = true, Cooldown = 1.6,
			Bounty = 2, Scale = 1.5, Knockback = 55, Color = Color3.fromRGB(255, 120, 60)},
		{Id = "AlienElite", Name = "Alien Elite", MinPlanet = 6, Weight = 2, Health = 160, Speed = 34, Damage = 15, Ranged = true, Cooldown = 1.0,
			Accuracy = 0.8, Bounty = 2.2, Scale = 1.05, Color = Color3.fromRGB(255, 70, 220)},
		{Id = "AlienCommander", Name = "Alien Commander", MinPlanet = 8, Weight = 1, Health = 350, Speed = 24, Damage = 26, Ranged = true, Cooldown = 1.7,
			Accuracy = 0.85, Bounty = 5, Scale = 1.3, Color = Color3.fromRGB(90, 255, 160)},
	},
}
Config.AlienTypes = {}
for _, t in ipairs(Config.Aliens.Types) do Config.AlienTypes[t.Id] = t end

-- game passes a dungeon chest can hand out for a while (never the VIP status), at most TempPassMax each
Config.TempPassKeys = {"DoubleMoney", "Lucky", "SuperSuit", "SpeedBoots", "BigCargo", "RadarPro"}
Config.TempPassMax = 1800
-- codes (typed in the Codes window, once per player): coins and/or a game pass for a while
Config.Codes = {
	["777"] = {Coins = 10000, Pass = "RadarPro", Seconds = 900},
}
-- the Free button: like + favourite the game (checked again after a rejoin) -> VIP for a while
Config.FreeReward = {Pass = "VIP", Seconds = 24 * 3600, RecheckSeconds = 30}
-- (v41) passive income like Steal an Egg: while you are away your pets keep earning (Share of their income per second,
-- for at most MaxHours; less than MinSeconds away pays nothing). Paid when you come back, with a "welcome back" card.
Config.OfflineIncome = {Share = 1, MaxHours = 24, MinSeconds = 60}
-- the VIP's perks: +10% coins from pets, +10% air, a random pass for an hour every day
Config.VipIncome = 1.1
Config.VipOxygen = 1.1
-- Alien dungeons, built from 99 Nights' ships. A UFO hovers over every planet with a tractor beam down
-- to the ground (stand in it to be beamed aboard); every planet also has two crashed UFOs to go into.
-- Inside: halls of the 99 Nights mothership, one per level: clear the level's aliens and the airlock
-- opens to the next; the last hall holds 99 Nights' alien chest (a temporary game pass or a great egg).
Config.Dungeons = {
	Space = Vector3.new(0, 600, -32000),  -- where the ships' halls are put together, far out of sight (v28: past the moved planets)
	LootCooldown = 1200, LootMax = 2,     -- a player loots at most LootMax alien chests (any ships) per LootCooldown seconds
	ClearDelay = 4,                       -- seconds before an airlock opens once a level is clear
	WaveBase = 2, WavePerLevel = 1,       -- aliens per level (Dead Rails' aliens, from PFE.Aliens)
	IdleClose = 40,                       -- an empty ship closes after this many seconds
	MaxCrew = 6,                          -- players who beam up while level 1 is on share the ship
	-- the UFO hovers above the highest sky islands (their top band ends at 190)
	Sky = {Name = "Alien Mothership", Levels = 3, Radius = 190, Height = 240, UFOScale = 1.25,
		Loot = {PassChance = 0.6, PassMinutes = {15, 30}, EggRare = 8, EggSuper = 0.06}},
	-- saucers that already came down: two on every planet, 99 Nights' crashed UFO and Dead Rails' UFO
	-- (tilted and half sunk into the ground); Angle / Radius place them around the planet centre
	Ground = {Name = "Crashed UFO", Levels = 2,
		Sites = {{Piece = "CrashedUFO", Angle = 220, Radius = 300, Clear = 40},
			{Piece = "Wreck", Angle = 130, Radius = 400, Clear = 44, Scale = 0.55, Tilt = 22}},
		Loot = {PassChance = 0.7, PassMinutes = {10, 20}, EggRare = 5, EggSuper = 0.03}},
	-- the alien stronghold: our saucer standing still high over the sky islands (no beam: only a jetpack
	-- gets you up to its landing platform); inside, the mothership's halls - four of them, more and tougher aliens, the best loot
	High = {Name = "Alien Stronghold", Levels = 4, Radius = 330, Angle = 310, Height = 215, Clear = 12, ExtraAliens = 3, ExtraTier = 2,
		Loot = {PassChance = 0.5, PassMinutes = {30, 60}, EggRare = 20, EggSuper = 0.2}},
}
-- every dungeon entrance on a planet: {Kind, Index, Key, X, Z (relative to the planet centre), Clear, Spec}
-- (the radii are authored for the old 560-stud maps and spread out with the planet: v28's maps are 5x wider)
function Config.DungeonSites(planetId)
	local planet = Config.Planets[planetId]
	if not planet then return {} end
	local turn = (planet.Order or 1) * 37
	local k = (planet.Radius or 560) / 560
	local list = {}
	local sky = Config.Dungeons.Sky
	local a = math.rad(40 + turn)
	table.insert(list, {Kind = "Sky", Index = 1, Key = planetId .. ":Sky", X = math.cos(a) * sky.Radius * k, Z = math.sin(a) * sky.Radius * k, Clear = 16, Spec = sky})
	local high = Config.Dungeons.High
	a = math.rad(high.Angle + turn)
	table.insert(list, {Kind = "High", Index = 1, Key = planetId .. ":High", X = math.cos(a) * high.Radius * k, Z = math.sin(a) * high.Radius * k,
		Clear = high.Clear, Spec = high})
	for i, site in ipairs(Config.Dungeons.Ground.Sites) do
		a = math.rad(site.Angle + turn)
		table.insert(list, {Kind = "Ground", Index = i, Key = planetId .. ":Ground" .. i, X = math.cos(a) * site.Radius * k, Z = math.sin(a) * site.Radius * k,
			Clear = site.Clear, Spec = site})
	end
	return list
end
-- clearings the planet generator keeps free of decor: {x, z, radius}
function Config.DungeonClearings(planetId)
	local list = {}
	for _, site in ipairs(Config.DungeonSites(planetId)) do table.insert(list, {site.X, site.Z, site.Clear}) end
	return list
end

-- Meteor Run minigame (queue circle in the middle of the Earth island)
Config.Minigame = {Cycle = 1800, Duration = 120, MaxEggs = 3, ZoneRadius = 44, SpawnEvery = 1.1,
	Speed = {9, 16}, Height = {18, 88}, ArenaRadius = 175, GrabRange = 7,
	InviteSeconds = 30}   -- everyone gets a JOIN / NO window this long before a run starts
Config.EggRespawn = {45, 90}
-- v28: five distance rings (PlanetGen.ZoneOf: 1 around the landing pad .. 5 at the edge of the 5x map). The
-- further out, the RARER the eggs lying there - and the fewer of them: ZoneShare is the part of a planet's egg
-- pool in each ring, and the outer rings are far bigger, so out there an egg is a long run from the next one.
-- Getting to the edge (and back to the rocket with the egg in your hands) is what trained Speed is for.
Config.ZoneEdges = {0.25, 0.45, 0.65, 0.83}     -- ring edges as a share of the planet's radius
Config.ZoneShare = {0.10, 0.22, 0.24, 0.24, 0.20}   -- (v41: the ring round the landing pad has fewer eggs)
-- multiplier per egg Tier (1 = the planet's commonest egg .. 7 = its chase egg) in each ring
Config.ZoneTierWeights = {
	[1] = {1.6, 0.9, 0.3, 0.08, 0.02, 0.004, 0.001},
	[2] = {1.0, 1.0, 0.7, 0.35, 0.12, 0.04, 0.01},
	[3] = {0.55, 1.0, 1.3, 1.1, 0.6, 0.25, 0.08},
	[4] = {0.25, 0.7, 1.6, 2.0, 1.6, 0.9, 0.35},
	[5] = {0.08, 0.35, 1.3, 2.6, 3.2, 2.6, 1.6},
}

-- Steal-an-Egg rules
Config.ShieldDuration = 60
Config.VipShieldDuration = 120
Config.NoviceProtectionPets = 3    -- bases are protected until their owner has this many pets
Config.StealHoldDuration = 1.4
Config.StealWalkSpeed = 15
Config.StealTimeout = 90           -- a thief who never gets home drops the egg
Config.CatchRange = 6.5            -- the owner catches a thief by running into them
-- Sounds. Every id here is public (Creator Store): the Steal an Egg pack's own sounds are private to that
-- game and can't play here, so the same kinds of sounds come from the store (or the ids you gave).
local function sid(n) return "rbxassetid://" .. n end
Config.Sounds = {
	-- music and ambience (Music.client)
	Title = sid(1836009626),             -- Halloween Horrors Waltz (APM): the intro (v28 Halloween)
	Base = sid(1838592691),              -- Halloween Night (APM): the island with the bases (first of BasePlaylist)
	CrabRave = sid(5410086218),          -- Noisestorm - Crab Rave (not used now: too loud for the flight)
	FlightMusic = sid(5410086218),       -- the rocket's flight music (the owner's pick): from 0:30, at 70%, fading in and out
	Wind = sid(93035214379043),          -- wind_loop: airless, dusty, icy, burning planets
	NightForest = sid(7274920568),       -- Night Forest Ambience: jungle, fungal, neon, void planets
	Scary = sid(139393062477955),        -- Scary Forest: aboard the alien ships
	Action = sid(1836009678),            -- Fast Paced Halloween (APM): Meteor Run, the minigame every 30 min
	UfoHum = sid(100230209655518),       -- ufo_hum: under the UFOs
	-- effects
	Laser = sid(137510557013265),        -- laser red: the raygun (and the aliens' guns, lower)
	LaserHit = sid(116852572291971),     -- a bolt hits an alien
	AlienDeath = sid(2141017975),
	AlienAlert = sid(9113089924),        -- an alien spots you
	Coin = sid(135483737426662),         -- coins in
	Cash = sid(134810204798705),         -- purchases
	Hover = sid(139800881181209), Click = sid(6895079853),
	Sparkle = sid(132381858621446), Tick = sid(119133534035860),
	Reward = sid(96102213526905), Confetti = sid(7933571710), Legendary = sid(2789429656),
	EggCrack = sid(9113959343), Plant = sid(9114083746), Pickup = sid(4612375233),
	BatSwing = sid(91685418034146), BatHit = sid(9118617342),
	RocketLaunch = sid(12222065), Jetpack = sid(105868857203338), Boom = sid(9125402735),
	FuseCharge = sid(108306323478967), FuseWhoosh = sid(9125648149), -- (APM / ProSoundEffects, public: the fusion show)
	Teleport = sid(135640489101126), LevelUp = sid(3120909354), ChestOpen = sid(116841971399984), DoorOpen = sid(118448537916332),
	-- v28: the hatch multiplier ("casino") and the fusion show
	Heartbeat = sid(9043365842), DrumRoll = sid(1842251033), SlotTick = sid(9119220620), Jackpot = sid(1846251193),
	Loser = sid(1846942478), BigBoom = sid(9126102254), Cheer = sid(9112766176), Riser = sid(16480577565),
	MagicWhoosh = sid(9125648149),
	-- (v37) the Halloween join cutscene (HalloweenIntro.client)
	IntroCalm = sid(1846088038),          -- Morning Mood (APM): the island before Halloween (its old music)
	Rain = sid(9112793871),               -- Heavy Rain 2 (ProSoundEffects)
	Thunder = sid(9120021541),            -- Thunder Sharp Booming Strikes Rumbling 2 (ProSoundEffects)
	Lightning = sid(9116282544),          -- Lightning Strike Sharp Hissing Crack 1 (ProSoundEffects)
	Rumble = sid(9112775181),             -- Earthquake Rumble 2 (ProSoundEffects): the ground opening
	BossGrowl = sid(9114628818),          -- Goliath Vocal Deep Growling Voice 22 (ProSoundEffects)
	BossLaugh = sid(7649680797),          -- Halloween Spooky Laugh SFX ("mwahahaha"), pitched down
	HorrorSting = sid(9047014318),        -- Beautiful Horror - Stinger 1 (APM): the world turns
	CrowsCaw = sid(190872950),            -- Crows Cawing ("great for horror"): the swarm rising from under the edge
	RavenSquawk = sid(9118067493),        -- Raven Bird Raucous Squawking 2 (ProSoundEffects)
	WingsRush = sid(9125738421),          -- Pigeon Surges, Sudden Bursts Of Birds Flying (ProSoundEffects): the swarm passing
	RockCrumble = sid(9113218938),        -- Avalanche Deep Crumbling 4 (ProSoundEffects): the King climbing the rim
	WaveWhoosh = sid(93800003062010),     -- Whoosh Hit Deep Low (APM): the darkness sweeping over
}
-- v28 Halloween: the island plays these one after another (APM / DistroKid tracks licensed for Roblox)
-- (v29: no jazzy shuffles - only the spooky orchestral ones)
Config.BasePlaylist = {
	sid(1838592691),      -- Halloween Night (APM)
	sid(1837467198),      -- Night of the Ghouls (APM)
	sid(139190190976686), -- Halloween Music Box (APM)
	sid(1836009626),      -- Halloween Horrors Waltz (APM)
	sid(130935065570387), -- Ghostly Masquerade Ball - Halloween Ambient (DistroKid)
}
-- (v29) calm music on every planet, quietly under its ambience (APM / DistroKid tracks licensed for Roblox), two each
Config.PlanetMusic = {
	Moon = {sid(140533822783920), sid(102039057339088)},        -- Space Ambient / Zero Gravity
	Mars = {sid(9042041852), sid(137911990035159)},             -- Calm Space (a) / Calm Cinematic Space
	Frostia = {sid(140041908508788), sid(140651103751263)},     -- Slow Breathing Aurora / Nordic Ice Visions
	Verdantis = {sid(91781617219749), sid(80087113697398)},     -- Floating Through Green Light / Water Over Moss
	Magmara = {sid(134397999360395), sid(86551540413853)},      -- Embers of Twilight Reverie / Solar Awakening
	Crystalis = {sid(108366797800248), sid(9042043110)},        -- Light Beyond Orbit / Calm Space (b)
	Mycelia = {sid(73731220283940), sid(98984030727095)},       -- Mysterious Magic Underscore / Soft Rain on Green Stone
	Neonix = {sid(136827064604146), sid(139793680497894)},      -- Deep Space Ocean / Nebula Dream Theta Waves
	Nebulon = {sid(108443170673682), sid(102638739412193)},     -- Cosmic Reflection / Signals Returning Home
}
-- the interface's sounds (names the scripts already use)
Config.Sfx = {
	Click = Config.Sounds.Click, Hover = Config.Sounds.Hover, Collect = Config.Sounds.Pickup, Cash = Config.Sounds.Cash,
	Sparkle = Config.Sounds.Sparkle, EggOpen = Config.Sounds.EggCrack, Reward = Config.Sounds.Reward, Tick = Config.Sounds.Tick,
	Plant = Config.Sounds.Plant,
}

-- (v38) the daily login calendar: one reward per (UTC) day; miss a day and it starts again from day 1. The eggs are
-- one-of-a-kind forged eggs (EggForge) whose hybrids earn about Income coins a second; coins scale with your income.
Config.Daily = {
	EggSeedBase = 900000000,
	Days = {
		{Kind = "Egg", Name = "Dawn Egg", Rarity = "Epic", Income = 1000, Growth = 45, Topper = 5,
			Colors = {{255, 206, 96}, {255, 128, 64}, {255, 240, 170}}, Hint = "Hatches a pet that earns ~1K/s"},
		{Kind = "Egg", Name = "Twin Sun Egg", Rarity = "Legendary", Income = 2000, Growth = 60, Topper = 1,
			Colors = {{255, 168, 40}, {255, 84, 40}, {255, 236, 120}}, Hint = "Twice as strong: ~2K/s pets!"},
		{Kind = "Coins", Name = "Coin Chest", Coins = 50000, IncomeSeconds = 900, Icon = "Chest", Hint = "A chest full of coins"},
		{Kind = "Pass", Name = "Lucky Potion", Pass = "Lucky", Seconds = 1800, Icon = "Potion", Hint = "Luckier hatches for 30 min"},
		{Kind = "Egg", Name = "Eclipse Egg", Rarity = "Mythic", Income = 5000, Growth = 75, Topper = 3,
			Colors = {{150, 70, 255}, {40, 20, 90}, {255, 120, 220}}, Hint = "Mythic pets: ~5K/s"},
		{Kind = "Pass", Name = "Double Coins", Pass = "DoubleMoney", Seconds = 3600, Coins = 100000, IncomeSeconds = 1200, Icon = "X2Coins",
			Hint = "x2 coins for an hour + coins"},
		{Kind = "Egg", Name = "Celestial Crown Egg", Rarity = "Secret", Income = 15000, Growth = 90, Topper = 2, Coins = 250000, IncomeSeconds = 2400,
			Colors = {{120, 230, 255}, {255, 230, 120}, {255, 255, 255}}, Hint = "THE JACKPOT: ~15K/s pets + coins"},
	},
}
-- the forged egg id of a calendar day's egg
function Config.DailyEggId(day)
	local entry = Config.Daily.Days[day]
	if not entry or entry.Kind ~= "Egg" then return nil end
	local index = 1
	for i, id in ipairs(Config.RarityOrder) do if id == entry.Rarity then index = i end end
	return string.format("Gen_%d_%d", index, Config.Daily.EggSeedBase + day)
end
-- the coins a day gives (it grows with the player's income)
function Config.DailyCoins(entry, income)
	if not entry or not entry.Coins then return 0 end
	return math.floor(math.max(entry.Coins, (income or 0) * (entry.IncomeSeconds or 0)))
end

-- (v37) the Halloween join cutscene: once per account (Data.IntroSeen < Version), every time in Studio
-- (StudioAlways); Speed only for the offline tests
Config.HalloweenIntro = {Enabled = true, Version = 1, StudioAlways = true, Skippable = true, Speed = 1}

-- Studio preview helpers (never active in live servers)
Config.DevShowcase = true

-- ---------------------------------------------------------------- content
Config.Rarities = {}
Config.RarityOrder = {}
for _, r in ipairs(ContentData.Rarities) do
	Config.Rarities[r.Id] = {Id = r.Id, Color = rgb(r.Color), Order = r.Order}
	table.insert(Config.RarityOrder, r.Id)
end

Config.Mutations = {}
Config.MutationList = {}
for _, m in ipairs(ContentData.Mutations) do
	local entry = {Id = m.Id, Name = m.Name, Chance = m.Chance, Multiplier = m.Multiplier, Color = rgb(m.Color)}
	Config.Mutations[m.Id] = entry
	table.insert(Config.MutationList, entry)
end

Config.Sizes = {}
for _, s in ipairs(ContentData.Sizes) do table.insert(Config.Sizes, {Id = s.Id, Name = s.Name, Scale = s.Scale, Chance = s.Chance}) end

Config.Galaxies = {}
Config.GalaxyOrder = {}
for _, g in ipairs(ContentData.Galaxies) do
	local entry = {Id = g.Id, Name = g.Name, Order = g.Order, Color = rgb(g.Color), Color2 = rgb(g.Color2), Planets = {}}
	Config.Galaxies[g.Id] = entry
	table.insert(Config.GalaxyOrder, entry)
end

Config.Planets = {}
Config.PlanetOrder = {}
for _, p in ipairs(ContentData.Planets) do
	local entry = {
		Id = p.Id, Name = p.Name, Galaxy = p.Galaxy, Order = p.Order, RequiredRange = p.RequiredRange,
		OxygenMultiplier = p.OxygenMultiplier, Gravity = p.Gravity, Reward = p.Reward,
		Origin = Vector3.new(p.Origin[1], p.Origin[2], p.Origin[3]), Radius = p.Radius,
		Color = rgb(p.Color), Color2 = rgb(p.Color2), Accent = rgb(p.Accent),
		GroundColor = rgb(p.Ground.Color), RockColor = rgb(p.Ground.Rock or p.Ground.Color2), Blurb = p.Blurb, Particles = p.Particles, Sky = p.Sky,
	}
	Config.Planets[p.Id] = entry
	table.insert(Config.PlanetOrder, entry)
	table.insert(Config.Galaxies[p.Galaxy].Planets, entry)
end
table.sort(Config.PlanetOrder, function(a, b) return a.Order < b.Order end)

Config.MapArt = ContentData.MapArt or {}
Config.GalaxyArt = ContentData.GalaxyArt or {}
Config.Pets = {}
Config.LegacySpecies = ContentData.LegacySpecies or {}
-- (v27) the old one-egg-per-species ids ('Moon3' ...) -> the new egg of that planet and tier
Config.LegacyEggs = ContentData.LegacyEggs or {}
Config.PetList = {}
for species, p in pairs(ContentData.Pets) do
	Config.Pets[species] = {
		Species = species, Name = p.Name, Income = p.Income, Rarity = p.Rarity or "Common",
		Color = rgb(p.Color), Existing = p.Existing == true, Style = p.Style, Limited = p.Limited == true,
		Planet = p.Planet, Tier = p.Tier or 1,
		Secret = p.Secret == true,     -- (v28) shown as "???" until you have hatched one
		Special = p.Special == true,   -- (v28) the Chimera: built from other pets, never in a drop table
	}
	table.insert(Config.PetList, Config.Pets[species])
end
table.sort(Config.PetList, function(a, b) return a.Income < b.Income end)

Config.EggCatalog = {}
Config.Eggs = {}
for _, e in ipairs(ContentData.Eggs) do
	local entry = {Id = e.Id, Name = e.Name, Rarity = e.Rarity, Species = e.Species, Planet = e.Planet, Tier = e.Tier,
		Weight = e.Weight, GrowthTime = e.GrowthTime, Existing = e.Existing == true, Limited = e.Limited == true, Stock = e.Stock,
		Drops = e.Drops, Secret = e.Secret == true, Retired = e.Retired == true,
		Fusion = e.Fusion == true}     -- (v28) a Fusion Egg: hatches from the drop tables of the eggs fused into it
	Config.Eggs[e.Id] = entry
	table.insert(Config.EggCatalog, entry)
end
-- (v36) the one-of-a-kind eggs Fusion forges ("Gen_<rarity>_<seed>"): EggForge rebuilds them from the id
setmetatable(Config.Eggs, {__index = function(_, id)
	if type(id) ~= "string" or string.sub(id, 1, 4) ~= "Gen_" then return nil end
	local forge = script.Parent:FindFirstChild("EggForge")
	return forge and require(forge).Info(id) or nil
end})
table.sort(Config.EggCatalog, function(a, b)
	local pa = Config.Planets[a.Planet] and Config.Planets[a.Planet].Order or 99
	local pb = Config.Planets[b.Planet] and Config.Planets[b.Planet].Order or 99
	if pa ~= pb then return pa < pb end
	return a.Tier < b.Tier
end)
-- what an egg hatches: one of its drops by weight (v27: every egg has several; its Species is only the likeliest)
function Config.RollHatch(info, random)
	if type(info.Drops) ~= "table" or #info.Drops == 0 then return info.Species end
	local total = 0
	for _, drop in ipairs(info.Drops) do total += drop[2] end
	local roll = (random and random:NextNumber() or math.random()) * total
	for _, drop in ipairs(info.Drops) do
		roll -= drop[2]
		if roll <= 0 then return drop[1] end
	end
	return info.Drops[#info.Drops][1]
end
Config.LimitedEggs = {}       -- the limited eggs on sale now (the retired Sakura Egg is only kept for the saves)
for _, egg in ipairs(Config.EggCatalog) do if egg.Limited and not egg.Retired then table.insert(Config.LimitedEggs, egg) end end
Config.FusionEggByRarity = {}
for _, egg in ipairs(Config.EggCatalog) do if egg.Fusion then Config.FusionEggByRarity[egg.Rarity] = egg end end
-- the eggs lying on a planet (EggsOnPlanet) never include the fusion, limited or retired eggs: their Planet is not a planet

-- every egg glows in its rarity's colour (grey, green, blue, purple, orange for the rarest)
Config.EggGlow = {Common = Color3.fromRGB(175, 180, 192), Uncommon = Color3.fromRGB(70, 230, 90), Rare = Color3.fromRGB(50, 150, 255),
	Epic = Color3.fromRGB(175, 80, 255), Legendary = Color3.fromRGB(255, 150, 30), Mythic = Color3.fromRGB(255, 150, 30),
	Secret = Color3.fromRGB(255, 150, 30), Eternal = Color3.fromRGB(255, 150, 30), Special = Color3.fromRGB(255, 70, 255)}

-- Fusion (v28): three eggs from the backpack become one FUSION EGG. The best of the three sets the level:
-- three of the same rarity always go one rarity up, two of the best rarity make it a coin flip, otherwise
-- a 35% chance to go up. The egg is that rarity's Fusion Egg; it remembers the three eggs and hatches from
-- their drop tables, tilted towards its rarity (Config.FusionDrops). Size roll: the eggs' average and a
-- bit; mutation: the best of theirs. (Special is never reached: Eternal is the top of a fusion.)
Config.FusionCost = 3
Config.FusionTop = 8   -- Eternal
function Config.FusionOdds(rarities)
	local order = {}
	for i, id in ipairs(Config.RarityOrder) do order[id] = i end
	local best, same = 0, 0
	for _, r in ipairs(rarities) do best = math.max(best, math.min(Config.FusionTop, order[r] or 1)) end
	for _, r in ipairs(rarities) do if math.min(Config.FusionTop, order[r] or 1) == best then same += 1 end end
	local up = math.min(Config.FusionTop, best + 1)
	local chance = same >= 3 and 1 or same == 2 and 0.5 or 0.35
	if up == best then return {{Rarity = Config.RarityOrder[best], Chance = 1}} end
	if chance >= 1 then return {{Rarity = Config.RarityOrder[up], Chance = 1}} end
	return {{Rarity = Config.RarityOrder[best], Chance = 1 - chance}, {Rarity = Config.RarityOrder[up], Chance = chance}}
end
-- what a Fusion Egg made of `sources` (egg ids) hatches: {{species, weight}, ...}. Every source egg's drop table
-- counts the same; pets of the egg's rarity (or better) are 3x as likely, one rarity below 1x, the rest
-- 0.25x; if the fusion went UP a rarity, the pets of that rarity on the source planets join the table too.
function Config.FusionDrops(rarity, sources)
	local order = {}
	for i, id in ipairs(Config.RarityOrder) do order[id] = i end
	local target = order[rarity] or 1
	local pool, list = {}, {}
	local planets, best = {}, 0
	local function add(species, weight)
		local pet = Config.Pets[species]
		if not pet or pet.Special or weight <= 0 then return end
		if not pool[species] then pool[species] = 0; table.insert(list, species) end
		pool[species] += weight
	end
	for _, eggId in ipairs(sources or {}) do
		local egg = Config.Eggs[eggId]
		if egg and not egg.Fusion then
			planets[egg.Planet] = true
			best = math.max(best, order[egg.Rarity] or 1)
			local total = 0
			for _, drop in ipairs(egg.Drops or {}) do total += drop[2] end
			for _, drop in ipairs(egg.Drops or {}) do add(drop[1], drop[2] / math.max(0.001, total)) end
		end
	end
	if target > best then
		local extra = {}
		for _, pet in ipairs(Config.PetList) do
			if planets[pet.Planet] and not pet.Limited and not pet.Special and order[pet.Rarity] == target then table.insert(extra, pet.Species) end
		end
		for _, species in ipairs(extra) do add(species, 0.6 / #extra) end
	end
	local out = {}
	for _, species in ipairs(list) do
		local r = order[Config.Pets[species].Rarity] or 1
		local k = r >= target and 3 or r == target - 1 and 1 or 0.25
		table.insert(out, {species, pool[species] * k})
	end
	table.sort(out, function(a, b) return a[2] > b[2] end)
	if #out == 0 then
		-- (no usable sources: any pet of that rarity)
		for _, pet in ipairs(Config.PetList) do
			if not pet.Limited and not pet.Special and pet.Rarity == rarity then table.insert(out, {pet.Species, 1}) end
		end
	end
	return out
end

function Config.EggsOnPlanet(planetId)
	local list = {}
	for _, egg in ipairs(Config.EggCatalog) do if egg.Planet == planetId then table.insert(list, egg) end end
	return list
end

-- ---------------------------------------------------------------- v28: speed, treadmills, trails
-- Speed Power (SP) is trained on a treadmill; the walk speed grows with it, a few studs/s for every
-- doubling (soft-capped at Max): 0 SP = 22, ~180 SP = 40, ~3K = 73, ~120K = 120, ~15M = 183.
-- (v29) slow and steady: +2 walk speed every time the trained speed doubles (from 10), never above 50
Config.Speed = {Base = Config.BaseWalkSpeed, PerDoubling = 2, Unit = 10, Max = 50}
function Config.WalkSpeedFor(power)
	power = math.max(0, tonumber(power) or 0)
	if power ~= power or power == math.huge then power = 0 end
	local s = Config.Speed
	return math.min(s.Max, s.Base + s.PerDoubling * math.log(1 + power / s.Unit, 2))
end
-- sprinting: the old x1.8 for the starting speed, never more than SprintBonusMax on top of a trained one
function Config.SprintSpeed(walk)
	return walk   -- (v29: no sprint)
end
Config.Treadmills = {}
for i, t in ipairs(ContentData.Treadmills or {}) do
	table.insert(Config.Treadmills, {Level = i, Name = t.Name, Gain = t.Gain, Cost = t.Cost, Color = rgb(t.Color), Accent = rgb(t.Accent),
		Material = t.Material, Fx = t.Fx})
end
Config.TreadmillTick = 0.25       -- the server grants SP this often while you stand on your belt
Config.TreadmillVip = 1.1         -- VIPs train 10% faster
Config.Trails, Config.TrailList = {}, {}
for i, t in ipairs(ContentData.Trails or {}) do
	local colors = {}
	for _, c in ipairs(t.Colors) do table.insert(colors, rgb(c)) end
	local entry = {Id = t.Id, Name = t.Name, Rarity = t.Rarity, Cost = t.Cost, Mult = t.Mult, Colors = colors, Glow = t.Glow or 0.5, Fx = t.Fx, Order = i}
	Config.Trails[t.Id] = entry
	table.insert(Config.TrailList, entry)
end
function Config.TrailColors(trail)
	local colors = trail and trail.Colors or {Color3.new(1, 1, 1)}
	if #colors == 1 then return ColorSequence.new(colors[1]) end
	local points = {}
	for i, c in ipairs(colors) do table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c)) end
	return ColorSequence.new(points)
end
-- SP per second on a treadmill of `level` wearing trail `trailId`
function Config.TreadmillGain(level, trailId, vip)
	local treadmill = Config.Treadmills[level or 1] or Config.Treadmills[1]
	local trail = trailId and Config.Trails[trailId]
	return (treadmill and treadmill.Gain or 1) * (trail and trail.Mult or 1) * (vip and Config.TreadmillVip or 1)
end

-- ---------------------------------------------------------------- v28: the hatch multiplier ("casino")
-- Every hatch rolls a multiplier first. It climbs on screen, faster and faster - m(t) = exp(a * t^Power) -
-- and may stop any moment: Instant of the time right away at x1, otherwise where the roll says. The roll
-- is a Pareto tail: P(m >= x) = (1 - Instant) * x^-Alpha, so x10 ~ 1 in 10 hatches, x100 ~ 1 in 70,
-- x1000 ~ 1 in 500, x1M ~ 1 in 180K, x10M ~ 1 in 1.3M. What it buys grows slowly with it (luck on the egg's
-- own drop table, a mutation step from MutationFrom, a one-of-a-kind Chimera from ChimeraFrom whose income
-- grows with log10 of the multiplier) - the economy stays where it is.
-- (v29) big multipliers come much more often, but each one does less: LuckPower tames how hard a multiplier
-- tilts the drop table, mutations need x1000, chimeras x20,000 (and earn at most x4 their best part)
Config.HatchRoll = {Instant = 0.2, Alpha = 0.55, Max = 1e7, Curve = {0.36, 0.44}, Power = 1.45, LuckPower = 0.35,
	MutationFrom = 1000, ChimeraFrom = 20000, ChimeraBonus = 1.5, ChimeraPerDecade = 0.8, ChimeraMaxBonus = 4,
	Announce = 1000}            -- multipliers this big are announced to the whole server
function Config.HatchCurve(a, t)
	return math.exp(a * math.max(0, t) ^ Config.HatchRoll.Power)
end
function Config.HatchTime(a, m)
	return (math.log(math.max(1, m)) / math.max(0.05, a)) ^ (1 / Config.HatchRoll.Power)
end
function Config.RoundMultiplier(m)
	if m < 10 then return math.floor(m * 100 + 0.5) / 100 end
	if m < 100 then return math.floor(m * 10 + 0.5) / 10 end
	return math.floor(m + 0.5)
end
function Config.RollMultiplier(random)
	local r = Config.HatchRoll
	local function roll() return random and random:NextNumber() or math.random() end
	if roll() < r.Instant then return 1 end
	local m = math.max(1e-9, roll()) ^ (-1 / r.Alpha)
	return Config.RoundMultiplier(math.clamp(m, 1, r.Max))
end
function Config.FormatMultiplier(m)
	if m < 10 then return string.format("x%.2f", m) end
	if m < 100 then return string.format("x%.1f", m) end
	local text = tostring(math.floor(m + 0.5))
	local out = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then out = string.sub(out, 2) end
	return "x" .. out
end
-- the rarity rank of a drop table entry (for the luck): rarer pets (and the smaller weights of a rarity) rank higher
local function rarityRank(species)
	local pet = Config.Pets[species]
	return pet and Config.Rarities[pet.Rarity] and Config.Rarities[pet.Rarity].Order or 1
end
-- pick from a drop table ({{species, weight}, ...}) with the multiplier as luck: the commonest entry keeps
-- its weight, the rarest is multiplied by m, the ones between by m^(rank share)
function Config.LuckyPick(drops, m, random)
	local n = #drops
	if n == 0 then return nil end
	local ranked = {}
	for i, d in ipairs(drops) do ranked[i] = {d[1], d[2], rarityRank(d[1])} end
	table.sort(ranked, function(a, b) if a[3] ~= b[3] then return a[3] < b[3] end return a[2] > b[2] end)
	local luck = math.max(1, m or 1) ^ (Config.HatchRoll.LuckPower or 1)
	local total = 0
	for i, d in ipairs(ranked) do
		d[4] = d[2] * luck ^ ((i - 1) / math.max(1, n - 1))
		total += d[4]
	end
	local roll = (random and random:NextNumber() or math.random()) * total
	for _, d in ipairs(ranked) do
		roll -= d[4]
		if roll <= 0 then return d[1] end
	end
	return ranked[n][1]
end
function Config.ChimeraBonus(m)
	local r = Config.HatchRoll
	return math.min(r.ChimeraMaxBonus, r.ChimeraBonus + r.ChimeraPerDecade * math.log10(math.max(1, m / r.ChimeraFrom)))
end
-- a funny name out of two pets: the front of the first, the back of the second ("Chicken" + "Dragon" = "Chickgon")
function Config.ChimeraName(a, b)
	local na = string.gsub((Config.Pets[a] and Config.Pets[a].Name) or a, "[^%a]", "")
	local nb = string.gsub((Config.Pets[b] and Config.Pets[b].Name) or b, "[^%a]", "")
	local front = string.sub(na, 1, math.max(3, math.ceil(#na * 0.55)))
	local back = string.lower(string.sub(nb, math.max(1, #nb - math.max(3, math.floor(#nb * 0.5)) + 1)))
	if string.sub(front, -1) == string.sub(back, 1, 1) then back = string.sub(back, 2) end
	return front .. back
end
-- what the UI and the income use for a pet record (the Chimera keeps its own name and income in the save)
function Config.PetInfo(record)
	if type(record) ~= "table" then return Config.Pets[record] end
	if record.Species == "Chimera" then
		local base = Config.Pets.Chimera
		-- (v36) a hybrid from a forged egg keeps the egg's rarity; the multiplier's Chimera is "Special"
		local rarity = (type(record.Rarity) == "string" and Config.Rarities[record.Rarity]) and record.Rarity or "Special"
		return {Species = "Chimera", Name = record.Name or "Chimera", Rarity = rarity, Income = record.Income or 1, Hybrid = rarity ~= "Special",
			Color = base and base.Color or Color3.fromRGB(255, 70, 255), Special = true, Parts = record.Parts, Tier = 8, Planet = "Special"}
	end
	return Config.Pets[record.Species]
end

-- (v41) air: every explorer starts with exactly AirBase seconds of it (the first helmet), and a helmet upgrade adds only
-- AirUpgradeShare of what it used to on top of that (the old ladder ran to 2000 s - nobody ever ran out of air)
Config.AirBase = 80
Config.AirUpgradeShare = 0.5
Config.Suits = {}
for i, s in ipairs(ContentData.Suits) do
	local first = ContentData.Suits[1].Oxygen
	local oxygen = i == 1 and Config.AirBase or Config.AirBase + math.floor((s.Oxygen - first) * Config.AirUpgradeShare / 5 + 0.5) * 5
	table.insert(Config.Suits, {Name = s.Name, Oxygen = oxygen, Cost = s.Cost, Primary = rgb(s.Primary),
		Secondary = rgb(s.Secondary), Trim = rgb(s.Trim), Glow = rgb(s.Glow)})
end
Config.Rockets = ContentData.Rockets
Config.Cargo = ContentData.Cargo
Config.Jetpacks = {}
for _, j in ipairs(ContentData.Jetpacks or {}) do
	table.insert(Config.Jetpacks, {Name = j.Name, FlightTime = j.FlightTime, Recharge = j.Recharge, Thrust = j.Thrust, Cost = j.Cost,
		Primary = rgb(j.Primary), Secondary = rgb(j.Secondary), Trim = rgb(j.Trim), Glow = rgb(j.Glow)})
end
Config.Events = {}
Config.EventList = {}
for _, e in ipairs(ContentData.Events or {}) do
	local entry = {Id = e.Id, Name = e.Name, Duration = e.Duration, Color = rgb(e.Color), Buff = e.Buff}
	Config.Events[e.Id] = entry
	table.insert(Config.EventList, entry)
end

Config.GamePasses = {}
Config.GamePassList = {}
for _, gp in ipairs(ContentData.GamePasses) do
	local entry = {Key = gp.Key, Name = gp.Name, Id = gp.Id or 0, Icon = gp.Icon, Color = rgb(gp.Color), Perks = gp.Perks}
	Config.GamePasses[gp.Key] = entry
	table.insert(Config.GamePassList, entry)
end
-- the IDs typed into ReplicatedStorage.PFE.Monetization (edit that script in Studio) win over the built-in ones
do
	local ok, ids = pcall(function() return require(script.Parent:WaitForChild("Monetization", 5)) end)
	if ok and type(ids) == "table" then
		for _, entry in ipairs(Config.GamePassList) do
			local id = ids.GamePasses and ids.GamePasses[entry.Key]
			if type(id) == "number" and id > 0 then entry.Id = id end
		end
		for _, pr in ipairs(ContentData.Products) do
			local id = ids.Products and ids.Products[pr.Key]
			if type(id) == "number" and id > 0 then pr.Id = id end
		end
	end
end
Config.Products = {}
Config.ProductList = {}
for _, pr in ipairs(ContentData.Products) do
	local entry = table.clone(pr)
	entry.Id = pr.Id or 0
	Config.Products[pr.Key] = entry
	table.insert(Config.ProductList, entry)
end

-- ---------------------------------------------------------------- formulas
function Config.AssetScale(value)
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return 1 end
	return math.clamp(value, 0.2, 8)
end
function Config.EggGrowthDuration(info, scale)
	scale = Config.AssetScale(scale)
	local multiplier = scale <= 2 and 1 or scale <= 6 and (scale / 2) ^ 1.389 or math.min((scale / 6) ^ 0.72 * 4.6, 20)
	return math.max(5, (info.GrowthTime or 30) * multiplier)
end
-- Steal an Egg placed-egg scales (EggScaleUtil): a planted egg starts at the model's own size
-- (times its size roll, never below 60%) and grows to three times that while it incubates
-- size (optional): the model's largest visible dimension at the authored scale; grown eggs are
-- capped at EggMaxGrownSize so the few giant Steal an Egg eggs still fit inside a pen
function Config.EggGrowthScales(authored, scale, size, rarity)
	-- with the rarity known (the base): the rarity's size ladder, growing EggGrowFactor times
	if rarity and size and size > 0 then
		local start = authored * Config.BaseEggTarget(rarity, scale) / size
		local target = math.min(start * Config.EggGrowFactor, authored * Config.EggMaxGrownSize / size)
		return math.min(start, target / 1.5), target
	end
	local raw = authored * Config.AssetScale(scale)
	local minimum = authored * 0.6
	local start = math.clamp(raw, minimum, authored * 8)
	local target = raw < minimum and minimum or raw * 3
	if size and size > 0 then
		local cap = authored * Config.EggMaxGrownSize / size
		if target > cap then target = cap; start = math.min(start, cap / 2.2) end
	end
	return start, target
end
-- Steal an Egg sizes: the cooler the egg or pet, the bigger it is - up to giants. The ladders follow
-- the source pack's own models (the median largest dimension of its pets and eggs of each rarity:
-- chickens ~3-4 studs, legendaries ~10-13, secrets ~20-30, eternal dragons and sea monsters ~50+).
-- The size roll (Big / Huge ...) multiplies them. A planted egg starts at its size and grows
-- EggGrowFactor (the source's x3) times bigger while it incubates.
-- (v27) a third bigger than the source ladder below the very top: even a common pet stands taller than you
-- (v30) bigger again and steeper, like SaE's giants; within a rarity the pets of the farther planets are bigger too
Config.BasePetSize = {Common = 10, Uncommon = 13, Rare = 17, Epic = 23, Legendary = 31, Mythic = 42, Secret = 58, Eternal = 78, Special = 62}
Config.BaseEggSize = {Common = 1.3, Uncommon = 1.5, Rare = 1.8, Epic = 2.2, Legendary = 2.8, Mythic = 3.8, Secret = 6.5, Eternal = 11, Special = 8}
Config.EggGrowFactor = 3
Config.PetMaxSize = 120         -- even a rolled-up giant stays this side of the neighbours' pens
Config.EggMaxGrownSize = 40     -- a fully grown egg still fits its (50-stud) pen
function Config.BasePetTarget(rarity, scale, species)
	local bonus = 1
	local pet = species and Config.Pets and Config.Pets[species]
	local planet = pet and Config.Planets and Config.Planets[pet.Planet or ""]
	if planet and planet.Order then bonus = 1 + 0.035 * (planet.Order - 1) end
	return math.min(Config.PetMaxSize, (Config.BasePetSize[rarity] or 6) * bonus * Config.AssetScale(scale))
end
function Config.BaseEggTarget(rarity, scale)
	return (Config.BaseEggSize[rarity] or 2.2) * Config.AssetScale(scale)
end
-- an egg in the hands / carried home: its own size, but never too small to see or too big to carry
function Config.HeldEggSize(rarity, scale)
	return math.clamp((Config.BaseEggSize[rarity] or 1.5) * 1.35 * (1 + (Config.AssetScale(scale) - 1) * 0.3), 2, 7)
end
-- Held eggs: small ones at the chest, hugged (both hands on their sides); big ones (Legendary and up,
-- Config.HeldEggOverheadFrom studs tall) raised over the head on both hands, like Steal an Egg.
-- HeldEggOffset = where the egg's centre sits relative to the HumanoidRootPart; headTop = how far the
-- top of the head is above it (an R15 block rig: 2.1). CarryPose.client puts the hands on the egg.
Config.HeldEggOverheadFrom = 3.6
function Config.HeldEggOverhead(size)
	return size.Y >= Config.HeldEggOverheadFrom
end
function Config.HeldEggOffset(size, headTop)
	if Config.HeldEggOverhead(size) then
		return CFrame.new(0, (headTop or 2.1) + 0.2 + size.Y * 0.5, -0.15)
	end
	local r = math.max(size.X, size.Z) * 0.5
	return CFrame.new(0, 0.3 + math.max(0, size.Y - 2.2) * 0.2, -(0.62 + r))
end
-- the top of this character's head above its HumanoidRootPart (for HeldEggOffset)
function Config.HeadTop(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not root or not head or not head:IsA("BasePart") then return 2.1 end
	return math.clamp(root.CFrame:PointToObjectSpace(head.Position).Y + head.Size.Y * 0.5, 1, 6)
end
-- an egg lying on a planet (half as big again as they used to be, the rarer the bigger)
function Config.PlanetEggSize(rarity, scale)
	local ratio = (Config.BaseEggSize[rarity] or 1.3) / Config.BaseEggSize.Common
	return 3.75 * ratio ^ 0.4 * (1 + (Config.AssetScale(scale) - 1) * 0.35)
end

-- cheapest "Skip Growth" tier that covers the remaining seconds
function Config.SkipProductFor(remaining)
	local best
	for _, product in ipairs(Config.ProductList) do
		if product.Kind == "SkipGrowth" and (product.Seconds or 0) >= remaining then
			if not best or product.Seconds < best.Seconds then best = product end
		end
	end
	if not best then
		for _, product in ipairs(Config.ProductList) do
			if product.Kind == "SkipGrowth" and (not best or product.Seconds > best.Seconds) then best = product end
		end
	end
	return best
end
function Config.MutationMultiplier(mutation)
	local m = Config.Mutations[mutation or "Normal"]
	return m and m.Multiplier or 1
end
function Config.PetIncome(info, scale, mutation)
	scale = Config.AssetScale(scale)
	local sizeMultiplier = scale <= 5 and scale ^ 1.85 or (scale / 5) ^ 1.2 * 19.637875755794113
	return math.max(1, math.round((info.Income or 1) * sizeMultiplier * Config.MutationMultiplier(mutation)))
end
function Config.SizeName(scale)
	local best, name = math.huge, ""
	for _, s in ipairs(Config.Sizes) do
		local d = math.abs(s.Scale - (scale or 1))
		if d < best then best = d; name = s.Name end
	end
	return name
end
function Config.EggDisplayName(egg)
	local info = Config.Eggs[egg.EggId]
	local name = info and info.Name or "Egg"
	local size = Config.SizeName(egg.Scale)
	local mutation = Config.Mutations[egg.Mutation or "Normal"]
	local prefix = ""
	if size ~= "" then prefix ..= size .. " " end
	if mutation and mutation.Name ~= "" then prefix ..= mutation.Name .. " " end
	return prefix .. name
end

local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx"}
function Config.Format(value)
	value = tonumber(value) or 0
	if value < 1000 then return tostring(math.floor(value)) end
	local tier = math.min(#suffixes, math.floor(math.log10(value) / 3) + 1)
	local scaled = value / (1000 ^ (tier - 1))
	local text = scaled >= 100 and string.format("%d", scaled) or scaled >= 10 and string.format("%.1f", scaled) or string.format("%.2f", scaled)
	if string.find(text, ".", 1, true) then
		text = string.gsub(string.gsub(text, "0+$", ""), "%.$", "")
	end
	return text .. suffixes[tier]
end
-- (v28) a rate that may have decimals (2.5 SP/s): one decimal below 100, Format above
function Config.FormatRate(value)
	value = tonumber(value) or 0
	if value < 100 and math.abs(value - math.floor(value)) > 0.05 then return string.format("%.1f", value) end
	return Config.Format(value)
end
function Config.FormatTime(seconds)
	seconds = math.max(0, math.ceil(seconds))
	if seconds < 60 then return seconds .. "s" end
	if seconds < 3600 then return string.format("%dm %02ds", seconds // 60, seconds % 60) end
	if seconds < 86400 then return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60) end
	return string.format("%dd %dh", seconds // 86400, (seconds % 86400) // 3600)
end
Config.Robux = utf8.char(0xE002)

return Config
