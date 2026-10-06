--!nocheck
-- Fusion (v28): three eggs from the backpack are fused into one FUSION EGG (Config.FusionOdds decides its
-- rarity: three of a rarity always go one up, two make it a coin flip, otherwise 35%). The egg remembers the
-- three eggs (Sources): planted and grown, it hatches from their drop tables tilted towards its rarity
-- (Config.FusionDrops) - and the hatch multiplier applies like on any egg. Its size roll is the eggs' average and
-- a bit more, its mutation the best of theirs. The client plays the show (FusionShow.client) from FusionResult.
local Fusion = {}
local ctx, Config, Data, EggForge
local rng = Random.new()

function Fusion.Fuse(profile, ids)
	if type(ids) ~= "table" or #ids ~= Config.FusionCost then return end
	if profile.Busy or profile.Stolen then return end
	local data = profile.Data
	local picked, seen = {}, {}
	for _, id in ipairs(ids) do
		if type(id) ~= "string" or seen[id] then return end
		seen[id] = true
		for index, egg in ipairs(data.Eggs) do
			if egg.Id == id then table.insert(picked, {Index = index, Egg = egg}); break end
		end
	end
	if #picked ~= Config.FusionCost then ctx.notice(profile, "Pick three eggs from your backpack."); return end
	local rarities, sources, scale, bestMutation = {}, {}, 0, "Normal"
	local mutationOrder = {}
	for i, m in ipairs(Config.MutationList) do mutationOrder[m.Id] = i end
	for _, entry in ipairs(picked) do
		local info = Config.Eggs[entry.Egg.EggId]
		if not info then return end
		table.insert(rarities, info.Rarity)
		-- a fusion egg fused again passes on the eggs it was made of
		if info.Fusion and entry.Egg.Sources then
			for _, src in ipairs(entry.Egg.Sources) do if #sources < 3 then table.insert(sources, src) end end
		elseif not info.Fusion then
			table.insert(sources, entry.Egg.EggId)
		end
		scale += Config.AssetScale(entry.Egg.Scale)
		local m = entry.Egg.Mutation or "Normal"
		if (mutationOrder[m] or 1) > (mutationOrder[bestMutation] or 1) then bestMutation = m end
	end
	-- (never more than three remembered eggs: the newest win)
	while #sources > 3 do table.remove(sources, 1) end
	-- the rarity it comes out as
	local odds = Config.FusionOdds(rarities)
	local roll, rarity = rng:NextNumber(), odds[#odds].Rarity
	for _, row in ipairs(odds) do
		roll -= row.Chance
		if roll <= 0 then rarity = row.Rarity; break end
	end
	-- (v36) a brand-new, one-of-a-kind egg of that rarity, with its own hybrid pets inside (EggForge)
	local forgedId = EggForge.NewId(rarity, rng)
	local eggInfo = EggForge.Info(forgedId)
	if not eggInfo then return end
	EggForge.Template(forgedId)
	local order = {}
	for i, id in ipairs(Config.RarityOrder) do order[id] = i end
	local best = 0
	for _, r in ipairs(rarities) do best = math.max(best, order[r] or 1) end
	-- the eggs are used up (highest index first, so the others stay where they are)
	table.sort(picked, function(a, b) return a.Index > b.Index end)
	local eggIds = {}
	for _, entry in ipairs(picked) do
		table.insert(eggIds, entry.Egg.EggId)
		table.remove(data.Eggs, entry.Index)
	end
	local egg = {Id = Data.Guid(), EggId = eggInfo.Id, Scale = Config.AssetScale(scale / #picked * 1.15), Mutation = bestMutation}
	table.insert(data.Eggs, egg)
	data.DiscoveredEggs[eggInfo.Id] = true
	data.Stats.Fusions = (data.Stats.Fusions or 0) + 1
	-- the hybrids it may hatch, for the show
	local hybrids, total = {}, 0
	for _, h in ipairs(eggInfo.Hybrids) do total += h.Weight end
	for _, h in ipairs(eggInfo.Hybrids) do
		table.insert(hybrids, {Name = h.Name, Parts = h.Parts, Income = h.Income, Chance = h.Weight / math.max(1, total)})
	end
	ctx.effect(profile.Player, "FusionResult", {EggId = eggInfo.Id, Rarity = rarity, Scale = egg.Scale, Mutation = egg.Mutation,
		Eggs = eggIds, Upgraded = (order[rarity] or 1) > best, Hybrids = hybrids, Name = eggInfo.Name, Id = egg.Id})
	ctx.markDirty(profile)
	ctx.sendState(profile)
	return egg
end

function Fusion.Init(context)
	ctx = context; Config = ctx.Config; Data = ctx.Data
	EggForge = require(game:GetService("ReplicatedStorage"):WaitForChild("PFE"):WaitForChild("EggForge"))
end

return Fusion
