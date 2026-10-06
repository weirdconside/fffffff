--!nocheck
-- Meteor Run on the client: the countdown splash, the run HUD (time left, eggs won), the meteors
-- themselves (Blender rocks with a fire trail and an egg on top, moved along the path the server
-- sent, so all players see the same flight) and the result card. Reaching an egg asks the server
-- to grab it; standing on a meteor carries you with it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local api = game:GetService("ReplicatedStorage"):WaitForChild("PFE")
local Config = require(api:WaitForChild("Config"))
local ModelUtil = require(api:WaitForChild("ModelUtil"))
local UI = require(api:WaitForChild("UIKit"))
local C = UI.C
local sky = api:WaitForChild("Sky")
local eggs = api:WaitForChild("UIAssets"):WaitForChild("Eggs")
local player = Players.LocalPlayer
local MG = Config.Minigame

local gui = UI.new("ScreenGui", {Name = "PFE_MeteorRun", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30}, player:WaitForChild("PlayerGui"))
local folder = Instance.new("Folder")
folder.Name = "PFE_Meteors"
folder.Parent = workspace

local run = nil          -- {EndsAt, StartsAt, Count, Max, Hud}
local meteors = {}       -- id -> {Data, Model, Parts, Egg, Asked}

local function sound(id, volume, speed)
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = volume; s.PlaybackSpeed = speed or 1; s.Parent = SoundService
	s:Play(); Debris:AddItem(s, 3)
end

-- ---------------------------------------------------------------- HUD
local function banner(text, color, hold)
	local label = UI.text(gui, text, UDim2.fromOffset(700, 90), UDim2.new(0.5, -350, 0.28, 0), 64, color or C.Gold)
	label.TextXAlignment = Enum.TextXAlignment.Center; label.TextWrapped = false; label.ZIndex = 30
	local s = UI.new("UIScale", {Scale = 0.3}, label)
	UI.tween(s, {Scale = 1}, 0.3, Enum.EasingStyle.Back)
	task.delay(hold or 0.8, function()
		if not label.Parent then return end
		UI.tween(s, {Scale = 0.2}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.21, function() label:Destroy() end)
	end)
end

local function makeHud()
	local card = UI.card(gui, Color3.fromRGB(255, 120, 40), UDim2.fromOffset(300, 74), UDim2.new(0.5, -150, 0, 70), "MeteorRunHud")
	local scale = UI.new("UIScale", {Scale = math.clamp(UI.scaleFor(workspace.CurrentCamera.ViewportSize), UI.minScale(), 1)}, card)
	UI.icon(card, "rbxassetid://74741161145180", UDim2.fromOffset(54, 54), UDim2.fromOffset(10, 10), {ZIndex = 6})
	local title = UI.text(card, "METEOR RUN", UDim2.new(1, -80, 0, 30), UDim2.fromOffset(72, 6), 26)
	title.TextWrapped = false
	local info = UI.text(card, "", UDim2.new(1, -80, 0, 26), UDim2.fromOffset(72, 38), 20, C.White)
	info.TextWrapped = false
	return {Card = card, Info = info, Scale = scale}
end

-- ---------------------------------------------------------------- the invitation (30 s before a run)
-- A small card at the top for everyone: JOIN takes you into the circle (from anywhere - a planet egg
-- in your hands is lost), NO just closes it. It goes away by itself when the run starts.
local invite = nil -- {Card, Scale, StartsAt, Info, Sub, Join}
local function inviteScale()
	local camera = workspace.CurrentCamera
	return camera and math.clamp(UI.scaleFor(camera.ViewportSize), UI.minScale(), 1) or 1
end
local function closeInvite()
	if not invite then return end
	local card, s = invite.Card, invite.Scale
	invite = nil
	UI.tween(s, {Scale = 0.2}, 0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(0.19, function() card:Destroy() end)
end
local function inviteHint()
	if player:GetAttribute("PFEQueued") == true then return "You're in the circle - stay inside!", C.Green end
	if player:GetAttribute("PFECarrying") == true then return "The egg in your hands will be lost!", Color3.fromRGB(255, 120, 120) end
	return "Jump on flying meteors and grab free eggs!", C.Soft
end
local function showInvite(startsAt)
	if invite or run or type(startsAt) ~= "number" then return end
	local card = UI.card(gui, Color3.fromRGB(255, 120, 40), UDim2.fromOffset(470, 160), UDim2.new(0.5, 0, 0, 96), "MeteorRunInvite")
	card.AnchorPoint = Vector2.new(0.5, 0); card.ZIndex = 20
	local s = UI.new("UIScale", {Scale = 0.3}, card)
	UI.tween(s, {Scale = inviteScale()}, 0.3, Enum.EasingStyle.Back)
	UI.icon(card, "rbxassetid://74741161145180", UDim2.fromOffset(64, 64), UDim2.fromOffset(12, 10), {ZIndex = 6})
	local title = UI.text(card, "METEOR RUN!", UDim2.new(1, -100, 0, 34), UDim2.fromOffset(86, 8), 30)
	title.TextWrapped = false
	local info = UI.text(card, "", UDim2.new(1, -100, 0, 24), UDim2.fromOffset(86, 42), 19, C.White)
	info.TextWrapped = false
	local hint, color = inviteHint()
	local sub = UI.text(card, hint, UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 78), 17, color)
	sub.TextXAlignment = Enum.TextXAlignment.Center; sub.TextWrapped = false
	local join = UI.button(card, "JOIN", C.Green, UDim2.fromOffset(200, 46), UDim2.new(0.5, -210, 1, -56), function()
		if not invite then return end
		api:WaitForChild("MinigameJoin"):FireServer()
		UI.disable(invite.Join, true)
		task.delay(1.2, function() if invite and invite.Join.Parent then UI.disable(invite.Join, false) end end)
	end, {TextSize = 26, Name = "JoinButton"})
	UI.button(card, "NO", C.Muted, UDim2.fromOffset(200, 46), UDim2.new(0.5, 10, 1, -56), closeInvite, {TextSize = 26, Name = "NoButton"})
	-- everything on the card above the card itself (the card sits at 20: its text and buttons were drawn under it)
	for _, d in ipairs(card:GetDescendants()) do
		if d:IsA("GuiObject") then d.ZIndex += 20 end
	end
	invite = {Card = card, Scale = s, StartsAt = startsAt, Info = info, Sub = sub, Join = join}
	sound(Config.Sfx.Reward, 0.45, 1.25)
end

-- ---------------------------------------------------------------- meteors
local function addMeteor(data)
	local template = sky:FindFirstChild(data.Model)
	if not template or meteors[data.Id] then return end
	local model = template:Clone()
	local parts = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true; p.CanTouch = false; table.insert(parts, p) end
	end
	-- fire trail from the back of the rock
	local tail = model:FindFirstChild("Tail") or model:FindFirstChildWhichIsA("BasePart")
	local attachment = Instance.new("Attachment"); attachment.Parent = tail
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"; fire.Rate = 60; fire.Lifetime = NumberRange.new(0.5, 0.9)
	fire.Speed = NumberRange.new(2, 5); fire.LightEmission = 1; fire.SpreadAngle = Vector2.new(20, 20)
	fire.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 0)})
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 70, 20)); fire.Parent = attachment
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"; smoke.Rate = 18; smoke.Lifetime = NumberRange.new(1, 1.6)
	smoke.Speed = NumberRange.new(1, 3); smoke.Size = NumberSequence.new(4, 10); smoke.Transparency = NumberSequence.new(0.5, 1)
	smoke.Color = ColorSequence.new(Color3.fromRGB(80, 70, 70)); smoke.Parent = attachment
	-- the prize egg on top, with a soft glow
	local eggTemplate = eggs:FindFirstChild(data.EggId)
	local egg
	if eggTemplate then
		egg = eggTemplate:Clone()
		ModelUtil.PrepareVisual(egg, true)
		ModelUtil.FitTo(egg, 3.2)
		ModelUtil.ApplyMutation(egg, data.Mutation)
		for _, p in ipairs(egg:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end end
		egg.Parent = model
		local info = Config.Eggs[data.EggId]
		local light = Instance.new("PointLight"); light.Range = 14; light.Brightness = 2
		light.Color = info and Config.Rarities[info.Rarity].Color or C.Gold
		light.Parent = egg:FindFirstChildWhichIsA("BasePart", true)
	end
	model.Name = "Meteor_" .. data.Id
	model.Parent = folder
	-- the rock's size: the egg sits on its top, and standing on it counts as reaching the egg
	model:PivotTo(CFrame.new(data.Start))
	local bounds, size = ModelUtil.VisibleBounds(model)
	local pivot = model:GetPivot()
	meteors[data.Id] = {Data = data, Model = model, Parts = parts, Egg = egg, EggOffset = nil,
		Top = bounds.Position.Y + size.Y / 2 - pivot.Position.Y, Radius = math.max(size.X, size.Z) / 2,
		Center = pivot:PointToObjectSpace(bounds.Position)}
	if egg then
		local top = Vector3.new(bounds.Position.X, bounds.Position.Y + size.Y / 2 - 0.3, bounds.Position.Z)
		ModelUtil.PlaceOnGround(egg, top, 0)
		meteors[data.Id].EggOffset = pivot:ToObjectSpace(egg:GetPivot())
	end
end

local function removeEgg(entry, taken)
	if entry.Egg then
		local position = entry.Egg:GetPivot().Position
		entry.Egg:Destroy(); entry.Egg = nil
		if taken then
			local holder = Instance.new("Part"); holder.Anchored = true; holder.CanCollide = false; holder.Transparency = 1
			holder.Position = position; holder.Parent = folder
			local sparks = Instance.new("ParticleEmitter")
			sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"; sparks.LightEmission = 1
			sparks.Speed = NumberRange.new(10, 20); sparks.SpreadAngle = Vector2.new(180, 180); sparks.Lifetime = NumberRange.new(0.4, 0.8)
			sparks.Size = NumberSequence.new(1, 0); sparks.Color = ColorSequence.new(C.Gold); sparks.Enabled = false; sparks.Parent = holder
			sparks:Emit(30)
			Debris:AddItem(holder, 2)
		end
	end
end

local function clearMeteors()
	folder:ClearAllChildren()
	meteors = {}
end

-- ---------------------------------------------------------------- server messages
api:WaitForChild("Minigame").OnClientEvent:Connect(function(kind, payload)
	if type(payload) ~= "table" then return end
	if kind == "Invite" then
		showInvite(payload.StartsAt)
		return
	elseif kind == "Joined" then
		closeInvite()
		banner("YOU'RE IN!", C.Gold, 1.1)
		sound(Config.Sfx.Collect, 0.7, 1)
		return
	elseif kind == "JoinFailed" then
		if invite then invite.Sub.Text = tostring(payload.Text or ""); invite.Sub.TextColor3 = Color3.fromRGB(255, 120, 120) end
		return
	end
	if kind == "Start" then
		closeInvite()
		clearMeteors()
		if run and run.Hud then run.Hud.Card:Destroy() end
		run = {EndsAt = payload.EndsAt, StartsAt = payload.StartsAt, Count = 0, Max = payload.MaxEggs or MG.MaxEggs, Hud = makeHud()}
		banner("METEOR RUN!", Color3.fromRGB(255, 176, 60), 1.4)
		sound(Config.Sfx.Reward, 0.7, 1)
		task.spawn(function()
			for _, n in ipairs({"3", "2", "1"}) do
				task.wait(0.9)
				if not run then return end
				banner(n, C.White, 0.5); sound(Config.Sfx.Tick, 0.6, 1.1)
			end
			task.wait(0.8)
			if run then banner("FLY UP & GRAB THE EGGS!", C.Gold, 1.4) end
		end)
	elseif kind == "Meteor" then
		addMeteor(payload)
	elseif kind == "Taken" then
		local entry = meteors[payload.Id]
		if entry then removeEgg(entry, true) end
		if payload.By == player.UserId and run then
			run.Count = payload.Count or run.Count + 1
			sound(Config.Sfx.Collect, 0.8, 1)
		end
	elseif kind == "End" then
		clearMeteors()
		if run and run.Hud then run.Hud.Card:Destroy() end
		run = nil
		local won = payload.Eggs or {}
		local card = UI.card(gui, #won > 0 and C.Green or C.Purple, UDim2.fromOffset(460, 150), UDim2.new(0.5, -230, 0.3, 0), "MeteorRunResult")
		local s = UI.new("UIScale", {Scale = 0.3}, card)
		UI.tween(s, {Scale = math.clamp(UI.scaleFor(workspace.CurrentCamera.ViewportSize), UI.minScale(), 1)}, 0.3, Enum.EasingStyle.Back)
		local head = UI.text(card, "METEOR RUN OVER!", UDim2.new(1, -20, 0, 44), UDim2.fromOffset(10, 8), 36, C.Gold)
		head.TextXAlignment = Enum.TextXAlignment.Center; head.TextWrapped = false
		local names = {}
		for _, egg in ipairs(won) do table.insert(names, Config.EggDisplayName(egg)) end
		local body = UI.text(card, #won > 0 and ("You won " .. #won .. (#won == 1 and " egg: " or " eggs: ") .. table.concat(names, ", "))
			or "No eggs this time. Next run in 30 minutes!", UDim2.new(1, -30, 0, 80), UDim2.fromOffset(15, 56), 20, C.White)
		body.TextXAlignment = Enum.TextXAlignment.Center
		sound(#won > 0 and Config.Sfx.Reward or Config.Sfx.Click, 0.7, 1)
		task.delay(5, function()
			if card.Parent then UI.tween(s, {Scale = 0.2}, 0.2); task.delay(0.21, function() card:Destroy() end) end
		end)
	end
end)

-- ---------------------------------------------------------------- per frame
RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for id, entry in pairs(meteors) do
		local data = entry.Data
		local age = now - data.T0
		if age > data.Life + 1 then
			entry.Model:Destroy(); meteors[id] = nil
		else
			local position = data.Start + data.Velocity * age
			local cf = CFrame.lookAt(position, position + Vector3.new(data.Velocity.X, 0, data.Velocity.Z)) * CFrame.Angles(0, 0, math.sin(age * 0.8) * data.Spin)
			entry.Model:PivotTo(cf)
			for _, p in ipairs(entry.Parts) do if p.Parent then p.AssemblyLinearVelocity = data.Velocity end end
			if entry.Egg and entry.EggOffset then
				entry.Egg:PivotTo(cf * entry.EggOffset * CFrame.Angles(0, age * 1.5, 0))
				-- close enough to the egg, or standing on its rock: ask the server for it
				if run and root and run.Count < run.Max and not entry.Asked then
					local eggPosition = ModelUtil.VisibleBounds(entry.Egg).Position
					local center = cf:PointToWorldSpace(entry.Center or Vector3.zero)
					local flat = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude
					local onRock = flat <= (entry.Radius or 4) + 2 and root.Position.Y >= position.Y + (entry.Top or 2) - 1
						and root.Position.Y <= position.Y + (entry.Top or 2) + 8
					if (root.Position - eggPosition).Magnitude <= MG.GrabRange or onRock then
						entry.Asked = true
						api:WaitForChild("MinigameGrab"):FireServer(id)
						task.delay(0.8, function() entry.Asked = false end)
					end
				end
			end
		end
	end
	if invite then
		local left = invite.StartsAt - now
		if left <= 0 then
			closeInvite()
		else
			local text = "Starts in " .. math.ceil(left) .. "s"
			if invite.Info.Text ~= text then invite.Info.Text = text end
			if not string.find(invite.Sub.Text, "flying") and not string.find(invite.Sub.Text, "respawn") then
				local hint, color = inviteHint()
				if invite.Sub.Text ~= hint then invite.Sub.Text = hint; invite.Sub.TextColor3 = color end
			end
		end
	end
	if run and run.Hud then
		local left = math.max(0, run.EndsAt - now)
		run.Hud.Info.Text = string.format("%d:%02d left  -  eggs %d/%d", math.floor(left) // 60, math.floor(left) % 60, run.Count, run.Max)
	end
end)
