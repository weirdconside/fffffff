-- Diagonal stud-brick curtain used when a round loads and when players return
-- to the lobby. Once the bricks cover the screen, the title screen's logo
-- (shared TitleLogo module) pops up in the middle and its letters hop.
local TweenService=game:GetService('TweenService')
local Workspace=game:GetService('Workspace')
local RunService=game:GetService('RunService')
local ReplicatedFirst=game:GetService('ReplicatedFirst')
local UISound=require(script.Parent.UISound)
local TitleLogo
do
    local m=ReplicatedFirst:FindFirstChild('TitleLogo') or ReplicatedFirst:WaitForChild('TitleLogo',5)
    if m then local ok,mod=pcall(require,m);if ok then TitleLogo=mod end end
end
local T={};T.__index=T
local STUD='rbxassetid://103855926983380'
local INK=Color3.fromRGB(34,27,20)
local PAPER=Color3.fromRGB(255,248,236)
-- outer rows are colourful, the middle band is paper like the title screen
local ROW_COLORS={Color3.fromRGB(52,158,216),Color3.fromRGB(226,35,31),PAPER,PAPER,PAPER,PAPER,PAPER,Color3.fromRGB(255,204,58),Color3.fromRGB(147,72,213)}
local ROWS=#ROW_COLORS
local BEAT=.46886
local SMALL_FONT=Font.new('rbxasset://fonts/families/FredokaOne.json',Enum.FontWeight.Bold,Enum.FontStyle.Normal)
function T.new(parent)
    local self=setmetatable({active=false,serial=0,shown=false,t=0},T)
    local gui=Instance.new('ScreenGui');gui.Name='StudTransition';gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.ScreenInsets=Enum.ScreenInsets.None;gui.ClipToDeviceSafeArea=false;gui.DisplayOrder=1900
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Enabled=false;gui.Parent=parent;self.gui=gui
    local rig=Instance.new('Frame');rig.Name='Rig';rig.BackgroundTransparency=1;rig.AnchorPoint=Vector2.new(.5,.5);rig.Position=UDim2.fromScale(.5,.5);rig.Rotation=-28;rig.Parent=gui;self.rig=rig
    self.rows={}
    for i=1,ROWS do
        local paper=ROW_COLORS[i]==PAPER
        local row=Instance.new('Frame');row.Name='Brick'..i;row.BorderSizePixel=0;row.BackgroundColor3=ROW_COLORS[i];row.ZIndex=2;row.Parent=rig
        local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(.5,0);corner.Parent=row
        local stroke=Instance.new('UIStroke');stroke.Color=INK;stroke.Thickness=3;stroke.Transparency=paper and .86 or 0;stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Parent=row
        local tex=Instance.new('ImageLabel');tex.Name='Studs';tex.BackgroundTransparency=1;tex.Size=UDim2.fromScale(1,1);tex.Image=STUD;tex.ScaleType=Enum.ScaleType.Tile
        tex.TileSize=UDim2.fromOffset(paper and 48 or 34,paper and 48 or 34);tex.ImageTransparency=paper and .93 or .72;tex.ZIndex=3;tex.Parent=row
        self.rows[i]=row
    end
    -- centre: the title logo with its hopping letters
    local stage=Instance.new('Frame');stage.Name='Stage';stage.BackgroundTransparency=1;stage.Size=UDim2.fromScale(1,1);stage.ZIndex=10;stage.Visible=false;stage.Parent=gui;self.stage=stage
    local particles=Instance.new('Frame');particles.Name='Particles';particles.BackgroundTransparency=1;particles.Size=UDim2.fromScale(1,1);particles.ZIndex=30;particles.Parent=stage
    if TitleLogo then
        self.logo=TitleLogo.new(stage,particles,{zindex=12,position=UDim2.fromScale(.5,.45),particleZ=31})
    end
    -- small status pill under the logo ("LOADING BATTLE...")
    local pill=Instance.new('Frame');pill.Name='Status';pill.AnchorPoint=Vector2.new(.5,0);pill.Size=UDim2.fromOffset(330,44);pill.BackgroundColor3=Color3.new(1,1,1);pill.ZIndex=20;pill.Parent=stage
    local pc=Instance.new('UICorner');pc.CornerRadius=UDim.new(.5,0);pc.Parent=pill
    local ps=Instance.new('UIStroke');ps.Color=INK;ps.Thickness=3;ps.Parent=pill
    local label=Instance.new('TextLabel');label.Name='Text';label.BackgroundTransparency=1;label.Position=UDim2.fromOffset(52,0);label.Size=UDim2.new(1,-104,1,0);label.ZIndex=22
    label.FontFace=SMALL_FONT;label.TextSize=20;label.TextColor3=INK;label.TextScaled=true;label.Text='';label.Parent=pill
    local lim=Instance.new('UITextSizeConstraint');lim.MaxTextSize=20;lim.MinTextSize=9;lim.Parent=label
    self.pill=pill;self.pillScale=Instance.new('UIScale');self.pillScale.Parent=pill;self.label=label
    self.dots={}
    for i=1,2 do
        local d=Instance.new('Frame');d.Name='Stud'..i;d.AnchorPoint=Vector2.new(.5,.5);d.Size=UDim2.fromOffset(16,16);d.BorderSizePixel=0;d.ZIndex=22
        d.BackgroundColor3=i==1 and Color3.fromRGB(64,192,29) or Color3.fromRGB(226,35,31);d.Parent=pill
        local c=Instance.new('UICorner');c.CornerRadius=UDim.new(1,0);c.Parent=d
        local s=Instance.new('UIStroke');s.Color=INK;s.Thickness=2;s.Parent=d
        self.dots[i]=d
    end
    -- round result: only the bricks and one big word (no logo)
    local resultStage=Instance.new('Frame');resultStage.Name='Result';resultStage.BackgroundTransparency=1;resultStage.Size=UDim2.fromScale(1,1);resultStage.ZIndex=10;resultStage.Visible=false;resultStage.Parent=gui
    local resultText=Instance.new('TextLabel');resultText.Name='Word';resultText.BackgroundTransparency=1;resultText.AnchorPoint=Vector2.new(.5,.5);resultText.Position=UDim2.fromScale(.5,.47)
    resultText.Size=UDim2.fromScale(.86,.3);resultText.FontFace=SMALL_FONT;resultText.TextScaled=true;resultText.ZIndex=14;resultText.Parent=resultStage
    local rs=Instance.new('UIStroke');rs.Color=INK;rs.Thickness=7;rs.Parent=resultText
    local rg=Instance.new('UIGradient');rg.Rotation=90;rg.Parent=resultText
    local shadow=resultText:Clone();shadow.Name='Shadow';shadow.ZIndex=13;shadow.Position=UDim2.new(.5,6,.47,8);shadow.TextColor3=INK;shadow.Parent=resultStage
    shadow:FindFirstChildOfClass('UIGradient'):Destroy()
    self.resultStage,self.resultText,self.resultShadow,self.resultGradient=resultStage,resultText,shadow,rg
    self.resultScale=Instance.new('UIScale');self.resultScale.Parent=resultStage
    self.connection=RunService.RenderStepped:Connect(function(dt)
        if self.shown then self:step(dt) end
        if resultStage.Visible then
            local t=os.clock()
            resultText.Rotation=math.sin(t*2.2)*3;shadow.Rotation=resultText.Rotation
            resultText.Position=UDim2.fromScale(.5,.47+math.sin(t*3)*.008);shadow.Position=UDim2.new(.5,6,.47+math.sin(t*3)*.008,8)
        end
    end)
    return self
end
function T:layout()
    local camera=Workspace.CurrentCamera;local v=camera and camera.ViewportSize or Vector2.new(1280,720)
    local d=math.sqrt(v.X*v.X+v.Y*v.Y)*1.15
    self.rig.Size=UDim2.fromOffset(d,d);self.width=d
    local h=d/ROWS
    for i,row in ipairs(self.rows) do row.Size=UDim2.fromOffset(d*1.25,h+6);row.Position=UDim2.fromOffset(row.Position.X.Offset,(i-1)*h-3) end
    local s=1
    if self.logo then s=self.logo:fit(v,.8,.42,.9) end
    self.pill.Position=UDim2.new(.5,0,.45,141*s+22)
    self.pillScale.Scale=math.clamp(s*1.1,.6,1)
end
-- BATTLE slams in, [BUT][WITH] pop, ADMIN PANEL cascades; then ADMIN PANEL hops
-- on the beat and BATTLE on the off-beat, each landing throwing confetti.
local function hopAt(t,start,amp,dur)
    local u=(t-start)/dur
    if u>=0 and u<1 then return amp*math.sin(math.pi*u) end
    return 0
end
function T:step(dt)
    self.t+=dt
    local t=self.t
    local logo=self.logo
    for i,d in ipairs(self.dots) do d.Position=UDim2.new(i==1 and 0 or 1,i==1 and 24 or -24,.5,-math.max(0,math.sin(t*7+i*1.6))*6) end
    if not logo then return end
    logo:step(dt)
    self.air=self.air or {};self.popped=self.popped or {}
    local nTop,nMain=logo:countTop(),logo:count()
    local beatStart=.05+nMain*.04+.45
    local function beat(i,offset,big,small)
        if t<beatStart then return 0 end
        local d=(i-1)*.025
        local k=math.floor((t-beatStart-d-offset*BEAT)/BEAT)
        if k<0 then return 0 end
        return hopAt(t,beatStart+(k+offset)*BEAT+d,k%4==0 and big or small,.3)
    end
    for i=1,nTop do
        local appear=(i-1)*.03
        local scale=0
        if t>=appear then local u=math.min(1,(t-appear)/.2);scale=1+1.2*(1-u)^3 end
        local lift=beat(i,.5,16,9)
        logo:poseTop(i,lift,scale,0)
        local key='t'..i
        if scale>0 and t>=appear+.18 and not self.popped[key] then self.popped[key]=true;logo:burstTop(i,5,120) end
        if lift>2 then self.air[key]=true elseif self.air[key] and lift<=.5 then self.air[key]=nil;logo:burstTop(i,2,100) end
    end
    for i=1,2 do
        local at=.2+i*.1
        local scale=t<at and 0 or TitleLogo.backOut((t-at)/.3)
        logo:tag(i,scale,beat(i,.5,10,6),t<at+.3 and 16*(1-(t-at)/.3) or 0)
        if t>=at and not self.popped['g'..i] then self.popped['g'..i]=true;logo:burstTag(i,5,110) end
    end
    for i=1,nMain do
        local appear=.3+(i-1)*.04
        local lift,scale,rot=0,1,0
        if t<appear then scale=0;rot=-25
        else
            local u=(t-appear)/.3
            if u<1 then scale=TitleLogo.backOut(u);rot=-25*(1-math.min(1,u*1.4)) end
            lift=beat(i,0,20,11)
        end
        logo:pose(i,lift,scale,rot)
        local key='m'..i
        if t>=appear+.05 and not self.popped[key] then self.popped[key]=true;logo:burst(i,5,120) end
        if lift>2 then self.air[key]=true elseif self.air[key] and lift<=.5 then self.air[key]=nil;logo:burst(i,3,110) end
    end
    local beatIndex=math.floor(t/(BEAT*4))
    if beatIndex~=self.lastShine then self.lastShine=beatIndex;logo:shine(.04) end
end
local function place(row,x) row.Position=UDim2.fromOffset(x,row.Position.Y.Offset) end
-- Bricks sweep in from the right. Yields until the screen is covered.
-- result: nil = logo (loading), 'win' / 'lose' = big result word, 'none' = bricks only
function T:cover(title,subtitle,duration,result)
    self.serial+=1;local serial=self.serial
    duration=duration or .45
    self:layout();self.gui.Enabled=true;self.active=true;UISound.play('whoosh')
    self.label.Text=title or ''
    self.stage.Visible=false;self.shown=false;self.resultStage.Visible=false
    local d=self.width
    for i,row in ipairs(self.rows) do
        place(row,d*1.3)
        TweenService:Create(row,TweenInfo.new(duration,Enum.EasingStyle.Quart,Enum.EasingDirection.Out,0,false,(i-1)*.03),{Position=UDim2.fromOffset(-d*.12,row.Position.Y.Offset)}):Play()
    end
    task.wait(duration+ROWS*.03)
    if serial~=self.serial then return end
    if result=='none' then return end
    if result=='win' or result=='lose' then
        local win=result=='win'
        local word=win and 'YOU WIN!' or 'YOU LOSE'
        self.resultText.Text=word;self.resultShadow.Text=word
        self.resultText.TextColor3=Color3.new(1,1,1)
        self.resultGradient.Color=win and ColorSequence.new(Color3.fromRGB(255,244,160),Color3.fromRGB(255,170,30))
            or ColorSequence.new(Color3.fromRGB(255,150,140),Color3.fromRGB(200,24,30))
        self.resultScale.Scale=0;self.resultStage.Visible=true
        TweenService:Create(self.resultScale,TweenInfo.new(.45,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
        return
    end
    -- logo in: every letter pops with a puff of stud bits
    self.t=0;self.popped={};self.air={};self.lastShine=nil
    if self.logo then
        self.logo:iconPose(1,0)
        for i=1,2 do self.logo:tag(i,0,0,0) end
        for i=1,self.logo:countTop() do self.logo:poseTop(i,0,0,0) end
        for i=1,self.logo:count() do self.logo:pose(i,0,0,-25) end
        self.logo:spinIcon(.9)
        local s=self.logo.iconScale;self.logo.iconSlot.Visible=true
        TweenService:Create(s,TweenInfo.new(.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
    end
    self.pillScale.Scale=self.pillScale.Scale*.6
    TweenService:Create(self.pillScale,TweenInfo.new(.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=math.clamp((self.logo and self.logo.fitScale.Scale or 1)*1.1,.6,1)}):Play()
    self.stage.Visible=true;self.shown=true
end
-- Bricks continue to the left and uncover the world.
function T:reveal(duration)
    self.serial+=1;local serial=self.serial
    duration=duration or .6
    self.stage.Visible=false;self.shown=false;self.resultStage.Visible=false;UISound.play('whoosh')
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
