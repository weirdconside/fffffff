-- English-only native HUD and a round-scoped top-down camera.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local shared=ReplicatedStorage:WaitForChild("ArmyRoundShared",20)
if not shared then warn("[ArmyRound] Shared data did not replicate");return end
local Data=require(shared:WaitForChild("RoundData"))
local Icons=require(shared:WaitForChild("ResourceIcons"))
local Animations=require(shared:WaitForChild("RoundAnimations"))
local Theme=require(shared:WaitForChild("StudTheme"))
local command=shared:WaitForChild("Command")
local snapshots=shared:WaitForChild("Snapshot")
local playerGui=player:WaitForChild("PlayerGui")
local hud=playerGui:WaitForChild("ArmyRoundHUD",20)
if not hud then warn("[ArmyRound] Native HUD did not replicate");return end

local currencies=Theme.buildHUD(hud,Data,Icons)
-- Simple white loading screen requested for initial join and round transitions.
-- It stays visible for exactly five seconds and reports progress in the center.
local loadingGui=Instance.new("ScreenGui")
loadingGui.Name="BattleLoading"
loadingGui.ResetOnSpawn=false
loadingGui.IgnoreGuiInset=true
loadingGui.DisplayOrder=2000
loadingGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
loadingGui.Enabled=false
loadingGui.Parent=playerGui
local loadingRoot=Instance.new("Frame")
loadingRoot.Name="White"
loadingRoot.Size=UDim2.fromScale(1,1)
loadingRoot.BackgroundColor3=Color3.fromRGB(255,255,255)
loadingRoot.BorderSizePixel=0
loadingRoot.Parent=loadingGui
local loadingTitle=Instance.new("TextLabel")
loadingTitle.Name="Title"
loadingTitle.AnchorPoint=Vector2.new(.5,.5)
loadingTitle.Position=UDim2.fromScale(.5,.405)
loadingTitle.Size=UDim2.new(1,-36,0,64)
loadingTitle.BackgroundTransparency=1
loadingTitle.Font=Enum.Font.GothamBlack
loadingTitle.Text="BATTLE BUT WITH ADMIN PANEL"
loadingTitle.TextColor3=Color3.fromRGB(0,0,0)
loadingTitle.TextScaled=true
loadingTitle.TextWrapped=true
loadingTitle.Parent=loadingRoot
local loadingPercent=Instance.new("TextLabel")
loadingPercent.Name="Percent"
loadingPercent.AnchorPoint=Vector2.new(.5,.5)
loadingPercent.Position=UDim2.fromScale(.5,.5)
loadingPercent.Size=UDim2.new(1,-36,0,48)
loadingPercent.BackgroundTransparency=1
loadingPercent.Font=Enum.Font.GothamBold
loadingPercent.Text="0%"
loadingPercent.TextColor3=Color3.fromRGB(0,0,0)
loadingPercent.TextScaled=true
loadingPercent.Parent=loadingRoot
local loadingGeneration=0
local function runLoading()
    loadingGeneration+=1
    local generation=loadingGeneration
    loadingGui.Enabled=true
    loadingPercent.Text="0%"
    local started=os.clock()
    task.spawn(function()
        while generation==loadingGeneration and loadingGui.Enabled do
            local progress=math.clamp((os.clock()-started)/5,0,1)
            loadingPercent.Text=tostring(math.floor(progress*100+0.5)).."%"
            if progress>=1 then loadingGui.Enabled=false;break end
            RunService.Heartbeat:Wait()
        end
    end)
end
runLoading()
local animation=nil
local active,token,state=false,nil,nil
local focus,home,lower,upper=Vector3.new(),Vector3.new(),Vector3.new(),Vector3.new()
local height,savedFov=48,nil
local hovered,selectedBuilding=nil,nil
local selectedUnits={}
local rallyNext,drag,windowFocused=false,false,true
local motion={}
local currentTarget=nil
-- Touch state is kept separately from the mouse state.  Roblox's Activated
-- signal handles buttons, but world taps and camera drags need an explicit
-- path because mobile devices do not emit MouseButton1/MouseMovement.
local touchId,touchStart,touchLast,touchMoved,touchStartedAt,touchOverGui=nil,nil,nil,false,0,nil
local touchPanThreshold=10
-- Forward declarations: the contextual panel is defined before input helpers.
local send, costText, tell
local lastKind="Barbarian"
local actionGui=Instance.new("ScreenGui");actionGui.Name="RoundActionPanel";actionGui.ResetOnSpawn=false;actionGui.IgnoreGuiInset=true;actionGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;actionGui.Enabled=false;actionGui.Parent=playerGui
local actionPanel=Instance.new("Frame");actionPanel.Name="Panel";actionPanel.AnchorPoint=Vector2.new(1,1);actionPanel.Position=UDim2.new(1,-24,1,-154);actionPanel.Size=UDim2.new(0,252,0,210);actionPanel.BackgroundColor3=Color3.fromRGB(18,27,47);actionPanel.BackgroundTransparency=.06;actionPanel.BorderSizePixel=0;actionPanel.Visible=false;actionPanel.Parent=actionGui
local panelCorner=Instance.new("UICorner");panelCorner.CornerRadius=UDim.new(0,12);panelCorner.Parent=actionPanel
local panelStroke=Instance.new("UIStroke");panelStroke.Color=Color3.fromRGB(86,179,224);panelStroke.Thickness=2;panelStroke.Transparency=.15;panelStroke.Parent=actionPanel
local panelTitle=Instance.new("TextLabel");panelTitle.Name="Title";panelTitle.BackgroundTransparency=1;panelTitle.Position=UDim2.new(0,14,0,9);panelTitle.Size=UDim2.new(1,-28,0,28);panelTitle.Font=Enum.Font.GothamBold;panelTitle.TextSize=18;panelTitle.TextXAlignment=Enum.TextXAlignment.Left;panelTitle.TextColor3=Color3.fromRGB(248,222,133);panelTitle.Text="BUILD";panelTitle.Parent=actionPanel
local panelInfo=Instance.new("TextLabel");panelInfo.Name="Info";panelInfo.BackgroundTransparency=1;panelInfo.Position=UDim2.new(0,14,0,38);panelInfo.Size=UDim2.new(1,-28,0,18);panelInfo.Font=Enum.Font.Gotham;panelInfo.TextSize=12;panelInfo.TextWrapped=true;panelInfo.TextXAlignment=Enum.TextXAlignment.Left;panelInfo.TextColor3=Color3.fromRGB(190,207,224);panelInfo.Parent=actionPanel
local actionButtons=Instance.new("Frame");actionButtons.Name="Buttons";actionButtons.BackgroundTransparency=1;actionButtons.Position=UDim2.new(0,12,0,58);actionButtons.Size=UDim2.new(1,-24,1,-68);actionButtons.Parent=actionPanel
local actionLayout=Instance.new("UIGridLayout");actionLayout.CellSize=UDim2.new(0,108,0,30);actionLayout.CellPadding=UDim2.new(0,6,0,5);actionLayout.Parent=actionButtons
local AdminUI=require(shared:WaitForChild("AdminUI"))
local LobbyUI=require(shared:WaitForChild("LobbyUI"))
local BaseBadges=require(shared:WaitForChild("BaseBadges"))
local adminUI=AdminUI.new(playerGui,function(op,payload) if send then send(op,payload) end end)
local lobbyPicker=LobbyUI.new(playerGui,player.UserId,command)
local baseBadges=BaseBadges.new(playerGui)
-- Retain the source stud styling for action windows; remove the global hint strip.
Theme.tree(actionGui);Theme.skin(actionPanel,Theme.Colors.Panel)
actionGui.DisplayOrder=20
panelTitle.TextColor3=Theme.Colors.Gold;panelInfo.TextColor3=Theme.Colors.Muted
panelTitle.Size=UDim2.new(1,-64,0,28)
actionPanel.Size=UDim2.fromOffset(310,258);actionPanel.Position=UDim2.new(1,-20,1,-24)
panelInfo.Size=UDim2.new(1,-28,0,42);panelInfo.TextYAlignment=Enum.TextYAlignment.Top
Theme.text(panelInfo,13,Theme.Colors.Muted)
actionButtons.Position=UDim2.fromOffset(12,86);actionButtons.Size=UDim2.new(1,-24,1,-96)
actionLayout.CellSize=UDim2.fromOffset(139,43);actionLayout.CellPadding=UDim2.fromOffset(7,7);actionLayout.SortOrder=Enum.SortOrder.LayoutOrder
local actionClose=Instance.new("TextButton");actionClose.Name="Close";actionClose.Text="X";actionClose.Size=UDim2.fromOffset(28,28);actionClose.Position=UDim2.new(1,-40,0,10);actionClose.ZIndex=6;actionClose.Parent=actionPanel;Theme.button(actionClose,Theme.Colors.Red,16)
local function resizeWindows()
    local camera=Workspace.CurrentCamera;if not camera then return end
    local viewport=camera.ViewportSize
    Theme.layoutHUD(hud,viewport)
    hud.Left.Visible=not (viewport.X<650 and actionPanel.Visible)
    -- Keep the contextual panel usable on narrow phones.  The old fixed
    -- 310px panel was clipped on portrait displays and intercepted taps near
    -- the screen edge.
    if viewport.X<600 then
        actionPanel.AnchorPoint=Vector2.new(.5,1)
        actionPanel.Position=UDim2.new(.5,0,1,-12)
        actionPanel.Size=UDim2.new(1,-20,0,220)
        actionButtons.Size=UDim2.new(1,-24,1,-96)
        actionLayout.CellSize=UDim2.new(.5,-8,0,38)
    else
        actionPanel.AnchorPoint=Vector2.new(1,1)
        actionPanel.Position=UDim2.new(1,-20,1,-24)
        actionPanel.Size=UDim2.fromOffset(310,258)
        actionButtons.Size=UDim2.new(1,-24,1,-96)
        actionLayout.CellSize=UDim2.fromOffset(139,43)
    end
end
resizeWindows()
local resizeClock=0
RunService.Heartbeat:Connect(function(dt)resizeClock=resizeClock+dt;if resizeClock>=.35 then resizeClock=0;resizeWindows() end end)
local function clearActionButtons()
    for _,o in ipairs(actionButtons:GetChildren()) do if o:IsA("TextButton") then o:Destroy() end end
end
local function addAction(text,color,callback)
    local b=Instance.new("TextButton");b.AutoButtonColor=true;b.BackgroundColor3=color or Color3.fromRGB(42,73,108);b.TextColor3=Color3.fromRGB(245,250,255);b.Font=Enum.Font.GothamBold;b.TextSize=12;b.TextWrapped=true;b.Text=text;b.Parent=actionButtons
    local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,7);c.Parent=b
    local captions={UP="UPGRADE [U]",WORK="HIRE WORKER",GET="COLLECT",BARB="BARBARIAN [1]",ARCH="ARCHER [2]",GIANT="GIANT [3]",WIZ="WIZARD [4]",RES="RESEARCH [R]",CRAFT="CRAFT",ATK="ATTACK",MOVE="ORDER ARMY",["GOLD WORK"]="GOLD WORKER"}
    b.Text=captions[text] or text;b.LayoutOrder=#actionButtons:GetChildren();b.ZIndex=5
    Theme.button(b,(text=="UP" or text=="GET") and Theme.Colors.Green or text=="RES" and Theme.Colors.Purple or Theme.Colors.Blue,14)
    b.Activated:Connect(callback);return b
end
local function hideAction()
    currentTarget=nil;actionPanel.Visible=false
end
actionClose.Activated:Connect(hideAction)
local panelVersion=nil
local function showAction(target)
    if not target or not state then hideAction();return end
    currentTarget=target;clearActionButtons();actionPanel.Visible=true
    local own=target.owner==tostring(player.UserId)
    if target.kind=="Building" and own then
        selectedBuilding=target.key;local b=state.buildings[target.key];if not b then hideAction();return end
        local short={LumberHut="LUMBER",MinerHut="MINE",OreMinerHut="ORE",CrystalMinerHut="CRYSTAL",GoldMine="GOLD",Barracks="BARRACKS",Townhall="TOWN",Campsite="CAMP",BuilderHut="BUILDER",Sawmill="SAWMILL",Foundry="FOUNDRY",TrainingCamp="RESEARCH"}
        panelTitle.Text=(Data.BuildingNames[b.kind] or short[b.kind] or b.kind).."  "..b.level
        panelVersion=target.key..":"..b.level..":"..tostring(b.upgrading>0)
        panelInfo.Text=b.upgrading>0 and ("Upgrading: "..b.upgrading.."s") or (b.nextCost and "Upgrade: "..costText(b.nextCost) or "Maximum level")
        if b.upgrading<=0 and b.nextCost then addAction("UP",Color3.fromRGB(46,125,94),function()send("Upgrade",{key=target.key})end) end
        if Data.WorkerResources[b.kind] then addAction("WORK",Color3.fromRGB(62,120,167),function()send("BuyWorker",{key=target.key})end);addAction("GET",Color3.fromRGB(185,132,48),function()send("Collect",{key=target.key})end) end
        if b.kind=="GoldMine" then addAction("GET",Color3.fromRGB(185,132,48),function()send("Collect",{key=target.key})end) end
        if b.kind=="Barracks" then
            for _,kind in ipairs({"Barbarian","Archer","Giant","Wizard"}) do
                local selectedKind=kind
                local troop=Data.Troops and Data.Troops.Troops and Data.Troops.Troops[selectedKind]
                addAction(({Barbarian="BARB",Archer="ARCH",Giant="GIANT",Wizard="WIZ"})[selectedKind] or selectedKind,Color3.fromRGB(66,119,164),function()send("Train",{kind=selectedKind})end)
            end
            addAction("RES",Color3.fromRGB(128,89,170),function()send("Research",{kind=lastKind})end)
        end
        if Data.Craft.Stations[b.kind] then addAction("CRAFT",Color3.fromRGB(128,89,170),function()send("Craft",{key=target.key})end) end
    elseif target.kind=="Base" and state.bases[target.key] then
        local base=state.bases[target.key];panelTitle.Text=(base.kind=="Territory" and "GOLD" or "TOWN")
        panelInfo.Text=""
        if own then
            if base.kind=="Territory" then addAction("GOLD WORK",Color3.fromRGB(196,142,45),function()send("BuyWorker",{key="BASE:"..target.key})end) end
            addAction("MOVE",Color3.fromRGB(66,119,164),function()rallyNext=true;tell("Click the ground to move your army.")end)
        else addAction("ATK",Color3.fromRGB(173,67,72),function()rallyNext=true;tell("Click the base again or the ground to send your army.")end) end
    else
        hideAction();return
    end
end
local hoverClock,syncClock=0,0
local currentWorld,lastSequence=nil,-1
local highlighted=Instance.new("Highlight")
highlighted.Name="RoundSelection";highlighted.FillTransparency=0.92;highlighted.OutlineTransparency=0.1
highlighted.Enabled=false;highlighted.Parent=Workspace
tell=function(text) if actionPanel.Visible then panelInfo.Text=text end end
local function blockedInput() return not windowFocused or loadingGui.Enabled or adminUI:isBlocking() or UIS:GetFocusedTextBox()~=nil or GuiService.MenuIsOpen==true end
send=function(op,payload)
    if active and token then command:FireServer(token,op,payload or {}) end
end
costText=function(cost)
    local parts={}
    for _,r in ipairs(Data.ResourceOrder) do
        if cost and cost[r] then parts[#parts+1]=cost[r].." "..(Data.ResourceNames[r] or r) end
    end
    return #parts>0 and table.concat(parts,", ") or "0"
end
local function updateResources(resources)
    for _,name in ipairs(Data.ResourceOrder) do
        local row=currencies:FindFirstChild(name)
        if row then
            local amount=resources and resources[name] or 0
            if type(amount)~="number" or amount~=amount then amount=0 end
            row.Visible=true
            row.Display.Text=tostring(math.floor(math.clamp(amount,0,999999)))
        end
    end
end
local function classify(object)
    local o=object
    while o and o~=currentWorld do
        local kind,key
        if o:GetAttribute("RoundExpansion") then kind="Expand";key=o:GetAttribute("RoundExpansion")
        elseif o:GetAttribute("RoundBuildingKey") then kind="Building";key=o:GetAttribute("RoundBuildingKey")
        elseif o:GetAttribute("RoundUnit") then kind="Unit";key=o:GetAttribute("RoundUnit")
        elseif o:GetAttribute("RoundBase") then kind="Base";key=o:GetAttribute("RoundBase")
        elseif o:GetAttribute("RoundCamp") then kind="Camp";key=o:GetAttribute("RoundCamp") end
        if kind then
            return {kind=kind,key=key,object=o,owner=o:GetAttribute("RoundOwner"),
                originalOwner=o:GetAttribute("RoundOriginalOwner"),base=o:GetAttribute("RoundBase"),unitRole=o:GetAttribute("RoundRole"),dead=o:GetAttribute("RoundDead")}
        end
        o=o.Parent
    end
end
local function overButton(x,y)
    local p
    if x and y then p=Vector2.new(x,y) else p=UIS:GetMouseLocation() end
    for _,o in ipairs(playerGui:GetGuiObjectsAtPosition(p.X,p.Y)) do
        local inRoot=function(root) return root and (o==root or o:IsDescendantOf(root)) end
        if o.Visible and (o:IsA("GuiButton") or o:IsA("TextBox") or inRoot(hud.Left) or inRoot(actionPanel) or inRoot(adminUI.card) or inRoot(lobbyPicker.card)) then return true end
    end
    return false
end
local function castAt(x,y)
    if not currentWorld or not currentWorld.Parent then
        local rounds=Workspace:FindFirstChild("ArmyRounds")
        local name=player:GetAttribute("RoundModel")
        currentWorld=rounds and name and rounds:FindFirstChild(name) or nil
    end
    local camera=Workspace.CurrentCamera
    if not currentWorld or not camera then return nil end
    local pos=(x and y) and Vector2.new(x,y) or UIS:GetMouseLocation()
    local ray=camera:ViewportPointToRay(pos.X,pos.Y)
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances={currentWorld}
    return Workspace:Raycast(ray.Origin,ray.Direction*2500,params)
end
local function cast() return castAt() end
local function showHover(target)
    if hovered and hovered.object and hovered.object.Parent then
        local ui=hovered.object:FindFirstChild("RoundHover");if ui then ui.Enabled=false end
    end
    hovered=target;highlighted.Enabled=false;highlighted.Adornee=nil
    if target and target.object then
        local ui=target.object:FindFirstChild("RoundHover");if ui then ui.Enabled=true end
        highlighted.Adornee=target.object;highlighted.Enabled=true
        highlighted.OutlineColor=target.owner==tostring(player.UserId) and Color3.fromRGB(124,237,164) or Color3.fromRGB(247,116,116)
    end
end
local function order(hit)
    if not hit then return end
    local ids={};local hadSelection=next(selectedUnits)~=nil
    local units=currentWorld and currentWorld:FindFirstChild("Units")
    local live={}
    if units then for _,m in ipairs(units:GetChildren()) do
        if m:GetAttribute("RoundOwner")==tostring(player.UserId) and not m:GetAttribute("RoundDead") then live[m:GetAttribute("RoundUnit") or ""]=true end
    end end
    for id in pairs(selectedUnits) do
        if live[id] then ids[#ids+1]=id else selectedUnits[id]=nil end
    end
    if hadSelection and #ids==0 then tell("Previous selection is gone. Ordering all available troops.") end
    local target=classify(hit.Instance)
    local base=target and target.base or nil
    send("Order",{pos={x=hit.Position.X,y=hit.Position.Y,z=hit.Position.Z},target=base,
        enemy=target and target.kind=="Unit" and target.owner~=tostring(player.UserId) and target.key or nil,
        camp=target and target.kind=="Camp" and target.owner==tostring(player.UserId) and target.key or nil,
        ids=#ids>0 and ids or nil})
    rallyNext=false
end
local function activate(hit)
    if not hit then return end
    if rallyNext then order(hit);return end
    local target=classify(hit.Instance)
    if not target then selectedUnits={};hideAction();return end
    local own=target.owner==tostring(player.UserId)
    if target.kind=="Expand" and (own or target.key=="BRIDGE") then
        send("Expand",{key=target.key,owner=target.owner})
    elseif target.kind=="Building" and own then
        showAction(target)
    elseif target.kind=="Base" then
        showAction(target)
    elseif target.kind=="Camp" or (target.kind=="Unit" and not own and not target.dead and target.unitRole~="Worker" and target.unitRole~="Builder") then
        order(hit)
    elseif target.kind=="Unit" and own and target.unitRole=="Troop" and not target.dead then
        if not UIS:IsKeyDown(Enum.KeyCode.LeftShift) and not UIS:IsKeyDown(Enum.KeyCode.RightShift) then selectedUnits={} end
        selectedUnits[target.key]=not selectedUnits[target.key] or nil
        local n=0;for _ in pairs(selectedUnits) do n=n+1 end
        tell("Selected: "..n..". Right-click to order; X selects all troops.")
    end
end
local function movementAction(_,inputState,input)
    if inputState==Enum.UserInputState.Cancel then motion={};return Enum.ContextActionResult.Sink end
    if blockedInput() then motion={};return Enum.ContextActionResult.Pass end
    if inputState==Enum.UserInputState.Begin then motion[input.KeyCode]=true
    elseif inputState==Enum.UserInputState.End then motion[input.KeyCode]=false end
    return Enum.ContextActionResult.Sink
end
local function restoreCamera()
    CAS:UnbindAction("ArmyRoundMovement");motion={};drag=false
    UIS.MouseBehavior=Enum.MouseBehavior.Default
    local camera=Workspace.CurrentCamera
    if camera then
        camera.CameraType=Enum.CameraType.Custom;camera.FieldOfView=savedFov or 70
        local character=player.Character;local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then camera.CameraSubject=humanoid end
    end
end
local function phase()
    local wanted=player:GetAttribute("ScenePhase")=="Round"
    local newToken=player:GetAttribute("RoundToken")
    if wanted and type(newToken)=="string" then
        local newHome=player:GetAttribute("RoundHome")
        local newMin,newMax=player:GetAttribute("RoundBoundsMin"),player:GetAttribute("RoundBoundsMax")
        if typeof(newHome)~="Vector3" or typeof(newMin)~="Vector3" or typeof(newMax)~="Vector3"
            or newMin.X>=newMax.X or newMin.Z>=newMax.Z or type(player:GetAttribute("RoundModel"))~="string" then return end
        if not active or token~=newToken then
            local enteringRound=not active
            if not active then local camera=Workspace.CurrentCamera;if camera then savedFov=camera.FieldOfView end end
            active=true;token=newToken;state=nil;lastSequence=-1
            selectedBuilding=nil;selectedUnits={};rallyNext=false;drag=false;motion={}
            home=newHome;lower=newMin;upper=newMax;focus=home;height=48
            if animation then animation:destroy();animation=nil end
            currentWorld=nil;hoverClock=0;syncClock=0
            CAS:BindActionAtPriority("ArmyRoundMovement",movementAction,false,3000,
                Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,
                Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.Space)
            UIS.MouseBehavior=Enum.MouseBehavior.Default
            hud.Enabled=true;actionGui.Enabled=true;adminUI:reset();lobbyPicker:hide();baseBadges:reset();hideAction();updateResources(nil)
            tell("WASD / arrows / screen edges: camera; wheel: zoom; H: home; capture every base to win.")
            runLoading()
            command:FireServer(token,"Sync",{})
        else lower=newMin;upper=newMax end
    elseif active then
        if animation then animation:destroy();animation=nil end
        active=false;token=nil;state=nil;currentWorld=nil;hud.Enabled=false;actionGui.Enabled=false;adminUI:reset();lobbyPicker:hide();baseBadges:reset();hideAction()
        selectedUnits={};selectedBuilding=nil;rallyNext=false
        showHover(nil);restoreCamera();updateResources(nil)
    else
        hud.Enabled=false
    end
end
snapshots.OnClientEvent:Connect(function(incoming)
    if type(incoming)~="table" then return end
    if type(incoming.lobby)=="table" then
        lobbyPicker:update(incoming.lobby,active,incoming.message)
        return
    end
    if type(incoming.token)~="string" or type(incoming.resources)~="table" then return end
    phase()
    local sequence=incoming.sequence
    if type(sequence)~="number" or sequence~=sequence then return end
    if not active or incoming.token~=token or sequence<lastSequence then return end
    lastSequence=sequence;state=incoming
    if type(incoming.message)=="string" then tell(incoming.message) end
    updateResources(incoming.resources)
    adminUI:update(incoming.wish)
    baseBadges:update(incoming.bases,incoming.roster)
    if type(incoming.message)=="string" and incoming.wish and incoming.wish.canType then
        adminUI:report(incoming.message,incoming.wish.ownDraft)
    end
    if currentTarget and currentTarget.kind=="Building" then
        local b=incoming.buildings[currentTarget.key]
        if not b then hideAction()
        elseif panelVersion~=currentTarget.key..":"..b.level..":"..tostring(b.upgrading>0) then showAction(currentTarget)
        elseif b.upgrading>0 then panelInfo.Text="Upgrading: "..b.upgrading.."s" end
    end
end)
for _,name in ipairs(Data.ResourceOrder) do
    local row=currencies:FindFirstChild(name)
    if row and row:FindFirstChild("ActualButton") then
        row.ActualButton.Activated:Connect(function() if active then tell(Data.ResourceHelp[name] or name) end end)
    end
end
UIS.InputBegan:Connect(function(input,processed)
    if not active or processed or blockedInput() then return end
    if input.UserInputType==Enum.UserInputType.MouseButton3 then drag=true
    elseif input.UserInputType==Enum.UserInputType.MouseButton2 then if not overButton() then order(cast()) end
    elseif input.UserInputType==Enum.UserInputType.MouseButton1 then if not overButton() then activate(cast()) end
    elseif input.UserInputType==Enum.UserInputType.Keyboard then
        local code=input.KeyCode
        local choices={[Enum.KeyCode.One]="Barbarian",[Enum.KeyCode.Two]="Archer",[Enum.KeyCode.Three]="Giant",[Enum.KeyCode.Four]="Wizard"}
        if choices[code] then lastKind=choices[code];send("Train",{kind=lastKind})
        elseif code==Enum.KeyCode.H then focus=home
        elseif code==Enum.KeyCode.X then selectedUnits={};tell("All troops selected.")
        elseif code==Enum.KeyCode.U then
            local key=hovered and hovered.kind=="Building" and hovered.owner==tostring(player.UserId) and hovered.key or selectedBuilding
            if key then send("Upgrade",{key=key}) else tell("Point at one of your buildings and press U.") end
        elseif code==Enum.KeyCode.R then send("Research",{kind=lastKind})
        elseif code==Enum.KeyCode.E then activate(cast())
        elseif code==Enum.KeyCode.P then
            -- Admin events are awarded by the server; P never grants or opens a
            -- free-form command box.
        end
    end
end)

-- World interaction for phones/tablets.  A short tap activates the same
-- target as a left click; dragging pans the top-down map; holding briefly on
-- the map sends the army there (the mobile equivalent of right click).  UI
-- touches are left to GuiButton.Activated and never leak into the world.
UIS.TouchStarted:Connect(function(input,processed)
    if not active or processed or blockedInput() or touchId then return end
    local p=input.Position
    touchId=input;touchStart=Vector2.new(p.X,p.Y);touchLast=touchStart
    touchMoved=false;touchStartedAt=os.clock()
    touchOverGui=overButton(p.X,p.Y)
end)
UIS.TouchMoved:Connect(function(input,processed)
    if input~=touchId or not active or blockedInput() then return end
    local p=input.Position;local now=Vector2.new(p.X,p.Y)
    local delta=now-touchLast;touchLast=now
    if touchOverGui then return end
    if (now-touchStart).Magnitude>=touchPanThreshold then touchMoved=true end
    if not touchMoved then return end
    local camera=Workspace.CurrentCamera
    local pixels=camera and camera.ViewportSize.Y or 720
    local scale=2*height*math.tan(math.rad(45/2))/math.max(1,pixels)
    focus=focus+Vector3.new(-delta.X,0,-delta.Y*1.16)*scale
end)
UIS.TouchEnded:Connect(function(input,processed)
    if input~=touchId then return end
    local p=input.Position;local wasGui=touchOverGui
    local duration=os.clock()-touchStartedAt
    touchId=nil;touchStart=nil;touchLast=nil;touchOverGui=nil
    if processed or not active or blockedInput() or wasGui then return end
    if touchMoved then return end
    local hit=castAt(p.X,p.Y)
    if duration>=.55 then order(hit) else activate(hit) end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton3 then drag=false end
    if input.KeyCode then motion[input.KeyCode]=false end
end)
UIS.WindowFocusReleased:Connect(function()
    windowFocused=false;motion={};drag=false
    touchId=nil;touchStart=nil;touchLast=nil;touchMoved=false;touchOverGui=nil
end)
UIS.WindowFocused:Connect(function() windowFocused=true end)
UIS.InputChanged:Connect(function(input,processed)
    if not active or blockedInput() then return end
    if input.UserInputType==Enum.UserInputType.MouseWheel and not processed then
        height=math.clamp(height-input.Position.Z*5,22,160)
    elseif input.UserInputType==Enum.UserInputType.MouseMovement and drag then
        local camera=Workspace.CurrentCamera
        local pixels=camera and camera.ViewportSize.Y or 720
        local scale=2*height*math.tan(math.rad(45/2))/math.max(1,pixels)
        focus=focus+Vector3.new(-input.Delta.X,0,-input.Delta.Y*1.16)*scale
    end
end)
local function down(key)
    if motion[key]~=nil then return motion[key] end
    return UIS:IsKeyDown(key)
end
RunService:BindToRenderStep("ArmyRoundCamera",Enum.RenderPriority.Camera.Value+1,function(dt)
    if not active then return end
    local camera=Workspace.CurrentCamera;if not camera then return end
    if not currentWorld or not currentWorld.Parent then
        local rounds=Workspace:FindFirstChild("ArmyRounds")
        currentWorld=rounds and rounds:FindFirstChild(player:GetAttribute("RoundModel") or "") or nil
    end
    if currentWorld and not animation then animation=Animations.new(currentWorld) end
    if animation then animation:step(dt,camera.CFrame.Position) end
    local step=math.clamp(dt,0,0.1);local speed=height*0.8
    if not blockedInput() then
        local x,z=0,0
        if down(Enum.KeyCode.A) or down(Enum.KeyCode.Left) then x=x-1 end
        if down(Enum.KeyCode.D) or down(Enum.KeyCode.Right) then x=x+1 end
        if down(Enum.KeyCode.W) or down(Enum.KeyCode.Up) then z=z-1 end
        if down(Enum.KeyCode.S) or down(Enum.KeyCode.Down) then z=z+1 end
        -- Edge panning does not depend on GUI hit testing: the left resource panel
        -- must never prevent the camera from travelling left.
        if x==0 and z==0 and not drag and UIS.MouseEnabled then
            local pointer=UIS:GetMouseLocation();local view=camera.ViewportSize
            if pointer.X>=0 and pointer.Y>=0 and pointer.X<=view.X and pointer.Y<=view.Y then
                if pointer.X<=12 then x=-1 elseif pointer.X>=view.X-12 then x=1 end
                if pointer.Y<=12 then z=-1 elseif pointer.Y>=view.Y-12 then z=1 end
            end
        end
        local delta=Vector3.new(x,0,z)
        if delta.Magnitude>0 then focus=focus+delta.Unit*speed*step end
    end
    focus=Vector3.new(math.clamp(focus.X,lower.X,upper.X),home.Y,math.clamp(focus.Z,lower.Z,upper.Z))
    camera.CameraType=Enum.CameraType.Scriptable;camera.FieldOfView=45
    camera.CFrame=CFrame.lookAt(focus+Vector3.new(0,height,height*0.58),focus)
    camera.Focus=CFrame.new(focus)
    hoverClock=hoverClock+dt;syncClock=syncClock+dt
    if hoverClock>=0.12 then
        hoverClock=0
        if not blockedInput() and not overButton() then local hit=cast();showHover(hit and classify(hit.Instance) or nil) else showHover(nil) end
        resizeWindows()
    end
    if syncClock>=2 then syncClock=0;command:FireServer(token,"Sync",{}) end
end)
for _,name in ipairs({"ScenePhase","RoundToken","RoundHome","RoundBoundsMin","RoundBoundsMax","RoundModel"}) do
    player:GetAttributeChangedSignal(name):Connect(phase)
end
player.CharacterAdded:Connect(function() task.defer(phase) end)
phase()
