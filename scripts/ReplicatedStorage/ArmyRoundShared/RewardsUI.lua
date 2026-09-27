-- Promo-code window and the like/favourite reward card by the chest. Presentation only:
-- DonationServer decides everything (codes, one claim per account, the rejoin check).
local Players=game:GetService('Players')
local Workspace=game:GetService('Workspace')
local TweenService=game:GetService('TweenService')
local CollectionService=game:GetService('CollectionService')
local RunService=game:GetService('RunService')
local Theme=require(script.Parent.StudTheme)
local C=Theme.Colors
local Rewards={};Rewards.__index=Rewards
local function make(class,parent,name,props)
    local o=Instance.new(class);o.Name=name or class
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent;return o
end
local function text(parent,name,t,size,color,props)
    local o=make('TextLabel',parent,name,props);o.BackgroundTransparency=1;o.Text=t;Theme.headline(o,size,color);o.TextWrapped=true
    return o
end
local STATUS={
    first={'FREE ADMIN TICKET!','1. Press LIKE and FAVORITE on the game page.\n2. REJOIN the game.\n3. Come back to this chest to claim your ticket.'},
    rejoin={'ALMOST THERE!','Like and favorite the game, then REJOIN.\nThe chest checks it after you rejoin (at least 1 minute later).'},
    ready={'YOUR TICKET IS READY!','Thanks for liking and favoriting the game!\nPress CLAIM to get 1 ADMIN TICKET.'},
    claimed={'THANK YOU!','You already got this reward. Enjoy your admin ticket!'},
}
function Rewards.new(parent,remote)
    local self=setmetatable({remote=remote,connections={},inZone=false,status=nil,found=0,total=6},Rewards)
    local gui=make('ScreenGui',parent,'Rewards',{ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=60,ZIndexBehavior=Enum.ZIndexBehavior.Sibling});self.gui=gui
    Theme.safe(gui)
    -- ------------------------------------------------------------ codes window
    local shade=make('TextButton',gui,'Shade',{Text='',AutoButtonColor=false,Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(10,8,20),BackgroundTransparency=.35,Visible=false,ZIndex=20,BorderSizePixel=0})
    local card=make('Frame',gui,'Codes',{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.45),Size=UDim2.fromOffset(460,300),Visible=false,ZIndex=21,Active=true})
    Theme.skin(card,Color3.fromRGB(52,44,66));self.fit=make('UIScale',card,'Fit')
    local header=make('Frame',card,'Header',{Position=UDim2.fromOffset(10,10),Size=UDim2.new(1,-20,0,60),ZIndex=22});Theme.skin(header,Color3.fromRGB(111,54,170))
    text(header,'Title','PROMO CODES',30,C.Gold,{Position=UDim2.fromOffset(14,4),Size=UDim2.new(1,-80,0,34),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=24})
    self.foundLabel=text(header,'Found','FOUND 0/6',13,C.White,{Position=UDim2.fromOffset(16,36),Size=UDim2.new(1,-80,0,18),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=24})
    local close=make('TextButton',header,'Close',{Text='X',AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-8,.5,0),Size=UDim2.fromOffset(44,44),ZIndex=25});Theme.button(close,C.Red,20)
    text(card,'Hint','Secret codes are hidden all over the island.\nEvery code = 1 ADMIN TICKET!',15,C.White,{Position=UDim2.fromOffset(20,80),Size=UDim2.new(1,-40,0,42),ZIndex=23})
    local boxFrame=make('Frame',card,'BoxFrame',{Position=UDim2.fromOffset(20,132),Size=UDim2.new(1,-40,0,54),ZIndex=22});Theme.skin(boxFrame,C.Dark)
    local box=make('TextBox',boxFrame,'Input',{BackgroundTransparency=1,Size=UDim2.new(1,-20,1,0),Position=UDim2.fromOffset(10,0),Text='',PlaceholderText='ENTER CODE',
        ClearTextOnFocus=false,ZIndex=24,TextSize=26,Font=Enum.Font.FredokaOne,TextColor3=C.Gold,PlaceholderColor3=C.Muted})
    self.box=box
    local go=make('TextButton',card,'Redeem',{Text='REDEEM',Position=UDim2.fromOffset(20,198),Size=UDim2.new(1,-40,0,50),ZIndex=23});Theme.button(go,C.Green,24)
    self.codeStatus=text(card,'Status','',15,C.White,{Position=UDim2.fromOffset(20,254),Size=UDim2.new(1,-40,0,36),ZIndex=23})
    self.shade,self.card=shade,card
    local function redeem()
        local code=box.Text:gsub('%s','')
        if code=='' then self.codeStatus.Text='Type a code first.';self.codeStatus.TextColor3=C.Red;return end
        self.codeStatus.Text='Checking...';self.codeStatus.TextColor3=C.White
        remote:FireServer('Redeem',code)
    end
    self.connections[#self.connections+1]=go.Activated:Connect(redeem)
    self.connections[#self.connections+1]=box.FocusLost:Connect(function(enter) if enter then redeem() end end)
    self.connections[#self.connections+1]=close.Activated:Connect(function() self:closeCodes() end)
    self.connections[#self.connections+1]=shade.Activated:Connect(function() self:closeCodes() end)
    -- ------------------------------------------------------------ chest reward card
    local reward=make('Frame',gui,'LikeReward',{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-24),Size=UDim2.fromOffset(460,190),Visible=false,ZIndex=10,Active=true})
    Theme.skin(reward,Color3.fromRGB(111,54,170));self.rewardFit=make('UIScale',reward,'Fit')
    make('UIGradient',reward,'Tone',{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(200,170,255))})
    self.rewardTitle=text(reward,'Title','',26,C.Gold,{Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,32),ZIndex=12})
    self.rewardBody=text(reward,'Body','',15,C.White,{Position=UDim2.fromOffset(18,42),Size=UDim2.new(1,-36,0,78),ZIndex=12})
    local claim=make('TextButton',reward,'Claim',{Text='CLAIM',AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-12),Size=UDim2.fromOffset(220,48),ZIndex=12,Visible=false})
    Theme.button(claim,C.Green,24);self.claim=claim
    self.rewardNote=text(reward,'Note','',13,C.Gold,{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-14),Size=UDim2.new(1,-30,0,40),ZIndex=12})
    self.reward=reward
    self.connections[#self.connections+1]=claim.Activated:Connect(function()
        claim.Text='...';remote:FireServer('RewardClaim')
    end)
    -- standing in the golden circle shows the card
    local clock=0
    self.connections[#self.connections+1]=RunService.Heartbeat:Connect(function(dt)
        clock+=dt;if clock<.2 then return end;clock=0
        local camera=Workspace.CurrentCamera
        if camera then
            local v=camera.ViewportSize
            self.fit.Scale=math.clamp(math.min((v.X-20)/460,(v.Y-20)/320),.5,1.2)
            self.rewardFit.Scale=math.clamp(math.min((v.X-20)/460,(v.Y*.45)/190),.5,1.1)
        end
        local inside=false
        local player=Players.LocalPlayer
        local root=self.available and player.Character and player.Character:FindFirstChild('HumanoidRootPart')
        if root then
            for _,zone in ipairs(CollectionService:GetTagged('RewardZone')) do
                if zone:IsA('BasePart') then
                    local d=root.Position-zone.Position
                    if Vector2.new(d.X,d.Z).Magnitude<=zone.Size.Y/2+.6 and math.abs(d.Y)<8 then inside=true end
                end
            end
        end
        if inside~=self.inZone then
            self.inZone=inside
            if inside then remote:FireServer('RewardStatus') else reward.Visible=false end
        end
    end)
    return self
end
function Rewards:showReward(payload)
    if type(payload)~='table' then return end
    local status=payload.status or self.status or 'first';self.status=status
    local def=STATUS[status] or STATUS.first
    self.rewardTitle.Text=def[1];self.rewardBody.Text=def[2]
    self.claim.Visible=status=='ready';self.claim.Text='CLAIM'
    self.rewardNote.Visible=status~='ready'
    self.rewardNote.Text=payload.message or (status=='claimed' and '' or 'Reward: 1 ADMIN TICKET (instant admin panel)')
    if payload.message and payload.ok then self.rewardTitle.Text='+1 ADMIN TICKET!';self.rewardNote.Visible=true end
    if self.inZone then
        if not self.reward.Visible then
            self.reward.Visible=true
            self.reward.Position=UDim2.new(.5,0,1,60);TweenService:Create(self.reward,TweenInfo.new(.25,Enum.EasingStyle.Back),{Position=UDim2.new(.5,0,1,-24)}):Play()
        end
    end
end
function Rewards:codeResult(payload)
    if type(payload)~='table' then return end
    self.codeStatus.Text=tostring(payload.message or '')
    self.codeStatus.TextColor3=payload.ok and C.Green or C.Red
    if payload.ok then self.box.Text='' end
end
function Rewards:applyState(payload)
    if type(payload)~='table' then return end
    self.found=tonumber(payload.codesFound) or self.found;self.total=tonumber(payload.codesTotal) or self.total
    self.foundLabel.Text=('FOUND %d/%d'):format(self.found,self.total)
end
function Rewards:openCodes()
    self.shade.Visible=true;self.card.Visible=true
    self.codeStatus.Text=''
    local fit=self.fit.Scale;self.fit.Scale=fit*.85
    TweenService:Create(self.fit,TweenInfo.new(.22,Enum.EasingStyle.Back),{Scale=fit}):Play()
end
function Rewards:closeCodes() self.shade.Visible=false;self.card.Visible=false;self.box:ReleaseFocus() end
function Rewards:setAvailable(value)
    self.available=value==true
    if not self.available then self:closeCodes();self.reward.Visible=false;self.inZone=false end
end
return Rewards
