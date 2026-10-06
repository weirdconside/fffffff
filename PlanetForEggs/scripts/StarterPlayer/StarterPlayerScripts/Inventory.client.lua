-- Source BackpackController layout and templates; egg ownership/planting stays
-- authoritative on the server. No original source-game scripts are executed.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterGui=game:GetService("StarterGui")
local Input=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local api=ReplicatedStorage:WaitForChild("PFE")
local Config=require(api:WaitForChild("Config"))
local EggForge = require(game:GetService("ReplicatedStorage"):WaitForChild("PFE"):WaitForChild("EggForge"))
local UI=require(api:WaitForChild("UIKit"))
local ModelUtil=require(api:WaitForChild("ModelUtil"))
local assets=api:WaitForChild("UIAssets")
local templates=assets:WaitForChild("InventoryTemplates")
local Action=api:WaitForChild("Action")
local eggModels=assets:WaitForChild("Eggs")
local state: {[string]: any}={Planet="Base",Eggs={},GrowingEggs={},BaseIndex=1}
local catalog={}
for _,info in ipairs(Config.EggCatalog) do catalog[info.Id]=info end
-- (v39) not only the catalog's eggs: the one-of-a-kind ones (Fusion's, the daily calendar's) have generated ids
-- that Config.Eggs works out from the id (EggForge) - without this they never showed in the backpack
local function eggInfo(kind) return catalog[kind] or (type(kind)=="string" and Config.Eggs[kind]) or nil end
local background=templates:GetAttribute("BackgroundColor") or Color3.fromRGB(38,38,38)
local font=templates:GetAttribute("SlotFont") or Font.fromEnum(Enum.Font.GothamBold)
local corner=templates:GetAttribute("CornerRadius") or UDim.new(.05,0)
local function new(class,properties,parent)
	local object=Instance.new(class)
	for key,value in pairs(properties) do object[key]=value end
	object.Parent=parent;return object
end
local function round(object)
	local node=object:FindFirstChildOfClass("UICorner") or new("UICorner",{},object)
	node.CornerRadius=corner
end
local function label(parent,text,size,position,textSize)
	return new("TextLabel",{BackgroundTransparency=1,Text=text,TextColor3=Color3.new(1,1,1),
		FontFace=font,TextSize=textSize or 14,TextWrapped=true,Size=size,Position=position,
		TextStrokeColor3=Color3.new(),TextStrokeTransparency=.45,ZIndex=24},parent)
end
local gui=new("ScreenGui",{Name="EggInventory",ResetOnSpawn=false,IgnoreGuiInset=false,
	ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=25},player:WaitForChild("PlayerGui"))
local backpack=new("Frame",{Name="Backpack",BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},gui)
local hotbar=new("Frame",{Name="Hotbar",BackgroundTransparency=1},backpack)
local main=new("Frame",{Name="Main",BackgroundTransparency=1},backpack)
local inventory=templates:WaitForChild("Inventory"):Clone()
inventory.Name="Inventory";inventory.Visible=false;inventory.Parent=main
-- Source runtime leaves these tools hidden; preserve the source shell, search,
-- category buttons, exact icon/name geometry, corner radii and gradients.
for _,name in ipairs({"Loading","AutoSell","FavoriteMode","EquipBest","VRInventorySelector"}) do
	local child=inventory:FindFirstChild(name);if child and child:IsA("GuiObject") then child.Visible=false end
end
local scroll=inventory:WaitForChild("ScrollingFrame")
local grid=scroll:WaitForChild("UIGridLayout")
local padding=scroll:FindFirstChildOfClass("UIPadding")
local slotTemplate=scroll:FindFirstChild("Template");if slotTemplate then slotTemplate.Visible=false end
local search=inventory:WaitForChild("Search")
local searchBox=search:WaitForChild("TextBox")
searchBox.Text="";searchBox.ClearTextOnFocus=false;searchBox.TextXAlignment=Enum.TextXAlignment.Left
local searchX=search:FindFirstChild("X");if searchX then searchX.Visible=false end
local searchStroke=search:FindFirstChild("StrokeTemplate");if searchStroke then searchStroke.Enabled=false end
local closeButton=inventory:FindFirstChild("Close")
local categoryFrame=inventory:WaitForChild("CategoryFrame")
local categoryTemplate=categoryFrame:WaitForChild("CategoryTemplate")
local eggCategory=categoryTemplate:Clone();eggCategory.Name="Eggs";eggCategory.Visible=true
eggCategory.CategoryName.Text="Eggs";eggCategory.ImageButton.Image="rbxassetid://116524274262912"
eggCategory.UIStroke.Enabled=true;eggCategory.Parent=categoryFrame
local categoryLabel=inventory:FindFirstChild("CategoryLabel")
if categoryLabel then categoryLabel.Text="Eggs" end

-- Only the inventory toggle is new: a small outlined bag beside the source hotbar.
local bag=new("TextButton",{Name="OpenInventory",BackgroundColor3=Color3.fromRGB(29,31,38),
	BackgroundTransparency=.12,Text="",AutoButtonColor=false,Size=UDim2.fromOffset(44,44),
	Selectable=true,ZIndex=20},backpack)
new("UICorner",{CornerRadius=UDim.new(0,12)},bag)
local bagBorder=new("UIStroke",{Color=Color3.fromRGB(208,215,229),Transparency=.68,Thickness=1},bag)
local glyph=new("Frame",{Name="BagOutline",BackgroundTransparency=1,Size=UDim2.fromOffset(20,23),
	AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,3),ZIndex=21},bag)
new("UICorner",{CornerRadius=UDim.new(0,5)},glyph)
new("UIStroke",{Color=Color3.fromRGB(235,240,249),Thickness=1.7},glyph)
local handle=new("Frame",{Name="Handle",BackgroundTransparency=1,Size=UDim2.fromOffset(9,7),
	AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,.5,-7),ZIndex=21},bag)
new("UICorner",{CornerRadius=UDim.new(0,3)},handle)
new("UIStroke",{Color=Color3.fromRGB(235,240,249),Thickness=1.7},handle)
local pocket=new("Frame",{Name="Pocket",BackgroundTransparency=1,Size=UDim2.fromOffset(12,7),
	Position=UDim2.fromOffset(4,11),ZIndex=21},glyph)
new("UICorner",{CornerRadius=UDim.new(0,2)},pocket)
new("UIStroke",{Color=Color3.fromRGB(235,240,249),Thickness=1.2},pocket)
local bagTip=label(bag,"Backpack  [ ` ]",UDim2.fromOffset(140,27),UDim2.fromOffset(-48,-33),13)
bagTip.Visible=false
bag.MouseEnter:Connect(function() bagTip.Visible=true;TweenService:Create(bagBorder,TweenInfo.new(.15),{Transparency=.15}):Play() end)
bag.MouseLeave:Connect(function() bagTip.Visible=false;TweenService:Create(bagBorder,TweenInfo.new(.15),{Transparency=.68}):Play() end)

local help=label(gui,"",UDim2.fromOffset(510,38),UDim2.new(.5,-255,1,-114),15)
help.Name="PlantingHint";help.Visible=false
local plantButton=new("TextButton",{Name="PlantEgg",AnchorPoint=Vector2.new(.5,1),
	Position=UDim2.new(.5,0,1,-150),Size=UDim2.fromOffset(176,40),BackgroundColor3=background,
	BackgroundTransparency=.12,Text="Plant egg",FontFace=font,TextSize=17,TextColor3=Color3.new(1,1,1),
	Visible=false,Selectable=true,ZIndex=25},gui)
round(plantButton)
local plantStroke=new("UIStroke",{Color=Color3.new(1,1,1),Thickness=2,Transparency=.2,
	ApplyStrokeMode=Enum.ApplyStrokeMode.Border},plantButton)
local selectedId,selectedKind=nil,nil
local grouped,slotButtons,allButtons={}, {}, {}
local byId,assignments,knownIds,bagOnly={},{},{},{}
local signature=""
local held,ghost,ghostHighlight=nil,nil,nil
local heldCenter,ghostCenter=CFrame.new(),CFrame.new()
local candidate,valid=false,false
local pendingUntil=0
local touchPoint=nil
local lastWasGamepad=false
local slotCount,slotSize=10,60
local TOOL_KEYS=2 -- keys 1-2 take out the raygun and the bat, the egg slots start at 3
local mobile=false
local drag,suppressClickUntil=nil,0
local resize,rebuild
local function menuOpen()
	return player:GetAttribute("PFEMenuOpen")==true or player:GetAttribute("PFEPlanetMapOpen")==true
end
-- an egg can be taken in the hands anywhere (also with the backpack open, also on planets) ...
local function canHold()
	return not state.Busy and not state.CarryingEgg and not state.Stolen
		and not player:GetAttribute("PFEFlightActive") and not menuOpen() and not GuiService.MenuIsOpen
end
-- ... and planted in your own pen
local function available()
	return canHold() and state.Planet=="Base"
end
local function clearVisuals()
	if held then held:Destroy();held=nil end
	if ghost then ghost:Destroy();ghost=nil;ghostHighlight=nil end
	player:SetAttribute("PFEHoldingStoredEgg",false)
	candidate=nil;valid=false
end
local function visibleBounds(model)
	local pivot=model:GetPivot()
	local low=Vector3.new(math.huge,math.huge,math.huge)
	local high=-low
	local found=false
	for _,part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency<1 then
			found=true
			local relative=pivot:ToObjectSpace(part.CFrame)
			for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
				local point=relative:PointToWorldSpace(part.Size*Vector3.new(x,y,z)*.5)
				low=low:Min(point);high=high:Max(point)
			end end end
		end
	end
	if not found then return model:GetBoundingBox() end
	return pivot*CFrame.new((low+high)*.5),high-low
end
local function cloneEgg(kind,name,maxSize,preview,recordScale,mutation)
	local template=EggForge.Template(kind)
	if not template then return nil,CFrame.new() end
	local model=template:Clone();model.Name=name
	ModelUtil.ApplyMutation(model,mutation)
	for _,part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
			part.CastShadow=not preview
			if preview and part.Transparency<1 then part.Transparency=.52 end
		elseif part:IsA("ParticleEmitter") or part:IsA("Trail") or part:IsA("Beam") then part.Enabled=false
		elseif part:IsA("LuaSourceContainer") or part:IsA("LayerCollector") or part:IsA("ProximityPrompt") then part:Destroy() end
	end
	if preview then
		local _,nativeSize=ModelUtil.VisibleBounds(model)
		local eggInfo=Config.Eggs[kind]
		local initialScale=Config.EggGrowthScales(ModelUtil.GetScale(model),recordScale,math.max(nativeSize.X,nativeSize.Y,nativeSize.Z),eggInfo and eggInfo.Rarity)
		ModelUtil.SetScale(model,initialScale)
	else
		ModelUtil.FitTo(model,maxSize)
	end
	local cf=visibleBounds(model)
	local center=model:GetPivot():ToObjectSpace(cf)
	model.Parent=workspace
	return model,center
end
local heldSize=Vector3.one
local function ensureVisuals()
	if not selectedKind or not canHold() then return end
	local selected=byId[selectedId]
	local recordScale=selected and selected.Eggs[1].Scale or 1
	local mutation=selected and selected.Eggs[1].Mutation or "Normal"
	local rarity=eggInfo(selectedKind) and eggInfo(selectedKind).Rarity
	if not held then
		-- in the hands at its own size: the rarer the bigger (Steal an Egg), within what two hands carry
		held,heldCenter=cloneEgg(selectedKind,"LocalEquippedEgg",Config.HeldEggSize(rarity,recordScale),false,1,mutation)
		if held then
			local _,size=ModelUtil.VisibleBounds(held);heldSize=size
			ModelUtil.AttachEggFX(held,rarity,recordScale)
		end
		player:SetAttribute("PFEHoldingStoredEgg",held~=nil)
	end
	-- the see-through preview on the ground only where it can be planted
	if ghost or not available() or inventory.Visible then return end
	ghost,ghostCenter=cloneEgg(selectedKind,"EggPlacementPreview",nil,true,recordScale,mutation)
	if ghost then
		ghostHighlight=new("Highlight",{Name="PlacementValidity",Adornee=ghost,
			DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,FillTransparency=.8,
			OutlineTransparency=0,OutlineColor=Color3.fromRGB(91,255,139)},ghost)
	end
end
local function updateSelection()
	for _,entry in ipairs(allButtons) do
		if entry.Button.Parent then entry.Equipped.Visible=entry.Id~=nil and entry.Id==selectedId end
	end
end
local function unequip()
	selectedId=nil;selectedKind=nil;clearVisuals();updateSelection()
	player:SetAttribute("PFESelectedEgg",nil)
end
local function selectGroup(group)
	if not group or not canHold() or os.clock()<suppressClickUntil then return end
	if selectedId==group.Id then unequip();return end
	-- an egg in the hands means the raygun / bat go back into the backpack
	local character=player.Character
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and character:FindFirstChildOfClass("Tool") then humanoid:UnequipTools() end
	clearVisuals();selectedId=group.Id;selectedKind=group.Kind
	player:SetAttribute("PFESelectedEgg",selectedId)
	-- the backpack stays open while choosing; the egg is in the hands straight away
	updateSelection();ensureVisuals()
end
local function cancelDrag()
	if drag and drag.Visual then drag.Visual:Destroy() end
	drag=nil
end
local function setInventory(open)
	if open and (state.Busy or player:GetAttribute("PFEFlightActive") or menuOpen()) then return end
	inventory.Visible=open;player:SetAttribute("PFEInventoryOpen",open)
	cancelDrag()
	if open then
		-- (the egg stays in the hands; only the ground preview waits until the backpack closes)
		if ghost then ghost:Destroy();ghost=nil;ghostHighlight=nil end
	else searchBox:ReleaseFocus() end
	if rebuild then rebuild() end
	if lastWasGamepad then GuiService.SelectedObject=open and slotButtons[1] or nil end
end
local function makeSlot(group,index,inBag)
	local button=templates:WaitForChild(inBag and "InventoryTemplate" or "HotbarTemplate"):Clone()
	button.Name=group and "Egg_"..group.Id or "Empty_"..index
	button.LayoutOrder=index;button.Visible=true
	button.Size=UDim2.fromOffset(inBag and slotSize*1.5 or slotSize,inBag and slotSize*1.5 or slotSize)
	button.BackgroundColor3=inBag and Color3.new() or background
	button.BackgroundTransparency=inBag and .5 or (templates:GetAttribute("SlotLockedTransparency") or .3)
	button.AutoButtonColor=false;button.Selectable=true;button.Active=true;button.Draggable=false;button.Text="";button.ZIndex=20
	button:SetAttribute("IsInventorySlot",inBag)
	local rootStroke=button:FindFirstChildOfClass("UIStroke");rootStroke.Thickness=0
	rootStroke.Color=templates:GetAttribute("BorderColor") or Color3.new(1,1,1)
	local scale=button:FindFirstChildOfClass("UIScale");if scale then scale.Scale=1 end
	local icon=button:WaitForChild("Icon")
	-- our own eggs: the slot shows the egg model itself (in the icon's place)
	icon.Image="";icon.Visible=false
	if group then
		local preview=UI.viewport(button,EggForge.Template(group.Kind),icon.Size,icon.Position,{Spin=false,Yaw=0.5,Prepare=function(m) ModelUtil.ApplyMutation(m,group.Eggs[1].Mutation) end})
		preview.AnchorPoint=icon.AnchorPoint;preview.ZIndex=icon.ZIndex+1
	end
	local name=button:WaitForChild("ToolName")
	name.Text=group and Config.EggDisplayName(group.Eggs[1]) or "";name.Visible=inBag and group~=nil
	local shadow=button:FindFirstChild("Shadow");if shadow then shadow.Visible=inBag and group~=nil end
	for _,element in ipairs({name,shadow}) do
		if element then
			for _,child in ipairs(element:GetChildren()) do if child:IsA("UIGradient") then child:Destroy() end end
			local gradients=templates:FindFirstChild("RarityGradients")
			local gradient=group and gradients and gradients:FindFirstChild(group.Info.Rarity)
			if gradient then gradient:Clone().Parent=element end
		end
	end
	local base=button:FindFirstChild("BaseTemplate")
	if base then
		base.Amount.Visible=false;base.Amount.Text=""
		local mutations=base:FindFirstChild("Mutations");if mutations then mutations.Visible=false end
	end
	for _,nodeName in ipairs({"FavIcon","Weight","StrokeFrame","ToolTip"}) do
		local node=button:FindFirstChild(nodeName);if node then node.Visible=false end
	end
	-- slot keys: 1 and 2 are the raygun and the bat, the egg slots follow from 3
	local number=button:FindFirstChild("Number");if number then number.Text=tostring((index+TOOL_KEYS)%10);number.Visible=not inBag and index+TOOL_KEYS<=10 and not Input.TouchEnabled end
	local equipped=new("Frame",{Name="Equipped",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),
		AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),ZIndex=3,Visible=false},button)
	round(equipped);new("UIStroke",{Color=templates:GetAttribute("EquippedColor") or Color3.new(1,1,1),Thickness=3.8},equipped)
	local entry={Button=button,Kind=group and group.Kind,Id=group and group.Id,Group=group,Equipped=equipped,Inventory=inBag,Index=index}
	local function hover(on)
		if scale then TweenService:Create(scale,TweenInfo.new(.15),{Scale=on and 1.015 or 1}):Play() end
	end
	button.MouseEnter:Connect(function() hover(true) end);button.MouseLeave:Connect(function() hover(false) end)
	button.SelectionGained:Connect(function() hover(true) end);button.SelectionLost:Connect(function() hover(false) end)
	button.Activated:Connect(function() selectGroup(group) end)
	button.InputBegan:Connect(function(input)
		if not group or not inventory.Visible then return end
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
			drag={Entry=entry,Start=Vector2.new(input.Position.X,input.Position.Y),Input=input,Active=false}
		end
	end)
	button.Parent=inBag and scroll or hotbar
	table.insert(allButtons,entry)
	if not inBag then slotButtons[index]=button end
	return button
end
local function applySearch()
	local query=string.lower(searchBox.Text)
	for _,entry in ipairs(allButtons) do
		if entry.Inventory then entry.Button.Visible=query=="" or string.find(string.lower(entry.Group.Info.Name),query,1,true)~=nil end
	end
	if searchX then searchX.Visible=query~="" end
end
local function assignedIndex(id)
	for index=1,slotCount do if assignments[index]==id then return index end end
	return nil
end
local function reconcileSlots()
	for index,id in pairs(assignments) do if index>slotCount or not byId[id] then assignments[index]=nil end end
	for _,group in ipairs(grouped) do
		if not knownIds[group.Id] and not bagOnly[group.Id] then
			for index=1,slotCount do if not assignments[index] then assignments[index]=group.Id;break end end
		end
		knownIds[group.Id]=true
	end
end
local function updateGrid()
	local size=scroll.AbsoluteSize;local window=scroll.AbsoluteWindowSize
	if size.X<=0 or window.Y<=0 then return end
	local gapX,gapY=math.floor(window.X*.02),math.floor(window.Y*.04)
	local left=padding and padding.PaddingLeft.Offset+padding.PaddingLeft.Scale*size.X or 0
	local right=padding and padding.PaddingRight.Offset+padding.PaddingRight.Scale*size.X or 0
	local columns=math.max(3,math.min(6,slotCount))
	local cell=(size.X-scroll.ScrollBarThickness-left-right)/columns-gapX
	grid.CellPadding=UDim2.fromOffset(gapX,gapY);grid.CellSize=UDim2.fromOffset(math.floor(cell),cell)
	local vertical=padding and padding.PaddingTop.Offset+padding.PaddingBottom.Offset+(padding.PaddingTop.Scale+padding.PaddingBottom.Scale)*size.Y or 0
	scroll.CanvasSize=UDim2.new(0,grid.AbsoluteContentSize.X,0,grid.AbsoluteContentSize.Y+vertical)
end
resize=function()
	local camera=workspace.CurrentCamera;if not camera then return end
	local size=camera.ViewportSize
	local tenFoot=GuiService:IsTenFootInterface()
	mobile=Input.TouchEnabled and not tenFoot
	local portrait=size.Y>size.X
	local newCount
	if mobile then
		-- Do not use raw width as the only phone test: modern phones can report
		-- 1080/1440+ pixel viewports and would otherwise get the desktop layout.
		newCount=portrait and 4 or 5
	elseif tenFoot then
		newCount=10
	else
		newCount=size.X<560 and 6 or size.X<720 and 7 or 8
	end
	local changed=slotCount~=newCount
	slotCount=newCount
	slotSize=tenFoot and 100 or (mobile and (portrait and 42 or 44) or 60)
	local lift=mobile and 10 or 0 -- (UI.bottomMargin: clear of the gesture bar)
	local gap=mobile and 4 or 5
	local width=5+slotCount*(slotSize+gap)
	local height=slotSize+8
	hotbar.Size=UDim2.fromOffset(width,height);hotbar.Position=UDim2.new(.5,-width/2,1,-height-lift)
	main.Size=UDim2.fromOffset(width,height*(mobile and 2 or 4)+40)
	main.Position=UDim2.new(.5,-width/2,1,-height-lift-main.Size.Y.Offset)
	local visible={}
	for _,entry in ipairs(allButtons) do if not entry.Inventory and (entry.Id or inventory.Visible) then table.insert(visible,entry) end end
	for i,entry in ipairs(visible) do
		entry.Button.Position=UDim2.fromOffset(width/2-slotSize/2+(slotSize+gap)*(i-(#visible/2+.5)),4)
	end
	bag.Size=UDim2.fromOffset(mobile and 40 or 44,mobile and 40 or 44)
	local bagScale=glyph:FindFirstChild("GlyphScale") or new("UIScale",{Name="GlyphScale"},glyph)
	bagScale.Scale=mobile and .9 or 1
	bag.Position=UDim2.new(.5,math.max(0,#visible*(slotSize+gap)/2)+7,1,-height+(mobile and 6 or 11)-lift)
	if mobile then bagTip.Visible=false end
	local helpWidth=mobile and math.max(190,math.min(portrait and 330 or 430,size.X-20)) or math.max(220,math.min(510,size.X-24))
	help.Size=UDim2.fromOffset(helpWidth,mobile and 32 or 38)
	help.TextSize=mobile and 13 or 15
	help.Position=UDim2.new(.5,-help.Size.X.Offset/2,1,-height-lift-(mobile and 36 or 44))
	plantButton.Position=UDim2.new(.5,0,1,-height-lift-(mobile and 58 or 72))
	plantButton.Size=UDim2.fromOffset(mobile and 150 or 176,mobile and 34 or 40)
	plantButton.TextSize=mobile and 15 or 17
	if changed then reconcileSlots();if rebuild then rebuild() end end
	updateGrid()
end
rebuild=function()
	if drag and drag.Active then cancelDrag() end
	for _,entry in ipairs(allButtons) do entry.Button:Destroy() end
	allButtons={};slotButtons={};grouped={};byId={}
	for _,egg in ipairs(state.Eggs or {}) do
		local kind=egg.EggId
		local info=kind and eggInfo(kind)
		if info then
			local entry={Id=egg.Id,Kind=kind,Info=info,Eggs={egg}}
			table.insert(grouped,entry);byId[egg.Id]=entry
		end
	end
	reconcileSlots()
	for index=1,slotCount do
		local group=assignments[index] and byId[assignments[index]]
		if group or inventory.Visible then makeSlot(group,index,false) end
	end
	local overflow={}
	for _,group in ipairs(grouped) do if not assignedIndex(group.Id) then table.insert(overflow,group) end end
	local rank={Common=1,Uncommon=2,Rare=3,Epic=4,Legendary=5,Mythic=6,Cosmic=7,Secret=8,Eternal=9}
	table.sort(overflow,function(a,b)
		local ar,br=rank[a.Info.Rarity] or 0,rank[b.Info.Rarity] or 0
		if ar~=br then return ar>br end
		local ap=Config.Pets[a.Info.Species];local bp=Config.Pets[b.Info.Species]
		local ai,bi=ap and ap.Income or 0,bp and bp.Income or 0
		if ai~=bi then return ai>bi end
		return a.Id<b.Id
	end)
	for index,group in ipairs(overflow) do makeSlot(group,index,true) end
	updateSelection();applySearch();resize()
end
local function contains(object,point)
	local at,size=object.AbsolutePosition,object.AbsoluteSize
	return object.Visible and point.X>=at.X and point.Y>=at.Y and point.X<=at.X+size.X and point.Y<=at.Y+size.Y
end
Input.InputChanged:Connect(function(input)
	if not drag then return end
	if input.UserInputType~=Enum.UserInputType.MouseMovement and input~=drag.Input then return end
	local point=Vector2.new(input.Position.X,input.Position.Y)
	if not drag.Active and (point-drag.Start).Magnitude>6 then
		drag.Active=true
		drag.Visual=drag.Entry.Button:Clone();drag.Visual.Name="DraggedSlot"
		drag.Visual.Size=UDim2.fromOffset(drag.Entry.Button.AbsoluteSize.X,drag.Entry.Button.AbsoluteSize.Y)
		drag.Visual.AnchorPoint=Vector2.new(.5,.5);drag.Visual.ZIndex=60;drag.Visual.Parent=gui
		for _,node in ipairs(drag.Visual:GetDescendants()) do if node:IsA("GuiObject") then node.ZIndex+=60 end end
	end
	if drag.Visual then local inset=GuiService:GetGuiInset();drag.Visual.Position=UDim2.fromOffset(point.X-inset.X,point.Y-inset.Y) end
end)
Input.InputEnded:Connect(function(input)
	if not drag or (input.UserInputType~=Enum.UserInputType.MouseButton1 and input~=drag.Input) then return end
	local current=drag
	if current.Active then
		local point=Vector2.new(input.Position.X,input.Position.Y)
		local origin=assignedIndex(current.Entry.Id)
		local target
		for _,entry in ipairs(allButtons) do if not entry.Inventory and contains(entry.Button,point) then target=entry.Index;break end end
		if target then
			local old=assignments[target]
			if origin then assignments[origin]=old else if old then bagOnly[old]=true end end
			assignments[target]=current.Entry.Id;bagOnly[current.Entry.Id]=nil
		elseif contains(inventory,point) or not contains(hotbar,point) then
			if origin then assignments[origin]=nil end
			bagOnly[current.Entry.Id]=true
		end
		suppressClickUntil=os.clock()+.15
	end
	cancelDrag()
	if current.Active then rebuild() end
end)
scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateGrid)
grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateGrid)
if searchX then searchX.Activated:Connect(function() searchBox.Text="" end) end
searchBox.Focused:Connect(function() if searchStroke then searchStroke.Enabled=true end end)
searchBox.FocusLost:Connect(function() if searchStroke then searchStroke.Enabled=false end end)
eggCategory.ImageButton.Activated:Connect(function() searchBox.Text="";scroll.CanvasPosition=Vector2.zero end)

local function snapPoint(screen)
	local area=state.PlantArea
	local camera=workspace.CurrentCamera
	local character=player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	if not area or typeof(area.CFrame)~="CFrame" or typeof(area.Size)~="Vector3" or not camera or not root then return nil,false end
	local ray=camera:ScreenPointToRay(screen.X,screen.Y)
	local surface=area.CFrame.Position
	local denominator=ray.Direction:Dot(area.CFrame.UpVector)
	if math.abs(denominator)<.001 then return nil,false end
	local distance=(surface-ray.Origin):Dot(area.CFrame.UpVector)/denominator
	if distance<=0 or distance>250 then return nil,false end
	local localPoint=area.CFrame:PointToObjectSpace(ray.Origin+ray.Direction*distance)
	local grid=area.GridSize or Config.PlantGridSize or 3
	local x=math.round(localPoint.X/grid)*grid
	local z=math.round(localPoint.Z/grid)*grid
	local point=area.CFrame:PointToWorldSpace(Vector3.new(x,0,z))
	local inside=math.abs(x)<=area.Size.X*.5-2 and math.abs(z)<=area.Size.Z*.5-2
	local nearby=(root.Position-point).Magnitude<=(Config.PlantDistance or Config.InteractionDistance or 24)
	local spaced=true
	for _,growing in ipairs(state.GrowingEggs or {}) do
		if typeof(growing.Position)=="Vector3" and (Vector3.new(point.X,0,point.Z)-Vector3.new(growing.Position.X,0,growing.Position.Z)).Magnitude<(area.MinSpacing or 2.25) then spaced=false;break end
	end
	return point,inside and nearby and spaced
end
local function confirmPlant(screen)
	if not selectedId or not available() or inventory.Visible or drag or os.clock()<pendingUntil or os.clock()<suppressClickUntil then return end
	if screen then candidate,valid=snapPoint(screen) end
	if not valid or not candidate then return end
	pendingUntil=os.clock()+.55
	Action:FireServer("PlantEgg",{EggId=selectedId,Position=candidate})
end
bag.Activated:Connect(function() setInventory(not inventory.Visible) end)
if closeButton then closeButton.Activated:Connect(function() setInventory(false) end) end
plantButton.Activated:Connect(function() confirmPlant() end)
searchBox:GetPropertyChangedSignal("Text"):Connect(applySearch)
local numberKeys={Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,Enum.KeyCode.Four,Enum.KeyCode.Five,
	Enum.KeyCode.Six,Enum.KeyCode.Seven,Enum.KeyCode.Eight,Enum.KeyCode.Nine,Enum.KeyCode.Zero}
local TOOL_ORDER={"Raygun","Bat"}
-- a number key on a tool: take it out (putting a held egg away first) or put it back
local function toggleTool(name)
	local character=player.Character
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if character:FindFirstChild(name) then humanoid:UnequipTools();return end
	if player:GetAttribute("PFECarrying") then return end
	if selectedId then unequip() end
	local pack=player:FindFirstChildOfClass("Backpack")
	local tool=pack and pack:FindFirstChild(name)
	if tool then humanoid:EquipTool(tool) end
end
Input.InputBegan:Connect(function(input,processed)
	if Input:GetFocusedTextBox() then return end
	if not processed and (input.KeyCode==Enum.KeyCode.Backquote or input.KeyCode==Enum.KeyCode.ButtonSelect) then setInventory(not inventory.Visible);return end
	if input.KeyCode==Enum.KeyCode.ButtonB or input.KeyCode==Enum.KeyCode.Escape then
		if inventory.Visible then setInventory(false) else unequip() end
		return
	end
	if processed then return end
	for index,key in ipairs(numberKeys) do
		if input.KeyCode==key then
			if index<=TOOL_KEYS then toggleTool(TOOL_ORDER[index]);return end
			local slot=index-TOOL_KEYS
			if assignments[slot] then selectGroup(byId[assignments[slot]]) end
			return
		end
	end
	if input.KeyCode==Enum.KeyCode.ButtonL1 or input.KeyCode==Enum.KeyCode.ButtonR1 then
		if #grouped==0 then return end
		local index=0
		for i,group in ipairs(grouped) do if group.Id==selectedId then index=i;break end end
		local direction=input.KeyCode==Enum.KeyCode.ButtonR1 and 1 or -1
		local group=grouped[(index-1+direction)%#grouped+1]
		if group.Id~=selectedId then selectGroup(group) end
	elseif input.KeyCode==Enum.KeyCode.ButtonX and inventory.Visible then
		local selected=GuiService.SelectedObject
		for _,entry in ipairs(allButtons) do
			if entry.Button==selected and entry.Id and not entry.Inventory then
				assignments[entry.Index]=nil;bagOnly[entry.Id]=true;rebuild();break
			end
		end
	elseif input.KeyCode==Enum.KeyCode.ButtonR2 then confirmPlant()
	elseif input.UserInputType==Enum.UserInputType.MouseButton1 then confirmPlant(Input:GetMouseLocation()) end
end)
Input.TouchTapInWorld:Connect(function(position,processed)
	if processed then return end
	touchPoint=position;confirmPlant(position)
end)
Input.LastInputTypeChanged:Connect(function(inputType)
	lastWasGamepad=string.find(inputType.Name,"Gamepad",1,true)~=nil
	if not lastWasGamepad then GuiService.SelectedObject=nil end
end)
RunService.RenderStepped:Connect(function()
	local flying=player:GetAttribute("PFEFlightActive")==true
	gui.Enabled=not flying and not menuOpen()
	local holding=selectedId and canHold()
	local usable=holding and available() and not inventory.Visible
	help.Visible=usable and true or false
	plantButton.Visible=help.Visible and lastWasGamepad -- (phones: a tap on the ground plants)
	if not holding then if held or ghost then clearVisuals() end;return end
	ensureVisuals()
	local character=player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	if held and root then
		-- at the chest, or over the head when it's big (the same place as a planet egg, see Config.HeldEggOffset)
		local cf=root.CFrame*Config.HeldEggOffset(heldSize,Config.HeadTop(character))
		held:PivotTo(cf*heldCenter:Inverse())
	end
	if not usable then
		if ghost then ghost:Destroy();ghost=nil;ghostHighlight=nil end
		candidate,valid=nil,false
		return
	end
	local camera=workspace.CurrentCamera
	if not camera then return end
	local point=Input:GetMouseLocation()
	if lastWasGamepad or (Input.TouchEnabled and not Input.MouseEnabled) then
		local inset=GuiService:GetGuiInset()
		point=touchPoint or Vector2.new(camera.ViewportSize.X*.5,camera.ViewportSize.Y*.56)+inset
	end
	candidate,valid=snapPoint(point)
	if ghost then
		if candidate then
			-- Match updateGrowing exactly: same authored scale, pivot and orientation.
			ghost:PivotTo(CFrame.new(candidate))
		else ghost:PivotTo(CFrame.new(0,-10000,0)) end
	end
	local color=valid and Color3.fromRGB(120,255,143) or Color3.fromRGB(255,117,117)
	if ghostHighlight then ghostHighlight.FillColor=color;ghostHighlight.OutlineColor=color end
	plantStroke.Color=color;plantButton.TextColor3=color
	help.Text=valid and (lastWasGamepad and "RT — Plant egg  •  B — Unequip" or (Input.TouchEnabled and not Input.MouseEnabled and "Tap the ground to plant your egg" or "Click the ground to plant your egg"))
		or "Choose a clear spot inside your pen"
end)
local function hideForMenu()
	if menuOpen() or player:GetAttribute("PFEFlightActive") then setInventory(false);clearVisuals() end
end
for _,attribute in ipairs({"PFEMenuOpen","PFEPlanetMapOpen","PFEFlightActive"}) do player:GetAttributeChangedSignal(attribute):Connect(hideForMenu) end
player.CharacterAdded:Connect(function() unequip();setInventory(false) end)
api:WaitForChild("State").OnClientEvent:Connect(function(nextState)
	if type(nextState)~="table" then return end
	if nextState.Light then
		for key,value in pairs(nextState) do state[key]=value end
		if nextState.CarryingEgg==nil then state.CarryingEgg=nil end
		if nextState.Stolen==nil then state.Stolen=nil end
		if selectedId and state.Busy then unequip() end
		return
	end
	state=nextState
	local ids={}
	local selectedExists=false
	for _,egg in ipairs(state.Eggs or {}) do
		table.insert(ids,egg.Id..":"..tostring(egg.EggId)..":"..tostring(egg.Mutation)..":"..tostring(egg.Scale or 1))
		if egg.Id==selectedId then selectedExists=true end
	end
	if selectedId and (not selectedExists or state.Busy) then unequip() end
	local nextSignature=table.concat(ids,"|")
	if signature~=nextSignature then
		if selectedId then clearVisuals() end
		signature=nextSignature;rebuild();resize()
	end
	if state.Busy then setInventory(false) end
end)
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false) end)
-- (again once the title screen hands the screen over)
player:GetAttributeChangedSignal("IntroActive"):Connect(function()
	task.defer(function() pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false) end) end)
end)
rebuild();resize();Action:FireServer("Sync")
