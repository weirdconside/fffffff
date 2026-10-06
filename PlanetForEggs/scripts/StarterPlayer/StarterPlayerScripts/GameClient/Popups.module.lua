--!nocheck
-- Notifications (outlined text, no boxes), egg-found / hatch / expedition reward cards,
-- theft alarm vignette and coin pops.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local EggForge = require(game:GetService("ReplicatedStorage"):WaitForChild("PFE"):WaitForChild("EggForge"))
local Popups = {}

function Popups.Init(store)
	local UI, Config, player, api = store.UI, store.Config, store.player, store.api
	local C = UI.C
	local assets = api:WaitForChild("UIAssets")
	local layer = UI.new("Frame", {Name = "Popups", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40}, store.gui)
	local toastHolder = UI.new("Frame", {Name = "Toasts", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(760, 150), ZIndex = 40}, layer)
	local toastScale = UI.new("UIScale", {}, toastHolder)
	UI.list(toastHolder, 2, false, Enum.HorizontalAlignment.Center)

	local function sound(file, volume, speed)
		local s = UI.new("Sound", {SoundId = "rbxasset://sounds/" .. file, Volume = volume or 0.4, PlaybackSpeed = speed or 1}, SoundService)
		s:Play()
		task.delay(4, function() s:Destroy() end)
	end
	Popups.Sound = sound
	-- one of Config.Sounds (a full id)
	function Popups.Play(id, volume, speed)
		local s = UI.new("Sound", {SoundId = id, Volume = volume or 0.4, PlaybackSpeed = speed or 1}, SoundService)
		s:Play()
		task.delay(6, function() s:Destroy() end)
	end

	local function colorOf(name)
		if typeof(name) == "Color3" then return name end
		if type(name) == "string" then
			if Config.Rarities[name] then return Config.Rarities[name].Color end
			if C[name] then return C[name] end
		end
		return C.White
	end
	-- strip emoji / pictographs: notifications are plain outlined text
	local function clean(text)
		local out = {}
		for _, code in utf8.codes(text) do
			if code < 0x2190 or (code >= 0xE000 and code <= 0xF8FF) then table.insert(out, utf8.char(code)) end
		end
		return (table.concat(out):gsub("^%s+", ""):gsub("%s%s+", " "))
	end
	local order = 0
	function Popups.Toast(text, color)
		if type(text) ~= "string" then return end
		text = clean(text)
		if text == "" then return end
		order += 1
		local tint = colorOf(color)
		local label = UI.text(toastHolder, text, UDim2.fromOffset(760, 34), nil, 27, tint == C.White and C.White or tint:Lerp(C.White, 0.3))
		label.Name = "Toast"; label.LayoutOrder = order; label.TextXAlignment = Enum.TextXAlignment.Center; label.TextWrapped = false
		label.TextScaled = true
		UI.new("UITextSizeConstraint", {MaxTextSize = 27, MinTextSize = 12}, label)
		local scale = UI.new("UIScale", {Scale = 0.4}, label)
		UI.tween(scale, {Scale = 1}, 0.32, Enum.EasingStyle.Back)
		local toasts = {}
		for _, child in ipairs(toastHolder:GetChildren()) do if child:IsA("TextLabel") then table.insert(toasts, child) end end
		table.sort(toasts, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		while #toasts > 3 do table.remove(toasts, 1):Destroy() end
		task.delay(3.6, function()
			if label.Parent then
				UI.tween(label, {TextTransparency = 1}, 0.3)
				local stroke = label:FindFirstChildOfClass("UIStroke")
				if stroke then UI.tween(stroke, {Transparency = 1}, 0.3) end
				task.delay(0.32, function() if label.Parent then label:Destroy() end end)
			end
		end)
	end

	-- ---------------------------------------------------------------- reward card (bottom centre)
	local function rewardCard(color, height)
		local card = UI.new("Frame", {Name = "RewardCard", BackgroundTransparency = 1, Size = UDim2.fromOffset(520, height or 150),
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 200), ZIndex = 45}, layer)
		local scale = UI.new("UIScale", {}, card)
		scale.Scale = math.clamp(UI.scaleFor(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)), UI.minScale(), 1.2)
		UI.tween(card, {Position = UDim2.new(0.5, 0, 1, -130)}, 0.45, Enum.EasingStyle.Back)
		return card
	end
	local function dismiss(card, after)
		task.delay(after, function()
			if card.Parent then
				UI.tween(card, {Position = UDim2.new(0.5, 0, 1, 260)}, 0.3)
				task.delay(0.35, function() if card.Parent then card:Destroy() end end)
			end
		end)
	end
	local function modelShot(card, template, color, size)
		local holder = UI.new("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Position = UDim2.fromOffset(0, 0), ZIndex = 46}, card)
		UI.sunburst(holder, UDim2.fromScale(1.4, 1.4), color, 0.35).ZIndex = 45
		UI.viewport(holder, template, UDim2.fromScale(1, 1), nil).ZIndex = 47
		return holder
	end

	local function eggFound(payload)
		local info = Config.Eggs[payload.EggId]
		if not info then return end
		local rarity = Config.Rarities[info.Rarity]
		local card = rewardCard(rarity.Color, 140)
		modelShot(card, EggForge.Template(payload.EggId), rarity.Color, 140)
		local head = UI.text(card, "EGG FOUND!", UDim2.fromOffset(360, 44), UDim2.fromOffset(150, 12), 40, C.Gold)
		head.ZIndex = 47; head.TextWrapped = false
		local name = UI.text(card, Config.EggDisplayName(payload), UDim2.fromOffset(360, 34), UDim2.fromOffset(150, 56), 28)
		name.ZIndex = 47; name.TextWrapped = false
		local r = UI.text(card, info.Rarity, UDim2.fromOffset(360, 28), UDim2.fromOffset(150, 92), 24, rarity.Color:Lerp(C.White, 0.2))
		r.ZIndex = 47
		Popups.Play(Config.Sounds.Pickup, 0.6, 1)
		if rarity.Order >= 5 or (payload.Mutation and payload.Mutation ~= "Normal") then Popups.Play(Config.Sounds.Legendary, 0.55, 1) end
		dismiss(card, 3)
	end
	local function hatched(payload)
		if payload.OwnerUserId ~= player.UserId then return end
		if payload.Rolled then return end -- (v28: the hatch multiplier screen already showed the pet)
		task.delay(3.4, function()
			local pet = Config.Pets[payload.Species]
			if not pet then return end
			local rarity = Config.Rarities[pet.Rarity]
			local card = rewardCard(rarity.Color, 160)
			modelShot(card, assets.Pets:FindFirstChild(payload.Species), rarity.Color, 160)
			local mutation = Config.Mutations[payload.Mutation or "Normal"]
			local head = UI.text(card, "NEW PET!", UDim2.fromOffset(340, 40), UDim2.fromOffset(170, 10), 36, C.Gold)
			head.ZIndex = 47; head.TextWrapped = false
			local name = UI.text(card, ((mutation and mutation.Name ~= "") and (mutation.Name .. " ") or "") .. pet.Name, UDim2.fromOffset(340, 40), UDim2.fromOffset(170, 50), 34)
			name.ZIndex = 47; name.TextWrapped = false
			if mutation and mutation.Id ~= "Normal" then name.TextColor3 = mutation.Color end
			local r = UI.text(card, pet.Rarity, UDim2.fromOffset(160, 28), UDim2.fromOffset(170, 94), 24, rarity.Color:Lerp(C.White, 0.2))
			r.ZIndex = 47
			local earn = UI.text(card, "+" .. Config.Format(Config.PetIncome(pet, payload.Scale, payload.Mutation)) .. "/s", UDim2.fromOffset(180, 28),
				UDim2.fromOffset(170, 122), 24, Color3.fromRGB(120, 255, 90))
			earn.ZIndex = 47
			sound("action_jump_land.mp3", 0.5, 1.2)
			dismiss(card, rarity.Order >= 5 and 4.5 or 3.2)
		end)
	end
	api:WaitForChild("EggHatched").OnClientEvent:Connect(function(payload) if type(payload) == "table" then hatched(payload) end end)

	-- ---------------------------------------------------------------- expedition result
	local lastResult
	store.on(function(state)
		local result = state.Result
		if type(result) ~= "table" or state.Busy or state.Planet ~= "Base" then return end
		local key = tostring(result.Planet) .. tostring(result.Eggs) .. tostring(result.Coins) .. tostring(result.Reason)
		if key == lastResult then return end
		lastResult = key
		local card = rewardCard(result.Success and C.Green or C.Red, 120)
		local head = UI.text(card, result.Success and "WELCOME HOME!" or "OUT OF AIR!", UDim2.fromOffset(520, 46), UDim2.fromOffset(0, 0), 42,
			result.Success and C.Gold or C.Red)
		head.TextXAlignment = Enum.TextXAlignment.Center; head.ZIndex = 47; head.TextWrapped = false
		local row = UI.new("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(520, 48), Position = UDim2.fromOffset(0, 54), ZIndex = 46}, card)
		UI.list(row, 18, true, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Center
		local function item(iconKey, value, order)
			local f = UI.new("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(110, 48), LayoutOrder = order, ZIndex = 46}, row)
			UI.icon(f, iconKey, UDim2.fromOffset(46, 46), nil, {ZIndex = 47})
			local t = UI.text(f, value, UDim2.fromOffset(64, 48), UDim2.fromOffset(48, 0), 30)
			t.ZIndex = 47; t.TextWrapped = false
		end
		item("Egg", tostring(result.Eggs or 0), 1)
		if (result.Coins or 0) > 0 then item("Coin", "+" .. Config.Format(result.Coins), 4) end
		dismiss(card, 4)
	end)

	-- ---------------------------------------------------------------- alarm vignette
	local alarm = UI.new("Frame", {Name = "Alarm", BackgroundColor3 = C.Red, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1}, store.overlay)
	UI.new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.3, 1),
		NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0.2)})}, alarm)
	local function flashAlarm()
		for i = 1, 3 do
			task.delay((i - 1) * 0.5, function()
				alarm.BackgroundTransparency = 0.35
				UI.tween(alarm, {BackgroundTransparency = 1}, 0.45)
			end)
		end
		sound("volume_slider.ogg", 0.8, 0.6)
	end

	-- ---------------------------------------------------------------- coins pop
	local function coins(amount)
		Popups.Play(Config.Sounds.Coin, 0.5, 1)
		local hudRoot = store.Hud and store.Hud.Root
		local wallet = hudRoot and hudRoot:FindFirstChild("Wallet", true)
		local pop = UI.text(layer, "+" .. Config.Format(amount), UDim2.fromOffset(220, 40),
			UDim2.fromOffset(wallet and wallet.AbsolutePosition.X + 70 or 80, wallet and wallet.AbsolutePosition.Y + 76 or 90), 32, C.Gold)
		pop.ZIndex = 50
		UI.tween(pop, {Position = pop.Position - UDim2.fromOffset(0, 40), TextTransparency = 1}, 1.2)
		task.delay(1.3, function() pop:Destroy() end)
		sound("action_get_up.mp3", 0.35, 2)
	end

	api:WaitForChild("Effect").OnClientEvent:Connect(function(kind, payload)
		payload = type(payload) == "table" and payload or {}
		if (kind == "CodeResult" or kind == "FreeResult" or kind == "DailyClaimed") and store.Menus and store.Menus.OnEffect then store.Menus.OnEffect(kind, payload) end
		if kind == "EggFound" then eggFound(payload)
		elseif kind == "Coins" then coins(payload.Amount or 0)
		elseif kind == "Alarm" then flashAlarm()
		elseif kind == "StealSuccess" then sound("impact_water.mp3", 0.5, 1.2)
		elseif kind == "Caught" then sound("impact_water.mp3", 0.6, 0.9)
		elseif kind == "RocketUpgrade" then Popups.Play(store.Config.Sounds.LevelUp, 0.5, 1)
		elseif kind == "EggLoaded" then sound("action_jump_land.mp3", 0.5, 1.5)
		elseif kind == "Shield" then sound("impact_water.mp3", 0.4, 0.7)
		end
	end)

	local function layout()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local s = math.clamp(UI.scaleFor(camera.ViewportSize), UI.minScale(), 1.2)
		toastScale.Scale = s
		local onPlanet = Config.Planets[store.state.Planet] ~= nil
		toastHolder.Position = UDim2.new(0.5, 0, 0, (onPlanet and 170 or 70) * s)
	end
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
	store.on(layout)
	layout()
end

return Popups
