-- Adapted source StarterPlayer.StarterPlayerScripts.Game.Plots.ActiveAssetsController.AssetMutationWalkSpeed.luau; original motion and personality constants retained.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetItem = {AssetItemData = function(item) return type(item) == "table" and type(item.Personality) == "string" end}
local v3 = {Rainbow="Rainbow", Golden="Golden", Silver="Silver"}
local t1 = {}

local function hasMutation(p1, s1: string) -- line: 20
	return s1 == p1.BaseMutation or table.find(p1.Mutations, s1) ~= nil
end

function t1.GetMultiplier(p2) -- line: 28
	assert(AssetItem.AssetItemData(p2), "Invalid asset item data")

	local Rainbow = v3.Rainbow

	if Rainbow == p2.BaseMutation or table.find(p2.Mutations, Rainbow) ~= nil then
		return 2.0
	end

	local Golden = v3.Golden

	if Golden == p2.BaseMutation or table.find(p2.Mutations, Golden) ~= nil then
		return 0.5
	end

	local Silver = v3.Silver

	if Silver == p2.BaseMutation or table.find(p2.Mutations, Silver) ~= nil then
		return 0.7
	end

	return 1.0
end

return t1

