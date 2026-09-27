-- Small screen-space badges at the SIDE of each owned base, never above the roof.
-- They have no physical geometry, no mouse capture, and shrink when zooming out.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Workspace=game:GetService('Workspace')
local Theme=require(script.Parent.StudTheme)
local Badges={};Badges.__index=Badges
local function make(class,parent,name)local o=Instance.new(class);o.Name=name or class;o.Parent=parent;return o end
function Badges.new(parent)
    local self=setmetatable({entries={},cache={},roster={},bases={},enabled=false},Badges)
    local gui=make('ScreenGui',parent,'BaseAvatars');gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=8;gui.Enabled=false;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;self.gui=gui
    self.connection=RunService.RenderStepped:Connect(function()self:render()end);return self
end
function Badges:portrait(uid)
    if self.cache[uid]~=nil then return end
    self.cache[uid]=false
    local id=tonumber(uid);if not id or id<1 then return end
    task.spawn(function()
        for _=1,3 do
            local ok,image,ready=pcall(Players.GetUserThumbnailAsync,Players,id,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150)
            if ok and ready and type(image)=='string' and image~='' then self.cache[uid]=image;return end
            task.wait(1)
        end
    end)
end
function Badges:update(bases,roster)
    self.bases=bases or {};self.roster=roster or {};self.enabled=true;self.gui.Enabled=true
    for id,rec in pairs(self.entries) do if not self.bases[id] or not self.bases[id].owner then rec.frame:Destroy();self.entries[id]=nil end end
    for id,b in pairs(self.bases) do if b.owner then
        local person=self.roster[b.owner] or {};local rec=self.entries[id]
        if not rec then
            rec={};self.entries[id]=rec
            local frame=make('Frame',self.gui,'Base_'..id);frame.AnchorPoint=Vector2.new(.5,.5);frame.Size=UDim2.fromOffset(32,32);frame.Active=false;frame.ZIndex=2;rec.frame=frame
            Theme.skin(frame,Theme.Colors.Panel)
            local image=make('ImageLabel',frame,'Avatar');image.BackgroundTransparency=1;image.Position=UDim2.fromOffset(2,2);image.Size=UDim2.new(1,-4,1,-4);image.ZIndex=5;image.Active=false;rec.image=image
            local fallback=make('TextLabel',frame,'BotAvatar');fallback.BackgroundTransparency=1;fallback.Size=UDim2.fromScale(1,1);fallback.ZIndex=6;fallback.Active=false;Theme.text(fallback,13);rec.fallback=fallback
            local name=make('TextLabel',frame,'Name');name.BackgroundTransparency=.1;name.BackgroundColor3=Theme.Colors.Dark;name.AnchorPoint=Vector2.new(.5,1);name.Position=UDim2.new(.5,0,0,-4);name.Size=UDim2.fromOffset(150,22);name.ZIndex=8;name.Visible=false;Theme.text(name,12);rec.name=name
            frame.MouseEnter:Connect(function()name.Visible=true end);frame.MouseLeave:Connect(function()name.Visible=false end)
        end
        rec.owner=b.owner;rec.pos=Vector3.new(b.pos.x+5,b.pos.y+1.2,b.pos.z-4)
        local c=person.color or {};rec.frame.BackgroundColor3=Color3.fromRGB(c.r or 110,c.g or 110,c.b or 110)
        rec.name.Text=person.name or 'Player'
        rec.fallback.Text=person.isBot and ('B'..tostring((person.name or ''):match('%d+') or '?')) or (person.name or '?'):sub(1,1):upper()
        if not person.isBot then self:portrait(b.owner) end
    end end
end
function Badges:render()
    if not self.enabled then return end
    local camera=Workspace.CurrentCamera;if not camera then return end
    local height=math.abs(camera.CFrame.Position.Y-camera.Focus.Position.Y)
    local size=math.clamp(40-height*.10,24,36)
    for _,rec in pairs(self.entries) do
        local pos,onScreen=camera:WorldToViewportPoint(rec.pos)
        rec.frame.Visible=onScreen and pos.Z>0
        if rec.frame.Visible then rec.frame.Position=UDim2.fromOffset(pos.X,pos.Y);rec.frame.Size=UDim2.fromOffset(size,size) end
        local image=self.cache[rec.owner];rec.image.Visible=type(image)=='string';rec.fallback.Visible=not rec.image.Visible
        if rec.image.Visible then rec.image.Image=image end
    end
end
function Badges:reset()
    self.enabled=false;self.gui.Enabled=false;self.bases={}
    for id,rec in pairs(self.entries) do rec.frame:Destroy();self.entries[id]=nil end
end
function Badges:destroy()self:reset();self.connection:Disconnect();self.gui:Destroy()end
return Badges
