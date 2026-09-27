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
remote.OnClientEvent:Connect(function(list)
    if type(list)~='table' then return end
    local camera=Workspace.CurrentCamera
    for i,item in ipairs(list) do
        if i>160 then break end
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
