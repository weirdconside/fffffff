-- Small 3D glyphs for Admin Vault cards and the title logo. Everything is built
-- from Roblox primitives inside a ViewportFrame, so no image uploads are needed.
local Icons={}
local GOLD=Color3.fromRGB(255,204,58)
local GOLD_D=Color3.fromRGB(214,150,24)
local INK=Color3.fromRGB(34,27,20)
local WOOD=Color3.fromRGB(170,112,64)
local WOOD_D=Color3.fromRGB(116,72,40)
local WHITE=Color3.fromRGB(250,250,244)
local function part(parent,size,cf,colour,shape,material,class)
    local p=Instance.new(class or 'Part');p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
    p.Size=size;p.CFrame=cf;p.Color=colour;p.Material=material or Enum.Material.SmoothPlastic
    if shape and p:IsA('Part') then p.Shape=shape end
    p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
local BALL,CYL=Enum.PartType.Ball,Enum.PartType.Cylinder
local up=CFrame.Angles(0,0,math.pi/2) -- turns an X-axis cylinder upright
local function crown(m,scale)
    scale=scale or 1
    local n=10;local r=.78*scale
    for k=0,n-1 do
        local a=k/n*math.pi*2
        part(m,Vector3.new(.52,.5,.16)*scale,CFrame.Angles(0,a,0)*CFrame.new(0,-.05*scale,r),GOLD)
    end
    for k=0,4 do
        local a=k/5*math.pi*2
        part(m,Vector3.new(.3,.3,.3)*scale,CFrame.Angles(0,a,0)*CFrame.new(0,.38*scale,r)*CFrame.Angles(0,0,math.pi/4),GOLD)
        part(m,Vector3.new(.2,.2,.2)*scale,CFrame.Angles(0,a,0)*CFrame.new(0,.66*scale,r),WHITE,BALL)
        local gem=({Color3.fromRGB(255,60,70),Color3.fromRGB(70,160,255),Color3.fromRGB(80,220,110),Color3.fromRGB(190,90,255),Color3.fromRGB(255,150,40)})[k+1]
        part(m,Vector3.new(.22,.22,.22)*scale,CFrame.Angles(0,a,0)*CFrame.new(0,-.05*scale,r+.08*scale),gem,BALL,Enum.Material.Neon)
    end
    part(m,Vector3.new(.12,1.3,1.3)*scale,CFrame.new(0,-.28*scale,0)*up,Color3.fromRGB(150,30,40),CYL,Enum.Material.Fabric)
end
local function coin(m,cf,size)
    part(m,Vector3.new(.2*size,1.3*size,1.3*size),cf*CFrame.Angles(0,0,0),GOLD,CYL)
    part(m,Vector3.new(.22*size,.95*size,.95*size),cf,GOLD_D,CYL)
    part(m,Vector3.new(.24*size,.3*size,.3*size),cf*CFrame.new(0,0,0),WHITE,BALL)
end
local function heart(m,cf,s,colour)
    colour=colour or Color3.fromRGB(255,80,120)
    part(m,Vector3.new(.75,.75,.55)*s,cf*CFrame.new(-.26*s,.18*s,0),colour,BALL)
    part(m,Vector3.new(.75,.75,.55)*s,cf*CFrame.new(.26*s,.18*s,0),colour,BALL)
    part(m,Vector3.new(.72,.72,.5)*s,cf*CFrame.new(0,-.14*s,0)*CFrame.Angles(0,0,math.pi/4),colour)
end
local function crate(m,cf,s)
    part(m,Vector3.new(1.4,1.4,1.4)*s,cf,WOOD,nil,Enum.Material.WoodPlanks)
    for _,e in ipairs({{1,1},{1,-1},{-1,1},{-1,-1}}) do
        part(m,Vector3.new(1.46,.16,.16)*s,cf*CFrame.new(0,e[1]*.66*s,e[2]*.66*s),WOOD_D)
        part(m,Vector3.new(.16,1.46,.16)*s,cf*CFrame.new(e[1]*.66*s,0,e[2]*.66*s),WOOD_D)
        part(m,Vector3.new(.16,.16,1.46)*s,cf*CFrame.new(e[1]*.66*s,e[2]*.66*s,0),WOOD_D)
    end
end
local BUILD={}
function BUILD.Crown(m) crown(m,1.15) end
function BUILD.Dice(m)
    local purple=Color3.fromRGB(147,72,213)
    part(m,Vector3.new(1.35,1.35,1.35),CFrame.Angles(.35,.6,0),purple)
    local base=CFrame.Angles(.35,.6,0)
    local pip=function(cf) part(m,Vector3.new(.24,.24,.24),base*cf,WHITE,BALL) end
    pip(CFrame.new(0,.62,0))                                   -- top: 1
    pip(CFrame.new(-.3,.3,.62));pip(CFrame.new(.3,-.3,.62))    -- front: 2
    for _,y in ipairs({-.3,0,.3}) do pip(CFrame.new(.62,y,-y)) end -- side: 3
end
function BUILD.Veto(m)
    part(m,Vector3.new(.3,1.8,1.8),up*CFrame.Angles(math.pi/2,0,0),Color3.fromRGB(226,35,31),CYL)
    part(m,Vector3.new(.35,1.4,1.4),up*CFrame.Angles(math.pi/2,0,0),WHITE,CYL)
    part(m,Vector3.new(.4,1.15,1.15),up*CFrame.Angles(math.pi/2,0,0),Color3.fromRGB(226,35,31),CYL)
    part(m,Vector3.new(1.1,.3,.5),CFrame.Angles(0,0,math.pi/4),WHITE)
    part(m,Vector3.new(1.1,.3,.5),CFrame.Angles(0,0,-math.pi/4),WHITE)
end
function BUILD.Hourglass(m)
    local blue=Color3.fromRGB(52,158,216)
    part(m,Vector3.new(.2,1.3,1.3),CFrame.new(0,.85,0)*up,WOOD_D,CYL)
    part(m,Vector3.new(.2,1.3,1.3),CFrame.new(0,-.85,0)*up,WOOD_D,CYL)
    for _,x in ipairs({-.55,.55}) do part(m,Vector3.new(.14,1.6,.14),CFrame.new(x,0,0),WOOD_D) end
    part(m,Vector3.new(.7,.9,.9),CFrame.new(0,.38,0)*up,Color3.fromRGB(200,235,255),CYL,Enum.Material.Glass).Transparency=.35
    part(m,Vector3.new(.7,.9,.9),CFrame.new(0,-.38,0)*up,Color3.fromRGB(200,235,255),CYL,Enum.Material.Glass).Transparency=.35
    part(m,Vector3.new(.35,.7,.7),CFrame.new(0,-.55,0)*up,GOLD,CYL)
    part(m,Vector3.new(.2,.45,.45),CFrame.new(0,.25,0)*up,GOLD,CYL)
    part(m,Vector3.new(.08,.5,.08),CFrame.new(0,-.05,0),GOLD)
    part(m,Vector3.new(.18,.18,.18),CFrame.new(.7,.75,0),blue,BALL,Enum.Material.Neon)
end
function BUILD.Hammer(m)
    local base=CFrame.Angles(0,0,-.55)
    part(m,Vector3.new(2,.24,.24),base*CFrame.new(0,0,0),WOOD,CYL)
    part(m,Vector3.new(.55,.8,.55),base*CFrame.new(.9,0,0),Color3.fromRGB(140,146,160))
    part(m,Vector3.new(.6,.25,.6),base*CFrame.new(.9,.42,0),Color3.fromRGB(96,101,116))
    part(m,Vector3.new(.3,.3,.3),base*CFrame.new(-.95,0,0),Color3.fromRGB(64,192,29),BALL)
end
function BUILD.Crate(m) crate(m,CFrame.Angles(0,.5,0),1) end
function BUILD.Token(m)
    local face=CFrame.Angles(0,math.pi/2+.35,0)
    coin(m,face,1.25)
    -- an embossed eight-point star on the side that faces the camera
    for _,a in ipairs({0,math.pi/4}) do part(m,Vector3.new(.08,.5,.5),face*CFrame.new(-.14,0,0)*CFrame.Angles(a,0,0),WHITE) end
end
function BUILD.Tokens(m)
    coin(m,CFrame.new(-.35,-.25,-.3)*CFrame.Angles(0,math.pi/2+.2,0),1)
    coin(m,CFrame.new(.35,-.05,-.1)*CFrame.Angles(0,math.pi/2+.5,0),1)
    coin(m,CFrame.new(0,.35,.3)*CFrame.Angles(0,math.pi/2+.35,0),1)
end
function BUILD.Drop(m)
    crate(m,CFrame.new(0,-.55,0)*CFrame.Angles(0,.5,0),.62)
    local chute=part(m,Vector3.new(1.9,1.1,1.9),CFrame.new(0,.75,0),Color3.fromRGB(64,192,29),BALL)
    part(m,Vector3.new(2,.6,2),CFrame.new(0,.35,0),Color3.fromRGB(64,192,29)).Transparency=1
    for _,x in ipairs({-.75,.75}) do part(m,Vector3.new(.05,1.05,.05),CFrame.new(x*.8,.0,0)*CFrame.Angles(0,0,-x*.35),WHITE) end
end
function BUILD.Heart(m) heart(m,CFrame.new(),1.6) end
function BUILD.Hearts(m) heart(m,CFrame.new(-.25,-.1,0),1.4);heart(m,CFrame.new(.55,.55,-.3),.8,Color3.fromRGB(255,150,190)) end
function BUILD.Chest(m)
    part(m,Vector3.new(1.8,.9,1.1),CFrame.new(0,-.35,0),WOOD,nil,Enum.Material.WoodPlanks)
    part(m,Vector3.new(1.85,.45,1.15),CFrame.new(0,.33,0),WOOD_D,nil,Enum.Material.WoodPlanks)
    part(m,Vector3.new(.25,1.35,1.2),CFrame.new(0,-.12,0),GOLD)
    for i=1,5 do part(m,Vector3.new(.08,.35,.35),CFrame.new(-.6+i*.22,.65+(i%2)*.1,.1)*CFrame.Angles(0,math.pi/2,.3*i)*up,GOLD,CYL) end
end
local function ticket(m,cf,s)
    local base=Color3.fromRGB(255,206,64)
    part(m,Vector3.new(2.1,1.05,.08)*s,cf,base)
    part(m,Vector3.new(1.9,.85,.1)*s,cf,Color3.fromRGB(255,232,140))
    part(m,Vector3.new(1.7,.65,.11)*s,cf,base)
    for _,x in ipairs({-1.05,1.05}) do part(m,Vector3.new(.3,.3,.14)*s,cf*CFrame.new(x*s,0,0),Color3.fromRGB(60,40,20),BALL) end
    for i=-2,2 do part(m,Vector3.new(.05,.05,.12)*s,cf*CFrame.new(.55*s,i*.14*s,0),WHITE,BALL) end
    for _,a in ipairs({0,math.pi/4}) do part(m,Vector3.new(.34,.34,.13)*s,cf*CFrame.new(-.2*s,0,0)*CFrame.Angles(0,0,a),Color3.fromRGB(226,52,48)) end
end
function BUILD.Ticket(m,options)
    local n=math.clamp(math.floor((options and options.count or 1)),1,20)
    local shown=n>=20 and 6 or n>=10 and 5 or n>=7 and 4 or n>=3 and 3 or 1
    for i=1,shown do
        local k=i-(shown+1)/2
        ticket(m,CFrame.new(k*.12,k*.05,-i*.03)*CFrame.Angles(0,-.35,k*.22),shown>1 and .82 or 1)
    end
end
function BUILD.Gavel(m)
    local wood=Color3.fromRGB(150,86,44);local dark=Color3.fromRGB(96,52,26)
    local tilt=CFrame.Angles(0,.3,-.6)
    part(m,Vector3.new(2.1,.22,.22),tilt*CFrame.new(-.2,0,0),wood,CYL)
    part(m,Vector3.new(1.3,.72,.72),tilt*CFrame.new(.85,0,0)*CFrame.Angles(0,math.pi/2,0),dark,CYL)
    for _,z in ipairs({-.45,.45}) do part(m,Vector3.new(.14,.78,.78),tilt*CFrame.new(.85,0,z)*CFrame.Angles(0,math.pi/2,0),GOLD,CYL) end
    part(m,Vector3.new(1.3,.22,.9),CFrame.new(.1,-.95,.2),dark)
    part(m,Vector3.new(1.1,.08,.7),CFrame.new(.1,-.82,.2),GOLD)
end
function BUILD.Shop(m)
    crown(m,1.25)
end
function Icons.build(parent,kind,options)
    options=options or {}
    local view=Instance.new('ViewportFrame');view.Name='Icon3D';view.BackgroundTransparency=1;view.BorderSizePixel=0
    view.Size=options.size or UDim2.fromScale(1,1);view.Position=options.position or UDim2.fromScale(.5,.5);view.AnchorPoint=Vector2.new(.5,.5)
    view.Ambient=Color3.fromRGB(200,196,190);view.LightColor=Color3.fromRGB(255,246,229);view.LightDirection=Vector3.new(-1,-2,-2.5)
    view.ZIndex=options.zindex or 5
    local world=Instance.new('WorldModel');world.Name='Geometry';world.Parent=view
    local model=Instance.new('Model');model.Name='Glyph';model.Parent=world
    local builder=BUILD[kind] or BUILD.Crown
    builder(model,options)
    local camera=Instance.new('Camera');camera.FieldOfView=options.fov or 32
    camera.CFrame=CFrame.lookAt(Vector3.new(2.4,1.7,4.4)*(options.distance or 1),Vector3.new(0,0,0));camera.Parent=view;view.CurrentCamera=camera
    model.WorldPivot=CFrame.new()
    view.Parent=parent
    return view,model
end
-- Gentle idle motion shared by every visible icon.
function Icons.spin(model,clock,seed,amount)
    if not model or not model.Parent then return end
    local t=clock+(seed or 0)
    model:PivotTo(CFrame.new(0,math.sin(t*1.7)*.06,0)*CFrame.Angles(0,math.sin(t*.9)*(amount or .45),math.sin(t*1.3)*.05))
end
return Icons
