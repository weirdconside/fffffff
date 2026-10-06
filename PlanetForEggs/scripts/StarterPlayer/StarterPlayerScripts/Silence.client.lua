--!nocheck
-- The game's sound policy. Our own sounds play: every id in Config.Sounds / Config.Sfx (all public),
-- Roblox's built-in rbxasset:// sounds (footsteps, jumps...), the title music and the radar beeps.
-- Everything else that came along with the source models (99 Nights, Dead Rails, Steal an Egg: their
-- ids are private to those games or noises we don't want) is kept at volume 0.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("PFE"):WaitForChild("Config"))
local KEEP = {TitleMusic = true, ScannerBeep = true, ScannerBeep2 = true}
local allowed = {}
for _, id in pairs(Config.Sounds or {}) do allowed[id] = true end
for _, id in pairs(Config.Sfx or {}) do allowed[id] = true end

local function keep(sound)
	local id = sound.SoundId or ""
	if sound:GetAttribute("PFEMute") == true then return false end
	return KEEP[sound.Name] == true or sound:GetAttribute("PFEKeepSound") == true or allowed[id] == true
		or string.sub(id, 1, 11) == "rbxasset://"
end
local hushed = setmetatable({}, {__mode = "k"}) -- sound -> the volume it had
local watched = setmetatable({}, {__mode = "k"})
local function check(sound)
	if keep(sound) then
		local volume = hushed[sound]
		if volume then hushed[sound] = nil; sound.Volume = volume end
	elseif not hushed[sound] then
		hushed[sound] = sound.Volume
		sound.Volume = 0
	end
end
local function watchSound(sound)
	if watched[sound] then return end
	watched[sound] = true
	check(sound)
	sound:GetPropertyChangedSignal("SoundId"):Connect(function() check(sound) end)
	sound:GetAttributeChangedSignal("PFEMute"):Connect(function() check(sound) end)
	sound:GetPropertyChangedSignal("Volume"):Connect(function()
		if hushed[sound] and sound.Volume ~= 0 then hushed[sound] = sound.Volume; sound.Volume = 0 end
	end)
end
local function watch(root)
	if not root then return end
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("Sound") then watchSound(item) end
	end
	root.DescendantAdded:Connect(function(item)
		if item:IsA("Sound") then watchSound(item) end
	end)
end
watch(workspace)
watch(game:GetService("SoundService"))
watch(player:WaitForChild("PlayerGui"))
watch(player:FindFirstChild("PlayerScripts"))
