--!nocheck
-- Robux shop: game pass ownership and developer product receipts.
-- Every grant is applied in memory and saved together with its receipt id, so a
-- retried receipt can never be granted twice.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shop = {}
local ctx
local passById, productById = {}, {}

function Shop.Init(context)
	ctx = context
	for _, pass in ipairs(ctx.Config.GamePassList) do
		if pass.Id and pass.Id > 0 then passById[pass.Id] = pass end
	end
	for _, product in ipairs(ctx.Config.ProductList) do
		if product.Id and product.Id > 0 then productById[product.Id] = product end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = passById[passId]
		local profile = ctx.profiles[player]
		if not purchased or not pass or not profile then return end
		profile.Passes[pass.Key] = true
		ctx.OnPassGranted(profile, pass.Key)
		ctx.notice(profile, pass.Icon .. " " .. pass.Name .. " unlocked. Thank you!", "Gold")
		ctx.markDirty(profile)
	end)

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local profile = player and ctx.profiles[player]
		local product = productById[receipt.ProductId]
		if not profile or not product or type(receipt.PurchaseId) ~= "string" or #receipt.PurchaseId > 128 then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if profile.Data.Purchases[receipt.PurchaseId] ~= nil then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local ok, err = pcall(ctx.GrantProduct, profile, product)
		if not ok then
			warn("[PFE] product grant failed", product.Key, err)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		profile.Data.Purchases[receipt.PurchaseId] = product.Key
		ctx.markDirty(profile)
		if not ctx.Data.HasStore() then return Enum.ProductPurchaseDecision.PurchaseGranted end
		for _ = 1, 4 do
			if ctx.Data.Save(profile, false) then return Enum.ProductPurchaseDecision.PurchaseGranted end
			task.wait(1.5)
		end
		-- Not saved yet: the next autosave stores grant + receipt together; Roblox retries
		-- later and the receipt check above then answers PurchaseGranted without re-granting.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

function Shop.RefreshPasses(profile)
	for _, pass in ipairs(ctx.Config.GamePassList) do
		if pass.Id and pass.Id > 0 then
			task.spawn(function()
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, profile.Player.UserId, pass.Id)
				if ok and owns and ctx.profiles[profile.Player] == profile then
					profile.Passes[pass.Key] = true
					ctx.OnPassGranted(profile, pass.Key)
					ctx.markDirty(profile)
				end
			end)
		end
	end
end

function Shop.Has(profile, key)
	if profile.Passes[key] == true or (profile.DevPasses == true and RunService:IsStudio()) then return true end
	local temp = profile.Data and profile.Data.TempPasses
	return temp ~= nil and (temp[key] or 0) > os.time()
end

-- a game pass for a while (dungeon loot, codes, gifts): stacks up to `max` (default Config.TempPassMax) from now
function Shop.GrantTemp(profile, key, seconds, max)
	local config = ctx.Config
	if not config.GamePasses[key] then return 0 end
	local now = os.time()
	local temp = profile.Data.TempPasses
	local untilTime = math.min(math.max(now, temp[key] or 0) + seconds, now + math.max(max or 0, config.TempPassMax))
	temp[key] = untilTime
	ctx.OnPassGranted(profile, key)
	ctx.markDirty(profile)
	return untilTime - now
end

-- the player attributes everyone's clients read (the VIP plate over the head, the gold super helmet)
-- always match what the player has RIGHT NOW: a bought pass, a temporary one still running (Free VIP,
-- gifts, alien chests - kept in the save, so also after a rejoin) or Studio's DevPasses. Checked every
-- second; before, only the moment of granting set them, so a Free VIP who came back had no VIP plate.
function Shop.SyncFlags(profile)
	local player = profile.Player
	if not player.Parent then return end
	for key, attribute in pairs({VIP = "PFEVIP", SuperSuit = "PFESuperSuit"}) do
		local has = Shop.Has(profile, key)
		if (player:GetAttribute(attribute) == true) ~= has then player:SetAttribute(attribute, has) end
	end
end

-- temporary passes that ran out: their effects go (walk speed, suit, cargo...)
function Shop.ExpireTemp(profile)
	local temp = profile.Data.TempPasses
	local now, changed = os.time(), false
	for key, untilTime in pairs(temp) do
		if untilTime <= now then temp[key] = nil; changed = true end
	end
	if changed then
		if not Shop.Has(profile, "SuperSuit") then profile.Player:SetAttribute("PFESuperSuit", false) end
		if not Shop.Has(profile, "VIP") then profile.Player:SetAttribute("PFEVIP", false) end
		ctx.setMovement(profile)
		ctx.markDirty(profile)
	end
	return changed
end

return Shop
