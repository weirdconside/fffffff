-- Client presentation only. Ownership and equip decisions stay in DonationServer.
local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local player=Players.LocalPlayer
local shared=ReplicatedStorage:WaitForChild('ArmyRoundShared',20)
if not shared then return end
local remote=shared:WaitForChild('DonationShopRemote',20)
if not remote then return end
local Shop=require(shared:WaitForChild('DonationShop'))
local Catalog=require(shared:WaitForChild('DonationCatalog'))
local shop=Shop.new(player:WaitForChild('PlayerGui'),remote,Catalog)
local function sceneAvailability() shop:setAvailable(player:GetAttribute('ScenePhase')~='Round') end
player:GetAttributeChangedSignal('ScenePhase'):Connect(sceneAvailability)
sceneAvailability()
remote.OnClientEvent:Connect(function(kind,payload)
 if kind=='Open' then shop:openShop() elseif kind=='State' then shop:applyState(payload) end
end)
remote:FireServer('State')
