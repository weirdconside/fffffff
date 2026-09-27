-- Native scene/model adapter. Gameplay state lives only in RoundState.
local World = {}
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local shared = ReplicatedStorage:WaitForChild("ArmyRoundShared")
local Icons = require(shared:WaitForChild("ResourceIcons"))
local Theme = require(shared:WaitForChild("StudTheme"))
local assets = assert(ServerStorage:FindFirstChild("ArmyAssets"), "ArmyAssets missing")
local function effect(model,kind)
    model:SetAttribute("RoundEffectKind",kind)
    model:SetAttribute("RoundEffectAt",Workspace:GetServerTimeNow())
    model:SetAttribute("RoundEffectSerial",(model:GetAttribute("RoundEffectSerial") or 0)+1)
end
local environment = assert(ServerStorage:FindFirstChild("ArmyEnvironment"), "ArmyEnvironment missing")
local function folder(name,parent)
    local o=Instance.new("Folder");o.Name=name;o.Parent=parent;return o
end
local function vec(p) return Vector3.new(p.x,p.y,p.z) end
local function point(v) return {x=v.X,y=v.Y,z=v.Z} end
local function rootOf(model)
    if model:IsA("BasePart") then return model end
    return model.PrimaryPart or model:FindFirstChild("Root",true) or model:FindFirstChildWhichIsA("BasePart",true)
end
local function physical(model,query)
    local list=model:GetDescendants();if model:IsA("BasePart") then table.insert(list,model) end
    for _,o in ipairs(list) do
        if o:IsA("BasePart") then
            o.Anchored=true;o.CanTouch=false
            o.AssemblyLinearVelocity=Vector3.new(0,0,0);o.AssemblyAngularVelocity=Vector3.new(0,0,0)
            if o.Transparency>=1 then o.CanCollide=false;o.CanQuery=false else o.CanQuery=query~=false end
        elseif o:IsA("BaseScript") then o.Disabled=true end
    end
end
local function bounds(model)
    local lo=Vector3.new(math.huge,math.huge,math.huge);local hi=-lo
    local list=model:GetDescendants();if model:IsA("BasePart") then table.insert(list,model) end
    for _,p in ipairs(list) do
        if p:IsA("BasePart") and p.Transparency<1 then
            local c=p.CFrame;local a,b,d=c.RightVector,c.UpVector,c.LookVector;local sz=p.Size/2
            local half=Vector3.new(math.abs(a.X)*sz.X+math.abs(b.X)*sz.Y+math.abs(d.X)*sz.Z,
                math.abs(a.Y)*sz.X+math.abs(b.Y)*sz.Y+math.abs(d.Y)*sz.Z,
                math.abs(a.Z)*sz.X+math.abs(b.Z)*sz.Y+math.abs(d.Z)*sz.Z)
            local x,y=p.Position-half,p.Position+half
            lo=Vector3.new(math.min(lo.X,x.X),math.min(lo.Y,x.Y),math.min(lo.Z,x.Z));hi=Vector3.new(math.max(hi.X,y.X),math.max(hi.Y,y.Y),math.max(hi.Z,y.Z))
        end
    end
    if lo.X==math.huge then local r=rootOf(model);lo=r and r.Position or Vector3.new();hi=lo end
    return lo,hi
end
local function sourceLabel(model,title,info)
    local r=rootOf(model);if not r then return nil end
    local ui=assets.UI.ComponentHover:Clone();ui.Name="RoundHover";ui.Adornee=r
    ui.AlwaysOnTop=true;ui.MaxDistance=200;ui.Enabled=false
    local _,hi=bounds(model)
    ui.StudsOffsetWorldSpace=Vector3.new(0,math.max(1.3,hi.Y-r.Position.Y+1.1),0)
    ui.CompName.Text=title;ui.Info.Text=info or "";ui.Parent=model
    return ui
end
local function sourceCost(data,cost)
    local text={};for _,r in ipairs(data.ResourceOrder) do if cost[r] then text[#text+1]=tostring(cost[r]).." "..(data.ResourceNames[r] or r) end end
    return table.concat(text," / ")
end
local function levelAsset(kind,level)
    for _,f in ipairs(assets.BuildingLevels:GetChildren()) do
        if f.Name:lower()==kind:lower() then return f:FindFirstChild(tostring(level)) end
    end
    return nil
end
local function placeResource(template,cf)
    local m=template:Clone();physical(m,true)
    local r=rootOf(m);assert(r,"Resource has no root")
    m.PrimaryPart=r
    local lo=bounds(m);local offset=r.Position.Y-lo.Y
    m:PivotTo(cf+Vector3.new(0,offset,0))
    return m
end
function World.create(data,roomId,token,group,runtime)
    local w={data=data,players={},units={},unitFolder=nil,central={},layouts={},territories={},territoryModels={},names={},token=token,deadUnits={}}
    local m=Instance.new("Model");m.Name="ArmyRound_"..token;w.model=m
    w.cache=folder("RoundCache_"..token,ServerStorage)
    local ok,err=pcall(function()
        local env=environment:Clone();env.Name="Environment";physical(env,true)
        -- Mark only the native water surface. Animations never infer water from
        -- arbitrary descendant names, so terrain and islands stay stationary.
        local ocean=env:FindFirstChild("Ocean",true)
        if ocean then
            local top=ocean:FindFirstChild("OceanTop",true)
            if top and top:IsA("BasePart") then top:SetAttribute("RoundWater",true);top:SetAttribute("RoundWaterSurface",true) end
        end
        env:PivotTo(CFrame.new(6000,0,roomId*6000));env.Parent=m;w.environment=env
        local markers=assert(env:FindFirstChild("PlotLocations"),"Original PlotLocations missing")
        local slots=#group==3 and {"1","3","5"} or {"1","4","2","5","3","6"}
        for _,p in ipairs(markers:GetChildren()) do if p:IsA("BasePart") then p.Transparency=1;p.CanCollide=false;p.CanQuery=false end end
        local i=0
        for _,tile in ipairs(env:GetChildren()) do
            if tile.Name=="MiddleTile" and tile:IsA("Model") then
                local r=tile:FindFirstChild("Root")
                if r and r:IsA("BasePart") then i=i+1;w.central["C:"..i]=point(r.Position+Vector3.new(0,r.Size.Y/2,0)) end
            end
        end
        -- Rebuild all island objectives from immutable marker positions, never donor owners.
        local territoryFolder=env:FindFirstChild("Territories")
        local zones=territoryFolder and territoryFolder:GetChildren() or {}
        table.sort(zones,function(a,b)
            if math.abs(a.Position.Z-b.Position.Z)>0.01 then return a.Position.Z<b.Position.Z end
            return a.Position.X<b.Position.X
        end)
        for index,zone in ipairs(zones) do
            if zone:IsA("BasePart") then
                local best,dd=nil,math.huge
                for _,pos in pairs(w.central) do
                    local distance=(Vector3.new(pos.x,zone.Position.Y,pos.z)-zone.Position).Magnitude
                    if distance<dd then dd=distance;best=pos end
                end
                assert(best and dd<8,"An island base has no walkable native tile")
                local id="Island:"..index
                w.territories[id]={tier=zone.Name,pos={x=best.x,y=best.y,z=best.z},goldRate=zone:GetAttribute("GoldPerSecond") or 0.05}
                w.territoryModels[id]=zone
                zone:SetAttribute("RoundBase",id);zone:SetAttribute("RoundOwner","")
                zone:SetAttribute("OwnerName","");zone:SetAttribute("OwnerUserId",0)
                zone:SetAttribute("Progress",0);zone:SetAttribute("Mode","Neutral")
                zone.CanCollide=false;zone.CanQuery=true;zone.CanTouch=false
            end
        end
        w.unitFolder=folder("Units",m)
        for index,player in ipairs(group) do
            local uid=tostring(player.UserId)
            w.names[uid]=player.Name or ("Player "..index)
            local marker=assert(markers:FindFirstChild(slots[index]),"Not enough original plot markers")
            local cf=marker.CFrame
            local plot=assets.ArmyPlotTemplate:Clone();physical(plot,true);plot:PivotTo(cf)
            plot.Name="Plot_"..uid;plot:SetAttribute("RoundOwner",uid)
            local v={model=plot,lands={},buildings={},nodes={},expand={},activeLevels={},labels={},nodeHP={},rotation=cf-cf.Position,buildingSources={},buildingAnchors={},displayReady={},buildingRetry={},nativeSigns={}}
            v.colour=({Color3.fromRGB(68,176,250),Color3.fromRGB(246,185,56),Color3.fromRGB(170,104,232),Color3.fromRGB(74,208,142),Color3.fromRGB(236,126,179),Color3.fromRGB(244,104,91)})[index] or Color3.fromRGB(224,224,224)
            v.storage=folder("Hidden_"..uid,w.cache)
            v.landFolder=plot:FindFirstChild("Land")
            for _,land in ipairs(v.landFolder:GetChildren()) do v.lands[land.Name]=land;land:SetAttribute("RoundLand",land.Name);land:SetAttribute("RoundOwner",uid);land.Parent=v.storage end
            local comps=plot:FindFirstChild("Components")
            for _,b in ipairs(comps:GetChildren()) do local key=b:GetAttribute("RoundBuildingKey");if key then v.buildings[key]=b;b:SetAttribute("RoundOwner",uid);b.Parent=v.storage else b:Destroy() end end
            v.componentFolder=comps;v.resourceFolder=folder("Resources",plot);v.expandFolder=folder("Expansions",plot)
            local originals=folder("BuildingOriginals_"..uid,w.cache)
            for key,building in pairs(v.buildings) do
                local lo,hi=bounds(building)
                v.buildingAnchors[key]=Vector3.new((lo.X+hi.X)/2,lo.Y,(lo.Z+hi.Z)/2)
                local backup=building:Clone();backup.Parent=originals;v.buildingSources[key]=backup
            end
            local resourceRoots=plot:FindFirstChild("ResourceRoots");v.resourceFrames={}
            for _,r in ipairs(resourceRoots:GetChildren()) do local key=r:GetAttribute("RoundResourceKey");if key then v.resourceFrames[key]=r.CFrame end end
            resourceRoots:Destroy()
            local misc=plot:FindFirstChild("Misc");if misc then misc:Destroy() end
            local plotRoot=plot:FindFirstChild("Root");plotRoot:ClearAllChildren();plotRoot.CanQuery=false;plotRoot.CanCollide=false
            plot.Parent=m;w.players[uid]=v
            local layout={lands={},buildings={},nodes={}}
            for name,land in pairs(v.lands) do local r=land:FindFirstChild("Root");layout.lands[name]=point(r.Position+Vector3.new(0,r.Size.Y/2,0)) end
            for key,d in pairs(data.Buildings) do
                local p=cf:PointToWorldSpace(vec(d.pos));layout.buildings[key]={x=p.X,y=layout.lands[d.land].y,z=p.Z}
                local b=v.buildings[key];if b then b:SetAttribute("RoundKind",d.kind) end
            end
            for key,d in pairs(data.ResourceNodes) do local p=cf:PointToWorldSpace(vec(d.pos));layout.nodes[key]={x=p.X,y=layout.lands[d.land].y,z=p.Z} end
            w.layouts[uid]=layout;v.home=vec(layout.lands.S1)
            -- Use the source wooden bridge, not a new platform, to join each home to the native centre.
            local nearest,nearestDistance=nil,math.huge
            for key,c in pairs(w.central) do
                if key:sub(1,2)=="C:" then
                    local d=(Vector3.new(c.x,v.home.Y,c.z)-v.home).Magnitude
                    if d<nearestDistance then nearestDistance=d;nearest=vec(c) end
                end
            end
            assert(nearest and nearestDistance<28,"No central landing for source bridge")
            local midpoint=(v.home+nearest)/2
            local bridge=assets.NativeBridge:Clone();physical(bridge,true)
            local deck=assert(bridge:FindFirstChild("Collide"),"Native bridge deck missing")
            bridge.PrimaryPart=deck
            local at=midpoint-Vector3.new(0,deck.Size.Y/2,0)
            bridge:PivotTo(CFrame.lookAt(at,Vector3.new(nearest.X,at.Y,nearest.Z)))
            bridge.Name="NativeBridge_"..uid;bridge.Parent=v.storage;v.bridge=bridge
            local gate=assets.Expand:Clone();physical(gate,true);gate.Name="BuildBridge"
            gate.CFrame=CFrame.new(v.home:Lerp(nearest,0.26)+Vector3.new(0,0.07,0))*v.rotation
            gate.CanCollide=false;gate.CanQuery=true;gate:SetAttribute("RoundOwner",uid);gate:SetAttribute("RoundExpansion","BRIDGE")
            gate.Parent=v.expandFolder;v.bridgeGate=gate
            sourceLabel(gate,"BRIDGE",sourceCost(data,data.BridgeCost))
            deck.CanCollide=true;deck.CanQuery=true;deck.CanTouch=false
            w.central["Bridge:"..uid]=point(midpoint)
            layout.bridgeLanding=point(nearest)
        end
        -- Camera bounds cover every future plot tile as well as the native centre.
        local lo=Vector3.new(math.huge,0,math.huge);local hi=Vector3.new(-math.huge,0,-math.huge)
        local function include(p)
            lo=Vector3.new(math.min(lo.X,p.x),0,math.min(lo.Z,p.z))
            hi=Vector3.new(math.max(hi.X,p.x),0,math.max(hi.Z,p.z))
        end
        for _,p in pairs(w.central) do include(p) end
        for _,layout in pairs(w.layouts) do for _,p in pairs(layout.lands) do include(p) end end
        w.cameraMin=lo-Vector3.new(24,0,24);w.cameraMax=hi+Vector3.new(24,0,24)
        w.center=(lo+hi)/2
        do
        end
        m:SetAttribute("RoundToken",token);m.Parent=runtime
    end)
    if not ok then m:Destroy();w.cache:Destroy();error(err) end
    return w
end
local function showBuilding(w,uid,key,b)
    local v=w.players[uid];local model=v.buildings[key]
    local installed=model and model.Parent==v.componentFolder
    local need=not installed or v.activeLevels[key]~=b.level
    if need and (not v.buildingRetry[key] or w.elapsed>=v.buildingRetry[key]) then
        -- Construct, position, validate and parent the replacement BEFORE releasing
        -- the old model. Never depend on a live model for an immutable anchor.
        local candidate
        local ok,err=pcall(function()
            local source=(b.level>1 and levelAsset(b.kind,b.level)) or v.buildingSources[key]
            if not source then source=v.buildingSources[key] end
            assert(source and source:IsA("Model"),"Missing building template: "..key)
            candidate=source:Clone();physical(candidate,true)
            candidate:PivotTo(v.rotation)
            local lo,hi=bounds(candidate)
            assert((hi-lo).Magnitude>.05,"Building has no visible geometry: "..key)
            local anchor=assert(v.buildingAnchors[key],"Missing building anchor")
            local base=Vector3.new((lo.X+hi.X)/2,lo.Y,(lo.Z+hi.Z)/2)
            candidate:PivotTo(candidate:GetPivot()+(anchor-base))
            candidate.Name=b.kind
            candidate:SetAttribute("RoundOwner",uid);candidate:SetAttribute("RoundBuildingKey",key);candidate:SetAttribute("RoundKind",b.kind)
            local oldLabel=candidate:FindFirstChild("RoundHover");if oldLabel then oldLabel:Destroy() end
            local hit=candidate:FindFirstChild("RoundHitbox");if hit then hit:Destroy() end
            lo,hi=bounds(candidate)
            hit=Instance.new("Part");hit.Name="RoundHitbox";hit.Anchored=true;hit.Transparency=1
            hit.CanCollide=false;hit.CanTouch=false;hit.CanQuery=true;hit.CastShadow=false
            hit.Size=Vector3.new(math.max(2,hi.X-lo.X),math.max(2,hi.Y-lo.Y),math.max(2,hi.Z-lo.Z))
            hit.CFrame=CFrame.new((lo+hi)/2);hit.Parent=candidate
            local label=sourceLabel(candidate,w.data.BuildingNames[b.kind] or b.kind,"")
            local nativeSigns={}
            local resource=w.data.WorkerResources[b.kind] or (b.kind=="GoldMine" and "Gold")
            for _,o in ipairs(candidate:GetDescendants()) do
                if o:IsA("BillboardGui") then
                    if o.Name=="StorageDisplay" and resource then Icons.fixBillboard(o,resource) end
                elseif o:IsA("TextLabel") and o.Name=="TextLabel" then nativeSigns[#nativeSigns+1]=o end
            end
            candidate.Parent=v.componentFolder
            assert(candidate:IsDescendantOf(v.model),"Building installation failed")
            local previous=model
            v.buildings[key]=candidate;v.labels[key]=label
            v.nativeSigns=v.nativeSigns or {};v.nativeSigns[key]=nativeSigns
            v.activeLevels[key]=b.level;v.buildingRetry[key]=nil
            model=candidate;installed=true
            effect(model,"Building")
            if previous and previous~=model then previous:Destroy() end
        end)
        if not ok then
            if candidate and candidate~=v.buildings[key] then candidate:Destroy() end
            v.buildingRetry[key]=(w.elapsed or 0)+2
            warn("[ArmyRound] Preserving/retrying building "..key..": "..tostring(err))
            -- Safe fallback keeps first-level geometry and interactions available.
            if model and model.Parent~=v.componentFolder then
                pcall(function() model.Parent=v.componentFolder end)
            end
        end
    end
    if not model or not model.Parent then return end
    local c=w.data.Components.Components[b.kind];local lv=c and c.Levels and c.Levels[b.level];local st=lv and lv.Stats or {}
    for _,label in ipairs(v.nativeSigns[key] or {}) do
        if w.data.WorkerResources[b.kind] then label.Text=math.floor(b.store).."/"..(st.Storage or 60)
        elseif b.kind=="GoldMine" then label.Text=math.floor(b.store).."/"..(st.GoldCap or 10)
        end
    end
    if model:GetAttribute("RoundCollect")~=(b.collectSerial or 0) then
        model:SetAttribute("RoundCollect",b.collectSerial or 0)
        if (b.collectSerial or 0)>0 then effect(model,"Collect") end
    end
    if model:GetAttribute("RoundCraft")~=(b.craftSerial or 0) then
        model:SetAttribute("RoundCraft",b.craftSerial or 0)
        if (b.craftSerial or 0)>0 then effect(model,"Craft") end
    end
    model:SetAttribute("RoundStore",math.floor(b.store));model:SetAttribute("RoundLevel",b.level)
    local label=v.labels[key]
    if label then
        local text="Lv. "..b.level
        if b.upgrade then text=text.." | "..math.ceil(b.upgrade.left).." s"
        elseif w.data.WorkerResources[b.kind] or b.kind=="GoldMine" then text=text.." | "..math.floor(b.store).." | CLICK"
        elseif b.kind=="Barracks" then text=text.." | 1 - 4"
        elseif b.craft and #b.craft>0 then text=text.." | "..#b.craft.." queued"
        else text=text.." | U" end
        label.Info.Text=text
    end
end
local function showResource(w,uid,key,node)
    local v=w.players[uid];local model=v.nodes[key]
    if not model then
        local source=assert(assets.Resources:FindFirstChild(node.kind),"Missing native resource "..node.kind)
        local cf=v.resourceFrames[key]
        local target=CFrame.new(vec(node.pos))
        if cf then target=target*(cf-cf.Position) end
        model=placeResource(source,target)
        model.Name=key;model:SetAttribute("RoundOwner",uid);model:SetAttribute("RoundResourceKey",key)
        -- The wind client only animates explicit resource roots. This prevents
        -- accidental pivoting of an entire land/terrain model.
        if node.kind=="Pine Tree" then
            model:SetAttribute("RoundWind",true);model:SetAttribute("RoundWindAmplitude",0.035)
        end
        effect(model,"Resource");model.Parent=v.resourceFolder;v.nodes[key]=model
        for _,p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then p:SetAttribute("NativeTransparency",p.Transparency) end end
    end
    local stage=node.hp<=0 and 0 or math.ceil(3*node.hp/node.maxHP)
    if v.nodeHP[key]~=stage then
        for _,child in ipairs(model:GetChildren()) do
            local n=tonumber(child.Name)
            if n then for _,p in ipairs(child:GetDescendants()) do
                if p:IsA("BasePart") then p.Transparency=n<=stage and (p:GetAttribute("NativeTransparency") or 0) or 1;p.CanQuery=n<=stage;p.CanCollide=false end
            end end
        end
        if v.nodeHP[key]~=nil then effect(model,stage==0 and "Harvest" or "Regrow") end
        v.nodeHP[key]=stage
    end
end
local function showExpansions(w,uid,p)
    local v=w.players[uid]
    for key,d in pairs(w.data.Lands) do
        local available=not p.lands[key] and p.cleared[d.requires]
        if available and not v.expand[key] then
            local parent=vec(p.layout.lands[d.requires]);local target=vec(p.layout.lands[key])
            local pos=parent:Lerp(target,0.38)+Vector3.new(0,0.07,0)
            local marker=assets.Expand:Clone();physical(marker,true);marker.Name="Expand_"..key
            marker.CFrame=CFrame.new(pos)*v.rotation;marker.CanCollide=false;marker.CanQuery=true
            marker:SetAttribute("RoundOwner",uid);marker:SetAttribute("RoundExpansion",key)
            marker.Parent=v.expandFolder
            local label=sourceLabel(marker,key,sourceCost(w.data,d.cost));if label then label.Enabled=false end
            v.expand[key]=marker
        elseif not available and v.expand[key] then v.expand[key]:Destroy();v.expand[key]=nil end
    end
end
local function rigMetadata(model,root)
    local named={};local assigned={};local links={}
    for _,p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then named[p.Name]=p;links[p]={} end
    end
    for _,j in ipairs(model:GetDescendants()) do
        if j:IsA("WeldConstraint") or j:IsA("Weld") then
            if links[j.Part0] and links[j.Part1] then
                links[j.Part0][#links[j.Part0]+1]=j.Part1;links[j.Part1][#links[j.Part1]+1]=j.Part0
            end
        end
    end
    for _,name in ipairs({"Head","RArm","LArm","RLeg","LLeg","Torso"}) do
        local p=named[name]
        if p then
            local queue={p};assigned[p]=name
            for _,part in ipairs(queue) do for _,other in ipairs(links[part]) do
                if not assigned[other] then assigned[other]=name;queue[#queue+1]=other end
            end end
        end
    end
    local inverse=root.CFrame:Inverse()
    for _,p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p~=root then
            local group=assigned[p]
            if not group then
                local parent=p.Parent;local tool=false
                while parent and parent~=model do if parent.Name=="Axe" or parent.Name=="Club" then tool=true end;parent=parent.Parent end
                group=(tool or p.Name=="Bow") and "RArm" or (p.Name=="Hat" and "Head" or "Torso")
            end
            local limb=named[group] or named.Torso or root
            local hinge=inverse:PointToWorldSpace(limb.Position+Vector3.new(0,limb.Size.Y*.45,0))
            p:SetAttribute("RoundRest",inverse*p.CFrame);p:SetAttribute("RoundLimb",group);p:SetAttribute("RoundHinge",hinge)
        end
    end
    for _,j in ipairs(model:GetDescendants()) do
        if j:IsA("Motor6D") or j:IsA("WeldConstraint") or j:IsA("Weld") or j:IsA("Animator") then j:Destroy() end
    end
end
local function spawnVisual(w,u)
    local source=assets.Entities:FindFirstChild(u.kind);assert(source,"Missing native unit "..u.kind)
    local m=source:Clone();physical(m,true)
    local r=rootOf(m);assert(r,"Unit root missing");m.PrimaryPart=r
    local lo=bounds(m);local foot=r.Position.Y-lo.Y
    for _,p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end
    rigMetadata(m,r)
    m:SetAttribute("RoundKind",u.kind);m:SetAttribute("RoundBornAt",Workspace:GetServerTimeNow())
    m.Name=u.kind.."_"..u.id;m:SetAttribute("RoundUnit",u.id);m:SetAttribute("RoundOwner",u.owner);m:SetAttribute("RoundRole",u.role)
    -- An invisible query target is easier to click than the very small native meshes.
    r.CanQuery=true;r.Size=Vector3.new(1.3,1.8,1.3)
    local health=assets.Healthbar:Clone();health.Name="RoundHealth";health.Adornee=r;health.StudsOffsetWorldSpace=Vector3.new(0,2.1,0);health.MaxDistance=170;health.AlwaysOnTop=true;health.Parent=m
    local bar=health:FindFirstChild("Bar");if bar then Theme.skin(bar,Theme.Colors.Dark) end;local clip=bar and bar:FindFirstChild("Clip")
    local colour=(u.role=="Enemy" or u.role=="Guard") and Color3.fromRGB(235,82,82) or (w.players[u.owner] and w.players[u.owner].colour or Color3.fromRGB(90,210,120))
    if clip and clip:FindFirstChild("Fill") then clip.Fill.BackgroundColor3=colour end
    local chaser=bar and bar:FindFirstChild("Chaser");if chaser then chaser.Visible=false end
    local rec={model=m,root=r,foot=math.max(0.1,foot),last=vec(u.pos),forward=Vector3.new(0,0,-1),health=health}
    m.Parent=w.unitFolder;w.units[u.id]=rec;return rec
end
function World.sync(w,state)
    w.elapsed=state.elapsed
    for uid,v in pairs(w.players) do
        local p=state.players[uid]
        if not p then
            v.model:Destroy();v.storage:Destroy();w.players[uid]=nil
        else
            for key in pairs(p.lands) do
                local land=v.lands[key]
                if land and land.Parent~=v.landFolder then effect(land,"Land");land.Parent=v.landFolder end
                if land then
                    local camp=land:FindFirstChild("EnemyCamp")
                    if camp and p.cleared[key] then camp:Destroy();effect(land,"Clear")
                    elseif camp then
                        camp:SetAttribute("RoundCamp",key);camp:SetAttribute("RoundOwner",uid)
                        if not camp:FindFirstChild("RoundHover") then
                            local ui=sourceLabel(camp,"GUARDED "..key,"CLICK TO SEND YOUR ARMY");if ui then ui.Enabled=true end
                        end
                    end
                end
            end
            for key,b in pairs(p.buildings) do
                showBuilding(w,uid,key,b)
                if b.kind=="Townhall" and v.labels[key] then
                    local base=state.bases[p.baseId]
                    local owner=base and base.owner or nil
                    local title=owner and (w.names[owner] or "Player") or "Neutral"
                    local model=v.buildings[key]
                    model:SetAttribute("RoundBase",p.baseId);model:SetAttribute("RoundOwner",owner or "")
                    model:SetAttribute("RoundOriginalOwner",uid)
                    v.labels[key].CompName.Text=title.." - Town Hall"
                    v.labels[key].Info.Text="HP "..math.ceil(p.baseHP).."/"..p.baseMaxHP.." | CAPTURE BASE"
                elseif b.kind=="Campsite" then
                    local used,cap=0,0
                    for _,u in pairs(state.units) do if u.owner==uid and u.role=="Troop" then used=used+w.data.Troops.Troops[u.kind].Units end end
                    for _,q in ipairs(p.training) do used=used+w.data.Troops.Troops[q.kind].Units end
                    for _,camp in pairs(p.buildings) do if camp.kind=="Campsite" then cap=cap+(w.data.Components.Components.Campsite.Levels[camp.level].Stats.Capacity or 0) end end
                    for _,label in ipairs(v.nativeSigns[key] or {}) do label.Text=used.."/"..cap end
                end
            end
            if (p.researchSerial or 0)~=(v.researchSerial or 0) then
                v.researchSerial=p.researchSerial
                for key,b in pairs(p.buildings) do if b.kind=="TrainingCamp" and v.buildings[key] then effect(v.buildings[key],"Research") end end
            end
            for key,node in pairs(p.nodes) do showResource(w,uid,key,node) end
            showExpansions(w,uid,p)
            if p.bridge then
                if v.bridge.Parent~=v.model then effect(v.bridge,"Bridge");v.bridge.Parent=v.model end
                if v.bridgeGate then v.bridgeGate:Destroy();v.bridgeGate=nil end
            end
        end
    end
    for id,zone in pairs(w.territoryModels) do
        local base=state.bases[id]
        if base then
            local owner=base.owner
            local guards=base.guardsAlive
            if guards==nil then guards=0;for guard in pairs(base.guards) do if state.units[guard] then guards=guards+1 end end end
            if zone:GetAttribute("RoundOwner")~=(owner or "") and owner then effect(zone,"Capture") end
            zone:SetAttribute("RoundOwner",owner or "")
            zone:SetAttribute("OwnerUserId",tonumber(owner) or 0)
            zone:SetAttribute("OwnerName",owner and (w.names[owner] or "Player") or "")
            zone:SetAttribute("Progress",base.progress/w.data.CaptureSeconds)
            zone:SetAttribute("Guards",guards)
            zone:SetAttribute("Mode",guards>0 and "Guarded" or (base.contested and "Contested" or (base.capturer and "Capturing" or (owner and "Owned" or "Neutral"))))
            local gui=zone:FindFirstChildWhichIsA("BillboardGui",true)
            if gui then
                if not gui:GetAttribute("RoundStudStyled") then Theme.billboard(gui);gui:SetAttribute("RoundStudStyled",true) end
                local claimed=gui:FindFirstChild("Claimed")
                if claimed then
                    claimed.Text=guards>0 and ("Guarded ("..guards..")") or (owner and ((w.names[owner] or "Player").."'s base") or "Neutral base")
                end
                local headshot=gui:FindFirstChild("Headshot");if headshot then headshot.Visible=false;headshot.Image="" end
                local bar=gui:FindFirstChild("Bar");local label=bar and bar:FindFirstChild("Label")
                local clip=bar and bar:FindFirstChild("Clip")
                if clip then clip.Size=UDim2.fromScale(base.capturer and math.clamp(base.progress/w.data.CaptureSeconds,0,1) or (owner and 1 or 0),1) end
                if label then
                    label.Text=guards>0 and "CLEAR THE GUARDS" or (base.contested and "CONTESTED" or (base.capturer and ("CAPTURING "..math.floor(100*base.progress/w.data.CaptureSeconds).."%") or (owner and "CAPTURED" or "HOLD WITH TROOPS")))
                end
                gui.Enabled=true;gui.MaxDistance=300
            end
        end
    end
    for id,u in pairs(state.units) do
        local r=w.units[id] or spawnVisual(w,u)
        local pos=vec(u.pos);local delta=Vector3.new(pos.X-r.last.X,0,pos.Z-r.last.Z)
        local walking=delta.Magnitude>0.01
        if walking then r.forward=delta.Unit end
        if u.facing then
            local target=vec(u.facing)-pos;target=Vector3.new(target.X,0,target.Z)
            if target.Magnitude>.01 then r.forward=target.Unit end
        end
        local pivot=pos+Vector3.new(0,r.foot,0)
        local pose=CFrame.lookAt(pivot,pivot+r.forward)
        -- Root/selection geometry stays authoritative; clients smooth and animate visible limbs.
        if not r.placed or walking or not r.facing or (r.forward-r.facing).Magnitude>.001 then
            r.model:PivotTo(pose);r.placed=true;r.facing=r.forward
        end
        r.model:SetAttribute("RoundPose",pose);r.model:SetAttribute("RoundMoving",walking)
        r.model:SetAttribute("RoundMode",u.mode);r.model:SetAttribute("RoundAttack",u.attackSerial or 0)
        r.model:SetAttribute("RoundWork",u.workSerial or 0)
        if u.targetPos then r.model:SetAttribute("RoundTarget",vec(u.targetPos)) end
        r.last=pos
        if r.hp~=u.hp then r.model:SetAttribute("RoundHP",math.ceil(u.hp));r.hp=u.hp end
        if r.maxHP~=u.maxHP then r.model:SetAttribute("RoundMaxHP",u.maxHP);r.maxHP=u.maxHP end
        local bar=r.health:FindFirstChild("Bar");local clip=bar and bar:FindFirstChild("Clip")
        if clip then clip.Size=UDim2.fromScale(math.max(0,u.hp/u.maxHP),1) end
        r.health.Enabled=u.role~="Worker" or u.hp<u.maxHP
    end
    for id,r in pairs(w.units) do
        if not state.units[id] then
            r.model:SetAttribute("RoundDead",true);r.model:SetAttribute("RoundDeathAt",Workspace:GetServerTimeNow())
            r.health.Enabled=false;r.root.CanQuery=false
            for _,p in ipairs(r.model:GetDescendants()) do if p:IsA("BasePart") then p.CanQuery=false end end
            w.deadUnits[id]={model=r.model,expires=state.elapsed+.85};w.units[id]=nil
        end
    end
    for id,r in pairs(w.deadUnits) do if state.elapsed>=r.expires then r.model:Destroy();w.deadUnits[id]=nil end end
end
function World.destroy(w)
    if w.model then w.model:Destroy() end
    if w.cache then w.cache:Destroy() end
end
return World
