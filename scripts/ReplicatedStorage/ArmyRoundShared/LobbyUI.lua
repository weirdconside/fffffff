-- Room UI: the first player on a square picks the room size, everybody on
-- the square sees a small status bar with a LEAVE button.
local Theme=require(script.Parent.StudTheme)
local UISound=require(script.Parent.UISound)
local Workspace=game:GetService('Workspace')
local RunService=game:GetService('RunService')
local TweenService=game:GetService('TweenService')
local C=Theme.Colors
local Lobby={};Lobby.__index=Lobby
local BAR_W=480
local ROOM_COLORS={Color3.fromRGB(52,142,230),Color3.fromRGB(147,72,213),Color3.fromRGB(64,170,90)}
local function make(class,parent,name,props)
    local o=Instance.new(class);o.Name=name or class
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent;return o
end
local function text(parent,name,value,size,color,props)
    local o=make('TextLabel',parent,name,props);o.BackgroundTransparency=1;o.Text=value;Theme.text(o,size,color);return o
end
function Lobby.new(parent,uid,command)
    local self=setmetatable({uid=tostring(uid),command=command,selected=1,room=nil,state=nil},Lobby)
    local gui=make('ScreenGui',parent,'LobbyRoomPicker',{Enabled=true,ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=45,ZIndexBehavior=Enum.ZIndexBehavior.Sibling});self.gui=gui
    -- host room picker -----------------------------------------------------------
    local card=make('Frame',gui,'Card',{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.55),Size=UDim2.fromOffset(380,262),Visible=false,Active=true})
    Theme.skin(card,C.Panel);self.card=card;self.scale=make('UIScale',card)
    local ribbon=make('Frame',card,'Ribbon',{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,0,0),Size=UDim2.fromOffset(250,40),ZIndex=6});Theme.skin(ribbon,ROOM_COLORS[1]);self.ribbon=ribbon
    self.fleet=text(ribbon,'Room','ROOM 1',20,C.White,{Size=UDim2.fromScale(1,1),ZIndex=8})
    text(card,'Title','CREATE ROOM',22,C.Gold,{Position=UDim2.fromOffset(18,30),Size=UDim2.new(1,-36,0,28),ZIndex=5})
    text(card,'Question','HOW MANY PLAYERS?',13,C.Muted,{Position=UDim2.fromOffset(18,58),Size=UDim2.new(1,-36,0,18),ZIndex=5})
    local function button(name,label,x,y,w,h,color,size,fn)
        local b=make('TextButton',card,name,{Text=label,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),ZIndex=6});Theme.button(b,color,size);b.Activated:Connect(fn);return b
    end
    self.left=button('Previous','<',18,86,50,50,C.Blue,24,function() self.selected=math.max(1,self.selected-1);self:refresh() end)
    self.right=button('Next','>',312,86,50,50,C.Blue,24,function() self.selected=math.min(6,self.selected+1);self:refresh() end)
    local crew=make('Frame',card,'Crew',{BackgroundTransparency=1,Position=UDim2.fromOffset(76,86),Size=UDim2.fromOffset(228,50),ZIndex=5})
    self.figures={}
    for i=1,6 do
        local f=make('Frame',crew,'Player'..i,{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(0,19+(i-1)*38,1,0),Size=UDim2.fromOffset(24,34),ZIndex=6,BorderSizePixel=0})
        make('UICorner',f,'Round',{CornerRadius=UDim.new(0,4)})
        local head=make('Frame',f,'Head',{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,0,-2),Size=UDim2.fromOffset(16,14),ZIndex=6,BorderSizePixel=0})
        make('UICorner',head,'Round',{CornerRadius=UDim.new(0,4)})
        make('UIStroke',f,'Line',{Color=C.Ink,Thickness=2});make('UIStroke',head,'Line',{Color=C.Ink,Thickness=2})
        self.figures[i]={body=f,head=head}
    end
    self.amount=text(card,'PlayerCount','1 PLAYER',22,C.White,{Position=UDim2.fromOffset(18,142),Size=UDim2.new(1,-36,0,26),ZIndex=5})
    self.subtitle=text(card,'Subtitle','',13,C.Muted,{Position=UDim2.fromOffset(18,168),Size=UDim2.new(1,-36,0,18),ZIndex=5})
    self.create=button('Create','CREATE',18,196,212,50,C.Green,22,function()
        if self.room and card.Visible and not self.pending then
            self.pending=true;card.Visible=false
            command:FireServer(nil,'LobbyConfig',{room=self.room,capacity=self.selected})
        end
    end)
    button('Leave','LEAVE',240,196,122,50,C.Red,20,function() self:leave() end)
    -- status bar for everybody on board ---------------------------------------------
    -- [ ROOM n ] [ PLAYERS x/y        ] [ LEAVE ]
    --            [ STARTS IN 12s      ]
    local bar=make('Frame',gui,'Status',{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,68),Size=UDim2.fromOffset(BAR_W,58),Visible=false,Active=true})
    Theme.skin(bar,C.Panel);self.bar=bar;self.barScale=make('UIScale',bar)
    local chip=make('Frame',bar,'Chip',{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(118,42),ZIndex=5});Theme.skin(chip,ROOM_COLORS[1]);self.chip=chip
    self.chipText=text(chip,'Room','ROOM 1',17,C.White,{Size=UDim2.fromScale(1,1),ZIndex=7})
    self.barText=text(bar,'Text','PLAYERS 1/4',19,C.Gold,{Position=UDim2.fromOffset(134,7),Size=UDim2.new(1,-252,0,24),ZIndex=5})
    self.barSub=text(bar,'Sub','STARTS IN 15s',13,C.Muted,{Position=UDim2.fromOffset(134,32),Size=UDim2.new(1,-252,0,18),ZIndex=5})
    local leave=make('TextButton',bar,'Leave',{Text='LEAVE',Position=UDim2.new(1,-110,0,9),Size=UDim2.fromOffset(102,40),ZIndex=6});Theme.button(leave,C.Red,18)
    leave.Activated:Connect(function() self:leave() end)
    self.connection=RunService.Heartbeat:Connect(function()
        local c=Workspace.CurrentCamera;if not c then return end
        local v=c.ViewportSize
        if card.Visible then self.scale.Scale=math.max(.4,math.min(1,(v.X-28)/380,(v.Y-60)/262)) end
        if bar.Visible then self.barScale.Scale=math.max(.5,math.min(1,(v.X-20)/BAR_W)) end
    end)
    self:refresh();return self
end
function Lobby:leave()
    if not self.room then return end
    self.command:FireServer(nil,'LobbyLeave',{})
    self:hide()
end
function Lobby:refresh()
    local n=self.selected
    self.amount.Text=tostring(n)..(n==1 and ' PLAYER' or ' PLAYERS')
    self.subtitle.Text=n==1 and 'PLAY SOLO AGAINST 3 BOTS' or ('WAIT FOR '..tostring(n-1)..' MORE '..(n==2 and 'PLAYER' or 'PLAYERS'))
    self.left.BackgroundColor3=n>1 and C.Blue or C.Dark
    self.right.BackgroundColor3=n<6 and C.Blue or C.Dark
    for i,f in ipairs(self.figures) do
        local on=i<=n
        local colour=on and (i==1 and C.Gold or C.White) or C.Dark
        f.body.BackgroundColor3=colour;f.head.BackgroundColor3=on and Color3.fromRGB(255,221,160) or C.Dark
        f.body.BackgroundTransparency=on and 0 or .35;f.head.BackgroundTransparency=on and 0 or .35
    end
end
function Lobby:setRoom(id)
    local colour=ROOM_COLORS[id] or ROOM_COLORS[1]
    self.ribbon.BackgroundColor3=colour;self.chip.BackgroundColor3=colour
    self.fleet.Text='ROOM '..tostring(id or 1);self.chipText.Text='ROOM '..tostring(id or 1)
end
function Lobby:update(l,active,message)
    if l.left and self.room and self.room~=l.room then return end
    if l.left or active then self:hide();return end
    if self.room~=l.room then self.selected=1;self.pending=false;self.room=l.room;self:refresh() end
    self:setRoom(l.room)
    local choosing=l.host==self.uid and l.choosing==true and not self.pending
    if l.capacity then self.pending=false;choosing=false end
    if message and message~='CHOOSE' and message~='JOIN' then self.pending=false end
    if choosing and not self.card.Visible then
        self.card.Visible=true;self.scale.Scale=.8;UISound.play('open')
        TweenService:Create(self.scale,TweenInfo.new(.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
    elseif not choosing then self.card.Visible=false end
    self.bar.Visible=not choosing
    if l.capacity then
        local full=(l.count or 0)>=l.capacity
        self.barText.Text='PLAYERS '..tostring(l.count or 0)..'/'..tostring(l.capacity)
        self.barSub.Text=(full and 'FULL  -  STARTING IN ' or 'STARTS IN ')..tostring(l.remaining or 0)..'s'
    else
        self.barText.Text=l.host==self.uid and 'CHOOSE THE SIZE' or 'HOST IS CHOOSING'
        self.barSub.Text='HOW MANY PLAYERS?'
    end
end
function Lobby:hide() self.card.Visible=false;self.bar.Visible=false;self.room=nil;self.pending=false;self.selected=1;self:refresh() end
function Lobby:destroy() self.connection:Disconnect();self.gui:Destroy() end
return Lobby
