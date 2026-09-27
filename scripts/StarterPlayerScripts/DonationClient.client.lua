-- Client presentation for the Admin Shop. Ownership stays in DonationServer.
local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local TextChatService=game:GetService('TextChatService')
local TweenService=game:GetService('TweenService')
local player=Players.LocalPlayer
local shared=ReplicatedStorage:WaitForChild('ArmyRoundShared',20)
if not shared then return end
local remote=shared:WaitForChild('DonationShopRemote',20)
if not remote then return end
local Theme=require(shared:WaitForChild('StudTheme'))
local Shop=require(shared:WaitForChild('DonationShop'))
local Catalog=require(shared:WaitForChild('DonationCatalog'))
local playerGui=player:WaitForChild('PlayerGui')
local shop=Shop.new(playerGui,remote,Catalog)
local function sceneAvailability() shop:setAvailable(player:GetAttribute('ScenePhase')~='Round' and player:GetAttribute('ScenePhase')~='Transferring') end
local function intro() shop:setIntro(player:GetAttribute('IntroActive')==true) end
player:GetAttributeChangedSignal('ScenePhase'):Connect(sceneAvailability)
player:GetAttributeChangedSignal('IntroActive'):Connect(intro)
sceneAvailability();intro()
-- Failsafe: never keep the shop button hidden if the title screen could not run.
task.delay(45,function() if player:GetAttribute('IntroActive')==true and not playerGui:FindFirstChild('TitleScreen') then shop:setIntro(false) end end)
-- [ADMIN] / [VIP] chat tags (server-set pass attributes).
TextChatService.OnIncomingMessage=function(message)
    local props=Instance.new('TextChatMessageProperties')
    local source=message.TextSource
    local sender=source and Players:GetPlayerByUserId(source.UserId)
    if sender and sender:GetAttribute('Perk_Admin')==true then
        props.PrefixText='<font color="#FF5A50">[ADMIN]</font> '..message.PrefixText
    elseif sender and sender:GetAttribute('Perk_VIP')==true then
        props.PrefixText='<font color="#5AE68C">[VIP]</font> '..message.PrefixText
    end
    return props
end
remote.OnClientEvent:Connect(function(kind,payload)
    if kind=='Open' then shop:openShop()
    elseif kind=='State' then shop:applyState(payload)
    end
end)
remote:FireServer('State')
