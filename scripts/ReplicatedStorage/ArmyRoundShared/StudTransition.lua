-- Diagonal stud-brick curtain with the title logo, used when a round loads
-- and when players return to the lobby (same look as the title screen).
local TweenService=game:GetService('TweenService')
local Workspace=game:GetService('Workspace')
local TextService=game:GetService('TextService')
local RunService=game:GetService('RunService')
local Theme=require(script.Parent.StudTheme)
local UISound=require(script.Parent.UISound)
local T={};T.__index=T
local STUD='rbxassetid://103855926983380'
local INK=Color3.fromRGB(34,27,20)
local PALETTE={Color3.fromRGB(52,158,216),Color3.fromRGB(64,192,29),Color3.fromRGB(226,35,31),Color3.fromRGB(255,204,58),
    Color3.fromRGB(147,72,213),Color3.fromRGB(255,140,40),Color3.fromRGB(0,190,214),Color3.fromRGB(240,80,150)}
local TITLE_FONT=Font.new("rbxasset://fonts/families/FredokaOne.json",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
local ROWS=9
function T.new(parent)
    local self=setmetatable({active=false,serial=0,letters={}},T)
    local gui=Instance.new('ScreenGui');gui.Name='StudTransition';gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=1900
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Enabled=false;gui.Parent=parent;self.gui=gui
    local rig=Instance.new('Frame');rig.Name='Rig';rig.BackgroundTransparency=1;rig.AnchorPoint=Vector2.new(.5,.5);rig.Position=UDim2.fromScale(.5,.5);rig.Rotation=-28;rig.Parent=gui;self.rig=rig
    self.rows={}
    for i=1,ROWS do
        local row=Instance.new('Frame');row.Name='Brick'..i;row.BorderSizePixel=0;row.BackgroundColor3=PALETTE[(i-1)%#PALETTE+1];row.ZIndex=2;row.Parent=rig
        local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(.5,0);corner.Parent=row
        local stroke=Instance.new('UIStroke');stroke.Color=INK;stroke.Thickness=3;stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Parent=row
        local tex=Instance.new('ImageLabel');tex.Name='Studs';tex.BackgroundTransparency=1;tex.Size=UDim2.fromScale(1,1);tex.Image=STUD;tex.ScaleType=Enum.ScaleType.Tile
        tex.TileSize=UDim2.fromOffset(34,34);tex.ImageTransparency=.72;tex.ZIndex=3;tex.Parent=row
        self.rows[i]=row
    end
    -- logo plate: small "BATTLE BUT WITH", big multicoloured "ADMIN PANEL"
    local plate=Instance.new('Frame');plate.Name='Plate';plate.AnchorPoint=Vector2.new(.5,.5);plate.Position=UDim2.fromScale(.5,.5);plate.Size=UDim2.fromOffset(620,210);plate.ZIndex=10;plate.Visible=false;plate.Parent=gui
    Theme.skin(plate,Color3.fromRGB(255,250,241));self.plate=plate
    local over=Instance.new('TextLabel');over.Name='Over';over.BackgroundTransparency=1;over.Position=UDim2.fromOffset(0,14);over.Size=UDim2.new(1,0,0,28);over.ZIndex=14
    over.FontFace=TITLE_FONT;over.TextSize=26;over.TextColor3=INK;over.Text='BATTLE  BUT  WITH';over.Parent=plate
    local word='ADMIN PANEL';local size=74;local widths={};local total=0
    for i=1,#word do
        local ch=word:sub(i,i);local w
        if ch==' ' then w=24 else
            local ok,dims=pcall(function() return TextService:GetTextSize(ch,size,Enum.Font.FredokaOne,Vector2.new(300,300)) end)
            w=(ok and dims.X or size*.62)+1
        end
        widths[i]=w;total+=w
    end
    local x=(620-total)/2;local n=0
    for i=1,#word do
        local ch=word:sub(i,i)
        if ch~=' ' then
            n+=1
            local colour=PALETTE[(n-1)%#PALETTE+1]
            local l=Instance.new('TextLabel');l.Name='L'..i;l.BackgroundTransparency=1;l.AnchorPoint=Vector2.new(.5,1);l.Position=UDim2.fromOffset(x+widths[i]/2,130)
            l.Size=UDim2.fromOffset(widths[i],size);l.FontFace=TITLE_FONT;l.TextSize=size;l.Text=ch;l.TextColor3=colour;l.ZIndex=14;l.Parent=plate
            local st=Instance.new('UIStroke');st.Color=INK;st.Thickness=5;st.Parent=l
            self.letters[#self.letters+1]={label=l,base=l.Position}
        end
        x+=widths[i]
    end
    local sub=Instance.new('TextLabel');sub.Name='Subtitle';sub.BackgroundTransparency=1;sub.Position=UDim2.fromOffset(10,140);sub.Size=UDim2.new(1,-20,0,26);sub.ZIndex=14;sub.Parent=plate
    Theme.text(sub,20,INK);self.sub=sub
    local hint=Instance.new('TextLabel');hint.Name='Hint';hint.BackgroundTransparency=1;hint.Position=UDim2.fromOffset(10,168);hint.Size=UDim2.new(1,-20,0,20);hint.ZIndex=14;hint.Parent=plate
    Theme.text(hint,13,Color3.fromRGB(110,96,84));self.hint=hint
    self.dots={}
    for i=1,4 do
        local d=Instance.new('Frame');d.BorderSizePixel=0;d.AnchorPoint=Vector2.new(.5,.5);d.Size=UDim2.fromOffset(16,12);d.Position=UDim2.new(.5,(i-2.5)*24,0,196)
        d.BackgroundColor3=PALETTE[i];d.ZIndex=15;d.Parent=plate
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
    self.scale.Scale=math.clamp(math.min((v.X-30)/620,(v.Y*.6)/210),.45,1.1)
end
local function place(row,x) row.Position=UDim2.fromOffset(x,row.Position.Y.Offset) end
-- Bricks sweep in from the right. Yields until the screen is covered.
function T:cover(title,subtitle,duration)
    self.serial+=1;local serial=self.serial
    duration=duration or .45
    self:layout();self.gui.Enabled=true;self.active=true;UISound.play('whoosh')
    self.sub.Text=title or '';self.hint.Text=subtitle or '';self.plate.Visible=false
    local d=self.width
    for i,row in ipairs(self.rows) do
        place(row,d*1.3)
        TweenService:Create(row,TweenInfo.new(duration,Enum.EasingStyle.Quart,Enum.EasingDirection.Out,0,false,(i-1)*.03),{Position=UDim2.fromOffset(-d*.12,row.Position.Y.Offset)}):Play()
    end
    task.wait(duration+ROWS*.03)
    if serial~=self.serial then return end
    self.plate.Visible=true
    local s=self.scale.Scale;self.scale.Scale=s*.8
    TweenService:Create(self.scale,TweenInfo.new(.25,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=s}):Play()
    task.spawn(function()
        local t=0
        while self.plate.Visible and serial==self.serial do
            t+=task.wait()
            for i,dot in ipairs(self.dots) do dot.Position=UDim2.new(.5,(i-2.5)*24,0,196-math.max(0,math.sin(t*6-i*.7))*8) end
            -- the letters hop one after another like the title screen
            for i,l in ipairs(self.letters) do
                l.label.Position=l.base-UDim2.fromOffset(0,math.max(0,math.sin(t*5-i*.55))*9)
            end
        end
    end)
end
-- Bricks continue to the left and uncover the world.
function T:reveal(duration)
    self.serial+=1;local serial=self.serial
    duration=duration or .6
    self.plate.Visible=false;UISound.play('whoosh')
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
