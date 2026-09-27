-- New deterministic server simulation. It does not execute the decompiled clients.
-- Geometry, costs, unit stats and recipes come from RoundData/the supplied models.
local State = {}
-- Use the Roblox sibling module in Studio; the relative fallback keeps the
-- state simulation runnable under Lune for deterministic tests.
local WishRules
do
    local ok, module = pcall(function() return require(script.Parent.WishRules) end)
    if ok then WishRules = module else WishRules = require("./WishRules.ModuleScript") end
end
local function copy(t)
    local out = {}
    for k,v in pairs(t or {}) do out[k] = type(v)=="table" and copy(v) or v end
    return out
end
local function finite(x) return type(x)=="number" and x==x and math.abs(x)<1000000 end
local function point(p) return type(p)=="table" and finite(p.x) and finite(p.y) and finite(p.z) end
local function dist(a,b) return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2) end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function sorted(t)
    local keys={}; for k in pairs(t) do keys[#keys+1]=k end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end); return keys
end
local function canPay(p,cost)
    for k,v in pairs(cost or {}) do
        if not finite(v) or v<0 or (p.resources[k] or 0)<v then return false end
    end
    return true
end
local function pay(p,cost) for k,v in pairs(cost or {}) do p.resources[k]=(p.resources[k] or 0)-v end end
local function give(p,k,v)
    if not finite(v) or v<=0 then return end
    p.resources[k]=math.min(999999,(p.resources[k] or 0)+v);p.discovered[k]=true
end
local function bestLevel(p,kind)
    local best=0
    for _,b in pairs(p.buildings) do if b.kind==kind then best=math.max(best,b.level) end end
    return best
end
local function stats(s,b) local c=s.data.Components.Components[b.kind];local d=c and c.Levels and c.Levels[b.level];return d and d.Stats or {} end
function State.capacity(s,p)
    local cap=0
    for _,b in pairs(p.buildings) do if b.kind=="Campsite" then cap=cap+(stats(s,b).Capacity or 0) end end
    return cap
end
function State.housing(s,p)
    local used=0
    for _,u in pairs(s.units) do if u.owner==p.id and u.role=="Troop" then used=used+s.data.Troops.Troops[u.kind].Units end end
    for _,q in ipairs(p.training) do used=used+s.data.Troops.Troops[q.kind].Units end
    return used
end
local function nearest(s,pos)
    local key,dd=nil,math.huge
    for _,k in ipairs(s.navOrder) do local d=dist(pos,s.nav[k]);if d<dd then key,dd=k,d end end
    return key,dd
end
local function rebuildNav(s)
    s.nav={}
    for k,pos in pairs(s.central) do
        local owner=k:match("^Bridge:(.+)$")
        if not owner or (s.players[owner] and s.players[owner].bridge) then s.nav[k]=pos end
    end
    for _,p in pairs(s.players) do
        for land in pairs(p.lands) do s.nav[p.id..":"..land]=p.layout.lands[land] end
    end
    s.navOrder=sorted(s.nav);s.edges={}
    for _,a in ipairs(s.navOrder) do
        s.edges[a]={}
        for _,b in ipairs(s.navOrder) do
            if a~=b and dist(s.nav[a],s.nav[b])<=17.5 and math.abs(s.nav[a].y-s.nav[b].y)<=(s.data.MaxNavStepHeight or 8) then
                s.edges[a][#s.edges[a]+1]=b
            end
        end
    end
    -- Flood-fill walkable components once, so aggro never pulls troops across water.
    s.navRegions={};local region=0
    for _,key in ipairs(s.navOrder) do
        if not s.navRegions[key] then
            region=region+1;local queue={key};s.navRegions[key]=region
            for _,at in ipairs(queue) do
                for _,other in ipairs(s.edges[at]) do
                    if not s.navRegions[other] then s.navRegions[other]=region;queue[#queue+1]=other end
                end
            end
        end
    end
end
local function connected(s,a,b)
    local ka,da=nearest(s,a);local kb,db=nearest(s,b)
    return ka and kb and da<=13 and db<=13 and s.navRegions[ka]==s.navRegions[kb]
end
local function route(s,start,goal)
    local a=nearest(s,start);local b,dd=nearest(s,goal)
    if not a or not b or dd>12 or s.navRegions[a]~=s.navRegions[b] then return nil end
    if a==b then return {copy(goal)} end
    local todo={a};local at=1;local prev={[a]=false}
    while at<=#todo and prev[b]==nil do
        local k=todo[at];at=at+1
        for _,v in ipairs(s.edges[k] or {}) do
            if prev[v]==nil then prev[v]=k;todo[#todo+1]=v end
        end
    end
    if prev[b]==nil then return nil end
    local rev={};local k=b
    while k and k~=a do rev[#rev+1]=copy(s.nav[k]);k=prev[k] end
    local result={}
    -- Start on the current segment; revisiting its centre during pursuit causes oscillation.
    for i=#rev,1,-1 do result[#result+1]=rev[i] end
    result[#result+1]=copy(goal);return result
end
local function go(s,u,pos)
    local path=route(s,u.pos,pos)
    if not path then return false end
    u.path=path;u.pathIndex=1;u.goal=copy(pos);return true
end
local function move(u,dt)
    local budget=u.speed*dt
    u.moved=false
    while u.path and u.pathIndex<=#u.path and budget>0 do
        local target=u.path[u.pathIndex];local d=dist(u.pos,target)
        if d>0.001 then u.moved=true;u.facing=copy(target) end
        if d<=budget or d<0.001 then
            u.pos=copy(target);u.pathIndex=u.pathIndex+1;budget=budget-d
        else
            local r=budget/d;u.pos={x=u.pos.x+(target.x-u.pos.x)*r,y=u.pos.y+(target.y-u.pos.y)*r,z=u.pos.z+(target.z-u.pos.z)*r};budget=0
        end
    end
    if u.path and u.pathIndex>#u.path then u.path=nil end
end
local function spawn(s,p,kind,pos,role,extra)
    s.nextUnit=s.nextUnit+1
    local base=s.data.Troops.Troops[kind]
    local mult=1+((p.research[kind] or 1)-1)*s.data.Research.StatMultPerLevel
    local u={id=tostring(s.nextUnit),owner=p.id,kind=kind,role=role or "Troop",pos=copy(pos),
        hp=base and base.HP*mult or 20,maxHP=base and base.HP*mult or 20,
        damage=base and base.Damage*mult or 0,speed=base and base.WalkSpeed or s.data.WorkerSpeed,
        range=base and (base.Range or 3) or 0,aggro=base and (base.AggroRange or 10) or 0,
        interval=base and (base.AttackInterval or 1) or 1,cooldown=0,chop=0,carry=0,mode="Idle"}
    for k,v in pairs(extra or {}) do u[k]=v end
    u.born=s.elapsed;u.workSerial=0
    s.units[u.id]=u;return u
end
local function addWorkers(s,p,b)
    local resource=s.data.WorkerResources[b.kind]
    if not resource then return end
    local have=0;for _,u in pairs(s.units) do if u.owner==p.id and u.role=="Worker" and u.building==b.key then have=have+1 end end
    for i=have+1,(stats(s,b).Workers or 1)+(b.extraWorkers or 0) do
        local pos=copy(b.pos);pos.x=pos.x+((i%3)-1)*0.75
        spawn(s,p,b.kind=="LumberHut" and "Lumberjack" or "Miner",pos,"Worker",{building=b.key,resource=resource})
    end
end
local function enableLand(s,p,land)
    p.lands[land]=true;p.cleared[land]=true
    for key,d in pairs(s.data.Buildings) do
        if d.land==land and not p.buildings[key] then
            local b={key=key,kind=d.kind,level=1,pos=copy(p.layout.buildings[key]),store=0}
            p.buildings[key]=b;addWorkers(s,p,b)
        end
    end
    for key,d in pairs(s.data.ResourceNodes) do
        if d.land==land and not p.nodes[key] then p.nodes[key]={key=key,kind=d.kind,resource=s.data.ResourceKinds[d.kind],pos=copy(p.layout.nodes[key]),hp=s.data.ResourceHealth[d.kind] or s.data.ResourceHP,maxHP=s.data.ResourceHealth[d.kind] or s.data.ResourceHP,regrow=0} end
    end
end
local function campEnemies(s,p,land)
    local camp={land=land,guards={},cleared=false};p.camps[land]=camp
    local index=0
    for _,kind in ipairs(sorted(s.data.Lands[land].enemies)) do
        for _=1,s.data.Lands[land].enemies[kind] do
            index=index+1;local pos=copy(p.layout.lands[land]);local a=index*2.39996
            pos.x=pos.x+math.cos(a)*2;pos.z=pos.z+math.sin(a)*2
            local dummy={id="camp:"..p.id..":"..land,research={}}
            local u=spawn(s,dummy,kind,pos,"Enemy",{campOwner=p.id,campLand=land,home=copy(pos)})
            camp.guards[u.id]=true
        end
    end
end
local function rally(s,p,goal,camp,base,enemy)
    p.rally={pos=copy(goal),camp=camp,base=base,enemy=enemy}
    local n=0
    for _,id in ipairs(sorted(s.units)) do
        local u=s.units[id]
        if u.owner==p.id and u.role=="Troop" and go(s,u,goal) then
            u.mode="AttackMove";u.orderBase=base;u.orderEnemy=enemy;n=n+1
        end
    end
    return n
end
function State.new(data,layouts,central,territories,options)
    options=type(options)=="table" and options or {}
    local s={data=data,players={},units={},central=copy(central or {}),nav={},navOrder={},edges={},elapsed=0,nextUnit=0,status="Active",winner=nil,pvp=count(layouts)>1,bases={},baseOrder={},baseTotal=0,rng=options.rng}
    for _,uid in ipairs(sorted(layouts)) do
        local p={id=uid,name=(options.names and options.names[uid]) or uid,isBot=options.bots and options.bots[uid] or false,color=copy(options.colors and options.colors[uid]),resources={},discovered={Log=true},layout=copy(layouts[uid]),lands={},cleared={},buildings={},nodes={},camps={},training={},bridge=false,research={},researchJob=nil,defeated=false,active=true,departed=false,collected=0,trained=0,baseHP=500,baseMaxHP=500,admin=false,goldWorkers=0,wishAwards=0,
            perks=copy(options.perks and options.perks[uid]),roundTickets=(options.tickets and tonumber(options.tickets[uid])) or 0}
        for _,r in ipairs(data.ResourceOrder) do p.resources[r]=0 end
        s.players[uid]=p
        for _,land in ipairs(sorted(data.Lands)) do if data.Lands[land].requires=="" then enableLand(s,p,land) end end
    end
    s.wish=WishRules.new(s.players,{rng=s.rng})
    -- Admin commands that create units go through the normal spawn path.
    s.wishHooks={summon=function(state,p,kind,n)
        local troop=state.data.Troops.Troops[kind];if not troop then return end
        -- Summons may overfill housing a little, never without limit.
        if State.housing(state,p)+troop.Units>State.capacity(state,p)+12 then return end
        local at,camp
        for _,key in ipairs(sorted(p.buildings)) do local b=p.buildings[key]
            if b.kind=="Barracks" and not at then at=b.pos end
            if b.kind=="Campsite" and not camp then camp=b.pos end
        end
        at=at or p.layout.lands.S1;camp=camp or at
        for i=1,n do
            local pos=copy(at);pos.x=pos.x+math.cos(i*2.4)*1.2;pos.z=pos.z+math.sin(i*2.4)*1.2
            local u=spawn(state,p,kind,pos,"Troop");u.summoned=true
            local goal=copy(camp);goal.x=goal.x+math.cos(state.nextUnit*2.4)*2;goal.z=goal.z+math.sin(state.nextUnit*2.4)*2
            if p.rally then goal=copy(p.rally.pos);u.mode="AttackMove";u.orderBase=p.rally.base;u.orderEnemy=p.rally.enemy end
            go(state,u,goal)
        end
    end}
    -- Every objective is registered once. Disconnects never reduce the target count.
    for _,uid in ipairs(sorted(s.players)) do
        local p=s.players[uid]
        for _,key in ipairs(sorted(p.buildings)) do
            local b=p.buildings[key]
            if b.kind=="Townhall" then
                local id="Home:"..uid
                s.bases[id]={id=id,kind="Townhall",homePlayer=uid,owner=uid,
                    pos=copy(b.pos),hp=p.baseHP,maxHP=p.baseMaxHP,guards={},progress=0}
                p.baseId=id;break
            end
        end
    end
    for _,id in ipairs(sorted(territories or {})) do
        local d=territories[id]
        local b={id=id,kind="Territory",tier=d.tier,pos=copy(d.pos),owner=nil,
            guards={},progress=0,goldRate=d.goldRate or 0.05,goldWorkers=0}
        s.bases[id]=b
        local n=0
        for _,kind in ipairs(sorted(data.NeutralGuardTiers[d.tier] or {})) do
            for _=1,data.NeutralGuardTiers[d.tier][kind] do
                n=n+1;local pos=copy(b.pos);local a=n*2.39996
                pos.x=pos.x+math.cos(a)*2.5;pos.z=pos.z+math.sin(a)*2.5
                local u=spawn(s,{id="guard:"..id,research={}},kind,pos,"Guard",{home=copy(b.pos),objective=id})
                b.guards[u.id]=true
            end
        end
    end
    s.baseOrder=sorted(s.bases);s.baseTotal=#s.baseOrder
    rebuildNav(s);return s
end
function State.setRng(s,rng)
    if type(rng)=="function" then s.rng=rng;WishRules.setRng(s.wish,rng) end
end
function State.canWish(s,uid,op,eventId)
    return WishRules.canWish(s,uid,op,eventId)
end
function State.hint(s,p)
    if p.defeated then return "Your home base was captured. Sailing back to the harbour." end
    for _,land in ipairs(sorted(p.camps)) do
        if not p.camps[land].cleared then
            local n=0;for _,u in pairs(s.units) do if u.owner==p.id and u.role=="Troop" and u.hp>0 then n=n+1 end end
            if n==0 and #p.training==0 then return land..": guards remain. Click the Barracks / press 1 to train troops; new troops will rally to the camp." end
            return land..": clear the red guards. Left-click a guard or the camp to send your army; X selects all troops."
        end
    end
    if p.collected<25 then return "Start: lumberjacks gather wood. Click the Lumber Hut to collect its stock." end
    if not p.lands.S5 then return "Unlock S5 for 25 Wood: click the expansion marker next to your island." end
    if p.trained<3 then return "Train 3 Barbarians: click the Barracks or press 1. Your Campsite has 10 spaces." end
    local lumber=bestLevel(p,"LumberHut")
    if lumber<2 then return "Point at the Lumber Hut and press U. Level 2 costs 60 Wood." end
    if not p.lands.S12 then return "Unlock S12 for 30 Wood. Clear its camp to get your first stone miners." end
    if not p.cleared.S12 then return "Right-click the S12 camp to send your army. The whistle also issues orders." end
    return "Capture every base to win. 1-4: train; U: upgrade; R: research; H: home camera."
end
function State.action(s,uid,op,payload)
    local p=s.players[uid]
    if not p or p.defeated or not p.active or s.status~="Active" then return false,"This round is no longer active." end
    payload=type(payload)=="table" and payload or {}
    if op=="Collect" then
        local b=p.buildings[payload.key];if not b then return false,"This is not your building." end
        local resource=s.data.WorkerResources[b.kind] or (b.kind=="GoldMine" and "Gold")
        if not resource then return false,"There is nothing to collect here." end
        local n=math.floor(b.store);if n<=0 then return false,"Storage is empty. Your workers will deliver resources shortly." end
        b.store=b.store-n;give(p,resource,n);p.collected=p.collected+n;b.collectSerial=(b.collectSerial or 0)+1
        return true,"Collected: "..n.." "..(s.data.ResourceNames[resource] or resource)
    elseif op=="Expand" then
        local key=payload.key
        if key=="BRIDGE" then
            local target=p
            if payload.owner and payload.owner~=uid then
                target=s.players[payload.owner]
                if not target then return false,"That island does not belong to this round." end
                local landing=target.layout.bridgeLanding
                local nearby=false
                if landing then for _,u in pairs(s.units) do
                    if u.owner==uid and u.role=="Troop" and u.hp>0 and dist(u.pos,landing)<=12 then nearby=true;break end
                end end
                if not nearby then return false,"Move your army to that island's central landing before building its bridge." end
            end
            if target.bridge then return false,"Bridge is already built." end
            if not canPay(p,s.data.BridgeCost) then return false,"Bridge: 250 Wood and 100 Stone required." end
            pay(p,s.data.BridgeCost);target.bridge=true;rebuildNav(s)
            return true,"Bridge built. Armies can now cross this island's landing."
        end
        local d=s.data.Lands[key]
        if not d or p.lands[key] then return false,"That land is already unlocked or does not exist." end
        if not p.cleared[d.requires] then return false,"Unlock and clear the previous land first." end
        if not canPay(p,d.cost) then return false,"Not enough resources to expand." end
        pay(p,d.cost);p.lands[key]=true
        if next(d.enemies) then campEnemies(s,p,key) else enableLand(s,p,key) end
        rebuildNav(s)
        if next(d.enemies) then
            local n=rally(s,p,p.layout.lands[key],key)
            return true,n>0 and ("Unlocked "..key..". Your army is attacking its guards.") or ("Unlocked "..key..". Train troops in the Barracks (1); they will attack the guards.")
        end
        return true,"Unlocked land "..key
    elseif op=="Train" then
        local kind=payload.kind;local d=s.data.Troops.Troops[kind]
        if not d or bestLevel(p,"Barracks")<(d.RequiresBarracks or 1) then return false,"You need Barracks of the required level." end
        if #p.training>=s.data.MaxTrainingQueue then return false,"The training queue is full." end
        if State.housing(s,p)+d.Units>State.capacity(s,p) then return false,"Not enough housing. Upgrade a Campsite with U." end
        if not canPay(p,d.Costs) then return false,"Not enough resources to train this troop." end
        local spawnAt
        for _,key in ipairs(sorted(p.buildings)) do local b=p.buildings[key];if b.kind=="Barracks" then spawnAt=b.pos;break end end
        local bonus=1
        for _,b in pairs(p.buildings) do if b.kind=="Barracks" then bonus=bonus+(stats(s,b).TrainBonus or 0) end end
        pay(p,d.Costs);p.training[#p.training+1]={kind=kind,left=d.TrainTime/bonus,pos=copy(spawnAt)}
        return true,kind.." added to the training queue"
    elseif op=="BuyWorker" then
        local key=payload.key
        if type(key)~="string" then return false,"Select a resource building or captured base." end
        if key:sub(1,5)=="BASE:" then
            local base=s.bases[key:sub(6)]
            if not base or base.owner~=uid then return false,"Capture this base before hiring gold workers." end
            base.goldWorkers=base.goldWorkers or 0
            if base.goldWorkers>=3 then return false,"This base has reached its gold worker limit." end
            local cost={Gold=10}
            if not canPay(p,cost) then return false,"A gold worker costs 10 Gold." end
            pay(p,cost);base.goldWorkers=base.goldWorkers+1;p.goldWorkers=(p.goldWorkers or 0)+1
            local pos=copy(base.pos);local slot=base.goldWorkers
            pos.x=pos.x+((slot%3)-1)*1.1;pos.z=pos.z+math.floor((slot-1)/3)*1.1
            spawn(s,p,"Barbarian",pos,"GoldWorker",{base=base.id,home=copy(base.pos)})
            return true,"Gold worker hired."
        end
        local b=p.buildings[key]
        if not b or not s.data.WorkerResources[b.kind] then return false,"Select a lumber or stone building." end
        local have=0;for _,u in pairs(s.units) do if u.owner==uid and u.role=="Worker" and u.building==key then have=have+1 end end
        local maxWorkers=(stats(s,b).Workers or 1)+3
        if have>=maxWorkers then return false,"This building has reached its worker limit." end
        local cost={Log=5,Gold=2}
        if not canPay(p,cost) then return false,"A worker costs 5 Wood and 2 Gold." end
        pay(p,cost);b.extraWorkers=(b.extraWorkers or 0)+1
        local pos=copy(b.pos);pos.x=pos.x+((have%3)-1)*.75
        spawn(s,p,b.kind=="LumberHut" and "Lumberjack" or "Miner",pos,"Worker",{building=key,resource=s.data.WorkerResources[b.kind]})
        return true,"Worker hired."
    elseif op=="WishDraft" or op=="WishSubmit" or op=="AppendDraft" or op=="AppendSubmit" then
        -- Treat every admin input as untrusted data. A malformed prompt must
        -- produce a normal rejection message and never escape the action path.
        local ok,accepted,message=pcall(WishRules.action,s,uid,op,payload)
        if ok then return accepted,message end
        warn("[ArmyRound] Admin input rejected safely: "..tostring(accepted))
        return false,"This prompt was rejected safely."
    elseif op=="Upgrade" then
        local b=p.buildings[payload.key];if not b then return false,"Select one of your buildings." end
        if b.upgrade then return false,"This building is already upgrading." end
        local c=s.data.Components.Components[b.kind];local d=c and c.Levels and c.Levels[b.level+1]
        if not d then return false,"This building is at its maximum level." end
        local gates=s.data.Components.TownhallGate[b.kind] or {}
        local required=gates[b.level+1] or b.level+1
        if b.kind~="Townhall" and bestLevel(p,"Townhall")<required then return false,"Town Hall level required: "..required end
        local busy=0;local builders=1
        for _,v in pairs(p.buildings) do if v.upgrade then busy=busy+1 end;if v.kind=="BuilderHut" then builders=math.max(builders,stats(s,v).Builders or 1) end end
        if busy>=builders then return false,"All builders are busy." end
        if not canPay(p,d.Cost) then return false,"Not enough resources for this upgrade." end
        pay(p,d.Cost);b.upgrade={left=math.min(d.BuildTime or 5,s.data.MaxBuildSeconds),target=b.level+1}
        local worker=spawn(s,p,"Builder",p.layout.lands.S1,"Builder",{building=b.key})
        go(s,worker,b.pos)
        return true,"Upgrade started."
    elseif op=="Craft" then
        local b=p.buildings[payload.key];local recipe=b and s.data.Craft.Stations[b.kind]
        if not recipe then return false,"Select a Sawmill or Foundry." end
        b.craft=b.craft or {};if #b.craft>=s.data.MaxCraftQueue then return false,"The crafting queue is full." end
        if not canPay(p,recipe.Inputs) then return false,"Not enough raw materials." end
        pay(p,recipe.Inputs);b.craft[#b.craft+1]={left=recipe.Time/(stats(s,b).CraftSpeed or 1),output=recipe.Output,amount=recipe.OutputAmount}
        return true,"Crafting added to the queue."
    elseif op=="Research" then
        local kind=payload.kind;local levels=s.data.Research.Research[kind];local level=(p.research[kind] or 1)+1;local d=levels and levels[level]
        if not d or bestLevel(p,"TrainingCamp")==0 then return false,"You need a Training Camp and an available research level." end
        if p.researchJob then return false,"Research is already in progress." end
        local gates=s.data.Research.TownhallGate[kind] or {};if bestLevel(p,"Townhall")<(gates[level] or level) then return false,"Upgrade your Town Hall before starting this research." end
        if not canPay(p,d.Cost) then return false,"Not enough resources for this research." end
        pay(p,d.Cost);p.researchJob={kind=kind,level=level,left=math.min(d.Time,s.data.MaxResearchSeconds)}
        return true,"Research started."
    elseif op=="Order" then
        local target=payload.target and s.bases[payload.target]
        if payload.target and not target then return false,"That base does not belong to this round." end
        local enemy=payload.enemy and s.units[payload.enemy]
        if payload.enemy and (not enemy or enemy.hp<=0 or enemy.owner==uid or enemy.role=="Worker" or enemy.role=="Builder") then
            return false,"That enemy is gone or is not an attack target."
        end
        local camp=payload.camp and p.camps[payload.camp]
        if payload.camp and (not camp or camp.cleared) then return false,"That camp is already clear or is not yours." end
        local position=enemy and enemy.pos or (camp and p.layout.lands[payload.camp] or (target and target.pos or payload.pos))
        if not point(position) then return false,"Invalid order position." end
        local navKey,navDistance=nearest(s,position)
        if not navKey or navDistance>7.5 then return false,"The destination is outside reachable land." end
        local destination={x=position.x,y=s.nav[navKey].y,z=position.z}
        local selected={}
        if payload.ids~=nil then
            if type(payload.ids)~="table" or #payload.ids>60 then return false,"Invalid troop selection." end
            local length=#payload.ids
            for k in pairs(payload.ids) do
                if type(k)~="number" or k%1~=0 or k<1 or k>length then return false,"Invalid troop selection." end
            end
            for _,id in ipairs(payload.ids) do
                if type(id)~="string" or #id>12 or selected[id] then return false,"Invalid unit." end
                local u=s.units[id];if not u or u.owner~=uid or u.role~="Troop" then return false,"You cannot order another player's units." end
                selected[id]=true
            end
        end
        local all=not next(selected);local orders={}
        for id,u in pairs(s.units) do
            if u.owner==uid and u.role=="Troop" and (all or selected[id]) then
                local path=route(s,u.pos,destination);if path then orders[id]=path end
            end
        end
        if not next(orders) then
            local n=0;for _,u in pairs(s.units) do if u.owner==uid and u.role=="Troop" then n=n+1 end end
            if n==0 then return false,"No troops yet. Click your Barracks or press 1 to train your army." end
            return false,"No troops can reach that point. Unlock land or build the island bridge first."
        end
        if all then p.rally={pos=copy(destination),base=target and target.id,enemy=enemy and enemy.id,camp=payload.camp} end
        for id,path in pairs(orders) do
            local u=s.units[id];u.path=path;u.pathIndex=1;u.goal=copy(destination);u.mode="AttackMove";u.target=nil;u.orderBase=target and target.id or nil;u.orderEnemy=enemy and enemy.id or nil
        end
        return true,"Order accepted."
    end
    return false,"Unknown command."
end
local function workerTick(s,p,u,dt)
    dt=dt*((p.workerBoostUntil or 0)>s.elapsed and (1+.6*(p.workerBoostStrength or 1)) or 1)
    local b=p.buildings[u.building];if not b then return end
    local cap=stats(s,b).Storage or 60
    if u.carry>0 then
        u.mode="Carrying";u.facing=copy(b.pos)
        if dist(u.pos,b.pos)<1.4 then
            local deposit=math.max(0,math.min(cap-b.store,u.carry))
            b.store=b.store+deposit;u.carry=u.carry-deposit;u.path=nil
        elseif not u.path then go(s,u,b.pos) end
        move(u,dt);return
    end
    if b.store>=cap then u.path=nil;u.mode="Full";return end
    local node=u.node and p.nodes[u.node]
    if not node or node.hp<=0 then
        node=nil;u.node=nil;local dd=math.huge
        for _,key in ipairs(sorted(p.nodes)) do
            local r=p.nodes[key];local d=dist(u.pos,r.pos)
            if r.resource==u.resource and r.hp>0 and d<dd then node=r;dd=d end
        end
        if node then u.node=node.key;go(s,u,node.pos) end
    end
    if not node then u.mode="Waiting";return end
    if dist(u.pos,node.pos)>1.1 then
        u.mode="Walking";if not u.path then go(s,u,node.pos) end;move(u,dt)
    else
        u.path=nil;u.mode="Chopping";u.facing=copy(node.pos);u.chop=u.chop+dt
        if u.chop>=s.data.ChopInterval then
            u.chop=u.chop-s.data.ChopInterval;u.workSerial=u.workSerial+1;node.hp=math.max(0,node.hp-1)
            if node.hp==0 then
                node.regrow=s.data.RegrowSeconds;u.carry=s.data.WorkerCarry;u.node=nil;u.mode="Carrying";go(s,u,b.pos)
            end
        end
    end
end
local function goldWorkerTick(s,p,u,dt)
    local base=u.base and s.bases[u.base]
    if not base or base.owner~=p.id then u.hp=0;return end
    u.mode="Working";u.facing=copy(base.pos);u.workSerial=(u.workSerial or 0)+dt
    -- The base itself generates the passive amount; this unit gives a visible,
    -- deterministic pulse so workers feel active without double-paying gold.
    if u.workSerial>=4 then
        u.workSerial=u.workSerial-4;give(p,"Gold",0.25)
    end
    if dist(u.pos,base.pos)>2.5 then
        if not u.path then go(s,u,base.pos) end
        move(u,dt)
    else
        u.path=nil
        local phase=(u.id:byte(#u.id) or 1)*0.07+s.elapsed
        u.pos.x=base.pos.x+math.cos(phase)*1.1;u.pos.z=base.pos.z+math.sin(phase)*1.1
    end
end
local function separateUnits(s)
    local ids=s.unitOrder or sorted(s.units)
    for i=1,#ids do
        local a=s.units[ids[i]]
        if a and a.hp>0 then
            for j=i+1,#ids do
                local b=s.units[ids[j]]
                if b and b.hp>0 and math.abs((a.pos.y or 0)-(b.pos.y or 0))<=2 then
                    local dx,dz=b.pos.x-a.pos.x,b.pos.z-a.pos.z
                    local d=math.sqrt(dx*dx+dz*dz)
                    if d<0.78 then
                        if d<0.001 then
                            local angle=((i*17+j*31)%360)*0.0174532925;dx=math.cos(angle);dz=math.sin(angle);d=1
                        end
                        local push=(0.78-d)*0.52;dx=dx/d;dz=dz/d
                        a.pos.x=a.pos.x-dx*push;a.pos.z=a.pos.z-dz*push
                        b.pos.x=b.pos.x+dx*push;b.pos.z=b.pos.z+dz*push
                    end
                end
            end
        end
    end
end
local function defender(u) return u.role=="Enemy" or u.role=="Guard" end
local function hostile(a,b)
    return a.owner~=b.owner and a.role~="Worker" and b.role~="Worker" and a.role~="Builder" and b.role~="Builder"
        and not (defender(a) and defender(b))
end
local function nearUnits(s,pos,radius)
    if not s.unitCells then return s.unitOrder end
    local result={};local size=16;local n=math.ceil(radius/size)
    local x,z=math.floor(pos.x/size),math.floor(pos.z/size)
    for dx=-n,n do for dz=-n,n do
        for _,id in ipairs(s.unitCells[(x+dx)..":"..(z+dz)] or {}) do result[#result+1]=id end
    end end
    return result
end
local function captureBase(s,b,uid)
    local winner=s.players[uid]
    if not winner or winner.defeated or not winner.active then return false end
    local old=b.owner
    if old~=uid and b.goldWorkers then
        local previous=s.players[old]
        if previous then previous.goldWorkers=math.max(0,(previous.goldWorkers or 0)-b.goldWorkers) end
        b.goldWorkers=0
    end
    b.owner=uid;b.progress=0;b.capturer=nil;b.contested=false
    if b.kind=="Townhall" then
        b.hp=b.maxHP
        local original=s.players[b.homePlayer]
        if original then
            original.baseHP=b.hp
            if old==original.id and uid~=original.id and not original.defeated then
                original.defeated=true;original.training={};original.researchJob=nil
                for _,building in pairs(original.buildings) do building.upgrade=nil;building.craft={} end
                for id,u in pairs(s.units) do if u.owner==original.id then s.units[id]=nil end end
            end
        end
    end
    return true
end
local function troopTick(s,u,dt)
    -- Freeze command: every troop of a frozen player acts at half speed.
    local owner=s.players[u.owner]
    if owner and (owner.slowUntil or 0)>s.elapsed then dt=dt*.5;u.frozen=true else u.frozen=nil end
    u.cooldown=math.max(0,u.cooldown-dt)
    local target,dd=nil,math.huge
    local explicit=u.orderEnemy and s.units[u.orderEnemy]
    if explicit and explicit.hp>0 and hostile(u,explicit) and connected(s,u.pos,explicit.pos) then
        local distance=dist(u.pos,explicit.pos)
        -- A distant explicit target is still an attack-move: defend against nearby
        -- enemies on the route instead of walking through an army without fighting.
        if distance<=math.max(u.aggro,u.range+2) then target=explicit;dd=distance
        else explicit=nil end
    elseif u.orderEnemy then u.orderEnemy=nil;explicit=nil end
    for _,id in ipairs(nearUnits(s,u.pos,u.aggro)) do
        local v=s.units[id]
        if not explicit and v and v.hp>0 and hostile(u,v) then
            local d=dist(u.pos,v.pos)
            if d<=u.aggro and d<dd and (not defender(u) or dist(v.pos,u.home)<13)
                and math.abs(v.pos.y-u.pos.y)<=s.data.MaxNavStepHeight and connected(s,u.pos,v.pos) then target=v;dd=d end
        end
    end
    if target then
        u.mode="Fighting";u.facing=copy(target.pos);u.targetPos=copy(target.pos)
        if dd<=u.range then
            u.path=nil
            if u.cooldown<=0 then
                u.cooldown=u.interval;u.attackSerial=(u.attackSerial or 0)+1
                local def=s.data.Troops.Troops[u.kind];local splash=def and def.Splash or 0
                for _,id in ipairs(nearUnits(s,target.pos,math.max(splash,1))) do
                    local victim=s.units[id]
                    if victim and victim.hp>0 and hostile(u,victim) and (victim==target or (splash>0 and dist(victim.pos,target.pos)<=splash)) then
                        local attacker=s.players[u.owner]
                        local boost=attacker and (attacker.armyBoostUntil or 0)>s.elapsed and (1+.25*(attacker.armyBoostStrength or 1)) or 1
                        victim.hp=math.max(0,victim.hp-u.damage*boost)
                        if victim.hp==0 and s.players[u.owner] then
                            local d=s.data.Troops.Troops[victim.kind];give(s.players[u.owner],"Trophy",d and d.Trophies or 1)
                        end
                    end
                end
            end
        else
            local goal=u.goal
            if not u.path or not u.chaseAt or dist(u.chaseAt,target.pos)>2 then
                go(s,u,target.pos);u.chaseAt=copy(target.pos);u.goal=goal
            end
            move(u,dt)
        end
    else
        u.chaseAt=nil
        if defender(u) then
            if dist(u.pos,u.home)>1 and not u.path then go(s,u,u.home) end
        elseif u.mode=="Fighting" and u.goal then go(s,u,u.goal);u.mode="AttackMove" end
        move(u,dt)
        if not u.path and not defender(u) then u.mode="Idle" end
        -- Only a deliberate army order can attack a town hall; ownership changes on capture.
        if u.role=="Troop" and u.goal then
            for _,id in ipairs(s.baseOrder) do
                local b=s.bases[id]
                if b.kind=="Townhall" and b.owner~=u.owner
                    and (u.orderBase==id or dist(u.goal,b.pos)<7)
                    and dist(u.pos,b.pos)<=u.range+2 and math.abs(u.pos.y-b.pos.y)<=4 and u.cooldown<=0 then
                    local attacker=s.players[u.owner];local defender=s.players[b.owner]
                    local boost=attacker and (attacker.armyBoostUntil or 0)>s.elapsed and (1+.25*(attacker.armyBoostStrength or 1)) or 1
                    local shield=defender and (defender.shieldUntil or 0)>s.elapsed and (1-.35*(defender.shieldStrength or 1)) or 1
                    b.hp=math.max(0,b.hp-u.damage*boost*shield);u.cooldown=u.interval
                    u.mode="Fighting";u.facing=copy(b.pos);u.targetPos=copy(b.pos)
                    u.attackSerial=(u.attackSerial or 0)+1
                    if b.hp==0 then captureBase(s,b,u.owner) end
                end
            end
        end
    end
end
-- Admin panel tickets: free round tickets (VIP / ADMIN) are spent first,
-- RoundServer spends a saved ticket only after canUseTicket succeeds.
function State.canUseTicket(s,uid)
    local p=s.players[uid]
    if not p or p.defeated or not p.active or s.status~="Active" then return false,"This round is no longer active." end
    return WishRules.canTicket(s,uid)
end
function State.roundTickets(s,uid) local p=s.players[uid];return p and p.roundTickets or 0 end
function State.spendRoundTicket(s,uid)
    local p=s.players[uid];if not p or (p.roundTickets or 0)<1 then return false end
    p.roundTickets=p.roundTickets-1;return true
end
function State.useTicket(s,uid)
    local ok,message=State.canUseTicket(s,uid);if not ok then return false,message end
    return WishRules.useTicket(s,uid)
end
function State.remove(s,uid)
    local p=s.players[uid];if not p or p.departed then return end
    p.active=false;p.departed=true;p.defeated=true;p.training={};p.researchJob=nil
    for _,r in ipairs(s.data.ResourceOrder) do p.resources[r]=0 end
    for _,b in pairs(p.buildings) do b.store=0;b.upgrade=nil;b.craft={} end
    for id,u in pairs(s.units) do if u.owner==uid or u.campOwner==uid then s.units[id]=nil end end
    -- An abandoned base becomes neutral, not an automatic win or a deleted objective.
    for _,b in pairs(s.bases) do
        if b.owner==uid then b.owner=nil;b.progress=0;b.capturer=nil end
    end
    rebuildNav(s)
end
local function objectiveTick(s,dt)
    for _,id in ipairs(s.baseOrder) do
        local b=s.bases[id]
        if b.kind=="Territory" then
            local guards=0
            for guard in pairs(b.guards) do if s.units[guard] then guards=guards+1 end end
            b.guardsAlive=guards
            local present={}
            for _,unitId in ipairs(nearUnits(s,b.pos,s.data.CaptureRadius)) do
                local u=s.units[unitId];local p=u and s.players[u.owner]
                if u and u.hp>0 and u.role=="Troop" and p and p.active and not p.defeated
                    and dist(u.pos,b.pos)<=s.data.CaptureRadius and math.abs(u.pos.y-b.pos.y)<=3 then present[u.owner]=true end
            end
            local n=count(present);local uid=next(present)
            b.contested=n>1
            if guards==0 and n==1 and uid~=b.owner then
                if b.capturer~=uid then b.capturer=uid;b.progress=0 end
                b.progress=math.min(s.data.CaptureSeconds,b.progress+dt)
                if b.progress>=s.data.CaptureSeconds then captureBase(s,b,uid) end
            elseif n==0 or uid==b.owner or guards>0 then
                b.progress=math.max(0,b.progress-dt*2)
                if b.progress==0 then b.capturer=nil end
            end
            local owner=b.owner and s.players[b.owner]
            if owner and owner.active and not owner.defeated then give(owner,"Gold",b.goldRate*dt*(1+(b.goldWorkers or 0)*0.5)) end
        else
            local p=s.players[b.homePlayer]
            if p then p.baseHP=b.hp;p.baseMaxHP=b.maxHP end
        end
    end
    local alive=0
    for _,p in pairs(s.players) do if p.active and not p.defeated then alive=alive+1 end end
    if alive==0 then s.status="Ended";s.reason="NoPlayers";s.winner=nil;return end
    if s.baseTotal>=2 then
        local uid=s.bases[s.baseOrder[1]].owner
        local p=uid and s.players[uid]
        if p and p.active and not p.defeated then
            local all=true
            for _,id in ipairs(s.baseOrder) do if s.bases[id].owner~=uid then all=false;break end end
            if all then s.status="Ended";s.winner=uid;s.reason="AllBasesCaptured" end
        end
    end
end

function State.step(s,dt)
    if not finite(dt) or dt<=0 or dt>1 or s.status~="Active" then return end
    s.elapsed=s.elapsed+dt
    for _,uid in ipairs(sorted(s.players)) do
        local p=s.players[uid]
        if p.active and not p.defeated then
            for _,r in pairs(p.nodes) do
                if r.hp<=0 then r.regrow=r.regrow-dt;if r.regrow<=0 then r.hp=r.maxHP;r.regrow=0 end end
            end
            for _,b in pairs(p.buildings) do
                if b.upgrade then
                    b.upgrade.left=b.upgrade.left-dt
                    if b.upgrade.left<=0 then
                        b.level=b.upgrade.target;b.upgrade=nil;addWorkers(s,p,b)
                        if b.kind=="Townhall" then
                            local base=s.bases[p.baseId];local old=base.maxHP
                            base.maxHP=400+b.level*100;base.hp=math.min(base.maxHP,base.hp+base.maxHP-old)
                            p.baseHP=base.hp;p.baseMaxHP=base.maxHP
                        end
                    end
                end
                if b.kind=="GoldMine" then local st=stats(s,b);b.store=math.min(st.GoldCap or 10,b.store+(st.GoldRate or 0.5)/60*s.data.GoldRateMultiplier*dt) end
                if b.craft and b.craft[1] then
                    b.craft[1].left=b.craft[1].left-dt
                    if b.craft[1].left<=0 then local q=table.remove(b.craft,1);give(p,q.output,q.amount);b.craftSerial=(b.craftSerial or 0)+1 end
                end
            end
            if p.training[1] then
                local q=p.training[1];q.left=q.left-dt
                if q.left<=0 then
                    table.remove(p.training,1);local target=q.pos
                    for _,b in pairs(p.buildings) do if b.kind=="Campsite" then target=b.pos;break end end
                    local u=spawn(s,p,q.kind,q.pos,"Troop")
                    local goal=copy(target)
                    if p.rally then goal=copy(p.rally.pos);u.mode="AttackMove";u.orderBase=p.rally.base;u.orderEnemy=p.rally.enemy
                    else goal.x=goal.x+math.cos(s.nextUnit*2.4)*2;goal.z=goal.z+math.sin(s.nextUnit*2.4)*2 end
                    go(s,u,goal);p.trained=p.trained+1
                end
            end
            if p.researchJob then
                local job=p.researchJob;job.left=job.left-dt
                if job.left<=0 then
                    local oldMult=1+((p.research[job.kind] or 1)-1)*s.data.Research.StatMultPerLevel
                    p.research[job.kind]=job.level;local mult=1+(job.level-1)*s.data.Research.StatMultPerLevel
                    for _,u in pairs(s.units) do if u.owner==uid and u.kind==job.kind then u.maxHP=u.maxHP/oldMult*mult;u.hp=math.min(u.maxHP,u.hp/oldMult*mult);u.damage=u.damage/oldMult*mult end end
                    p.researchJob=nil;p.researchSerial=(p.researchSerial or 0)+1
                end
            end
        end
    end
    s.unitOrder=sorted(s.units);s.unitCells={}
    for _,id in ipairs(s.unitOrder) do
        local u=s.units[id];local key=math.floor(u.pos.x/16)..":"..math.floor(u.pos.z/16)
        local cell=s.unitCells[key] or {};s.unitCells[key]=cell;cell[#cell+1]=id
    end
    for _,id in ipairs(s.unitOrder) do
        local u=s.units[id]
        if u and u.hp>0 then
            u.moved=false
            if u.role=="Builder" then
                local p=s.players[u.owner];local b=p and p.buildings[u.building]
                if not b or not b.upgrade then s.units[id]=nil
                elseif dist(u.pos,b.pos)>1.5 then u.mode="Walking";if not u.path then go(s,u,b.pos) end;move(u,dt)
                else u.mode="Building";u.path=nil;u.facing=copy(b.pos);u.chop=u.chop+dt
                    if u.chop>=s.data.ChopInterval then u.chop=0;u.workSerial=u.workSerial+1 end
                end
            elseif u.role=="Worker" then local p=s.players[u.owner];if p and not p.defeated then workerTick(s,p,u,dt) end
            elseif u.role=="GoldWorker" then local p=s.players[u.owner];if p and not p.defeated then goldWorkerTick(s,p,u,dt) end
            else troopTick(s,u,dt) end
        end
    end
    separateUnits(s)
    for id,u in pairs(s.units) do if u.hp<=0 then s.units[id]=nil end end
    for _,p in pairs(s.players) do
        for land,camp in pairs(p.camps) do
            if not camp.cleared then
                local alive=false;for id in pairs(camp.guards) do if s.units[id] then alive=true;break end end
                if not alive and not p.departed then camp.cleared=true;enableLand(s,p,land);give(p,"Gold",5+count(camp.guards)) end
            end
        end
    end
    objectiveTick(s,dt)
    WishRules.tick(s,s.elapsed)
end
function State.snapshot(s,uid)
    local p=s.players[uid];if not p then return nil end
    local buildings={}
    for k,b in pairs(p.buildings) do
        local d=s.data.Components.Components[b.kind].Levels[b.level+1]
        buildings[k]={kind=b.kind,level=b.level,store=math.floor(b.store),upgrading=b.upgrade and math.ceil(b.upgrade.left) or 0,nextCost=d and copy(d.Cost) or nil,
            crafting=b.craft and #b.craft or 0,craftLeft=b.craft and b.craft[1] and math.ceil(b.craft[1].left) or 0}
    end
    local bases={};local captured=0
    for _,id in ipairs(s.baseOrder) do
        local b=s.bases[id]
        bases[id]={id=id,kind=b.kind,owner=b.owner,pos=copy(b.pos),hp=b.hp,maxHP=b.maxHP,
            guards=b.guardsAlive or count(b.guards),progress=b.progress,capturer=b.capturer,contested=b.contested,
            goldWorkers=b.goldWorkers or 0}
        if b.owner==uid then captured=captured+1 end
    end
    local roster={};for id,person in pairs(s.players) do roster[id]={name=person.name,isBot=person.isBot,color=copy(person.color)} end
    return {roster=roster,bases=bases,basesCaptured=captured,basesTotal=s.baseTotal,resources=copy(p.resources),discovered=copy(p.discovered),lands=copy(p.lands),cleared=copy(p.cleared),buildings=buildings,
        training=copy(p.training),research=copy(p.research),researchJob=p.researchJob and copy(p.researchJob) or nil,bridge=p.bridge,housing=State.housing(s,p),capacity=State.capacity(s,p),
        elapsed=math.floor(s.elapsed),remaining=nil,status=s.status,winner=s.winner,reason=s.reason,
        hint=State.hint(s,p),defeated=p.defeated,baseHP=math.ceil(p.baseHP),baseMaxHP=p.baseMaxHP,admin=false,goldWorkers=p.goldWorkers or 0,adminBoost=p.adminBoost or 1,
        wish=WishRules.snapshot(s,uid),roundTickets=p.roundTickets or 0,ticketReady=WishRules.canTicket(s,uid)==true,ticketQueue=WishRules.queuePosition(s,uid),frozen=(p.slowUntil or 0)>s.elapsed,
        boosts={army=(p.armyBoostUntil or 0)>s.elapsed,workers=(p.workerBoostUntil or 0)>s.elapsed,shield=(p.shieldUntil or 0)>s.elapsed}}
end
State.copy=copy
-- Read-only route probe for diagnostics and the repeatable playthrough.
State.route=route
return State
