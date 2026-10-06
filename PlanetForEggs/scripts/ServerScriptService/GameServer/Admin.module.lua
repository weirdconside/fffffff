--!nocheck
-- The owner's admin: an Infinite Yield-style command set that runs on the server (real, for everyone,
-- not a local "visual"), and an admin-abuse board whose events reach every server (MessagingService).
--  * Admins: Config.Admins (user ids; zoy0m). ";admin <player>" makes someone admin in this server.
--  * OWNER title over the head of Config.Owners (zoy0m, MM2GARRY), VIP over VIPs - everyone sees it; the chat tag is
--    added by AdminClient.
--  * Commands: remotes.Admin:InvokeServer("speed all 50") -> {Ok, Text, Client = {...}}. Players are
--    picked like in Infinite Yield: me, all, others, random, nearest, farthest, or the start of a name.
--    Some commands (view, esp, fov) only change the admin's own screen: the result tells the client.
--  * Abuse: remotes.Admin:InvokeServer("!abuse", kind, args) -> published to every server; each server
--    runs it (announcements, giant silhouettes of the admins in the sky, luck / coin boosts, events,
--    Meteor Run, egg and coin rains, game passes for everyone, disco).
local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local DataStoreService = game:GetService("DataStoreService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
-- in Studio the admin keeps to this server: no ban store, no cross-server messages (an unpublished place
-- can't use DataStore / MessagingService, and Studio would ask you to publish first)
local ONLINE = not RunService:IsStudio()

local Admin = {}
local ctx, Config
local rng = Random.new()
local TOPIC = "PFE_AdminAbuse"
local sessionAdmins = {} -- userId -> true (";admin" in this server)
local loopKill = {}      -- player -> true
local jails = {}         -- player -> model
local serverLocked = false
local banStore
local bans = {}          -- userId -> reason (cached)

function Admin.IsAdmin(player)
	return player ~= nil and (Config.Admins[player.UserId] == true or sessionAdmins[player.UserId] == true)
end

-- ---------------------------------------------------------------- helpers
local function profileOf(player) return ctx.profiles[player] end
local function character(player) return player.Character end
local function humanoid(player) return ctx.humanoid(player) end
local function root(player) local c = player.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function num(v, default) v = tonumber(v); if v == nil or v ~= v then return default end return v end

-- Infinite Yield's player picking: me, all, others, random, nearest, farthest, admins, nonadmins,
-- or the start of a user / display name (several with commas)
local function targets(admin, token)
	token = string.lower(token or "me")
	local list = {}
	for piece in string.gmatch(token, "[^,]+") do
		local all = Players:GetPlayers()
		if piece == "me" then table.insert(list, admin)
		elseif piece == "all" or piece == "everyone" then for _, p in ipairs(all) do table.insert(list, p) end
		elseif piece == "others" then for _, p in ipairs(all) do if p ~= admin then table.insert(list, p) end end
		elseif piece == "random" then if #all > 0 then table.insert(list, all[rng:NextInteger(1, #all)]) end
		elseif piece == "admins" then for _, p in ipairs(all) do if Admin.IsAdmin(p) then table.insert(list, p) end end
		elseif piece == "nonadmins" then for _, p in ipairs(all) do if not Admin.IsAdmin(p) then table.insert(list, p) end end
		elseif piece == "nearest" or piece == "farthest" then
			local mine = root(admin)
			local best, bestD
			for _, p in ipairs(all) do
				local r = root(p)
				if p ~= admin and r and mine then
					local d = (r.Position - mine.Position).Magnitude
					if not bestD or (piece == "nearest" and d < bestD) or (piece == "farthest" and d > bestD) then best, bestD = p, d end
				end
			end
			if best then table.insert(list, best) end
		else
			for _, p in ipairs(all) do
				if string.sub(string.lower(p.Name), 1, #piece) == piece or string.sub(string.lower(p.DisplayName), 1, #piece) == piece then
					table.insert(list, p)
				end
			end
		end
	end
	local seen, out = {}, {}
	for _, p in ipairs(list) do if not seen[p] then seen[p] = true; table.insert(out, p) end end
	return out
end
local function names(list)
	local t = {}
	for _, p in ipairs(list) do table.insert(t, p.Name) end
	return #t > 0 and table.concat(t, ", ") or "nobody"
end

local function tellAll(text, color)
	for _, p in ipairs(Players:GetPlayers()) do ctx.remotes.Notice:FireClient(p, text, color or "Gold") end
end
local function effectAll(kind, payload)
	for _, p in ipairs(Players:GetPlayers()) do ctx.effect(p, kind, payload) end
end

local function refresh(player)
	local profile = profileOf(player)
	if profile then ctx.setMovement(profile); ctx.markDirty(profile) end
end

local function setAppearance(player, transparency)
	local c = character(player)
	if not c then return end
	for _, d in ipairs(c:GetDescendants()) do
		if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
			if transparency then
				if d:GetAttribute("PFEOriginalT") == nil then d:SetAttribute("PFEOriginalT", d.Transparency) end
				d.Transparency = transparency
			elseif d:GetAttribute("PFEOriginalT") ~= nil then
				d.Transparency = d:GetAttribute("PFEOriginalT"); d:SetAttribute("PFEOriginalT", nil)
			end
		end
	end
	player:SetAttribute("PFEHideTitle", transparency ~= nil or nil)   -- (invisible: no plate either)
end

local function effectOn(player, class, on, props)
	local r = root(player)
	if not r then return end
	local existing = r:FindFirstChild("PFEAdmin" .. class)
	if existing then existing:Destroy() end
	if on then
		local e = Instance.new(class)
		e.Name = "PFEAdmin" .. class
		for k, v in pairs(props or {}) do e[k] = v end
		e.Parent = class == "ForceField" and player.Character or r
	end
end

local function jail(player, on)
	if jails[player] then jails[player]:Destroy(); jails[player] = nil end
	if not on then return end
	local r = root(player)
	if not r then return end
	local cage = Instance.new("Model"); cage.Name = "PFEJail_" .. player.Name
	local centre = r.Position
	local function bar(size, offset, transparency)
		local p = Instance.new("Part"); p.Anchored = true; p.Size = size; p.CFrame = CFrame.new(centre + offset)
		p.Material = Enum.Material.Neon; p.Color = Color3.fromRGB(255, 70, 70); p.Transparency = transparency or 0.35; p.Parent = cage
	end
	bar(Vector3.new(10, 1, 10), Vector3.new(0, -3.5, 0), 0); bar(Vector3.new(10, 1, 10), Vector3.new(0, 6.5, 0))
	bar(Vector3.new(1, 10, 10), Vector3.new(5, 1.5, 0)); bar(Vector3.new(1, 10, 10), Vector3.new(-5, 1.5, 0))
	bar(Vector3.new(10, 10, 1), Vector3.new(0, 1.5, 5)); bar(Vector3.new(10, 10, 1), Vector3.new(0, 1.5, -5))
	cage.Parent = workspace
	jails[player] = cage
end

local function giveEggs(profile, count, zone)
	local planets = Config.PlanetOrder
	local given = 0
	for _ = 1, count do
		if #profile.Data.Eggs >= Config.MaxStoredEggs then break end
		local planet = planets[rng:NextInteger(1, #planets)]
		local info = ctx.Expeditions.RollEgg(profile, planet.Id, zone or 4, 10, 0.05)
		if info then
			table.insert(profile.Data.Eggs, {Id = ctx.Data.Guid(), EggId = info.Id, Scale = ctx.Expeditions.RollSize(),
				Mutation = ctx.Expeditions.RollMutation(profile, planet.Id)})
			profile.Data.DiscoveredEggs[info.Id] = true
			given += 1
		end
	end
	ctx.markDirty(profile)
	return given
end

-- ---------------------------------------------------------------- commands
-- each: Names, Args (help text), Desc, Run(admin, args) -> text, clientAction
local commands, byName = {}, {}
local function cmd(namesList, args, desc, run)
	local entry = {Names = namesList, Args = args, Desc = desc, Run = run}
	table.insert(commands, entry)
	for _, n in ipairs(namesList) do byName[n] = entry end
end
local function each(admin, token, fn)
	local list = targets(admin, token)
	for _, p in ipairs(list) do pcall(fn, p) end
	return list
end

-- movement & body
cmd({"fly"}, "[plr] [speed]", "Fly (WASD / move stick, Space up, Ctrl / crouch down)", function(a, x)
	local speed = num(x[2], 60)
	return "Flying: " .. names(each(a, x[1], function(p) p:SetAttribute("PFEAdminFly", speed) end))
end)
cmd({"unfly"}, "[plr]", "Stop flying", function(a, x) return "Landed: " .. names(each(a, x[1], function(p) p:SetAttribute("PFEAdminFly", nil) end)) end)
cmd({"noclip"}, "[plr]", "Walk through walls", function(a, x) return "Noclip: " .. names(each(a, x[1], function(p) p:SetAttribute("PFEAdminNoclip", true) end)) end)
cmd({"clip"}, "[plr]", "Solid again", function(a, x) return "Clip: " .. names(each(a, x[1], function(p) p:SetAttribute("PFEAdminNoclip", nil) end)) end)
cmd({"infjump", "infinitejump"}, "[plr]", "Jump in the air forever", function(a, x) return "Infinite jump: " .. names(each(a, x[1], function(p) p:SetAttribute("PFEAdminInfJump", true) end)) end)
cmd({"uninfjump"}, "[plr]", "Normal jumps", function(a, x) return "Normal jump: " .. names(each(a, x[1], function(p) p:SetAttribute("PFEAdminInfJump", nil) end)) end)
cmd({"speed", "ws", "walkspeed"}, "[plr] [n]", "Walk speed", function(a, x)
	local n = num(x[2], 16)
	return "Speed " .. n .. ": " .. names(each(a, x[1], function(p) local pr = profileOf(p); if pr then pr.AdminWalkSpeed = n; refresh(p) end end))
end)
cmd({"unspeed", "unws"}, "[plr]", "Normal walk speed", function(a, x)
	return "Normal speed: " .. names(each(a, x[1], function(p) local pr = profileOf(p); if pr then pr.AdminWalkSpeed = nil; refresh(p) end end))
end)
cmd({"jumppower", "jp", "jump"}, "[plr] [n]", "Jump power", function(a, x)
	local n = num(x[2], 50)
	return "Jump " .. n .. ": " .. names(each(a, x[1], function(p) local pr = profileOf(p); if pr then pr.AdminJump = n; refresh(p) end end))
end)
cmd({"unjumppower", "unjp"}, "[plr]", "Normal jump power", function(a, x)
	return "Normal jump: " .. names(each(a, x[1], function(p) local pr = profileOf(p); if pr then pr.AdminJump = nil; refresh(p) end end))
end)
cmd({"hipheight", "hh"}, "[plr] [n]", "Hip height", function(a, x)
	local n = num(x[2], 0)
	return "Hip height " .. n .. ": " .. names(each(a, x[1], function(p) humanoid(p).HipHeight = n end))
end)
cmd({"size", "scale"}, "[plr] [n]", "Make them bigger / smaller (0.2 - 10)", function(a, x)
	local n = math.clamp(num(x[2], 1), 0.2, 10)
	return "Size " .. n .. ": " .. names(each(a, x[1], function(p) character(p):ScaleTo(n) end))
end)
cmd({"gravity", "grav"}, "[plr] [n]", "Their gravity (default: the planet's)", function(a, x)
	local n = x[2] and num(x[2], 196.2) or nil
	return "Gravity: " .. names(each(a, x[1], function(p) p:SetAttribute("PFEAdminGravity", n) end))
end)
cmd({"sit"}, "[plr]", "Sit down", function(a, x) return "Sat: " .. names(each(a, x[1], function(p) humanoid(p).Sit = true end)) end)
cmd({"trip"}, "[plr]", "Trip over", function(a, x)
	return "Tripped: " .. names(each(a, x[1], function(p) ctx.effect(p, "Knockback", {From = root(p).Position + Vector3.new(0, 0, 2), Force = 20, Duration = 1.2}) end))
end)
cmd({"fling"}, "[plr]", "Fling them far away", function(a, x)
	return "Flung: " .. names(each(a, x[1], function(p)
		local r = root(p)
		ctx.effect(p, "Knockback", {From = r.Position + Vector3.new(rng:NextNumber(-1, 1), -1, rng:NextNumber(-1, 1)), Force = 260, Duration = 2.5})
	end))
end)
cmd({"spin"}, "[plr] [speed]", "Spin around", function(a, x)
	local n = num(x[2], 20)
	return "Spinning: " .. names(each(a, x[1], function(p)
		local r = root(p)
		local old = r:FindFirstChild("PFEAdminSpin"); if old then old:Destroy() end
		local att = r:FindFirstChild("RootAttachment") or r:FindFirstChildOfClass("Attachment")
		local av = Instance.new("AngularVelocity"); av.Name = "PFEAdminSpin"; av.Attachment0 = att
		av.MaxTorque = math.huge; av.AngularVelocity = Vector3.new(0, n, 0); av.Parent = r
	end))
end)
cmd({"unspin"}, "[plr]", "Stop spinning", function(a, x)
	return "Stopped: " .. names(each(a, x[1], function(p) local s = root(p):FindFirstChild("PFEAdminSpin"); if s then s:Destroy() end end))
end)
cmd({"freeze", "fr"}, "[plr]", "Freeze in place", function(a, x) return "Frozen: " .. names(each(a, x[1], function(p) root(p).Anchored = true end)) end)
cmd({"thaw", "unfreeze", "unfr"}, "[plr]", "Unfreeze", function(a, x) return "Thawed: " .. names(each(a, x[1], function(p) root(p).Anchored = false end)) end)
cmd({"invisible", "invis"}, "[plr]", "Invisible to everyone", function(a, x) return "Invisible: " .. names(each(a, x[1], function(p) setAppearance(p, 1) end)) end)
cmd({"visible", "vis"}, "[plr]", "Visible again", function(a, x) return "Visible: " .. names(each(a, x[1], function(p) setAppearance(p, nil) end)) end)
cmd({"ghost"}, "[plr]", "See-through", function(a, x) return "Ghost: " .. names(each(a, x[1], function(p) setAppearance(p, 0.6) end)) end)

-- health
cmd({"god"}, "[plr]", "Can't be hurt (aliens, air, falls)", function(a, x)
	return "God: " .. names(each(a, x[1], function(p)
		local pr = profileOf(p); if pr then pr.God = true end
		effectOn(p, "ForceField", true, {Visible = false})
		local h = humanoid(p); h.Health = h.MaxHealth
	end))
end)
cmd({"ungod"}, "[plr]", "Can be hurt again", function(a, x)
	return "Mortal: " .. names(each(a, x[1], function(p) local pr = profileOf(p); if pr then pr.God = nil end; effectOn(p, "ForceField", false) end))
end)
cmd({"heal"}, "[plr]", "Full health (and air)", function(a, x)
	return "Healed: " .. names(each(a, x[1], function(p)
		local h = humanoid(p); h.Health = h.MaxHealth
		local pr = profileOf(p); if pr then pr.Oxygen = ctx.maxOxygen(pr); ctx.markDirty(pr) end
	end))
end)
cmd({"kill"}, "[plr]", "Kill", function(a, x) return "Killed: " .. names(each(a, x[1], function(p) humanoid(p).Health = 0 end)) end)
cmd({"loopkill", "lk"}, "[plr]", "Kill again every time they spawn", function(a, x)
	return "Loop-killing: " .. names(each(a, x[1], function(p) loopKill[p] = true; humanoid(p).Health = 0 end))
end)
cmd({"unloopkill", "unlk"}, "[plr]", "Stop loop-killing", function(a, x) return "Spared: " .. names(each(a, x[1], function(p) loopKill[p] = nil end)) end)
cmd({"explode"}, "[plr]", "Blow up", function(a, x)
	return "Boom: " .. names(each(a, x[1], function(p)
		local e = Instance.new("Explosion"); e.Position = root(p).Position; e.BlastRadius = 8; e.BlastPressure = 500000; e.Parent = workspace
	end))
end)
cmd({"respawn", "re", "refresh"}, "[plr]", "Respawn at their base", function(a, x)
	return "Respawned: " .. names(each(a, x[1], function(p) local pr = profileOf(p); if pr then ctx.loadCharacter(pr) end end))
end)
cmd({"ff", "forcefield"}, "[plr]", "Visible force field", function(a, x) return "ForceField: " .. names(each(a, x[1], function(p) effectOn(p, "ForceField", true) end)) end)
cmd({"unff"}, "[plr]", "Remove the force field", function(a, x) return "No ForceField: " .. names(each(a, x[1], function(p) effectOn(p, "ForceField", false) end)) end)

-- effects
for _, fx in ipairs({{"fire", "Fire", {Size = 6}}, {"smoke", "Smoke", {}}, {"sparkles", "Sparkles", {}}, {"light", "PointLight", {Range = 20, Brightness = 3}}}) do
	cmd({fx[1]}, "[plr]", "Give them " .. fx[1], function(a, x) return fx[2] .. ": " .. names(each(a, x[1], function(p) effectOn(p, fx[2], true, fx[3]) end)) end)
	cmd({"un" .. fx[1]}, "[plr]", "Remove " .. fx[1], function(a, x) return "No " .. fx[1] .. ": " .. names(each(a, x[1], function(p) effectOn(p, fx[2], false) end)) end)
end

-- teleports
cmd({"bring"}, "[plr]", "Bring them to you", function(a, x)
	local mine = root(a)
	if not mine then return "You have no character" end
	return "Brought: " .. names(each(a, x[1], function(p) if p ~= a then character(p):PivotTo(mine.CFrame * CFrame.new(rng:NextNumber(-4, 4), 0, -4)) end end))
end)
cmd({"to", "goto", "tp2"}, "[plr]", "Teleport to them", function(a, x)
	local target = targets(a, x[1])[1]
	local r = target and root(target)
	if not r or not a.Character then return "Nobody to go to" end
	a.Character:PivotTo(r.CFrame * CFrame.new(0, 0, 4))
	return "Went to " .. target.Name
end)
cmd({"tp", "teleport"}, "[plr] [plr2]", "Teleport the first to the second", function(a, x)
	local dest = targets(a, x[2])[1]
	local r = dest and root(dest)
	if not r then return "Nowhere to go" end
	return "Teleported: " .. names(each(a, x[1], function(p) if p ~= dest then character(p):PivotTo(r.CFrame * CFrame.new(rng:NextNumber(-4, 4), 0, 4)) end end)) .. " to " .. dest.Name
end)
cmd({"planet"}, "[plr] [planet]", "Send them to a planet (Moon, Mars, ... Nebulon)", function(a, x)
	local wanted = string.lower(x[2] or "")
	local planetId
	for id in pairs(Config.Planets) do if string.lower(id) == wanted or string.sub(string.lower(id), 1, #wanted) == wanted and #wanted > 0 then planetId = id end end
	if not planetId then return "Which planet? " .. table.concat((function() local t = {} for _, p in ipairs(Config.PlanetOrder) do table.insert(t, p.Id) end return t end)(), ", ") end
	return "To " .. planetId .. ": " .. names(each(a, x[1], function(p)
		local pr = profileOf(p)
		if pr then
			if pr.Planet ~= "Base" then ctx.Expeditions.DevAction(pr, "DevHome") end
			pr.DevTravel = true
			ctx.Expeditions.DevAction(pr, "DevVisit", planetId)
		end
	end))
end)
cmd({"home", "base"}, "[plr]", "Send them home to their base", function(a, x)
	return "Home: " .. names(each(a, x[1], function(p) local pr = profileOf(p); if pr then ctx.Expeditions.DevAction(pr, "DevHome"); ctx.sendState(pr) end end))
end)
cmd({"jail"}, "[plr]", "Lock them in a cage", function(a, x) return "Jailed: " .. names(each(a, x[1], function(p) jail(p, true) end)) end)
cmd({"unjail"}, "[plr]", "Let them out", function(a, x) return "Released: " .. names(each(a, x[1], function(p) jail(p, false) end)) end)
cmd({"punish"}, "[plr]", "Take their character away", function(a, x) return "Punished: " .. names(each(a, x[1], function(p) character(p).Parent = nil end)) end)
cmd({"unpunish"}, "[plr]", "Give it back", function(a, x) return "Unpunished: " .. names(each(a, x[1], function(p) if p.Character then p.Character.Parent = workspace end end)) end)

-- looks & tools
cmd({"char", "morph"}, "[plr] [username/id]", "Look like someone else", function(a, x)
	local id = tonumber(x[2])
	if not id and x[2] then local ok, r = pcall(function() return Players:GetUserIdFromNameAsync(x[2]) end); if ok then id = r end end
	if not id then return "Whose look? (username or user id)" end
	local ok, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(id) end)
	if not ok then return "Couldn't load that avatar" end
	return "Morphed: " .. names(each(a, x[1], function(p) humanoid(p):ApplyDescription(desc) end))
end)
cmd({"unchar", "unmorph"}, "[plr]", "Their own look again", function(a, x)
	return "Restored: " .. names(each(a, x[1], function(p)
		local desc = Players:GetHumanoidDescriptionFromUserId(math.max(1, p.UserId))
		humanoid(p):ApplyDescription(desc)
	end))
end)
cmd({"name", "tag"}, "[plr] [text]", "A name tag over their head", function(a, x)
	local text = table.concat(x, " ", 2)
	return "Tagged: " .. names(each(a, x[1], function(p)
		local head = character(p):FindFirstChild("Head")
		local old = head:FindFirstChild("PFEAdminTag"); if old then old:Destroy() end
		if text == "" then return end
		local gui = Instance.new("BillboardGui"); gui.Name = "PFEAdminTag"; gui.Size = UDim2.fromOffset(200, 30); gui.StudsOffset = Vector3.new(0, 4.2, 0)
		gui.AlwaysOnTop = true; gui.MaxDistance = 120; gui.Parent = head
		local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(1, 1); l.Text = text; l.TextScaled = true
		l.Font = Enum.Font.FredokaOne; l.TextColor3 = Color3.new(1, 1, 1); l.TextStrokeTransparency = 0; l.Parent = gui
	end))
end)
cmd({"tools", "gear"}, "[plr]", "Give back the bat, raygun and jetpack", function(a, x)
	return "Geared: " .. names(each(a, x[1], function(p) local pr = profileOf(p); if pr then ctx.Gear.OnCharacter(pr) end end))
end)
cmd({"removetools", "rtools"}, "[plr]", "Take their tools", function(a, x)
	return "Disarmed: " .. names(each(a, x[1], function(p)
		humanoid(p):UnequipTools()
		for _, t in ipairs(p.Backpack:GetChildren()) do if t:IsA("Tool") then t:Destroy() end end
	end))
end)

-- the game's things
cmd({"coins", "money", "givecoins"}, "[plr] [n]", "Give coins", function(a, x)
	local n = num(x[2], 1e6)
	return "+" .. Config.Format(n) .. " coins: " .. names(each(a, x[1], function(p)
		local pr = profileOf(p); if pr then pr.Data.Coins = math.max(0, pr.Data.Coins + n); ctx.effect(p, "Coins", {Amount = n}); ctx.markDirty(pr) end
	end))
end)
cmd({"setcoins"}, "[plr] [n]", "Set their coins", function(a, x)
	local n = math.max(0, num(x[2], 0))
	return "Coins = " .. Config.Format(n) .. ": " .. names(each(a, x[1], function(p) local pr = profileOf(p); if pr then pr.Data.Coins = n; ctx.markDirty(pr) end end))
end)
cmd({"eggs", "giveeggs"}, "[plr] [n]", "Great eggs into their storage", function(a, x)
	local n = math.clamp(num(x[2], 3), 1, 50)
	return "Eggs: " .. names(each(a, x[1], function(p) local pr = profileOf(p); if pr then giveEggs(pr, n, 4) end end))
end)
cmd({"allpets", "pets"}, "[plr]", "One of every pet", function(a, x)
	return "All pets: " .. names(each(a, x[1], function(p) local pr = profileOf(p); if pr then ctx.Expeditions.DevAction(pr, "DevPets") end end))
end)
cmd({"pass", "givepass"}, "[plr] [pass] [minutes]", "A game pass for a while (DoubleMoney, Lucky, SuperSuit, SpeedBoots, BigCargo, RadarPro)", function(a, x)
	local key
	for k in pairs(Config.GamePasses) do if x[2] and string.lower(k) == string.lower(x[2]) then key = k end end
	if not key then return "Which pass?" end
	local minutes = num(x[3], 30)
	return key .. " for " .. minutes .. " min: " .. names(each(a, x[1], function(p) local pr = profileOf(p); if pr then ctx.Shop.GrantTemp(pr, key, minutes * 60) end end))
end)
cmd({"luck"}, "[plr] [minutes]", "x2 luck", function(a, x)
	local minutes = num(x[2], 30)
	return "Luck: " .. names(each(a, x[1], function(p)
		local pr = profileOf(p); if pr then pr.Data.LuckUntil = math.max(os.time(), pr.Data.LuckUntil or 0) + minutes * 60; ctx.markDirty(pr) end
	end))
end)
cmd({"oxygen", "air"}, "[plr]", "Full air tank", function(a, x)
	return "Air: " .. names(each(a, x[1], function(p) local pr = profileOf(p); if pr then pr.Oxygen = ctx.maxOxygen(pr); ctx.markDirty(pr) end end))
end)
cmd({"maxupgrades", "maxall"}, "[plr]", "Best rocket, suit, cargo, jetpack", function(a, x)
	return "Maxed: " .. names(each(a, x[1], function(p)
		local pr = profileOf(p)
		if not pr then return end
		pr.Data.RocketLevel = #Config.Rockets; pr.Data.SuitLevel = #Config.Suits; pr.Data.CargoLevel = #Config.Cargo; pr.Data.JetpackLevel = #Config.Jetpacks
		pr.Base:SetAttribute("RocketLevel", pr.Data.RocketLevel); p:SetAttribute("PFESuitLevel", pr.Data.SuitLevel)
		ctx.Gear.AttachJetpack(pr); ctx.markDirty(pr)
	end))
end)
cmd({"unlockplanets", "travel"}, "[plr]", "Fly to any planet", function(a, x)
	return "Unlocked: " .. names(each(a, x[1], function(p) local pr = profileOf(p); if pr then pr.DevTravel = true; ctx.markDirty(pr) end end))
end)
cmd({"readyeggs", "hatch"}, "[plr]", "Their growing eggs are ready", function(a, x)
	return "Ready: " .. names(each(a, x[1], function(p) local pr = profileOf(p); if pr then ctx.Expeditions.DevAction(pr, "DevReadyEggs") end end))
end)
cmd({"resetmaps", "newmaps"}, "", "New planet maps now", function() ctx.ResetMaps(); return "The planets changed" end)
cmd({"event"}, "[MeteorShower/GoldenHour/Starfall/EggStorm/Aurora/PumpkinNight]", "Start a world event", function(_, x)
	for id in pairs(Config.Events) do if x[1] and string.lower(id) == string.lower(x[1]) then ctx.Events.Start(id); return id .. " started" end end
	local t = {}; for id in pairs(Config.Events) do table.insert(t, id) end
	return "Which event? " .. table.concat(t, ", ")
end)
cmd({"meteorrun", "minigame"}, "", "Start Meteor Run now", function() ctx.Minigame.DevStart(); return "Meteor Run!" end)
cmd({"endmeteorrun"}, "", "End Meteor Run", function() ctx.Minigame.DevEnd(); return "Meteor Run over" end)
cmd({"killaliens", "clearaliens"}, "", "Every alien on the planets dies", function()
	local n = 0
	for _, planet in ipairs(Config.PlanetOrder) do
		for _, record in ipairs(table.clone(ctx.Aliens.List(planet.Id))) do ctx.Aliens.Damage(record, 1e9, nil); n += 1 end
	end
	return n .. " aliens down"
end)

-- the world
cmd({"time", "clocktime"}, "[0-24]", "Time of day for everyone", function(_, x) local n = num(x[1], 14); effectAll("AdminLighting", {ClockTime = n}); return "Time " .. n end)
cmd({"day"}, "", "Daytime for everyone", function() effectAll("AdminLighting", {ClockTime = 14}); return "Day" end)
cmd({"night"}, "", "Night for everyone", function() effectAll("AdminLighting", {ClockTime = 0}); return "Night" end)
cmd({"fog"}, "[end]", "Fog for everyone", function(_, x) effectAll("AdminLighting", {FogEnd = num(x[1], 200)}); return "Fog" end)
cmd({"nofog", "unfog"}, "", "No fog", function() effectAll("AdminLighting", {FogEnd = 100000}); return "No fog" end)
cmd({"music", "play"}, "[sound id]", "Music for everyone in this server", function(_, x)
	local old = workspace:FindFirstChild("PFEAdminMusic"); if old then old:Destroy() end
	local id = tonumber(x[1]); if not id then return "Which sound id?" end
	local s = Instance.new("Sound"); s.Name = "PFEAdminMusic"; s.SoundId = "rbxassetid://" .. id; s.Looped = true; s.Volume = 0.6
	s:SetAttribute("PFEKeepSound", true); s.Parent = workspace; s:Play()
	return "Playing " .. id
end)
cmd({"stopmusic", "stop"}, "", "Stop the admin music", function() local s = workspace:FindFirstChild("PFEAdminMusic"); if s then s:Destroy() end; return "Stopped" end)

-- messages
cmd({"m", "message", "announce"}, "[text]", "A big message to this server", function(a, x)
	local text = table.concat(x, " "); effectAll("AdminAnnounce", {Text = text, From = a.DisplayName}); return "Announced"
end)
cmd({"h", "hint"}, "[text]", "A small notice to everyone here", function(_, x) tellAll(table.concat(x, " "), "Purple"); return "Hinted" end)
cmd({"pm"}, "[plr] [text]", "A private message", function(a, x)
	local text = table.concat(x, " ", 2)
	return "PM to: " .. names(each(a, x[1], function(p) ctx.remotes.Notice:FireClient(p, "[" .. a.DisplayName .. "] " .. text, "Blue") end))
end)
cmd({"countdown"}, "[seconds]", "A countdown for everyone", function(_, x)
	local n = math.clamp(math.floor(num(x[1], 10)), 1, 60)
	task.spawn(function() for i = n, 1, -1 do tellAll(tostring(i), "Gold"); task.wait(1) end; tellAll("GO!", "Green") end)
	return "Counting down " .. n
end)

-- moderation
cmd({"kick"}, "[plr] [reason]", "Kick from this server", function(a, x)
	local reason = table.concat(x, " ", 2); if reason == "" then reason = "Kicked by an admin" end
	return "Kicked: " .. names(each(a, x[1], function(p) if not Admin.IsAdmin(p) then p:Kick(reason) end end))
end)
cmd({"ban"}, "[plr] [reason]", "Ban from the game (every server, stays)", function(a, x)
	local reason = table.concat(x, " ", 2); if reason == "" then reason = "Banned by an admin" end
	return "Banned: " .. names(each(a, x[1], function(p)
		if Admin.IsAdmin(p) then return end
		bans[p.UserId] = reason
		if banStore then pcall(function() banStore:SetAsync(tostring(p.UserId), reason) end) end
		p:Kick(reason)
	end))
end)
cmd({"unban"}, "[username/id]", "Lift a ban", function(_, x)
	local id = tonumber(x[1])
	if not id and x[1] then local ok, r = pcall(function() return Players:GetUserIdFromNameAsync(x[1]) end); if ok then id = r end end
	if not id then return "Who?" end
	bans[id] = nil
	if banStore then pcall(function() banStore:RemoveAsync(tostring(id)) end) end
	return "Unbanned " .. id
end)
cmd({"slock", "serverlock"}, "", "Nobody new can join this server", function() serverLocked = true; return "Server locked" end)
cmd({"unslock", "unlock"}, "", "Open the server again", function() serverLocked = false; return "Server open" end)
cmd({"shutdown"}, "", "Kick everyone in this server", function(a)
	for _, p in ipairs(Players:GetPlayers()) do if p ~= a then p:Kick("The server was shut down by an admin") end end
	return "Everyone else was kicked"
end)
cmd({"rejoin", "rj"}, "[plr]", "Rejoin a new server", function(a, x)
	return "Rejoining: " .. names(each(a, x[1], function(p) TeleportService:TeleportAsync(game.PlaceId, {p}) end))
end)
cmd({"admin"}, "[plr]", "Admin for this server", function(a, x)
	return "Admin: " .. names(each(a, x[1], function(p) sessionAdmins[p.UserId] = true; p:SetAttribute("PFEAdmin", true) end))
end)
cmd({"unadmin"}, "[plr]", "No longer admin here", function(a, x)
	return "Unadmin: " .. names(each(a, x[1], function(p)
		if not Config.Admins[p.UserId] then sessionAdmins[p.UserId] = nil; p:SetAttribute("PFEAdmin", nil) end
	end))
end)

-- the admin's own screen
-- view / spectate: your camera follows them (also after they die and respawn), you see the planet they
-- are on, and your HUD shows THEIR air, cargo, coins, passes and egg scanner / radar (for videos).
local spectators = {} -- admin -> target
local function stopSpectating(admin)
	if not spectators[admin] then return end
	spectators[admin] = nil
	if admin.Parent then ctx.effect(admin, "Spectate", {Stop = true}) end
end
function Admin.SpectatorsOf(target)
	local list = {}
	for admin, t in pairs(spectators) do if t == target and admin.Parent then table.insert(list, admin) end end
	return list
end
cmd({"view", "spectate"}, "[plr]", "Watch them: camera, their planet and their HUD", function(a, x)
	local t = targets(a, x[1])[1]; if not t then return "Nobody" end
	if t == a then stopSpectating(a); return "Camera back", {Action = "unview"} end
	spectators[a] = t
	local profile = profileOf(t)
	if profile then ctx.effect(a, "Spectate", ctx.spectateState(profile)) end
	return "Viewing " .. t.Name, {Action = "view", Target = t}
end)
cmd({"unview"}, "", "Your camera back", function(a) stopSpectating(a); return "Camera back", {Action = "unview"} end)
cmd({"esp"}, "", "See everyone through walls (your screen)", function() return "ESP on", {Action = "esp", On = true} end)
cmd({"unesp"}, "", "ESP off", function() return "ESP off", {Action = "esp", On = false} end)
cmd({"fov"}, "[n]", "Your field of view", function(_, x) return "FOV", {Action = "fov", Value = math.clamp(num(x[1], 70), 20, 120)} end)
cmd({"cmds", "commands", "help"}, "", "The command list", function() return #commands .. " commands", {Action = "cmds"} end)

-- ---------------------------------------------------------------- admin abuse (every server)
local abuse = {}
local giantFolder
local function silhouettes(userIds, seconds)
	if not giantFolder then giantFolder = Instance.new("Folder"); giantFolder.Name = "PFE_AdminGiants"; giantFolder.Parent = workspace end
	local island = ctx.world:FindFirstChild("OriginalIsland")
	local centre = island and island:GetPivot().Position or Vector3.new(0, 60, 0)
	for i, id in ipairs(userIds) do
		task.spawn(function()
			local ok, model = pcall(function() return Players:CreateHumanoidModelFromUserId(id) end)
			if not ok or not model then return end
			model.Name = "AdminGiant_" .. id
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end
				if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
			end
			local h = model:FindFirstChildOfClass("Humanoid"); if h then h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
			pcall(function() model:ScaleTo(45) end)
			local angle = (i - 1) / math.max(1, #userIds) * math.pi * 2 + math.pi / 4
			local at = centre + Vector3.new(math.cos(angle) * 700, 60, math.sin(angle) * 700)
			model:PivotTo(CFrame.lookAt(at, Vector3.new(centre.X, at.Y, centre.Z)))
			local _, size = model:GetBoundingBox()
			model:PivotTo(model:GetPivot() + Vector3.new(0, size.Y / 2 - 60, 0))
			local shade = Instance.new("Highlight"); shade.FillColor = Color3.fromRGB(10, 8, 20); shade.FillTransparency = 0.05
			shade.OutlineColor = Color3.fromRGB(255, 215, 90); shade.OutlineTransparency = 0.2; shade.DepthMode = Enum.HighlightDepthMode.Occluded
			shade.Parent = model
			model:SetAttribute("PFEAdminGiant", true)
			model.Parent = giantFolder
			task.delay(seconds, function() if model.Parent then model:Destroy() end end)
		end)
	end
end
function abuse.Announce(args) effectAll("AdminAnnounce", {Text = tostring(args.Text or ""), From = args.From, Global = true}) end
function abuse.Silhouettes(args)
	silhouettes(args.Ids or {}, math.clamp(num(args.Seconds, 90), 10, 600))
	effectAll("AdminAnnounce", {Text = "THE ADMINS ARE WATCHING", From = args.From, Global = true, Style = "Giant"})
end
function abuse.Luck(args)
	local minutes = math.clamp(num(args.Minutes, 15), 1, 180)
	workspace:SetAttribute("PFEAdminLuck", math.clamp(num(args.Multiplier, 2), 1, 100))
	workspace:SetAttribute("PFEAdminLuckUntil", os.time() + minutes * 60)
	tellAll("ADMIN ABUSE: x" .. workspace:GetAttribute("PFEAdminLuck") .. " luck for " .. minutes .. " min!", "Purple")
end
function abuse.Coins(args)
	local minutes = math.clamp(num(args.Minutes, 15), 1, 180)
	workspace:SetAttribute("PFEAdminCoins", math.clamp(num(args.Multiplier, 2), 1, 100))
	workspace:SetAttribute("PFEAdminCoinsUntil", os.time() + minutes * 60)
	tellAll("ADMIN ABUSE: x" .. workspace:GetAttribute("PFEAdminCoins") .. " coins for " .. minutes .. " min!", "Gold")
end
function abuse.Event(args) if Config.Events[args.Id] then ctx.Events.Start(args.Id) end end
function abuse.MeteorRun() ctx.Minigame.DevStart() end
function abuse.EggRain(args)
	local n = math.clamp(math.floor(num(args.Count, 2)), 1, 10)
	for _, profile in pairs(ctx.profiles) do giveEggs(profile, n, 4) end
	for _, planet in ipairs(Config.PlanetOrder) do for _ = 1, n * 3 do pcall(ctx.Expeditions.SpawnBonusEgg, planet.Id) end end
	tellAll("ADMIN ABUSE: egg rain! Great eggs for everyone and every planet!", "Gold")
end
function abuse.CoinRain(args)
	local minutes = math.clamp(num(args.Minutes, 10), 1, 600)
	for _, profile in pairs(ctx.profiles) do
		local _, income = ctx.petList(profile)
		local amount = math.max(5000, income * 60 * minutes)
		profile.Data.Coins += amount
		ctx.effect(profile.Player, "Coins", {Amount = amount})
		ctx.markDirty(profile)
	end
	tellAll("ADMIN ABUSE: coin rain - " .. minutes .. " minutes of income for everyone!", "Gold")
end
function abuse.Pass(args)
	if not Config.GamePasses[args.Key] then return end
	local minutes = math.clamp(num(args.Minutes, 15), 1, 30)
	for _, profile in pairs(ctx.profiles) do ctx.Shop.GrantTemp(profile, args.Key, minutes * 60) end
	tellAll("ADMIN ABUSE: " .. Config.GamePasses[args.Key].Name .. " for everyone, " .. minutes .. " min!", "Gold")
end
function abuse.Disco(args) effectAll("AdminDisco", {Seconds = math.clamp(num(args.Seconds, 30), 5, 300)}) end
function abuse.Night(args) effectAll("AdminLighting", {ClockTime = num(args.ClockTime, 0)}) end
function abuse.Restart(args)
	for _, p in ipairs(Players:GetPlayers()) do
		if not Admin.IsAdmin(p) then p:Kick(tostring(args.Text or "The game is updating - join again!")) end
	end
end

local function runAbuse(kind, args)
	local fn = abuse[kind]
	if fn then
		local ok, err = pcall(fn, args or {})
		if not ok then warn("[PFE] admin abuse " .. tostring(kind) .. " failed: " .. tostring(err)) end
	end
end
local function publish(kind, args)
	runAbuse(kind, args)
	args = args or {}
	if not ONLINE then return false, "Studio" end
	local ok, err = pcall(function()
		MessagingService:PublishAsync(TOPIC, HttpService:JSONEncode({Kind = kind, Args = args, Job = game.JobId}))
	end)
	return ok, err
end

-- ---------------------------------------------------------------- the remote
local function handle(player, line, kind, args)
	if not Admin.IsAdmin(player) then return {Ok = false, Text = "Not an admin"} end
	if line == "!abuse" then
		if type(kind) ~= "string" or not abuse[kind] then return {Ok = false, Text = "Unknown abuse"} end
		args = type(args) == "table" and args or {}
		args.From = player.DisplayName
		if kind == "Silhouettes" then
			local ids = {}
			for id in pairs(Config.Admins) do table.insert(ids, id) end
			for id in pairs(sessionAdmins) do if not table.find(ids, id) then table.insert(ids, id) end end
			args.Ids = ids
		end
		local ok = publish(kind, args)
		return {Ok = true, Text = kind .. (ok and " - sent to every server" or " - this server (MessagingService unavailable here)")}
	end
	if line == "!list" then
		local list = {}
		for _, c in ipairs(commands) do table.insert(list, {Names = c.Names, Args = c.Args, Desc = c.Desc}) end
		return {Ok = true, List = list}
	end
	if type(line) ~= "string" then return {Ok = false, Text = "?"} end
	line = string.gsub(line, "^%s*[;:!/]?", "")
	local words = {}
	for w in string.gmatch(line, "%S+") do table.insert(words, w) end
	local name = string.lower(table.remove(words, 1) or "")
	local entry = byName[name]
	if not entry then return {Ok = false, Text = "Unknown command: " .. name} end
	local ok, text, client = pcall(entry.Run, player, words)
	if not ok then return {Ok = false, Text = "Failed: " .. tostring(text)} end
	return {Ok = true, Text = text, Client = client}
end

-- ---------------------------------------------------------------- titles over heads
-- OWNER (Config.IsOwner: zoy0m, MM2GARRY) or VIP (the pass, or VIP for a while). The server only marks
-- the player (attribute PFETitle = "Owner" / "VIP"); every client draws the plate itself over that
-- player's CURRENT head (Titles.client). A plate made here inside the Head died with it: on live servers
-- Roblox swaps the Head when the avatar's appearance loads (dynamic heads), so nobody saw them.
local function titleOf(player)
	if Config.IsOwner(player) then return "Owner" end
	if player:GetAttribute("PFEVIP") == true then return "VIP" end
	return nil
end
local function titleTag(player)
	local kind = titleOf(player)
	if player:GetAttribute("PFETitle") ~= kind then player:SetAttribute("PFETitle", kind) end
end
Admin.RefreshTitle = function(player) titleTag(player) end

function Admin.Init(context)
	ctx = context
	Config = ctx.Config
	ctx.Admin = Admin
	if ONLINE then pcall(function() banStore = DataStoreService:GetDataStore("PFE_Bans_v1") end) end
	local remote = ctx.network:FindFirstChild("Admin") or Instance.new("RemoteFunction")
	remote.Name = "Admin"; remote.Parent = ctx.network
	remote.OnServerInvoke = function(player, line, kind, args)
		local ok, result = pcall(handle, player, line, kind, args)
		if ok then return result end
		return {Ok = false, Text = tostring(result)}
	end
	local function onPlayer(player)
		if bans[player.UserId] then player:Kick(bans[player.UserId]); return end
		if banStore then
			local ok, reason = pcall(function() return banStore:GetAsync(tostring(player.UserId)) end)
			if ok and reason then bans[player.UserId] = reason; player:Kick(reason); return end
		end
		if serverLocked and not Admin.IsAdmin(player) then player:Kick("This server is locked"); return end
		if Admin.IsAdmin(player) then player:SetAttribute("PFEAdmin", true) end
		if Config.IsOwner(player) then player:SetAttribute("PFEOwner", true) end
		player.CharacterAdded:Connect(function(char)
			titleTag(player)
			if loopKill[player] then task.delay(0.5, function() local h = char:FindFirstChildOfClass("Humanoid"); if h then h.Health = 0 end end) end
		end)
		titleTag(player)
		player:GetAttributeChangedSignal("PFEVIP"):Connect(function() titleTag(player) end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
	Players.PlayerRemoving:Connect(function(p)
		loopKill[p] = nil; jail(p, false)
		spectators[p] = nil
		for admin, t in pairs(spectators) do
			if t == p then stopSpectating(admin); ctx.remotes.Notice:FireClient(admin, p.Name .. " left - camera back", "Red") end
		end
	end)
	-- the spectated player's HUD state, four times a second
	task.spawn(function()
		while true do
			task.wait(0.25)
			for admin, t in pairs(spectators) do
				local profile = t.Parent and profileOf(t)
				if admin.Parent and profile then
					local ok, state = pcall(ctx.spectateState, profile)
					if ok then ctx.effect(admin, "Spectate", state) end
				end
			end
		end
	end)
	if ONLINE then task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				local ok, data = pcall(function() return HttpService:JSONDecode(message.Data) end)
				if ok and type(data) == "table" and data.Job ~= game.JobId then runAbuse(data.Kind, data.Args) end
			end)
		end)
	end) end
end

Admin.Commands = commands
return Admin
