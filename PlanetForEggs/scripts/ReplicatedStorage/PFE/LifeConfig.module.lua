--!nocheck
-- (v41) Planet life: what makes the planets more than egg fields. Shared by the server (GameServer.PlanetLife,
-- .Bosses, .GoldenRace, .Caves) and the clients (LifeClient, BossClient, GoldenEggClient, CaveClient, Flashlight).
--  * WEATHER: every planet always has some weather on (Life.Weather, Life.PlanetWeather): meteor rain, sandstorms,
--    blizzards, eruptions, acid rain, solar flares, thunder, quakes, crystal blooms, gravity flux, spirit fog, spore
--    blooms, data glitches, heatwaves, comet showers, hail. Each one is dangerous in its own way and pays in its own
--    way: rare eggs in craters, eggs the wind digs out, frozen eggs in ice, eggs inside volcanic bombs...
--  * BOSSES: every Life.Boss.Every seconds a planet's mini-boss (Ice Yeti, Sand Worm, Lava Golem...) wakes up where the
--    explorers are; the whole server fights it with bats and rayguns; when it falls, eggs rain down.
--  * THE GOLDEN EGG: every Life.Golden.Every seconds one Golden Egg appears on a random planet, shown to everybody (the
--    tracker, a beam of light across the planet, an arrow). Grab it and get it to your rocket - the bat knocks it out of
--    the carrier's hands.
--  * CAVES: two cave mouths on every planet lead into long dark caves (a flashlight is in everyone's hotbar). The deeper,
--    the better: breakable crystals and ore (eggs and coins inside), eggs, air vents, cave aliens, cracked walls with
--    secret rooms behind them and the Deep Vault at the bottom.
-- Breakable things (crystals, rocks, volcanic bombs, ice blocks, cracked walls, chests) are hit with the bat or the raygun.
local ContentData = require(script.Parent:WaitForChild("ContentData"))

local Life = {}
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
Life.rgb = rgb

-- ---------------------------------------------------------------- damage to things
Life.BatDamage = 20          -- one bat hit on a crystal, a rock or a boss
Life.LaserScale = 1          -- x the raygun's damage on them
Life.BotDamage = 0.6         -- a bot's hit (bat or raygun) does this much of a player's
Life.SafeRadius = 70         -- the landing pad: no strikes, no bosses' attacks there

-- ---------------------------------------------------------------- weather
-- Fields (all optional):
--  Strike = periodic telegraphed impacts near the explorers {Kind, Every = {min, max} s per planet, Delay = warning s,
--           Radius, Damage, Knock, Near = {min, max} studs from the explorer picked, Egg = chance it leaves an egg,
--           Boost = rare boost of that egg, MutationStep, Break = chance it leaves a breakable (BreakKind) instead}
--  Air = air used x this (not under shelter); Speed = walk speed x this (not under shelter); Burn = damage/s (not under
--  shelter); Shelter = {Kind, PerExplorer, Radius, Near, Life}: things that protect you (campfire, mushroom cap, shade rock)
--  Wind (client push, studs/s), Gravity (client x), Fog (client), Shake (client)
--  Zone = hazard patches {Kind, Every, Life, Radius, Damage (per s), Air, Teleport = {min, max}, Launch, Near, Max, Egg, Boost}
--  Breakables = {Kind, Every, Max (per explorer), Near, Egg, Boost}
--  Eggs = eggs that turn up near the explorers {Every, Near, Boost, MutationStep, MinMutation, Height = {min, max}, Life, Look}
--  Flare = {Every, Warn, Damage, GoldenEggs}: a wave that hurts everybody not under shelter
Life.WeatherDuration = {80, 130}
Life.Weather = {
	MeteorRain = {Name = "Meteor Rain", Color = rgb(255, 120, 60), Hint = "Dodge the red circles - craters hide rare eggs!",
		Strike = {Kind = "Meteor", Every = {1.4, 2.4}, Delay = 1.7, Radius = 10, Damage = 22, Knock = 45, Near = {10, 70}, Egg = 0.25, Boost = 4}},
	Sandstorm = {Name = "Sandstorm", Color = rgb(230, 170, 90), Hint = "The wind digs buried eggs out - and blows you around",
		Wind = 22, Air = 1.25, Fog = {Density = 0.62, Color = rgb(214, 160, 100)},
		Eggs = {Every = 6, Near = {18, 70}, Boost = 2.5, Life = 60, Look = "Dig"}},
	Blizzard = {Name = "Blizzard", Color = rgb(190, 230, 255), Hint = "You freeze away from a campfire!",
		Air = 1.7, Speed = 0.8, Burn = 1.5, Fog = {Density = 0.6, Color = rgb(225, 238, 255)}, Wind = 10,
		Shelter = {Kind = "Campfire", PerExplorer = 2, Radius = 16, Near = {25, 70}, Life = 75, Heal = 4},
		Breakables = {Kind = "IceBlock", Every = 9, Max = 3, Near = {16, 60}, Egg = 0.75, Boost = 2.5}},
	Eruption = {Name = "Eruption", Color = rgb(255, 90, 30), Hint = "Volcanic bombs! Smash the fallen ones - eggs inside",
		Strike = {Kind = "VolcanoBomb", Every = {1.2, 2.1}, Delay = 2.2, Radius = 11, Damage = 28, Knock = 55, Near = {10, 75},
			Break = 0.35, BreakKind = "LavaBomb"}},
	AcidRain = {Name = "Acid Rain", Color = rgb(170, 255, 80), Hint = "Get under a mushroom cap! Toxic eggs grow in the rain",
		Burn = 3, Shelter = {Kind = "Mushroom", PerExplorer = 3, Radius = 14, Near = {15, 60}, Life = 70},
		Eggs = {Every = 8, Near = {18, 70}, Boost = 2, MutationStep = 1, Life = 60, Look = "Grow"}},
	SolarFlare = {Name = "Solar Flare", Color = rgb(255, 220, 90), Hint = "Hide behind a shade rock when the flare hits!",
		Shelter = {Kind = "ShadeRock", PerExplorer = 3, Radius = 13, Near = {15, 55}, Life = 70},
		Flare = {Every = 22, Warn = 5, Damage = 35, GoldenEggs = 1}},
	ThunderStorm = {Name = "Thunderstorm", Color = rgb(150, 170, 255), Hint = "Lightning charges the eggs it hits!",
		Fog = {Density = 0.5, Color = rgb(90, 100, 130)},
		Strike = {Kind = "Lightning", Every = {0.9, 1.7}, Delay = 1.1, Radius = 8, Damage = 30, Knock = 30, Near = {8, 70}, Egg = 0.15,
			Boost = 3, MutationStep = 1}},
	Earthquake = {Name = "Earthquake", Color = rgb(200, 140, 100), Hint = "Stay off the cracks - eggs bubble up out of them",
		Shake = true,
		Zone = {Kind = "Fissure", Every = 5, Life = 14, Radius = 5, Length = 34, Damage = 14, Near = {10, 60}, Max = 4, Egg = 0.5, Boost = 3}},
	CrystalBloom = {Name = "Crystal Bloom", Color = rgb(220, 130, 255), Hint = "Crystals sprout everywhere - smash them!",
		Breakables = {Kind = "Crystal", Every = 4.5, Max = 5, Near = {15, 70}, Egg = 0.4, Boost = 3}},
	GravityFlux = {Name = "Gravity Flux", Color = rgb(160, 120, 255), Hint = "Gravity is weak - eggs float up in the air!",
		Gravity = 0.35, Eggs = {Every = 6, Near = {16, 60}, Boost = 3, Height = {10, 24}, Life = 60, Look = "Float"}},
	SpiritFog = {Name = "Spirit Fog", Color = rgb(150, 255, 220), Hint = "Follow the wisps - they lead to hidden eggs",
		Fog = {Density = 0.8, Color = rgb(170, 220, 210)},
		Eggs = {Every = 11, Near = {60, 130}, Boost = 4, Life = 75, Look = "Wisp"}},
	SporeBloom = {Name = "Spore Bloom", Color = rgb(255, 110, 220), Hint = "Spore pods launch you high - spore clouds eat your air",
		Zone = {Kind = "SporeCloud", Every = 6, Life = 16, Radius = 14, Air = 2.5, Near = {10, 60}, Max = 4},
		Pads = {Kind = "SporePod", Every = 5, Life = 30, Radius = 5, Launch = 120, Near = {12, 50}, Max = 4},
		Eggs = {Every = 8, Near = {16, 60}, Boost = 3, Height = {20, 32}, Life = 60, Look = "Float"}},
	DataGlitch = {Name = "Data Glitch", Color = rgb(60, 240, 255), Hint = "Glitch zones teleport you - glitched eggs inside",
		Zone = {Kind = "Glitch", Every = 6, Life = 14, Radius = 12, Teleport = {30, 60}, Near = {10, 60}, Max = 4, Egg = 0.45, Boost = 3,
			Rainbow = 0.15}},
	Heatwave = {Name = "Heatwave", Color = rgb(255, 150, 40), Hint = "The heat burns your air - rest in the shade, mind the geysers",
		Air = 1.6, Speed = 0.9, Shelter = {Kind = "ShadeRock", PerExplorer = 3, Radius = 13, Near = {15, 55}, Life = 70},
		Strike = {Kind = "Geyser", Every = {2, 3.2}, Delay = 1.8, Radius = 7, Damage = 18, Knock = 75, Near = {8, 60}, Egg = 0.1, Boost = 3}},
	CometShower = {Name = "Comet Shower", Color = rgb(255, 240, 180), Hint = "Shooting stars drop star eggs!",
		Strike = {Kind = "Star", Every = {1.5, 2.6}, Delay = 1.5, Radius = 6, Damage = 0, Near = {10, 80}, Egg = 0.4, Boost = 5}},
	Hailstorm = {Name = "Hailstorm", Color = rgb(210, 235, 255), Hint = "Hailstones hurt - eggs frozen in ice blocks!",
		Fog = {Density = 0.5, Color = rgb(200, 215, 235)},
		Strike = {Kind = "Hail", Every = {0.5, 1}, Delay = 0.9, Radius = 4, Damage = 8, Knock = 15, Near = {3, 40}},
		Breakables = {Kind = "IceBlock", Every = 8, Max = 3, Near = {16, 60}, Egg = 0.7, Boost = 2.5}},
}
Life.PlanetWeather = {
	Moon = {"MeteorRain", "SolarFlare", "GravityFlux", "Earthquake", "CometShower"},
	Mars = {"Sandstorm", "MeteorRain", "Eruption", "Earthquake", "Heatwave"},
	Frostia = {"Blizzard", "Hailstorm", "ThunderStorm", "SpiritFog", "CrystalBloom"},
	Verdantis = {"ThunderStorm", "AcidRain", "SpiritFog", "Hailstorm", "SporeBloom"},
	Magmara = {"Eruption", "Heatwave", "Earthquake", "MeteorRain"},
	Crystalis = {"CrystalBloom", "MeteorRain", "SolarFlare", "Earthquake", "CometShower"},
	Mycelia = {"SporeBloom", "AcidRain", "SpiritFog", "ThunderStorm"},
	Neonix = {"DataGlitch", "ThunderStorm", "SolarFlare", "GravityFlux", "CometShower"},
	Nebulon = {"GravityFlux", "CometShower", "MeteorRain", "SolarFlare", "CrystalBloom"},
}
Life.MaxWeatherEggs = 6        -- weather eggs lying around per explorer at most

-- ---------------------------------------------------------------- breakables
-- HP in bat hits x Life.BatDamage; Coins = x the planet's Reward; Egg = chance of an egg inside
Life.Breakables = {
	Crystal = {Name = "Crystal", HP = 60, Coins = 0.2, Egg = 0.4, Boost = 3, Size = 7},
	Ore = {Name = "Ore Rock", HP = 80, Coins = 0.35, Egg = 0.1, Boost = 2, Size = 7},
	Geode = {Name = "Geode", HP = 100, Coins = 0.3, Egg = 0.6, Boost = 3.5, Size = 6},
	IceBlock = {Name = "Frozen Egg", HP = 60, Coins = 0.1, Egg = 1, Boost = 2.5, Size = 6},
	LavaBomb = {Name = "Volcanic Bomb", HP = 60, Coins = 0.15, Egg = 0.85, Boost = 4, Size = 6},
	Wall = {Name = "Cracked Wall", HP = 160, Coins = 0, Egg = 0, Size = 14},
	Chest = {Name = "Treasure Chest", HP = 40, Coins = 1, Egg = 1, Boost = 6, Size = 6},
	Vault = {Name = "Deep Vault Chest", HP = 80, Coins = 3, Egg = 1, Boost = 12, Super = 0.15, Size = 8},
	CometCore = {Name = "Comet Heart", HP = 200, Coins = 1.5, Egg = 1, Eggs = 3, Boost = 6, Size = 10},
}
-- surface geodes: always a few around every explorer (not only in some weather), never by the rocket
Life.Geodes = {PerExplorer = 4, Near = {50, 220}, Every = 3, Kinds = {"Crystal", "Ore", "Geode"}}

-- ---------------------------------------------------------------- bosses
Life.Boss = {Every = 600, First = 240, Duration = 210, Announce = 30, HealthPerExtra = 0.6, EggRain = {Base = 10, PerFighter = 4, Boost = 6,
	Super = 0.08, Radius = {12, 46}, Life = 120}, CoinsReward = 4}
Life.Bosses = {
	Moon = {Name = "Moon Golem", Body = "Golem", Health = 900, Damage = 24, Speed = 15, Scale = 1,
		Main = rgb(150, 154, 166), Dark = rgb(92, 96, 110), Glow = rgb(110, 230, 255)},
	Mars = {Name = "Sand Worm", Body = "Worm", Health = 1100, Damage = 28, Speed = 24, Scale = 1,
		Main = rgb(205, 130, 80), Dark = rgb(140, 72, 44), Glow = rgb(255, 196, 90)},
	Frostia = {Name = "Ice Yeti", Body = "Yeti", Health = 1300, Damage = 28, Speed = 19, Scale = 1,
		Main = rgb(236, 246, 255), Dark = rgb(150, 190, 230), Glow = rgb(110, 220, 255)},
	Verdantis = {Name = "Vine Beast", Body = "Golem", Health = 1500, Damage = 30, Speed = 16, Scale = 1.05,
		Main = rgb(70, 140, 60), Dark = rgb(60, 50, 40), Glow = rgb(200, 255, 90)},
	Magmara = {Name = "Lava Golem", Body = "Golem", Health = 1800, Damage = 34, Speed = 14, Scale = 1.15,
		Main = rgb(60, 52, 54), Dark = rgb(30, 26, 28), Glow = rgb(255, 110, 30)},
	Crystalis = {Name = "Crystal Titan", Body = "Golem", Health = 2000, Damage = 34, Speed = 15, Scale = 1.1,
		Main = rgb(150, 110, 210), Dark = rgb(80, 60, 130), Glow = rgb(130, 255, 240)},
	Mycelia = {Name = "Spore Brute", Body = "Yeti", Health = 2300, Damage = 36, Speed = 18, Scale = 1.1,
		Main = rgb(150, 90, 170), Dark = rgb(70, 50, 90), Glow = rgb(190, 255, 110)},
	Neonix = {Name = "Data Serpent", Body = "Worm", Health = 2600, Damage = 38, Speed = 26, Scale = 1.05,
		Main = rgb(36, 40, 70), Dark = rgb(20, 20, 40), Glow = rgb(60, 240, 255)},
	Nebulon = {Name = "Void Wyrm", Body = "Worm", Health = 3000, Damage = 40, Speed = 26, Scale = 1.15,
		Main = rgb(60, 40, 120), Dark = rgb(24, 16, 50), Glow = rgb(255, 220, 120)},
}
-- the boss's hitbox (studs, before Scale) and how far its attacks reach
Life.BossBodies = {
	Golem = {Size = Vector3.new(14, 20, 12), Slam = 20, Throw = 9, Reach = 12},
	Yeti = {Size = Vector3.new(12, 18, 10), Slam = 18, Throw = 7, Reach = 11},
	Worm = {Size = Vector3.new(10, 16, 10), Slam = 14, Throw = 8, Reach = 10},
}

-- ---------------------------------------------------------------- the Golden Egg race
Life.Golden = {Every = 300, First = 150, Duration = 240, Boost = 12, Super = 0.25, Coins = 6, Lost = 3}

-- ---------------------------------------------------------------- caves
Life.Caves = {
	Space = Vector3.new(0, 900, 46000),  -- where the caves are put together (above the fall height, far from everything)
	Step = 3200,                         -- between the planets' cave systems
	MainLength = 16, Branches = 0.5, BranchLength = {1, 3}, Secret = 0.4,
	Room = {Radius = {20, 32}, Height = {20, 30}}, Tunnel = {Width = 13, Height = 14, Length = {26, 46}},
	AirRate = 0.7,                       -- air used in the caves x this (it's sheltered down there)
	VentEvery = 3, VentAir = 35, VentCooldown = 45,
	AliensFrom = 4, AlienRespawn = 180,
	LootRespawn = 240,                   -- the crystals, rocks and eggs of a cleared chamber come back after this long
	Stalactites = {From = 6, Every = {6, 10}, Damage = 18},
	Sites = {{Angle = 75, Radius = 430, Name = "Shallow Cave"}, {Angle = 235, Radius = 900, Name = "Deep Cavern"}},
	Clear = 30,                          -- decor keeps this far from a cave mouth
}
local planetDefs = {}
for _, p in ipairs(ContentData.Planets) do planetDefs[p.Id] = p end
-- the cave mouths on a planet: {Index, Key, X, Z (from the planet centre), Name, Clear}
function Life.CaveSites(planetId)
	local def = planetDefs[planetId]
	if not def then return {} end
	local k = (def.Radius or 560) / 2800
	local list = {}
	for i, site in ipairs(Life.Caves.Sites) do
		local a = math.rad(site.Angle + (def.Order or 1) * 53)
		local r = site.Radius * math.max(0.3, k)
		table.insert(list, {Index = i, Key = planetId .. ":Cave" .. i, X = math.cos(a) * r, Z = math.sin(a) * r, Name = site.Name, Clear = Life.Caves.Clear})
	end
	return list
end
-- where a planet's cave system is built
function Life.CaveOrigin(planetId)
	local def = planetDefs[planetId]
	return Life.Caves.Space + Vector3.new(((def and def.Order or 1) - 1) * Life.Caves.Step, 0, 0)
end

-- ---------------------------------------------------------------- the extra world events (Events.lua)
Life.ExtraEvents = {
	{Id = "TreasureComet", Name = "Treasure Comet", Duration = 50, Color = {255, 200, 90},
		Buff = "A comet crashes on every planet - smash its crystal heart for eggs and coins!"},
	{Id = "CoinRain", Name = "Coin Rain", Duration = 45, Color = {255, 220, 60}, Buff = "Coins rain down on the planets - grab them!"},
	{Id = "EggTornado", Name = "Egg Tornado", Duration = 50, Color = {140, 220, 255},
		Buff = "Tornadoes full of eggs sweep the planets - they spit eggs out as they go!"},
}

return Life
