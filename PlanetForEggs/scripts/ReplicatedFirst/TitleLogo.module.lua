--!nocheck
-- The game logo for the title screen (the intro of "Battle but with Admin Panel", rebuilt for us):
--   [emblem]  P L A N E T
--             [FOR] E G G S
-- The icon is the game's emblem (a white ringed planet on a brown tile), animated. Lives in ReplicatedFirst.
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
local EMBLEM=Color3.fromRGB(143,92,42)         -- the brown tile of the game's emblem
local EMBLEM_BACK=Color3.fromRGB(104,64,28)
local EMBLEM_EDGE=Color3.fromRGB(78,46,18)
local EMBLEM_IMAGE="rbxassetid://101208360819397" -- the white ringed planet
local TOP_WORD,MAIN_WORD="PLANET","EGGS"
local TAGS={"FOR"}
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
    -- app icon: the game's emblem, a white ringed planet on a brown tile (it flips on the beat,
    -- the planet bobs and tilts, a shine sweeps over it and two sparks ride the ring)
    local slot=make("Frame",frame,"IconSlot",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(110,146),Size=UDim2.fromOffset(170,170),ZIndex=zb})
    self.iconSlot=slot;self.iconHome=slot.Position;self.iconScale=make("UIScale",slot,"Pop")
    local icon=make("Frame",slot,"Icon",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),BackgroundColor3=EMBLEM,BorderSizePixel=0,ZIndex=zb+1,ClipsDescendants=true})
    make("UICorner",icon,"Round",{CornerRadius=UDim.new(.22,0)})
    make("UIStroke",icon,"Line",{Color=INK,Thickness=5})
    make("UIGradient",icon,"Shade",{Rotation=100,Color=ColorSequence.new(Color3.fromRGB(255,236,210),Color3.fromRGB(175,150,125))})
    local edge=make("Frame",slot,"Edge",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,9),Size=UDim2.fromScale(1,1),BackgroundColor3=EMBLEM_EDGE,BorderSizePixel=0,ZIndex=zb})
    make("UICorner",edge,"Round",{CornerRadius=UDim.new(.22,0)})
    make("UIStroke",edge,"Line",{Color=INK,Thickness=5})
    self.icon=icon;self.iconEdge=edge
    local planet=make("ImageLabel",icon,"Planet",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.86,.86),
        Image=EMBLEM_IMAGE,ScaleType=Enum.ScaleType.Fit,ZIndex=zb+3})
    self.view=planet
    -- a glossy band that sweeps across now and then
    local shine=make("Frame",icon,"Shine",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.72,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(-.6,.5),Size=UDim2.fromScale(.28,1.8),Rotation=24,ZIndex=zb+4})
    self.iconShine=shine
    -- two little sparks orbiting along the ring
    self.sparks={}
    for i=1,2 do
        local spark=make("Frame",icon,"Spark"..i,{BackgroundColor3=Color3.fromRGB(255,244,200),BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(12,12),ZIndex=zb+5})
        make("UICorner",spark,"Round",{CornerRadius=UDim.new(1,0)})
        self.sparks[i]=spark
    end
    -- row 1: PLANET in hot colours
    local x=ICON_W
    for i=1,#TOP_WORD do
        local l,w=letter(frame,"T"..i,TOP_WORD:sub(i,i),TOP_SIZE,x,TOP_BASE,FIRE[(i-1)%#FIRE+1],zb+2)
        self.top[i]=l;x+=w-3
    end
    local row1=x
    -- row 2: the little [FOR] tag, then EGGS in rainbow colours (reads PLANET / FOR EGGS)
    x=ICON_W+6
    for i,word in ipairs(TAGS) do
        local w=glyphWidth(word,TAG_SIZE)+30
        local tag=make("Frame",frame,"Tag"..i,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(x+w/2,MAIN_BASE-MAIN_SIZE*.42),Size=UDim2.fromOffset(w,TAG_SIZE+16),
            Rotation=-7,BackgroundColor3=INK,BorderSizePixel=0,ZIndex=zb+5})
        make("UICorner",tag,"Round",{CornerRadius=UDim.new(0,10)})
        make("UIStroke",tag,"Line",{Color=Color3.new(1,1,1),Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
        make("ImageLabel",tag,"Studs",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=STUD,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(22,22),ImageTransparency=.86,ZIndex=zb+6})
        make("TextLabel",tag,"Text",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Text=word,FontFace=TITLE_FONT,TextSize=TAG_SIZE,TextColor3=PALETTE.gold,ZIndex=zb+7})
        self.tags[i]={holder=tag,pop=make("UIScale",tag,"Pop"),home=tag.Position,rot=tag.Rotation,colour=PALETTE.gold}
        x+=w+16
    end
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
-- EGGS letter i / PLANET letter i: lift in logo pixels, pop scale, rotation
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

-- per-frame: emblem flip / bob / shine / sparks, icon wobble, letter shine sweeps, shake, confetti
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
    self.icon.BackgroundColor3=c>=0 and EMBLEM or EMBLEM_BACK
    self.view.Visible=c>0.15
    -- the planet bobs and tilts; a shine sweeps over every ~3 s; sparks ride the ring's ellipse
    self.view.Position=UDim2.new(.5,0,.5,math.sin(t*2.2)*5)
    self.view.Rotation=math.sin(t*1.3)*8
    local sweep=(t%3.2)/0.8
    self.iconShine.Position=UDim2.fromScale(sweep<=1 and (-.6+2.2*sweep) or 1.8,.5)
    for i,spark in ipairs(self.sparks) do
        local a=t*1.6+(i-1)*math.pi
        local x,y=math.cos(a)*.44,math.sin(a)*.16
        local r=math.rad(-22)
        spark.Position=UDim2.fromScale(.5+x*math.cos(r)-y*math.sin(r),.53+x*math.sin(r)+y*math.cos(r))
        spark.Visible=c>0.15 and math.sin(a)>-0.35
        spark.BackgroundTransparency=.1+.3*(1-math.abs(math.sin(a)))
    end
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
