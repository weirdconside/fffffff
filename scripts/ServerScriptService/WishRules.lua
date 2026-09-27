-- Authoritative Admin event: private input -> announcement -> roulette -> append/execute.
-- Human drafts are PRIVATE and filtered only on submission, before any public display.
-- The command interpreter is local and bounded; there is no external AI service.
local Typing=require(game:GetService('ReplicatedStorage'):WaitForChild('ArmyRoundShared'):WaitForChild('TypingRules'))
local Rules={Times={Prompt=15,Announcement=3,Roulette=5,Append=10,Applied=4,Filtering=6,Resolving=6}}
-- Admin panel pacing: a visible timer opens the panel for someone at random.
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
-- ------------------------------------------------------------------ interpreter
local function has(t,list) for _,word in ipairs(list) do if t:find(word,1,true) then return true end end;return false end
local INTENTS={
    {intent='Shield',text='Peace shield on armies and bases',any={'do not kill','dont kill',"don't kill",'no kill','peace','не убивать','не убивай','не атаковать','не трогать','пощади','мир '}},
    {intent='Heal',text='Heal living troops',all={{'heal','cure','restore','лечи','вылечи','исцели','восстанови','хил'},{'army','troop','unit','soldier','арм','войск','солдат','юнит','отряд'}}},
    {intent='Workers',text='Boost worker production',all={{'worker','production','economy','рабоч','экономик','производ'},{'boost','fast','speed','faster','ускор','быстр','буст'}}},
    {intent='Army',text='Boost army damage',all={{'army','troop','damage','attack','арм','войск','урон','атак'},{'boost','strong','increase','power','buff','rage','усил','сильн','мощ','бафф','ярост'}}},
    {intent='Shield',text='Fortify bases',any={'fortify','shield','protect','wall','defen','защит','щит','укреп','оборон'}},
    {intent='Smite',text='Meteors strike enemy troops',any={'meteor','lightning','smite','strike','nuke','bomb','fireball','explo','метеор','молни','бомб','огнен','взорв','кара','уничтож'}},
    {intent='Freeze',text='Freeze enemy armies',any={'freeze','slow','frost','stun','ice ','замороз','медлен','лёд','лед ','оглуш','замедл'}},
    {intent='Build',text='Instant construction',any={'build','construct','upgrade','finish','instant','построй','строй','улучш','достро','мгновен'}},
    {intent='Steal',text='Steal from rivals',any={'steal','rob','loot','take their','take all','укради','украсть','ограб','отбер','забери','отними'}},
    {intent='Summon',text='Summon troops',any={'spawn','summon','army of','reinforce','recruit','призов','призыв','создай','подкреплен','вызов','дай войск','дай армию'}},
    {intent='Gold',text='Gold rain',all={{'gold','coin','money','rich','золот','монет','деньг','богат'},{'give','grant','rain','more','get','want','дай','дать','добав','получ','дожд','больше','хочу'}}},
    {intent='Resources',text='Give resources',all={{'give','grant','more','get','want','дай','добав','больше','получ','хочу'},{'wood','resource','stone','log','plank','iron','crystal','ore','ресурс','дерев','древес','камн','камен','доск','желез','кристал','руд'}}},
}
function Rules.parse(text)
    local t=' '..Rules.sanitize(text):lower()..' '
    if t=='  ' then return nil,'No prompt was submitted.' end
    for _,rule in ipairs(INTENTS) do
        local ok=false
        if rule.any then ok=has(t,rule.any) end
        if rule.all then ok=true;for _,list in ipairs(rule.all) do if not has(t,list) then ok=false;break end end end
        if ok then return rule.intent,rule.text end
    end
    return nil,'The Admin Panel did not understand that command.'
end
Rules.Examples={'heal my army','boost my army','meteor on enemies','freeze enemies','summon 3 giants','give me gold','steal their wood','build instantly','fortify my base','give me stone'}
local function contains(s,text) return s:find(text,1,true)~=nil end
local function plan(s,e)
    local intent,description=Rules.parse(e.prompt);if not intent then return nil,description end
    local result={intent=intent,text=e.prompt,all=false,strength=1,seconds=nil,extras={},labels={description}}
    local combined={e.prompt}
    for _,id in ipairs(s.wish.ids) do
        local text=e.additions[id]
        if text and text~='' and eligible(s,id) then
            combined[#combined+1]=text
            local t=text:lower()
            if contains(t,'cancel') or contains(t,'block this') or contains(t,'отмен') then
                result.cancel=true
            elseif contains(t,'half') or contains(t,'половин') or contains(t,'слаб') then result.strength=.5;result.labels[#result.labels+1]='half strength'
            elseif contains(t,'10 sec') or contains(t,'10 сек') or contains(t,'short') or contains(t,'коротк') then result.seconds=10;result.labels[#result.labels+1]='only 10 seconds'
            elseif contains(t,'double') or contains(t,'twice') or contains(t,'двойн') or contains(t,'вдвое') then result.strength=math.min(2,result.strength*2);result.labels[#result.labels+1]='double power'
            elseif contains(t,'everyone') or contains(t,'all players') or contains(t,'для всех') or contains(t,'всем') then result.all=true;result.labels[#result.labels+1]='for everyone'
            else
                local extra,label=Rules.parse(text)
                if not extra then e.finalPrompt=table.concat(combined,' ');return nil,'An appended clause was not understood. No effects were applied.' end
                result.extras[#result.extras+1]={intent=extra,text=text,all=contains(t,'everyone') or contains(t,'all players') or contains(t,'всем')}
                result.labels[#result.labels+1]=label:lower()
            end
        end
    end
    e.finalPrompt=table.concat(combined,' ');return result
end
local TROOPS={{'giant','гигант',kind='Giant',cap=2},{'wizard','маг','волшеб',kind='Wizard',cap=2},{'archer','лучник',kind='Archer',cap=4},{'barbarian','варвар',kind='Barbarian',cap=5}}
local function summonKind(text)
    local t=text:lower()
    for _,row in ipairs(TROOPS) do for _,word in ipairs(row) do if contains(t,word) then return row.kind,row.cap end end end
    return 'Barbarian',5
end
local function resourceGift(text)
    local t=text:lower()
    local rows={{{'plank','доск'},'Plank',30},{{'iron','желез'},'Iron Bar',12},{{'ore','руд'},'Iron Ore',40},{{'crystal','кристал'},'Crystal',15},
        {{'stone','камн','камен'},'Stone',90},{{'wood','log','дерев','древес'},'Log',140}}
    local out={}
    for _,row in ipairs(rows) do if has(t,row[1]) then out[row[2]]=row[3] end end
    if not next(out) then out={Log=80,Stone=40} end
    return out
end
local function applyOne(s,p,item,strength,seconds)
    local intent=item.intent
    local hooks=s.wishHooks or {}
    if intent=='Workers' then p.workerBoostUntil=s.elapsed+(seconds or 45);p.workerBoostStrength=strength
    elseif intent=='Army' then p.armyBoostUntil=s.elapsed+(seconds or 30);p.armyBoostStrength=strength
    elseif intent=='Shield' then p.shieldUntil=s.elapsed+(seconds or 30);p.shieldStrength=strength
    elseif intent=='Heal' then for _,u in pairs(s.units) do if u.owner==p.id and u.role=='Troop' and u.hp>0 then u.hp=math.min(u.maxHP,u.hp+u.maxHP*.45*strength) end end
    elseif intent=='Resources' then
        for r,n in pairs(resourceGift(item.text or '')) do p.resources[r]=math.min(999999,(p.resources[r] or 0)+math.floor(n*strength));p.discovered[r]=true end
    elseif intent=='Gold' then p.resources.Gold=math.min(999999,(p.resources.Gold or 0)+math.floor(30*strength));p.discovered.Gold=true
    elseif intent=='Smite' then
        for _,u in pairs(s.units) do
            local owner=s.players[u.owner]
            if owner and owner.id~=p.id and u.role=='Troop' and u.hp>0 then u.hp=math.max(0,u.hp-u.maxHP*.45*strength);u.smitten=(u.smitten or 0)+1 end
        end
    elseif intent=='Freeze' then
        for id,other in pairs(s.players) do if id~=p.id and eligible(s,id) then other.slowUntil=s.elapsed+(seconds or 15)*math.min(1,strength+.25) end end
    elseif intent=='Build' then
        for _,b in pairs(p.buildings) do if b.upgrade then b.upgrade.left=math.max(.05,b.upgrade.left-60*strength) end end
        if p.researchJob then p.researchJob.left=math.max(.05,p.researchJob.left-30*strength) end
    elseif intent=='Steal' then
        for id,other in pairs(s.players) do if id~=p.id and eligible(s,id) then
            for _,r in ipairs({'Log','Stone','Gold'}) do
                local take=math.min(120,math.floor((other.resources[r] or 0)*.15*strength))
                if take>0 then other.resources[r]=other.resources[r]-take;p.resources[r]=math.min(999999,(p.resources[r] or 0)+take);p.discovered[r]=true end
            end
        end end
    elseif intent=='Summon' then
        local kind,cap=summonKind(item.text or '')
        local wanted=tonumber((item.text or ''):match('(%d+)')) or cap
        local n=math.clamp(math.floor(wanted*strength+.5),1,cap)
        if hooks.summon then hooks.summon(s,p,kind,n) end
    end
end
local function apply(s,e)
    if not eligible(s,e.recipient) then return false,'The author is no longer in the round.' end
    local proposal,message=plan(s,e);if not proposal then return false,message end
    if proposal.cancel then return false,'The appended prompt cancels this command. No effects were applied.','Cancelled' end
    local function run(item,all)
        for _,id in ipairs(s.wish.ids) do if eligible(s,id) and (all or id==e.recipient) then applyOne(s,s.players[id],item,proposal.strength,proposal.seconds) end end
    end
    run(proposal,proposal.all);for _,item in ipairs(proposal.extras) do run(item,item.all) end
    e.effectLabels=proposal.labels
    return true,'EXECUTED: '..table.concat(proposal.labels,' + ')..'.'
end
local function finish(s,e,reason,outcome)
    if e.phase=='Applied' then return end
    e.pending={};e.buffers={};e.applied=false;e.outcome=outcome or 'Rejected'
    if reason then e.effect=reason else
        -- A malformed or stale prompt must be rejected without escaping the
        -- server heartbeat. No success is reported when the effect throws.
        local ok,success,message,result=pcall(apply,s,e)
        if not ok then
            warn('[ArmyRound] Admin prompt rejected safely: '..tostring(success))
            e.effect='The prompt was rejected safely. No effects were applied.'
            e.outcome='Rejected'
        else
            e.applied=success==true;e.effect=message;e.outcome=result or (success and 'Executed' or 'Rejected')
        end
    end
    phase(s,e,'Applied')
end
local function anyPending(e) return next(e.pending)~=nil end
function Rules.canWish(s,uid,op,id)
    local e=s.wish and s.wish.event
    if s.status~='Active' or not eligible(s,uid) or not e or tostring(id or '')~=e.id or s.elapsed>=e.deadline or e.submitted[uid] then return false end
    if e.phase=='Prompt' then return uid==e.recipient and (op=='WishDraft' or op=='WishSubmit') end
    if e.phase=='Append' then return op=='AppendDraft' or op=='AppendSubmit' end
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
        if e.phase=='Resolving' and not anyPending(e) then finish(s,e) end
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
        if e.phase=='Resolving' and not anyPending(e) then finish(s,e);return end
        if elapsed<e.deadline then return end
        if e.phase=='Prompt' then submit(s,e,e.recipient,'Prompt')
        elseif e.phase=='Filtering' then finish(s,e,'Text filtering timed out. No effect was applied.')
        elseif e.phase=='Announcement' then
            e.choice=random(w)<.5 and 'Execute' or 'Append';phase(s,e,'Roulette')
        elseif e.phase=='Roulette' then
            if e.choice=='Execute' then finish(s,e) else
                e.submitted={};e.buffers={};e.pending={};phase(s,e,'Append')
            end
        elseif e.phase=='Append' then
            for _,id in ipairs(w.ids) do if eligible(s,id) and not e.submitted[id] then submit(s,e,id,'Append') end end
            if anyPending(e) then phase(s,e,'Resolving') else finish(s,e) end
        elseif e.phase=='Resolving' then
            -- Fail closed for unfiltered clauses. The base prompt remains filtered.
            if anyPending(e) then finish(s,e,'An appended prompt could not be filtered. No effect was applied.') else finish(s,e) end
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
        if text and text~='' then local p=s.players[id];quotes[#quotes+1]={uid=id,name=p and p.name or 'Player',color=p and copy(p.color),text=text} end
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
