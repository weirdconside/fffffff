-- Visuals for admin commands (meteors, ice, heal, summons, gold...). Purely cosmetic:
-- the server already applied the effect, this only shows it where it happened.
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local TweenService=game:GetService('TweenService')
local Debris=game:GetService('Debris')
local Workspace=game:GetService('Workspace')
local shared=ReplicatedStorage:WaitForChild('ArmyRoundShared')
local remote=shared:WaitForChild('AdminFX')
local folder=Instance.new('Folder');folder.Name='AdminFX';folder.Parent=Workspace
local rng=Random.new()
local function v3(p) return Vector3.new(p.x,p.y,p.z) end
local function part(props)
    local p=Instance.new('Part');p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
    p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
    for k,v in pairs(props) do p[k]=v end
    p.Parent=folder;return p
end
local function tween(o,t,goal,style) local tw=TweenService:Create(o,TweenInfo.new(t,style or Enum.EasingStyle.Quad,Enum.EasingDirection.Out),goal);tw:Play();return tw end
local function burst(at,color,count,speed,life,size)
    local anchor=part({Transparency=1,Size=Vector3.new(.2,.2,.2),Position=at})
    local e=Instance.new('ParticleEmitter');e.Color=ColorSequence.new(color);e.LightEmission=.8
    e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size or .8),NumberSequenceKeypoint.new(1,0)})
    e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})
    e.Lifetime=NumberRange.new(life*.6,life);e.Speed=NumberRange.new(speed*.5,speed);e.SpreadAngle=Vector2.new(180,180)
    e.Rate=0;e.Parent=anchor;e:Emit(count)
    Debris:AddItem(anchor,life+.2)
end
local function pillar(at,color,height,time)
    local p=part({Shape=Enum.PartType.Cylinder,Material=Enum.Material.Neon,Color=color,Transparency=.35,
        Size=Vector3.new(height,3,3),CFrame=CFrame.new(at+Vector3.new(0,height/2,0))*CFrame.Angles(0,0,math.rad(90))})
    tween(p,time,{Transparency=1,Size=Vector3.new(height,.2,.2)})
    Debris:AddItem(p,time+.1)
end
local FX={}
FX.meteor=function(at,info,delay)
    task.wait(delay)
    local from=at+Vector3.new(rng:NextNumber(-18,18),70,rng:NextNumber(-18,18))
    local rock=part({Shape=Enum.PartType.Ball,Material=Enum.Material.Neon,Color=Color3.fromRGB(255,120,30),Size=Vector3.new(2.6,2.6,2.6),Position=from})
    local fire=Instance.new('Fire');fire.Size=7;fire.Heat=0;fire.Color=Color3.fromRGB(255,140,40);fire.SecondaryColor=Color3.fromRGB(255,60,20);fire.Parent=rock
    local a0=Instance.new('Attachment');a0.Position=Vector3.new(0,1,0);a0.Parent=rock
    local a1=Instance.new('Attachment');a1.Position=Vector3.new(0,-1,0);a1.Parent=rock
    local trail=Instance.new('Trail');trail.Attachment0=a0;trail.Attachment1=a1;trail.Lifetime=.35;trail.LightEmission=1
    trail.Color=ColorSequence.new(Color3.fromRGB(255,200,80),Color3.fromRGB(255,60,20));trail.Parent=rock
    tween(rock,.75,{Position=at},Enum.EasingStyle.Quad).Completed:Wait()
    rock:Destroy()
    local boom=Instance.new('Explosion');boom.Position=at;boom.BlastRadius=0;boom.BlastPressure=0;boom.DestroyJointRadiusPercent=0;boom.Parent=folder
    local ring=part({Shape=Enum.PartType.Cylinder,Material=Enum.Material.Neon,Color=Color3.fromRGB(255,150,50),Transparency=.2,
        Size=Vector3.new(.3,2,2),CFrame=CFrame.new(at+Vector3.new(0,.2,0))*CFrame.Angles(0,0,math.rad(90))})
    tween(ring,.5,{Size=Vector3.new(.3,12,12),Transparency=1});Debris:AddItem(ring,.6)
    burst(at+Vector3.new(0,1,0),Color3.fromRGB(90,70,60),14,14,1,1.2)
end
FX.lightning=function(at,info,delay)
    task.wait(delay)
    local top=at+Vector3.new(rng:NextNumber(-3,3),60,rng:NextNumber(-3,3));local last=top
    for i=1,6 do
        local nextPoint=top:Lerp(at,i/6)+(i<6 and Vector3.new(rng:NextNumber(-3,3),0,rng:NextNumber(-3,3)) or Vector3.zero)
        local len=(nextPoint-last).Magnitude
        local seg=part({Material=Enum.Material.Neon,Color=Color3.fromRGB(255,245,140),Size=Vector3.new(.5,.5,len),CFrame=CFrame.lookAt((last+nextPoint)/2,nextPoint)})
        tween(seg,.4,{Transparency=1});Debris:AddItem(seg,.5);last=nextPoint
    end
    burst(at+Vector3.new(0,1,0),Color3.fromRGB(255,240,120),20,16,.6,.7)
end
FX.heal=function(at) burst(at+Vector3.new(0,1.5,0),Color3.fromRGB(90,255,120),18,6,1.2,.6);pillar(at,Color3.fromRGB(90,255,120),10,1) end
FX.rage=function(at) burst(at+Vector3.new(0,1.5,0),Color3.fromRGB(255,60,50),16,7,1,.6) end
FX.slow=function(at) burst(at+Vector3.new(0,1,0),Color3.fromRGB(120,160,255),12,3,1.5,.6) end
FX.boost=function(at) pillar(at,Color3.fromRGB(120,255,120),30,1.4);burst(at+Vector3.new(0,2,0),Color3.fromRGB(180,255,120),25,10,1.2,.7) end
FX.build=function(at) pillar(at,Color3.fromRGB(255,220,80),18,1.2);burst(at+Vector3.new(0,2,0),Color3.fromRGB(255,230,120),18,8,1,.6) end
FX.poof=function(at) burst(at+Vector3.new(0,2,0),Color3.fromRGB(150,150,150),25,8,1.4,1.4) end
FX.summon=function(at) pillar(at,Color3.fromRGB(255,255,255),40,1.6);burst(at+Vector3.new(0,1,0),Color3.fromRGB(230,230,255),30,10,1.2,1.2) end
FX.freeze=function(at,info)
    local t=math.clamp(tonumber(info.t) or 8,1,20)
    local ice=part({Material=Enum.Material.Ice,Color=Color3.fromRGB(150,220,255),Transparency=.35,Size=Vector3.new(2.6,3.4,2.6),Position=at+Vector3.new(0,1.7,0),Reflectance=.2})
    ice.Size=Vector3.new(.2,.2,.2);tween(ice,.25,{Size=Vector3.new(2.6,3.4,2.6)},Enum.EasingStyle.Back)
    burst(at+Vector3.new(0,1.5,0),Color3.fromRGB(200,240,255),12,6,.8,.5)
    task.delay(t,function() if ice.Parent then tween(ice,.4,{Transparency=1});burst(ice.Position,Color3.fromRGB(200,240,255),10,8,.6,.4);Debris:AddItem(ice,.5) end end)
end
FX.shield=function(at,info)
    local t=math.clamp(tonumber(info.t) or 20,2,60)
    local dome=part({Shape=Enum.PartType.Ball,Material=Enum.Material.ForceField,Color=Color3.fromRGB(90,170,255),Transparency=.1,Size=Vector3.new(1,1,1),Position=at})
    tween(dome,.5,{Size=Vector3.new(22,22,22)},Enum.EasingStyle.Back)
    task.delay(t,function() if dome.Parent then tween(dome,.5,{Size=Vector3.new(1,1,1)});Debris:AddItem(dome,.6) end end)
end
local function coin(from,to,time,color)
    local c=part({Shape=Enum.PartType.Cylinder,Material=Enum.Material.Neon,Color=color,Size=Vector3.new(.25,1.1,1.1),CFrame=CFrame.new(from)*CFrame.Angles(0,0,math.rad(90))})
    tween(c,time,{CFrame=CFrame.new(to)*CFrame.Angles(rng:NextNumber(0,6),0,math.rad(90))},Enum.EasingStyle.Bounce)
    task.delay(time+.5,function() if c.Parent then tween(c,.3,{Transparency=1});Debris:AddItem(c,.35) end end)
end
local RES_COLOR={Gold=Color3.fromRGB(255,210,50),Log=Color3.fromRGB(160,105,55),Stone=Color3.fromRGB(160,160,165),Plank=Color3.fromRGB(215,160,95),
    ['Iron Ore']=Color3.fromRGB(150,110,90),['Iron Bar']=Color3.fromRGB(200,200,215),Crystal=Color3.fromRGB(170,110,255),Trophy=Color3.fromRGB(255,200,90)}
FX.gold=function(at,info)
    local color=RES_COLOR[info.r] or RES_COLOR.Gold
    for i=1,16 do
        local land=at+Vector3.new(rng:NextNumber(-5,5),.6,rng:NextNumber(-5,5))
        coin(land+Vector3.new(0,25+rng:NextNumber(0,10),0),land,1.1+rng:NextNumber(0,.4),color)
        if i%4==0 then task.wait(.05) end
    end
    burst(at+Vector3.new(0,2,0),color,20,8,1,.6)
end
FX.loot=FX.gold
FX.steal=function(at,info)
    local to=info.to and v3(info.to);if not to then return end
    for i=1,10 do
        local mid=(at+to)/2+Vector3.new(0,20,0)
        local c=part({Shape=Enum.PartType.Ball,Material=Enum.Material.Neon,Color=RES_COLOR.Gold,Size=Vector3.new(.9,.9,.9),Position=at+Vector3.new(0,1,0)})
        task.spawn(function()
            local t0=os.clock()
            while c.Parent and os.clock()-t0<1.2 do
                local a=(os.clock()-t0)/1.2;local p=(at:Lerp(mid,a)):Lerp(mid:Lerp(to,a),a)
                c.Position=p;task.wait()
            end
            c:Destroy()
        end)
        task.wait(.06)
    end
end
-- ------------------------------------------------------------------ timed effects (screen, controls, weather)
-- They only exist during a round and are removed when the player leaves it.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local player=Players.LocalPlayer
local FREDOKA=Font.new('rbxasset://fonts/families/FredokaOne.json',Enum.FontWeight.Bold,Enum.FontStyle.Normal)
local timed={}   -- name -> {untilAt, cleanup}
local function screenGui(name,order)
    local g=Instance.new('ScreenGui');g.Name=name;g.ResetOnSpawn=false;g.IgnoreGuiInset=true;g.DisplayOrder=order
    g.ScreenInsets=Enum.ScreenInsets.None;g.Parent=player:WaitForChild('PlayerGui');return g
end
local function label(parent,text,size,pos,color)
    local l=Instance.new('TextLabel');l.BackgroundTransparency=1;l.Size=size;l.Position=pos;l.AnchorPoint=Vector2.new(.5,.5)
    l.FontFace=FREDOKA;l.TextScaled=true;l.Text=text;l.TextColor3=color or Color3.new(1,1,1);l.Parent=parent
    local st=Instance.new('UIStroke');st.Thickness=3;st.Color=Color3.fromRGB(30,24,20);st.Parent=l
    return l
end
local function stop(name)
    local t=timed[name];if not t then return end
    timed[name]=nil;pcall(t.cleanup)
end
local function start(name,seconds,make)
    seconds=math.clamp(tonumber(seconds) or 10,1,120)
    if timed[name] then timed[name].untilAt=os.clock()+seconds;return timed[name] end
    local t={untilAt=os.clock()+seconds}
    t.cleanup=make(t) or function() end
    timed[name]=t;return t
end
local function colorFx(t,props)
    local cc=Instance.new('ColorCorrectionEffect');cc.Name='AdminFX_CC'
    for k,v in pairs(props) do cc[k]=v end
    cc.Parent=Workspace.CurrentCamera or Workspace;t.cc=cc
    return function() cc:Destroy() end
end
local function particles(t,color,speed,size,rate,lifetime)
    local box=part({Transparency=1,Size=Vector3.new(90,1,90)})
    local e=Instance.new('ParticleEmitter');e.Color=ColorSequence.new(color);e.LightEmission=.2;e.Rate=rate
    e.Size=NumberSequence.new(size);e.Speed=NumberRange.new(speed,speed*1.2);e.Lifetime=NumberRange.new(lifetime,lifetime)
    e.EmissionDirection=Enum.NormalId.Bottom;e.SpreadAngle=Vector2.new(4,4);e.Transparency=NumberSequence.new(.2)
    e.Parent=box;t.follow=box
    return function() box:Destroy() end
end
local WEATHER={
    night=function(t) return colorFx(t,{Brightness=-.28,Contrast=.12,Saturation=-.25,TintColor=Color3.fromRGB(150,170,255)}) end,
    day=function(t) return colorFx(t,{Brightness=.08,Contrast=.05,Saturation=.2,TintColor=Color3.fromRGB(255,244,222)}) end,
    fog=function(t) return colorFx(t,{Brightness=.12,Contrast=-.35,Saturation=-.45,TintColor=Color3.fromRGB(225,230,235)}) end,
    rain=function(t)
        local a=colorFx(t,{Brightness=-.1,Saturation=-.3,TintColor=Color3.fromRGB(200,210,230)})
        local b=particles(t,Color3.fromRGB(170,200,255),90,.18,900,.7)
        return function() a();b() end
    end,
    snow=function(t)
        local a=colorFx(t,{Brightness=.05,Saturation=-.2,TintColor=Color3.fromRGB(235,242,255)})
        local b=particles(t,Color3.fromRGB(255,255,255),12,.45,300,4)
        return function() a();b() end
    end,
    disco=function(t) t.disco=true;return colorFx(t,{Saturation=.6,Contrast=.2}) end,
}
local SCREEN={
    blind=function(t)
        local g=screenGui('AdminBlind',30)
        local f=Instance.new('Frame');f.Size=UDim2.fromScale(1,1);f.BackgroundColor3=Color3.new(0,0,0);f.BorderSizePixel=0;f.Parent=g
        t.text=label(g,'BLINDED BY THE ADMIN PANEL',UDim2.new(.8,0,0,40),UDim2.fromScale(.5,.5))
        return function() g:Destroy() end
    end,
    blur=function(t) local b=Instance.new('BlurEffect');b.Size=20;b.Parent=Workspace.CurrentCamera or Workspace;return function() b:Destroy() end end,
    rainbow=function(t) t.disco=true;return colorFx(t,{Saturation=.8,Contrast=.15}) end,
    shake=function(t) t.shake=true end,
    flip=function(t) t.flip=true end,
}
local function controls(t)
    local g=screenGui('AdminControlsLock',40)
    -- an invisible full-screen button swallows taps and clicks on the round (the admin panel sits above it)
    local sink=Instance.new('TextButton');sink.Text='';sink.BackgroundTransparency=1;sink.Size=UDim2.fromScale(1,1);sink.AutoButtonColor=false;sink.Parent=g
    t.text=label(g,'CONTROLS DISABLED',UDim2.new(.7,0,0,44),UDim2.new(.5,0,.8,0),Color3.fromRGB(255,120,110))
    return function() g:Destroy() end
end
local announceGui
local function announce(text,from)
    announceGui=announceGui or screenGui('AdminAnnounce',75)
    announceGui:ClearAllChildren()
    local l=label(announceGui,tostring(text),UDim2.new(.86,0,0,64),UDim2.new(.5,0,.36,0),Color3.fromRGB(255,226,90))
    local sub=label(announceGui,'- '..tostring(from or 'Admin'),UDim2.new(.5,0,0,26),UDim2.new(.5,0,.36,44))
    l.TextTransparency=1;tween(l,.3,{TextTransparency=0})
    task.delay(6,function() if l.Parent then tween(l,.5,{TextTransparency=1});tween(sub,.5,{TextTransparency=1});Debris:AddItem(l,.6);Debris:AddItem(sub,.6) end end)
end
RunService:BindToRenderStep('AdminFXCamera',Enum.RenderPriority.Camera.Value+5,function()
    local camera=Workspace.CurrentCamera;if not camera then return end
    local now=os.clock()
    for name,t in pairs(timed) do
        if now>=t.untilAt then stop(name)
        else
            if t.text then t.text.Text=t.text.Text:gsub(' %(%d+%)$','')..' ('..math.ceil(t.untilAt-now)..')' end
            if t.follow then t.follow.CFrame=CFrame.new(camera.CFrame.Position+Vector3.new(0,30,0)) end
            if t.disco and t.cc then t.cc.TintColor=Color3.fromHSV((now*.6)%1,.55,1) end
        end
    end
    local cf=camera.CFrame
    if timed.shake then cf=cf*CFrame.new(rng:NextNumber(-.6,.6),rng:NextNumber(-.6,.6),0)*CFrame.Angles(0,0,math.rad(rng:NextNumber(-2.5,2.5))) end
    if timed.flip then cf=cf*CFrame.Angles(0,0,math.pi) end
    if cf~=camera.CFrame then camera.CFrame=cf end
end)
local function clearAll() for name in pairs(timed) do stop(name) end end
player:GetAttributeChangedSignal('ScenePhase'):Connect(function() if player:GetAttribute('ScenePhase')~='Round' then clearAll() end end)
local me=tostring(player.UserId)
local function special(item)
    if item.k=='screen' and item.uid==me and SCREEN[item.e] then start(item.e,item.t,SCREEN[item.e]);return true end
    if item.k=='controls' and item.uid==me then start('controls',item.t,controls);return true end
    if item.k=='weather' and WEATHER[item.e] then
        for name in pairs(WEATHER) do if name~=item.e and timed['w_'..name] then stop('w_'..name) end end
        start('w_'..item.e,item.t,WEATHER[item.e]);return true
    end
    if item.k=='announce' and type(item.text)=='string' then announce(item.text,item.from);return true end
    return item.k=='screen' or item.k=='controls'
end
remote.OnClientEvent:Connect(function(list)
    if type(list)~='table' then return end
    local camera=Workspace.CurrentCamera
    for i,item in ipairs(list) do
        if i>160 then break end
        if type(item)=='table' and special(item) then continue end
        local fn=type(item)=='table' and FX[item.k]
        if fn and type(item.p)=='table' then
            local at=v3(item.p)
            -- skip what is far off-screen; rounds are small, so this is only a safety net
            if not camera or (camera.CFrame.Position-at).Magnitude<900 then
                task.spawn(fn,at,item,(i%12)*.08)
            end
        end
    end
end)
