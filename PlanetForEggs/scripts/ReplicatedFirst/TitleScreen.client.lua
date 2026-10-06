--!nocheck
-- Title screen / loading intro (from "Battle but with Admin Panel", with our name and our planet
-- symbol instead of the crown). Runs from ReplicatedFirst.
-- 1. While the place loads only a quiet loading screen is shown (no music).
-- 2. Once everything is loaded and frames are smooth, the music starts and the
--    whole show is driven by the track's own clock (TimePosition), so every
--    hit lands exactly on the beat even if a frame is dropped.
local ReplicatedFirst=game:GetService("ReplicatedFirst")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local ContentProvider=game:GetService("ContentProvider")
local StarterGui=game:GetService("StarterGui")
local SoundService=game:GetService("SoundService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)
player:SetAttribute("IntroActive",true)
local playerGui=player:WaitForChild("PlayerGui")
local function core(enabled)
    pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,enabled) end)
    -- the game has its own egg hotbar: Roblox's default backpack stays off
    pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false) end)
    -- (v34) and our own Tab list replaces Roblox's player list (PlayerList.client)
    pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false) end)
end
core(false)
local logoModule=ReplicatedFirst:WaitForChild("TitleLogo",10)
if not logoModule then core(true);player:SetAttribute("IntroActive",false);return end
local TitleLogo=require(logoModule)

local STUD=TitleLogo.Stud
local INK=TitleLogo.Ink
local PAPER=Color3.fromRGB(255,250,241)
local PALETTE=TitleLogo.Palette
local LETTER_COLORS=TitleLogo.LetterColors
local TITLE_FONT=TitleLogo.Font
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
local backOut=TitleLogo.backOut
local function quintOut(u) u=math.clamp(u,0,1);return 1-(1-u)^5 end

-- ---------------------------------------------------------------- music timeline (measured from the track)
local MUSIC_ID=132472169476353
local HIT=.57                      -- opening hit
local WORD_TIMES={.77,.99,1.20}    -- the little roll after it: PLANET / FOR / (beat)
local ROLL_END=1.42
local LETTERS_START,LETTER_GAP=1.50,.075
local CROUCH=2.50                  -- the silence before the drop
local DROP=2.98                    -- the active part starts here
local BEAT=.46886                  -- 128 BPM, beat 0 = DROP
local TRACK_LENGTH=32.55

local gui=make("ScreenGui",playerGui,"TitleScreen",{ResetOnSpawn=false,IgnoreGuiInset=true,ScreenInsets=Enum.ScreenInsets.None,ClipToDeviceSafeArea=false,DisplayOrder=5000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local paper=make("Frame",gui,"Paper",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(1,400,1,400),BackgroundColor3=PAPER,BorderSizePixel=0,ZIndex=1})
make("UIGradient",paper,"Tint",{Rotation=90,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,236,214)),ColorSequenceKeypoint.new(.55,Color3.fromRGB(255,190,140)),ColorSequenceKeypoint.new(1,Color3.fromRGB(190,140,230))})})
make("ImageLabel",paper,"Studs",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=STUD,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(56,56),ImageTransparency=.94,ZIndex=1})

-- ---------------------------------------------------------------- (v29) Halloween: a crescent moon, jack-o'-lanterns in the corners, bats
local spooky=make("Frame",gui,"Halloween",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=2})
local moon=make("Frame",spooky,"Moon",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.84,.17),Size=UDim2.fromOffset(150,150),BackgroundColor3=Color3.fromRGB(255,244,200),BorderSizePixel=0,ZIndex=2})
make("UICorner",moon,"Round",{CornerRadius=UDim.new(1,0)});make("UIStroke",moon,"Line",{Color=INK,Thickness=3})
local bite=make("Frame",moon,"Bite",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.72,.38),Size=UDim2.fromScale(.86,.86),BackgroundColor3=Color3.fromRGB(255,214,170),BorderSizePixel=0,ZIndex=3})
make("UICorner",bite,"Round",{CornerRadius=UDim.new(1,0)})
local function jack(pos,size,rot)
    local p=make("Frame",spooky,"Pumpkin",{AnchorPoint=Vector2.new(.5,1),Position=pos,Size=UDim2.fromOffset(size,size*.78),Rotation=rot,BackgroundColor3=Color3.fromRGB(255,140,30),BorderSizePixel=0,ZIndex=4})
    make("UICorner",p,"Round",{CornerRadius=UDim.new(.42,0)});make("UIStroke",p,"Line",{Color=INK,Thickness=4})
    for _,x in ipairs({.33,.67}) do
        local rib=make("Frame",p,"Rib",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(x,.5),Size=UDim2.new(0,3,.9,0),BackgroundColor3=Color3.fromRGB(215,100,20),BorderSizePixel=0,ZIndex=5})
    end
    for _,x in ipairs({.3,.7}) do
        make("Frame",p,"Eye",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(x,.38),Size=UDim2.fromScale(.16,.2),Rotation=45,BackgroundColor3=Color3.fromRGB(255,236,110),BorderSizePixel=0,ZIndex=6})
    end
    make("Frame",p,"Mouth",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.7),Size=UDim2.fromScale(.56,.12),BackgroundColor3=Color3.fromRGB(255,236,110),BorderSizePixel=0,ZIndex=6})
    local stem=make("Frame",p,"Stem",{AnchorPoint=Vector2.new(.5,1),Position=UDim2.fromScale(.5,.04),Size=UDim2.fromScale(.12,.22),BackgroundColor3=Color3.fromRGB(90,140,50),BorderSizePixel=0,ZIndex=5})
    make("UIStroke",stem,"Line",{Color=INK,Thickness=3})
    return p
end
local jacks={jack(UDim2.new(0,90,1,-10),150,-6),jack(UDim2.new(0,200,1,-6),96,8),jack(UDim2.new(1,-100,1,-8),140,5),jack(UDim2.new(1,-215,1,-4),84,-9)}
local bats={}
for i=1,12 do
    local b=make("Frame",spooky,"Bat",{AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,Size=UDim2.fromOffset(60,30),ZIndex=3})
    local body=make("Frame",b,"Body",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(16,14),BackgroundColor3=Color3.fromRGB(40,24,56),BorderSizePixel=0,ZIndex=3})
    make("UICorner",body,"Round",{CornerRadius=UDim.new(.4,0)})
    for _,side in ipairs({-1,1}) do
        make("Frame",body,"Ear",{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,side*4,0,2),Size=UDim2.fromOffset(5,7),Rotation=side*12,BackgroundColor3=Color3.fromRGB(40,24,56),BorderSizePixel=0,ZIndex=3})
        make("Frame",body,"Eye",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,side*3,.4,0),Size=UDim2.fromOffset(3,3),BackgroundColor3=Color3.fromRGB(255,200,60),BorderSizePixel=0,ZIndex=4})
    end
    local wings={}
    for _,side in ipairs({-1,1}) do
        local w=make("Frame",b,"Wing",{AnchorPoint=Vector2.new(side<0 and 1 or 0,.5),Position=UDim2.new(.5,side*6,.5,0),Size=UDim2.fromOffset(24,10),BackgroundColor3=Color3.fromRGB(40,24,56),BorderSizePixel=0,ZIndex=3})
        make("UICorner",w,"Round",{CornerRadius=UDim.new(.5,0)})
        table.insert(wings,{frame=w,side=side})
    end
    bats[i]={frame=b,wings=wings,speed=.035+math.random()*.05,phase=math.random()*6.28,y=.08+math.random()*.62,scale=.6+math.random()*.9,dir=(i%2==0) and 1 or -1,x=math.random()}
    make("UIScale",b,"Size",{Scale=bats[i].scale})
end
local batClock=0
local function animateBats(dt)
    batClock+=dt
    for _,b in ipairs(bats) do
        b.x=(b.x+b.dir*b.speed*dt)%1.3
        local x=b.dir>0 and b.x-.15 or 1.15-b.x
        b.frame.Position=UDim2.fromScale(x,b.y+math.sin(batClock*1.6+b.phase)*.035)
        b.frame.Rotation=math.sin(batClock*2+b.phase)*8
        local flap=math.sin(batClock*14+b.phase)
        for _,w in ipairs(b.wings) do w.frame.Rotation=w.side*flap*28;w.frame.Size=UDim2.fromOffset(24,8+math.abs(flap)*6) end
    end
    moon.Rotation=math.sin(batClock*.4)*3
    for i,j in ipairs(jacks) do
        local eye=j:FindFirstChild("Eye")
        for _,c in ipairs(j:GetChildren()) do
            if c.Name=="Eye" or c.Name=="Mouth" then c.BackgroundColor3=Color3.fromRGB(255,220+math.floor(35*math.sin(batClock*7+i)),90+math.floor(40*math.sin(batClock*5+i))) end
        end
    end
end

-- ---------------------------------------------------------------- loading screen (before the show)
local waiting=make("Frame",gui,"Loading",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(220,80),ZIndex=20})
local waitDots={}
for i=1,4 do
    local d=make("Frame",waiting,"Stud"..i,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,(i-2.5)*34,0,24),Size=UDim2.fromOffset(24,18),BackgroundColor3=LETTER_COLORS[i],BorderSizePixel=0,ZIndex=21})
    make("UICorner",d,"Round",{CornerRadius=UDim.new(0,5)});make("UIStroke",d,"Line",{Color=INK,Thickness=2.5})
    waitDots[i]=d
end
local waitText=make("TextLabel",waiting,"Text",{BackgroundTransparency=1,Position=UDim2.fromOffset(0,44),Size=UDim2.new(1,0,0,28),Text="LOADING",FontFace=TITLE_FONT,TextSize=24,TextColor3=INK,ZIndex=21})

-- ---------------------------------------------------------------- diagonal stud bricks at the sides
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
-- entry order: outside-in, alternating left and right, so the frame builds up evenly
local ENTRY_ORDER={12,1,10,3,11,2,8,4,9,5,7,6,13,14}
local bars={}
for i,def in ipairs(BAR_DEFS) do
    local bar=make("Frame",rig,"Brick"..i,{BackgroundColor3=def.c,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),ZIndex=3})
    make("UICorner",bar,"Round",{CornerRadius=UDim.new(.5,0)})
    make("UIStroke",bar,"Line",{Color=INK,Thickness=3,Transparency=.1})
    make("UIGradient",bar,"Shade",{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(205,205,205))})
    make("ImageLabel",bar,"Studs",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=STUD,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(30,30),ImageTransparency=.7,ZIndex=4})
    local gloss=make("Frame",bar,"Gloss",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.55,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,.14,0),Size=UDim2.new(.86,0,.16,0),ZIndex=5})
    make("UICorner",gloss,"Round",{CornerRadius=UDim.new(.5,0)})
    bars[i]={frame=bar,def=def,seed=i*1.37,dir=def.lane<0 and -1 or 1,entry=.05}
end
for rank,index in ipairs(ENTRY_ORDER) do bars[index].entry=.05+(rank-1)*.07 end
local D=1000
local function layoutBars()
    local v=viewport();D=math.sqrt(v.X*v.X+v.Y*v.Y)
    rig.Size=UDim2.fromOffset(D,D)
    for _,b in ipairs(bars) do b.frame.Size=UDim2.fromOffset(b.def.len*D*.5,math.max(22,b.def.w*D*.5)) end
end
local function placeBar(b,offset)
    -- rig X runs along the bricks, rig Y across them
    b.frame.Position=UDim2.fromOffset(D*.5+(b.def.rest*.5)*D+offset,D*.5+(b.def.lane*.5)*D)
end
rig.Visible=false

-- ---------------------------------------------------------------- logo + particles
local particles=make("Frame",gui,"Particles",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=30})
local logo=TitleLogo.new(gui,particles,{zindex=10,position=UDim2.fromScale(.5,.44),particleZ=31})
logo.frame.Visible=false
local LETTERS=logo:count()

-- loader that turns into "press any key"
local lower=make("Frame",gui,"Lower",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,.44,150),Size=UDim2.fromOffset(460,60),ZIndex=10})
local lowerScale=make("UIScale",lower,"Fit")
local pill=make("TextButton",lower,"Start",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(400,50),BackgroundColor3=Color3.new(1,1,1),AutoButtonColor=false,Text="",Visible=false,ZIndex=14})
make("UICorner",pill,"Round",{CornerRadius=UDim.new(.5,0)})
make("UIStroke",pill,"Line",{Color=INK,Thickness=3})
make("UIGradient",pill,"Shade",{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(226,226,232))})
local pillScale=make("UIScale",pill,"Pulse")
make("TextLabel",pill,"Text",{BackgroundTransparency=1,Position=UDim2.fromOffset(48,0),Size=UDim2.new(1,-96,1,0),Text=UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and "TAP TO START" or "PRESS ANY KEY TO START",
    FontFace=TITLE_FONT,TextSize=20,TextScaled=true,TextColor3=INK,ZIndex=16})
make("UITextSizeConstraint",pill:FindFirstChild("Text"),"Fit",{MaxTextSize=20,MinTextSize=10})
for i,side in ipairs({-1,1}) do
    local dot=make("Frame",pill,"Stud"..i,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(side<0 and 0 or 1,side*-22,.5,0),Size=UDim2.fromOffset(18,18),BackgroundColor3=side<0 and PALETTE.green or PALETTE.red,BorderSizePixel=0,ZIndex=16})
    make("UICorner",dot,"Round",{CornerRadius=UDim.new(1,0)});make("UIStroke",dot,"Line",{Color=INK,Thickness=2})
end
local credits=make("TextLabel",gui,"Credits",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-14),Size=UDim2.fromOffset(300,18),
    Text="PLANET FOR EGGS  -  HALLOWEEN UPDATE",FontFace=SMALL_FONT,TextSize=13,TextColor3=INK,TextTransparency=1,ZIndex=12})
local flash=make("Frame",gui,"Flash",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=40})

-- ---------------------------------------------------------------- brick wipe used for the exit
local wipe=make("Frame",gui,"Wipe",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Rotation=-28,ZIndex=50,Visible=false})
local wipeRows={}
for i=1,9 do
    local row=make("Frame",wipe,"Row"..i,{BackgroundColor3=LETTER_COLORS[(i-1)%#LETTER_COLORS+1],BorderSizePixel=0,ZIndex=51})
    make("UICorner",row,"Round",{CornerRadius=UDim.new(.5,0)});make("UIStroke",row,"Line",{Color=INK,Thickness=3})
    make("ImageLabel",row,"Studs",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=STUD,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(34,34),ImageTransparency=.72,ZIndex=52})
    wipeRows[i]=row
end

local function fit()
    local v=viewport()
    layoutBars()
    local s=logo:fit(v,.86,.5,1)
    lower.Position=UDim2.new(.5,0,.44,141*s+16)
    lowerScale.Scale=math.clamp(s*1.05,.62,1.1)
end
fit()

-- ---------------------------------------------------------------- music + clock
local music=Instance.new("Sound");music.Name="TitleMusic";music.Looped=true;music.Volume=.7
if MUSIC_ID>0 then music.SoundId="rbxassetid://"..MUSIC_ID end
music.Parent=SoundService
local clockMode,playStart,silentStart,loops,lastPos,lastTime="idle",0,0,0,0,0
local function startClock()
    playStart=os.clock()
    if MUSIC_ID>0 then music.TimePosition=0;music:Play();clockMode="wait" else clockMode="silent";silentStart=os.clock() end
end
local function songTime()
    if clockMode=="idle" then return -1 end
    if clockMode=="wait" then
        if music.IsPlaying and music.TimePosition>0 then clockMode="music"
        elseif os.clock()-playStart>1.5 then clockMode="silent";silentStart=playStart end   -- audio blocked: same show, silently
        if clockMode=="wait" then return 0 end
    end
    if clockMode=="music" then
        if not music.IsPlaying then clockMode="silent";silentStart=os.clock()-lastTime;return lastTime end
        local pos=music.TimePosition
        if pos+1<lastPos then loops+=1 end
        lastPos=pos;lastTime=pos+loops*math.max(music.TimeLength,5)
        return lastTime
    end
    lastTime=os.clock()-silentStart;return lastTime
end
local function trackLength() return (clockMode=="music" and music.TimeLength>5) and music.TimeLength or TRACK_LENGTH end

-- ---------------------------------------------------------------- choreography (pure function of song time)
--  0.57 hit      PLANET slams in letter by letter
--  0.77          the planet icon flies in
--  0.99          the [FOR] tag pops
--  1.50 - 1.80   EGGS letters pop one by one
--  2.50          silence: everything crouches and trembles
--  2.98 drop     everything jumps; from now on EGGS hops on the beat
--                and PLANET answers on the off-beat, confetti on every landing
local TOP_GAP=.035
local TAG_TIMES={.99,1.20}
local function hop(L,start,amp,dur)
    local u=(L-start)/dur
    if u>=0 and u<1 then return amp*math.sin(math.pi*u),amp end
    return 0,0
end
local function crouch(L,i)
    if L>=CROUCH and L<DROP then
        local u=(L-CROUCH)/(DROP-CROUCH)
        return -7*math.sin(u*math.pi/2),math.sin(L*70+i*1.7)*2*u
    end
    return 0,0
end
-- beat hops after the drop; offset 0 = on the beat, .5 = off-beat
local function beatHop(L,i,offset,big,small,first)
    local d=(i-1)*.022
    local k=math.floor((L-DROP-d-offset*BEAT)/BEAT)
    if k<0 then return 0,0 end
    local start=DROP+(k+offset)*BEAT+d
    local amp=(k==0 and offset==0) and big*1.6 or (k%4==0 and big or small)
    return hop(L,start,amp,(k==0 and offset==0) and .46 or .30)
end
local function mainState(i,L,first)
    local appear=LETTERS_START+(i-1)*LETTER_GAP
    if first and L<appear then return 0,0,-25,0 end
    local scale,rot=1,0
    if first and L<appear+.34 then local u=(L-appear)/.34;scale=backOut(u);rot=-25*(1-math.min(1,u*1.4)) end
    if L>=DROP then local lift,amp=beatHop(L,i,0,22,12,first);return lift,scale*(1+.0025*lift),rot,amp end
    local c,tr=crouch(L,i)
    if c~=0 then return c,scale,tr,0 end
    if not first then
        for _,t in ipairs({ROLL_END,WORD_TIMES[3],WORD_TIMES[2],WORD_TIMES[1]}) do
            if L>=t+(i-1)*.022 then local lift,amp=hop(L,t+(i-1)*.022,10,.3);return lift,scale,rot,amp end
        end
    end
    return 0,scale,rot,0
end
local function topState(i,L,first)
    local appear=HIT+(i-1)*TOP_GAP
    if first and L<appear then return 0,0,0,0 end
    local scale=1
    if first and L<appear+.22 then local u=(L-appear)/.22;scale=1+1.3*(1-u)^3 end   -- slams down from big
    if L>=DROP and L<DROP+.46+(i-1)*.022 then local lift,amp=hop(L,DROP+(i-1)*.022,36,.46);return lift,scale,0,amp end   -- the drop: both rows jump together
    if L>=DROP then local lift,amp=beatHop(L,i,.5,18,10,first);return lift,scale,0,amp end
    local c,tr=crouch(L,i+20)
    if c~=0 then return c,scale,tr,0 end
    local lift,amp=hop(L,ROLL_END+(i-1)*.03,12,.3)
    if lift==0 and not first then lift,amp=hop(L,HIT+(i-1)*.03,30,.36) end
    return lift,scale,0,amp
end
local function tagState(i,L,first)
    local t=TAG_TIMES[i]
    if first and L<t then return 0,0,0 end
    local scale,wob=1,0
    if first and L<t+.3 then local u=(L-t)/.3;scale=backOut(u);wob=18*(1-u) end
    if L>=DROP then local lift=beatHop(L,i,.5,14,8,first);return scale,lift,math.sin(L*9+i)*2 end
    local c=crouch(L,i+40);if c~=0 then return scale,c,0 end
    if not first then local lift=hop(L,t,10,.3);return scale,lift,wob end
    return scale,0,wob
end
local lastL=-1
local airborne,airTop,airTag,landed={},{},{},{}
local loaderShown,readyAt=false,nil
local function drive(song,dt)
    local len=trackLength()
    local first=song<len
    local L=song%len
    local function crossed(e) return (lastL<e and L>=e) or (L<lastL and (e<=L or e>lastL)) end
    if lastL>=0 then
        if crossed(HIT) then
            logo:shake(first and 9 or 6)
            if not first then flash.BackgroundTransparency=.6 end
        end
        if crossed(WORD_TIMES[1]) then logo:spinIcon(BEAT*3) end
        for i,t in ipairs(TAG_TIMES) do if crossed(t) then logo:burstTag(i,6,120) end end
        if crossed(DROP) then
            flash.BackgroundTransparency=.45
            logo:shine(.04);logo:shake(12)
            if not loaderShown then loaderShown=true;readyAt=os.clock()+.25 end
            tween(credits,.6,{TextTransparency=.25})
        end
        if L>=DROP and lastL>=DROP then
            local k0,k1=math.floor((lastL-DROP)/BEAT),math.floor((L-DROP)/BEAT)
            if k1>k0 and k1%16==0 then logo:spinIcon(BEAT*3);logo:shine(.04) end
        end
    end
    lastL=L
    flash.BackgroundTransparency=math.min(1,flash.BackgroundTransparency+dt*1.6)
    -- icon
    local iconAt=WORD_TIMES[1]
    if first and L<iconAt then logo:iconPose(0,0)
    elseif first and L<iconAt+.7 then local u=(L-iconAt)/.7;logo:iconPose(backOut(u),backOut(u))
    else
        local pulse=0
        if L>=DROP then local ph=((L-DROP)/BEAT)%1;pulse=.07*(1-ph)^3 end
        logo:iconPose(1,1+pulse)
    end
    -- PLANET
    for i=1,logo:countTop() do
        local lift,scale,rot,amp=topState(i,L,first)
        logo:poseTop(i,lift,scale,rot)
        if first and scale>0 and not landed[i] and L>=HIT+(i-1)*TOP_GAP+.2 then landed[i]=true;logo:burstTop(i,7,130) end
        if lift>2 and not airTop[i] then airTop[i]=amp
        elseif lift<=.5 and airTop[i] then local a=airTop[i];airTop[i]=nil;logo:burstTop(i,a>=16 and 4 or 2,110) end
    end
    -- [FOR]
    for i=1,2 do
        local scale,lift,rot=tagState(i,L,first)
        logo:tag(i,scale,lift,rot)
        if lift>2 and not airTag[i] then airTag[i]=true elseif lift<=.5 and airTag[i] then airTag[i]=nil;logo:burstTag(i,2,90) end
    end
    -- EGGS
    for i=1,LETTERS do
        local lift,scale,rot,amp=mainState(i,L,first)
        logo:pose(i,lift,scale,rot)
        local appear=LETTERS_START+(i-1)*LETTER_GAP
        if first and not landed[100+i] and L>=appear+.05 then landed[100+i]=true;logo:burst(i,7,130) end
        if lift>2 and not airborne[i] then airborne[i]=amp
        elseif lift<=.5 and airborne[i] then
            local a=airborne[i];airborne[i]=nil
            logo:burst(i,a>=30 and 7 or (a>=20 and 5 or 3),a>=30 and 150 or 115)
        end
    end
    -- bricks glide in one after another, punch on the drop, breathe on the beat
    rig.Visible=true
    local t=os.clock()
    for _,b in ipairs(bars) do
        local offset=math.sin(t*.6+b.seed)*12
        if first then offset+=b.dir*D*1.25*(1-quintOut((L-b.entry)/1.25)) end
        if L>=DROP then
            local u=(L-DROP)/.45
            if u<1 and first then offset-=b.dir*34*(1-u)^2 end
            local ph=((L-DROP)/BEAT)%4
            offset-=b.dir*9*math.max(0,1-ph*2.5)^2
        elseif not first and L>=HIT and L<HIT+.4 then
            offset-=b.dir*20*(1-(L-HIT)/.4)^2
        end
        placeBar(b,offset)
    end
end

-- ---------------------------------------------------------------- ready / start / exit
local stage="loading"
local ready=false
local function becomeReady()
    if ready then return end;ready=true;stage="ready"
    pill.Visible=true;pillScale.Scale=.4
    tween(pillScale,.45,{Scale=1},Enum.EasingStyle.Back)
end
local finished=false
local frameConnection
local function exit()
    if finished or not ready then return end;finished=true;stage="exit"
    tween(pillScale,.12,{Scale=1.12},Enum.EasingStyle.Quad);task.delay(.12,function() tween(pillScale,.18,{Scale=.9}) end)
    for i=1,LETTERS do logo:burst(i,4,150) end
    for i=1,logo:countTop() do logo:burstTop(i,4,150) end
    task.wait(.35)
    local v=viewport();local d=math.sqrt(v.X*v.X+v.Y*v.Y)*1.15
    wipe.Size=UDim2.fromOffset(d,d);wipe.Visible=true
    local h=d/#wipeRows
    for i,row in ipairs(wipeRows) do
        row.Size=UDim2.fromOffset(d*1.25,h+6);row.Position=UDim2.fromOffset(d*1.3,(i-1)*h-3)
        tween(row,.5,{Position=UDim2.fromOffset(-d*.12,(i-1)*h-3)},Enum.EasingStyle.Quart,Enum.EasingDirection.Out,(i-1)*.035)
    end
    task.wait(.5+#wipeRows*.035)
    paper.Visible=false;rig.Visible=false;logo.frame.Visible=false;lower.Visible=false;credits.Visible=false;particles.Visible=false
    core(true)
    player:SetAttribute("IntroActive",false)
    for i,row in ipairs(wipeRows) do
        tween(row,.6,{Position=UDim2.fromOffset(-d*1.45,(i-1)*h-3)},Enum.EasingStyle.Quart,Enum.EasingDirection.In,(i-1)*.03)
    end
    -- straight back to the player: no camera flight
    local fade=TweenService:Create(music,TweenInfo.new(1),{Volume=0});fade:Play()
    task.wait(.9)
    music:Destroy()
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

-- ---------------------------------------------------------------- per-frame
local fitClock,waitClock=0,0
local scriptStart=os.clock()
frameConnection=RunService.RenderStepped:Connect(function(dt)
    if not gui.Parent then frameConnection:Disconnect();return end
    -- failsafe: never trap the player behind the title
    if not ready and os.clock()-scriptStart>50 then
        if stage=="loading" then waiting.Visible=false;logo.frame.Visible=true;stage="intro";startClock() end
        becomeReady()
    end
    fitClock+=dt;if fitClock>.5 then fitClock=0;fit() end
    animateBats(dt)
    if stage=="loading" then
        waitClock+=dt
        for i,d in ipairs(waitDots) do d.Position=UDim2.new(.5,(i-2.5)*34,0,24-math.max(0,math.sin(waitClock*6-i*.8))*12) end
        return
    end
    logo:step(dt)
    local song=songTime()
    if song>=0 and stage~="exit" then drive(song,dt) end
    if stage=="intro" then
        local hasCharacter=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if readyAt and os.clock()>=readyAt and (hasCharacter or os.clock()-playStart>8) then becomeReady() end
    elseif stage=="ready" then
        local t=os.clock()
        pillScale.Scale=pillScale.Scale+((1+math.sin(t*3.2)*.04)-pillScale.Scale)*math.min(1,dt*10)
    end
end)

-- ---------------------------------------------------------------- wait for a smooth start, then play
task.spawn(function()
    local t0=os.clock()
    local preloaded=false
    task.spawn(function() pcall(function() ContentProvider:PreloadAsync({music,gui}) end);preloaded=true end)
    while not preloaded and os.clock()-t0<8 do task.wait() end
    while not game:IsLoaded() and os.clock()-t0<25 do task.wait() end
    -- the first seconds after loading stutter; start only once frames are steady
    local steady,t1=0,os.clock()
    while steady<15 and os.clock()-t1<4 do
        local dt=RunService.RenderStepped:Wait()
        if dt<1/35 then steady+=1 else steady=0 end
    end
    if finished or stage~="loading" or not gui.Parent then return end
    tween(waitText,.2,{TextTransparency=1})
    for _,d in ipairs(waitDots) do tween(d,.2,{BackgroundTransparency=1}) end
    task.delay(.2,function() waiting.Visible=false end)
    logo.frame.Visible=true
    for _,b in ipairs(bars) do placeBar(b,b.dir*D*1.3) end
    stage="intro"
    startClock()
end)
