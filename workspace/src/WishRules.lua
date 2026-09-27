-- Authoritative Admin event: private input -> announcement -> roulette -> append/execute.
-- Human drafts are PRIVATE and filtered only on submission, before any public display.
-- The effect interpreter remains local and bounded; there is no external AI service.
local Typing=require(game:GetService('ReplicatedStorage'):WaitForChild('ArmyRoundShared'):WaitForChild('TypingRules'))
local Rules={Times={Prompt=15,Announcement=3,Roulette=5,Append=10,Applied=3,Filtering=6,Resolving=6}}
local function copy(v) if type(v)~='table' then return v end;local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out end
local function keys(t) local a={};for k in pairs(t or {}) do a[#a+1]=tostring(k) end;table.sort(a);return a end
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
    local ids=keys(players);local counts={};for _,id in ipairs(ids) do counts[id]=0 end
    return {ids=ids,counts=counts,maxAwards=3,totalStages=#ids*3,completedStages=0,lastAward=-math.huge,cooldown=60,nextId=0,rng=opts and opts.rng or math.random}
end
function Rules.setRng(w,rng) if w and type(rng)=='function' then w.rng=rng end end
function Rules.progress(s)
    local best=0;for id,p in pairs(s.players) do if eligible(s,id) then
        local n=0;for _,b in pairs(p.buildings) do n=n+math.max(0,b.level-1) end;best=math.max(best,n)
    end end;return best
end
local function recipient(s)
    local w=s.wish;local least=math.huge;local list={}
    for _,id in ipairs(w.ids) do if eligible(s,id) and w.counts[id]<w.maxAwards then least=math.min(least,w.counts[id]) end end
    for _,id in ipairs(w.ids) do if eligible(s,id) and w.counts[id]==least then list[#list+1]=id end end
    if #list>0 then return list[math.floor(random(w)*#list)+1] end
end
function Rules.newEvent(s,elapsed)
    local w=s.wish
    if not w or w.event or w.completedStages>=w.totalStages or elapsed-w.lastAward<w.cooldown then return end
    local id=recipient(s);if not id then return end
    w.nextId=w.nextId+1;w.counts[id]=w.counts[id]+1;w.completedStages=w.completedStages+1;w.lastAward=elapsed
    local e={id=tostring(w.nextId),recipient=id,prompt='',buffers={},submitted={},pending={},additions={},applied=false}
    w.event=e;phase(s,e,'Prompt');return e
end
function Rules.parse(text)
    local t=Rules.sanitize(text):lower()
    if t=='' then return nil,'No prompt was submitted.' end
    -- Harmless requests are a bounded shield effect, so they never break the
    -- round heartbeat or get treated as an unknown server operation.
    local peace={'do not kill','dont kill',"don't kill",'no kill','не убивать','не убивай','не атаковать','не трогать','пощади','peace','мир'}
    for _,phrase in ipairs(peace) do if t:find(phrase,1,true) then return 'Shield','Protect armies and bases' end end
    if t:find('heal',1,true) and (t:find('army',1,true) or t:find('troop',1,true) or t:find('unit',1,true) or t:find('арм',1,true) or t:find('войск',1,true)) then return 'Heal','Heal living troops' end
    if (t:find('worker',1,true) or t:find('production',1,true) or t:find('рабоч',1,true)) and (t:find('boost',1,true) or t:find('fast',1,true) or t:find('speed',1,true) or t:find('ускор',1,true)) then return 'Workers','Boost worker production' end
    if (t:find('army',1,true) or t:find('troop',1,true) or t:find('damage',1,true) or t:find('арм',1,true) or t:find('урон',1,true)) and (t:find('boost',1,true) or t:find('strong',1,true) or t:find('increase',1,true) or t:find('усил',1,true)) then return 'Army','Boost army damage' end
    if t:find('fortify',1,true) or t:find('shield',1,true) or t:find('protect my base',1,true) or t:find('защит',1,true) then return 'Shield','Fortify bases' end
    if (t:find('give',1,true) or t:find('grant',1,true) or t:find('дай',1,true) or t:find('добав',1,true)) and (t:find('wood',1,true) or t:find('resource',1,true) or t:find('ресурс',1,true) or t:find('дерев',1,true)) then return 'Resources','Give resources' end
    return nil,'This prompt is not supported by the local game rules.'
end
local function contains(s,text) return s:find(text,1,true)~=nil end
local function plan(s,e)
    local intent,description=Rules.parse(e.prompt);if not intent then return nil,description end
    local result={intent=intent,all=false,strength=1,seconds=nil,extras={}}
    local combined={e.prompt}
    for _,id in ipairs(s.wish.ids) do
        local text=e.additions[id]
        if text and text~='' and eligible(s,id) then
            combined[#combined+1]=text
            local t=text:lower()
            if contains(t,'cancel this wish') or contains(t,'block this wish') then
                result.cancel=true
            elseif contains(t,'half strength') or contains(t,'half as strong') then result.strength=.5
            elseif contains(t,'only for 10 seconds') or contains(t,'lasts 10 seconds') then result.seconds=10
            elseif contains(t,'for everyone') or contains(t,'for all players') then result.all=true
            else
                local extra=Rules.parse(text)
                if not extra then e.finalPrompt=table.concat(combined,' ');return nil,'An appended clause is not supported. No effects were applied.' end
                result.extras[#result.extras+1]={intent=extra,all=contains(t,'everyone') or contains(t,'all players')}
            end
        end
    end
    e.finalPrompt=table.concat(combined,' ');return result
end
local function applyOne(s,p,intent,strength,seconds)
    if intent=='Workers' then p.workerBoostUntil=s.elapsed+(seconds or 45);p.workerBoostStrength=strength
    elseif intent=='Army' then p.armyBoostUntil=s.elapsed+(seconds or 30);p.armyBoostStrength=strength
    elseif intent=='Shield' then p.shieldUntil=s.elapsed+(seconds or 30);p.shieldStrength=strength
    elseif intent=='Heal' then for _,u in pairs(s.units) do if u.owner==p.id and u.role=='Troop' and u.hp>0 then u.hp=math.min(u.maxHP,u.hp+u.maxHP*.4*strength) end end
    elseif intent=='Resources' then for r,n in pairs({Log=80,Stone=40}) do p.resources[r]=math.min(999999,(p.resources[r] or 0)+math.floor(n*strength));p.discovered[r]=true end end
end
local function apply(s,e)
    if not eligible(s,e.recipient) then return false,'The author is no longer in the round.' end
    local proposal,message=plan(s,e);if not proposal then return false,message end
    if proposal.cancel then return false,'The appended prompt cancels this wish. No effects were applied.','Cancelled' end
    local function run(intent,all)
        for _,id in ipairs(s.wish.ids) do if eligible(s,id) and (all or id==e.recipient) then applyOne(s,s.players[id],intent,proposal.strength,proposal.seconds) end end
    end
    run(proposal.intent,proposal.all);for _,item in ipairs(proposal.extras) do run(item.intent,item.all) end
    return true,'The final prompt was executed.'
end
local function finish(s,e,reason)
    if e.phase=='Applied' then return end
    e.pending={};e.buffers={};e.applied=false;e.outcome='Rejected'
    if reason then e.effect=reason else
        -- A malformed or stale prompt must be rejected without escaping the
        -- server heartbeat. No success is reported when the effect throws.
        local ok,message,outcome=pcall(apply,s,e)
        if not ok then
            warn('[ArmyRound] Admin prompt rejected safely: '..tostring(message))
            e.effect='The prompt was rejected safely. No effects were applied.'
            e.outcome='Rejected'
        else
            e.applied=message==true;e.effect=outcome;e.outcome=outcome or (message and 'Executed' or 'Rejected')
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
        if e.phase=='Applied' then if elapsed>=e.deadline then w.event=nil end;return end
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
    elseif w.completedStages<w.totalStages and Rules.progress(s)>=(w.completedStages+1)*2 then Rules.newEvent(s,elapsed) end
end
function Rules.snapshot(s,uid)
    local w=s.wish;if not w then return nil end
    local e=w.event
    if not e then return {phase='Idle'} end
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
        outcome=e.outcome,effect=e.effect,applied=e.applied}
end
Rules.copy=copy
return Rules
