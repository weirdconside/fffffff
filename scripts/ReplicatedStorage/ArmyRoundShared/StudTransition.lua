-- Diagonal stud-brick wipe used when a ship sets sail and when it returns.
local TweenService=game:GetService('TweenService')
local Workspace=game:GetService('Workspace')
local Theme=require(script.Parent.StudTheme)
local T={};T.__index=T
local STUD='rbxassetid://103855926983380'
local PALETTE={Color3.fromRGB(52,158,216),Color3.fromRGB(255,204,58),Color3.fromRGB(64,192,29),Color3.fromRGB(147,72,213),Color3.fromRGB(226,35,31),Color3.fromRGB(0,178,190),Color3.fromRGB(255,140,40)}
local ROWS=9
function T.new(parent)
    local self=setmetatable({active=false,serial=0},T)
    local gui=Instance.new('ScreenGui');gui.Name='StudTransition';gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=1900
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Enabled=false;gui.Parent=parent;self.gui=gui
    local rig=Instance.new('Frame');rig.Name='Rig';rig.BackgroundTransparency=1;rig.AnchorPoint=Vector2.new(.5,.5);rig.Position=UDim2.fromScale(.5,.5);rig.Rotation=-28;rig.Parent=gui;self.rig=rig
    self.rows={}
    for i=1,ROWS do
        local row=Instance.new('Frame');row.Name='Brick'..i;row.BorderSizePixel=0;row.BackgroundColor3=PALETTE[(i-1)%#PALETTE+1];row.ZIndex=2;row.Parent=rig
        local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(.5,0);corner.Parent=row
        local stroke=Instance.new('UIStroke');stroke.Color=Theme.Colors.Ink;stroke.Thickness=3;stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Parent=row
        local tex=Instance.new('ImageLabel');tex.Name='Studs';tex.BackgroundTransparency=1;tex.Size=UDim2.fromScale(1,1);tex.Image=STUD;tex.ScaleType=Enum.ScaleType.Tile
        tex.TileSize=UDim2.fromOffset(34,34);tex.ImageTransparency=.72;tex.ZIndex=3;tex.Parent=row
        self.rows[i]=row
    end
    local plate=Instance.new('Frame');plate.Name='Plate';plate.AnchorPoint=Vector2.new(.5,.5);plate.Position=UDim2.fromScale(.5,.5);plate.Size=UDim2.fromOffset(420,112);plate.ZIndex=10;plate.Visible=false;plate.Parent=gui
    Theme.skin(plate,Theme.Colors.Panel);self.plate=plate
    local title=Instance.new('TextLabel');title.Name='Title';title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(10,14);title.Size=UDim2.new(1,-20,0,40);title.ZIndex=12;title.Parent=plate
    Theme.text(title,30,Theme.Colors.Gold);self.title=title
    local sub=Instance.new('TextLabel');sub.Name='Subtitle';sub.BackgroundTransparency=1;sub.Position=UDim2.fromOffset(10,56);sub.Size=UDim2.new(1,-20,0,22);sub.ZIndex=12;sub.Parent=plate
    Theme.text(sub,15,Theme.Colors.White);self.sub=sub
    self.dots={}
    for i=1,4 do
        local d=Instance.new('Frame');d.BorderSizePixel=0;d.AnchorPoint=Vector2.new(.5,.5);d.Size=UDim2.fromOffset(16,12);d.Position=UDim2.new(.5,(i-2.5)*24,0,94)
        d.BackgroundColor3=PALETTE[i];d.ZIndex=13;d.Parent=plate
        local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,3);c.Parent=d
        self.dots[i]=d
    end
    self.scale=Instance.new('UIScale');self.scale.Parent=plate
    return self
end
function T:layout()
    local camera=Workspace.CurrentCamera;local v=camera and camera.ViewportSize or Vector2.new(1280,720)
    local d=math.sqrt(v.X*v.X+v.Y*v.Y)*1.15
    self.rig.Size=UDim2.fromOffset(d,d);self.width=d
    local h=d/ROWS
    for i,row in ipairs(self.rows) do row.Size=UDim2.fromOffset(d*1.25,h+6);row.Position=UDim2.fromOffset(0,(i-1)*h-3) end
    self.scale.Scale=math.clamp(v.X/900,.6,1.2)
end
local function place(row,x) row.Position=UDim2.fromOffset(x,row.Position.Y.Offset) end
-- Bricks sweep in from the right. Yields until the screen is covered.
function T:cover(title,subtitle,duration)
    self.serial+=1;local serial=self.serial
    duration=duration or .55
    self:layout();self.gui.Enabled=true;self.active=true
    self.title.Text=title or '';self.sub.Text=subtitle or '';self.plate.Visible=false
    local d=self.width
    for i,row in ipairs(self.rows) do
        place(row,d*1.3)
        TweenService:Create(row,TweenInfo.new(duration,Enum.EasingStyle.Quart,Enum.EasingDirection.Out,0,false,(i-1)*.035),{Position=UDim2.fromOffset(-d*.12,row.Position.Y.Offset)}):Play()
    end
    task.wait(duration+ROWS*.035)
    if serial~=self.serial then return end
    self.plate.Visible=true
    task.spawn(function()
        local t=0
        while self.plate.Visible and serial==self.serial do
            t+=task.wait()
            for i,dot in ipairs(self.dots) do dot.Position=UDim2.new(.5,(i-2.5)*24,0,94-math.max(0,math.sin(t*6-i*.7))*8) end
        end
    end)
end
-- Bricks continue to the left and uncover the world.
function T:reveal(duration)
    self.serial+=1;local serial=self.serial
    duration=duration or .6
    self.plate.Visible=false
    local d=self.width or 2000
    for i,row in ipairs(self.rows) do
        TweenService:Create(row,TweenInfo.new(duration,Enum.EasingStyle.Quart,Enum.EasingDirection.In,0,false,(i-1)*.03),{Position=UDim2.fromOffset(-d*1.45,row.Position.Y.Offset)}):Play()
    end
    task.delay(duration+ROWS*.03+.05,function()
        if serial==self.serial then self.gui.Enabled=false;self.active=false end
    end)
end
function T:isActive() return self.active end
return T
