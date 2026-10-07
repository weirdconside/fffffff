--!nocheck
-- (v41) The Golden Egg race on screen (GameServer.PlanetLife.GoldenRace): the "GOLDEN EGG!" splash for everybody, a
-- pillar of golden light over the egg that you see from anywhere on its planet (it follows the carrier), a glow on
-- whoever holds it, an arrow at the edge of the screen with the distance, and the winner's moment.
-- (The tracker on the right marks the planet too: Tracker.lua.)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local UI = require(api:WaitForChild("UIKit"))
local player = Players.LocalPlayer
local C = UI.C
local S = Config.Sounds
local GOLD = Color3.fromRGB(255, 214, 60)

local folder = Instance.new("Folder")
folder.Name = "PFE_GoldenFX"
folder.Parent = workspace

local function here()
	return player:GetAttribute("PFESpectateWorld") or player:GetAttribute("PFETrackerPlanet") or "Earth"
end
local function racing()
	local planet = workspace:GetAttribute("PFEGoldenPlanet")
	return type(planet) == "string" and planet ~= "" and planet or nil
end

-- ---------------------------------------------------------------- the pillar of light
local pillar = Instance.new("Part")
pillar.Name = "GoldenPillar"; pillar.Anchored = true; pillar.CanCollide = false; pillar.CanQuery = false; pillar.CanTouch = false; pillar.CastShadow = false
pillar.Material = Enum.Material.Neon; pillar.Color = GOLD; pillar.Transparency = 0.45; pillar.Size = Vector3.new(500, 5, 5); pillar.Shape = Enum.PartType.Cylinder
local glowRing = Instance.new("Part")
glowRing.Name = "GoldenRing"; glowRing.Anchored = true; glowRing.CanCollide = false; glowRing.CanQuery = false; glowRing.CanTouch = false; glowRing.CastShadow = false
glowRing.Material = Enum.Material.Neon; glowRing.Color = GOLD; glowRing.Transparency = 0.6; glowRing.Shape = Enum.PartType.Cylinder; glowRing.Size = Vector3.new(0.2, 16, 16)
local sparkle = Instance.new("ParticleEmitter")
sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"; sparkle.Rate = 30; sparkle.Lifetime = NumberRange.new(1.5, 3)
sparkle.Speed = NumberRange.new(10, 25); sparkle.SpreadAngle = Vector2.new(8, 8); sparkle.Size = NumberSequence.new(1.6, 0)
sparkle.Color = ColorSequence.new(GOLD); sparkle.LightEmission = 1; sparkle.LightInfluence = 0; sparkle.EmissionDirection = Enum.NormalId.Right
sparkle.Parent = pillar
local beamLight = Instance.new("PointLight")
beamLight.Color = GOLD; beamLight.Range = 40; beamLight.Brightness = 3; beamLight.Parent = glowRing

-- whoever holds it glows
local carrierGlow = Instance.new("Highlight")
carrierGlow.Name = "GoldenCarrier"; carrierGlow.FillColor = GOLD; carrierGlow.OutlineColor = Color3.fromRGB(255, 255, 200)
carrierGlow.FillTransparency = 0.55; carrierGlow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; carrierGlow.Enabled = false
carrierGlow.Parent = folder

-- ---------------------------------------------------------------- the arrow
local gui = Instance.new("ScreenGui")
gui.Name = "PFE_GoldenEgg"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 23
gui.Parent = player:WaitForChild("PlayerGui")
local arrow = UI.new("Frame", {Name = "Arrow", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(84, 84), BackgroundTransparency = 1, Visible = false}, gui)
local arrowScale = UI.new("UIScale", {}, arrow)
local egg = UI.icon(arrow, "EggBig", UDim2.fromOffset(46, 46), UDim2.new(0.5, -23, 0, 4), {ZIndex = 3, ImageColor3 = GOLD})
local pointer = UI.icon(arrow, "Next", UDim2.fromOffset(34, 34), UDim2.new(0.5, -17, 0.5, -17), {ZIndex = 2, ImageColor3 = GOLD})
local distance = UI.text(arrow, "", UDim2.new(1, 40, 0, 22), UDim2.new(0, -20, 1, -20), 18, GOLD)
distance.TextXAlignment = Enum.TextXAlignment.Center; distance.TextWrapped = false
local _ = egg

local function layout()
	local camera = workspace.CurrentCamera
	if camera then arrowScale.Scale = math.clamp(UI.scaleFor(camera.ViewportSize), UI.minScale(), 1.1) end
end
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
layout()

RunService.RenderStepped:Connect(function()
	local planet = racing()
	local position = workspace:GetAttribute("PFEGoldenPos")
	local onIt = planet ~= nil and here() == planet and typeof(position) == "Vector3" and player:GetAttribute("PFECave") == nil
		and player:GetAttribute("PFEDungeon") == nil and player:GetAttribute("PFEFlightActive") ~= true
	-- the pillar and its ring
	if onIt then
		pillar.Parent = folder; glowRing.Parent = folder
		local t = os.clock()
		pillar.CFrame = CFrame.new(position + Vector3.new(0, 250, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		pillar.Size = Vector3.new(500, 4 + math.sin(t * 3) * 0.8, 4 + math.sin(t * 3) * 0.8)
		glowRing.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, t, math.pi / 2)
	else
		pillar.Parent = nil; glowRing.Parent = nil
	end
	-- the carrier's glow
	local carrierId = workspace:GetAttribute("PFEGoldenCarrier") or 0
	local carrier = carrierId > 0 and Players:GetPlayerByUserId(carrierId) or nil
	local carrierBody = carrier and carrier.Character
	if carrierId < 0 and onIt then
		-- a bot has it (bots have negative ids; their bodies are in workspace.PFE_Bots)
		local bots = workspace:FindFirstChild("PFE_Bots")
		for _, model in ipairs(bots and bots:GetChildren() or {}) do if model:GetAttribute("BotId") == -carrierId then carrierBody = model end end
	end
	carrierGlow.Adornee = onIt and carrierBody or nil
	carrierGlow.Enabled = carrierGlow.Adornee ~= nil
	-- the arrow at the edge of the screen (not for the one holding it)
	local camera = workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not onIt or not camera or not root or carrier == player then arrow.Visible = false; return end
	local d = (position - root.Position).Magnitude
	distance.Text = math.floor(d) .. "m"
	local vp = camera.ViewportSize
	local screen, inFront = camera:WorldToViewportPoint(position + Vector3.new(0, 4, 0))
	local margin = 70 * arrowScale.Scale
	local centre = vp / 2
	local dir = Vector2.new(screen.X, screen.Y) - centre
	if not inFront then dir = -dir end
	local onScreen = inFront and screen.X > margin and screen.X < vp.X - margin and screen.Y > margin and screen.Y < vp.Y - margin
	if onScreen then
		arrow.Position = UDim2.fromOffset(screen.X, screen.Y - 40 * arrowScale.Scale)
		pointer.Rotation = 90
	else
		if dir.Magnitude < 1 then dir = Vector2.new(0, -1) end
		local k = math.min((centre.X - margin) / math.max(1e-3, math.abs(dir.X)), (centre.Y - margin) / math.max(1e-3, math.abs(dir.Y)))
		local p = centre + dir * k
		arrow.Position = UDim2.fromOffset(p.X, p.Y)
		pointer.Rotation = math.deg(math.atan2(dir.Y, dir.X))
	end
	arrow.Visible = true
end)

-- ---------------------------------------------------------------- the splashes
local splash = UI.text(gui, "", UDim2.new(1, -40, 0, 64), UDim2.new(0, 20, 0.16, 0), 54, GOLD)
splash.TextXAlignment = Enum.TextXAlignment.Center; splash.TextTransparency = 1; splash.TextScaled = true
UI.new("UITextSizeConstraint", {MaxTextSize = 54, MinTextSize = 20}, splash)
local sub = UI.text(gui, "", UDim2.new(1, -40, 0, 30), UDim2.new(0, 20, 0.16, 64), 24, C.White)
sub.TextXAlignment = Enum.TextXAlignment.Center; sub.TextTransparency = 1; sub.TextScaled = true
UI.new("UITextSizeConstraint", {MaxTextSize = 24, MinTextSize = 12}, sub)
local token = 0
local function show(text, line, color, seconds)
	token += 1
	local mine = token
	splash.Text = text; splash.TextColor3 = color or GOLD; sub.Text = line or ""
	for _, l in ipairs({splash, sub}) do
		l.TextTransparency = 0
		local s = l:FindFirstChildOfClass("UIStroke"); if s then s.Transparency = 0 end
	end
	local pop = splash:FindFirstChildOfClass("UIScale") or UI.new("UIScale", {}, splash)
	pop.Scale = 0.3; UI.tween(pop, {Scale = 1}, 0.35, Enum.EasingStyle.Back)
	task.delay(seconds or 3.5, function()
		if mine ~= token then return end
		for _, l in ipairs({splash, sub}) do
			UI.tween(l, {TextTransparency = 1}, 0.4)
			local s = l:FindFirstChildOfClass("UIStroke"); if s then UI.tween(s, {Transparency = 1}, 0.4) end
		end
	end)
end
local function play(id, volume, speed)
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = volume or 0.6; s.PlaybackSpeed = speed or 1; s.Parent = SoundService
	s:Play(); Debris:AddItem(s, 8)
end
api:WaitForChild("Effect").OnClientEvent:Connect(function(kind, payload)
	if type(payload) ~= "table" then payload = {} end
	if kind == "GoldenStart" then
		if player:GetAttribute("PFECutscene") then return end
		show("THE GOLDEN EGG!", "appeared on " .. tostring(payload.PlanetName) .. " - first to get it into their rocket keeps it!", GOLD, 4.5)
		play(S.Legendary, 0.6, 1)
	elseif kind == "GoldenTaken" then
		show("YOU HAVE THE GOLDEN EGG!", "Run to your rocket - everybody is after you!", GOLD, 3)
		play(S.Riser, 0.5, 1.2)
	elseif kind == "GoldenWon" then
		if payload.Mine then
			show("GOLDEN EGG SECURED!", "+" .. Config.Format(tonumber(payload.Coins) or 0) .. " coins and the egg is yours!", GOLD, 5)
			play(S.Jackpot, 0.7, 1)
			play(S.Confetti, 0.6, 1)
		else
			show(string.upper(tostring(payload.Winner)) .. " WON THE GOLDEN EGG", "The next one comes in 5 minutes!", Color3.fromRGB(255, 230, 150), 3.5)
		end
	end
end)
