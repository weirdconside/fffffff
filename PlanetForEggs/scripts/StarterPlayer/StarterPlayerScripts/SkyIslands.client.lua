--!nocheck
-- Floating sky islands above the planet you are on. They are built here from ReplicatedStorage.PFE.Sky,
-- recoloured for the planet (Top = its ground, Rock = its stone, Core = its accent) and moved along the
-- shared SkyPaths every frame, so every player sees them in the same place. Their parts get the
-- island's velocity, which carries players standing on them. The planet's eggs lying on islands
-- (pickups with an IslandId) ride along: the prompt part and the egg model (placed by the server's
-- VisualOffset, so an egg a meteor rebuilt stays on its island too).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local SkyPaths = require(api:WaitForChild("SkyPaths"))
local sky = api:WaitForChild("Sky")
local player = Players.LocalPlayer

local folder = Instance.new("Folder")
folder.Name = "PFE_SkyIslands"
folder.Parent = workspace
local current = {Planet = nil, Seed = nil, Islands = {}}
local planetOfState = "Base"

local function recolor(model, planet)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			if part.Name == "Top" then
				part.Color = planet.GroundColor
			elseif part.Name == "Core" then
				part.Color = planet.Accent
				local light = Instance.new("PointLight"); light.Color = planet.Accent; light.Range = 16; light.Brightness = 1.2; light.Parent = part
			elseif part.Name == "Rock" or part.Name == "Stone" then
				local k = part.Color.R * 255 / 140
				part.Color = Color3.new(math.clamp(planet.RockColor.R * k, 0, 1), math.clamp(planet.RockColor.G * k, 0, 1), math.clamp(planet.RockColor.B * k, 0, 1))
			end
			part.Anchored = true
			part.CanTouch = false
			part.CastShadow = part.Size.Magnitude > 6
		end
	end
end

local function clear()
	folder:ClearAllChildren()
	current = {Planet = nil, Seed = nil, Islands = {}}
end

local function build(planetId)
	local seed = workspace:GetAttribute("PFEMapSeed") or 0
	if current.Planet == planetId and current.Seed == seed then return end
	clear()
	local planet = Config.Planets[planetId]
	if not planet then return end
	current.Planet, current.Seed = planetId, seed
	for _, island in ipairs(SkyPaths.Islands(planetId, seed)) do
		local template = sky:FindFirstChild(island.Model)
		if template then
			local model = template:Clone()
			model.Name = "Island_" .. island.Id
			recolor(model, planet)
			model.Parent = folder
			local parts, rel = {}, {}
			local pivot = model:GetPivot()
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then table.insert(parts, part); table.insert(rel, pivot:ToObjectSpace(part.CFrame)) end
			end
			table.insert(current.Islands, {Island = island, Model = model, Parts = parts, Rel = rel, CFrames = table.create(#parts)})
		end
	end
end

local function refresh()
	local planet = player:GetAttribute("PFESpectateWorld") or planetOfState   -- (admin "view": theirs)
	if Config.Planets[planet] then build(planet) else clear() end
end
player:GetAttributeChangedSignal("PFESpectateWorld"):Connect(function() refresh() end)
api:WaitForChild("State").OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or payload.Planet == nil then return end
	if payload.Planet ~= planetOfState then
		planetOfState = payload.Planet
		refresh()
	end
end)
workspace:GetAttributeChangedSignal("PFEMapSeed"):Connect(refresh)

-- (v36) the island eggs of the planet we are on, kept in a list (a pool has hundreds of ground eggs besides)
local islandItems, watchedPool, poolConns = {}, nil, {}
local function watchPool(pool)
	if pool == watchedPool then return end
	for _, c in ipairs(poolConns) do c:Disconnect() end
	table.clear(poolConns); table.clear(islandItems)
	watchedPool = pool
	if not pool then return end
	local function add(item) if item:GetAttribute("IslandId") then islandItems[item] = true end end
	for _, item in ipairs(pool:GetChildren()) do add(item) end
	table.insert(poolConns, pool.ChildAdded:Connect(add))
	table.insert(poolConns, pool.ChildRemoved:Connect(function(item) islandItems[item] = nil end))
end
local farClock = 0
RunService.Heartbeat:Connect(function(dt)
	if not current.Planet then watchPool(nil); return end
	local planet = Config.Planets[current.Planet]
	local t = workspace:GetServerTimeNow()
	local byId = {}
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	farClock += dt
	local farStep = farClock >= 1 / 15
	if farStep then farClock = 0 end
	for _, entry in ipairs(current.Islands) do
		local offset = SkyPaths.Offset(entry.Island, t)
		local at = planet.Origin + offset.Position
		local near = not eye or (at - eye).Magnitude < 320
		if near or farStep then
			-- (v36) one bulk move for all its parts (much cheaper than PivotTo, which walks the model every time)
			local pivot = CFrame.new(planet.Origin) * offset
			for i, r in ipairs(entry.Rel) do entry.CFrames[i] = pivot * r end
			local ok = pcall(function() workspace:BulkMoveTo(entry.Parts, entry.CFrames, Enum.BulkMoveMode.FireCFrameChanged) end)
			if not ok then entry.Model:PivotTo(pivot) end
		end
		-- (only islands someone could be standing on need the carrying velocity)
		if near then
			local velocity = SkyPaths.Velocity(entry.Island, t)
			for _, part in ipairs(entry.Parts) do part.AssemblyLinearVelocity = velocity end
		end
		byId[entry.Island.Id] = offset
	end
	-- the planet's eggs on islands ride with them
	local pickups = workspace:FindFirstChild("PFE_Pickups")
	local pool = pickups and pickups:FindFirstChild(current.Planet)
	watchPool(pool)
	if pool then
		for item in pairs(islandItems) do
			local id = item:GetAttribute("IslandId")
			local offset = id and byId[id]
			local proxy = offset and item:FindFirstChild("Pickup")
			if proxy then
				local target = CFrame.new(planet.Origin + offset.Position + Vector3.new(0, 1.95, 0))
				proxy.CFrame = target
				local visual = item:FindFirstChild("Visual")
				local visualOffset = item:GetAttribute("VisualOffset")
				if visual and typeof(visualOffset) == "CFrame" then visual:PivotTo(target * visualOffset) end
			end
		end
	end
end)
