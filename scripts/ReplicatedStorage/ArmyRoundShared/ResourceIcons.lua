-- Compact, asset-independent resource icons.
-- All glyphs are made from Roblox primitives so mining/storage displays cannot
-- inherit the donor tree image. The same builder powers HUD rows and billboards.
local Icons={}
local function part(parent,name,size,colour,cf,shape)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=colour
    p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
    p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.CFrame=cf or CFrame.new()
    if shape then p.Shape=shape end
    p.Parent=parent;return p
end
local brown=Color3.fromRGB(135,83,43)
local tan=Color3.fromRGB(222,172,105)
local grey=Color3.fromRGB(139,152,171)
local darkGrey=Color3.fromRGB(89,101,119)
local gold=Color3.fromRGB(255,200,62)
local crystal=Color3.fromRGB(126,164,255)
local function canonical(kind)
    local s=tostring(kind or ""):lower()
    local aliases={wood="Log",logs="Log",planks="Plank",["iron bars"]="Iron Bar",["ironbar"]="Iron Bar",crystals="Crystal",trophies="Trophy",ore="Iron Ore"}
    return aliases[s] or kind
end
local function build(parent,kind)
    kind=canonical(kind)
    if kind=="Log" then
        for i=-1,1 do
            local cf=CFrame.new(i*.42,0,0)*CFrame.Angles(0,0,math.pi/2)
            part(parent,"Log",Vector3.new(1.55,.5,.5),brown,cf,Enum.PartType.Cylinder)
            part(parent,"CutEnd",Vector3.new(.035,.42,.42),tan,cf*CFrame.new(.78,0,0),Enum.PartType.Cylinder)
        end
    elseif kind=="Stone" or kind=="Iron Ore" then
        for i=1,3 do part(parent,"Rock",Vector3.new(.8,.72,.82),kind=="Stone" and grey or darkGrey,CFrame.new((i-2)*.42,(i%2)*.18,0)*CFrame.Angles(.2*i,.4*i,.2)) end
        if kind=="Iron Ore" then for i=1,5 do part(parent,"MetalVein",Vector3.new(.21,.23,.14),Color3.fromRGB(220,164,107),CFrame.new((i-3)*.25,(i%2)*.3,.46)*CFrame.Angles(0,0,.4)) end end
    elseif kind=="Gold" then
        for i=0,3 do part(parent,"Coin",Vector3.new(.14,1.1,1.1),gold,CFrame.new(i*.09,i*.16-.24,0)*CFrame.Angles(0,0,math.pi/2),Enum.PartType.Cylinder) end
    elseif kind=="Plank" or kind=="Iron Bar" then
        for i=0,2 do part(parent,kind,Vector3.new(1.55,.22,.42),kind=="Plank" and tan or Color3.fromRGB(187,205,227),CFrame.new(0,i*.22-.2,(i%2)*.2)*CFrame.Angles(0,i*.15,0)) end
        if kind=="Plank" then for i=-1,1 do part(parent,"Grain",Vector3.new(1.2,.015,.025),brown,CFrame.new(0,.365,i*.1)) end end
    elseif kind=="Crystal" then
        for i=-1,1 do
            local cf=CFrame.new(i*.4,i==0 and .1 or -.1,0)*CFrame.Angles(0,0,-i*.22)
            part(parent,"Crystal",Vector3.new(.36,1.05,.36),Color3.fromRGB(111+i*18,137,255),cf)
            local tip=Instance.new("WedgePart");tip.Name="CrystalPoint";tip.Size=Vector3.new(.36,.32,.36);tip.Color=Color3.fromRGB(171,202,255)
            tip.Anchored=true;tip.CanCollide=false;tip.CanQuery=false;tip.CanTouch=false;tip.CastShadow=false;tip.CFrame=cf*CFrame.new(0,.685,0);tip.Parent=parent
        end
    elseif kind=="Trophy" then
        part(parent,"Base",Vector3.new(.95,.22,.7),Color3.fromRGB(91,62,36),CFrame.new(0,-.63,0))
        part(parent,"Stem",Vector3.new(.22,.6,.22),gold,CFrame.new(0,-.28,0))
        part(parent,"Cup",Vector3.new(.96,.73,.73),gold,CFrame.new(0,.23,0),Enum.PartType.Ball)
        for _,i in ipairs({-1,1}) do part(parent,"Handle",Vector3.new(.2,.55,.18),gold,CFrame.new(i*.56,.2,0)*CFrame.Angles(0,0,-i*.35)) end
    else
        -- Unknown values still get a neutral stone glyph instead of borrowing a
        -- stale tree ImageLabel from the donor place.
        for i=1,2 do part(parent,"Unknown",Vector3.new(.55,.55,.55),grey,CFrame.new((i-1)*.45-.2,0,0),Enum.PartType.Ball) end
    end
end
local function hideLegacy(parent)
    for _,o in ipairs(parent:GetDescendants()) do
        if o:IsA("ImageLabel") or o:IsA("ImageButton") then
            if o.Name=="Icon" or o:GetAttribute("ResourceIconLegacy") then
                o.Visible=false;o.Image="";o:SetAttribute("ResourceIconLegacy",true)
            end
        end
    end
end
local function make(parent,kind,size)
    local old=parent:FindFirstChild("RoundResourceIcon")
    if old then old:Destroy() end
    local view=Instance.new("ViewportFrame");view.Name="RoundResourceIcon";view.BackgroundTransparency=1
    view.BorderSizePixel=0;view.Size=size or UDim2.fromScale(1,1);view.Position=UDim2.fromScale(.5,.5);view.AnchorPoint=Vector2.new(.5,.5)
    view.Ambient=Color3.fromRGB(205,205,205);view.LightColor=Color3.fromRGB(255,246,229);view.LightDirection=Vector3.new(-1,-2,-3)
    view:SetAttribute("ResourceKind",canonical(kind));local z=1;if parent:IsA("GuiObject") then z=parent.ZIndex end;view.ZIndex=z+2
    local world=Instance.new("WorldModel");world.Name="IconGeometry";world.Parent=view;build(world,kind)
    local camera=Instance.new("Camera");camera.Name="IconCamera";camera.FieldOfView=30;camera.CFrame=CFrame.lookAt(Vector3.new(2.7,2,4.7),Vector3.new(0,.05,0));camera.Parent=view;view.CurrentCamera=camera
    view.Parent=parent;return view
end
-- Mount a correct icon into a row in ArmyRoundHUD.Currencies.
function Icons.mountAt(parent,resource,size)
    if not parent then return nil end
    hideLegacy(parent)
    local view=parent:FindFirstChild("RoundResourceIcon")
    if not view or view:GetAttribute("ResourceKind")~=canonical(resource) then view=make(parent,resource,size) end
    if size then view.Size=size end
    return view
end
-- Replace any donor StorageDisplay image (including nested Hold/Icon) with the
-- resource-specific primitive icon. This is called after each building level swap.
function Icons.fixBillboard(billboard,resource)
    if not billboard then return nil end
    hideLegacy(billboard)
    local host=billboard:FindFirstChild("Hold") or billboard
    return Icons.mountAt(host,resource,UDim2.fromScale(1,1))
end
function Icons.mount(currencies,order)
    if not currencies then return end
    for _,name in ipairs(order or {}) do
        local row=currencies:FindFirstChild(name) or currencies:FindFirstChild((name=="Log" and "Wood") or name)
        if row then
            local icon=Icons.mountAt(row,name,UDim2.new(0,38,0,38))
            icon.Position=UDim2.new(0,4,.5,0);icon.AnchorPoint=Vector2.new(0,.5)
            local button=row:FindFirstChild("ActualButton");if button then button.ZIndex=icon.ZIndex+1 end
        end
    end
end
return Icons
