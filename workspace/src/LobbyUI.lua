-- One private 1..6 player picker, with explicit Create. No permanent waiting modal.
local Theme=require(script.Parent.StudTheme)
local Workspace=game:GetService('Workspace')
local RunService=game:GetService('RunService')
local Lobby={};Lobby.__index=Lobby
local function make(class,parent,name)local o=Instance.new(class);o.Name=name or class;o.Parent=parent;return o end
function Lobby.new(parent,uid,command)
    local self=setmetatable({uid=tostring(uid),command=command,selected=1,room=nil},Lobby)
    local gui=make('ScreenGui',parent,'LobbyRoomPicker');gui.Enabled=false;gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=45;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;self.gui=gui
    local card=make('Frame',gui,'Card');card.AnchorPoint=Vector2.new(.5,.5);card.Position=UDim2.fromScale(.5,.5);card.Size=UDim2.fromOffset(340,210);Theme.skin(card,Theme.Colors.Panel);self.card=card;self.scale=make('UIScale',card)
    local title=make('TextLabel',card,'Title');title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(18,16);title.Size=UDim2.new(1,-36,0,28);title.Text='CREATE ROOM';title.ZIndex=5;Theme.text(title,22,Theme.Colors.Gold)
    local amount=make('TextLabel',card,'PlayerCount');amount.BackgroundTransparency=1;amount.Position=UDim2.fromOffset(78,62);amount.Size=UDim2.fromOffset(184,38);amount.ZIndex=5;Theme.text(amount,23);self.amount=amount
    local subtitle=make('TextLabel',card,'Subtitle');subtitle.BackgroundTransparency=1;subtitle.Position=UDim2.fromOffset(60,101);subtitle.Size=UDim2.fromOffset(220,22);subtitle.ZIndex=5;subtitle.TextXAlignment=Enum.TextXAlignment.Center;Theme.text(subtitle,12,Theme.Colors.Muted);self.subtitle=subtitle
    local function button(name,text,x,y,w,h,color,fn)
        local b=make('TextButton',card,name);b.Position=UDim2.fromOffset(x,y);b.Size=UDim2.fromOffset(w,h);b.Text=text;b.ZIndex=5;Theme.button(b,color,20);b.Activated:Connect(fn);return b
    end
    self.left=button('Previous','<',22,62,48,44,Theme.Colors.Blue,function()self.selected=math.max(1,self.selected-1);self:refresh()end)
    self.right=button('Next','>',270,62,48,44,Theme.Colors.Blue,function()self.selected=math.min(6,self.selected+1);self:refresh()end)
    self.create=button('Create','CREATE',22,144,296,44,Theme.Colors.Green,function()
        if self.room and self.gui.Enabled and not self.pending then
            self.pending=true;self.gui.Enabled=false;command:FireServer(nil,'LobbyConfig',{room=self.room,capacity=self.selected})
        end
    end)
    self.connection=RunService.Heartbeat:Connect(function()
        if self.gui.Enabled then local c=Workspace.CurrentCamera;if c then self.scale.Scale=math.max(.25,math.min(1,(c.ViewportSize.X-28)/340,(c.ViewportSize.Y-50)/210)) end end
    end)
    self:refresh();return self
end
function Lobby:refresh()
    self.amount.Text=tostring(self.selected)..(self.selected==1 and ' PLAYER' or ' PLAYERS')
    self.subtitle.Text=self.selected==1 and '(WITH BOTS)' or '(WAIT FOR PLAYERS)'
    self.left.Active=self.selected>1;self.right.Active=self.selected<6
    self.left.BackgroundColor3=self.selected>1 and Theme.Colors.Blue or Theme.Colors.Dark
    self.right.BackgroundColor3=self.selected<6 and Theme.Colors.Blue or Theme.Colors.Dark
end
function Lobby:update(l,active,message)
    if l.left and self.room and self.room~=l.room then return end
    if l.left or active then self:hide();return end
    if self.room~=l.room then self.selected=1;self.pending=false;self.room=l.room;self:refresh() end
    if l.capacity then self.pending=false;self.gui.Enabled=false;return end
    if message and message~='CHOOSE' and message~='JOIN' then self.pending=false end
    self.gui.Enabled=l.host==self.uid and l.choosing==true and not self.pending
end
function Lobby:hide()self.gui.Enabled=false;self.room=nil;self.pending=false;self.selected=1;self:refresh() end
function Lobby:destroy()self.connection:Disconnect();self.gui:Destroy()end
return Lobby
