-- Admin panel executor. A plan is a list of actions from AdminCommands (instant dictionary) or AdminBrain (Gemini).
-- Everything here only changes the current round's state: nothing is saved, nothing touches passes, tickets,
-- Robux or other players' accounts, and no action can remove a player from the round.
local Actions={}
Actions.Types={'damage_troops','kill_troops','heal_troops','damage_base','heal_base','summon','give','take','steal','swap_resources',
    'freeze','slow','haste','boost_army','buff_troops','invincible','shield','boost_workers','instant_build','level_up','level_down',
    'research_up','expand','bridge','capture_island','attack','teleport_troops','convert_troops','disable_controls','screen','weather','announce'}
Actions.UnitKinds={'Barbarian','Archer','Giant','Wizard'}
Actions.Resources={'Log','Stone','Gold','Plank','Iron Ore','Iron Bar','Crystal','Trophy'}
Actions.Buildings={'Townhall','Barracks','Campsite','LumberHut','MinerHut','GoldMine','Sawmill','Foundry','OreMinerHut','CrystalMinerHut','TrainingCamp','BuilderHut'}
Actions.ScreenEffects={'blind','shake','flip','blur','rainbow'}
Actions.Weather={'night','day','rain','snow','fog','disco'}
Actions.MaxTroops=200          -- the only hard limit: troops a single player can own through the admin panel
Actions.MaxSeconds=600          -- timed effects last at most 10 minutes (and never past the round)
-- amounts when no number was given (the admin panel is meant to feel huge)
local GIVE_DEFAULT={Log=30000,Stone=20000,Gold=6000,Plank=6000,['Iron Ore']=6000,['Iron Bar']=2000,Crystal=2000,Trophy=1500}
Actions.Unlimited=999999
local HARMFUL={damage_troops=true,kill_troops=true,damage_base=true,take=true,steal=true,freeze=true,slow=true,level_down=true,
    convert_troops=true,disable_controls=true,screen=true}
local GLOBAL={weather=true,announce=true}
Actions.Harmful=HARMFUL
local VALID={};for _,t in ipairs(Actions.Types) do VALID[t]=true end
local function set(list) local out={};for _,v in ipairs(list) do out[string.lower(v)]=v end;return out end
local UNIT=set(Actions.UnitKinds);local RES=set(Actions.Resources);local BUILD=set(Actions.Buildings)
local SCREEN=set(Actions.ScreenEffects);local WEATHER=set(Actions.Weather)
RES.wood='Log';RES.logs='Log';RES.coins='Gold';RES.money='Gold';RES.iron='Iron Bar';RES.ore='Iron Ore';RES.crystals='Crystal';RES.planks='Plank';RES.trophies='Trophy'
local function lower(t) return string.lower(tostring(t or '')) end
local function keys(t) local a={};for k in pairs(t or {}) do a[#a+1]=tostring(k) end;table.sort(a);return a end
local function num(v,lo,hi,default)
    v=tonumber(v);if not v or v~=v or math.abs(v)==math.huge then v=default end
    return math.clamp(math.floor(v+.5),lo,hi)
end
local function eligible(s,id) local p=s.players[id];return p and p.active and not p.defeated and not p.departed end
local function random(s)
    local ok,n=pcall(s.wish and s.wish.rng or math.random);if not ok or type(n)~='number' or n~=n then n=.5 end
    return math.abs(n)%1
end
local function name(s,uid) local p=s.players[uid];return p and p.name or 'Player' end
local function findName(s,text)
    local n=lower(text):gsub('^@','');if n=='' then return nil end
    local ids=keys(s.players)
    for _,id in ipairs(ids) do if lower(s.players[id].name)==n then return id end end
    if #n>=3 then
        for _,id in ipairs(ids) do if lower(s.players[id].name):sub(1,#n)==n then return id end end
        for _,id in ipairs(ids) do if lower(s.players[id].name):find(n,1,true) then return id end end
    end
end
Actions.findName=findName
-- target spec -> player ids: author | enemies | everyone | random_enemy | except:<name> | <player name>
local function targets(s,e,spec,harmful)
    local t=lower(spec):gsub('%s+','_')
    local out={}
    local function add(id) if eligible(s,id) then out[#out+1]=id end end
    if t=='' then t=harmful and 'enemies' or 'author' end
    local except=t:match('^except:(.+)$')
    if t=='author' or t=='me' or t=='self' or t=='i' or t=='my' then add(e.recipient)
    elseif t=='enemies' or t=='enemy' or t=='others' or t=='opponents' then for _,id in ipairs(s.wish.ids) do if id~=e.recipient then add(id) end end
    elseif t=='everyone' or t=='all' or t=='everybody' or t=='all_players' then for _,id in ipairs(s.wish.ids) do add(id) end
    elseif except then
        local skip=findName(s,except) or e.recipient
        for _,id in ipairs(s.wish.ids) do if id~=skip then add(id) end end
    elseif t=='random_enemy' or t=='random' or t=='someone' then
        local list={};for _,id in ipairs(s.wish.ids) do if id~=e.recipient and eligible(s,id) then list[#list+1]=id end end
        if #list>0 then out[1]=list[math.floor(random(s)*#list)+1] end
    else
        local id=findName(s,spec)
        if id then add(id) else return targets(s,e,'',harmful) end
    end
    return out
end
local function fx(s,kind,pos,extra)
    s.fx=s.fx or {}
    if #s.fx>=200 then return end
    local item={k=kind,p=pos and {x=pos.x,y=pos.y,z=pos.z} or nil}
    for k,v in pairs(extra or {}) do item[k]=v end
    s.fx[#s.fx+1]=item
end
local function troops(s,uid)
    local list={}
    for _,id in ipairs(keys(s.units)) do local u=s.units[id];if u.owner==uid and u.role=='Troop' and u.hp>0 then list[#list+1]=u end end
    return list
end
local function basePos(s,p)
    local b=p.baseId and s.bases[p.baseId]
    return b and b.pos or (p.layout and p.layout.lands and p.layout.lands.S1)
end
local function hook(s,n) return s.wishHooks and s.wishHooks[n] end
local function invincible(s,p) return (p.invincibleUntil or 0)>s.elapsed end
local function resourceList(a)
    local r=RES[lower(a.resource)]
    if r then return {r} end
    local t=lower(a.resource)
    if t=='all' or t=='everything' or t=='resources' then return {'Log','Stone','Gold','Plank','Iron Ore','Iron Bar','Crystal','Trophy'} end
    return {'Log','Stone','Gold'}
end
local function secs(a,default) return num(a.seconds,1,Actions.MaxSeconds,default) end

local H={}
H.damage_troops=function(s,e,p,a)
    if invincible(s,p) then return 0 end
    local pct=num(a.percent,1,100,100)/100
    local list=troops(s,p.id);local shown=0
    local kind=a.style=='lightning' and 'lightning' or 'meteor'
    for _,u in ipairs(list) do
        u.hp=math.max(0,u.hp-u.maxHP*pct)
        if shown<14 then shown=shown+1;fx(s,kind,u.pos) end
    end
    if #list==0 then
        -- nobody to hit: it lands on their town hall instead (never below 1 HP)
        local b=p.baseId and s.bases[p.baseId]
        if not b or b.owner~=p.id then return 0 end
        b.hp=math.max(1,b.hp-b.maxHP*.5*pct);p.baseHP=b.hp
        for i=1,3 do fx(s,kind,{x=b.pos.x+math.cos(i*2.1)*3,y=b.pos.y,z=b.pos.z+math.sin(i*2.1)*3}) end
    end
    return 1
end
H.kill_troops=function(s,e,p,a) a.percent=100;return H.damage_troops(s,e,p,a) end
H.heal_troops=function(s,e,p,a)
    local pct=num(a.percent,1,100,100)/100;local n=0
    for _,u in ipairs(troops(s,p.id)) do u.hp=math.min(u.maxHP,u.hp+u.maxHP*pct);n=n+1;if n<=12 then fx(s,'heal',u.pos) end end
    fx(s,'heal',basePos(s,p))
    return 1
end
H.damage_base=function(s,e,p,a)
    local b=p.baseId and s.bases[p.baseId];if not b or b.owner~=p.id or invincible(s,p) then return 0 end
    local pct=num(a.percent,1,100,99)/100
    if (p.shieldUntil or 0)>s.elapsed then pct=pct*.5 end
    -- the panel can hurt a base but never capture it: troops must finish the job
    b.hp=math.max(1,b.hp-b.maxHP*pct);p.baseHP=b.hp
    for i=1,6 do fx(s,a.style=='lightning' and 'lightning' or 'meteor',{x=b.pos.x+math.cos(i*1.05)*4,y=b.pos.y,z=b.pos.z+math.sin(i*1.05)*4}) end
    return 1
end
H.heal_base=function(s,e,p,a)
    local b=p.baseId and s.bases[p.baseId];if not b or b.owner~=p.id then return 0 end
    b.hp=math.min(b.maxHP,b.hp+b.maxHP*num(a.percent,1,100,100)/100);p.baseHP=b.hp
    fx(s,'heal',b.pos);return 1
end
H.summon=function(s,e,p,a)
    local kind=UNIT[lower(a.unit)] or 'Barbarian'
    local count=hook(s,'troopCount') and hook(s,'troopCount')(s,p) or #troops(s,p.id)
    local n=math.min(num(a.count,1,Actions.MaxTroops,50),Actions.MaxTroops-count)
    if n<=0 or not hook(s,'summon') then a.full=true;return 0 end
    local at=hook(s,'summon')(s,p,kind,n)
    fx(s,'summon',at or basePos(s,p),{n=n})
    a.unit=kind;a.done=(a.done or 0)+n
    return 1
end
H.give=function(s,e,p,a)
    local list=resourceList(a)
    for _,r in ipairs(list) do
        local have=p.resources[r] or 0
        local amount
        if a.unlimited then amount=Actions.Unlimited
        elseif tonumber(a.factor) and tonumber(a.factor)>1 then amount=math.floor(math.max(have,GIVE_DEFAULT[r])*(math.min(tonumber(a.factor),1000)-1))
        else amount=num(a.amount,1,999999,GIVE_DEFAULT[r]*math.clamp(tonumber(a.scale) or 1,.01,1000)) end
        p.resources[r]=math.min(Actions.Unlimited,have+amount);p.discovered[r]=true
    end
    fx(s,'gold',basePos(s,p),{r=list[1]})
    return 1
end
H.take=function(s,e,p,a)
    local pct=num(a.percent,1,100,100)/100
    for _,r in ipairs(resourceList(a)) do p.resources[r]=math.floor((p.resources[r] or 0)*(1-pct)) end
    fx(s,'poof',basePos(s,p));return 1
end
H.steal=function(s,e,p,a)
    local thief=s.players[a.to and findName(s,a.to) or e.recipient] or s.players[e.recipient]
    if not thief or thief==p or not eligible(s,thief.id) then return 0 end
    local pct=num(a.percent,1,100,100)/100
    for _,r in ipairs(resourceList(a)) do
        local take=math.floor((p.resources[r] or 0)*pct)
        if take>0 then p.resources[r]=p.resources[r]-take;thief.resources[r]=math.min(999999,(thief.resources[r] or 0)+take);thief.discovered[r]=true end
    end
    fx(s,'steal',basePos(s,p),{to=basePos(s,thief)});return 1
end
H.swap_resources=function(s,e,p,a)
    local other=s.players[a.to and findName(s,a.to) or e.recipient]
    if not other or other==p or not eligible(s,other.id) then return 0 end
    for _,r in ipairs(Actions.Resources) do
        p.resources[r],other.resources[r]=other.resources[r] or 0,p.resources[r] or 0
        if (p.resources[r] or 0)>0 then p.discovered[r]=true end;if (other.resources[r] or 0)>0 then other.discovered[r]=true end
    end
    fx(s,'steal',basePos(s,p),{to=basePos(s,other)});fx(s,'steal',basePos(s,other),{to=basePos(s,p)})
    return 1
end
H.freeze=function(s,e,p,a)
    if invincible(s,p) then return 0 end
    local t=secs(a,30);p.slowUntil=s.elapsed+t;p.slowFactor=0
    for i,u in ipairs(troops(s,p.id)) do if i<=16 then fx(s,'freeze',u.pos,{t=t}) end end
    fx(s,'freeze',basePos(s,p),{t=math.min(t,4)});return 1
end
H.slow=function(s,e,p,a)
    local t=secs(a,60);p.slowUntil=s.elapsed+t;p.slowFactor=.15
    for i,u in ipairs(troops(s,p.id)) do if i<=12 then fx(s,'slow',u.pos) end end
    return 1
end
H.haste=function(s,e,p,a)
    p.hasteUntil=s.elapsed+secs(a,120);p.hastePower=num(a.power,1,20,5)
    for i,u in ipairs(troops(s,p.id)) do if i<=12 then fx(s,'boost',u.pos) end end
    return 1
end
H.boost_army=function(s,e,p,a)
    p.armyBoostUntil=s.elapsed+secs(a,120);p.armyBoostStrength=num(a.power,1,100,10)
    for i,u in ipairs(troops(s,p.id)) do if i<=12 then fx(s,'rage',u.pos) end end
    fx(s,'rage',basePos(s,p));return 1
end
H.buff_troops=function(s,e,p,a)
    local mult=1+num(a.percent,-99,9900,900)/100;local n=0
    for _,u in ipairs(troops(s,p.id)) do
        local now=u.buff or 1;local target=math.clamp(now*mult,.01,100);local k=target/now
        if k~=1 then u.maxHP=u.maxHP*k;u.hp=math.max(1,u.hp*k);u.damage=u.damage*k;u.buff=target end
        n=n+1;if n<=12 then fx(s,mult>=1 and 'rage' or 'slow',u.pos) end
    end
    return n>0 and 1 or 0
end
H.invincible=function(s,e,p,a)
    local t=secs(a,60);p.invincibleUntil=s.elapsed+t
    fx(s,'shield',basePos(s,p),{t=t});return 1
end
H.shield=function(s,e,p,a)
    local t=secs(a,120);p.shieldUntil=s.elapsed+t;p.shieldStrength=.9
    fx(s,'shield',basePos(s,p),{t=t});return 1
end
H.boost_workers=function(s,e,p,a)
    p.workerBoostUntil=s.elapsed+secs(a,180);p.workerBoostStrength=num(a.power,1,50,10)
    fx(s,'boost',basePos(s,p));return 1
end
H.instant_build=function(s,e,p,a)
    local n=0
    for _,b in pairs(p.buildings) do if b.upgrade then b.upgrade.left=math.min(b.upgrade.left,.05);n=n+1;fx(s,'build',b.pos) end end
    if p.researchJob then p.researchJob.left=.05;n=n+1 end
    for _,q in ipairs(p.training or {}) do q.left=math.min(q.left,.05);n=n+1 end
    for _,b in pairs(p.buildings) do if b.craft then for _,c in ipairs(b.craft) do c.left=math.min(c.left,.05);n=n+1 end end end
    if n==0 then return 0 end
    fx(s,'build',basePos(s,p));return 1
end
local function buildingList(s,p,a,wantUp)
    local want=lower(a.building):gsub('[%s_]','')
    local exact=BUILD[want]
    local comps=s.data and s.data.Components and s.data.Components.Components or {}
    local list={}
    for _,key in ipairs(keys(p.buildings)) do
        local b=p.buildings[key];local c=comps[b.kind]
        local match=want=='' or want=='all' or (exact and b.kind==exact) or (not exact and lower(b.kind):find(want,1,true))
        if match and c and c.Levels and (wantUp and c.Levels[b.level+1] or (not wantUp and b.level>1)) then list[#list+1]=b end
    end
    return list,comps
end
H.level_up=function(s,e,p,a)
    local list,comps=buildingList(s,p,a,true)
    local levels=num(a.levels,1,10,10);local n=math.min(#list,num(a.count,1,50,50))
    if n==0 or not hook(s,'setLevel') then return 0 end
    for i=1,n do
        local b=list[i];local top=#comps[b.kind].Levels
        hook(s,'setLevel')(s,p,b,math.min(top,b.level+levels));fx(s,'build',b.pos)
    end
    return 1
end
H.level_down=function(s,e,p,a)
    local list=buildingList(s,p,a,false)
    local levels=num(a.levels,1,10,10);local n=math.min(#list,num(a.count,1,50,50))
    if n==0 or not hook(s,'setLevel') then return 0 end
    for i=1,n do local b=list[i];hook(s,'setLevel')(s,p,b,math.max(1,b.level-levels));fx(s,'poof',b.pos) end
    return 1
end
H.research_up=function(s,e,p,a)
    local kinds=UNIT[lower(a.unit)] and {UNIT[lower(a.unit)]} or Actions.UnitKinds
    local levels=num(a.levels,1,10,10);local n=0
    for _,kind in ipairs(kinds) do if hook(s,'research') and hook(s,'research')(s,p,kind,levels) then n=n+1 end end
    if n==0 then return 0 end
    fx(s,'build',basePos(s,p));return 1
end
H.expand=function(s,e,p,a)
    local n=hook(s,'expand') and hook(s,'expand')(s,p,num(a.count,1,40,40)) or 0
    if n==0 then return 0 end
    fx(s,'build',basePos(s,p));a.done=n;return 1
end
H.bridge=function(s,e,p,a)
    if p.bridge or not hook(s,'bridge') then return 0 end
    hook(s,'bridge')(s,p);fx(s,'build',basePos(s,p));return 1
end
H.capture_island=function(s,e,p,a)
    local n=hook(s,'captureIslands') and hook(s,'captureIslands')(s,p,num(a.count,1,20,20)) or 0
    return n>0 and 1 or 0
end
local function victimOf(s,e,p,a)
    local v=a.victim and findName(s,a.victim)
    if v and v~=p.id and eligible(s,v) then return v end
    local list={};for _,id in ipairs(s.wish.ids) do if id~=p.id and eligible(s,id) then list[#list+1]=id end end
    return #list>0 and list[math.floor(random(s)*#list)+1] or nil
end
H.attack=function(s,e,p,a)
    local victim=victimOf(s,e,p,a);if not victim or not hook(s,'attack') then return 0 end
    a.victim=name(s,victim)
    local n=hook(s,'attack')(s,p,s.players[victim]) or 0
    if n==0 then return 0 end
    fx(s,'rage',basePos(s,p));return 1
end
H.teleport_troops=function(s,e,p,a)
    if not hook(s,'teleport') then return 0 end
    local to=lower(a.to);local pos
    if to=='home' or to=='base' or to=='' then pos=basePos(s,p)
    elseif to=='center' or to=='centre' or to=='middle' then pos=hook(s,'center') and hook(s,'center')(s) end
    local near=false
    if not pos and not (to=='home' or to=='base' or to=='' or to=='center' or to=='centre' or to=='middle') then
        local v=victimOf(s,e,p,{victim=a.to});if v then pos=basePos(s,s.players[v]);a.to=name(s,v);near=true end
    end
    if not pos then return 0 end
    local n=hook(s,'teleport')(s,p,pos,near)
    if n==0 then return 0 end
    fx(s,'summon',pos,{n=n});return 1
end
H.convert_troops=function(s,e,p,a)
    local to=s.players[a.to and findName(s,a.to) or e.recipient] or s.players[e.recipient]
    if not to or to==p or not hook(s,'convert') then return 0 end
    local n=hook(s,'convert')(s,p,to,num(a.percent,1,100,100)/100,Actions.MaxTroops)
    return n>0 and 1 or 0
end
H.disable_controls=function(s,e,p,a)
    if p.isBot then return 0 end
    local t=secs(a,20);p.controlsLockedUntil=s.elapsed+t
    fx(s,'controls',nil,{uid=p.id,t=t});return 1
end
H.screen=function(s,e,p,a)
    if p.isBot then return 0 end
    local effect=SCREEN[lower(a.effect)] or 'shake'
    fx(s,'screen',nil,{uid=p.id,e=effect,t=secs(a,15)});return 1
end

local LABEL={
    damage_troops=function(a,who) return (a.style=='lightning' and 'Lightning' or 'Meteors')..' hit '..who end,
    kill_troops=function(a,who) return who..': army wiped out' end,
    heal_troops=function(a,who) return who..': army healed' end,
    damage_base=function(a,who) return 'Meteors smash '..who..'\'s base' end,
    heal_base=function(a,who) return who..': base repaired' end,
    summon=function(a,who) return who..' +'..tostring(a.done or a.count or '')..' '..tostring(a.unit or 'troops') end,
    give=function(a,who) return who..' got '..(RES[lower(a.resource)] or 'resources') end,
    take=function(a,who) return who..' lost resources' end,
    steal=function(a,who) return 'Robbed '..who end,
    swap_resources=function(a,who) return who..' swapped resources' end,
    freeze=function(a,who) return who..' frozen' end,
    slow=function(a,who) return who..' slowed down' end,
    haste=function(a,who) return who..': army speed up' end,
    boost_army=function(a,who) return who..': army boosted' end,
    buff_troops=function(a,who) return who..': troops '..((tonumber(a.percent) or 100)>=0 and 'buffed' or 'weakened') end,
    invincible=function(a,who) return who..' invincible' end,
    shield=function(a,who) return who..' shielded' end,
    boost_workers=function(a,who) return who..': workers boosted' end,
    instant_build=function(a,who) return who..': built instantly' end,
    level_up=function(a,who) return who..': buildings upgraded' end,
    level_down=function(a,who) return who..': buildings downgraded' end,
    research_up=function(a,who) return who..': research up' end,
    expand=function(a,who) return who..': new lands unlocked' end,
    bridge=function(a,who) return who..': bridge built' end,
    capture_island=function(a,who) return who..' captured islands' end,
    attack=function(a,who) return who..' attacks '..tostring(a.victim or 'an enemy') end,
    teleport_troops=function(a,who) return who..': army teleported' end,
    convert_troops=function(a,who) return who..'\'s troops switched sides' end,
    disable_controls=function(a,who) return who..': controls disabled' end,
    screen=function(a,who) return who..': '..tostring(SCREEN[lower(a.effect)] or 'shake')..' screen' end,
    weather=function(a) return (WEATHER[lower(a.effect)] or 'night')..' for everyone' end,
    announce=function(a) return 'Announcement' end,
}
function Actions.normalize(raw)
    if type(raw)~='table' then return nil end
    local function text(v) return type(v)=='string' and v:gsub('[%c]',' '):sub(1,120) or nil end
    local plan={actions={},caption=text(raw.caption),cancelled=raw.cancelled==true,refused=raw.refused==true,reason=text(raw.reason),rejected={}}
    for _,who in ipairs(type(raw.rejected_additions)=='table' and raw.rejected_additions or {}) do
        if type(who)=='string' then plan.rejected[#plan.rejected+1]=who:sub(1,40) end
    end
    for _,a in ipairs(type(raw.actions)=='table' and raw.actions or {}) do
        if type(a)=='table' and VALID[a.type] and #plan.actions<16 then
            local clean={type=a.type}
            for _,k in ipairs({'target','unit','resource','building','victim','to','effect','style'}) do if type(a[k])=='string' then clean[k]=a[k]:sub(1,40) end end
            if type(a.text)=='string' then clean.text=text(a.text) end
            if a.unlimited==true then clean.unlimited=true end
            for _,k in ipairs({'count','amount','percent','seconds','power','levels','factor','scale'}) do if tonumber(a[k]) then clean[k]=tonumber(a[k]) end end
            plan.actions[#plan.actions+1]=clean
        end
    end
    if plan.caption=='' then plan.caption=nil end
    return plan
end
local function names(s,ids)
    local list={};for i,id in ipairs(ids) do if i>3 then list[#list+1]='+'..(#ids-3);break end;list[#list+1]=name(s,id) end
    return table.concat(list,', ')
end
-- returns success, effect text, outcome
function Actions.execute(s,e,raw)
    if not eligible(s,e.recipient) then return false,'The author is no longer in the round.','Rejected' end
    local plan=Actions.normalize(raw)
    if not plan then return false,'The Admin Panel could not read that command.','Rejected' end
    e.rejected={}
    for _,who in ipairs(plan.rejected) do
        local id=findName(s,who)
        if id and e.additions[id] and e.additions[id]~='' then e.rejected[id]=true end
    end
    if plan.refused then return false,plan.reason or 'This command does not exist in the game.','Rejected' end
    if plan.cancelled then return false,plan.caption or 'Someone cancelled the command!','Cancelled' end
    if #plan.actions==0 then return false,plan.reason or 'This command does not exist in the game.','Rejected' end
    local labels,full={},false
    for _,a in ipairs(plan.actions) do
        if GLOBAL[a.type] then
            if a.type=='weather' then fx(s,'weather',nil,{e=WEATHER[lower(a.effect)] or 'night',t=secs(a,90)});labels[#labels+1]=LABEL.weather(a)
            elseif a.type=='announce' and a.text and a.text~='' then fx(s,'announce',nil,{text=a.text,from=name(s,e.recipient)});labels[#labels+1]=LABEL.announce(a) end
        else
            local hit={}
            for _,id in ipairs(targets(s,e,a.target,HARMFUL[a.type])) do
                local ok,result=pcall(H[a.type],s,e,s.players[id],a)
                if not ok then warn('[ArmyRound] Admin action '..a.type..' failed safely: '..tostring(result))
                elseif result~=0 then hit[#hit+1]=id end
            end
            if a.full then full=true end
            if #hit>0 then labels[#labels+1]=LABEL[a.type](a,names(s,hit)) end
        end
    end
    if #labels==0 then
        return false,full and ('Troop limit: '..Actions.MaxTroops..' per player. When some of them fall you can summon more.') or 'Nothing could be affected right now.','Rejected'
    end
    e.effectLabels=labels
    local summary=table.concat(labels,' + ')..'!'
    if full then summary=summary..' (limit '..Actions.MaxTroops..' troops per player)' end
    return true,plan.caption and (plan.caption..'\n'..summary) or summary,'Executed'
end
return Actions
