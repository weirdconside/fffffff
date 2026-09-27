-- Admin Vault window + the crown shop button. Presentation only: every purchase
-- goes through DonationServer and Roblox's own purchase prompt.
local RunService=game:GetService('RunService')
local Workspace=game:GetService('Workspace')
local MarketplaceService=game:GetService('MarketplaceService')
local TweenService=game:GetService('TweenService')
local Theme=require(script.Parent.StudTheme)
local Icons=require(script.Parent.ShopIcons)
local C=Theme.Colors
local Shop={};Shop.__index=Shop
local W,H=760,520
local ROYAL=Color3.fromRGB(111,54,170)
local function make(class,parent,name,props)
    local o=Instance.new(class);o.Name=name or class
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent;return o
end
local function label(parent,name,text,size,color,props)
    local o=make('TextLabel',parent,name,props);o.BackgroundTransparency=1;o.Text=text
    Theme.text(o,size,color);return o
end
local function round(o,r) make('UICorner',o,'Round',{CornerRadius=r or UDim.new(1,0)}) end
local function stroke(o,color,thickness) make('UIStroke',o,'Line',{Color=color or C.Ink,Thickness=thickness or 2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
-- Crown glyph drawn with frames (used on the shop button).
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
local function priceText(shop,item)
    local info=shop.prices[item.key]
    local price=info or item.price
    return 'R$ '..tostring(price)
end
function Shop.new(parent,remote,catalog)
    local self=setmetatable({parent=parent,remote=remote,catalog=catalog,open=false,passes={},tokens={},studio=RunService:IsStudio(),
        prices={},cards={},glyphs={},connections={},tab='Powers',available=true,hiddenByIntro=false},Shop)
    local gui=make('ScreenGui',parent,'DonationShop',{ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=58,ZIndexBehavior=Enum.ZIndexBehavior.Sibling});self.gui=gui
    -- ------------------------------------------------------------ shop button (new icon)
    local holder=make('Frame',gui,'ShopButton',{BackgroundTransparency=1,AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-14,.5,0),Size=UDim2.fromOffset(84,100),ZIndex=5})
    local button=make('TextButton',holder,'Open',{Text='',AutoButtonColor=false,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,4),Size=UDim2.fromOffset(72,72),ZIndex=6,Rotation=-4})
    Theme.skin(button,ROYAL)
    local shine=make('Frame',button,'Shine',{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=0,Size=UDim2.fromScale(1,1),ZIndex=12,BorderSizePixel=0})
    round(shine,UDim.new(0,5))
    local grad=make('UIGradient',shine,'Sweep',{Rotation=25,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.42,1),NumberSequenceKeypoint.new(.5,.55),NumberSequenceKeypoint.new(.58,1),NumberSequenceKeypoint.new(1,1)}),Offset=Vector2.new(-1,0)})
    crownGlyph(button,8)
    local plate=make('Frame',holder,'Plate',{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,66),Size=UDim2.fromOffset(78,26),ZIndex=14})
    Theme.skin(plate,C.Gold)
    label(plate,'Caption','SHOP',17,C.Ink,{Size=UDim2.fromScale(1,1),ZIndex=16})
    local badge=make('Frame',holder,'Robux',{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(74,8),Size=UDim2.fromOffset(28,28),ZIndex=15,BackgroundColor3=C.Green,BorderSizePixel=0})
    round(badge);stroke(badge,C.Ink,2)
    label(badge,'R','R$',12,C.White,{Size=UDim2.fromScale(1,1),ZIndex=17})
    self.button=holder
    -- ------------------------------------------------------------ window
    local shade=make('TextButton',gui,'Shade',{Text='',AutoButtonColor=false,Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(12,10,20),BackgroundTransparency=.35,Visible=false,ZIndex=20,BorderSizePixel=0})
    self.shade=shade
    local card=make('Frame',gui,'Card',{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(W,H),Visible=false,ZIndex=21,Active=true})
    Theme.skin(card,C.Panel);self.card=card
    self.scale=make('UIScale',card,'Fit')
    local header=make('Frame',card,'Header',{Position=UDim2.fromOffset(10,10),Size=UDim2.new(1,-20,0,64),ZIndex=22});Theme.skin(header,ROYAL)
    local headIcon=make('Frame',header,'IconHolder',{BackgroundTransparency=1,Position=UDim2.fromOffset(6,2),Size=UDim2.fromOffset(60,60),ZIndex=24})
    local _,headGlyph=Icons.build(headIcon,'Crown',{zindex=25,fov=30});self.headGlyph=headGlyph
    label(header,'Title','ADMIN VAULT',30,C.Gold,{Position=UDim2.fromOffset(72,6),Size=UDim2.new(1,-150,0,32),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=26})
    label(header,'Subtitle','ROBUX ONLY  -  POWERS FOR THE ADMIN PANEL',13,C.White,{Position=UDim2.fromOffset(74,38),Size=UDim2.new(1,-150,0,18),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=26})
    local close=make('TextButton',header,'Close',{Text='X',AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-10,.5,0),Size=UDim2.fromOffset(44,44),ZIndex=27})
    Theme.button(close,C.Red,20)
    -- tabs + wallet
    local tabs=make('Frame',card,'Tabs',{BackgroundTransparency=1,Position=UDim2.fromOffset(12,82),Size=UDim2.new(1,-24,0,40),ZIndex=22})
    make('UIListLayout',tabs,'Row',{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center})
    self.tabButtons={}
    for i,tab in ipairs(catalog.Tabs) do
        local b=make('TextButton',tabs,tab.id,{Text=tab.title,LayoutOrder=i,Size=UDim2.fromOffset(150,38),ZIndex=23})
        Theme.button(b,C.Dark,15);self.tabButtons[tab.id]=b
        self.connections[#self.connections+1]=b.Activated:Connect(function() self:selectTab(tab.id) end)
    end
    local wallet=make('Frame',tabs,'Wallet',{LayoutOrder=10,Size=UDim2.fromOffset(222,38),ZIndex=23});Theme.skin(wallet,C.Dark)
    self.wallet=label(wallet,'Text','TOKENS 0  -  DROPS 0',14,C.Gold,{Size=UDim2.fromScale(1,1),ZIndex=25})
    -- items
    local scroll=make('ScrollingFrame',card,'Items',{Position=UDim2.fromOffset(12,130),Size=UDim2.new(1,-24,1,-176),BackgroundTransparency=1,BorderSizePixel=0,
        ScrollBarThickness=7,ScrollBarImageColor3=C.Gold,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=22})
    make('UIGridLayout',scroll,'Grid',{CellSize=UDim2.fromOffset(234,232),CellPadding=UDim2.fromOffset(8,8),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center})
    make('UIPadding',scroll,'Pad',{PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,8)})
    self.items=scroll
    for _,item in ipairs(catalog.list()) do
        local box=make('Frame',scroll,item.key,{LayoutOrder=item.order,ZIndex=23});Theme.skin(box,C.Card)
        local disc=make('Frame',box,'Disc',{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,10),Size=UDim2.fromOffset(92,92),BackgroundColor3=item.color,ZIndex=24,BorderSizePixel=0})
        round(disc);stroke(disc,C.Ink,3)
        make('UIGradient',disc,'Light',{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(170,170,170))})
        local _,glyph=Icons.build(disc,item.icon,{zindex=26,size=UDim2.fromScale(1.35,1.35)})
        self.glyphs[#self.glyphs+1]={model=glyph,seed=item.order*1.7}
        label(box,'Name',item.title,17,C.Gold,{Position=UDim2.fromOffset(8,106),Size=UDim2.new(1,-16,0,22),ZIndex=26})
        local detail=label(box,'Detail',item.detail,12,C.Muted,{Position=UDim2.fromOffset(12,130),Size=UDim2.new(1,-24,0,52),ZIndex=26,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
        detail.TextWrapped=true
        local buy=make('TextButton',box,'Buy',{Text='R$ '..item.price,AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-9),Size=UDim2.new(1,-24,0,38),ZIndex=27})
        Theme.button(buy,C.Green,18)
        if item.badge then
            local rib=make('Frame',box,'Badge',{Position=UDim2.fromOffset(-6,8),Size=UDim2.fromOffset(62,24),Rotation=-12,ZIndex=29});Theme.skin(rib,C.Red)
            label(rib,'Text',item.badge,14,C.White,{Size=UDim2.fromScale(1,1),ZIndex=31})
        end
        self.cards[item.key]={frame=box,buy=buy,item=item}
        self.connections[#self.connections+1]=buy.Activated:Connect(function() self:buy(item) end)
    end
    self.status=label(card,'Status','Choose a power. Every purchase uses the official Roblox prompt.',13,C.White,{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,16,1,-12),Size=UDim2.new(1,-32,0,24),ZIndex=26,TextXAlignment=Enum.TextXAlignment.Left})
    -- ------------------------------------------------------------ behaviour
    local function setOpen(v)
        self.open=v==true;shade.Visible=self.open;card.Visible=self.open;holder.Visible=not self.open and self.available and not self.hiddenByIntro
        if self.open then
            self.scale.Scale=.85;TweenService:Create(self.scale,TweenInfo.new(.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=self:fitScale()}):Play()
            self:refresh();self:fetchPrices()
        end
    end
    self.setOpen=setOpen
    self.connections[#self.connections+1]=button.Activated:Connect(function() setOpen(true) end)
    self.connections[#self.connections+1]=close.Activated:Connect(function() setOpen(false) end)
    self.connections[#self.connections+1]=shade.Activated:Connect(function() setOpen(false) end)
    self.connections[#self.connections+1]=button.MouseEnter:Connect(function() TweenService:Create(button,TweenInfo.new(.15),{Size=UDim2.fromOffset(78,78)}):Play() end)
    self.connections[#self.connections+1]=button.MouseLeave:Connect(function() TweenService:Create(button,TweenInfo.new(.15),{Size=UDim2.fromOffset(72,72)}):Play() end)
    local clock,fitClock=0,0
    self.connections[#self.connections+1]=RunService.RenderStepped:Connect(function(dt)
        clock+=dt
        if holder.Visible then
            button.Rotation=-4+math.sin(clock*1.6)*3
            button.Position=UDim2.new(.5,0,0,4+math.sin(clock*2.1)*2)
            grad.Offset=Vector2.new(((clock%3.2)/3.2)*3-1.5,0)
        end
        if self.open then
            for _,g in ipairs(self.glyphs) do Icons.spin(g.model,clock,g.seed) end
            Icons.spin(self.headGlyph,clock,0,.8)
            fitClock+=dt;if fitClock>.3 then fitClock=0;self.scale.Scale=self:fitScale() end
        end
    end)
    self:selectTab('Powers')
    return self
end
function Shop:fitScale()
    local camera=Workspace.CurrentCamera;if not camera then return 1 end
    local v=camera.ViewportSize
    return math.clamp(math.min((v.X-20)/W,(v.Y-20)/H),.45,1.15)
end
function Shop:selectTab(id)
    self.tab=id
    for key,b in pairs(self.tabButtons) do b.BackgroundColor3=key==id and C.Gold or C.Dark;b.TextColor3=key==id and C.Ink or C.White end
    for _,card in pairs(self.cards) do card.frame.Visible=card.item.tab==id end
    self.items.CanvasPosition=Vector2.new()
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
    local tokens=self.tokens or {}
    self.wallet.Text='TOKENS '..tostring(tokens.AdminToken or 0)..'  -  DROPS '..tostring(tokens.SupplyDrop or 0)
    for key,card in pairs(self.cards) do
        local item=card.item;local b=card.buy
        if item.kind=='Pass' and self.passes[key] then b.Text='OWNED';b.BackgroundColor3=C.Dark;b.TextColor3=C.Gold
        elseif not self.catalog.configured(item) then
            b.Text=self.studio and ('TEST  R$ '..item.price) or 'SOON';b.BackgroundColor3=self.studio and C.Blue or C.Dark;b.TextColor3=C.White
        else b.Text=priceText(self,item);b.BackgroundColor3=C.Green;b.TextColor3=C.White end
    end
end
function Shop:buy(item)
    if item.kind=='Pass' and self.passes[item.key] then self.status.Text='You already own '..item.title..'.';return end
    self.status.Text='Opening the Roblox purchase window...'
    self.remote:FireServer('Buy',item.key)
end
function Shop:applyState(payload)
    if type(payload)~='table' then return end
    self.passes=type(payload.passes)=='table' and payload.passes or {}
    self.tokens=type(payload.tokens)=='table' and payload.tokens or {}
    if payload.studio~=nil then self.studio=payload.studio==true end
    if payload.message then self.status.Text=payload.message end
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
