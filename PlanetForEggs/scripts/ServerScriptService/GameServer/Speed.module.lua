--!nocheck
-- v28 SPEED (Steal an Egg's treadmills and trails):
--  * every base has a treadmill next to its spawn (build_world.py builds it: Belt, Frame, Accent, Screen ...).
--    Standing on your own belt trains Speed Power (SP) every Config.TreadmillTick - the client runs you in place
--    on it (Treadmill.client) - and your walk speed grows with SP (Config.WalkSpeedFor);
--  * the Upgrades menu swaps the treadmill for a better one (Config.Treadmills: Gain = SP per second);
--  * the trail shop: a streak behind you that multiplies the SP you gain (Config.Trails), bought with coins.
local Players = game:GetService("Players")

local Speed = {}
local ctx, Config

local function treadmillOf(profile) return profile.Base and profile.Base:FindFirstChild("Treadmill") end
local function beltOf(profile)
	local treadmill = treadmillOf(profile)
	return treadmill and treadmill:FindFirstChild("Belt")
end

-- is this player standing (running) on their own treadmill's belt?
function Speed.OnBelt(profile)
	if profile.Planet ~= "Base" or profile.Busy or profile.Stolen or profile.Expedition then return false end
	local root = ctx.root(profile.Player)
	local belt = beltOf(profile)
	if not root or not belt then return false end
	local p = belt.CFrame:PointToObjectSpace(root.Position)
	if math.abs(p.X) <= belt.Size.X / 2 + 1 and math.abs(p.Z) <= belt.Size.Z / 2 + 1.5 and p.Y > -1 and p.Y < 8 then return true end
	-- (v30) the client anchors the runner on the belt, and an anchored root stops replicating: the server may still
	-- see the spot where they stepped on. Trust the client's "I'm running" while that spot is next to the belt.
	return profile.TreadmillClaim == true and (root.Position - belt.Position).Magnitude < 14
end

function Speed.Gain(profile)
	return Config.TreadmillGain(profile.Data.TreadmillLevel, profile.Data.Trail ~= "" and profile.Data.Trail or nil, ctx.hasPass(profile, "VIP"))
end

-- ---------------------------------------------------------------- the treadmill's look
local FX = {
	Bubbles = {Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 6, Size = 0.5, Speed = 2, Emit = 0.6},
	Embers = {Texture = "rbxasset://textures/particles/fire_sparks_main.dds", Rate = 14, Size = 0.35, Speed = 4, Emit = 1},
	Snow = {Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 10, Size = 0.3, Speed = 1.5, Emit = 0.8},
	Sparkle = {Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 10, Size = 0.4, Speed = 2, Emit = 1},
	Stars = {Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 16, Size = 0.45, Speed = 1, Emit = 1},
	Void = {Texture = "rbxasset://textures/particles/smoke_main.dds", Rate = 8, Size = 2.2, Speed = 1.2, Emit = 0.2},
}
local function setScreen(treadmill, level)
	local screen = treadmill:FindFirstChild("Screen")
	local info = Config.Treadmills[level] or Config.Treadmills[1]
	if not screen then return end
	local gui = screen:FindFirstChild("Display")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "Display"; gui.Face = Enum.NormalId.Back; gui.LightInfluence = 0; gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60; gui.Parent = screen
		local bg = Instance.new("Frame")
		bg.Name = "Bg"; bg.Size = UDim2.fromScale(1, 1); bg.BorderSizePixel = 0; bg.Parent = gui
		local grad = Instance.new("UIGradient"); grad.Rotation = 90; grad.Parent = bg
		for i, key in ipairs({"Title", "Gain"}) do
			local t = Instance.new("TextLabel")
			t.Name = key; t.BackgroundTransparency = 1; t.TextScaled = true
			t.FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
			t.TextColor3 = Color3.new(1, 1, 1); t.Size = UDim2.fromScale(0.92, i == 1 and 0.4 or 0.36)
			t.Position = UDim2.fromScale(0.04, i == 1 and 0.08 or 0.55); t.Parent = bg
			local stroke = Instance.new("UIStroke"); stroke.Thickness = 3; stroke.Color = Color3.fromRGB(14, 12, 28); stroke.Parent = t
		end
	end
	local bg = gui:FindFirstChild("Bg")
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	bg.UIGradient.Color = ColorSequence.new(info.Accent:Lerp(Color3.new(1, 1, 1), 0.15), info.Color:Lerp(Color3.new(0, 0, 0), 0.55))
	bg.Title.Text = string.upper(info.Name)
	bg.Gain.Text = "+" .. Config.FormatRate(info.Gain) .. " SPEED/s"
	bg.Gain.TextColor3 = Color3.fromRGB(150, 255, 110)
end
function Speed.RenderTreadmill(base, level)
	local treadmill = base and base:FindFirstChild("Treadmill")
	if not treadmill then return end
	level = math.clamp(level or 1, 1, #Config.Treadmills)
	local info = Config.Treadmills[level]
	treadmill:SetAttribute("Level", level)
	treadmill:SetAttribute("Gain", info.Gain)
	local material = Enum.Material[info.Material] or Enum.Material.SmoothPlastic
	for _, part in ipairs(treadmill:GetDescendants()) do
		if part:IsA("BasePart") then
			if part.Name == "Frame" or part.Name == "Post" or part.Name == "Rail" then
				part.Color = info.Color; part.Material = material
			elseif part.Name == "Accent" then
				part.Color = info.Accent; part.Material = Enum.Material.Neon
			elseif part.Name == "Bar" then
				part.Color = info.Accent:Lerp(Color3.new(1, 1, 1), 0.25)
			end
		end
	end
	setScreen(treadmill, level)
	-- the higher tiers sparkle, burn, snow ...
	local belt = treadmill:FindFirstChild("Belt")
	local old = belt and belt:FindFirstChild("TierFx")
	if old then old:Destroy() end
	local spec = info.Fx and FX[info.Fx]
	if belt and spec then
		local e = Instance.new("ParticleEmitter")
		e.Name = "TierFx"; e.Texture = spec.Texture; e.Rate = spec.Rate; e.LightEmission = spec.Emit; e.LightInfluence = 0
		e.Color = ColorSequence.new(info.Accent, info.Accent:Lerp(Color3.new(1, 1, 1), 0.5))
		e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, spec.Size), NumberSequenceKeypoint.new(1, 0)})
		e.Speed = NumberRange.new(spec.Speed * 0.5, spec.Speed); e.Lifetime = NumberRange.new(0.8, 1.6)
		e.SpreadAngle = Vector2.new(25, 25); e.EmissionDirection = Enum.NormalId.Top
		e.Transparency = NumberSequence.new(0.2, 1)
		e.Parent = belt
	end
	local sign = treadmill:FindFirstChild("SignAnchor") or treadmill.PrimaryPart
	local board = sign and sign:FindFirstChild("TreadmillSign")
	if sign and not board then
		board = ctx.label(sign, "", "", Color3.new(1, 1, 1), 2.5)
		if board then board.Name = "TreadmillSign"; board.MaxDistance = 90 end
	end
	if board then
		board.Title.Text = info.Name
		board.Title.TextColor3 = info.Accent:Lerp(Color3.new(1, 1, 1), 0.35)
		board.Subtitle.Text = "Run here: +" .. Config.FormatRate(info.Gain) .. " speed/s"
	end
end

-- ---------------------------------------------------------------- upgrades & the trail shop
function Speed.Upgrade(profile)
	if profile.Planet ~= "Base" or not ctx.near(profile, profile.Base:FindFirstChild("Spawn"), Config.BaseInteractionDistance) then
		ctx.notice(profile, "Return to your base to upgrade."); return
	end
	local data = profile.Data
	local nextOne = Config.Treadmills[data.TreadmillLevel + 1]
	if not nextOne then ctx.notice(profile, "Your treadmill is the best there is!"); return end
	if data.Coins < nextOne.Cost then ctx.notice(profile, "You need " .. Config.Format(nextOne.Cost) .. " coins.", "Red"); return end
	data.Coins -= nextOne.Cost
	data.TreadmillLevel += 1
	Speed.RenderTreadmill(profile.Base, data.TreadmillLevel)
	ctx.notice(profile, nextOne.Name .. " installed! +" .. Config.FormatRate(nextOne.Gain) .. " speed/s", "Gold")
	ctx.effect(profile.Player, "TreadmillUpgrade", {Level = data.TreadmillLevel})
	ctx.markDirty(profile)
end

local function clearTrail(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	for _, name in ipairs({"PFETrail", "PFETrailA0", "PFETrailA1", "PFETrailFx"}) do
		local old = root:FindFirstChild(name)
		if old then old:Destroy() end
	end
end
-- the streak behind the character (everyone sees it)
function Speed.ApplyTrail(profile)
	local character = profile.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	clearTrail(character)
	local trail = Config.Trails[profile.Data.Trail or ""]
	if not root or not trail then return end
	local a0 = Instance.new("Attachment"); a0.Name = "PFETrailA0"; a0.Position = Vector3.new(0, 1.1, 0.55); a0.Parent = root
	local a1 = Instance.new("Attachment"); a1.Name = "PFETrailA1"; a1.Position = Vector3.new(0, -1.5, 0.55); a1.Parent = root
	local t = Instance.new("Trail")
	t.Name = "PFETrail"; t.Attachment0 = a0; t.Attachment1 = a1
	t.Color = Config.TrailColors(trail); t.LightEmission = trail.Glow; t.LightInfluence = 0.2
	t.Lifetime = 0.55 + 0.05 * trail.Order; t.MinLength = 0.05; t.FaceCamera = true
	t.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1)})
	t.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.25)})
	t.Parent = root
	local spec = trail.Fx and FX[trail.Fx]
	if spec then
		local e = Instance.new("ParticleEmitter")
		e.Name = "PFETrailFx"; e.Texture = spec.Texture; e.Rate = spec.Rate * 1.2; e.LightEmission = spec.Emit; e.LightInfluence = 0
		e.Color = Config.TrailColors(trail); e.Lifetime = NumberRange.new(0.5, 1.1)
		e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, spec.Size * 1.2), NumberSequenceKeypoint.new(1, 0)})
		e.Speed = NumberRange.new(0.5, spec.Speed); e.SpreadAngle = Vector2.new(180, 180); e.Drag = 2
		e.Transparency = NumberSequence.new(0.1, 1)
		e.Parent = a1
	end
end
function Speed.BuyTrail(profile, id)
	local trail = type(id) == "string" and Config.Trails[id]
	if not trail or profile.Busy then return end
	local data = profile.Data
	if data.Trails[id] then Speed.EquipTrail(profile, id); return end
	if data.Coins < trail.Cost then ctx.notice(profile, "You need " .. Config.Format(trail.Cost) .. " coins.", "Red"); return end
	data.Coins -= trail.Cost
	data.Trails[id] = true
	data.Trail = id
	Speed.ApplyTrail(profile)
	ctx.notice(profile, trail.Name .. " trail unlocked! x" .. trail.Mult .. " speed training", "Gold")
	ctx.effect(profile.Player, "TrailBought", {Id = id})
	ctx.markDirty(profile)
end
function Speed.EquipTrail(profile, id)
	local data = profile.Data
	if id == "" or id == nil then data.Trail = ""
	elseif type(id) == "string" and data.Trails[id] then data.Trail = id
	else return end
	Speed.ApplyTrail(profile)
	ctx.markDirty(profile)
end

function Speed.OnCharacter(profile)
	task.defer(function()
		if ctx.profiles[profile.Player] == profile then Speed.ApplyTrail(profile) end
	end)
end

function Speed.Init(context)
	ctx = context
	Config = ctx.Config
	ctx.Speed = Speed
	-- every base's treadmill starts as the Rusty Treadmill (an owner's join paints it in their level)
	for _, base in ipairs(ctx.bases:GetChildren()) do Speed.RenderTreadmill(base, 1) end
	task.spawn(function()
		local tick = Config.TreadmillTick
		local clock = 0
		while true do
			task.wait(tick)
			clock += tick
			for _, profile in pairs(ctx.profiles) do
				local ok, err = pcall(function()
					local on = Speed.OnBelt(profile)
					if on ~= (profile.OnTreadmill == true) then
						profile.OnTreadmill = on
						profile.Player:SetAttribute("PFEOnTreadmill", on)
					end
					if on then
						local data = profile.Data
						data.SpeedPower = math.min(1e15, (data.SpeedPower or 0) + Speed.Gain(profile) * tick)
						profile.Player:SetAttribute("PFESpeedPower", math.floor(data.SpeedPower))
					end
					-- the walk speed follows the trained power (checked once a second)
					if clock >= 1 and math.abs(ctx.walkSpeed(profile) - (profile.SpeedApplied or 0)) > 0.05 then ctx.setMovement(profile) end
					-- (v33) the Tab list shows everyone's coins
					if clock >= 1 then
						local coins = math.floor(profile.Data.Coins or 0)
						if profile.Player:GetAttribute("PFECoins") ~= coins then profile.Player:SetAttribute("PFECoins", coins) end
					end
				end)
				if not ok then warn("[PFE] speed tick", err) end
			end
			if clock >= 1 then clock = 0 end
		end
	end)
end

return Speed
