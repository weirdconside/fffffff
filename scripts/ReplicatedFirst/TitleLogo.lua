-- The game logo, shared by the title screen and the round loading curtain:
--   [crown icon]  B A T T L E  [BUT] [WITH]
--                 A D M I N   P A N E L
-- "BATTLE" is as loud as "ADMIN PANEL" so nobody reads the name as just
-- "Admin Panel". Lives in ReplicatedFirst.
local TextService=game:GetService("TextService")
local Logo={};Logo.__index=Logo

local STUD="rbxassetid://103855926983380"
local INK=Color3.fromRGB(34,27,20)
local PALETTE={
    blue=Color3.fromRGB(52,158,216),cyan=Color3.fromRGB(0,190,214),gold=Color3.fromRGB(255,204,58),green=Color3.fromRGB(64,192,29),
    purple=Color3.fromRGB(147,72,213),red=Color3.fromRGB(226,35,31),orange=Color3.fromRGB(255,140,40),pink=Color3.fromRGB(240,80,150),
}
local LETTER_COLORS={PALETTE.blue,PALETTE.green,PALETTE.red,PALETTE.gold,PALETTE.purple,PALETTE.orange,PALETTE.cyan,PALETTE.pink}
local FIRE={Color3.fromRGB(236,46,36),Color3.fromRGB(255,112,28),Color3.fromRGB(255,176,32),Color3.fromRGB(255,112,28),Color3.fromRGB(236,46,36),Color3.fromRGB(255,140,40)}
local TITLE_FONT=Font.new("rbxasset://fonts/families/FredokaOne.json",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
Logo.Palette=PALETTE;Logo.LetterColors=LETTER_COLORS;Logo.Ink=INK;Logo.Stud=STUD;Logo.Font=TITLE_FONT
local TOP_WORD,MAIN_WORD="BATTLE","ADMIN PANEL"
local TAGS={"BUT","WITH"}
local TOP_SIZE,MAIN_SIZE,TAG_SIZE=92,112,42
local TOP_BASE,MAIN_BASE=112,258      -- baselines of the two rows inside the logo
local ICON_W=222
Logo.Height=282

local function make(class,parent,name,props)
    local o=Instance.new(class);o.Name=name or class
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent;return o
end
local function glyphWidth(text,size)
    local ok,dims=pcall(function() return TextService:GetTextSize(text,size,Enum.Font.FredokaOne,Vector2.new(2000,2000)) end)
    return ok and dims.X or #text*size*.62
end
local function backOut(u) u=math.clamp(u,0,1);local c1,c3=1.70158,2.70158;return 1+c3*(u-1)^3+c1*(u-1)^2 end
Logo.backOut=backOut

-- one chunky 3D letter: drop shadow + white face tinted by a gradient with a shine band
local function letter(parent,name,ch,size,x,baseline,colour,z)
    local w=glyphWidth(ch,size)+2
    local holder=make("Frame",parent,name,{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,1),Position=UDim2.fromOffset(x+w/2,baseline),Size=UDim2.fromOffset(w,size),ZIndex=z})
    local pop=make("UIScale",holder,"Pop")
    local thick=size>=100 and 6 or 5
    local shadow=make("TextLabel",holder,"Shadow",{BackgroundTransparency=1,Position=UDim2.fromOffset(0,math.floor(size*.07)),Size=UDim2.fromScale(1,1),Text=ch,FontFace=TITLE_FONT,TextSize=size,
        TextColor3=Color3.new(colour.R*.55,colour.G*.55,colour.B*.55),ZIndex=z})
    make("UIStroke",shadow,"Line",{Color=INK,Thickness=thick})
    local face=make("TextLabel",holder,"Face",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Text=ch,FontFace=TITLE_FONT,TextSize=size,TextColor3=Color3.new(1,1,1),ZIndex=z+1})
    make("UIStroke",face,"Line",{Color=INK,Thickness=thick})
    local shine=make("UIGradient",face,"Shine",{Rotation=20,Offset=Vector2.new(-1.2,0),Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,colour),ColorSequenceKeypoint.new(.44,colour),ColorSequenceKeypoint.new(.5,Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(.56,colour),ColorSequenceKeypoint.new(1,colour)})})
    return {holder=holder,pop=pop,shine=shine,x=x+w/2,base=baseline,colour=colour,shineAt=-10},w
end

-- parent: frame/ScreenGui for the logo; particles: full-screen frame for the confetti
function Logo.new(parent,particles,options)
    options=options or {}
    local self=setmetatable({letters={},top={},tags={},pool={},live={},strokes={},particles=particles,clock=0},Logo)
    local zb=options.zindex or 10
    local frame=make("Frame",parent,"Logo",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=options.position or UDim2.fromScale(.5,.44),
        Size=UDim2.fromOffset(1000,Logo.Height),ZIndex=zb})
    self.frame=frame;self.home=frame.Position;self.fitScale=make("UIScale",frame,"Fit")
    -- app icon: purple stud tile with a slowly turning 3D crown
    local slot=make("Frame",frame,"IconSlot",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(110,146),Size=UDim2.fromOffset(170,170),ZIndex=zb})
    self.iconSlot=slot;self.iconHome=slot.Position;self.iconScale=make("UIScale",slot,"Pop")
    local icon=make("Frame",slot,"Icon",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),BackgroundColor3=PALETTE.purple,BorderSizePixel=0,ZIndex=zb+1})
    make("UICorner",icon,"Round",{CornerRadius=UDim.new(.22,0)})
    make("UIStroke",icon,"Line",{Color=INK,Thickness=5})
    make("UIGradient",icon,"Shade",{Rotation=120,Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(170,160,200))})
    make("ImageLabel",icon,"Studs",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=STUD,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(34,34),ImageTransparency=.72,ZIndex=zb+2})
    local edge=make("Frame",slot,"Edge",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,9),Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(80,34,120),BorderSizePixel=0,ZIndex=zb})
    make("UICorner",edge,"Round",{CornerRadius=UDim.new(.22,0)})
    make("UIStroke",edge,"Line",{Color=INK,Thickness=5})
    self.icon=icon;self.iconEdge=edge
    local view=make("ViewportFrame",icon,"Crown3D",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.52),Size=UDim2.fromScale(1.15,1.15),ZIndex=zb+4,
        Ambient=Color3.fromRGB(205,200,190),LightColor=Color3.fromRGB(255,246,229),LightDirection=Vector3.new(-1,-2,-2.5)})
    self.view=view
    local world=make("WorldModel",view,"World")
    local crown=make("Model",world,"Crown");self.crown=crown
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
    -- row 1: BATTLE in hot colours
    local x=ICON_W
    for i=1,#TOP_WORD do
        local l,w=letter(frame,"T"..i,TOP_WORD:sub(i,i),TOP_SIZE,x,TOP_BASE,FIRE[(i-1)%#FIRE+1],zb+2)
        self.top[i]=l;x+=w-3
    end
    local row1=x
    -- the two little tags that finish the sentence: [BUT] [WITH]
    x+=18
    for i,word in ipairs(TAGS) do
        local w=glyphWidth(word,TAG_SIZE)+30
        local tag=make("Frame",frame,"Tag"..i,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(x+w/2,TOP_BASE-TOP_SIZE*.42+(i==1 and -4 or 6)),Size=UDim2.fromOffset(w,TAG_SIZE+16),
            Rotation=i==1 and -7 or 5,BackgroundColor3=INK,BorderSizePixel=0,ZIndex=zb+5})
        make("UICorner",tag,"Round",{CornerRadius=UDim.new(0,10)})
        make("UIStroke",tag,"Line",{Color=Color3.new(1,1,1),Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
        make("ImageLabel",tag,"Studs",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=STUD,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(22,22),ImageTransparency=.86,ZIndex=zb+6})
        make("TextLabel",tag,"Text",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Text=word,FontFace=TITLE_FONT,TextSize=TAG_SIZE,TextColor3=i==1 and PALETTE.gold or Color3.new(1,1,1),ZIndex=zb+7})
        self.tags[i]={holder=tag,pop=make("UIScale",tag,"Pop"),home=tag.Position,rot=tag.Rotation,colour=i==1 and PALETTE.gold or PALETTE.cyan}
        x+=w+12
    end
    row1=x
    -- row 2: ADMIN PANEL in rainbow colours
    x=ICON_W
    for i=1,#MAIN_WORD do
        local ch=MAIN_WORD:sub(i,i)
        if ch==" " then x+=34 else
            local n=#self.letters+1
            local l,w=letter(frame,"L"..n,ch,MAIN_SIZE,x,MAIN_BASE,LETTER_COLORS[(n-1)%#LETTER_COLORS+1],zb+2)
            self.letters[n]=l;x+=w-2
        end
    end
    self.width=math.max(row1,x)+20
    frame.Size=UDim2.fromOffset(self.width,Logo.Height)
    -- confetti: pooled squares/dots that burst out of a letter in every direction
    if particles then
        for i=1,160 do
            local bit=make("Frame",particles,"Bit",{AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(8,8),BorderSizePixel=0,Visible=false,ZIndex=(options.particleZ or zb+6)})
            make("UICorner",bit,"Round",{CornerRadius=UDim.new(i%2==0 and 1 or .25,0)})
            self.strokes[bit]=make("UIStroke",bit,"Line",{Color=INK,Thickness=1.5})
            self.pool[#self.pool+1]=bit
        end
    end
    return self
end

function Logo:fit(viewport,widthShare,heightShare,maxScale)
    local s=math.min((viewport.X*(widthShare or .86))/self.width,(viewport.Y*(heightShare or .5))/Logo.Height)
    s=math.clamp(s,.25,maxScale or 1)
    self.fitScale.Scale=s
    return s
end
local function setPose(l,lift,scale,rot)
    l.holder.Position=UDim2.fromOffset(l.x,l.base-(lift or 0))
    l.pop.Scale=scale or 1
    l.holder.Rotation=rot or 0
    l.holder.Visible=(scale or 1)>.01
end
-- ADMIN PANEL letter i / BATTLE letter i: lift in logo pixels, pop scale, rotation
function Logo:pose(i,lift,scale,rot) local l=self.letters[i];if l then setPose(l,lift,scale,rot) end end
function Logo:poseTop(i,lift,scale,rot) local l=self.top[i];if l then setPose(l,lift,scale,rot) end end
function Logo:tag(i,scale,lift,extraRot)
    local t=self.tags[i];if not t then return end
    t.pop.Scale=scale;t.holder.Position=t.home-UDim2.fromOffset(0,lift or 0);t.holder.Rotation=t.rot+(extraRot or 0)
    t.holder.Visible=scale>.01
end
function Logo:iconPose(progress,scale)
    -- progress 0: parked above the text, 1: home
    local u=math.clamp(progress,0,1.2)
    local home=self.iconHome
    self.iconSlot.Position=UDim2.fromOffset(560+(home.X.Offset-560)*u,-260+(home.Y.Offset+260)*u)
    self.iconSlot.Rotation=160*(1-math.min(u,1))
    self.iconScale.Scale=scale
    self.iconSlot.Visible=scale>.01
end
function Logo:shake(amount) self.shakeAt=self.clock;self.shakeAmount=amount end
function Logo:spinIcon(duration) self.spinStart=self.clock;self.spinTime=duration end
function Logo:shine(stagger)
    local n=0
    for _,l in ipairs(self.top) do l.shineAt=self.clock+n*(stagger or .05);n+=1 end
    for _,l in ipairs(self.letters) do l.shineAt=self.clock+n*(stagger or .05)*.6;n+=1 end
end
function Logo:count() return #self.letters end
function Logo:countTop() return #self.top end

-- confetti burst from the middle of a letter (the original title screen effect)
local function centreOf(holder,layer)
    local p=holder.AbsolutePosition;local s=holder.AbsoluteSize
    return Vector2.new(p.X+s.X*.5,p.Y+s.Y*.4)-layer.AbsolutePosition
end
function Logo:emit(at,count,reach,colour)
    if not at then return end
    local k=self.fitScale.Scale*.7+.3
    for i=1,count do
        local bit=table.remove(self.pool)
        if not bit then break end
        local size=math.random(7,13)*k
        bit.Size=UDim2.fromOffset(size,size)
        bit.BackgroundColor3=(i%3==0 and colour) or LETTER_COLORS[math.random(1,#LETTER_COLORS)]
        bit.BackgroundTransparency=0;bit.Rotation=math.random(0,90);bit.Visible=true;bit.Position=UDim2.fromOffset(at.X,at.Y)
        if self.strokes[bit] then self.strokes[bit].Transparency=0 end
        local a=math.random()*math.pi*2;local r=(math.random()*.6+.4)*(reach or 130)*k
        self.live[#self.live+1]={frame=bit,x0=at.X,y0=at.Y,x1=at.X+math.cos(a)*r,y1=at.Y+math.sin(a)*r+30*k,
            rot0=bit.Rotation,rot1=bit.Rotation+math.random(-200,200),size=size,age=0,life=.7+math.random()*.4}
    end
end
function Logo:burst(i,count,reach) local l=self.letters[i];if l and self.particles then self:emit(centreOf(l.holder,self.particles),count,reach,l.colour) end end
function Logo:burstTop(i,count,reach) local l=self.top[i];if l and self.particles then self:emit(centreOf(l.holder,self.particles),count,reach,l.colour) end end
function Logo:burstTag(i,count,reach) local t=self.tags[i];if t and self.particles then self:emit(centreOf(t.holder,self.particles),count,reach,t.colour) end end

-- per-frame: crown turn, icon wobble, shine sweeps, shake, confetti
function Logo:step(dt)
    self.clock+=dt
    local t=self.clock
    local extra=0
    if self.spinStart then
        local k=(t-self.spinStart)/self.spinTime
        if k>=1 then self.spinStart=nil else extra=360*(1-(1-k)^3) end
    end
    local angle=math.rad(extra+math.sin(t*1.1)*14)
    local c=math.cos(angle)
    self.icon.Size=UDim2.fromScale(math.max(.08,math.abs(c)),1)
    self.iconEdge.Size=UDim2.fromScale(math.max(.08,math.abs(c))+.02,1)
    self.iconEdge.Position=UDim2.new(.5,math.sin(angle)*10,.5,9)
    self.icon.BackgroundColor3=c>=0 and PALETTE.purple or Color3.fromRGB(96,40,150)
    self.view.Visible=c>0.15
    self.crown:PivotTo(CFrame.new(0,math.sin(t*2)*.05,0)*CFrame.Angles(0,t*.9,math.sin(t*1.3)*.08))
    for _,list in ipairs({self.top,self.letters}) do
        for _,l in ipairs(list) do
            local u=(t-l.shineAt)/.55
            l.shine.Offset=Vector2.new(u>=0 and u<=1 and (-1.2+2.4*u) or -1.2,0)
        end
    end
    if self.shakeAt then
        local u=(t-self.shakeAt)/.35
        if u>=1 then self.shakeAt=nil;self.frame.Position=self.home
        else
            local a=self.shakeAmount*(1-u)^2
            self.frame.Position=self.home+UDim2.fromOffset(math.sin(t*90)*a,math.cos(t*77)*a*.6)
        end
    end
    for i=#self.live,1,-1 do
        local p=self.live[i]
        p.age+=dt
        local u=p.age/p.life
        if u>=1 then
            p.frame.Visible=false;table.remove(self.live,i);self.pool[#self.pool+1]=p.frame
        else
            local e=1-(1-u)^2
            p.frame.Position=UDim2.fromOffset(p.x0+(p.x1-p.x0)*e,p.y0+(p.y1-p.y0)*e)
            p.frame.Rotation=p.rot0+(p.rot1-p.rot0)*e
            local s=p.size+(2-p.size)*e;p.frame.Size=UDim2.fromOffset(s,s)
            p.frame.BackgroundTransparency=e
            local st=self.strokes[p.frame];if st then st.Transparency=e end
        end
    end
end
return Logo
