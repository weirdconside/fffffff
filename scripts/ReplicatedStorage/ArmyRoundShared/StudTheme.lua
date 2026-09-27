-- Shared native stud/bevel theme. Texture IDs and palette are copied from
-- 1231313132.rbxl / ProgressionClient433 and TrailShop.Main.ImageLabel.
local Theme={}
local C={Panel=Color3.fromRGB(83,78,67),Card=Color3.fromRGB(108,102,85),Ink=Color3.fromRGB(34,27,20),Gold=Color3.fromRGB(255,221,74),Green=Color3.fromRGB(64,192,29),Blue=Color3.fromRGB(52,158,216),Purple=Color3.fromRGB(147,72,213),White=Color3.fromRGB(255,255,242),Muted=Color3.fromRGB(216,213,193),Dark=Color3.fromRGB(51,47,40),Red=Color3.fromRGB(226,35,31)}
Theme.Colors=C
local function make(class,parent,name)
    local o=Instance.new(class);o.Name=name or class;o.Parent=parent;return o
end
-- Text must always sit above the stud texture/bevel of the panel it is on.
local function liftAboveSkin(o)
    local parent=o.Parent
    local skin=parent and (parent:FindFirstChild('StudBevel') or parent:FindFirstChild('StudTexture'))
    if skin and skin:IsA('GuiObject') and o~=skin and o.ZIndex<=skin.ZIndex then o.ZIndex=skin.ZIndex+1 end
end
Theme.lift=liftAboveSkin
function Theme.text(o,size,color)
    for _,d in ipairs(o:GetChildren()) do if (d:IsA('UIStroke') and d.Name~='StudOutline') or d:IsA('UIGradient') or d:IsA('UITextSizeConstraint') then d:Destroy() end end
    liftAboveSkin(o)
    o.FontFace=Font.new('rbxasset://fonts/families/LegacyArial.json',Enum.FontWeight.Bold,Enum.FontStyle.Normal)
    o.TextSize=size or 16;o.TextScaled=false;o.TextColor3=color or C.White;o.TextStrokeTransparency=1
    o.RichText=false;o.TextTransparency=0
    if o:IsA('TextLabel') and o:FindFirstChild('StudCaption') then o.TextTransparency=1 end
    return o
end
function Theme.skin(o,color)
    for _,d in ipairs(o:GetChildren()) do
        if d:IsA('UIStroke') or d:IsA('UICorner') or d:IsA('UIGradient') or d.Name=='StudTexture' or d.Name=='StudBevel' then d:Destroy() end
    end
    o.BackgroundTransparency=0;o.BackgroundColor3=color or C.Panel;o.BorderSizePixel=0
    local corner=make('UICorner',o);corner.CornerRadius=UDim.new(0,5)
    local outline=make('UIStroke',o,'StudOutline');outline.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;outline.Color=C.Ink;outline.Thickness=2
    local tex=make('ImageLabel',o,'StudTexture');tex.BackgroundTransparency=1;tex.Size=UDim2.fromScale(1,1);tex.Image='rbxassetid://103855926983380';tex.ScaleType=Enum.ScaleType.Tile;tex.TileSize=UDim2.fromOffset(26,26);tex.ImageTransparency=.84;tex.ZIndex=o.ZIndex;tex.Active=false
    local bevel=make('ImageLabel',o,'StudBevel');bevel.BackgroundTransparency=1;bevel.Size=UDim2.fromScale(1,1);bevel.Image='rbxassetid://74603642649742';bevel.ScaleType=Enum.ScaleType.Slice;bevel.SliceCenter=Rect.new(13,13,129,129);bevel.SliceScale=.3;bevel.ImageTransparency=.26;bevel.ZIndex=o.ZIndex;bevel.Active=false
    -- Content that already lives on the panel must stay above the new texture.
    for _,d in ipairs(o:GetChildren()) do
        if d:IsA('GuiObject') and d~=tex and d~=bevel and d.ZIndex<=o.ZIndex then d.ZIndex=o.ZIndex+1 end
    end
    -- A skinned TextLabel would draw its own text UNDER its texture children:
    -- move the text into a caption above them (buttons do the same in Theme.button).
    if o:IsA('TextLabel') then
        local ink=o:FindFirstChild('StudCaption') or make('TextLabel',o,'StudCaption')
        ink.BackgroundTransparency=1;ink.Size=UDim2.new(1,-8,1,-4);ink.Position=UDim2.fromOffset(4,2);ink.ZIndex=o.ZIndex+3;ink.TextWrapped=true
        ink.FontFace=o.FontFace;ink.TextSize=o.TextSize;ink.TextColor3=o.TextColor3;ink.Text=o.Text;ink.RichText=o.RichText
        ink.TextXAlignment=o.TextXAlignment;ink.TextYAlignment=o.TextYAlignment;ink.TextScaled=o.TextScaled
        o.TextTransparency=1
        if not o:GetAttribute('StudCaptionBound') then
            o:SetAttribute('StudCaptionBound',true)
            for _,prop in ipairs({'Text','TextColor3','TextSize','FontFace'}) do
                o:GetPropertyChangedSignal(prop):Connect(function() ink[prop]=o[prop] end)
            end
        end
    end
    return o
end
function Theme.button(b,color,size)
    Theme.skin(b,color or C.Blue);Theme.text(b,size or 15);b.AutoButtonColor=true
    -- Put lettering above the stud texture, including dynamically changed labels.
    local ink=b:FindFirstChild('StudCaption') or make('TextLabel',b,'StudCaption')
    ink.BackgroundTransparency=1;ink.Size=UDim2.new(1,-8,1,-4);ink.Position=UDim2.fromOffset(4,2);ink.ZIndex=b.ZIndex+3;ink.TextWrapped=true
    Theme.text(ink,size or 15);ink.Text=b.Text;ink.TextColor3=b.TextColor3;b.TextTransparency=1
    if not b:GetAttribute('StudCaptionBound') then
        b:SetAttribute('StudCaptionBound',true)
        b:GetPropertyChangedSignal('Text'):Connect(function() ink.Text=b.Text end)
        b:GetPropertyChangedSignal('TextColor3'):Connect(function() ink.TextColor3=b.TextColor3 end)
    end
    return b
end
function Theme.tree(root)
    for _,o in ipairs(root:GetDescendants()) do
        if o:IsA('TextLabel') or o:IsA('TextBox') then Theme.text(o,math.clamp(o.TextSize,13,22));o.ZIndex=math.max(o.ZIndex,4)
        elseif o:IsA('TextButton') then Theme.button(o,C.Blue,15) end
    end
end
function Theme.billboard(root)
    -- Sibling ordering keeps every label above the panel it belongs to.
    if root:IsA('LayerCollector') then root.ZIndexBehavior=Enum.ZIndexBehavior.Sibling end
    if root:IsA('BillboardGui') then root.AlwaysOnTop=true end
    for _,o in ipairs(root:GetDescendants()) do
        if o:IsA('TextLabel') then Theme.text(o,16);o.TextWrapped=true;o.ZIndex=4
        elseif o:IsA('Frame') and o.BackgroundTransparency<.9 then Theme.skin(o,C.Card) end
    end
end
function Theme.buildHUD(hud,data,icons)
    hud:ClearAllChildren();hud.ResetOnSpawn=false;hud.IgnoreGuiInset=true;hud.DisplayOrder=10;hud.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    local left=make('Frame',hud,'Left');left.Position=UDim2.fromOffset(16,112);left.Size=UDim2.fromOffset(222,462);Theme.skin(left,C.Panel)
    local heading=make('TextLabel',left,'Heading');heading.BackgroundTransparency=1;heading.Position=UDim2.fromOffset(12,8);heading.Size=UDim2.new(1,-24,0,22);heading.Text='RESOURCES';heading.TextXAlignment=Enum.TextXAlignment.Left;heading.ZIndex=4;Theme.text(heading,16,C.Gold)
    local rows=make('ScrollingFrame',left,'Currencies');rows.Position=UDim2.fromOffset(8,38);rows.Size=UDim2.new(1,-16,1,-46);rows.BackgroundTransparency=1;rows.BorderSizePixel=0;rows.ScrollBarThickness=4;rows.ScrollingDirection=Enum.ScrollingDirection.Y;rows.CanvasSize=UDim2.fromOffset(0,#data.ResourceOrder*52);rows.AutomaticCanvasSize=Enum.AutomaticSize.None;rows.ZIndex=3
    local list=make('UIListLayout',rows);list.Padding=UDim.new(0,4);list.SortOrder=Enum.SortOrder.LayoutOrder
    for index,key in ipairs(data.ResourceOrder) do
        local row=make('Frame',rows,key);row.Size=UDim2.new(1,-6,0,48);row.LayoutOrder=index;row.ZIndex=3;Theme.skin(row,C.Dark)
        local name=make('TextLabel',row,'ResourceName');name.BackgroundTransparency=1;name.Position=UDim2.fromOffset(54,4);name.Size=UDim2.new(1,-60,0,17);name.Text=data.ResourceNames[key] or key;name.TextXAlignment=Enum.TextXAlignment.Left;name.ZIndex=6;Theme.text(name,14,C.Muted)
        local amount=make('TextLabel',row,'Display');amount.BackgroundTransparency=1;amount.Position=UDim2.fromOffset(54,21);amount.Size=UDim2.new(1,-60,0,24);amount.Text='0';amount.TextXAlignment=Enum.TextXAlignment.Left;amount.ZIndex=6;Theme.text(amount,21)
        local click=make('TextButton',row,'ActualButton');click.Size=UDim2.fromScale(1,1);click.BackgroundTransparency=1;click.Text='';click.ZIndex=8
    end
    icons.mount(rows,data.ResourceOrder)
    for _,row in ipairs(rows:GetChildren()) do
        if row:IsA('Frame') then local icon=row:FindFirstChild('RoundResourceIcon');if icon then icon.Size=UDim2.fromOffset(42,42);icon.Position=UDim2.new(0,5,.5,0);icon.AnchorPoint=Vector2.new(0,.5);icon.ZIndex=6 end end
    end
    return rows
end
function Theme.layoutHUD(hud,viewport)
    local w=viewport.X;local h=viewport.Y
    hud.Left.Position=UDim2.fromOffset(12,68)
    hud.Left.Size=UDim2.fromOffset(w<700 and 190 or 222,math.max(132,math.min(462,h-110)))
end
return Theme
