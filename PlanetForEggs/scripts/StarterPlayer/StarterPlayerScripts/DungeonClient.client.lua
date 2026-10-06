--!nocheck
-- The alien ships (server: Dungeons.lua) on this side.
--  * The UFOs over the planets hover: a slow bob and turn. Their tractor beams and pads shimmer.
--  * Beaming up / leaving the ship: a flash in the beam's colour.
--  * Every level gets a splash ("LEVEL 2/3", "THE VAULT", "LEVEL CLEAR!"; floors in the stronghold),
--    the alien chest a big reveal of what was in it (a game pass for a while, or an egg).
--  * The alien chests glow and sparkle while they wait; opening one throws its lid back with a burst
--    of light and confetti.
--  * The UFOs hum (3D, heard from below).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local UI = require(api:WaitForChild("UIKit"))
local player = Players.LocalPlayer
local C = UI.C

local BEAM = Color3.fromRGB(120, 255, 170)

-- ---------------------------------------------------------------- screen: flash + splashes
local gui = Instance.new("ScreenGui")
gui.Name = "PFE_Dungeon"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 30
gui.ScreenInsets = Enum.ScreenInsets.None; gui.ClipToDeviceSafeArea = false -- the flash covers notched phones edge to edge
gui.Parent = player:WaitForChild("PlayerGui")
local flash = UI.new("Frame", {Name = "Flash", BackgroundColor3 = BEAM, BackgroundTransparency = 1, BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1), ZIndex = 50}, gui)
-- below the middle of the screen: the HUD's ship line and the toasts stay readable above it
local holder = UI.new("Frame", {Name = "Splash", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58),
	Size = UDim2.fromOffset(600, 120), BackgroundTransparency = 1, ZIndex = 40}, gui)
local holderScale = UI.new("UIScale", {}, holder)

local openNearestChest
local function sound(id, volume, speed)
	if not id then return end
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = volume; s.PlaybackSpeed = speed or 1; s.Parent = SoundService
	s:Play(); Debris:AddItem(s, 3)
end

local function doFlash(color, strength)
	flash.BackgroundColor3 = color or BEAM
	flash.BackgroundTransparency = 1 - (strength or 0.9)
	UI.tween(flash, {BackgroundTransparency = 1}, 0.9)
end

local current
local function splash(title, subtitle, color, hold)
	if current then current:Destroy() end
	local frame = UI.new("Frame", {Name = "Card", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 40}, holder)
	current = frame
	local s = UI.new("UIScale", {Scale = 0.3}, frame)
	local burst = UI.sunburst(frame, UDim2.fromOffset(320, 320), color, 0.55)
	burst.ZIndex = 40
	local head = UI.text(frame, title, UDim2.fromScale(1, 0.6), UDim2.fromScale(0, 0.04), 48, color:Lerp(C.White, 0.25))
	head.TextXAlignment = Enum.TextXAlignment.Center; head.TextWrapped = false; head.ZIndex = 42
	local sub = UI.text(frame, subtitle, UDim2.fromScale(1, 0.32), UDim2.fromScale(0, 0.64), 22, C.White)
	sub.TextXAlignment = Enum.TextXAlignment.Center; sub.ZIndex = 42
	UI.tween(s, {Scale = 1}, 0.35, Enum.EasingStyle.Back)
	task.delay(hold or 2.2, function()
		if not frame.Parent then return end
		UI.tween(s, {Scale = 0.2}, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.26, function() frame:Destroy() end)
	end)
end

local function layout()
	local camera = workspace.CurrentCamera
	if camera then
		holderScale.Scale = math.clamp(UI.scaleFor(camera.ViewportSize), 0.5, 1.1)
		-- short phone screens: a bit higher, clear of the objective line and the hotbar
		holder.Position = UDim2.fromScale(0.5, camera.ViewportSize.Y < 560 and 0.5 or 0.58)
	end
end
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
layout()

-- ---------------------------------------------------------------- the alien chests
local chests = {} -- chest model -> {Light, Phase}
local function trackChest(chest)
	if chests[chest] or not chest:IsA("Model") or chest:GetAttribute("AlienChest") ~= true then return end
	local main = chest:FindFirstChild("Main") or chest:FindFirstChildWhichIsA("BasePart", true)
	if not main then return end
	local light = Instance.new("PointLight"); light.Color = BEAM; light.Range = 16; light.Brightness = 1.5; light.Parent = main
	local sparkles = Instance.new("Sparkles"); sparkles.SparkleColor = BEAM; sparkles.Parent = main
	chests[chest] = {Light = light, Sparkles = sparkles, Main = main, Phase = math.random() * 6}
end
-- the lid swings back on its hinge (the back edge), light and the chest's own particles burst out
local function openLid(chest)
	local record = chests[chest]
	if not record or record.Opened then return end
	record.Opened = true
	local lid = chest:FindFirstChild("ChestLid")
	local main = record.Main
	if lid and lid:IsA("Model") then
		local frame = main.CFrame
		local box, size = lid:GetBoundingBox()
		local rel = frame:ToObjectSpace(box)
		local hinge = frame * CFrame.new(rel.Position.X, rel.Position.Y - size.Y / 2, rel.Position.Z + size.Z / 2)
		local offset = hinge:ToObjectSpace(lid:GetPivot())
		-- swing it the way its front edge goes up
		local centre = hinge:ToObjectSpace(box)
		local up = (CFrame.Angles(math.rad(80), 0, 0) * centre).Position.Y >= (CFrame.Angles(math.rad(-80), 0, 0) * centre).Position.Y
		local angle = Instance.new("NumberValue")
		angle.Changed:Connect(function(a) lid:PivotTo(hinge * CFrame.Angles(math.rad(a), 0, 0) * offset) end)
		TweenService:Create(angle, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Value = up and 80 or -80}):Play()
	end
	for _, e in ipairs(chest:GetDescendants()) do
		if e:IsA("ParticleEmitter") then pcall(function() e:Emit(30) end) end
	end
	record.Sparkles.Enabled = false
	record.Light.Color = Color3.fromRGB(255, 220, 120); record.Light.Brightness = 7; record.Light.Range = 24
	TweenService:Create(record.Light, TweenInfo.new(1.6), {Brightness = 1.2, Range = 12}):Play()
end
openNearestChest = function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local best, bestD
	for chest, record in pairs(chests) do
		if chest.Parent and root then
			local d = (record.Main.Position - root.Position).Magnitude
			if not bestD or d < bestD then best, bestD = chest, d end
		end
	end
	if best and bestD < 40 then openLid(best) end
end
task.spawn(function()
	local dungeons = workspace:WaitForChild("PFE_Dungeons", 30)
	local runs = dungeons and dungeons:WaitForChild("Runs", 30)
	if not runs then return end
	for _, d in ipairs(runs:GetDescendants()) do trackChest(d) end
	runs.DescendantAdded:Connect(function(d) task.defer(trackChest, d) end)
end)

api:WaitForChild("Effect").OnClientEvent:Connect(function(kind, payload)
	payload = type(payload) == "table" and payload or {}
	if kind == "DungeonEnter" then
		doFlash(BEAM, 0.95)
		sound(Config.Sounds.Teleport, 0.6, 1)
	elseif kind == "DungeonExit" then
		doFlash(BEAM, 0.8)
		sound(Config.Sounds.Teleport, 0.5, 0.9)
	elseif kind == "DungeonLevel" then
		if (tonumber(payload.Level) or 1) > 1 and not payload.Fort then doFlash(BEAM, 0.85); sound(Config.Sounds.Teleport, 0.5, 1.1) end -- through the airlock
		if payload.Vault then
			splash("THE VAULT", "Open the alien chest!", Color3.fromRGB(255, 205, 70))
		else
			local aliens = tonumber(payload.Aliens) or 0
			local word = payload.Fort and "FLOOR " or "LEVEL "
			splash(word .. tostring(payload.Level) .. "/" .. tostring(payload.Levels),
				aliens > 0 and ("Defeat the " .. aliens .. (aliens == 1 and " alien" or " aliens") .. (payload.Fort and " on this floor" or " aboard"))
					or "Clear the deck - the airlock opens soon",
				BEAM, 1.8)
		end
	elseif kind == "DungeonClear" then
		local text
		if payload.Fort then
			text = payload.Vault and "The gate is open - the alien chest is yours!" or "The doors upstairs are open - go up!"
		else
			text = payload.Vault and "The airlock to the vault is lit - walk in!" or "The airlock is lit - walk in to go on"
		end
		splash(payload.Fort and "FLOOR CLEAR!" or "LEVEL CLEAR!", text, Color3.fromRGB(120, 255, 120), 1.8)
		sound(Config.Sounds.LevelUp, 0.55, 1)
		task.delay(0.4, function() sound(Config.Sounds.DoorOpen, 0.5, 1) end)
	elseif kind == "DungeonLoot" then
		if payload.Kind == "Pass" then
			local pass = Config.GamePasses[payload.Key]
			local minutes = math.max(1, math.floor((tonumber(payload.Seconds) or 0) / 60 + 0.5))
			splash("ALIEN CHEST!", (pass and pass.Name or "Game pass") .. " for " .. minutes .. " min", pass and pass.Color or C.Gold, 3.2)
		elseif payload.Kind == "Egg" then
			local info = Config.Eggs[payload.EggId]
			local color = info and Config.Rarities[info.Rarity] and Config.Rarities[info.Rarity].Color or C.Gold
			local name = info and Config.EggDisplayName({EggId = payload.EggId, Mutation = payload.Mutation, Scale = payload.Scale}) or "An egg"
			splash("ALIEN CHEST!", name .. " - waiting at your base", color, 3.2)
		end
		doFlash(Color3.fromRGB(255, 230, 140), 0.5)
		sound(Config.Sounds.ChestOpen, 0.7, 1)
		task.delay(0.35, function() sound(Config.Sounds.Confetti, 0.6, 1) end)
		openNearestChest()
	end
end)

-- ---------------------------------------------------------------- the UFOs hover
local hovering = {} -- ufo model -> {Base = CFrame, Phase}
local beams = {}
local function hum(model)
	local part = model and (model:FindFirstChild("Main") or model:FindFirstChildWhichIsA("BasePart", true))
	if not part or part:FindFirstChild("UfoHum") then return end
	local s = Instance.new("Sound"); s.Name = "UfoHum"; s.SoundId = Config.Sounds.UfoHum; s.Looped = true; s.Volume = 0.6
	s.RollOffMode = Enum.RollOffMode.InverseTapered; s.RollOffMinDistance = 30; s.RollOffMaxDistance = 320
	s:SetAttribute("PFEKeepSound", true); s.Parent = part; s:Play()
end
local function track(site)
	local ufo = site:FindFirstChild("UFO")
	if ufo and ufo:IsA("Model") and not hovering[ufo] then hovering[ufo] = {Base = ufo:GetPivot(), Phase = math.random() * 6} end
	hum(ufo or site:FindFirstChild("Saucer"))
	for _, name in ipairs({"TractorBeam", "BeamPad"}) do
		local part = site:FindFirstChild(name)
		if part and not beams[part] then beams[part] = part.Transparency end
	end
end
task.spawn(function()
	local dungeons = workspace:WaitForChild("PFE_Dungeons", 30)
	local sites = dungeons and dungeons:WaitForChild("Sites", 30)
	if not sites then return end
	for _, site in ipairs(sites:GetChildren()) do track(site) end
	sites.ChildAdded:Connect(function(site) task.defer(track, site) end)
end)

local accumulator = 0
RunService.RenderStepped:Connect(function(dt)
	accumulator += dt
	if accumulator < 1 / 30 then return end
	accumulator = 0
	local camera = workspace.CurrentCamera
	if not camera then return end
	local t = os.clock()
	local eye = camera.CFrame.Position
	for ufo, info in pairs(hovering) do
		if not ufo.Parent then
			hovering[ufo] = nil
		elseif (info.Base.Position - eye).Magnitude < 2400 then
			ufo:PivotTo(info.Base * CFrame.new(0, math.sin(t * 0.8 + info.Phase) * 2.5, 0) * CFrame.Angles(0, t * 0.12 + info.Phase, 0))
		end
	end
	for chest, record in pairs(chests) do
		if not chest.Parent then chests[chest] = nil
		elseif not record.Opened then record.Light.Brightness = 1.2 + math.sin(t * 2.4 + record.Phase) * 0.8 end
	end
	for part, base in pairs(beams) do
		if not part.Parent then
			beams[part] = nil
		elseif (part.Position - eye).Magnitude < 2400 then
			part.Transparency = math.clamp(base + math.sin(t * 3 + part.Position.X) * 0.06, 0, 1)
		end
	end
end)
