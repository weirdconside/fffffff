-- Authoritative Admin event: private input -> announcement -> roulette -> append -> thinking -> applied.
-- Human drafts are PRIVATE and filtered only on submission, before any public display.
-- The command is turned into a plan of bounded game actions: by Gemini (AdminBrain) when it
-- answers in time, otherwise by the local interpreter below. Both go through one executor.
local Typing=require(game:GetService('ReplicatedStorage'):WaitForChild('ArmyRoundShared'):WaitForChild('TypingRules'))
local Rules={Times={Prompt=15,Announcement=3,Roulette=5,Append=10,Applied=5,Filtering=6,Resolving=6,Thinking=9}}
Rules.FirstDelay=120     -- seconds into the round before the first admin panel (2 minutes)
Rules.Interval=120       -- one timer admin panel every 2 minutes (start to start)
Rules.AdminBonus=.20     -- ADMIN pass: +20% weight in the random pick
local function copy(v) if type(v)~='table' then return v end;local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out end
local function keys(t) local a={};for k in pairs(t or {}) do a[#a+1]=tostring(k) end;table.sort(a);return a end
local function perk(p,name) return p~=nil and type(p.perks)=='table' and p.perks[name]==true end
function Rules.sanitize(value)
    return (Typing.clip(value,120):gsub('%s+',' '):match('^%s*(.-)%s*$') or '')
end
local function random(w)
    local ok,n=pcall(w.rng);if not ok or type(n)~='number' or n~=n or math.abs(n)==math.huge then n=.5 end
    return math.abs(n)%1
end
local function eligible(s,id) local p=s.players[id];return p and p.active and not p.defeated and not p.departed end
local function phase(s,e,name)
    e.phase=name;e.started=s.elapsed;e.duration=Rules.Times[name] or 0;e.deadline=s.elapsed+e.duration
end
function Rules.new(players,opts)
    local ids=keys(players);local counts={}
    for _,id in ipairs(ids) do counts[id]=0 end
    return {ids=ids,counts=counts,nextAt=Rules.FirstDelay,firstDone=false,queue={},nextId=0,rng=opts and opts.rng or math.random}
end
function Rules.setRng(w,rng) if w and type(rng)=='function' then w.rng=rng end end
-- VIP owners always get the FIRST timer panel; afterwards it is a weighted
-- random pick where ADMIN owners weigh 20% more.
local function recipient(s)
    local w=s.wish
    if not w.firstDone then
        local vips={}
        for _,id in ipairs(w.ids) do if eligible(s,id) and perk(s.players[id],'VIP') then vips[#vips+1]=id end end
        if #vips>0 then return vips[math.floor(random(w)*#vips)+1] end
    end
    local total,list=0,{}
    for _,id in ipairs(w.ids) do if eligible(s,id) then
        local weight=perk(s.players[id],'Admin') and (1+Rules.AdminBonus) or 1
        total=total+weight;list[#list+1]={id=id,weight=weight}
    end end
    if total<=0 then return nil end
    local roll=random(w)*total
    for _,entry in ipairs(list) do roll=roll-entry.weight;if roll<=0 then return entry.id end end
    return list[#list].id
end
Rules.pickForTest=recipient
local function open(s,id,ticket)
    local w=s.wish
    w.nextId=w.nextId+1
    local e={id=tostring(w.nextId),recipient=id,prompt='',buffers={},submitted={},pending={},additions={},applied=false,ticket=ticket==true}
    w.counts[id]=(w.counts[id] or 0)+1
    w.event=e;phase(s,e,'Prompt');return e
end
function Rules.newEvent(s)
    local w=s.wish
    if not w or w.event then return end
    local id=recipient(s);if not id then return end
    w.firstDone=true;w.lastTimerStart=s.elapsed
    return open(s,id,false)
end
-- Tickets: open the panel for the owner right now, or right after the
-- current one (one waiting ticket per player).
function Rules.canTicket(s,uid)
    local w=s.wish
    if not w or s.status~='Active' or not eligible(s,uid) then return false,'You cannot use a ticket right now.' end
    for _,q in ipairs(w.queue) do if q==uid then return false,'Your ticket is already waiting in line.' end end
    if w.event and w.event.recipient==uid and w.event.phase=='Prompt' then return false,'The admin panel is already yours!' end
    return true
end
function Rules.useTicket(s,uid)
    local ok,message=Rules.canTicket(s,uid);if not ok then return false,message end
    local w=s.wish
    if not w.event then open(s,uid,true);return true,'Ticket used: the admin panel is yours!' end
    w.queue[#w.queue+1]=uid
    return true,'Ticket used: the admin panel opens for you right after this one (#'..#w.queue..' in line).'
end
function Rules.queuePosition(s,uid)
    for i,q in ipairs(s.wish and s.wish.queue or {}) do if q==uid then return i end end
    return nil
end

-- ================================================================== actions
-- Every plan (AI or local) is a list of these. Each field is clamped here, so
-- nothing a model or a player writes can exceed these limits.
Rules.ActionTypes={'damage_troops','kill_troops','heal_troops','damage_base','heal_base','summon','give','take','steal',
    'freeze','slow','boost_army','boost_workers','shield','instant_build','level_up','buff_troops','attack'}
Rules.UnitKinds={'Barbarian','Archer','Giant','Wizard'}
Rules.Resources={'Log','Stone','Gold','Plank','Iron Ore','Iron Bar','Crystal','Trophy'}
local GIVE_CAP={Log=1200,Stone=800,Gold=150,Plank=250,['Iron Ore']=250,['Iron Bar']=80,Crystal=80,Trophy=60}
local GIVE_DEFAULT={Log=250,Stone=150,Gold=40,Plank=50,['Iron Ore']=50,['Iron Bar']=15,Crystal=15,Trophy=10}
local SUMMON_CAP={Barbarian=20,Archer=15,Giant=8,Wizard=8}
local MAX_TROOPS=70
local HARMFUL={damage_troops=true,kill_troops=true,damage_base=true,take=true,freeze=true,slow=true,steal=true}
local VALID={};for _,t in ipairs(Rules.ActionTypes) do VALID[t]=true end
local UNIT={};for _,k in ipairs(Rules.UnitKinds) do UNIT[k:lower()]=k end
local RES={};for _,k in ipairs(Rules.Resources) do RES[k:lower()]=k end
RES.wood='Log';RES.logs='Log';RES.coins='Gold';RES.money='Gold';RES.iron='Iron Bar';RES.ore='Iron Ore';RES.crystals='Crystal';RES.planks='Plank';RES.trophies='Trophy'
local function num(v,lo,hi,default)
    v=tonumber(v);if not v or v~=v then v=default end
    return math.clamp(math.floor(v+.5),lo,hi)
end
local function lower(t) return string.lower(tostring(t or '')) end
local function has(t,list) for _,word in ipairs(list) do if t:find(word,1,true) then return true end end;return false end

-- target spec -> list of player ids
local function findName(s,name)
    local n=lower(name):gsub('^@','');if n=='' then return nil end
    local ids=keys(s.players)
    for _,id in ipairs(ids) do if lower(s.players[id].name)==n then return id end end
    if #n>=3 then
        for _,id in ipairs(ids) do if lower(s.players[id].name):sub(1,#n)==n then return id end end
        for _,id in ipairs(ids) do if lower(s.players[id].name):find(n,1,true) then return id end end
    end
    return nil
end
local SELF={author=true,me=true,self=true,caster=true,player=true,mine=true,my=true,i=true}
local ENEMIES={enemies=true,enemy=true,others=true,opponents=true,rivals=true,them=true,all_enemies=true}
local EVERYONE={everyone=true,all=true,everybody=true,all_players=true,both=true}
local function resolveTargets(s,e,spec,harmful)
    local t=lower(spec):gsub('%s+','_')
    local out={}
    local function add(id) if eligible(s,id) then out[#out+1]=id end end
    if t=='' then t=harmful and 'enemies' or 'author' end
    if SELF[t] then add(e.recipient)
    elseif ENEMIES[t] then for _,id in ipairs(s.wish.ids) do if id~=e.recipient then add(id) end end
    elseif EVERYONE[t] then for _,id in ipairs(s.wish.ids) do add(id) end
    elseif t=='random_enemy' or t=='random' or t=='someone' then
        local list={};for _,id in ipairs(s.wish.ids) do if id~=e.recipient and eligible(s,id) then list[#list+1]=id end end
        if #list>0 then out[1]=list[math.floor(random(s.wish)*#list)+1] end
    else
        local id=findName(s,spec)
        if id then add(id) else return resolveTargets(s,e,'',harmful) end
    end
    return out
end

local function fx(s,kind,pos,extra)
    s.fx=s.fx or {}
    if #s.fx>=160 or not pos then return end
    local item={k=kind,p={x=pos.x,y=pos.y,z=pos.z}}
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
    if b then return b.pos end
    return p.layout and p.layout.lands and p.layout.lands.S1
end
local function name(s,uid) local p=s.players[uid];return p and p.name or 'Player' end
local function names(s,ids)
    local list={};for i,id in ipairs(ids) do if i>3 then list[#list+1]='+'..(#ids-3);break end;list[#list+1]=name(s,id) end
    return table.concat(list,', ')
end

local H={}
H.damage_troops=function(s,e,p,a)
    local pct=num(a.percent,10,100,60)/100
    local list=troops(s,p.id);local shown=0
    for _,u in ipairs(list) do
        u.hp=math.max(0,u.hp-u.maxHP*pct);u.smitten=(u.smitten or 0)+1
        if shown<10 then shown=shown+1;fx(s,a.fxKind or 'meteor',u.pos) end
    end
    -- nobody to hit: the strike lands on their town hall instead, so it is never a no-op
    if #list==0 then
        local b=p.baseId and s.bases[p.baseId]
        if b and b.owner==p.id then
            b.hp=math.max(1,b.hp-b.maxHP*.12*pct/.6);p.baseHP=b.hp
            for i=1,3 do fx(s,a.fxKind or 'meteor',{x=b.pos.x+math.cos(i*2.1)*3,y=b.pos.y,z=b.pos.z+math.sin(i*2.1)*3}) end
        end
        return 'base'
    end
    return #list
end
H.kill_troops=function(s,e,p,a) a.percent=100;return H.damage_troops(s,e,p,a) end
H.heal_troops=function(s,e,p,a)
    local pct=num(a.percent,10,100,60)/100;local n=0
    for _,u in ipairs(troops(s,p.id)) do u.hp=math.min(u.maxHP,u.hp+u.maxHP*pct);n=n+1;if n<=10 then fx(s,'heal',u.pos) end end
    fx(s,'heal',basePos(s,p))
    return n
end
H.damage_base=function(s,e,p,a)
    local b=p.baseId and s.bases[p.baseId];if not b or b.owner~=p.id then return 0 end
    local pct=num(a.percent,10,90,40)/100
    if (p.shieldUntil or 0)>s.elapsed then pct=pct*.5 end
    b.hp=math.max(1,b.hp-b.maxHP*pct);p.baseHP=b.hp
    for i=1,5 do fx(s,'meteor',{x=b.pos.x+math.cos(i*1.26)*4,y=b.pos.y,z=b.pos.z+math.sin(i*1.26)*4}) end
    return 1
end
H.heal_base=function(s,e,p,a)
    local b=p.baseId and s.bases[p.baseId];if not b or b.owner~=p.id then return 0 end
    b.hp=math.min(b.maxHP,b.hp+b.maxHP*num(a.percent,10,100,50)/100);p.baseHP=b.hp
    fx(s,'heal',b.pos);return 1
end
H.summon=function(s,e,p,a)
    local kind=UNIT[lower(a.unit)] or 'Barbarian'
    local have=#troops(s,p.id)
    local n=math.min(num(a.count,1,SUMMON_CAP[kind],math.ceil(SUMMON_CAP[kind]/2)),MAX_TROOPS-have)
    if n<=0 or not (s.wishHooks and s.wishHooks.summon) then return 0 end
    local at=s.wishHooks.summon(s,p,kind,n)
    fx(s,'summon',at or basePos(s,p),{n=n})
    a.unit=kind;a.count=n
    return n
end
local function resourceList(a)
    local r=RES[lower(a.resource)]
    if r then return {r} end
    if lower(a.resource)=='all' or lower(a.resource)=='everything' then return {'Log','Stone','Gold','Plank','Iron Ore','Iron Bar','Crystal'} end
    return {'Log','Stone','Gold'}
end
H.give=function(s,e,p,a)
    local list=resourceList(a)
    for _,r in ipairs(list) do
        local amount=num(a.amount,1,GIVE_CAP[r],GIVE_DEFAULT[r])
        if #list>1 and not a.amount then amount=GIVE_DEFAULT[r] end
        p.resources[r]=math.min(999999,(p.resources[r] or 0)+amount);p.discovered[r]=true
    end
    fx(s,list[1]=='Gold' and 'gold' or 'loot',basePos(s,p),{r=list[1]})
    return 1
end
H.take=function(s,e,p,a)
    local pct=num(a.percent,5,80,40)/100
    for _,r in ipairs(resourceList(a)) do p.resources[r]=math.floor((p.resources[r] or 0)*(1-pct)) end
    fx(s,'poof',basePos(s,p));return 1
end
H.steal=function(s,e,p,a)
    local thief=s.players[a.to and findName(s,a.to) or e.recipient] or s.players[e.recipient]
    if not thief or thief==p or not eligible(s,thief.id) then return 0 end
    local pct=num(a.percent,5,60,25)/100
    for _,r in ipairs(resourceList(a)) do
        local take=math.min(GIVE_CAP[r] or 200,math.floor((p.resources[r] or 0)*pct))
        if take>0 then p.resources[r]=p.resources[r]-take;thief.resources[r]=math.min(999999,(thief.resources[r] or 0)+take);thief.discovered[r]=true end
    end
    fx(s,'steal',basePos(s,p),{to=basePos(s,thief)});return 1
end
H.freeze=function(s,e,p,a)
    p.slowUntil=s.elapsed+num(a.seconds,3,20,10);p.slowFactor=0
    for i,u in ipairs(troops(s,p.id)) do if i<=12 then fx(s,'freeze',u.pos,{t=p.slowUntil-s.elapsed}) end end
    fx(s,'freeze',basePos(s,p),{t=3});return 1
end
H.slow=function(s,e,p,a)
    p.slowUntil=s.elapsed+num(a.seconds,5,40,20);p.slowFactor=.4
    for i,u in ipairs(troops(s,p.id)) do if i<=12 then fx(s,'slow',u.pos) end end
    return 1
end
H.boost_army=function(s,e,p,a)
    p.armyBoostUntil=s.elapsed+num(a.seconds,5,60,30);p.armyBoostStrength=num(a.power,1,3,2)
    for i,u in ipairs(troops(s,p.id)) do if i<=12 then fx(s,'rage',u.pos) end end
    fx(s,'rage',basePos(s,p));return 1
end
H.boost_workers=function(s,e,p,a)
    p.workerBoostUntil=s.elapsed+num(a.seconds,10,90,45);p.workerBoostStrength=num(a.power,1,3,2)
    fx(s,'boost',basePos(s,p));return 1
end
H.shield=function(s,e,p,a)
    p.shieldUntil=s.elapsed+num(a.seconds,5,60,30);p.shieldStrength=num(a.power,1,2,2)/2+.5
    fx(s,'shield',basePos(s,p),{t=p.shieldUntil-s.elapsed});return 1
end
H.instant_build=function(s,e,p,a)
    local n=0
    for _,b in pairs(p.buildings) do if b.upgrade then b.upgrade.left=math.min(b.upgrade.left,.05);n=n+1;fx(s,'build',b.pos) end end
    if p.researchJob then p.researchJob.left=.05;n=n+1 end
    for _,q in ipairs(p.training or {}) do q.left=math.min(q.left,.05);n=n+1 end
    fx(s,'build',basePos(s,p))
    return n
end
H.level_up=function(s,e,p,a)
    local want=lower(a.building):gsub('[%s_]','')
    local comps=s.data and s.data.Components and s.data.Components.Components or {}
    local list={}
    for _,key in ipairs(keys(p.buildings)) do
        local b=p.buildings[key];local c=comps[b.kind]
        if not b.upgrade and c and c.Levels and c.Levels[b.level+1] and (want=='' or lower(b.kind):find(want,1,true) or want:find(lower(b.kind),1,true)) then list[#list+1]=b end
    end
    table.sort(list,function(x,y) if x.level~=y.level then return x.level<y.level end;return x.key<y.key end)
    local n=math.min(#list,num(a.count,1,3,want=='' and 2 or 1))
    for i=1,n do list[i].upgrade={left=.05,target=list[i].level+1};fx(s,'build',list[i].pos) end
    return n
end
H.buff_troops=function(s,e,p,a)
    local mult=1+num(a.percent,10,200,50)/100;local n=0
    for _,u in ipairs(troops(s,p.id)) do
        local now=u.buff or 1;local nextMult=math.min(3,now*mult);local k=nextMult/now
        if k>1 then u.maxHP=u.maxHP*k;u.hp=u.hp*k;u.damage=u.damage*k;u.buff=nextMult end
        n=n+1;if n<=10 then fx(s,'rage',u.pos) end
    end
    return n
end
H.attack=function(s,e,p,a)
    local victim=a.victim and findName(s,a.victim)
    if not victim or victim==p.id or not eligible(s,victim) then
        local list={};for _,id in ipairs(s.wish.ids) do if id~=p.id and eligible(s,id) then list[#list+1]=id end end
        victim=#list>0 and list[math.floor(random(s.wish)*#list)+1] or nil
    end
    if not victim or not (s.wishHooks and s.wishHooks.attack) then return 0 end
    a.victim=name(s,victim)
    local n=s.wishHooks.attack(s,p,s.players[victim]) or 0
    fx(s,'rage',basePos(s,p));return n
end

local LABEL={
    damage_troops=function(a,who) return (a.fxKind=='lightning' and 'Lightning' or 'Meteors')..' hit '..who end,
    kill_troops=function(a,who) return who..' lost their army' end,
    heal_troops=function(a,who) return who..' healed' end,
    damage_base=function(a,who) return 'Meteors smash '..who..'\'s base' end,
    heal_base=function(a,who) return who..'\'s base repaired' end,
    summon=function(a,who) return who..' +'..tostring(a.count or '')..' '..tostring(a.unit or 'troops') end,
    give=function(a,who) return who..' got '..(RES[lower(a.resource)] or (lower(a.resource)=='all' and 'everything') or 'resources') end,
    take=function(a,who) return who..' lost resources' end,
    steal=function(a,who) return 'Robbed '..who end,
    freeze=function(a,who) return who..' frozen' end,
    slow=function(a,who) return who..' slowed' end,
    boost_army=function(a,who) return who..' army boosted' end,
    boost_workers=function(a,who) return who..' workers boosted' end,
    shield=function(a,who) return who..' shielded' end,
    instant_build=function(a,who) return who..' built instantly' end,
    level_up=function(a,who) return who..' leveled up' end,
    buff_troops=function(a,who) return who..' troops buffed' end,
    attack=function(a,who) return who..' attacks '..tostring(a.victim or 'an enemy') end,
}
-- Normalises any table the AI (or anything else) produced into a safe plan.
function Rules.normalizePlan(raw)
    if type(raw)~='table' then return nil end
    local plan={actions={},caption=type(raw.caption)=='string' and Rules.sanitize(raw.caption) or nil,
        cancelled=raw.cancelled==true,refused=raw.refused==true,reason=type(raw.reason)=='string' and Rules.sanitize(raw.reason) or nil,rejected={}}
    for _,who in ipairs(type(raw.rejected_additions)=='table' and raw.rejected_additions or {}) do
        if type(who)=='string' then plan.rejected[#plan.rejected+1]=who:sub(1,40) end
    end
    for _,a in ipairs(type(raw.actions)=='table' and raw.actions or {}) do
        if type(a)=='table' and VALID[a.type] and #plan.actions<8 then
            local clean={type=a.type}
            for _,k in ipairs({'target','unit','resource','building','victim','to'}) do if type(a[k])=='string' then clean[k]=a[k]:sub(1,40) end end
            for _,k in ipairs({'count','amount','percent','seconds','power'}) do if tonumber(a[k]) then clean[k]=tonumber(a[k]) end end
            if a.style=='lightning' or a.fxKind=='lightning' then clean.fxKind='lightning' end
            plan.actions[#plan.actions+1]=clean
        end
    end
    if plan.caption=='' then plan.caption=nil end
    return plan
end
function Rules.execute(s,e,plan)
    if not eligible(s,e.recipient) then return false,'The author is no longer in the round.','Rejected' end
    plan=Rules.normalizePlan(plan)
    if not plan then return false,'The Admin Panel could not read that command.','Rejected' end
    -- additions that did not fit are rejected on their own; the rest of the command still runs
    e.rejected={}
    for _,who in ipairs(plan.rejected) do
        local id=findName(s,who)
        if id and e.additions[id] and e.additions[id]~='' then e.rejected[id]=true end
    end
    if plan.refused then return false,plan.reason or 'This command does not fit the game rules.','Rejected' end
    if plan.cancelled then return false,plan.caption or 'Someone cancelled the command!','Cancelled' end
    if #plan.actions==0 then return false,plan.caption or 'The Admin Panel did not find anything to do.','Rejected' end
    local labels={}
    for _,a in ipairs(plan.actions) do
        local who=resolveTargets(s,e,a.target,HARMFUL[a.type])
        local hit={}
        for _,id in ipairs(who) do
            local ok,result=pcall(H[a.type],s,e,s.players[id],a)
            if not ok then warn('[ArmyRound] Admin action '..a.type..' failed safely: '..tostring(result))
            elseif result~=0 then hit[#hit+1]=id end
        end
        if #hit>0 then
            local whoText=(#hit==1 and hit[1]==e.recipient) and name(s,e.recipient) or names(s,hit)
            labels[#labels+1]=LABEL[a.type](a,whoText)
        end
    end
    if #labels==0 then return false,plan.caption and (plan.caption..' (nothing to affect)') or 'Nothing could be affected right now.','Rejected' end
    e.effectLabels=labels
    local summary=table.concat(labels,' + ')..'!'
    return true,plan.caption and (plan.caption..'\n'..summary) or summary,'Executed'
end

-- ================================================================== local interpreter
-- Used when Gemini is not configured, fails, or is too slow. It never rejects a
-- command it half-understands: unknown additions are ignored, and a command it
-- does not understand at all still does something fun.
local W={
    peace={'do not kill','dont kill',"don't kill",'no kill','peace','не убива','не убей','не атак','не трога','пощад','мир ','перемири','неуязв','invincib','god mode','godmode','бессмерт'},
    kill={'kill','destroy','wipe','annihilat','obliterat','exterminat','убей','убить','уничтож','сотри','истреб','перебей','ликвид','смерть','умрут','умри'},
    meteor={'meteor','nuke','bomb','fireball','explo','rocket','missile','fire','strike','smite','damage','hurt','hit ','метеор','ядер','бомб','огн','взорв','ракет','удар','урон','поджар','сожги','жги','атомн'},
    lightning={'lightning','thunder','storm','zap','молни','гром','шторм','буря'},
    base={'base','castle','town hall','townhall','tower','house','hall','fort','баз','замок','замк','ратуш','башн','дом','крепост'},
    heal={'heal','cure','restore','revive','regen','medic','лечи','лечен','вылеч','исцел','хил','восстан','реген','возроди','оживи'},
    summon={'spawn','summon','army of','reinforce','recruit','call ','create','призов','призыв','создай','спавн','вызов','вызови','подкреп','наним','найми'},
    give={'give','grant','more','get','want','add','rain','need','free','дай','дать','добав','больше','хочу','получ','дожд','нужн','бесплат','начисл','подар'},
    take={'remove','take away','delete','lose','reset','zero','убер','отним','забер','обнули','удали','сбрось','потеря'},
    steal={'steal','rob','loot','heist','swipe','укра','ограб','стащ','своруй','отбер','грабь'},
    freeze={'freeze','frozen','frost','ice','stun','stop','paraly','замороз','заморож','лед','лёд','стоп','останов','оглуш','парализ','застынь'},
    slow={'slow','snail','sleep','tired','замедл','медлен','улитк','усыпи','спать','сон '},
    army={'army','troop','soldier','unit','warrior','fighter','арм','войск','солдат','юнит','воин','бойц','отряд'},
    power={'boost','strong','power','buff','rage','faster','fast','speed','damage','усил','сильн','мощ','бафф','ярост','быстр','скорост','урон','буст'},
    bigger={'bigger','huge','giant army','hp','health','tank','огромн','больше хп','здоров','танк','крепк','прочн'},
    workers={'worker','production','economy','farm','mining','рабоч','эконом','производ','добыч','фарм','шахт'},
    shield={'shield','protect','fortify','wall','defen','armor','armour','щит','защит','укреп','оборон','брон','стен'},
    build={'build','construct','finish','instant','hurry','построй','строй','достро','мгновен'},
    level={'upgrade','level','max ','maximum','улучш','прокач','уровн','апгрейд','макс'},
    attack={'attack','invade','raid','charge','go to','send army','send my army','атакуй','атака','напад','напасть','в атаку','рейд','иди на','идите на','штурм','вперед','вперёд'},
    win={' win','victory','победа','побед','выигр'},
}
local MOD={
    half={'half','weak','little','slightly','половин','слаб','чуть','немного'},
    double={'double','twice','x2','mega','ultra','super','max','вдвое','двойн','супер','мега','ультра','сильно','очень'},
    everyone={'everyone','everybody','all players','for all','всем','для всех','каждому','все игроки'},
    me={' me ',' my ','myself','author','the one who','мне','меня','моим','моей','моих','мой ','мою','автор','себе','тому кто'},
    enemies={'enemies','enemy','others','opponent','rival','them','their','врагам','враг','вражеск','противник','остальн','других','чужих'},
    cancel={'cancel','block','nothing happens','never mind','отмен','блок','ничего не','не выполн','не будет'},
    short={'10 sec','short','briefly','коротк','10 сек','на секунд'},
    long={'long','forever','minute','долг','навсегда','минут'},
}
local function clauseTarget(s,e,t)
    for _,id in ipairs(keys(s.players)) do
        local n=lower(s.players[id].name)
        if #n>=3 and t:find(n,1,true) then return s.players[id].name end
    end
    if has(t,{'except me','but me','not me','кроме меня','кроме себя','но не мне','не меня'}) then return 'enemies' end
    if has(t,MOD.everyone) then return 'everyone' end
    if has(t,MOD.enemies) then return 'enemies' end
    if has(t,MOD.me) then return 'author' end
    return nil
end
local function detectUnit(t)
    local rows={{'giant','гигант','великан',kind='Giant'},{'wizard','mage','маг','волшеб','колдун',kind='Wizard'},{'archer','bow','лучник','лучн',kind='Archer'},{'barbarian','warrior','варвар','воин',kind='Barbarian'}}
    for _,row in ipairs(rows) do for _,w in ipairs(row) do if t:find(w,1,true) then return row.kind end end end
end
local function detectResource(t)
    local rows={{{'gold','coin','money','золот','монет','деньг','бабк'},'Gold'},{{'plank','доск'},'Plank'},{{'iron bar','ingot','слит'},'Iron Bar'},
        {{'ore','руд'},'Iron Ore'},{{'iron','желез'},'Iron Bar'},{{'crystal','gem','diamond','кристал','алмаз','гем'},'Crystal'},
        {{'stone','rock','камн','камен','камен'},'Stone'},{{'wood','log','tree','дерев','древес','брев','лес'},'Log'},{{'trophy','trophies','трофе','кубк'},'Trophy'},
        {{'resource','everything','all res','ресурс','всё','все '},'all'}}
    for _,row in ipairs(rows) do if has(t,row[1]) then return row[2] end end
end
local function numberIn(t) return tonumber(t:match('(%d+)')) end
-- one piece of text -> list of actions
local function detect(t)
    local out={}
    local function add(a) out[#out+1]=a end
    local unit,res=detectUnit(t),detectResource(t)
    local baseWord=has(t,W.base)
    if has(t,W.peace) then add({type='shield',target='everyone'}) return out end
    if has(t,W.win) then add({type='damage_troops',target='enemies',percent=70});add({type='boost_army',target='author'}) end
    if has(t,W.heal) then add({type=baseWord and 'heal_base' or 'heal_troops'}) end
    if has(t,W.steal) then add({type='steal',resource=res or 'all'})
    elseif res and has(t,W.take) then add({type='take',resource=res})
    elseif res and res~='all' and not has(t,W.summon) then add({type='give',resource=res,amount=numberIn(t)})
    elseif res=='all' and has(t,W.give) then add({type='give',resource='all'}) end
    if has(t,W.freeze) then add({type='freeze',seconds=numberIn(t)}) elseif has(t,W.slow) then add({type='slow'}) end
    if unit and (has(t,W.summon) or has(t,W.give) or numberIn(t)) then add({type='summon',unit=unit,count=numberIn(t)})
    elseif has(t,W.summon) and has(t,W.army) then add({type='summon',unit='Barbarian',count=numberIn(t)}) end
    if has(t,W.army) and has(t,W.bigger) then add({type='buff_troops'})
    elseif has(t,W.army) and has(t,W.power) and not has(t,W.kill) then add({type='boost_army'})
    elseif has(t,{'rage','ярост'}) then add({type='boost_army'}) end
    if has(t,W.workers) then add({type='boost_workers'}) end
    if has(t,W.shield) then add({type='shield'}) end
    if has(t,W.level) then add({type='level_up'}) elseif has(t,W.build) then add({type='instant_build'}) end
    if has(t,W.attack) and not has(t,W.meteor) then add({type='attack'}) end
    if has(t,W.kill) then add({type=baseWord and 'damage_base' or 'kill_troops',percent=baseWord and 70 or nil})
    elseif has(t,W.lightning) then add({type='damage_troops',fxKind='lightning'})
    elseif has(t,W.meteor) and not (has(t,W.army) and has(t,W.power) and not has(t,W.base)) then add({type=baseWord and 'damage_base' or 'damage_troops'}) end
    return out
end
local function split(t)
    local parts={}
    t=t:gsub(' and then ',' | '):gsub(' then ',' | '):gsub(' and ',' | '):gsub(' also ',' | '):gsub(' plus ',' | ')
        :gsub(' и ',' | '):gsub(' потом ',' | '):gsub(' затем ',' | '):gsub(' а также ',' | '):gsub(' плюс ',' | '):gsub('[,;+]',' | ')
    for piece in t:gmatch('[^|]+') do piece=piece:match('^%s*(.-)%s*$');if piece~='' then parts[#parts+1]=' '..piece..' ' end end
    return parts
end
function Rules.localPlan(s,e)
    local plan={actions={}}
    local base=' '..lower(Rules.sanitize(e.prompt))..' '
    local defaultTarget=clauseTarget(s,e,base)
    for _,piece in ipairs(split(base)) do
        local own=clauseTarget(s,e,piece)
        for _,a in ipairs(detect(piece)) do
            -- "boost my army and nuke" must not nuke the author: harmful parts only take their own target
            local target=own or ((not HARMFUL[a.type] or defaultTarget~='author') and defaultTarget) or nil
            a.target=a.target or target
            if a.type=='attack' and target and target~='author' and target~='enemies' and target~='everyone' then a.victim=target;a.target='author' end
            plan.actions[#plan.actions+1]=a
        end
    end
    if #plan.actions==0 then return {refused=true,reason='The Admin Panel cannot do that command.'} end
    plan.rejected_additions={}
    -- roulette additions: modifiers change everything, new actions are appended, the rest is ignored
    for _,id in ipairs(s.wish.ids) do
        local text=e.additions[id]
        if text and text~='' and eligible(s,id) then
            local t=' '..lower(text)..' '
            if has(t,MOD.cancel) then plan.cancelled=true;plan.caption=name(s,id)..' cancelled the command!';break end
            local target=clauseTarget(s,e,t)
            if target=='author' and id~=e.recipient then target=name(s,id) end
            local extra={};for _,piece in ipairs(split(t)) do for _,a in ipairs(detect(piece)) do extra[#extra+1]=a end end
            local modifier=target~=nil
            for _,list in pairs(MOD) do if has(t,list) then modifier=true end end
            if #extra>0 then
                for _,a in ipairs(extra) do a.target=a.target or target;plan.actions[#plan.actions+1]=a end
            elseif not modifier then
                plan.rejected_additions[#plan.rejected_additions+1]=name(s,id)
            else
                for _,a in ipairs(plan.actions) do
                    if has(t,MOD.half) then for _,k in ipairs({'percent','count','amount','seconds'}) do if a[k] then a[k]=a[k]*.5 end end;a.percent=a.percent or 30;a.power=1 end
                    if has(t,MOD.double) then a.percent=(a.percent or 50)*2;a.count=(a.count or 5)*2;a.amount=a.amount and a.amount*2;a.seconds=a.seconds and a.seconds*2;a.power=3 end
                    if has(t,MOD.short) then a.seconds=5 end
                    if has(t,MOD.long) then a.seconds=60 end
                    if target then a.target=target end
                end
            end
        end
    end
    if #plan.actions>8 then local keep={};for i=1,8 do keep[i]=plan.actions[i] end;plan.actions=keep end
    return plan
end
-- the command the old API parsed; kept for bots and tests
function Rules.parse(text)
    local t=' '..lower(Rules.sanitize(text))..' '
    if t=='  ' then return nil,'No prompt was submitted.' end
    local list=detect(t)
    if #list==0 then return nil,'Not understood locally.' end
    return list[1].type,list[1].type
end
Rules.Examples={'meteor on enemies','summon 5 giants','heal my army','freeze everyone except me','give me 100 gold','steal their wood','upgrade my town hall','shield my base'}

-- ================================================================== event flow
local function finish(s,e,reason,outcome)
    if e.phase=='Applied' then return end
    e.pending={};e.buffers={};e.applied=false;e.outcome=outcome or 'Rejected';e.effect=reason
    phase(s,e,'Applied')
end
local function executePlan(s,e,plan,source)
    if e.phase=='Applied' then return end
    e.pending={};e.buffers={}
    local ok,success,message,outcome=pcall(Rules.execute,s,e,plan)
    if not ok then
        warn('[ArmyRound] Admin command failed safely: '..tostring(success))
        e.applied=false;e.effect='The Admin Panel glitched. No effects were applied.';e.outcome='Rejected'
    else
        e.applied=success==true;e.effect=message;e.outcome=outcome or (success and 'Executed' or 'Rejected')
    end
    e.source=source
    phase(s,e,'Applied')
end
-- the final command is known: ask the brain (RoundServer) and wait for it
local function think(s,e)
    if e.phase=='Applied' or e.phase=='Thinking' then return end
    e.pending={};e.buffers={};e.brainAsked=false
    local parts={e.prompt}
    for _,id in ipairs(s.wish.ids) do local t=e.additions[id];if t and t~='' then parts[#parts+1]=t end end
    e.finalPrompt=table.concat(parts,' ')
    phase(s,e,'Thinking')
end
-- One job per event for AdminBrain: the author's command, everyone's additions and a small game summary.
function Rules.thinking(s)
    local e=s.wish and s.wish.event
    if not e or e.phase~='Thinking' or e.brainAsked then return nil end
    e.brainAsked=true
    local players={}
    for _,id in ipairs(s.wish.ids) do
        local p=s.players[id]
        if p and eligible(s,id) then
            local army={};for _,u in ipairs(troops(s,id)) do army[u.kind]=(army[u.kind] or 0)+1 end
            local res={};for _,r in ipairs(Rules.Resources) do local n=math.floor(p.resources[r] or 0);if n>0 then res[r]=n end end
            players[#players+1]={name=p.name,author=id==e.recipient,troops=army,resources=res,base_hp=math.floor(p.baseHP or 0),base_max_hp=p.baseMaxHP}
        end
    end
    local additions={}
    for _,id in ipairs(s.wish.ids) do local t=e.additions[id];if t and t~='' then additions[#additions+1]={player=name(s,id),text=t} end end
    return {eventId=e.id,author=name(s,e.recipient),authorUid=e.recipient,command=e.prompt,additions=additions,players=players}
end
-- AdminBrain answered (plan) or failed (nil -> local interpreter).
function Rules.resolve(s,eventId,plan)
    local e=s.wish and s.wish.event
    if not e or e.id~=eventId or e.phase~='Thinking' or s.status~='Active' then return false end
    if plan~=nil and Rules.normalizePlan(plan) then return executePlan(s,e,plan,'ai') or true end
    executePlan(s,e,Rules.localPlan(s,e),'local');return true
end
local function anyPending(e) return next(e.pending)~=nil end
function Rules.canWish(s,uid,op,id)
    local e=s.wish and s.wish.event
    if s.status~='Active' or not eligible(s,uid) or not e or tostring(id or '')~=e.id or s.elapsed>=e.deadline or e.submitted[uid] then return false end
    if e.phase=='Prompt' then return uid==e.recipient and (op=='WishDraft' or op=='WishSubmit') end
    if e.phase=='Append' then return uid~=e.recipient and (op=='AppendDraft' or op=='AppendSubmit') end
    return false
end
function Rules.approve(s,uid,eventId,sourcePhase,filtered)
    local e=s.wish and s.wish.event
    if not e or e.id~=eventId or not e.pending[uid] or e.pending[uid].phase~=sourcePhase or s.status~='Active' then return false end
    e.pending[uid]=nil
    if sourcePhase=='Prompt' then
        if e.phase~='Filtering' then return false end
        if not filtered or Rules.sanitize(filtered)=='' then finish(s,e,'The prompt could not be shared. Please try again at the next event.');return false end
        e.prompt=Rules.sanitize(filtered);e.buffers={};phase(s,e,'Announcement')
    else
        if e.phase~='Append' and e.phase~='Resolving' then return false end
        if filtered then e.additions[uid]=Rules.sanitize(filtered) end
        if e.phase=='Resolving' and not anyPending(e) then think(s,e) end
    end
    return true
end
local function submit(s,e,uid,sourcePhase)
    e.submitted[uid]=true
    local text=Rules.sanitize(e.buffers[uid] or '')
    if sourcePhase=='Prompt' then
        if text=='' then finish(s,e,'No prompt was submitted.');return end
        phase(s,e,'Filtering')
    elseif text=='' then e.additions[uid]='';return end
    e.pending[uid]={phase=sourcePhase,text=text,started=s.elapsed}
    if s.players[uid].isBot then Rules.approve(s,uid,e.id,sourcePhase,text) end
end
function Rules.action(s,uid,op,payload)
    payload=type(payload)=='table' and payload or {}
    if not Rules.canWish(s,uid,op,payload.eventId) then return false,'This input window is closed.' end
    local e=s.wish.event
    if op=='WishDraft' or op=='AppendDraft' then
        local text=payload.prompt or payload.text or ''
        if not Typing.validEdit(e.buffers[uid] or '',text) then return false,'Type the prompt manually; pasting is disabled.' end
        e.buffers[uid]=text;return true,nil
    end
    -- Submit carries no authoritative text: it uses the character-by-character server buffer.
    submit(s,e,uid,e.phase);return true,nil
end
function Rules.pending(s)
    local out={};local e=s.wish and s.wish.event
    if e then for uid,job in pairs(e.pending) do if not job.running then
        job.running=true;out[#out+1]={uid=uid,eventId=e.id,phase=job.phase,text=job.text}
    end end end
    return out
end
function Rules.tick(s,elapsed)
    local w=s.wish;if not w then return end
    if s.status~='Active' then w.event=nil;return end
    local e=w.event
    if e then
        if e.phase=='Applied' then
            if elapsed>=e.deadline then
                w.event=nil
                -- the timer restarts after a timer panel; tickets never delay it
                if not e.ticket then w.nextAt=math.max((w.lastTimerStart or elapsed)+Rules.Interval,elapsed+5)
                else w.nextAt=math.max(w.nextAt,elapsed+3) end
            end
            return
        end
        if not eligible(s,e.recipient) then finish(s,e,'The author left the round.');return end
        for uid in pairs(e.pending) do
            if not eligible(s,uid) then e.pending[uid]=nil;e.additions[uid]=nil end
        end
        if e.phase=='Resolving' and not anyPending(e) then think(s,e);return end
        if elapsed<e.deadline then return end
        if e.phase=='Prompt' then submit(s,e,e.recipient,'Prompt')
        elseif e.phase=='Filtering' then finish(s,e,'Text filtering timed out. No effect was applied.')
        elseif e.phase=='Announcement' then
            e.choice=random(w)<.5 and 'Execute' or 'Append';phase(s,e,'Roulette')
        elseif e.phase=='Roulette' then
            if e.choice=='Execute' then think(s,e) else
                e.submitted={};e.buffers={};e.pending={};phase(s,e,'Append')
            end
        elseif e.phase=='Append' then
            for _,id in ipairs(w.ids) do if id~=e.recipient and eligible(s,id) and not e.submitted[id] then submit(s,e,id,'Append') end end
            if anyPending(e) then phase(s,e,'Resolving') else think(s,e) end
        elseif e.phase=='Resolving' then
            -- unfiltered clauses are dropped; the filtered command still runs
            for uid in pairs(e.pending) do e.additions[uid]=nil end
            think(s,e)
        elseif e.phase=='Thinking' then
            -- the AI did not answer in time
            executePlan(s,e,Rules.localPlan(s,e),'local')
        end
        return
    end
    -- waiting tickets go first, then the timer
    while #w.queue>0 do
        local uid=table.remove(w.queue,1)
        if eligible(s,uid) then open(s,uid,true);return end
    end
    if elapsed>=w.nextAt then Rules.newEvent(s) end
end
function Rules.snapshot(s,uid)
    local w=s.wish;if not w then return nil end
    local e=w.event
    if not e then return {phase='Idle',nextIn=math.max(0,math.ceil(w.nextAt-s.elapsed)),queue=#w.queue} end
    local author=s.players[e.recipient];local quotes={}
    if e.prompt~='' then quotes[#quotes+1]={uid=e.recipient,name=author and author.name or 'Player',color=author and copy(author.color),text=e.prompt} end
    if e.phase=='Applied' then for _,id in ipairs(w.ids) do local text=e.additions[id]
        if text and text~='' then local p=s.players[id];quotes[#quotes+1]={uid=id,name=p and p.name or 'Player',color=p and copy(p.color),text=text,rejected=e.rejected and e.rejected[id] or nil} end
    end end
    local canType=Rules.canWish(s,uid,e.phase=='Prompt' and 'WishDraft' or 'AppendDraft',e.id)
    return {eventId=e.id,phase=e.phase,remaining=math.max(0,math.ceil(e.deadline-s.elapsed)),remainingExact=math.max(0,e.deadline-s.elapsed),
        phaseElapsed=math.max(0,s.elapsed-e.started),duration=e.duration,recipient=e.recipient,recipientName=author and author.name,
        recipientColor=author and copy(author.color),prompt=e.prompt,finalPrompt=e.finalPrompt,quotes=quotes,choice=e.choice,
        canType=canType,submitted=e.submitted[uid]==true,ownDraft=canType and (e.buffers[uid] or '') or nil,
        outcome=e.outcome,effect=e.effect,applied=e.applied,ticket=e.ticket,
        examples=e.phase=='Prompt' and uid==e.recipient and Rules.Examples or nil}
end
Rules.copy=copy
return Rules
