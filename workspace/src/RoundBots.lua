-- Fair bots: no resource grants, hidden damage or instant upgrades. Each action
-- goes through RoundState.action, including wishes and counter-wishes.
local Bots={}
local Profiles={
    {name='Builder',army=8,archers=.22,think=1.12,order=4.4,goals={{'Barracks',1},{'MinerHut',1},{'LumberHut',2},{'BuilderHut',1},{'Townhall',2},{'Campsite',2},{'Barracks',2},{'GoldMine',1},{'Sawmill',1},{'BRIDGE',1},{'Townhall',3},{'LumberHut',3},{'MinerHut',3},{'Campsite',3},{'BuilderHut',2},{'OreMinerHut',1},{'Foundry',1},{'Barracks',3},{'TrainingCamp',1},{'CrystalMinerHut',1},{'Townhall',4},{'Campsite',4},{'Barracks',4}}},
    {name='Raider',army=10,archers=.18,think=.91,order=3.1,goals={{'Barracks',1},{'MinerHut',1},{'LumberHut',2},{'Barracks',2},{'BuilderHut',1},{'Townhall',2},{'Campsite',2},{'BRIDGE',1},{'GoldMine',1},{'Townhall',3},{'Campsite',3},{'Sawmill',1},{'MinerHut',3},{'LumberHut',3},{'OreMinerHut',1},{'Foundry',1},{'Barracks',3},{'TrainingCamp',1},{'CrystalMinerHut',1},{'Townhall',4},{'Campsite',4},{'Barracks',4}}},
    {name='Tactician',army=9,archers=.36,think=1.31,order=3.8,goals={{'Barracks',1},{'MinerHut',1},{'LumberHut',2},{'BuilderHut',1},{'Barracks',2},{'Townhall',2},{'Campsite',2},{'GoldMine',1},{'BRIDGE',1},{'Townhall',3},{'Campsite',3},{'Sawmill',1},{'LumberHut',3},{'MinerHut',3},{'OreMinerHut',1},{'Foundry',1},{'TrainingCamp',1},{'Barracks',3},{'CrystalMinerHut',1},{'Townhall',4},{'Campsite',4},{'Barracks',4}}}
}
local function keys(t) local a={};for k in pairs(t or {}) do a[#a+1]=k end;table.sort(a);return a end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2) end
local function pay(p,cost,reserve)
    for k,v in pairs(cost or {}) do if (p.resources[k] or 0)<v+(reserve and reserve[k] or 0) then return false end end
    return true
end
local function building(p,kind)
    local best
    for _,key in ipairs(keys(p.buildings)) do local b=p.buildings[key];if b.kind==kind and (not best or b.level>best.level) then best=b end end
    return best
end
local function troops(s,p)
    local units,housing,kinds={},0,{}
    for _,id in ipairs(keys(s.units)) do local u=s.units[id];if u.owner==p.id and u.role=='Troop' and u.hp>0 then
        units[#units+1]=u;housing=housing+s.data.Troops.Troops[u.kind].Units;kinds[u.kind]=(kinds[u.kind] or 0)+1
    end end
    return units,housing,kinds
end
local function issue(B,p,op,payload)
    local ok,message=B.State.action(B.state,p.id,op,payload or {})
    if ok then p.botLast=op;p.botActions=(p.botActions or 0)+1 else p.botLastError=message end
    return ok
end
local function guards(data,key)
    local n=0;for kind,count in pairs(data.Lands[key].enemies or {}) do n=n+count*(data.Troops.Troops[kind].Units or 1) end;return n
end
local function landTask(s,p,key,seen)
    seen=seen or {};if seen[key] then return end;seen[key]=true
    local d=s.data.Lands[key];if not d then return end
    if p.cleared[key] then return end
    if p.lands[key] then return {camp=key,guardHousing=guards(s.data,key)} end
    if d.requires~='' and not p.cleared[d.requires] then return landTask(s,p,d.requires,seen) end
    return {op='Expand',payload={key=key},cost=d.cost or {},guardHousing=guards(s.data,key),land=key}
end
local function goalTask(s,p,kind,level,depth)
    depth=(depth or 0)+1;if depth>8 then return end
    if kind=='BRIDGE' then if not p.bridge then return {op='Expand',payload={key='BRIDGE'},cost=s.data.BridgeCost} end;return end
    local b=building(p,kind)
    if not b then
        for _,key in ipairs(keys(s.data.Buildings)) do local d=s.data.Buildings[key];if d.kind==kind then return landTask(s,p,d.land) end end
        return
    end
    if b.level>=level then return end
    if b.upgrade then return {waiting=true,kind=kind} end
    local levels=s.data.Components.Components[kind].Levels;local d=levels[b.level+1];if not d then return end
    local gate=(s.data.Components.TownhallGate[kind] or {})[b.level+1] or b.level+1
    local town=building(p,'Townhall')
    if kind~='Townhall' and (not town or town.level<gate) then return goalTask(s,p,'Townhall',gate,depth) end
    return {op='Upgrade',payload={key=b.key},cost=d.Cost or {},kind=kind}
end
local function goal(B,p)
    local s=B.state
    for _,item in ipairs(p.botProfile.goals) do
        local task=goalTask(s,p,item[1],item[2])
        if task then return task end
    end
    -- Late-game development remains bounded by real prerequisites and gates.
    for _,key in ipairs(keys(p.buildings)) do
        local b=p.buildings[key];local task=goalTask(s,p,b.kind,b.level+1)
        if task and task.op and pay(p,task.cost) then return task end
    end
end
local function recruit(B,p,wanted,reserve,urgent)
    local s=B.state;local barracks=building(p,'Barracks');if not barracks or #p.training>=3 then return end
    local used=B.State.housing(s,p);local cap=B.State.capacity(s,p)
    local units,_,mix=troops(s,p)
    for _,q in ipairs(p.training) do mix[q.kind]=(mix[q.kind] or 0)+1 end
    -- Newly unlocked classes join an existing army when there is housing.
    -- A healthy low-tier army is not an excuse to never use the new tier.
    if barracks.level>=3 and not mix.Giant then wanted=math.max(wanted,used+4) end
    if barracks.level>=4 and not mix.Wizard then wanted=math.max(wanted,used+4) end
    if used>=math.min(cap,wanted) then return end
    local preference={'Barbarian','Archer','Giant','Wizard'}
    if barracks.level>=4 and not mix.Wizard then preference={'Wizard','Giant','Archer','Barbarian'}
    elseif barracks.level>=3 and not mix.Giant then preference={'Giant','Archer','Barbarian'}
    elseif barracks.level>=2 and (mix.Archer or 0)<math.max(1,math.floor(#units*p.botProfile.archers)) then preference={'Archer','Barbarian'} end
    for _,kind in ipairs(preference) do
        local d=s.data.Troops.Troops[kind]
        if barracks.level>=(d.RequiresBarracks or 1) and used+d.Units<=cap and pay(p,d.Costs,urgent and nil or reserve) then
            issue(B,p,'Train',{kind=kind});return
        end
    end
end
local function economy(B,p)
    local s=B.state
    -- Every store is collected, not only the first alphabetically found hut.
    for _,key in ipairs(keys(p.buildings)) do
        local b=p.buildings[key]
        if (s.data.WorkerResources[b.kind] or b.kind=='GoldMine') and (b.store or 0)>=1 then issue(B,p,'Collect',{key=key}) end
    end
    local task=goal(B,p);local reserve=task and task.cost or {}
    local units,live=troops(s,p);local cap=B.State.capacity(s,p)
    local campNeed=task and task.guardHousing and task.guardHousing>0 and math.ceil(task.guardHousing*1.2)+2 or 0
    -- A large guarded expansion must not trap the economy behind a small army cap.
    if campNeed>cap and cap<18 then
        local camp=building(p,'Campsite')
        local alternative=camp and goalTask(s,p,'Campsite',camp.level+1)
        if alternative then
            -- TH3 requires Gold: do not wait forever when the next camp is the
            -- only current source. Full-capacity troops may still take that camp.
            if not (alternative.cost and alternative.cost.Gold and (p.resources.Gold or 0)<alternative.cost.Gold and not building(p,'GoldMine')) then
                task=alternative;reserve=task.cost or {};campNeed=0
            end
        end
    end
    local wanted=math.min(cap,math.max(p.botProfile.army,campNeed))
    if task and task.op and pay(p,task.cost) and (campNeed==0 or live>=math.min(cap,campNeed)) then
        if issue(B,p,task.op,task.payload) then reserve={} end
    end
    local urgent=(campNeed>0 and live<math.min(cap,campNeed)) or live<math.min(4,wanted)
    -- Training must not starve saved construction budgets, except when troops
    -- are needed to unlock the very resource required by the budget.
    recruit(B,p,wanted,reserve,urgent)
    for _,key in ipairs(keys(p.buildings)) do
        local b=p.buildings[key];local recipe=s.data.Craft.Stations[b.kind]
        if recipe and #(b.craft or {})<3 then
            local need=math.max(reserve[recipe.Output] or 0,recipe.Output=='Plank' and 100 or 30)
            if (p.resources[recipe.Output] or 0)<need and pay(p,recipe.Inputs) then issue(B,p,'Craft',{key=key}) end
        end
    end
    if building(p,'TrainingCamp') and not p.researchJob then
        for _,kind in ipairs(p.botProfile.name=='Tactician' and {'Archer','Barbarian','Giant','Wizard'} or {'Barbarian','Archer','Giant','Wizard'}) do
            local level=(p.research[kind] or 1)+1;local d=(s.data.Research.Research[kind] or {})[level]
            local town=building(p,'Townhall');local gate=(s.data.Research.TownhallGate[kind] or {})[level] or level
            if d and town and town.level>=gate and pay(p,d.Cost,reserve) and issue(B,p,'Research',{kind=kind}) then break end
        end
    end
    -- Hire only when the savings plan allows it; the state caps extra workers.
    if building(p,'GoldMine') and (p.resources.Gold or 0)>(reserve.Gold or 0)+25 then
        for _,key in ipairs(keys(p.buildings)) do local b=p.buildings[key]
            if s.data.WorkerResources[b.kind] and (b.extraWorkers or 0)<(p.botProfile.name=='Builder' and 3 or 1) and pay(p,{Log=5,Gold=2},reserve) then issue(B,p,'BuyWorker',{key=key});break end
        end
    end
    for _,id in ipairs(s.baseOrder) do local b=s.bases[id]
        if b.kind=='Territory' and b.owner==p.id and (b.goldWorkers or 0)<2 and pay(p,{Gold=10},reserve) then issue(B,p,'BuyWorker',{key='BASE:'..id});break end
    end
    p.botPlan=task and (task.camp and 'Clear '..task.camp or task.op or 'Developing') or 'Conquer all bases'
end
local function orders(B,p)
    local s=B.state;local army,housing=troops(s,p);if #army==0 then return end
    local task,signature
    local home=s.bases[p.baseId]
    for _,id in ipairs(keys(s.units)) do local u=s.units[id]
        if u.role=='Troop' and u.owner~=p.id and u.hp>0 and distance(u.pos,home.pos)<23 then task={enemy=id,pos=u.pos};signature='Defend:'..id;break end
    end
    if not task then
        for _,land in ipairs(keys(p.camps)) do
            local camp=p.camps[land]
            if not camp.cleared then
                local need=math.min(B.State.capacity(s,p),math.ceil(guards(s.data,land)*1.2)+2)
                if housing>=need or (p.botTarget=='Camp:'..land and housing>=math.max(3,need*.6)) then task={camp=land,pos=p.layout.lands[land]};signature='Camp:'..land end
                break
            end
        end
    end
    if not task and p.bridge and housing>=math.min(B.State.capacity(s,p),p.botProfile.army) then
        local best=math.huge
        for _,id in ipairs(s.baseOrder) do local base=s.bases[id]
            if base.owner~=p.id then
                local reachable=B.State.route(s,army[1].pos,base.pos)
                if reachable then
                    local count=0;for guard in pairs(base.guards or {}) do if s.units[guard] then count=count+1 end end
                    local bias=p.botProfile.name=='Raider' and (base.kind=='Townhall' and -35 or 0) or count*7
                    local score=distance(army[1].pos,base.pos)+bias
                    if score<best then best=score;task={target=id,pos=base.pos};signature='Base:'..id end
                end
            end
        end
        if not task then
            for _,id in ipairs(keys(s.players)) do local other=s.players[id]
                if id~=p.id and not other.bridge and s.bases[other.baseId].owner~=p.id and other.layout.bridgeLanding then
                    if B.State.route(s,army[1].pos,other.layout.bridgeLanding) then
                        task={pos=other.layout.bridgeLanding};signature='Bridge:'..id
                        if pay(p,s.data.BridgeCost) then issue(B,p,'Expand',{key='BRIDGE',owner=id}) end
                        break
                    end
                end
            end
        end
    end
    if task and (signature~=p.botTarget or s.elapsed-(p.botLastOrder or -100)>14) then
        -- No ids field means "all troops" and records a rally for new recruits.
        if issue(B,p,'Order',task) then p.botTarget=signature;p.botLastOrder=s.elapsed end
    end
end
local function wish(B,p)
    local s=B.state;local e=s.wish and s.wish.event;if not e then return end
    local append=e.phase=='Append';local op=append and 'Append' or 'Wish'
    if not B.State.canWish(s,p.id,op..'Draft',e.id) then return end
    local key=e.id..':'..e.phase
    if p.botWishKey~=key then
        p.botWishKey=key;p.botWishStart=s.elapsed;p.botWishDrafted=0
        if append then
            if e.recipient==p.id then p.botWishText='and heal my army'
            else p.botWishText=p.botProfile.name=='Builder' and 'and give everyone resources' or p.botProfile.name=='Raider' and 'but at half strength' or 'but only for 10 seconds' end
        else
            local wounded=false
            for _,u in pairs(s.units) do if u.owner==p.id and u.role=='Troop' and u.hp<u.maxHP*.65 then wounded=true;break end end
            p.botWishText=wounded and 'Heal my army' or (p.botProfile.name=='Builder' and 'Boost my workers' or p.botProfile.name=='Raider' and 'Boost my army' or 'Fortify my base')
        end
    end
    local age=s.elapsed-p.botWishStart;local delay=.6+p.botJitter*.7
    -- Bots use the same single-character edit path and submit their server buffer.
    local wanted=math.min(#p.botWishText,math.max(0,math.floor((age-delay)*9)))
    if p.botWishDrafted<wanted then
        local n=p.botWishDrafted+1
        if issue(B,p,op..'Draft',{eventId=e.id,prompt=p.botWishText:sub(1,n)}) then p.botWishDrafted=n end
    elseif wanted==#p.botWishText and age>delay+#p.botWishText/9+.5 then
        issue(B,p,op..'Submit',{eventId=e.id})
    end
end
function Bots.attach(state,roster,stateModule)
    local B={state=state,State=stateModule,roster={}};state.bots=state.bots or {};local index=0
    for _,entry in ipairs(roster or {}) do
        local uid=tostring(entry.UserId);local p=state.players[uid]
        local bot=(type(entry)=='table' and entry.IsBot==true) or (typeof(entry)=='Instance' and entry:GetAttribute('IsBot')==true)
        if p and bot then
            index=index+1;p.isBot=true;p.botProfile=Profiles[(index-1)%#Profiles+1]
            p.botJitter=(math.abs(entry.UserId)%97)/97;p.botClock=p.botJitter;p.botOrderClock=0
            p.botActions=0;p.botStyle=p.botProfile.name
            B.roster[#B.roster+1]=uid;state.bots[uid]=true
        end
    end
    return B
end
function Bots.step(B,dt)
    if not B or B.state.status~='Active' then return end
    for _,id in ipairs(B.roster) do local p=B.state.players[id]
        if p and p.active and not p.defeated then
            wish(B,p)
            p.botClock=p.botClock+dt;p.botOrderClock=p.botOrderClock+dt
            if p.botClock>=p.botProfile.think+p.botJitter*.25 then p.botClock=0;economy(B,p) end
            if p.botOrderClock>=p.botProfile.order+p.botJitter then p.botOrderClock=0;orders(B,p) end
        end
    end
end
function Bots.prompts() return {'Boost my workers','Heal my army','Boost my army','Fortify my base','Give me resources','and give everyone resources','but at half strength','but only for 10 seconds'} end
Bots.Profiles=Profiles
return Bots
