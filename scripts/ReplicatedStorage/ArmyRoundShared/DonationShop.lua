-- Admin Shop window + the crown shop button. Presentation only: every purchase
-- goes through DonationServer and Roblox's own purchase prompt.
local RunService=game:GetService('RunService')
local Workspace=game:GetService('Workspace')
local MarketplaceService=game:GetService('MarketplaceService')
local TweenService=game:GetService('TweenService')
local Theme=require(script.Parent.StudTheme)
local Icons=require(script.Parent.ShopIcons)
local UISound=require(script.Parent.UISound)
local C=Theme.Colors
local Shop={};Shop.__index=Shop
local W,H=836,586
local ROYAL=Color3.fromRGB(111,54,170)
local NIGHT=Color3.fromRGB(52,44,66)
local function make(class,parent,name,props)
    local o=Instance.new(class);o.Name=name or class
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent;return o
end
local HEADLINES={Title=true,PassesTitle=true,TicketsTitle=true,Name=true,Amount=true,Count=true,Caption=true,Text=true}
local function label(parent,name,text,size,color,props)
    local o=make('TextLabel',parent,name,props);o.BackgroundTransparency=1;o.Text=text
    if HEADLINES[name] and size>=14 then Theme.headline(o,size,color) else Theme.text(o,size,color) end
    return o
end
local function round(o,r) make('UICorner',o,'Round',{CornerRadius=r or UDim.new(1,0)}) end
local function stroke(o,color,thickness,transparency)
    return make('UIStroke',o,'Line',{Color=color or C.Ink,Thickness=thickness or 2,Transparency=transparency or 0,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
local function lighten(c,k) return c:Lerp(Color3.new(1,1,1),k) end
local function darken(c,k) return c:Lerp(Color3.new(0,0,0),k) end
-- Crown glyph drawn with frames (shop button).
local function crownGlyph(parent,z)
    local g=make('Frame',parent,'Crown',{BackgroundTransparency=1,Size=UDim2.fromOffset(46,34),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.44,0),ZIndex=z})
    local band=make('Frame',g,'Band',{BackgroundColor3=C.Gold,Size=UDim2.fromOffset(42,13),Position=UDim2.fromOffset(2,20),ZIndex=z+2,BorderSizePixel=0})
    round(band,UDim.new(0,3));stroke(band,C.Ink,2)
    for i,x in ipairs({6,23,40}) do
        local tall=i==2
        local spike=make('Frame',g,'Spike'..i,{BackgroundColor3=C.Gold,Size=UDim2.fromOffset(tall and 15 or 12,tall and 15 or 12),AnchorPoint=Vector2.new(.5,.5),
            Position=UDim2.fromOffset(x,tall and 14 or 17),Rotation=45,ZIndex=z+1,BorderSizePixel=0})
        round(spike,UDim.new(0,2));stroke(spike,C.Ink,2)
        local pearl=make('Frame',g,'Pearl'..i,{BackgroundColor3=C.White,Size=UDim2.fromOffset(7,7),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(x,tall and 3 or 8),ZIndex=z+3,BorderSizePixel=0})
        round(pearl);stroke(pearl,C.Ink,1.5)
    end
    for i,col in ipairs({Color3.fromRGB(226,35,31),Color3.fromRGB(52,158,216),Color3.fromRGB(64,192,29)}) do
        local gem=make('Frame',g,'Gem'..i,{BackgroundColor3=col,Size=UDim2.fromOffset(7,7),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(8+(i-1)*15,26.5),ZIndex=z+4,BorderSizePixel=0})
        round(gem)
    end
    return g
end
-- Soft light rays that spin slowly behind featured icons.
local function rays(parent,z,size,colour)
    local holder=make('Frame',parent,'Rays',{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(size,size),ZIndex=z})
    for i=0,5 do
        local ray=make('Frame',holder,'Ray'..i,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(0,14,1,0),Rotation=i*30,
            BackgroundColor3=colour,BackgroundTransparency=.55,BorderSizePixel=0,ZIndex=z})
        make('UIGradient',ray,'Fade',{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.2),NumberSequenceKeypoint.new(1,1)})})
        round(ray,UDim.new(.5,0))
    end
    local glow=make('Frame',holder,'Glow',{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.62,.62),BackgroundColor3=colour,BackgroundTransparency=.45,BorderSizePixel=0,ZIndex=z})
    round(glow)
    make('UIGradient',glow,'Fade',{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(1,1)}),Rotation=0})
    return holder,glow
end
local function badge(parent,text,color,z,pos)
    local rib=make('Frame',parent,'Badge',{Position=pos or UDim2.fromOffset(-8,10),Size=UDim2.fromOffset(math.max(62,#text*11+18),26),Rotation=-10,ZIndex=z})
    Theme.skin(rib,color)
    label(rib,'Text',text,14,C.White,{Size=UDim2.fromScale(1,1),ZIndex=z+3})
    return rib
end
local function hover(self,frame)
    local scale=make('UIScale',frame,'Hover')
    self.connections[#self.connections+1]=frame.MouseEnter:Connect(function() TweenService:Create(scale,TweenInfo.new(.14,Enum.EasingStyle.Quad),{Scale=1.035}):Play() end)
    self.connections[#self.connections+1]=frame.MouseLeave:Connect(function() TweenService:Create(scale,TweenInfo.new(.14,Enum.EasingStyle.Quad),{Scale=1}):Play() end)
end
function Shop.new(parent,remote,catalog)
    local self=setmetatable({parent=parent,remote=remote,catalog=catalog,open=false,passes={},tokens={},studio=RunService:IsStudio(),
        prices={},cards={},glyphs={},spinners={},glows={},sparkles={},connections={},available=true,hiddenByIntro=false},Shop)
    local gui=make('ScreenGui',parent,'DonationShop',{ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=58,ZIndexBehavior=Enum.ZIndexBehavior.Sibling});self.gui=gui
    Theme.safe(gui)
    -- ------------------------------------------------------------ shop button
    local holder=make('Frame',gui,'ShopButton',{BackgroundTransparency=1,AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-10,.4,0),Size=UDim2.fromOffset(84,100),ZIndex=5})
    local buttonFit=make('UIScale',holder,'Fit')
    local button=make('TextButton',holder,'Open',{Text='',AutoButtonColor=false,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,4),Size=UDim2.fromOffset(72,72),ZIndex=6,Rotation=-4})
    Theme.skin(button,ROYAL);button:SetAttribute('UISound','open')
    local shine=make('Frame',button,'Shine',{BackgroundColor3=Color3.new(1,1,1),Size=UDim2.fromScale(1,1),ZIndex=12,BorderSizePixel=0});round(shine,UDim.new(0,5))
    local grad=make('UIGradient',shine,'Sweep',{Rotation=25,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.42,1),NumberSequenceKeypoint.new(.5,.55),NumberSequenceKeypoint.new(.58,1),NumberSequenceKeypoint.new(1,1)}),Offset=Vector2.new(-1,0)})
    crownGlyph(button,8)
    local plate=make('Frame',holder,'Plate',{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,66),Size=UDim2.fromOffset(78,26),ZIndex=14});Theme.skin(plate,C.Gold)
    label(plate,'Caption','SHOP',17,C.Ink,{Size=UDim2.fromScale(1,1),ZIndex=16})
    local rbadge=make('Frame',holder,'Robux',{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(74,8),Size=UDim2.fromOffset(28,28),ZIndex=15,BackgroundColor3=C.Green,BorderSizePixel=0})
    round(rbadge);stroke(rbadge,C.Ink,2);label(rbadge,'R','R$',12,C.White,{Size=UDim2.fromScale(1,1),ZIndex=17})
    self.button=holder
    -- ------------------------------------------------------------ window
    local shade=make('TextButton',gui,'Shade',{Text='',AutoButtonColor=false,Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(10,8,20),BackgroundTransparency=.3,Visible=false,ZIndex=20,BorderSizePixel=0})
    self.shade=shade
    local card=make('Frame',gui,'Card',{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(W,H),Visible=false,ZIndex=21,Active=true})
    Theme.skin(card,NIGHT);self.card=card;self.scale=make('UIScale',card,'Fit')
    make('UIGradient',card,'Tone',{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(190,180,210))})
    -- header
    local header=make('Frame',card,'Header',{Position=UDim2.fromOffset(10,10),Size=UDim2.new(1,-20,0,72),ZIndex=22});Theme.skin(header,ROYAL)
    make('UIGradient',header,'Tone',{Rotation=0,Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(150,170,255))})
    local headIcon=make('Frame',header,'IconHolder',{BackgroundTransparency=1,Position=UDim2.fromOffset(6,4),Size=UDim2.fromOffset(64,64),ZIndex=24})
    local _,headGlyph=Icons.build(headIcon,'Crown',{zindex=25,fov=30});self.headGlyph=headGlyph
    label(header,'Title','ADMIN SHOP',32,C.Gold,{Position=UDim2.fromOffset(76,6),Size=UDim2.new(1,-330,0,36),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=26})
    label(header,'Subtitle','ROBUX ONLY  -  BE THE ONE WHO TYPES THE COMMAND',13,C.White,{Position=UDim2.fromOffset(78,42),Size=UDim2.new(1,-330,0,18),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=26})
    for i=1,9 do
        -- twinkles live in the empty strip right of the title, never behind lettering
        local sp=make('Frame',header,'Sparkle'..i,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(300+(i-1)*30,10+((i*37)%26)),Size=UDim2.fromOffset(6,6),Rotation=45,
            BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=24})
        self.sparkles[#self.sparkles+1]={frame=sp,seed=i*1.9}
    end
    local wallet=make('Frame',header,'Wallet',{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-66,.5,0),Size=UDim2.fromOffset(176,46),ZIndex=24});Theme.skin(wallet,C.Dark)
    local walletIcon=make('Frame',wallet,'Icon',{BackgroundTransparency=1,Position=UDim2.fromOffset(2,0),Size=UDim2.fromOffset(52,46),ZIndex=25})
    local _,walletGlyph=Icons.build(walletIcon,'Ticket',{zindex=26,count=1,fov=34});self.walletGlyph=walletGlyph
    label(wallet,'Caption','YOUR TICKETS',11,C.Muted,{Position=UDim2.fromOffset(56,4),Size=UDim2.new(1,-62,0,14),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=27})
    self.wallet=label(wallet,'Count','0',22,C.Gold,{Position=UDim2.fromOffset(56,17),Size=UDim2.new(1,-62,0,24),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=27})
    local close=make('TextButton',header,'Close',{Text='X',AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-10,.5,0),Size=UDim2.fromOffset(46,46),ZIndex=27});Theme.button(close,C.Red,20)
    -- ---------------------------------------------------------- passes
    label(card,'PassesTitle','PASSES',18,C.Gold,{Position=UDim2.fromOffset(20,90),Size=UDim2.fromOffset(200,22),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=23})
    local passes=catalog.passes()
    for i,item in ipairs(passes) do
        local x=12+(i-1)*((W-24)/2)
        local box=make('Frame',card,item.key,{Position=UDim2.fromOffset(x+4,116),Size=UDim2.fromOffset((W-24)/2-8,212),ZIndex=23});Theme.skin(box,item.color)
        make('UIGradient',box,'Tone',{Rotation=90,Color=ColorSequence.new(lighten(item.color,.25),darken(item.color,.25))})
        hover(self,box)
        local glowStroke=stroke(box,item.accent,4,1);glowStroke.Name='OwnedGlow'
        local iconArea=make('Frame',box,'IconArea',{BackgroundTransparency=1,Position=UDim2.fromOffset(6,6),Size=UDim2.fromOffset(150,150),ZIndex=24})
        local rayHolder,glow=rays(iconArea,24,190,lighten(item.color,.6))
        self.spinners[#self.spinners+1]=rayHolder;self.glows[#self.glows+1]=glow
        local _,glyph=Icons.build(iconArea,item.icon,{zindex=27,size=UDim2.fromScale(1.05,1.05),fov=30})
        self.glyphs[#self.glyphs+1]={model=glyph,seed=i*2.1}
        local title=label(box,'Name',item.title,34,C.White,{Position=UDim2.fromOffset(160,10),Size=UDim2.new(1,-170,0,38),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=27})
        title.TextStrokeTransparency=0;title.TextStrokeColor3=C.Ink
        local list=make('Frame',box,'Perks',{BackgroundTransparency=1,Position=UDim2.fromOffset(160,52),Size=UDim2.new(1,-170,0,96),ZIndex=26})
        make('UIListLayout',list,'List',{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder})
        for k,line in ipairs(item.perks or {}) do
            local row=make('Frame',list,'Perk'..k,{BackgroundTransparency=1,Size=UDim2.new(1,0,0,28),LayoutOrder=k,ZIndex=26})
            local dot=make('Frame',row,'Dot',{AnchorPoint=Vector2.new(0,.5),Position=UDim2.new(0,0,.5,0),Size=UDim2.fromOffset(16,16),BackgroundColor3=item.accent,BorderSizePixel=0,ZIndex=27})
            round(dot);stroke(dot,C.Ink,2)
            local t=label(row,'Text',line,13,C.White,{Position=UDim2.fromOffset(24,0),Size=UDim2.new(1,-24,1,0),TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,ZIndex=27})
            t.TextWrapped=true;t.TextStrokeTransparency=.4;t.TextStrokeColor3=C.Ink
        end
        local buy=make('TextButton',box,'Buy',{Text='R$ '..item.price,AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-12,1,-12),Size=UDim2.fromOffset(170,44),ZIndex=28})
        Theme.button(buy,C.Green,20)
        if item.badge then badge(box,item.badge,C.Red,30) end
        self.cards[item.key]={frame=box,buy=buy,item=item,glow=glowStroke}
        self.connections[#self.connections+1]=buy.Activated:Connect(function() self:buy(item) end)
    end
    -- ---------------------------------------------------------- tickets
    label(card,'TicketsTitle','TICKETS',18,C.Gold,{Position=UDim2.fromOffset(20,338),Size=UDim2.fromOffset(120,22),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=23})
    label(card,'TicketsHelp',catalog.TicketHelp or '',12,C.Muted,{Position=UDim2.fromOffset(130,340),Size=UDim2.new(1,-150,0,20),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=23})
    local packs=catalog.tickets()
    local cw=(W-24-4*8)/#packs
    for i,item in ipairs(packs) do
        local box=make('Frame',card,item.key,{Position=UDim2.fromOffset(12+(i-1)*(cw+8),364),Size=UDim2.fromOffset(cw,176),ZIndex=23});Theme.skin(box,Color3.fromRGB(78,66,104))
        make('UIGradient',box,'Tone',{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(180,170,200))})
        hover(self,box)
        local art=make('Frame',box,'Art',{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,4),Size=UDim2.fromOffset(cw-12,86),ZIndex=24})
        local _,glow=rays(art,24,120,Color3.fromRGB(255,214,90));self.glows[#self.glows+1]=glow
        local _,glyph=Icons.build(art,'Ticket',{zindex=26,count=item.count,fov=34,size=UDim2.fromScale(1.1,1.2)})
        self.glyphs[#self.glyphs+1]={model=glyph,seed=i*1.3,amount=.3}
        local amount=label(box,'Amount','x'..item.count,28,C.Gold,{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,88),Size=UDim2.new(1,-8,0,32),ZIndex=27})
        amount.TextStrokeTransparency=0;amount.TextStrokeColor3=C.Ink
        local buy=make('TextButton',box,'Buy',{Text='R$ '..item.price,AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-10),Size=UDim2.new(1,-18,0,36),ZIndex=28})
        Theme.button(buy,C.Green,17)
        if item.badge then badge(box,item.badge,item.badge=='BEST VALUE' and C.Red or C.Blue,30,UDim2.fromOffset(-6,6)) end
        self.cards[item.key]={frame=box,buy=buy,item=item}
        self.connections[#self.connections+1]=buy.Activated:Connect(function() self:buy(item) end)
    end
    self.status=label(card,'Status','Every purchase uses the official Roblox window.',13,C.White,{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,16,1,-10),Size=UDim2.new(1,-32,0,22),ZIndex=26,TextXAlignment=Enum.TextXAlignment.Left})
    -- ------------------------------------------------------------ behaviour
    local function setOpen(v)
        self.open=v==true;shade.Visible=self.open;card.Visible=self.open;holder.Visible=not self.open and self.available and not self.hiddenByIntro
        if self.open then
            self.scale.Scale=.82;TweenService:Create(self.scale,TweenInfo.new(.25,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=self:fitScale()}):Play()
            shade.BackgroundTransparency=1;TweenService:Create(shade,TweenInfo.new(.2),{BackgroundTransparency=.3}):Play()
            self:refresh();self:fetchPrices()
        end
    end
    self.setOpen=setOpen
    self.connections[#self.connections+1]=button.Activated:Connect(function() setOpen(true) end)
    self.connections[#self.connections+1]=close.Activated:Connect(function() setOpen(false) end)
    self.connections[#self.connections+1]=shade.Activated:Connect(function() setOpen(false) end)
    self.connections[#self.connections+1]=button.MouseEnter:Connect(function() TweenService:Create(button,TweenInfo.new(.15),{Size=UDim2.fromOffset(78,78)}):Play() end)
    self.connections[#self.connections+1]=button.MouseLeave:Connect(function() TweenService:Create(button,TweenInfo.new(.15),{Size=UDim2.fromOffset(72,72)}):Play() end)
    local clock,fitClock,buttonClock=0,0,1
    self.connections[#self.connections+1]=RunService.RenderStepped:Connect(function(dt)
        clock+=dt
        buttonClock+=dt
        if buttonClock>=.5 then
            buttonClock=0
            local camera=Workspace.CurrentCamera
            if camera then buttonFit.Scale=math.clamp(camera.ViewportSize.Y/640,.62,1) end
        end
        if holder.Visible then
            button.Rotation=-4+math.sin(clock*1.6)*3
            button.Position=UDim2.new(.5,0,0,4+math.sin(clock*2.1)*2)
            grad.Offset=Vector2.new(((clock%3.2)/3.2)*3-1.5,0)
        end
        if self.open then
            for _,g in ipairs(self.glyphs) do Icons.spin(g.model,clock,g.seed,g.amount) end
            Icons.spin(self.headGlyph,clock,0,.8);Icons.spin(self.walletGlyph,clock,1,.3)
            for i,r in ipairs(self.spinners) do r.Rotation=(clock*18*(i%2==0 and -1 or 1))%360 end
            for i,g in ipairs(self.glows) do g.BackgroundTransparency=.5+math.sin(clock*2.4+i)*.12 end
            for _,sp in ipairs(self.sparkles) do
                local k=(math.sin(clock*3+sp.seed)+1)/2
                sp.frame.BackgroundTransparency=1-k*.9;sp.frame.Size=UDim2.fromOffset(3+k*5,3+k*5)
            end
            local pulse=(math.sin(clock*3)+1)/2
            for _,c in pairs(self.cards) do if c.glow and c.owned then c.glow.Transparency=.1+pulse*.4 end end
            fitClock+=dt;if fitClock>.3 then fitClock=0;self.scale.Scale=self:fitScale() end
        end
    end)
    return self
end
function Shop:fitScale()
    local camera=Workspace.CurrentCamera;if not camera then return 1 end
    local v=camera.ViewportSize
    return math.clamp(math.min((v.X-20)/W,(v.Y-20)/H),.4,1.15)
end
function Shop:fetchPrices()
    if self.fetching then return end;self.fetching=true
    task.spawn(function()
        for _,item in ipairs(self.catalog.list()) do
            if self.catalog.configured(item) and not self.prices[item.key] then
                local ok,info=pcall(function()
                    return MarketplaceService:GetProductInfo(item.id,item.kind=='Pass' and Enum.InfoType.GamePass or Enum.InfoType.Product)
                end)
                if ok and type(info)=='table' and tonumber(info.PriceInRobux) then self.prices[item.key]=info.PriceInRobux end
            end
        end
        self.fetching=false;self:refresh()
    end)
end
function Shop:refresh()
    self.wallet.Text=tostring((self.tokens or {}).Ticket or 0)
    for key,card in pairs(self.cards) do
        local item=card.item;local b=card.buy
        card.owned=item.kind=='Pass' and self.passes[key]==true
        if card.glow then card.glow.Transparency=card.owned and .2 or 1 end
        if card.owned then b.Text='OWNED';b.BackgroundColor3=C.Dark;b.TextColor3=C.Gold
        elseif self.owner then b.Text='FREE';b.BackgroundColor3=C.Green;b.TextColor3=C.White
        elseif not self.catalog.configured(item) then
            b.Text=self.studio and ('TEST R$ '..item.price) or 'SOON';b.BackgroundColor3=self.studio and C.Blue or C.Dark;b.TextColor3=C.White
        else b.Text='R$ '..tostring(self.prices[key] or item.price);b.BackgroundColor3=C.Green;b.TextColor3=C.White end
    end
end
function Shop:buy(item)
    if item.kind=='Pass' and self.passes[item.key] then self.status.Text='You already own '..item.title..'.';return end
    self.status.Text=self.owner and 'OWNER: it is free for you!' or 'Opening the Roblox purchase window...'
    self.remote:FireServer('Buy',item.key)
end
function Shop:applyState(payload)
    if type(payload)~='table' then return end
    self.passes=type(payload.passes)=='table' and payload.passes or {}
    self.tokens=type(payload.tokens)=='table' and payload.tokens or {}
    if payload.studio~=nil then self.studio=payload.studio==true end
    self.owner=payload.owner==true
    if payload.message then
        local m=payload.message
        if m:find('granted') or m:find('Thank you') or m:find('Unlocked') or m:find('FREE') then UISound.play('success') end
        self.status.Text=m;self.status.TextColor3=C.Gold
        TweenService:Create(self.status,TweenInfo.new(1.2),{TextColor3=C.White}):Play()
    end
    self:refresh()
end
function Shop:openShop() if self.available and not self.hiddenByIntro then self.setOpen(true) end end
function Shop:closeShop() self.setOpen(false) end
function Shop:isBlocking() return self.open end
function Shop:setAvailable(value)
    self.available=value==true
    if not self.available then self.setOpen(false) end
    self.button.Visible=self.available and not self.open and not self.hiddenByIntro
end
function Shop:setIntro(active)
    self.hiddenByIntro=active==true
    if self.hiddenByIntro then self.setOpen(false) end
    self.button.Visible=self.available and not self.open and not self.hiddenByIntro
end
function Shop:destroy() for _,c in ipairs(self.connections) do c:Disconnect() end;if self.gui then self.gui:Destroy() end end
return Shop
