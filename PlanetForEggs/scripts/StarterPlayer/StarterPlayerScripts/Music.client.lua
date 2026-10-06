--!nocheck
-- Music and ambience, one track at a time, faded into each other (Config.Sounds):
--  * the island with the bases: (v28 Halloween) a spooky playlist, one track after another (Config.BasePlaylist)
--  * the rocket: calm space music, quietly, for the flight; nothing else (the rocket is silent)
--  * on a planet: its ambience - wind on the airless, dusty, icy, burning and crystal worlds; the night
--    forest on the jungle, fungal, neon and void ones
--  * Meteor Run (every 30 min): action music (Running Faster); aboard the alien ships: Scary Forest
--  * nothing while the title screen plays its own music (or the Halloween join cutscene, v37)
-- Also the interface's hover / click sounds on every button.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local player = Players.LocalPlayer
local S = Config.Sounds

local function track(name, id, volume, looped)
	local sound = Instance.new("Sound")
	sound.Name = "PFE_" .. name; sound.SoundId = id; sound.Looped = looped ~= false; sound.Volume = 0
	sound:SetAttribute("PFEKeepSound", true)
	sound.Parent = SoundService
	return {Sound = sound, Full = volume, Level = 0}
end
local tracks = {
	Base = track("BaseMusic", S.Base, 0.32),
	Flight = track("FlightMusic", S.FlightMusic, 0.7),
	Wind = track("Wind", S.Wind, 0.45),
	Forest = track("NightForest", S.NightForest, 0.5),
	Scary = track("ScaryForest", S.Scary, 0.35),
	Action = track("ActionMusic", S.Action, 0.45),
	PlanetMusic = track("PlanetMusic", "", 0.3, false),    -- (v29) calm music under every planet's ambience
}
tracks.Wind.Full = 0.3; tracks.Forest.Full = 0.32
-- (v30) on the planets the island's own music plays on, muffled (as if heard through the helmet), under a quiet wind
local muffle = Instance.new("EqualizerSoundEffect")
muffle.Name = "PFE_Muffle"; muffle.LowGain = 2; muffle.MidGain = -14; muffle.HighGain = -30; muffle.Enabled = false; muffle.Priority = 1
muffle.Parent = tracks.Base.Sound
local BASE_FULL = tracks.Base.Full
-- (v29) the planet's own calm tracks, one after the other
local planetList, planetIndex, planetFor = nil, 1, nil
local function setPlanetMusic(id)
	local list = Config.PlanetMusic and Config.PlanetMusic[id]
	if planetFor == id then return end
	planetFor = id
	planetList = list
	planetIndex = math.random(1, math.max(1, list and #list or 1))
	local s = tracks.PlanetMusic.Sound
	s:Stop()
	s.SoundId = list and list[planetIndex] or ""
	s.TimePosition = 0
end
tracks.PlanetMusic.Sound.Ended:Connect(function()
	if not planetList then return end
	planetIndex = planetIndex % #planetList + 1
	local s = tracks.PlanetMusic.Sound
	s.SoundId = planetList[planetIndex]; s.TimePosition = 0
	if tracks.PlanetMusic.Level > 0.001 then s:Play() end
end)
local WIND_SKIES = {Space = true, Mars = true, Frost = true, Lava = true, Crystal = true}
-- the island's playlist: when a track ends the next one starts (the base track does not loop)
local playlist = Config.BasePlaylist or {S.Base}
local playIndex = 1
tracks.Base.Sound.Looped = #playlist <= 1
tracks.Base.Sound.Ended:Connect(function()
	playIndex = playIndex % #playlist + 1
	tracks.Base.Sound.SoundId = playlist[playIndex]
	tracks.Base.Sound.TimePosition = 0
	if tracks.Base.Level > 0.001 then tracks.Base.Sound:Play() end
end)

local planetId, inMinigame = "Base", false
api:WaitForChild("State").OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	if payload.Planet ~= nil then planetId = payload.Planet end
	if not payload.Light then inMinigame = payload.Minigame ~= nil end
end)

local function oneShot(id, volume, speed)
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = volume or 0.5; s.PlaybackSpeed = speed or 1
	s:SetAttribute("PFEKeepSound", true); s.Parent = SoundService; s:Play()
	Debris:AddItem(s, 8)
end

-- which track should be on now
local function wanted()
	if player:GetAttribute("IntroActive") == true then return nil end
	if player:GetAttribute("PFECutscene") == true then return nil end   -- (v37) HalloweenIntro plays its own
	if player:GetAttribute("PFEFlightActive") == true then return "Flight" end
	local ship = player:GetAttribute("PFEDungeon")
	if inMinigame then return "Action" end
	if type(ship) == "string" and ship ~= "" then return "Scary" end
	local planet = Config.Planets[planetId]
	if planet then return "Base", true end
	return "Base", false
end

-- the rocket: its music from 0:30 (FLIGHT_START), fading in when the flight starts and out when it ends
local flying = false
local FLIGHT_START = 30
player:GetAttributeChangedSignal("PFEFlightActive"):Connect(function()
	local now = player:GetAttribute("PFEFlightActive") == true
	if now and not flying then
		local crab = tracks.Flight
		crab.Sound.TimePosition = FLIGHT_START
	end
	flying = now
end)

RunService.RenderStepped:Connect(function(dt)
	local want, onPlanet = wanted()
	local planetOn = false
	muffle.Enabled = onPlanet == true
	tracks.Base.Full = onPlanet and BASE_FULL * 0.7 or BASE_FULL
	tracks.Wind.Full = 0.12
	for key, t in pairs(tracks) do
		local target = (key == want or (key == "Wind" and onPlanet)) and t.Full or 0
		if key == "PlanetMusic" and t.Sound.SoundId == "" then target = 0 end
		local speed = (key == "Flight" or want == "Flight") and 0.6 or 0.3 -- volume per second (gentle fades in and out)
		if t.Level < target then t.Level = math.min(target, t.Level + speed * dt)
		elseif t.Level > target then t.Level = math.max(target, t.Level - speed * dt) end
		t.Sound.Volume = t.Level
		if t.Level > 0.001 and not t.Sound.IsPlaying then
			if key == "Flight" and t.Sound.TimePosition < FLIGHT_START then t.Sound.TimePosition = FLIGHT_START end
			t.Sound:Play()
		elseif t.Level <= 0.001 and t.Sound.IsPlaying then t.Sound:Pause() end
		-- (a track still loading can start from 0:00 whatever was set: keep the flight music from 0:30)
		if key == "Flight" and t.Sound.IsPlaying and t.Sound.IsLoaded and t.Sound.TimePosition < FLIGHT_START - 0.5 then
			t.Sound.TimePosition = FLIGHT_START
		end
	end
end)

-- ---------------------------------------------------------------- interface sounds
local lastHover = 0
local hooked = setmetatable({}, {__mode = "k"})
local function hook(button)
	if hooked[button] or not button:IsA("GuiButton") then return end
	hooked[button] = true
	button.MouseEnter:Connect(function()
		local t = os.clock()
		if t - lastHover > 0.06 then lastHover = t; oneShot(S.Hover, 0.25, 1) end
	end)
	button.Activated:Connect(function() oneShot(S.Click, 0.4, 1) end)
end
local gui = player:WaitForChild("PlayerGui")
for _, item in ipairs(gui:GetDescendants()) do hook(item) end
gui.DescendantAdded:Connect(hook)
