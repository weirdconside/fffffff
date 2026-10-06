--!nocheck
-- First-steps guide: a bouncing arrow over the next objective, with a very short
-- objective line (only while the tutorial is running or when something needs doing).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Guide = {}

function Guide.Init(store)
	local UI, Config, player = store.UI, store.Config, store.player
	local C = UI.C
	local hint = UI.text(store.gui, "", UDim2.fromOffset(600, 38), UDim2.new(0.5, 0, 1, -110), 30, C.White)
	hint.Name = "TutorialHint"; hint.AnchorPoint = Vector2.new(0.5, 1); hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.TextWrapped = false; hint.Visible = false
	local hintScale = UI.new("UIScale", {}, hint)

	-- a bouncing arrow over the next objective (no world beam: it read as a neon strip)
	local markerFolder = Instance.new("Folder")
	markerFolder.Name = "PFE_GuideMarker"
	local anchor, marker
	local function showMarker(target)
		if not target then
			if marker then marker.Enabled = false end
			return
		end
		if not anchor then
			anchor = Instance.new("Part")
			anchor.Name = "GuideTarget"; anchor.Anchored = true; anchor.CanCollide = false; anchor.CanQuery = false; anchor.CanTouch = false
			anchor.Transparency = 1; anchor.Size = Vector3.new(0.2, 0.2, 0.2); anchor.Parent = markerFolder
			markerFolder.Parent = workspace
			marker = Instance.new("BillboardGui")
			marker.Size = UDim2.fromOffset(64, 64); marker.AlwaysOnTop = true; marker.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
			marker.LightInfluence = 0; marker.Adornee = anchor; marker.Parent = anchor
			UI.icon(marker, "Next", UDim2.fromScale(1, 1), nil, {Rotation = 90})
		end
		anchor.Position = target
		marker.Enabled = true
	end

	local function objective(state)
		local base = workspace.PlanetForEggs.Bases:FindFirstChild("Base" .. tostring(state.BaseIndex or 1))
		local step = state.TutorialStep or 1
		local onEarth = state.Planet == "Base"
		if state.Busy or player:GetAttribute("PFEDungeon") then return nil end -- the ship line in the HUD says what to do there
		if state.Stolen then
			local area = base and base:FindFirstChild("PlantArea")
			return "Run to your base!", area and area.Position
		end
		if state.CarryingEgg then
			local planet = workspace.PlanetForEggs.Planets:FindFirstChild(state.Planet)
			local landing = planet and planet:FindFirstChild("Landing")
			return "Bring the egg to your rocket", landing and landing.Position
		end
		if onEarth then
			local eggs = #(state.Eggs or {})
			if eggs > 0 and #(state.GrowingEggs or {}) == 0 and step <= 2 then
				local area = base and base:FindFirstChild("PlantArea")
				return "Plant your egg", area and area.Position
			end
			for _, egg in ipairs(state.GrowingEggs or {}) do
				if egg.ReadyAt and egg.ReadyAt <= workspace:GetServerTimeNow() and typeof(egg.Position) == "Vector3" then
					return step <= 7 and "Hatch your egg!" or nil, egg.Position
				end
			end
			if step <= 3 or (eggs == 0 and #(state.GrowingEggs or {}) == 0 and #(state.Pets or {}) < 3) then
				local launch = base and base:FindFirstChild("Launch")
				return "Fly to the Moon", launch and launch.Position
			end
		else
			local exp = state.Expedition
			local loaded = exp and exp.Eggs and #exp.Eggs or 0
			if loaded >= (state.Capacity or 1) or ((state.Oxygen or 0) < (state.MaxOxygen or 60) * 0.3 and loaded > 0) then
				local planet = workspace.PlanetForEggs.Planets:FindFirstChild(state.Planet)
				local landing = planet and planet:FindFirstChild("Landing")
				return "Fly home", landing and landing.Position
			end
			if step <= 4 then return "Find eggs behind trees and rocks", nil end
		end
		return nil
	end

	local current
	store.on(function(state) current = state end)
	store.onLight(function(state) current = state end)
	local clock, bob = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		bob += dt
		if marker and marker.Enabled then marker.StudsOffsetWorldSpace = Vector3.new(0, 7 + math.sin(bob * 4) * 0.6, 0) end
		clock += dt
		if clock < 0.25 then return end
		clock = 0
		local state = current or store.state
		local text, target
		if not store.flying() and not store.menuOpen() then text, target = objective(state) end
		hint.Visible = text ~= nil
		if text and hint.Text ~= text then hint.Text = text end
		local camera = workspace.CurrentCamera
		if camera then
			hintScale.Scale = math.clamp(UI.scaleFor(camera.ViewportSize), UI.minScale(), 1.2)
			hint.Position = UDim2.new(0.5, 0, 1, UI.isTouch() and -128 or -140) -- above the bottom timers
		end
		showMarker(text and target or nil)
	end)
end

return Guide
