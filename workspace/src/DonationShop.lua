-- donor-style shop surface. Uses the donor's inlet texture, bevel, gold outline,
-- Roblox's Legacy font and outlined white labels without copying donor product logic.
local RunService=game:GetService('RunService')
local Workspace=game:GetService('Workspace')
local Theme=require(script.Parent.StudTheme)
local Shop={};Shop.__index=Shop
local INLET='rbxassetid://103855926983380'
local BEVEL='rbxassetid://74603642649742'
local GOLD=Color3.fromRGB(255,208,66)
local WHITE=Color3.fromRGB(255,255,255)
local function make(class,parent,name)local o=Instance.new(class);o.Name=name or class;o.Parent=parent;return o end
local function text(o,size,color)
 o.BackgroundTransparency=1;o.Font=Enum.Font.Legacy;o.TextSize=size;o.TextColor3=color or WHITE;o.TextStrokeColor3=Color3.new(0,0,0);o.TextStrokeTransparency=0;o.TextWrapped=true;return o
end
local function frame(parent,name,size,pos,color)
 local o=make('Frame',parent,name);o.Size=size;o.Position=pos;o.BackgroundColor3=color or Color3.fromRGB(42,42,42);o.BorderSizePixel=0
 local c=make('UICorner',o,'UICorner');c.CornerRadius=UDim.new(0,7)
 local st=make('UIStroke',o,'UIStroke');st.Color=GOLD;st.Thickness=2.6
 local inlet=make('ImageLabel',o,'InletTexture');inlet.BackgroundTransparency=1;inlet.Size=UDim2.fromScale(1,1);inlet.Image=INLET;inlet.ScaleType=Enum.ScaleType.Tile;inlet.TileSize=UDim2.fromOffset(32,32);inlet.ImageTransparency=.78;inlet.ZIndex=o.ZIndex
 local bevel=make('ImageLabel',o,'BevelEffect');bevel.BackgroundTransparency=1;bevel.Size=UDim2.fromScale(1,1);bevel.Image=BEVEL;bevel.ScaleType=Enum.ScaleType.Slice;bevel.SliceCenter=Rect.new(13,13,129,129);bevel.SliceScale=.3;bevel.ImageTransparency=.32;bevel.ZIndex=o.ZIndex+1
 return o
end
function Shop.new(parent,remote,catalog)
 local self=setmetatable({parent=parent,remote=remote,catalog=catalog,open=false,owned={},equipped=nil,preview=nil,connections={}},Shop)
 local gui=make('ScreenGui',parent,'DonationShop');gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=58;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;self.gui=gui
 local open=make('TextButton',gui,'OpenButton');open.AnchorPoint=Vector2.new(1,0);open.Position=UDim2.new(1,-18,0,18);open.Size=UDim2.fromOffset(148,45);open.Text='SHOP';open.ZIndex=5;Theme.button(open,Theme.Colors.Gold,19);self.openButton=open
 local shade=make('Frame',gui,'Shade');shade.Size=UDim2.fromScale(1,1);shade.BackgroundColor3=Color3.fromRGB(12,14,24);shade.BackgroundTransparency=.34;shade.Visible=false;shade.Active=true;shade.ZIndex=20;self.shade=shade
 local card=frame(gui,'Card',UDim2.fromOffset(600,540),UDim2.fromScale(.5,.5),Color3.fromRGB(30,32,38));card.AnchorPoint=Vector2.new(.5,.5);card.ZIndex=21;card.Visible=false;self.card=card
 local title=text(make('TextLabel',card,'Title'),27,GOLD);title.Position=UDim2.fromOffset(28,20);title.Size=UDim2.new(1,-130,0,36);title.Text='SHOP';title.TextXAlignment=Enum.TextXAlignment.Left;title.ZIndex=25
 local subtitle=text(make('TextLabel',card,'Subtitle'),13,WHITE);subtitle.Position=UDim2.fromOffset(30,57);subtitle.Size=UDim2.new(1,-60,0,22);subtitle.Text='COSMETICS • PREVIEW FREE';subtitle.TextXAlignment=Enum.TextXAlignment.Left;subtitle.ZIndex=25
 local close=make('TextButton',card,'Close');close.AnchorPoint=Vector2.new(1,0);close.Position=UDim2.new(1,-17,0,17);close.Size=UDim2.fromOffset(38,38);close.Text='X';close.ZIndex=27;Theme.button(close,Theme.Colors.Red,18);self.close=close
 local scroll=make('ScrollingFrame',card,'Items');scroll.Position=UDim2.fromOffset(22,90);scroll.Size=UDim2.new(1,-44,1,-145);scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.ScrollBarThickness=6;scroll.ScrollBarImageColor3=GOLD;scroll.CanvasSize=UDim2.fromOffset(0,0);scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y;scroll.ZIndex=22;self.items=scroll
 local grid=make('UIGridLayout',scroll,'Grid');grid.CellSize=UDim2.fromOffset(266,108);grid.CellPadding=UDim2.fromOffset(10,10);grid.SortOrder=Enum.SortOrder.LayoutOrder
 local status=text(make('TextLabel',card,'Status'),13,WHITE);status.Position=UDim2.fromOffset(28,card.Size.Y.Offset-48);status.Size=UDim2.new(1,-56,0,30);status.Text='Choose PREVIEW to try a style.';status.TextXAlignment=Enum.TextXAlignment.Left;status.ZIndex=25;self.status=status
 local byId={}
 for index,item in ipairs(catalog.list()) do
   local box=frame(scroll,item.id,UDim2.fromOffset(266,108),UDim2.new(),Color3.fromRGB(51,53,61));box.LayoutOrder=index;box.ZIndex=23;byId[item.id]=box
   local swatch=make('Frame',box,'Swatch');swatch.Position=UDim2.fromOffset(12,13);swatch.Size=UDim2.fromOffset(38,38);swatch.BackgroundColor3=item.color or (item.colors and item.colors[1]) or GOLD;swatch.BorderSizePixel=0;swatch.ZIndex=26;local sc=make('UICorner',swatch);sc.CornerRadius=UDim.new(1,0)
   local nm=text(make('TextLabel',box,'Name'),14,WHITE);nm.Position=UDim2.fromOffset(60,9);nm.Size=UDim2.new(1,-150,0,24);nm.Text=item.title;nm.TextXAlignment=Enum.TextXAlignment.Left;nm.ZIndex=26
   local desc=text(make('TextLabel',box,'Detail'),10,Color3.fromRGB(225,225,225));desc.Position=UDim2.fromOffset(60,34);desc.Size=UDim2.new(1,-70,0,29);desc.Text=item.detail;desc.TextXAlignment=Enum.TextXAlignment.Left;desc.TextYAlignment=Enum.TextYAlignment.Top;desc.ZIndex=26
   local preview=make('TextButton',box,'Preview');preview.Position=UDim2.fromOffset(10,72);preview.Size=UDim2.fromOffset(106,27);preview.Text='PREVIEW';preview.ZIndex=27;Theme.button(preview,Theme.Colors.Blue,11)
   local equip=make('TextButton',box,'Equip');equip.Position=UDim2.fromOffset(126,72);equip.Size=UDim2.fromOffset(120,27);equip.Text=RunService:IsStudio() and 'EQUIP' or ((tonumber(item.passId or 0)>0) and 'PURCHASE' or 'UNAVAILABLE');equip.ZIndex=27;Theme.button(equip,RunService:IsStudio() and Theme.Colors.Green or Theme.Colors.Dark,11)
   self.connections[#self.connections+1]=preview.Activated:Connect(function() self.status.Text='Previewing '..item.title..'...';remote:FireServer('Preview',item.id) end)
   self.connections[#self.connections+1]=equip.Activated:Connect(function()
     if not RunService:IsStudio() and tonumber(item.passId or 0)>0 then self.status.Text='Opening purchase...';remote:FireServer('Prompt',item.id)
     else self.status.Text='Checking '..item.title..'...';remote:FireServer('Equip',item.id) end
   end)
 end
 local function setOpen(v)self.open=v==true;shade.Visible=self.open;card.Visible=self.open;open.Visible=not self.open;if self.open then status.Text='Choose PREVIEW to try a style.' end end
 self.openShop=function()setOpen(true)end;self.closeShop=function()setOpen(false)end
 self.connections[#self.connections+1]=open.Activated:Connect(function()setOpen(true)end);self.connections[#self.connections+1]=close.Activated:Connect(function()setOpen(false)end)
 self.connections[#self.connections+1]=shade.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then setOpen(false)end end)
 self.connections[#self.connections+1]=RunService.Heartbeat:Connect(function()
   if not self.open then return end;local camera=Workspace.CurrentCamera;if camera then local v=camera.ViewportSize;local scale=math.clamp(math.min((v.X-22)/600,(v.Y-22)/540),.44,1);local u=card:FindFirstChild('ShopScale') or make('UIScale',card,'ShopScale');u.Scale=scale end
 end)
 self.boxes=byId
 return self
end
function Shop:applyState(payload)
 if type(payload)~='table' then return end
 self.owned=payload.owned or {};self.equipped=payload.equipped;self.preview=payload.preview
 if payload.message then self.status.Text=payload.message end
 for id,box in pairs(self.boxes or {}) do
   local e=box:FindFirstChild('Equip');if e then e.Text=(self.equipped==id and 'EQUIPPED' or self.owned[id] and 'EQUIP' or 'EQUIP') end
 end
end
function Shop:isBlocking()return self.open end
function Shop:setAvailable(value)
 self.gui.Enabled=value==true
 if not value and self.closeShop then self.closeShop() end
end
function Shop:destroy()for _,c in ipairs(self.connections)do c:Disconnect()end;if self.gui then self.gui:Destroy()end end
return Shop
