--!nocheck
-- World presentation: builds the current planet's Blender decor from the server layout,
-- applies per-planet lighting / sky / gravity / ambient particles, shows region names,
-- plays flights and small world effects.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local api = ReplicatedStorage:WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local PlanetGen = require(api:WaitForChild("PlanetGen"))
local ModelUtil = require(api:WaitForChild("ModelUtil"))
local FlightFX = require(api:WaitForChild("FlightFX"))
local world = workspace:WaitForChild("PlanetForEggs")
local prefabRoot = api:WaitForChild("Prefabs")

local state = {Planet = "Base", RocketLevel = 1}
-- weak devices: phones, or graphics set low by hand (Roblox quality 1-3)
local function lowQualitySetting()
	local ok, level = pcall(function() return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value end)
	return ok and type(level) == "number" and level > 0 and level <= 3
end
local lowDetail = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) or lowQualitySetting()

-- ---------------------------------------------------------------- prefab index
local prefabs = {}
for _, lib in ipairs(prefabRoot:GetChildren()) do
	for _, model in ipairs(lib:GetChildren()) do prefabs[model.Name] = model end
end

-- ---------------------------------------------------------------- decor (streamed around the player)
-- v28: the planets are 5x wider (~45K decor models each) - far too many to build. The server keeps the layout
-- and hands out CHUNKS (PlanetGen.PackChunks); this client builds only the chunks within LOAD_R of the player
-- (nearest first, a few ms of work per frame) and takes the ones behind UNLOAD_R down again, so as you run
-- across a planet the forest grows in ahead of you behind the haze and disappears behind you.
--   * a flight preloads the chunks around the landing pad while the cinematic plays;
--   * a map reset while you stand on a planet rolls a thick "cosmic storm" fog in, swaps every chunk for the
--     new layout's behind it and clears the fog again, so it neither freezes nor pops.
-- Built pieces get cheap physics (no touch/query, no shadows on small parts) and only a few of their lights and
-- particles stay on.
local decor = Instance.new("Folder")
decor.Name = "PFE_PlanetDecor"
decor.Parent = workspace
local BUILD_MS = lowDetail and 3.5 or 5.5       -- ms of building per frame
local STORM_MS = lowDetail and 6 or 9           -- ms per frame behind the reset fog
local LIGHT_EVERY = lowDetail and 12 or 5       -- keep one light in N decor pieces
local LOAD_R = lowDetail and 420 or 620         -- studs around the player that are built
local UNLOAD_R = LOAD_R + 180                   -- built chunks further than this are taken down
local built, token = nil, 0
local regions = {}
local avoidNext                                 -- keep solid decor off this spot on the next build
local teardown = {}                             -- folders being destroyed a slice at a time
local stream = nil                              -- the planet being streamed (see buildDecor)

-- destroy old decor folders gradually (a few hundred models per frame)
local function retire(folder)
	if not folder then return end
	folder.Name = "Retired"
	table.insert(teardown, folder)
end
task.spawn(function()
	while true do
		local folder = teardown[1]
		if folder then
			local started = os.clock()
			local children = folder:GetChildren()
			for i = #children, 1, -1 do
				children[i]:Destroy()
				if os.clock() - started > 0.003 then break end
			end
			if #folder:GetChildren() == 0 then folder:Destroy(); table.remove(teardown, 1) end
		end
		task.wait()
	end
end)

local function clearDecor()
	token += 1
	built = nil
	stream = nil
	decor:SetAttribute("Building", false)
	for _, child in ipairs(decor:GetChildren()) do retire(child) end
	regions = {}
end

local function prepare(model, index, detail)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.CanTouch = false; item.CanQuery = false
			if detail then item.CanCollide = false end
			if detail or lowDetail or item.Size.Magnitude < 6 then item.CastShadow = false end
		elseif item:IsA("Light") then
			item.Enabled = index % LIGHT_EVERY == 0
			item.Shadows = false
		elseif item:IsA("ParticleEmitter") then
			if index % 2 == 1 then item.Enabled = false elseif lowDetail then item.Rate *= 0.5 end
		end
	end
end

-- the spot decor must keep clear after a reset: the player's character on this planet
local function playerSpot(origin)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local rel = root.Position - origin
		if Vector2.new(rel.X, rel.Z).Magnitude < 4000 and math.abs(rel.Y) < 600 then return Vector2.new(rel.X, rel.Z) end
	end
	return nil
end

-- where the streaming centres: the player on this planet, otherwise its landing pad
local function streamFocus(planetId)
	local planet = Config.Planets[planetId]
	if not planet then return Vector2.zero end
	if player:GetAttribute("PFEFlightActive") then return Vector2.zero end
	local spot = playerSpot(planet.Origin)
	return spot or Vector2.zero
end

-- ask the server for the layout header, and chunks (offline tests: generate locally)
local function fetchHeader(planetId)
	local remote = api:WaitForChild("PlanetLayout", 10)
	local ok, header = false, nil
	if remote then ok, header = pcall(remote.InvokeServer, remote, planetId) end
	if not ok or type(header) ~= "table" then
		local layout = PlanetGen.Generate(planetId, workspace:GetAttribute("PFEMapSeed") or 0)
		header = layout and PlanetGen.Header(layout)
	end
	return header
end
local function fetchChunks(planetId, seed, keys)
	local remote = api:FindFirstChild("PlanetChunks")
	local ok, packed = false, nil
	if remote then ok, packed = pcall(remote.InvokeServer, remote, planetId, seed, keys) end
	if not ok or type(packed) ~= "table" then
		local layout = PlanetGen.Generate(planetId, seed)
		packed = layout and PlanetGen.PackChunks(layout, keys)
	end
	return packed
end

local function placeRow(entry, origin, folder)
	local model = entry.Template:Clone()
	prepare(model, entry.Index, entry.Detail)
	if math.abs(entry.Scale - 1) > 0.01 then ModelUtil.SetScale(model, entry.Scale) end
	model:PivotTo(CFrame.new(origin + Vector3.new(entry.X, 0, entry.Z)) * CFrame.Angles(0, math.rad(entry.Rot), 0))
	model.Parent = folder
	return model
end

-- a thick fog / storm for the reset swap; returns a function that clears it again
local stormFx = {}
local function rollStormIn()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then return function() end end
	local saved = {Density = atmosphere.Density, Haze = atmosphere.Haze, Offset = atmosphere.Offset, Color = atmosphere.Color, Decay = atmosphere.Decay}
	local planet = Config.Planets[built or ""]
	local tint = planet and planet.Accent and planet.Accent:Lerp(Color3.fromRGB(200, 190, 255), 0.5) or Color3.fromRGB(180, 170, 230)
	TweenService:Create(atmosphere, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {Density = 0.9, Haze = 3, Offset = 1, Color = tint, Decay = tint:Lerp(Color3.new(0, 0, 0), 0.4)}):Play()
	stormFx.Active = true
	return function()
		stormFx.Active = false
		TweenService:Create(atmosphere, TweenInfo.new(1.4, Enum.EasingStyle.Quad), saved):Play()
	end
end

-- the chunk keys within `radius` of focus (planet-relative), nearest first
local function chunksAround(focus, radius, size)
	local list = {}
	local cx0, cz0 = math.floor((focus.X - radius) / size), math.floor((focus.Y - radius) / size)
	local cx1, cz1 = math.floor((focus.X + radius) / size), math.floor((focus.Y + radius) / size)
	for cx = cx0, cx1 do
		for cz = cz0, cz1 do
			local centre = Vector2.new((cx + 0.5) * size, (cz + 0.5) * size)
			local d = (centre - focus).Magnitude
			if d <= radius + size * 0.71 then table.insert(list, {Key = cx .. "," .. cz, D = d, Centre = centre}) end
		end
	end
	table.sort(list, function(a, b) return a.D < b.D end)
	return list
end

-- stream `planetId`'s decor. storm = a reset swap on the planet the player stands on
local function buildDecor(planetId, storm)
	if built == planetId and not storm and stream and stream.Planet == planetId then return end
	token += 1
	local myToken = token
	local previous = {}
	for _, child in ipairs(decor:GetChildren()) do table.insert(previous, child) end
	if not storm then for _, child in ipairs(previous) do retire(child) end; previous = {} end
	built = planetId
	local avoid = avoidNext
	avoidNext = nil
	decor:SetAttribute("Building", true)
	-- (a reset: the storm rolls in at once, while the new layout is fetched)
	local clearStorm = storm and rollStormIn() or nil
	task.spawn(function()
		local header = fetchHeader(planetId)
		if token ~= myToken or not header then
			decor:SetAttribute("Building", false)
			if clearStorm then clearStorm() end
			return
		end
		local origin = Config.Planets[planetId].Origin
		local size = header.Chunk or PlanetGen.Chunk or 192
		local folder = Instance.new("Folder")
		folder.Name = planetId
		folder.Parent = decor
		if storm then
			task.wait(0.9)
			-- the old forest goes first (fast, it is hidden in the fog)
			local budget = workspace:GetAttribute("PFEDecorBudget") or STORM_MS / 1000
			for _, old in ipairs(previous) do
				local children = old:GetChildren()
				local i = #children
				while i >= 1 do
					if token ~= myToken then break end
					local started = os.clock()
					while i >= 1 and os.clock() - started < budget do children[i]:Destroy(); i -= 1 end
					task.wait()
				end
				old:Destroy()
			end
		end
		regions = header.Regions or {}
		local me = {Planet = planetId, Seed = header.Seed, Folder = folder, Loaded = {}, Size = size, Origin = origin, Avoid = avoid}
		stream = me
		local queue = {}            -- rows waiting to be placed: {Key, Rows}
		local nextIndex = 0
		-- place what is queued within this frame's budget (nearest chunk first: the queue is in that order)
		local function work(budget)
			local started = os.clock()
			while #queue > 0 and os.clock() - started < budget do
				local job = queue[1]
				local chunk = me.Loaded[job.Key]
				if not chunk then table.remove(queue, 1); continue end
				local row = job.Rows[job.I]
				if not row then
					chunk.Done = true
					table.remove(queue, 1)
				else
					job.I += 1
					nextIndex += 1
					local name = job.Names[row[1]]
					local template = name and prefabs[name]
					if template then
						local detail = template:GetAttribute("Kind") == "Detail"
						local x, z = row[2], row[3]
						local blocked = me.Avoid and not detail and (Vector2.new(x, z) - me.Avoid).Magnitude < 9
						-- weak devices: a third of the small decor, every other big piece
						local hash = math.floor(math.abs(x * 7.3 + z * 13.1)) % 6
						local thin = lowDetail and ((detail and hash % 3 ~= 0) or (not detail and hash == 5))
						if not blocked and not thin then
							local model = placeRow({Template = template, Detail = detail, Index = nextIndex, X = x, Z = z, Rot = row[4], Scale = row[5]}, origin, folder)
							table.insert(chunk.Models, model)
						end
					end
				end
			end
		end
		-- the loop: request what is missing around the focus, place, and take far chunks down
		local first = true
		local clock = 0
		while token == myToken do
			local focus = streamFocus(planetId)
			local wanted = chunksAround(focus, LOAD_R, size)
			local missing = {}
			for _, c in ipairs(wanted) do
				if not me.Loaded[c.Key] then table.insert(missing, c.Key) end
				if #missing >= 24 then break end
			end
			if #missing > 0 then
				for _, key in ipairs(missing) do me.Loaded[key] = {Models = {}, Done = false} end
				local packed = fetchChunks(planetId, me.Seed, missing)
				if token ~= myToken then break end
				if packed and packed.Chunks then
					for _, key in ipairs(missing) do
						local rows = packed.Chunks[key]
						if rows and #rows > 0 then table.insert(queue, {Key = key, Rows = rows, Names = packed.Names, I = 1})
						else me.Loaded[key].Done = true end
					end
				else
					for _, key in ipairs(missing) do me.Loaded[key] = nil end
				end
			end
			-- take down the chunks far behind (a few per pass)
			local dropped = 0
			for key, chunk in pairs(me.Loaded) do
				local cx, cz = string.match(key, "^(-?%d+),(-?%d+)$")
				local centre = Vector2.new((tonumber(cx) + 0.5) * size, (tonumber(cz) + 0.5) * size)
				if (centre - focus).Magnitude > UNLOAD_R + size * 0.71 then
					for _, model in ipairs(chunk.Models) do model:Destroy() end
					me.Loaded[key] = nil
					dropped += 1
					if dropped >= 6 then break end
				end
			end
			-- build for a few frames, then look around again
			local budget = workspace:GetAttribute("PFEDecorBudget") or (storm and first and STORM_MS or BUILD_MS) / 1000
			local frames = 0
			repeat
				work(budget)
				task.wait()
				frames += 1
			until token ~= myToken or frames >= 8 or #queue == 0
			clock += frames
			if first and #queue == 0 then
				-- everything around the focus stands: done building (the fog can lift)
				first = false
				decor:SetAttribute("Building", false)
				if clearStorm then clearStorm(); clearStorm = nil end
			end
			if #queue == 0 then task.wait(0.15) end
		end
		if clearStorm then clearStorm() end
	end)
end

-- a new map cycle: rebuild the planet the player is on from the new layout behind a storm
workspace:GetAttributeChangedSignal("PFEMapSeed"):Connect(function()
	local planetId = built
	if planetId and Config.Planets[planetId] then
		avoidNext = playerSpot(Config.Planets[planetId].Origin)
		buildDecor(planetId, true)
	end
end)

-- ---------------------------------------------------------------- lighting presets
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
local sky = Lighting:FindFirstChildOfClass("Sky")
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local presets = {
	-- v28 Halloween: the island at a spooky dusk - an orange horizon under purple haze, a big moon, the pumpkins glowing
	Earth = {Clock = 18.25, Bright = 1.5, Amb = rgb(112, 88, 138), Out = rgb(126, 102, 150), Den = 0.32, Off = 0.12, Col = rgb(150, 92, 168), Dec = rgb(255, 120, 48), Glare = 0.25, Haze = 1.9, Bloom = 0.45, Thresh = 0.95, Tint = rgb(255, 236, 230), Sat = 0.12, Moon = 28},
	Space = {Clock = 13.6, Bright = 2.4, Amb = rgb(96, 100, 128), Out = rgb(120, 126, 158), Den = 0.36, Off = 0, Col = rgb(40, 44, 80), Dec = rgb(10, 10, 30), Glare = 0, Haze = 0, Bloom = 0.35, Thresh = 1, Tint = rgb(240, 244, 255), Sat = 0, Skybox = "Space", Sun = true},
	Flight = {Clock = 13, Bright = 2.8, Amb = rgb(70, 74, 100), Out = rgb(96, 102, 136), Den = 0, Off = 0, Col = rgb(20, 20, 40), Dec = rgb(5, 5, 15), Glare = 0, Haze = 0, Bloom = 0.55, Thresh = 0.9, Tint = rgb(236, 242, 255), Sat = 0.05, Skybox = "Space"},
	Mars = {Clock = 16.4, Bright = 2.3, Amb = rgb(150, 100, 80), Out = rgb(200, 140, 110), Den = 0.36, Off = 0.2, Col = rgb(240, 150, 100), Dec = rgb(170, 80, 50), Glare = 0.3, Haze = 1.4, Bloom = 0.25, Thresh = 1.1, Tint = rgb(255, 235, 220), Sat = 0.1},
	Frost = {Clock = 12, Bright = 2.6, Amb = rgb(150, 180, 210), Out = rgb(180, 210, 235), Den = 0.36, Off = 0.2, Col = rgb(200, 230, 255), Dec = rgb(120, 170, 230), Glare = 0.2, Haze = 1, Bloom = 0.25, Thresh = 1.1, Tint = rgb(235, 245, 255), Sat = 0},
	Jungle = {Clock = 13, Bright = 2.4, Amb = rgb(100, 140, 110), Out = rgb(140, 180, 150), Den = 0.36, Off = 0.15, Col = rgb(170, 230, 190), Dec = rgb(60, 140, 110), Glare = 0.2, Haze = 1.4, Bloom = 0.3, Thresh = 1.05, Tint = rgb(240, 255, 240), Sat = 0.15},
	Lava = {Clock = 18.1, Bright = 1.7, Amb = rgb(140, 75, 60), Out = rgb(170, 85, 60), Den = 0.42, Off = 0.3, Col = rgb(255, 110, 60), Dec = rgb(90, 20, 20), Glare = 0.5, Haze = 2, Bloom = 0.6, Thresh = 0.95, Tint = rgb(255, 225, 205), Sat = 0.15},
	Crystal = {Clock = 19.6, Bright = 1.9, Amb = rgb(150, 120, 190), Out = rgb(175, 145, 215), Den = 0.36, Off = 0.2, Col = rgb(220, 150, 255), Dec = rgb(90, 50, 160), Glare = 0.2, Haze = 1, Bloom = 0.6, Thresh = 0.95, Tint = rgb(245, 235, 255), Sat = 0.15},
	Toxic = {Clock = 19, Bright = 1.7, Amb = rgb(110, 120, 95), Out = rgb(130, 150, 110), Den = 0.42, Off = 0.25, Col = rgb(160, 230, 110), Dec = rgb(70, 40, 90), Glare = 0.2, Haze = 2, Bloom = 0.6, Thresh = 0.95, Tint = rgb(240, 255, 230), Sat = 0.15},
	Neon = {Clock = 0.1, Bright = 1.4, Amb = rgb(95, 95, 150), Out = rgb(115, 115, 175), Den = 0.36, Off = 0.1, Col = rgb(80, 60, 160), Dec = rgb(20, 10, 50), Glare = 0, Haze = 0.5, Bloom = 0.9, Thresh = 0.8, Tint = rgb(235, 235, 255), Sat = 0.2, Skybox = "Space"},
	-- aboard an alien ship (Dungeons): Dead Rails' "Alien" light made brighter - a light grey ambient and a
	-- pale green grade, no haze, the stars outside the windows
	Ship = {Clock = 14.5, Bright = 2.2, Amb = rgb(165, 172, 168), Out = rgb(172, 184, 178), Den = 0, Off = 0, Col = rgb(170, 170, 170), Dec = rgb(106, 112, 125), Glare = 0, Haze = 0, Bloom = 0.35, Thresh = 1.1, Tint = rgb(218, 255, 214), Sat = 0.05, Skybox = "Space"},
	Void = {Clock = 0.1, Bright = 1.5, Amb = rgb(115, 105, 165), Out = rgb(135, 125, 195), Den = 0.36, Off = 0.05, Col = rgb(70, 40, 140), Dec = rgb(20, 10, 40), Glare = 0, Haze = 0.3, Bloom = 0.8, Thresh = 0.85, Tint = rgb(240, 235, 255), Sat = 0.1, Skybox = "Space"},
	-- (v41) down in a cave: night, almost no ambient light, a dark haze - the flashlight, the glowing crystals and the vents
	-- are what you see by
	Cave = {Clock = 0, Bright = 0, Amb = rgb(26, 26, 34), Out = rgb(20, 20, 28), Den = 0.62, Off = 0, Col = rgb(8, 8, 14), Dec = rgb(4, 4, 8), Glare = 0, Haze = 0, Bloom = 0.7, Thresh = 0.9, Tint = rgb(235, 235, 255), Sat = 0.05, Skybox = "Space"},
}
-- the Milky Way skybox used in space and on airless worlds (public Creator Store set)
local SPACE_SKY = {Ft = 133001552999736, Bk = 132336371397963, Lf = 135011051064571, Rt = 89726705086909, Up = 102995181898486, Dn = 109149593532057}
local defaultSky = sky and {Ft = sky.SkyboxFt, Bk = sky.SkyboxBk, Lf = sky.SkyboxLf, Rt = sky.SkyboxRt, Up = sky.SkyboxUp, Dn = sky.SkyboxDn,
	Moon = sky.MoonTextureId}
local function setSkybox(kind)
	if not sky then return end
	local set = kind == "Space" and SPACE_SKY or defaultSky
	for _, face in ipairs({"Ft", "Bk", "Lf", "Rt", "Up", "Dn"}) do
		local v = set[face]
		if v ~= nil then sky["Skybox" .. face] = type(v) == "number" and ("rbxassetid://" .. v) or v end
	end
	sky.MoonTextureId = kind == "Space" and "" or (defaultSky.Moon or "")
end
local currentPreset
local function applyPreset(key, instant)
	local p = presets[key] or presets.Earth
	if currentPreset == key then return end
	currentPreset = key
	local info = TweenInfo.new(instant and 0 or 1.2, Enum.EasingStyle.Quad)
	local function set(object, props)
		if instant then for k, v in pairs(props) do object[k] = v end else TweenService:Create(object, info, props):Play() end
	end
	Lighting.ClockTime = p.Clock
	set(Lighting, {Brightness = p.Bright, Ambient = p.Amb, OutdoorAmbient = p.Out})
	set(atmosphere, {Density = p.Den, Offset = p.Off, Color = p.Col, Decay = p.Dec, Glare = p.Glare, Haze = p.Haze})
	if bloom then set(bloom, {Intensity = p.Bloom, Threshold = p.Thresh}) end
	if grade then set(grade, {TintColor = p.Tint, Saturation = p.Sat}) end
	setSkybox(p.Skybox)
	if sky then
		sky.StarCount = 5000
		sky.CelestialBodiesShown = p.Sun == true or key == "Earth" or key == "Mars" or key == "Frost" or key == "Jungle"
		pcall(function() sky.MoonAngularSize = p.Moon or 11 end)
	end
end

-- ---------------------------------------------------------------- sky bodies (follow the camera, feel infinitely far)
local skyFolder = Instance.new("Folder")
skyFolder.Name = "PFE_SkyBodies"
skyFolder.Parent = workspace
local skyBodies = {}
local function artBody(key, studs, direction, tint, glow)
	local art = Config.MapArt[key]
	if not art then return end
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Transparency = 1; p.Size = Vector3.new(1, 1, 1); p.Parent = skyFolder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(studs, studs); gui.LightInfluence = 0; gui.AlwaysOnTop = false; gui.MaxDistance = 100000; gui.Adornee = p; gui.Parent = p
	if glow then
		local halo = Instance.new("ImageLabel")
		halo.BackgroundTransparency = 1; halo.Image = "rbxassetid://94777715473697"; halo.ImageColor3 = glow; halo.ImageTransparency = 0.8
		halo.AnchorPoint = Vector2.new(0.5, 0.5); halo.Position = UDim2.fromScale(0.5, 0.5); halo.Size = UDim2.fromScale(1.45, 1.45); halo.Parent = gui
	end
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1; image.Image = "rbxassetid://" .. art.Image; image.ScaleType = Enum.ScaleType.Fit
	image.AnchorPoint = Vector2.new(0.5, 0.5); image.Position = UDim2.fromScale(0.5, 0.5); image.Size = UDim2.fromScale(1, 1)
	if art.Rect then image.ImageRectOffset = Vector2.new(art.Rect[1], art.Rect[2]); image.ImageRectSize = Vector2.new(art.Rect[3], art.Rect[4]) end
	if tint then image.ImageColor3 = tint end
	image.Parent = gui
	table.insert(skyBodies, {Part = p, Dir = direction.Unit, Dist = 3000})
	return p
end
local skyRecipes = {
	Moon = function() artBody("Earth", 900, Vector3.new(0.5, 0.35, -0.8), nil, rgb(120, 190, 255)) end,
	Mars = function() artBody("Moon", 120, Vector3.new(-0.4, 0.5, -0.8)); artBody("Moon", 80, Vector3.new(0.6, 0.6, -0.5), rgb(210, 190, 180)) end,
	Frostia = function() artBody("Nebulon", 1900, Vector3.new(0.3, 0.45, -0.85), rgb(210, 230, 255)) end,
	Verdantis = function() artBody("Crystalis", 520, Vector3.new(-0.6, 0.4, -0.7)); artBody("Moon", 160, Vector3.new(0.7, 0.55, 0.3), rgb(230, 255, 230)) end,
	Magmara = function() artBody("Magmara", 1300, Vector3.new(0.2, 0.25, -0.95), nil, rgb(255, 120, 40)) end,
	Crystalis = function() artBody("Mycelia", 900, Vector3.new(-0.3, 0.5, -0.8), nil, rgb(200, 140, 255)) end,
	Mycelia = function() artBody("Neonix", 700, Vector3.new(0.5, 0.4, -0.75)); artBody("Verdantis", 220, Vector3.new(-0.6, 0.6, -0.4)) end,
	Neonix = function() artBody("Nebulon", 1400, Vector3.new(0.2, 0.45, -0.9), rgb(220, 200, 255)); artBody("Mycelia", 300, Vector3.new(-0.7, 0.35, -0.6)) end,
	Nebulon = function() artBody("Neonix", 1100, Vector3.new(0.1, 0.35, -0.95), nil, rgb(170, 110, 255)) end,
}
local function setSky(planetId)
	skyFolder:ClearAllChildren(); skyBodies = {}
	local recipe = skyRecipes[planetId]
	if recipe then recipe() end
end

-- ---------------------------------------------------------------- ambient particles around the camera
local ambientPart = Instance.new("Part")
ambientPart.Name = "PFE_Ambient"; ambientPart.Anchored = true; ambientPart.CanCollide = false; ambientPart.CanQuery = false; ambientPart.CanTouch = false
ambientPart.Transparency = 1; ambientPart.Size = Vector3.new(140, 60, 140); ambientPart.Parent = workspace
local ambient = Instance.new("ParticleEmitter")
ambient.Shape = Enum.ParticleEmitterShape.Box; ambient.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward; ambient.Enabled = false
ambient.LightInfluence = 0; ambient.Parent = ambientPart
local ambientKinds = {
	Dust = {Tex = "rbxasset://textures/particles/sparkles_main.dds", Color = rgb(210, 220, 255), Rate = 25, Size = 0.25, Speed = 1, Accel = Vector3.new(0, 0.3, 0), Life = 6, Emit = 0.6},
	RedDust = {Tex = "rbxasset://textures/particles/smoke_main.dds", Color = rgb(220, 120, 80), Rate = 14, Size = 6, Speed = 6, Accel = Vector3.new(4, 0, 1), Life = 6, Emit = 0.1, Transparency = 0.8},
	Snow = {Tex = "rbxasset://textures/particles/sparkles_main.dds", Color = rgb(255, 255, 255), Rate = 90, Size = 0.35, Speed = 2, Accel = Vector3.new(1, -6, 0), Life = 8, Emit = 0.3},
	Fireflies = {Tex = "rbxasset://textures/particles/sparkles_main.dds", Color = rgb(220, 255, 120), Rate = 18, Size = 0.4, Speed = 1.5, Accel = Vector3.new(0, 0.5, 0), Life = 5, Emit = 1},
	Embers = {Tex = "rbxasset://textures/particles/fire_sparks_main.dds", Color = rgb(255, 150, 60), Rate = 40, Size = 0.35, Speed = 3, Accel = Vector3.new(0, 4, 0), Life = 5, Emit = 1},
	Sparkles = {Tex = "rbxasset://textures/particles/sparkles_main.dds", Color = rgb(255, 170, 240), Rate = 30, Size = 0.4, Speed = 1, Accel = Vector3.new(0, 1, 0), Life = 5, Emit = 1},
	Spores = {Tex = "rbxasset://textures/particles/sparkles_main.dds", Color = rgb(190, 255, 110), Rate = 40, Size = 0.45, Speed = 1, Accel = Vector3.new(0, 0.8, 0), Life = 7, Emit = 0.8},
	Digital = {Tex = "rbxasset://textures/particles/SquareParticle.png", Color = rgb(60, 240, 255), Rate = 30, Size = 0.3, Speed = 2, Accel = Vector3.new(0, 2, 0), Life = 4, Emit = 1},
	Stardust = {Tex = "rbxasset://textures/particles/sparkles_main.dds", Color = rgb(230, 210, 255), Rate = 45, Size = 0.3, Speed = 0.8, Accel = Vector3.new(0, 0.4, 0), Life = 6, Emit = 1},
}
local function setAmbient(kind)
	local spec = ambientKinds[kind]
	if not spec then ambient.Enabled = false; return end
	ambient.Texture = spec.Tex; ambient.Color = ColorSequence.new(spec.Color); ambient.Rate = lowDetail and spec.Rate * 0.5 or spec.Rate
	ambient.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, spec.Size), NumberSequenceKeypoint.new(1, 0)})
	ambient.Speed = NumberRange.new(spec.Speed * 0.5, spec.Speed); ambient.Acceleration = spec.Accel
	ambient.Lifetime = NumberRange.new(spec.Life * 0.6, spec.Life); ambient.LightEmission = spec.Emit
	ambient.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, spec.Transparency or 0.1), NumberSequenceKeypoint.new(1, 1)})
	ambient.SpreadAngle = Vector2.new(180, 180)
	ambient.Enabled = true
end

-- ---------------------------------------------------------------- region names
local lastRegion
local toast = function(text)
	local popup = player.PlayerGui:FindFirstChild("PFE_LocalToast")
	if popup then popup:Fire(text, "Blue") end
end
local function updateRegion()
	local watchedId = player:GetAttribute("PFESpectateUserId")
	local watched = watchedId and Players:GetPlayerByUserId(watchedId)
	local planet = Config.Planets[player:GetAttribute("PFESpectateWorld") or state.Planet]
	local character = watched and watched.Character or player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local name
	local cave = player:GetAttribute("PFECave")
	if type(cave) == "string" and cave ~= "" and not watched then
		-- (v41) in a cave: its name and how deep you are
		local depth = player:GetAttribute("PFECaveDepth") or 0
		name = depth > 0 and (cave .. "  -  depth " .. depth .. "/" .. (player:GetAttribute("PFECaveMax") or 16)) or cave
	elseif planet and rootPart and not state.Busy then
		local rel = rootPart.Position - planet.Origin
		for _, region in ipairs(regions) do
			if (Vector2.new(rel.X - region.X, rel.Z - region.Z)).Magnitude <= (region.Radius or 100) * 1.05 then name = region.Name; break end
		end
		name = name or (rel.Magnitude < 60 and "Landing Site" or "Wilds")
	end
	if name ~= lastRegion then
		lastRegion = name
		player:SetAttribute("PFERegion", name)
	end
end

-- ---------------------------------------------------------------- planet switch
-- Only the map the player is on is drawn: every other planet (and Earth while you are away)
-- is hidden locally, so no map can be seen from another one. Fireflies, lights and labels of
-- hidden maps are switched off too. Parts stay where they are (server logic is untouched).
local hiddenMaps = {} -- root -> {Saved = {[Instance] = {property, value}}, Link = connection}
local function conceal(saved, item)
	if saved[item] then return end
	if item:IsA("BasePart") or item:IsA("Decal") then
		saved[item] = {"LocalTransparencyModifier", item.LocalTransparencyModifier or 0}; item.LocalTransparencyModifier = 1
	elseif item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") or item:IsA("Light")
		or item:IsA("BillboardGui") or item:IsA("SurfaceGui") or item:IsA("Fire") or item:IsA("Smoke") or item:IsA("Sparkles") then
		saved[item] = {"Enabled", item.Enabled ~= false}; item.Enabled = false
	end
end
local function hideMap(root)
	if not root or hiddenMaps[root] then return end
	local record = {Saved = {}}
	hiddenMaps[root] = record
	record.Link = root.DescendantAdded:Connect(function(item) conceal(record.Saved, item) end)
	task.spawn(function()
		local started = os.clock()
		for _, item in ipairs(root:GetDescendants()) do
			if hiddenMaps[root] ~= record then return end
			conceal(record.Saved, item)
			if os.clock() - started > 0.004 then task.wait(); started = os.clock() end
		end
	end)
end
local function showMap(root)
	local record = root and hiddenMaps[root]
	if not record then return end
	hiddenMaps[root] = nil
	record.Link:Disconnect()
	-- restored a few thousand at a time (Earth alone is ~11k parts) so arriving never hitches
	task.spawn(function()
		local started = os.clock()
		for item, saved in pairs(record.Saved) do
			if hiddenMaps[root] then return end -- hidden again meanwhile
			if item.Parent then item[saved[1]] = saved[2] end
			if os.clock() - started > 0.004 then task.wait(); started = os.clock() end
		end
	end)
end
-- folders whose children carry a Planet attribute (dungeon sites, aliens)
local function planetBound()
	local list = {}
	local dungeons = workspace:FindFirstChild("PFE_Dungeons")
	local sites = dungeons and dungeons:FindFirstChild("Sites")
	if sites then table.insert(list, sites) end
	local aliens = workspace:FindFirstChild("PFE_Aliens")
	if aliens then table.insert(list, aliens) end
	-- (v41) the weather's things, the bosses, the cave mouths: one folder per planet
	local life = workspace:FindFirstChild("PFE_PlanetLife")
	if life then table.insert(list, life) end
	return list
end
local visibleWorld = "Base"
local function setVisibleMap(planetId)
	visibleWorld = planetId
	local onEarth = not Config.Planets[planetId]
	for _, planet in ipairs(world.Planets:GetChildren()) do
		if planet.Name == planetId then showMap(planet) end
	end
	if onEarth then showMap(world:FindFirstChild("OriginalIsland")); showMap(world:FindFirstChild("Bases")) end
	for _, planet in ipairs(world.Planets:GetChildren()) do
		if planet.Name ~= planetId then hideMap(planet) end
	end
	if not onEarth then hideMap(world:FindFirstChild("OriginalIsland")); hideMap(world:FindFirstChild("Bases")) end
	-- the alien ships' entrances and the aliens belong to their planet too: seen only there
	-- (from the island with the bases none of the UFOs, wrecks or aliens show)
	for _, folder in ipairs(planetBound()) do
		for _, item in ipairs(folder:GetChildren()) do
			local owner = item:GetAttribute("Planet")
			if owner == planetId then showMap(item) elseif owner ~= nil then hideMap(item) end
		end
	end
end

task.spawn(function()
	local dungeons = workspace:WaitForChild("PFE_Dungeons", 60)
	local watched = {}
	local sites = dungeons and dungeons:WaitForChild("Sites", 60)
	if sites then table.insert(watched, sites) end
	local aliens = workspace:WaitForChild("PFE_Aliens", 60)
	if aliens then table.insert(watched, aliens) end
	local life = workspace:WaitForChild("PFE_PlanetLife", 60)
	if life then table.insert(watched, life) end
	for _, folder in ipairs(watched) do
		local function place(item)
			local owner = item:GetAttribute("Planet")
			if owner ~= nil and owner ~= visibleWorld then hideMap(item) end
		end
		for _, item in ipairs(folder:GetChildren()) do place(item) end
		folder.ChildAdded:Connect(function(item) task.defer(place, item) end)
		folder.ChildRemoved:Connect(function(item)
			local record = hiddenMaps[item]
			if record then record.Link:Disconnect(); hiddenMaps[item] = nil end
		end)
	end
end)

local worldNow = "Base"
local function setWorld(planetId)
	worldNow = planetId
	local planet = Config.Planets[planetId]
	setVisibleMap(planetId)
	-- (spectating someone elsewhere: their world is drawn, but you keep your own planet's gravity)
	local own = Config.Planets[state.Planet]
	if planet then
		buildDecor(planetId)
		applyPreset(planet.Sky)
		setSky(planetId)
		setAmbient(planet.Particles)
		workspace.Gravity = Config.BaseGravity * ((player:GetAttribute("PFESpectateWorld") and (own and own.Gravity or 1)) or planet.Gravity)
	else
		clearDecor()
		applyPreset("Earth")
		setSky(nil)
		setAmbient(nil)
		workspace.Gravity = Config.BaseGravity
	end
end

-- aboard an alien ship: the ship's light, normal gravity, no planet weather; the planet's again after
local function refreshShip()
	local ship = player:GetAttribute("PFEDungeon")
	local cave = player:GetAttribute("PFECave")
	local planet = Config.Planets[worldNow]
	if type(ship) == "string" and ship ~= "" then
		applyPreset("Ship")
		setAmbient(nil)
		workspace.Gravity = Config.BaseGravity
	elseif type(cave) == "string" and cave ~= "" and planet then
		-- (v41) in a cave: dark, no planet weather, ordinary gravity (the jumps down there are made for it)
		applyPreset("Cave")
		setAmbient(nil)
		setSky(nil)
		workspace.Gravity = Config.BaseGravity
	elseif planet then
		applyPreset(planet.Sky)
		setAmbient(planet.Particles)
		workspace.Gravity = Config.BaseGravity * planet.Gravity
	end
end
player:GetAttributeChangedSignal("PFEDungeon"):Connect(refreshShip)
player:GetAttributeChangedSignal("PFECave"):Connect(function()
	refreshShip()
	-- (back out of a cave: the planet's sky bodies again)
	if not player:GetAttribute("PFECave") and Config.Planets[worldNow] then setSky(worldNow) end
end)

-- ---------------------------------------------------------------- rocket upgrade visuals
local function refreshRocket(rocket, level)
	for _, p in ipairs(rocket:GetDescendants()) do
		local required = p:GetAttribute("RequiresLevel")
		if p:IsA("BasePart") and required then
			p.Transparency = level >= required and (p:GetAttribute("BaseTransparency") or 0) or 1
			for _, fx in ipairs(p:GetChildren()) do if fx:IsA("PointLight") then fx.Enabled = level >= required end end
		end
	end
end
for _, base in ipairs(world.Bases:GetChildren()) do
	local rocket = base:FindFirstChild("Rocket")
	if rocket then
		refreshRocket(rocket, base:GetAttribute("RocketLevel") or 1)
		base:GetAttributeChangedSignal("RocketLevel"):Connect(function() refreshRocket(rocket, base:GetAttribute("RocketLevel") or 1) end)
	end
end
local function refreshReturnRockets()
	for _, planet in ipairs(world.Planets:GetChildren()) do
		local rocket = planet:FindFirstChild("ReturnRocket")
		if rocket then refreshRocket(rocket, state.RocketLevel or 1) end
	end
end

-- ---------------------------------------------------------------- state & flights
local lastPlanet
api:WaitForChild("State").OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	for k, v in pairs(payload) do state[k] = v end
	if not payload.Light then refreshReturnRockets() end
	local planet = player:GetAttribute("PFESpectateWorld") or state.Planet
	if planet ~= lastPlanet and not (state.Busy and player:GetAttribute("PFEFlightActive")) then
		lastPlanet = planet
		setWorld(planet)
	end
end)
-- admin "view": the watched player's world while watching, yours again after
player:GetAttributeChangedSignal("PFESpectateWorld"):Connect(function()
	local planet = player:GetAttribute("PFESpectateWorld") or state.Planet
	if planet ~= lastPlanet then lastPlanet = planet; setWorld(planet) end
end)

api:WaitForChild("Flight").OnClientEvent:Connect(function(info)
	if type(info) ~= "table" then return end
	local fromPlanet = state.Planet
	local rocket, landing
	if fromPlanet ~= "Base" and Config.Planets[fromPlanet] then
		local model = world.Planets:FindFirstChild(fromPlanet)
		rocket = model and model:FindFirstChild("ReturnRocket")
	else
		local base = world.Bases:FindFirstChild("Base" .. tostring(info.BaseIndex or state.BaseIndex or 1))
		rocket = base and base:FindFirstChild("Rocket")
	end
	if info.Destination == "Base" then
		local base = world.Bases:FindFirstChild("Base" .. tostring(info.BaseIndex or state.BaseIndex or 1))
		landing = base and base:FindFirstChild("Rocket")
	else
		local model = world.Planets:FindFirstChild(info.Destination)
		landing = model and model:FindFirstChild("ReturnRocket")
		buildDecor(info.Destination) -- start building while the cinematic plays
	end
	local arrived = false
	local function arrive()
		if arrived then return end
		arrived = true
		lastPlanet = info.Destination
		setWorld(info.Destination)
	end
	-- fallback if the cinematic cannot play (no rocket model): switch at the teleport
	task.delay(math.max(1, (tonumber(info.Duration) or Config.FlightDuration) - 0.1), arrive)
	if not rocket then return end
	FlightFX.Play(rocket, info, landing, {
		Space = function()
			applyPreset("Flight", true); setSky(nil); setAmbient(nil)
		end,
		Arrive = arrive,
	})
end)
player.CharacterAdded:Connect(function() FlightFX.Cancel() end)

-- ---------------------------------------------------------------- catching a thief
api:WaitForChild("Effect").OnClientEvent:Connect(function(kind, payload)
	if kind ~= "Catch" or type(payload) ~= "table" then return end
	local thief = Players:GetPlayerByUserId(payload.To or 0)
	local body = thief and thief.Character
	if not body and (tonumber(payload.To) or 0) < 0 then
		-- (v35) a bot caught with an egg
		local bots = workspace:FindFirstChild("PFE_Bots")
		for _, model in ipairs(bots and bots:GetChildren() or {}) do if model:GetAttribute("BotId") == -payload.To then body = model end end
	end
	local root = body and body:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - root.Position).Magnitude > 150 then return end
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/impact_water.mp3"; s.PlaybackSpeed = 1.4; s.Volume = 0.7; s.Parent = root
	s:Play()
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"; burst.LightEmission = 1; burst.Rate = 0
	burst.Speed = NumberRange.new(12, 24); burst.SpreadAngle = Vector2.new(180, 180); burst.Lifetime = NumberRange.new(0.4, 0.8)
	burst.Size = NumberSequence.new(1.2, 0); burst.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90)); burst.Parent = root
	burst:Emit(40)
	task.delay(2, function() s:Destroy(); burst:Destroy() end)
end)

-- ---------------------------------------------------------------- per-frame
local regionClock, rainbowClock = 0, 0
RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	if camera then
		local camPos = camera.CFrame.Position
		ambientPart.CFrame = CFrame.new(camPos + Vector3.new(0, 10, 0))
		for _, entry in ipairs(skyBodies) do
			local cf = CFrame.new(camPos + entry.Dir * entry.Dist)
			local tilt = entry.Part:GetAttribute("Tilt")
			if tilt then cf = CFrame.lookAt(cf.Position, camPos) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(tilt), 0, 0) end
			entry.Part.CFrame = cf
		end
	end
	regionClock += dt
	if regionClock > 0.5 then regionClock = 0; updateRegion() end
	rainbowClock += dt
end)

-- Rainbow mutation colour cycling (pets in pens, eggs in pens and on planets).
-- (a registry fed by DescendantAdded; parts of each model are listed once)
local rainbow = {}
local function watchRainbow(item)
	if item:IsA("Model") and item:GetAttribute("RainbowMutation") and not rainbow[item] then
		local parts = {}
		for _, p in ipairs(item:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 0.9 and p.Name ~= "Pupil" and p.Name ~= "Eye" and p.Material ~= Enum.Material.Neon then
				table.insert(parts, p)
			end
		end
		rainbow[item] = parts
	end
end
for _, root in ipairs({world.Bases, workspace:WaitForChild("PFE_Pickups", 10)}) do
	if root then
		for _, item in ipairs(root:GetDescendants()) do watchRainbow(item) end
		root.DescendantAdded:Connect(function(item) task.defer(watchRainbow, item) end)
	end
end
task.spawn(function()
	while true do
		task.wait(0.1)
		local hue = (os.clock() * 0.25) % 1
		for model, parts in pairs(rainbow) do
			if not model.Parent then
				rainbow[model] = nil
			else
				for _, p in ipairs(parts) do p.Color = Color3.fromHSV((hue + (p.Position.Y * 0.05)) % 1, 0.55, 1) end
			end
		end
	end
end)

setWorld("Base")
