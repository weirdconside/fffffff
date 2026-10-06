--!nocheck
-- Every egg glows in its rarity's colour (Config.EggGlow: grey, green, blue, purple, orange for the
-- rarest): on the planets, growing in the pens, in the hands, carried home. Roblox draws at most 31
-- Highlights at once, so the nearest MAX eggs to the camera get one (a small pool, re-assigned
-- a few times a second); the rarest (Secret / Eternal) show through walls, like Steal an Egg's.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))

local MAX = 28
local folder = Instance.new("Folder")
folder.Name = "PFE_EggHighlights"
folder.Parent = workspace
local pool = {}
for i = 1, MAX do
	local light = Instance.new("Highlight")
	light.Name = "EggGlow" .. i
	light.Enabled = false
	light.FillTransparency = 0.82
	light.OutlineTransparency = 0.05
	light.DepthMode = Enum.HighlightDepthMode.Occluded
	light.Parent = folder
	pool[i] = light
end

-- the egg models the game shows: they all carry EggId (clones of UIAssets.Eggs)
local function collect(list)
	local function add(model)
		if model and model:IsA("Model") and model.Parent and model:GetAttribute("EggId") then table.insert(list, model) end
	end
	local pickups = workspace:FindFirstChild("PFE_Pickups")
	if pickups then
		for _, planet in ipairs(pickups:GetChildren()) do
			for _, item in ipairs(planet:GetChildren()) do add(item:FindFirstChild("Visual")) end
		end
	end
	local world = workspace:FindFirstChild("PlanetForEggs")
	local bases = world and world:FindFirstChild("Bases")
	if bases then
		for _, base in ipairs(bases:GetChildren()) do
			local growing = base:FindFirstChild("GrowingEggs")
			if growing then for _, object in ipairs(growing:GetChildren()) do add(object:FindFirstChild("EggVisual")) end end
		end
	end
	add(workspace:FindFirstChild("LocalEquippedEgg"))
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		if character then add(character:FindFirstChild("CarriedPlanetEgg")) end
	end
	-- (v35) and the eggs in the bots' hands
	local botFolder = workspace:FindFirstChild("PFE_Bots")
	for _, bot in ipairs(botFolder and botFolder:GetChildren() or {}) do add(bot:FindFirstChild("CarriedPlanetEgg")) end
end

local elapsed = 1
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.3 then return end
	elapsed = 0
	local camera = workspace.CurrentCamera
	if not camera then return end
	local list = {}
	collect(list)
	local from = camera.CFrame.Position
	local scored = {}
	for _, model in ipairs(list) do
		local pivot = model:GetPivot().Position
		table.insert(scored, {Model = model, Distance = (pivot - from).Magnitude})
	end
	table.sort(scored, function(a, b) return a.Distance < b.Distance end)
	for i, light in ipairs(pool) do
		local entry = scored[i]
		if entry and entry.Distance < 600 then
			local info = Config.Eggs[entry.Model:GetAttribute("EggId")]
			local rarity = info and info.Rarity or "Common"
			local color = Config.EggGlow[rarity] or Config.EggGlow.Common
			if light.Adornee ~= entry.Model then light.Adornee = entry.Model end
			light.FillColor = color; light.OutlineColor = color
			light.DepthMode = (rarity == "Secret" or rarity == "Eternal") and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
			light.Enabled = true
		else
			light.Enabled = false
			light.Adornee = nil
		end
	end
end)
