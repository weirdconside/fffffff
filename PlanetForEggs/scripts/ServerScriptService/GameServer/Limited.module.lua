--!nocheck
-- Limited offers (the Sakura Egg): a fixed number for the whole game. The count sold lives in a
-- DataStore key per offer (UpdateAsync, so servers never overwrite each other), every sale is
-- published to all servers (MessagingService) and each server re-reads the count now and then.
-- Workspace attributes PFELimitedSold_<Key> / PFELimitedStock_<Key> carry it to the shop on every client.
-- In Studio there is no DataStore / MessagingService: the count is kept in memory.
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")

local Limited = {}
local ctx, Config
local ONLINE = not RunService:IsStudio()
local TOPIC = "PFE_Limited"
local store
local sold = {}      -- product key -> sold (as known here)
local offers = {}    -- product key -> product

local function publish(key)
	local product = offers[key]
	workspace:SetAttribute("PFELimitedSold_" .. key, math.min(sold[key] or 0, product.Stock or 0))
	workspace:SetAttribute("PFELimitedStock_" .. key, product.Stock or 0)
end
local function refresh(key)
	if not store then return end
	local ok, value = pcall(function() return store:GetAsync(key) end)
	if ok and type(value) == "number" then sold[key] = math.max(sold[key] or 0, value); publish(key) end
end

function Limited.Remaining(key)
	local product = offers[key]
	if not product then return 0 end
	return math.max(0, (product.Stock or 0) - (sold[key] or 0))
end
function Limited.SoldOut(key) return Limited.Remaining(key) <= 0 end

-- one more sold (the receipt is being granted): the shared count goes up by one
function Limited.Sell(key)
	sold[key] = (sold[key] or 0) + 1
	if store then
		local ok, value = pcall(function()
			return store:UpdateAsync(key, function(old) return (type(old) == "number" and old or 0) + 1 end)
		end)
		if ok and type(value) == "number" then sold[key] = math.max(sold[key], value) end
		pcall(function() MessagingService:PublishAsync(TOPIC, {Key = key, Sold = sold[key]}) end)
	end
	publish(key)
	return sold[key]
end

function Limited.Init(context)
	ctx = context; Config = ctx.Config
	for _, product in ipairs(Config.ProductList) do
		if product.Kind == "LimitedEgg" then offers[product.Key] = product; sold[product.Key] = 0; publish(product.Key) end
	end
	if ONLINE then
		local ok, result = pcall(function() return DataStoreService:GetDataStore("PFE_Limited_v1") end)
		if ok then store = result end
		pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				local data = message.Data
				if type(data) == "table" and offers[data.Key] and type(data.Sold) == "number" then
					sold[data.Key] = math.max(sold[data.Key] or 0, data.Sold); publish(data.Key)
				end
			end)
		end)
	end
	task.spawn(function()
		while true do
			for key in pairs(offers) do refresh(key) end
			task.wait(45)
		end
	end)
end

return Limited
