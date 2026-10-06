--!nocheck
-- HUD bootstrap: one ScreenGui, a shared client store and the UI modules
-- (Hud, Timers, Tracker, Menus, Popups, Guide) that render from it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local api = ReplicatedStorage:WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local UI = require(api:WaitForChild("UIKit"))

local oldGui = player:WaitForChild("PlayerGui"):FindFirstChild("PFE_HUD")
if oldGui then oldGui:Destroy() end
local gui = UI.new("ScreenGui", {Name = "PFE_HUD", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 20,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
-- phones: right up to the edges of the screen (only the camera cut-out is kept clear), not Roblox's
-- wider core-UI margins; the HUD keeps itself below Roblox's own buttons (Hud.lua)
pcall(function()
	local touch = game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled
	gui.ScreenInsets = touch and Enum.ScreenInsets.DeviceSafeInsets or Enum.ScreenInsets.CoreUISafeInsets
end)
local overlay = UI.new("ScreenGui", {Name = "PFE_Overlay", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 45,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player.PlayerGui)

-- ---------------------------------------------------------------- store
local store = {
	state = {Coins = 0, Income = 0, Planet = "Base", Eggs = {}, GrowingEggs = {}, Pets = {}, Passes = {},
		DiscoveredEggs = {}, DiscoveredPets = {}, VisitedPlanets = {}, SuitLevel = 1, RocketLevel = 1, CargoLevel = 1,
		Oxygen = 60, MaxOxygen = 60, Capacity = 1, Busy = false, TutorialStep = 1, Stats = {}},
	gui = gui, overlay = overlay, api = api, Config = Config, UI = UI, player = player,
	listeners = {}, lightListeners = {},
}
function store.send(action, argument) api:WaitForChild("Action"):FireServer(action, argument) end
function store.on(callback) table.insert(store.listeners, callback) end
function store.onLight(callback) table.insert(store.lightListeners, callback) end
function store.flying() return player:GetAttribute("PFEFlightActive") == true end
-- admin "view": the watched player's HUD state (nil when watching nobody); the HUD shows it instead
store.spectate = nil
store.spectateListeners = {}
function store.onSpectate(callback) table.insert(store.spectateListeners, callback) end
function store.menuOpen() return player:GetAttribute("PFEMenuOpen") == true or player:GetAttribute("PFEPlanetMapOpen") == true end

local modules = {}
for _, name in ipairs({"Hud", "Timers", "Tracker", "Menus", "Popups", "Guide"}) do
	local ok, module = pcall(require, script:WaitForChild(name))
	if ok then
		modules[name] = module
		store[name] = module
	else
		warn("[PFE] UI module " .. name .. " failed: " .. tostring(module))
	end
end
for name, module in pairs(modules) do
	local ok, err = pcall(module.Init, store)
	if not ok then warn("[PFE] UI module " .. name .. " init failed: " .. tostring(err)) end
end

api:WaitForChild("State").OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	if payload.Light then
		for key, value in pairs(payload) do if key ~= "Light" then store.state[key] = value end end
		if payload.CarryingEgg == nil then store.state.CarryingEgg = nil end
		if payload.Stolen == nil then store.state.Stolen = nil end
		for _, callback in ipairs(store.lightListeners) do
			local ok, err = pcall(callback, store.state)
			if not ok then warn("[PFE] light update: " .. tostring(err)) end
		end
		return
	end
	store.state = payload
	for _, callback in ipairs(store.listeners) do
		local ok, err = pcall(callback, store.state)
		if not ok then warn("[PFE] state update: " .. tostring(err)) end
	end
end)
api:WaitForChild("Effect").OnClientEvent:Connect(function(kind, payload)
	if kind ~= "Spectate" or type(payload) ~= "table" then return end
	if payload.Stop then
		store.spectate = nil
		player:SetAttribute("PFESpectateWorld", nil); player:SetAttribute("PFESpectateUserId", nil)
	else
		store.spectate = payload
		player:SetAttribute("PFESpectateWorld", payload.Planet); player:SetAttribute("PFESpectateUserId", payload.UserId)
	end
	for _, callback in ipairs(store.spectateListeners) do
		local ok, err = pcall(callback, store.spectate or store.state)
		if not ok then warn("[PFE] spectate update: " .. tostring(err)) end
	end
end)
api:WaitForChild("Notice").OnClientEvent:Connect(function(text, color)
	if store.Popups then store.Popups.Toast(text, color) end
end)
api:WaitForChild("OpenMenu").OnClientEvent:Connect(function(kind)
	if kind == "RocketHub" and store.Menus then store.Menus.OpenMap() end
end)

local localToast = player.PlayerGui:FindFirstChild("PFE_LocalToast") or Instance.new("BindableEvent")
localToast.Name = "PFE_LocalToast"
localToast.Parent = player.PlayerGui
localToast.Event:Connect(function(text, color) if store.Popups then store.Popups.Toast(text, color) end end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
store.send("Sync")
