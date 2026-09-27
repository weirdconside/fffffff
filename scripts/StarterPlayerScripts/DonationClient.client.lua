-- Client presentation for the Admin Vault. Ownership stays in DonationServer.
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
-- Gold [ADMIN] chat tag for Admin Pass owners (server-set attribute).
TextChatService.OnIncomingMessage=function(message)
    local props=Instance.new('TextChatMessageProperties')
    local source=message.TextSource
    local sender=source and Players:GetPlayerByUserId(source.UserId)
    if sender and sender:GetAttribute('Perk_AdminPass')==true then
        props.PrefixText='<font color="#FFD24A">[ADMIN]</font> '..message.PrefixText
    end
    return props
end
-- "Thank you" banner with brick confetti when somebody tips.
local toastGui=Instance.new('ScreenGui');toastGui.Name='VaultThanks';toastGui.ResetOnSpawn=false;toastGui.IgnoreGuiInset=true;toastGui.DisplayOrder=62;toastGui.Parent=playerGui
local queue,busy={},false
local COLORS={Theme.Colors.Gold,Theme.Colors.Blue,Theme.Colors.Green,Theme.Colors.Purple,Theme.Colors.Red}
local function confetti(amount)
    for i=1,amount do
        local b=Instance.new('Frame');b.BorderSizePixel=0;b.Size=UDim2.fromOffset(math.random(8,14),math.random(6,10));b.AnchorPoint=Vector2.new(.5,.5)
        b.BackgroundColor3=COLORS[(i%#COLORS)+1];b.Position=UDim2.new(.5,math.random(-40,40),0,70);b.Rotation=math.random(0,360);b.ZIndex=4;b.Parent=toastGui
        local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,2);corner.Parent=b
        local target=UDim2.new(.5+math.random(-45,45)/100,0,.35+math.random(0,50)/100,0)
        TweenService:Create(b,TweenInfo.new(1.4+math.random()*.8,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=target,Rotation=b.Rotation+math.random(-360,360),BackgroundTransparency=1}):Play()
        task.delay(2.4,function() b:Destroy() end)
    end
end
local function show(data)
    busy=true
    local plate=Instance.new('Frame');plate.Name='Toast';plate.AnchorPoint=Vector2.new(.5,0);plate.Position=UDim2.new(.5,0,0,-80);plate.Size=UDim2.fromOffset(460,64);plate.ZIndex=5;plate.Parent=toastGui
    Theme.skin(plate,Color3.fromRGB(111,54,170))
    local title=Instance.new('TextLabel');title.BackgroundTransparency=1;title.Size=UDim2.new(1,-20,0,30);title.Position=UDim2.fromOffset(10,6);title.ZIndex=8;title.Parent=plate
    Theme.text(title,20,Theme.Colors.Gold);title.Text=tostring(data.name or 'Someone')..' SUPPORTED THE GAME!'
    local sub=Instance.new('TextLabel');sub.BackgroundTransparency=1;sub.Size=UDim2.new(1,-20,0,20);sub.Position=UDim2.fromOffset(10,36);sub.ZIndex=8;sub.Parent=plate
    Theme.text(sub,14,Theme.Colors.White);sub.Text=tostring(data.title or 'THANK YOU')..'  -  thank you for keeping the harbour alive!'
    TweenService:Create(plate,TweenInfo.new(.45,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=UDim2.new(.5,0,0,70)}):Play()
    confetti(math.clamp(math.floor((tonumber(data.amount) or 25)/8),12,60))
    task.delay(4.2,function()
        TweenService:Create(plate,TweenInfo.new(.35),{Position=UDim2.new(.5,0,0,-80)}):Play()
        task.delay(.4,function() plate:Destroy();busy=false;if #queue>0 then show(table.remove(queue,1)) end end)
    end)
end
remote.OnClientEvent:Connect(function(kind,payload)
    if kind=='Open' then shop:openShop()
    elseif kind=='State' then shop:applyState(payload)
    elseif kind=='Thanks' and type(payload)=='table' then
        if busy then if #queue<4 then queue[#queue+1]=payload end else show(payload) end
    end
end)
remote:FireServer('State')
