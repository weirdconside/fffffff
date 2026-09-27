-- Authoritative Admin event: private input -> announcement -> roulette -> (additions) -> applied.
-- Everyone SEES the text after Roblox filtering; the command itself is understood from what was typed.
-- Understanding: AdminCommands (instant built-in dictionary) when every word is known, otherwise
-- AdminBrain (Gemini, via RoundServer). Execution: AdminActions, the only place that changes the round.
local Typing=require(game:GetService('ReplicatedStorage'):WaitForChild('ArmyRoundShared'):WaitForChild('TypingRules'))
local Commands,Actions
do
    local ok=pcall(function() Commands=require(script.Parent.AdminCommands);Actions=require(script.Parent.AdminActions) end)
    if not ok then Commands=require('./AdminCommands.ModuleScript');Actions=require('./AdminActions.ModuleScript') end
end
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

-- ================================================================== event flow
local function finish(s,e,reason,outcome)
    if e.phase=='Applied' then return end
    e.pending={};e.buffers={};e.applied=false;e.outcome=outcome or 'Rejected';e.effect=reason
    phase(s,e,'Applied')
end
local function executePlan(s,e,plan,source)
    if e.phase=='Applied' then return end
    e.pending={};e.buffers={}
    local ok,success,message,outcome=pcall(Actions.execute,s,e,plan)
    if not ok then
        warn('[ArmyRound] Admin command failed safely: '..tostring(success))
        e.applied=false;e.effect='The Admin Panel glitched. No effects were applied.';e.outcome='Rejected'
    else
        e.applied=success==true;e.effect=message;e.outcome=outcome or (success and 'Executed' or 'Rejected')
    end
    e.source=source
    phase(s,e,'Applied')
end
-- The final command is known. A command the dictionary fully understands runs right away;
-- anything else waits (invisibly, the roulette/addition view stays) for Gemini.
local function think(s,e)
    if e.phase=='Applied' or e.phase=='Thinking' then return end
    e.pending={};e.buffers={};e.brainAsked=false
    local parts={e.prompt}
    for _,id in ipairs(s.wish.ids) do local t=e.additions[id];if t and t~='' then parts[#parts+1]=t end end
    e.finalPrompt=table.concat(parts,' ')
    local ok,instant=pcall(Commands.plan,s,e,true)
    if ok and instant then executePlan(s,e,instant,'dictionary');return end
    if not ok then warn('[ArmyRound] Admin dictionary failed safely: '..tostring(instant)) end
    phase(s,e,'Thinking')
end
local function fallback(s,e)
    local ok,plan=pcall(Commands.plan,s,e,false)
    executePlan(s,e,ok and plan or {refused=true,reason='The Admin Panel did not understand that command.'},'fallback')
end
-- One job per event for AdminBrain: what was really typed, plus a small game summary.
function Rules.thinking(s)
    local e=s.wish and s.wish.event
    if not e or e.phase~='Thinking' or e.brainAsked then return nil end
    e.brainAsked=true
    local players={}
    for _,id in ipairs(s.wish.ids) do
        local p=s.players[id]
        if p and eligible(s,id) then
            local army={};for _,u in pairs(s.units) do if u.owner==id and u.role=='Troop' and u.hp>0 then army[u.kind]=(army[u.kind] or 0)+1 end end
            local res={};for _,r in ipairs(Actions.Resources) do local n=math.floor(p.resources[r] or 0);if n>0 then res[r]=n end end
            local buildings={};for _,b in pairs(p.buildings) do buildings[b.kind]=math.max(buildings[b.kind] or 0,b.level) end
            players[#players+1]={name=p.name,author=id==e.recipient,troops=army,resources=res,buildings=buildings,base_hp=math.floor(p.baseHP or 0),base_max_hp=p.baseMaxHP}
        end
    end
    local additions={}
    for _,id in ipairs(s.wish.ids) do
        local t=e.additions[id]
        if t and t~='' then additions[#additions+1]={player=s.players[id] and s.players[id].name or 'Player',text=(e.rawAdditions and e.rawAdditions[id]) or t} end
    end
    local author=s.players[e.recipient]
    return {eventId=e.id,author=author and author.name or 'Player',authorUid=e.recipient,command=e.rawPrompt or e.prompt,additions=additions,players=players}
end
-- AdminBrain answered (plan) or failed (nil -> built-in dictionary, best effort).
function Rules.resolve(s,eventId,plan)
    local e=s.wish and s.wish.event
    if not e or e.id~=eventId or e.phase~='Thinking' or s.status~='Active' then return false end
    if type(plan)=='table' then executePlan(s,e,plan,'ai') else fallback(s,e) end
    return true
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
    local typed=e.pending[uid].text
    e.pending[uid]=nil
    if sourcePhase=='Prompt' then
        if e.phase~='Filtering' then return false end
        if not filtered or Rules.sanitize(filtered)=='' then finish(s,e,'The prompt could not be shared. Please try again at the next event.');return false end
        e.prompt=Rules.sanitize(filtered);e.rawPrompt=typed;e.buffers={};phase(s,e,'Announcement')
    else
        if e.phase~='Append' and e.phase~='Resolving' then return false end
        if filtered then e.additions[uid]=Rules.sanitize(filtered);e.rawAdditions=e.rawAdditions or {};e.rawAdditions[uid]=typed end
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
            fallback(s,e)
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
    if e.prompt~='' then quotes[#quotes+1]={uid=e.recipient,name=author and author.name or 'Player',color=author and copy(author.color),text=e.prompt,
        rejected=(e.phase=='Applied' and e.outcome=='Rejected') or nil} end
    if e.phase=='Applied' then for _,id in ipairs(w.ids) do local text=e.additions[id]
        if text and text~='' then local p=s.players[id];quotes[#quotes+1]={uid=id,name=p and p.name or 'Player',color=p and copy(p.color),text=text,rejected=e.rejected and e.rejected[id] or nil} end
    end end
    local canType=Rules.canWish(s,uid,e.phase=='Prompt' and 'WishDraft' or 'AppendDraft',e.id)
    return {eventId=e.id,phase=e.phase,remaining=math.max(0,math.ceil(e.deadline-s.elapsed)),remainingExact=math.max(0,e.deadline-s.elapsed),
        phaseElapsed=math.max(0,s.elapsed-e.started),duration=e.duration,recipient=e.recipient,recipientName=author and author.name,
        recipientColor=author and copy(author.color),prompt=e.prompt,finalPrompt=e.finalPrompt,quotes=quotes,choice=e.choice,
        canType=canType,submitted=e.submitted[uid]==true,ownDraft=canType and (e.buffers[uid] or '') or nil,
        outcome=e.outcome,effect=e.effect,applied=e.applied,ticket=e.ticket,
        examples=nil}
end
Rules.copy=copy
return Rules
