--!nocheck
-- v28 Halloween on the island (presentation only): the ghosts (build_world.py tags them HalloweenBob) float
-- up and down and turn slowly, and a few flocks of bats flap in circles over the lawn. Only while you are on
-- the island (the planets hide the island anyway).
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local world = workspace:WaitForChild("PlanetForEggs")
local island = world:WaitForChild("OriginalIsland")
local GROUND_Y = 68

local ghosts = {}
local function collect()
	local folder = island:FindFirstChild("Halloween")
	if not folder then return end
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("HalloweenBob") then
			table.insert(ghosts, {Model = m, Home = m:GetPivot(), Phase = math.random() * 6.28, Speed = 0.6 + math.random() * 0.5})
		end
	end
end
task.defer(collect)

-- bats: little black shapes with flapping wings, flying in loops
local bats = {}
local folder = Instance.new("Folder")
folder.Name = "PFE_Bats"
folder.Parent = workspace
local function part(name, size, color, parent)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.Color = color; p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
	p.Parent = parent
	return p
end
local DARK = Color3.fromRGB(30, 18, 40)
for flock = 1, 4 do
	local centre = Vector3.new(math.cos(flock * 1.6) * 170, GROUND_Y + 28 + flock * 6, math.sin(flock * 1.6) * 170)
	for i = 1, 6 do
		local m = Instance.new("Model")
		m.Name = "Bat"
		local body = part("Body", Vector3.new(0.8, 0.7, 1.1), DARK, m)
		local wl = part("WingL", Vector3.new(1.6, 0.12, 0.9), DARK, m)
		local wr = part("WingR", Vector3.new(1.6, 0.12, 0.9), DARK, m)
		for side = -1, 1, 2 do
			local eye = part("Eye", Vector3.new(0.14, 0.14, 0.05), Color3.fromRGB(255, 200, 60), m)
			eye.Material = Enum.Material.Neon
			eye:SetAttribute("Side", side)
		end
		m.PrimaryPart = body
		m.Parent = folder
		table.insert(bats, {Model = m, Body = body, L = wl, R = wr, Centre = centre, Radius = 20 + math.random() * 25,
			Speed = (0.4 + math.random() * 0.4) * (math.random() < 0.5 and -1 or 1), Phase = i / 6 * math.pi * 2, Height = math.random() * 8})
	end
end

local clock, acc = 0, 0
RunService.RenderStepped:Connect(function(dt)
	clock += dt
	acc += dt
	if acc < 1 / 30 then return end   -- (v36) 30 updates a second is plenty for drifting ghosts and bats
	acc = 0
	local camera = workspace.CurrentCamera
	local near = camera and camera.CFrame.Position.Magnitude < 1200
	local want = (near and player:GetAttribute("PFEPreHalloween") ~= true) and workspace or nil
	if folder.Parent ~= want then folder.Parent = want end
	if not near then return end
	local eye = camera.CFrame.Position
	for _, g in ipairs(ghosts) do
		-- (v36) only the ghosts you could see bob (one bulk move each)
		if g.Model.Parent and (g.Home.Position - eye).Magnitude < 320 then
			local y = math.sin(clock * g.Speed + g.Phase) * 1.4
			local pivot = g.Home * CFrame.new(0, y, 0) * CFrame.Angles(0, math.sin(clock * 0.3 + g.Phase) * 0.6, math.sin(clock * 0.9 + g.Phase) * 0.06)
			if not g.Parts then
				g.Parts, g.Rel, g.CFrames = {}, {}, {}
				local home = g.Model:GetPivot()
				for _, part in ipairs(g.Model:GetDescendants()) do
					if part:IsA("BasePart") then table.insert(g.Parts, part); table.insert(g.Rel, home:ToObjectSpace(part.CFrame)) end
				end
			end
			for i, r in ipairs(g.Rel) do g.CFrames[i] = pivot * r end
			local ok = pcall(function() workspace:BulkMoveTo(g.Parts, g.CFrames, Enum.BulkMoveMode.FireCFrameChanged) end)
			if not ok then g.Model:PivotTo(pivot) end
		end
	end
	for _, b in ipairs(bats) do
		local a = b.Phase + clock * b.Speed
		local pos = b.Centre + Vector3.new(math.cos(a) * b.Radius, b.Height + math.sin(clock * 2 + b.Phase) * 2, math.sin(a) * b.Radius)
		local ahead = b.Centre + Vector3.new(math.cos(a + 0.1 * math.sign(b.Speed)) * b.Radius, b.Height, math.sin(a + 0.1 * math.sign(b.Speed)) * b.Radius)
		local cf = CFrame.lookAt(pos, Vector3.new(ahead.X, pos.Y, ahead.Z))
		local flap = math.sin(clock * 16 + b.Phase) * 0.7
		b.Body.CFrame = cf
		b.L.CFrame = cf * CFrame.new(-0.6, 0, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-0.7, 0, 0)
		b.R.CFrame = cf * CFrame.new(0.6, 0, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(0.7, 0, 0)
		for _, e in ipairs(b.Model:GetChildren()) do
			if e.Name == "Eye" then e.CFrame = cf * CFrame.new(e:GetAttribute("Side") * 0.18, 0.12, -0.56) end
		end
	end
end)
