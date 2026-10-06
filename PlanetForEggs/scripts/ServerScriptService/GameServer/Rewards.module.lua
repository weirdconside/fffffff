--!nocheck
-- Codes, the Free reward and the VIP's daily present.
--  * Codes (Config.Codes): typed in the Codes window, each once per player (Data.Codes).
--  * Free: like and favourite the game, press Claim, come back into the game: VIP for a while
--    (Data.FreeStage 0 -> 1 on the claim -> 2 on the next visit, see Rewards.Free).
--  * VIP: every new day (UTC) the first time you are in the game, a random game pass for an hour.
local Rewards = {}
local ctx, Config, Shop
local rng = Random.new()

local function today() return math.floor(os.time() / 86400) end

local function describe(reward)
	local parts = {}
	if reward.Coins then table.insert(parts, "+" .. Config.Format(reward.Coins) .. " coins") end
	if reward.Pass then
		local pass = Config.GamePasses[reward.Pass]
		table.insert(parts, (pass and pass.Name or reward.Pass) .. " for " .. math.floor((reward.Seconds or 900) / 60) .. " min")
	end
	return table.concat(parts, " + ")
end

local function give(profile, reward)
	local data = profile.Data
	if reward.Coins then
		data.Coins = math.min(1e15, data.Coins + reward.Coins)
		ctx.effect(profile.Player, "Coins", {Amount = reward.Coins})
	end
	if reward.Pass then Shop.GrantTemp(profile, reward.Pass, reward.Seconds or 900, reward.Seconds or 900) end
	ctx.markDirty(profile)
	ctx.sendState(profile)
end

function Rewards.Redeem(profile, code)
	if type(code) ~= "string" or #code > 40 then return end
	local key = string.upper(string.gsub(code, "%s", ""))
	local reward = Config.Codes[key]
	local function answer(ok, text)
		ctx.effect(profile.Player, "CodeResult", {Ok = ok, Text = text})
		if ok then ctx.notice(profile, text, "Gold") end
	end
	if not reward then return answer(false, "That code doesn't exist.") end
	if reward.Expires and os.time() > reward.Expires then return answer(false, "That code has expired.") end
	if profile.Data.Codes[key] then return answer(false, "You already used this code.") end
	profile.Data.Codes[key] = os.time()
	give(profile, reward)
	answer(true, "Code " .. key .. ": " .. describe(reward) .. "!")
end

-- The Free reward. Roblox lets no game check a like, and its favourite check (AvatarEditorService)
-- doesn't see games favourited on their page, so the proof is a rejoin: CLAIM (the client shows
-- Roblox's own "add to favourites" window) puts it on hold, and VIP comes on the next visit, at least
-- Config.FreeReward.RecheckSeconds after the claim.
local function grantFree(profile)
	local data, R = profile.Data, Config.FreeReward
	data.FreeStage = 2
	Shop.GrantTemp(profile, R.Pass, R.Seconds, R.Seconds)
	ctx.markDirty(profile); ctx.sendState(profile)
	ctx.notice(profile, "👑 VIP for " .. math.floor(R.Seconds / 3600) .. " hours - thanks for the like and the favourite!", "Gold")
	ctx.effect(profile.Player, "FreeResult", {Stage = 2, Text = "VIP unlocked for " .. math.floor(R.Seconds / 3600) .. " hours!"})
end
local function freeDue(profile)
	local data = profile.Data
	return data.FreeStage == 1 and (profile.JoinedAt or 0) > (data.FreeAskedAt or 0)
		and os.time() - (data.FreeAskedAt or 0) >= Config.FreeReward.RecheckSeconds
end
function Rewards.Free(profile, _favorited, claim)
	local data = profile.Data
	local function answer(stage, text)
		ctx.effect(profile.Player, "FreeResult", {Stage = stage, Text = text})
	end
	if data.FreeStage >= 2 then
		if claim then answer(2, "You already got this reward - thank you!") end
		return
	end
	if data.FreeStage == 0 then
		if not claim then return end
		data.FreeStage = 1; data.FreeAskedAt = os.time()
		ctx.markDirty(profile); ctx.sendState(profile)
		return answer(1, "Thank you! Leave and come back into the game - your VIP will be waiting.")
	end
	if freeDue(profile) then return grantFree(profile) end
	if claim then answer(1, "Almost there! Leave and come back into the game to get your VIP.") end
end
-- joined again after claiming: the VIP (a little later if they came straight back)
function Rewards.OnJoin(profile)
	profile.JoinedAt = profile.JoinedAt or os.time()
	if freeDue(profile) then grantFree(profile) end
end

-- the VIP's present: a random pass for an hour, once a day (checked on joining and every minute)
function Rewards.Daily(profile)
	local data = profile.Data
	if not Shop.Has(profile, "VIP") or data.VipDailyDay == today() then return end
	data.VipDailyDay = today()
	local choices = {}
	for _, key in ipairs(Config.TempPassKeys) do
		if profile.Passes[key] ~= true then table.insert(choices, key) end
	end
	if #choices == 0 then ctx.markDirty(profile); return end
	local key = choices[rng:NextInteger(1, #choices)]
	Shop.GrantTemp(profile, key, 3600, 3600)
	ctx.notice(profile, "👑 VIP daily gift: " .. Config.GamePasses[key].Name .. " for 1 hour!", "Gold")
	ctx.markDirty(profile)
	ctx.sendState(profile)
end

-- (v38) the daily calendar (Config.Daily): where the player stands today
function Rewards.DailyState(profile)
	local data = profile.Data
	local t = today()
	local days = #Config.Daily.Days
	local last, step = data.DailyDay or 0, data.DailyStep or 0
	local claimed = last == t
	local onStreak = claimed or last == t - 1
	local nextDay = onStreak and (step % days + 1) or 1
	return {Day = claimed and step or nextDay, Tomorrow = claimed and nextDay or (nextDay % days + 1), Claimable = not claimed,
		Streak = onStreak and (data.DailyStreak or 0) or 0, ResetAt = (t + 1) * 86400}
end
function Rewards.ClaimDaily(profile)
	local data = profile.Data
	local t = today()
	if data.DailyDay == t then return end
	local days = #Config.Daily.Days
	local onStreak = data.DailyDay == t - 1
	local day = onStreak and ((data.DailyStep or 0) % days + 1) or 1
	local entry = Config.Daily.Days[day]
	if entry.Kind == "Egg" and #data.Eggs >= Config.MaxStoredEggs then
		-- (a full backpack would lose the new egg: the gift waits until there is room)
		ctx.notice(profile, "Your egg storage is full - plant some eggs, then claim your gift!")
		ctx.effect(profile.Player, "DailyFull", {Day = day})
		return
	end
	data.DailyDay = t; data.DailyStep = day
	data.DailyStreak = onStreak and (data.DailyStreak or 0) + 1 or 1
	local payload = {Day = day, Name = entry.Name, Kind = entry.Kind}
	if entry.Kind == "Egg" then
		local eggId = Config.DailyEggId(day)
		local ok = eggId and ctx.eggTemplate and pcall(ctx.eggTemplate, eggId)
		table.insert(data.Eggs, {Id = ctx.Data.Guid(), EggId = eggId, Scale = 1, Mutation = "Normal"})
		data.DiscoveredEggs[eggId] = true
		payload.EggId = eggId
	end
	if entry.Pass then
		Shop.GrantTemp(profile, entry.Pass, entry.Seconds or 1800, entry.Seconds or 1800)
		payload.Pass = entry.Pass; payload.Seconds = entry.Seconds
	end
	local coins = Config.DailyCoins(entry, select(2, ctx.petList(profile)))
	if coins > 0 then
		data.Coins = math.min(1e15, data.Coins + coins)
		ctx.effect(profile.Player, "Coins", {Amount = coins})
		payload.Coins = coins
	end
	ctx.effect(profile.Player, "DailyClaimed", payload)
	ctx.notice(profile, "Day " .. day .. " reward: " .. entry.Name .. (coins > 0 and (" + " .. Config.Format(coins) .. " coins") or "") .. "!", "Gold")
	ctx.markDirty(profile)
	ctx.sendState(profile)
end

function Rewards.Init(context)
	ctx = context; Config = ctx.Config; Shop = ctx.Shop
	task.spawn(function()
		while true do
			task.wait(60)
			for _, profile in pairs(ctx.profiles) do
				pcall(Rewards.Daily, profile)
				if freeDue(profile) then pcall(grantFree, profile) end
			end
		end
	end)
end

return Rewards
