-- The game logo ("BATTLE BUT WITH" + multicoloured "ADMIN PANEL" + the crown
-- app icon). Shared by the title screen and the round loading curtain, so both
-- always show exactly the same thing. Lives in ReplicatedFirst.
local TextService=game:GetService("TextService")
local Logo={};Logo.__index=Logo

local STUD="rbxassetid://103855926983380"
local INK=Color3.fromRGB(34,27,20)
local PALETTE={
    blue=Color3.fromRGB(52,158,216),cyan=Color3.fromRGB(0,190,214),gold=Color3.fromRGB(255,204,58),green=Color3.fromRGB(64,192,29),
    purple=Color3.fromRGB(147,72,213),red=Color3.fromRGB(226,35,31),orange=Color3.fromRGB(255,140,40),pink=Color3.fromRGB(240,80,150),
}
local LETTER_COLORS={PALETTE.blue,PALETTE.green,PALETTE.red,PALETTE.gold,PALETTE.purple,PALETTE.orange,PALETTE.cyan,PALETTE.pink}
local TITLE_FONT=Font.new("rbxasset://fonts/families/FredokaOne.json",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
Logo.Palette=PALETTE;Logo.LetterColors=LETTER_COLORS;Logo.Ink=INK;Logo.Stud=STUD;Logo.Font=TITLE_FONT
local WORD="ADMIN PANEL"
local OVER={"BATTLE","BUT","WITH"}
local LETTER_SIZE,OVER_SIZE=112,34
local BASE_Y=196          -- baseline of the big letters inside the logo
local ICON_W=222          -- room on the left for the app icon
Logo.Height=260

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

-- parent: the frame/ScreenGui to put the logo in; particles: a full-screen frame for the stud bits
function Logo.new(parent,particles,options)
    options=options or {}
    local self=setmetatable({letters={},words={},pool={},live={},strokes={},particles=particles,spin=0,clock=0},Logo)
    local zb=options.zindex or 10
    local frame=make("Frame",parent,"Logo",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=options.position or UDim2.fromScale(.5,.44),
        Size=UDim2.fromOffset(820,Logo.Height),ZIndex=zb})
    self.frame=frame;self.fitScale=make("UIScale",frame,"Fit")
    -- app icon: purple stud tile with a slowly turning 3D crown
    local slot=make("Frame",frame,"IconSlot",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(110,132),Size=UDim2.fromOffset(170,170),ZIndex=zb})
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
    -- "BATTLE BUT WITH": three words that can pop in one by one
    local x=ICON_W+6
    for i,wordText in ipairs(OVER) do
        local w=glyphWidth(wordText,OVER_SIZE)+4
        local holder=make("Frame",frame,"Over"..i,{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(x+w/2,51),Size=UDim2.fromOffset(w,OVER_SIZE+6),ZIndex=zb+2})
        local label=make("TextLabel",holder,"Text",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Text=wordText,FontFace=TITLE_FONT,TextSize=OVER_SIZE,TextColor3=INK,ZIndex=zb+2})
        make("UIStroke",label,"Line",{Color=Color3.new(1,1,1),Thickness=3})
        self.words[i]={holder=holder,pop=make("UIScale",holder,"Pop"),home=holder.Position}
        x+=w+OVER_SIZE*.45
    end
    -- the big letters
    x=ICON_W
    for i=1,#WORD do
        local ch=WORD:sub(i,i)
        if ch==" " then x+=34 else
            local w=glyphWidth(ch,LETTER_SIZE)+2
            local n=#self.letters+1
            local colour=LETTER_COLORS[(n-1)%#LETTER_COLORS+1]
            local holder=make("Frame",frame,"L"..n,{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,1),Position=UDim2.fromOffset(x+w/2,BASE_Y),Size=UDim2.fromOffset(w,LETTER_SIZE),ZIndex=zb+2})
            local pop=make("UIScale",holder,"Pop")
            local shadow=make("TextLabel",holder,"Shadow",{BackgroundTransparency=1,Position=UDim2.fromOffset(0,8),Size=UDim2.fromScale(1,1),Text=ch,FontFace=TITLE_FONT,TextSize=LETTER_SIZE,
                TextColor3=Color3.new(colour.R*.55,colour.G*.55,colour.B*.55),ZIndex=zb+2})
            make("UIStroke",shadow,"Line",{Color=INK,Thickness=6})
            local face=make("TextLabel",holder,"Face",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Text=ch,FontFace=TITLE_FONT,TextSize=LETTER_SIZE,TextColor3=Color3.new(1,1,1),ZIndex=zb+3})
            make("UIStroke",face,"Line",{Color=INK,Thickness=6})
            local shine=make("UIGradient",face,"Shine",{Rotation=20,Offset=Vector2.new(-1.2,0),Color=ColorSequence.new({
                ColorSequenceKeypoint.new(0,colour),ColorSequenceKeypoint.new(.44,colour),ColorSequenceKeypoint.new(.5,Color3.new(1,1,1)),
                ColorSequenceKeypoint.new(.56,colour),ColorSequenceKeypoint.new(1,colour)})})
            self.letters[n]={holder=holder,pop=pop,shine=shine,x=x+w/2,colour=colour,air=false,shineAt=-10}
            x+=w-2
        end
    end
    self.width=x+20
    frame.Size=UDim2.fromOffset(self.width,Logo.Height)
    -- stud-bit particles (pooled, animated by step())
    if particles then
        for i=1,90 do
            local bit=make("Frame",particles,"Bit",{AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(8,8),BorderSizePixel=0,Visible=false,ZIndex=(options.particleZ or zb+6)})
            make("UICorner",bit,"Round",{CornerRadius=UDim.new(i%2==0 and 1 or .25,0)})
            self.strokes[bit]=make("UIStroke",bit,"Line",{Color=INK,Thickness=1.5})
            self.pool[#self.pool+1]=bit
        end
    end
    return self
end

-- Scale the logo to the screen: at most `widthShare` of the width and `heightShare` of the height.
function Logo:fit(viewport,widthShare,heightShare,maxScale)
    local s=math.min((viewport.X*(widthShare or .86))/self.width,(viewport.Y*(heightShare or .5))/Logo.Height)
    s=math.clamp(s,.25,maxScale or 1)
    self.fitScale.Scale=s
    return s
end

-- letter pose: lift in logo pixels (up is positive), pop scale, rotation
function Logo:pose(i,lift,scale,rot)
    local l=self.letters[i];if not l then return end
    l.holder.Position=UDim2.fromOffset(l.x,BASE_Y-(lift or 0))
    l.pop.Scale=scale or 1
    l.holder.Rotation=rot or 0
    l.holder.Visible=(scale or 1)>.01
end
function Logo:word(i,scale,drop)
    local w=self.words[i];if not w then return end
    w.pop.Scale=scale;w.holder.Position=w.home-UDim2.fromOffset(0,drop or 0)
    w.holder.Visible=scale>.01
end
function Logo:iconPose(progress,scale)
    -- progress 0: parked above the text, 1: home
    local from=UDim2.fromOffset(560,-260)
    local u=math.clamp(progress,0,1.2)
    local home=self.iconHome
    self.iconSlot.Position=UDim2.fromOffset(from.X.Offset+(home.X.Offset-from.X.Offset)*u,from.Y.Offset+(home.Y.Offset-from.Y.Offset)*u)
    self.iconSlot.Rotation=160*(1-math.min(u,1))
    self.iconScale.Scale=scale
    self.iconSlot.Visible=scale>.01
end
function Logo:spinIcon(duration) self.spinStart=self.clock;self.spinTime=duration end
-- sweep of light across every letter, one after another
function Logo:shine(stagger)
    for i,l in ipairs(self.letters) do l.shineAt=self.clock+(i-1)*(stagger or .05) end
end

-- screen point under letter i (bottom centre), relative to the particle layer
function Logo:letterFoot(i)
    local l=self.letters[i];local layer=self.particles
    if not l or not layer then return nil end
    local p=l.holder.AbsolutePosition;local s=l.holder.AbsoluteSize
    return Vector2.new(p.X+s.X*.5,p.Y+s.Y*.92)-layer.AbsolutePosition,s.X
end
function Logo:emit(at,count,power,colour,spread)
    if not at then return end
    for _=1,count do
        local bit=table.remove(self.pool)
        if not bit then break end
        local size=math.random(6,12)*(self.fitScale.Scale*.6+.4)
        bit.Size=UDim2.fromOffset(size,size)
        bit.BackgroundColor3=(math.random()<.45 and colour) or LETTER_COLORS[math.random(1,#LETTER_COLORS)]
        bit.BackgroundTransparency=0;bit.Rotation=math.random(0,90);bit.Visible=true
        if self.strokes[bit] then self.strokes[bit].Transparency=0 end
        local side=math.random()<.5 and -1 or 1
        local x=at.X+side*(spread or 0)*math.random()*.5
        bit.Position=UDim2.fromOffset(x,at.Y)
        local p=power*(self.fitScale.Scale*.5+.5)
        self.live[#self.live+1]={frame=bit,x=x,y=at.Y,vx=side*(p*.35+math.random()*p*.9),vy=-(p*.55+math.random()*p*.8),
            spin=math.random(-540,540),age=0,life=.55+math.random()*.35,size=size}
    end
end
function Logo:burst(i,count,power)
    local at,w=self:letterFoot(i)
    if at then self:emit(at,count,power,self.letters[i].colour,w) end
end

-- per-frame: crown turn, icon wobble, shine sweeps, particles
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
    for _,l in ipairs(self.letters) do
        local u=(t-l.shineAt)/.55
        l.shine.Offset=Vector2.new(u>=0 and u<=1 and (-1.2+2.4*u) or -1.2,0)
    end
    local g=1400*self.fitScale.Scale
    for i=#self.live,1,-1 do
        local p=self.live[i]
        p.age+=dt
        if p.age>=p.life then
            p.frame.Visible=false;table.remove(self.live,i);self.pool[#self.pool+1]=p.frame
        else
            p.vy+=g*dt;p.x+=p.vx*dt;p.y+=p.vy*dt
            local k=p.age/p.life
            p.frame.Position=UDim2.fromOffset(p.x,p.y)
            p.frame.Rotation+=p.spin*dt
            p.frame.BackgroundTransparency=k*k
            local st=self.strokes[p.frame];if st then st.Transparency=k*k end
            local s=p.size*(1-k*.6);p.frame.Size=UDim2.fromOffset(s,s)
        end
    end
end
function Logo:count() return #self.letters end
return Logo
