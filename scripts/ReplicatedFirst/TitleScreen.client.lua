-- Title screen / loading intro. Runs from ReplicatedFirst, so it is on screen
-- before the rest of the game has replicated. Self-contained on purpose.
local ReplicatedFirst=game:GetService("ReplicatedFirst")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local ContentProvider=game:GetService("ContentProvider")
local TextService=game:GetService("TextService")
local StarterGui=game:GetService("StarterGui")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)
player:SetAttribute("IntroActive",true)
local playerGui=player:WaitForChild("PlayerGui")
local function core(enabled) pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,enabled) end) end
core(false)

local STUD="rbxassetid://103855926983380"
local INK=Color3.fromRGB(34,27,20)
local PAPER=Color3.fromRGB(255,250,241)
local PALETTE={
    blue=Color3.fromRGB(52,158,216),cyan=Color3.fromRGB(0,190,214),gold=Color3.fromRGB(255,204,58),green=Color3.fromRGB(64,192,29),
    purple=Color3.fromRGB(147,72,213),red=Color3.fromRGB(226,35,31),orange=Color3.fromRGB(255,140,40),pink=Color3.fromRGB(240,80,150),
}
local LETTER_COLORS={PALETTE.blue,PALETTE.green,PALETTE.red,PALETTE.gold,PALETTE.purple,PALETTE.orange,PALETTE.cyan,PALETTE.pink}
local TITLE_FONT=Font.new("rbxasset://fonts/families/FredokaOne.json",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
local SMALL_FONT=Font.new("rbxasset://fonts/families/LegacyArial.json",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
local function make(class,parent,name,props)
    local o=Instance.new(class);o.Name=name or class
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent;return o
end
local function tween(o,t,props,style,dir,delay)
    local tw=TweenService:Create(o,TweenInfo.new(t,style or Enum.EasingStyle.Quart,dir or Enum.EasingDirection.Out,0,false,delay or 0),props);tw:Play();return tw
end
local function viewport() local c=Workspace.CurrentCamera;return c and c.ViewportSize or Vector2.new(1280,720) end

local gui=make("ScreenGui",playerGui,"TitleScreen",{ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=5000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local paper=make("Frame",gui,"Paper",{Size=UDim2.fromScale(1,1),BackgroundColor3=PAPER,BorderSizePixel=0,ZIndex=1})
make("UIGradient",paper,"Tint",{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(255,236,214))})
make("ImageLabel",paper,"Studs",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=STUD,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(56,56),ImageTransparency=.94,ZIndex=1})

-- ---------------------------------------------------------------- diagonal stud bricks
local rig=make("Frame",gui,"Bricks",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Rotation=-57,ZIndex=2})
-- lane: distance across the diagonal (-1..1), rest: along the diagonal (-1..1), len: length, w: thickness
local BAR_DEFS={
    {lane=-.98,rest=-.55,len=1.10,w=.090,c=PALETTE.gold},{lane=-.86,rest=-.20,len=.95,w=.075,c=PALETTE.cyan},
    {lane=-.76,rest=-.62,len=.80,w=.105,c=PALETTE.purple},{lane=-.64,rest=-.15,len=.70,w=.062,c=PALETTE.blue},
    {lane=-.55,rest=-.85,len=.55,w=.080,c=PALETTE.cyan},{lane=-.44,rest=-.72,len=.42,w=.058,c=PALETTE.blue},
    {lane=.42,rest=.70,len=.45,w=.060,c=PALETTE.gold},{lane=.52,rest=.30,len=.75,w=.085,c=PALETTE.purple},
    {lane=.64,rest=.82,len=.60,w=.070,c=PALETTE.pink},{lane=.73,rest=.10,len=.95,w=.110,c=PALETTE.red},
    {lane=.86,rest=.62,len=.85,w=.080,c=PALETTE.orange},{lane=.97,rest=.05,len=1.10,w=.095,c=PALETTE.red},
    {lane=.30,rest=1.05,len=.30,w=.045,c=PALETTE.green},{lane=-.30,rest=-1.05,len=.30,w=.045,c=PALETTE.green},
}
local bars={}
local function newBar(def,index)
    local bar=make("Frame",rig,"Brick"..index,{BackgroundColor3=def.c,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),ZIndex=3})
    make("UICorner",bar,"Round",{CornerRadius=UDim.new(.5,0)})
    make("UIStroke",bar,"Line",{Color=INK,Thickness=3,Transparency=.1})
    make("UIGradient",bar,"Shade",{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(205,205,205))})
    make("ImageLabel",bar,"Studs",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=STUD,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(30,30),ImageTransparency=.7,ZIndex=4})
    -- the glossy highlight stripe that makes each brick read as plastic
    local gloss=make("Frame",bar,"Gloss",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.55,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,.14,0),Size=UDim2.new(.86,0,.16,0),ZIndex=5})
    make("UICorner",gloss,"Round",{CornerRadius=UDim.new(.5,0)})
    return {frame=bar,def=def,offset=0,seed=index*1.37}
end
for i,def in ipairs(BAR_DEFS) do bars[i]=newBar(def,i) end
local D=1000
local function layoutBars()
    local v=viewport();D=math.sqrt(v.X*v.X+v.Y*v.Y)
    rig.Size=UDim2.fromOffset(D,D)
    for _,b in ipairs(bars) do
        local def=b.def
        b.frame.Size=UDim2.fromOffset(def.len*D*.5,math.max(22,def.w*D*.5))
    end
end
local function barPosition(b,extra)
    -- rig X runs along the bricks, rig Y across them
    return UDim2.fromOffset(D*.5+(b.def.rest*.5)*D+b.offset+(extra or 0),D*.5+(b.def.lane*.5)*D)
end

-- ---------------------------------------------------------------- logo: stud "app icon" with a 3D crown
local logo=make("Frame",gui,"Logo",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.44),Size=UDim2.fromOffset(820,260),ZIndex=10})
local logoScale=make("UIScale",logo,"Fit")
local iconSlot=make("Frame",logo,"IconSlot",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(110,132),Size=UDim2.fromOffset(170,170),ZIndex=10})
local icon=make("Frame",iconSlot,"Icon",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),BackgroundColor3=PALETTE.purple,BorderSizePixel=0,ZIndex=11})
make("UICorner",icon,"Round",{CornerRadius=UDim.new(.22,0)})
make("UIStroke",icon,"Line",{Color=INK,Thickness=5})
make("UIGradient",icon,"Shade",{Rotation=120,Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(170,160,200))})
make("ImageLabel",icon,"Studs",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=STUD,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(34,34),ImageTransparency=.72,ZIndex=12})
local iconEdge=make("Frame",iconSlot,"Edge",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,9),Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(80,34,120),BorderSizePixel=0,ZIndex=10})
make("UICorner",iconEdge,"Round",{CornerRadius=UDim.new(.22,0)})
make("UIStroke",iconEdge,"Line",{Color=INK,Thickness=5})
local view=make("ViewportFrame",icon,"Crown3D",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.52),Size=UDim2.fromScale(1.15,1.15),ZIndex=14,
    Ambient=Color3.fromRGB(205,200,190),LightColor=Color3.fromRGB(255,246,229),LightDirection=Vector3.new(-1,-2,-2.5)})
local world=make("WorldModel",view,"World")
local crown=make("Model",world,"Crown")
do
    local GOLD=Color3.fromRGB(255,204,58)
    local function p(size,cf,colour,shape,material)
        local x=Instance.new("Part");x.Anchored=true;x.Size=size;x.CFrame=cf;x.Color=colour;x.Material=material or Enum.Material.SmoothPlastic
        if shape then x.Shape=shape end;x.TopSurface=Enum.SurfaceType.Smooth;x.BottomSurface=Enum.SurfaceType.Smooth;x.Parent=crown;return x
    end
    for k=0,11 do p(Vector3.new(.5,.55,.16),CFrame.Angles(0,k/12*math.pi*2,0)*CFrame.new(0,0,.86),GOLD) end
    local gems={Color3.fromRGB(255,60,70),Color3.fromRGB(70,160,255),Color3.fromRGB(80,220,110),Color3.fromRGB(190,90,255),Color3.fromRGB(255,150,40)}
    for k=0,4 do
        local a=CFrame.Angles(0,k/5*math.pi*2,0)
        p(Vector3.new(.34,.34,.34),a*CFrame.new(0,.44,.86)*CFrame.Angles(0,0,math.pi/4),GOLD)
        p(Vector3.new(.22,.22,.22),a*CFrame.new(0,.76,.86),Color3.fromRGB(250,250,244),Enum.PartType.Ball)
        p(Vector3.new(.24,.24,.24),a*CFrame.new(0,0,.95),gems[k+1],Enum.PartType.Ball,Enum.Material.Neon)
    end
    p(Vector3.new(.14,1.45,1.45),CFrame.new(0,-.26,0)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(150,30,40),Enum.PartType.Cylinder,Enum.Material.Fabric)
    crown.WorldPivot=CFrame.new()
    local cam=make("Camera",view,"Camera",{FieldOfView=30,CFrame=CFrame.lookAt(Vector3.new(0,1.6,4.6),Vector3.new(0,.1,0))})
    view.CurrentCamera=cam
end

-- title text: small line + big multi-coloured letters
local textBlock=make("Frame",logo,"Text",{BackgroundTransparency=1,Position=UDim2.fromOffset(222,0),Size=UDim2.new(1,-222,1,0),ZIndex=10})
local over=make("TextLabel",textBlock,"Over",{BackgroundTransparency=1,Position=UDim2.fromOffset(6,34),Size=UDim2.fromOffset(560,34),Text="BATTLE  BUT  WITH",
    FontFace=TITLE_FONT,TextSize=34,TextColor3=INK,TextXAlignment=Enum.TextXAlignment.Left,TextTransparency=1,ZIndex=12})
local overStroke=make("UIStroke",over,"Line",{Color=Color3.new(1,1,1),Thickness=3,Transparency=1})
local letters={}
local WORD="ADMIN PANEL"
do
    local x=0;local size=112
    for i=1,#WORD do
        local ch=WORD:sub(i,i)
        if ch==" " then x+=34 else
            local ok,dims=pcall(function() return TextService:GetTextSize(ch,size,Enum.Font.FredokaOne,Vector2.new(400,400)) end)
            local w=(ok and dims.X or size*.62)+2
            local holder=make("Frame",textBlock,"L"..i,{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,1),Position=UDim2.fromOffset(x+w/2,196),Size=UDim2.fromOffset(w,size),ZIndex=12})
            local scale=make("UIScale",holder,"Pop",{Scale=0})
            local colour=LETTER_COLORS[(#letters)%#LETTER_COLORS+1]
            local shadow=make("TextLabel",holder,"Shadow",{BackgroundTransparency=1,Position=UDim2.fromOffset(0,8),Size=UDim2.fromScale(1,1),Text=ch,FontFace=TITLE_FONT,TextSize=size,
                TextColor3=Color3.new(colour.R*.55,colour.G*.55,colour.B*.55),ZIndex=12})
            make("UIStroke",shadow,"Line",{Color=INK,Thickness=6})
            local face=make("TextLabel",holder,"Face",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Text=ch,FontFace=TITLE_FONT,TextSize=size,TextColor3=Color3.new(1,1,1),ZIndex=13})
            make("UIStroke",face,"Line",{Color=INK,Thickness=6})
            local shine=make("UIGradient",face,"Shine",{Rotation=20,Offset=Vector2.new(-1.2,0),Color=ColorSequence.new({
                ColorSequenceKeypoint.new(0,colour),ColorSequenceKeypoint.new(.44,colour),ColorSequenceKeypoint.new(.5,Color3.new(1,1,1)),
                ColorSequenceKeypoint.new(.56,colour),ColorSequenceKeypoint.new(1,colour)})})
            letters[#letters+1]={holder=holder,scale=scale,shine=shine,x=x+w/2,colour=colour}
            x+=w-2
        end
    end
    textBlock.Size=UDim2.fromOffset(x+20,260)
    logo.Size=UDim2.fromOffset(222+x+20,260)
end

-- loader that turns into "press any key"
local lower=make("Frame",gui,"Lower",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,.44,150),Size=UDim2.fromOffset(460,60),ZIndex=10})
local lowerScale=make("UIScale",lower,"Fit")
local track=make("Frame",lower,"Track",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(380,28),BackgroundColor3=Color3.fromRGB(58,50,40),BorderSizePixel=0,ZIndex=11,BackgroundTransparency=1})
make("UICorner",track,"Round",{CornerRadius=UDim.new(.5,0)})
local trackStroke=make("UIStroke",track,"Line",{Color=INK,Thickness=3,Transparency=1})
local fill=make("Frame",track,"Fill",{Size=UDim2.fromScale(0,1),BackgroundColor3=PALETTE.gold,BorderSizePixel=0,ZIndex=12,BackgroundTransparency=1})
make("UICorner",fill,"Round",{CornerRadius=UDim.new(.5,0)})
local fillStuds=make("ImageLabel",fill,"Studs",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=STUD,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(24,24),ImageTransparency=1,ZIndex=13})
local status=make("TextLabel",lower,"Status",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,1,-4),Size=UDim2.fromOffset(460,22),Text="",FontFace=SMALL_FONT,TextSize=15,TextColor3=INK,TextTransparency=1,ZIndex=12})
local pill=make("TextButton",lower,"Start",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(400,50),BackgroundColor3=Color3.new(1,1,1),AutoButtonColor=false,Text="",Visible=false,ZIndex=14})
make("UICorner",pill,"Round",{CornerRadius=UDim.new(.5,0)})
make("UIStroke",pill,"Line",{Color=INK,Thickness=3})
make("UIGradient",pill,"Shade",{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(226,226,232))})
local pillScale=make("UIScale",pill,"Pulse")
local pillText=make("TextLabel",pill,"Text",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Text=UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and "TAP TO START" or "PRESS ANY KEY TO START",
    FontFace=TITLE_FONT,TextSize=20,TextColor3=INK,ZIndex=16})
for i,side in ipairs({-1,1}) do
    local dot=make("Frame",pill,"Stud"..i,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(side<0 and 0 or 1,side*-22,.5,0),Size=UDim2.fromOffset(18,18),BackgroundColor3=side<0 and PALETTE.green or PALETTE.red,BorderSizePixel=0,ZIndex=16})
    make("UICorner",dot,"Round",{CornerRadius=UDim.new(1,0)});make("UIStroke",dot,"Line",{Color=INK,Thickness=2})
end
local credits=make("TextLabel",gui,"Credits",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-14),Size=UDim2.fromOffset(600,34),
    Text="HARBOUR UPDATE  -  v2.0\nBUILD  -  BATTLE  -  TYPE THE COMMAND",FontFace=SMALL_FONT,TextSize=13,TextColor3=INK,TextTransparency=1,ZIndex=12})

-- flash + confetti layers
local flash=make("Frame",gui,"Flash",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=40})
local confettiLayer=make("Frame",gui,"Confetti",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=30})
local function burst(at,colour,amount)
    for i=1,amount do
        local s=math.random(7,13)
        local bit=make("Frame",confettiLayer,"Bit",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(at.X,at.Y),Size=UDim2.fromOffset(s,s),
            BackgroundColor3=i%3==0 and colour or LETTER_COLORS[math.random(1,#LETTER_COLORS)],BorderSizePixel=0,Rotation=math.random(0,90),ZIndex=31})
        make("UICorner",bit,"Round",{CornerRadius=UDim.new(i%2==0 and 1 or .25,0)})
        make("UIStroke",bit,"Line",{Color=INK,Thickness=1.5})
        local a=math.random()*math.pi*2;local r=math.random(50,130)
        tween(bit,.7+math.random()*.4,{Position=UDim2.fromOffset(at.X+math.cos(a)*r,at.Y+math.sin(a)*r+30),Rotation=bit.Rotation+math.random(-200,200),BackgroundTransparency=1,Size=UDim2.fromOffset(2,2)},Enum.EasingStyle.Quad)
        task.delay(1.3,function() bit:Destroy() end)
    end
end

-- ---------------------------------------------------------------- brick wipe used for the exit
local wipe=make("Frame",gui,"Wipe",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Rotation=-28,ZIndex=50,Visible=false})
local wipeRows={}
for i=1,9 do
    local row=make("Frame",wipe,"Row"..i,{BackgroundColor3=LETTER_COLORS[(i-1)%#LETTER_COLORS+1],BorderSizePixel=0,ZIndex=51})
    make("UICorner",row,"Round",{CornerRadius=UDim.new(.5,0)});make("UIStroke",row,"Line",{Color=INK,Thickness=3})
    make("ImageLabel",row,"Studs",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=STUD,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(34,34),ImageTransparency=.72,ZIndex=52})
    wipeRows[i]=row
end

-- ---------------------------------------------------------------- layout
local function fit()
    local v=viewport()
    layoutBars()
    local s=math.clamp(math.min((v.X*.86)/logo.Size.X.Offset,(v.Y*.5)/260),.3,1)
    logoScale.Scale=s
    lower.Position=UDim2.new(.5,0,.44,130*s+18)
    lowerScale.Scale=math.clamp(s*1.05,.62,1.1)
end
fit()

-- ---------------------------------------------------------------- intro timeline
local started=os.clock()
local stage="intro"
local iconSpin=0      -- extra flip angle (degrees) animated on top of the idle wobble
local function spinIcon(duration)
    local t0=os.clock()
    task.spawn(function()
        while os.clock()-t0<duration do
            local k=(os.clock()-t0)/duration;iconSpin=360*(1-(1-k)^3);RunService.RenderStepped:Wait()
        end
        iconSpin=0
    end)
end
local function barsIn(delayBase,fast)
    for i,b in ipairs(bars) do
        local dir=b.def.lane<0 and -1 or 1
        b.frame.Position=barPosition(b,dir*D*1.2)
        tween(b.frame,fast and .5 or .9,{Position=barPosition(b)},Enum.EasingStyle.Back,Enum.EasingDirection.Out,delayBase+(i%7)*.06)
    end
end
local function barsOut(duration)
    for i,b in ipairs(bars) do
        local dir=b.def.lane<0 and -1 or 1
        tween(b.frame,duration,{Position=barPosition(b,dir*D*1.2)},Enum.EasingStyle.Quart,Enum.EasingDirection.In,(i%5)*.03)
    end
end
local function popLetters(delayBase)
    for i,l in ipairs(letters) do
        task.delay(delayBase+(i-1)*.075,function()
            l.holder.Rotation=-25
            tween(l.scale,.45,{Scale=1},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
            tween(l.holder,.45,{Rotation=0},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
            local abs=l.holder.AbsolutePosition+Vector2.new(l.holder.AbsoluteSize.X/2,-l.holder.AbsoluteSize.Y*.5)
            burst(abs,l.colour,7)
        end)
    end
end
local function shineLetters()
    for i,l in ipairs(letters) do
        l.shine.Offset=Vector2.new(-1.2,0)
        tween(l.shine,.55,{Offset=Vector2.new(1.2,0)},Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,(i-1)*.05)
    end
end
-- icon flies in with a spin
iconSlot.Position=UDim2.fromOffset(560,-260);iconSlot.Rotation=160
local iconScale=make("UIScale",iconSlot,"Pop",{Scale=.25})
barsIn(.05)
tween(iconSlot,.9,{Position=UDim2.fromOffset(110,132),Rotation=0},Enum.EasingStyle.Back,Enum.EasingDirection.Out,.45)
tween(iconScale,.9,{Scale=1},Enum.EasingStyle.Back,Enum.EasingDirection.Out,.45)
task.delay(.5,function() spinIcon(1.1) end)
task.delay(1.15,function()
    over.Position=UDim2.fromOffset(6,10)
    tween(over,.5,{TextTransparency=0,Position=UDim2.fromOffset(6,34)},Enum.EasingStyle.Back)
    tween(overStroke,.5,{Transparency=0})
end)
popLetters(1.25)
task.delay(1.25+#letters*.075+.3,shineLetters)
task.delay(2.2,function()
    tween(track,.35,{BackgroundTransparency=0});tween(trackStroke,.35,{Transparency=0})
    tween(fill,.35,{BackgroundTransparency=0});tween(fillStuds,.35,{ImageTransparency=.7})
    tween(status,.35,{TextTransparency=0});tween(credits,.6,{TextTransparency=.25})
end)

-- ---------------------------------------------------------------- loading progress (monotonic)
local shown,peakQueue=0,1
local function measure()
    local q=ContentProvider.RequestQueueSize
    peakQueue=math.max(peakQueue,q)
    local assets=1-q/peakQueue
    local loaded=game:IsLoaded() and 1 or 0
    local character=player.Character and player.Character:FindFirstChild("HumanoidRootPart") and 1 or 0
    return math.clamp(.45*loaded+.35*assets+.2*character,0,1)
end
task.spawn(function()
    pcall(function() ContentProvider:PreloadAsync({gui}) end)
end)

-- ---------------------------------------------------------------- ready / start / exit
local ready=false
local function becomeReady()
    if ready then return end;ready=true;stage="ready"
    tween(track,.25,{Size=UDim2.fromOffset(400,50),BackgroundTransparency=1});tween(trackStroke,.25,{Transparency=1})
    tween(fill,.2,{BackgroundTransparency=1});tween(fillStuds,.2,{ImageTransparency=1});tween(status,.2,{TextTransparency=1})
    task.delay(.2,function()
        pill.Visible=true;pillScale.Scale=.4
        tween(pillScale,.45,{Scale=1},Enum.EasingStyle.Back)
    end)
end
local finished=false
local function cinematicCamera()
    local camera=Workspace.CurrentCamera;if not camera then return end
    local character=player.Character or player.CharacterAdded:Wait()
    local root=character:WaitForChild("HumanoidRootPart",10);if not root then return end
    camera.CameraType=Enum.CameraType.Scriptable
    local look=root.CFrame.LookVector
    local from=CFrame.lookAt(root.Position+Vector3.new(0,55,0)-look*70+root.CFrame.RightVector*40,root.Position+look*60)
    local to=CFrame.lookAt(root.Position-look*14+Vector3.new(0,7,0),root.Position+look*8+Vector3.new(0,2,0))
    camera.CFrame=from
    return camera,from,to
end
local function exit()
    if finished or not ready then return end;finished=true;stage="exit"
    tween(pillScale,.12,{Scale=1.12},Enum.EasingStyle.Quad);task.delay(.12,function() tween(pillScale,.18,{Scale=.9}) end)
    for i,l in ipairs(letters) do
        task.delay((i-1)*.03,function()
            tween(l.holder,.16,{Position=l.holder.Position-UDim2.fromOffset(0,18)},Enum.EasingStyle.Quad)
            task.delay(.16,function() tween(l.holder,.22,{Position=l.holder.Position+UDim2.fromOffset(0,18)},Enum.EasingStyle.Bounce) end)
        end)
    end
    task.wait(.35)
    -- bricks sweep over everything
    local v=viewport();local d=math.sqrt(v.X*v.X+v.Y*v.Y)*1.15
    wipe.Size=UDim2.fromOffset(d,d);wipe.Visible=true
    local h=d/#wipeRows
    for i,row in ipairs(wipeRows) do
        row.Size=UDim2.fromOffset(d*1.25,h+6);row.Position=UDim2.fromOffset(d*1.3,(i-1)*h-3)
        tween(row,.5,{Position=UDim2.fromOffset(-d*.12,(i-1)*h-3)},Enum.EasingStyle.Quart,Enum.EasingDirection.Out,(i-1)*.035)
    end
    task.wait(.5+#wipeRows*.035)
    paper.Visible=false;rig.Visible=false;logo.Visible=false;lower.Visible=false;credits.Visible=false;confettiLayer.Visible=false
    local camera,from,to=cinematicCamera()
    core(true)
    player:SetAttribute("IntroActive",false)
    for i,row in ipairs(wipeRows) do
        tween(row,.6,{Position=UDim2.fromOffset(-d*1.45,(i-1)*h-3)},Enum.EasingStyle.Quart,Enum.EasingDirection.In,(i-1)*.03)
    end
    if camera then
        local t0=os.clock()
        while os.clock()-t0<1.6 do
            local k=(os.clock()-t0)/1.6;k=1-(1-k)^3
            camera.CFrame=from:Lerp(to,k);RunService.RenderStepped:Wait()
        end
        camera.CameraType=Enum.CameraType.Custom
        local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then camera.CameraSubject=humanoid end
    else
        task.wait(.9)
    end
    if frameConnection then frameConnection:Disconnect() end
    gui:Destroy()
end
pill.Activated:Connect(function() task.spawn(exit) end)
UserInputService.InputBegan:Connect(function(input)
    if not ready or finished then return end
    local t=input.UserInputType
    if t==Enum.UserInputType.Keyboard or t==Enum.UserInputType.MouseButton1 or t==Enum.UserInputType.Touch or t.Name:sub(1,7)=="Gamepad" then
        if input.KeyCode~=Enum.KeyCode.Unknown or t==Enum.UserInputType.MouseButton1 or t==Enum.UserInputType.Touch then task.spawn(exit) end
    end
end)

-- ---------------------------------------------------------------- per-frame animation
local nextShine,nextFlip,nextRefresh=5,6.5,11
local fitClock=0
local frameConnection
frameConnection=RunService.RenderStepped:Connect(function(dt)
    if not gui.Parent then frameConnection:Disconnect();return end
    local t=os.clock()-started
    fitClock+=dt;if fitClock>.5 then fitClock=0;fit() end
    -- bricks drift gently along their diagonal
    for _,b in ipairs(bars) do b.offset=math.sin(t*.6+b.seed)*12 end
    if stage~="intro" or t>2.2 then
        for _,b in ipairs(bars) do
            local playing=b.frame:GetAttribute("Busy")
            if not playing then b.frame.Position=barPosition(b) end
        end
    end
    -- the icon wobbles in fake 3D (width follows the cosine of its spin) and the crown turns for real
    local angle=math.rad(iconSpin+math.sin(t*1.1)*14)
    local c=math.cos(angle)
    icon.Size=UDim2.fromScale(math.max(.08,math.abs(c)),1)
    iconEdge.Size=UDim2.fromScale(math.max(.08,math.abs(c))+.02,1)
    iconEdge.Position=UDim2.new(.5,math.sin(angle)*10,.5,9)
    icon.BackgroundColor3=c>=0 and PALETTE.purple or Color3.fromRGB(96,40,150)
    view.Visible=c>0.15
    crown:PivotTo(CFrame.new(0,math.sin(t*2)*.05,0)*CFrame.Angles(0,t*.9,math.sin(t*1.3)*.08))
    -- ready: pill pulses; the loader shows real progress until then
    if stage=="intro" then
        local target=measure()
        shown=math.max(shown,shown+(target-shown)*math.min(1,dt*3))
        fill.Size=UDim2.fromScale(math.clamp(shown,.04,1),1)
        status.Text=("LOADING THE HARBOUR...  %d%%"):format(math.floor(shown*100+.5))
        if t>3.1 and target>=.98 and shown>.95 then fill.Size=UDim2.fromScale(1,1);becomeReady() end
        if t>25 then becomeReady() end
    elseif stage=="ready" then
        pillScale.Scale=pillScale.Scale+((1+math.sin(t*3.2)*.04)-pillScale.Scale)*math.min(1,dt*10)
    end
    if stage~="exit" then
        if t>nextShine then nextShine=t+4.5;shineLetters() end
        if t>nextFlip then nextFlip=t+7;spinIcon(1.2) end
        if t>nextRefresh and stage=="ready" then
            nextRefresh=t+12
            -- the reference-style refresh: a soft flash, bricks leave and come back
            flash.BackgroundTransparency=.35;tween(flash,.6,{BackgroundTransparency=1},Enum.EasingStyle.Quad)
            for _,b in ipairs(bars) do b.frame:SetAttribute("Busy",true) end
            barsOut(.35)
            task.delay(.45,function()
                barsIn(0,true)
                task.delay(1.1,function() for _,b in ipairs(bars) do b.frame:SetAttribute("Busy",nil) end end)
            end)
            popLetters(.25)
            for _,l in ipairs(letters) do l.scale.Scale=.6 end
        end
    end
end)
-- bricks are tweened during the intro; let the idle drift take over afterwards
for _,b in ipairs(bars) do b.frame:SetAttribute("Busy",true) end
task.delay(2.3,function() for _,b in ipairs(bars) do b.frame:SetAttribute("Busy",nil) end end)
