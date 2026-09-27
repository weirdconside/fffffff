local Data=__req("RoundData")
local State=__req("RoundState")
local Bots=__req("RoundBots")
local W=__req("WishRules")
local seed=12345
local function rng() seed=(seed*1103515245+12345)%2147483648;return seed/2147483648 end
local uids={"1","2","-1","-2"}
local layouts={}
for i,uid in ipairs(uids) do
    local ox=i*300
    local L={lands={},buildings={},nodes={}}
    for name,d in pairs(Data.Lands) do L.lands[name]={x=d.pos.x+ox,y=d.pos.y+0.5,z=d.pos.z} end
    for key,d in pairs(Data.Buildings) do L.buildings[key]={x=d.pos.x+ox,y=L.lands[d.land].y,z=d.pos.z} end
    for key,d in pairs(Data.ResourceNodes) do L.nodes[key]={x=d.pos.x+ox,y=L.lands[d.land].y,z=d.pos.z} end
    layouts[uid]=L
end
local perks={["1"]={AdminPass=true,RiggedRoulette=true,VetoPower=true,OvertimePen=true,MasterBuilder=true,StarterCrate=true}}
local s=State.new(Data,layouts,{},{},{names={["1"]="Alice",["2"]="Bob",["-1"]="Bot 1",["-2"]="Bot 2"},bots={["-1"]=true,["-2"]=true},colors={},perks=perks,rng=rng})
State.setRng(s,rng)
assert(s.players["1"].resources.Log==60,"starter crate")
assert(s.players["2"].resources.Log==0)
local B=Bots.attach(s,{{UserId=1},{UserId=2},{UserId=-1,IsBot=true},{UserId=-2,IsBot=true}},State)
local function tick(n)
    for _=1,n do
        State.step(s,0.1);Bots.step(B,0.1)
        for _,job in ipairs(W.pending(s)) do W.approve(s,job.uid,job.eventId,job.phase,job.text) end
    end
end
local function typeText(uid,op,text)
    local e=s.wish.event
    for i=1,#text do local ok,msg=State.action(s,uid,op.."Draft",{eventId=e.id,prompt=text:sub(1,i)});assert(ok,msg) end
    local ok,msg=State.action(s,uid,op.."Submit",{eventId=e.id});assert(ok,msg)
end
tick(600)
print("t=",s.elapsed,"bots actions",s.players["-1"].botActions,s.players["-2"].botActions,"stages",s.wish.completedStages,s.wish.totalStages)
-- wait for idle
local guard=0
while s.wish.event and guard<2000 do tick(1);guard=guard+1 end
-- Admin token for Alice: summon giants
local ok,msg=State.useToken(s,"1","AdminToken");print("token",ok,msg)
assert(ok and s.wish.event and s.wish.event.recipient=="1" and s.wish.event.token)
assert(s.wish.event.duration==25,"overtime pen "..tostring(s.wish.event.duration))
local before=0;for _,u in pairs(s.units) do if u.owner=="1" and u.kind=="Giant" then before=before+1 end end
typeText("1","Wish","summon 3 giants")
local phases={}
guard=0
while s.wish.event and s.wish.event.phase~="Applied" and guard<3000 do
    local e=s.wish.event;phases[e.phase]=true
    if e.phase=="Append" and not e.submitted["2"] then typeText("2","Append","but at half strength") end
    tick(1);guard=guard+1
end
local e=s.wish.event
print("outcome",e.outcome,e.effect,e.finalPrompt)
local after=0;for _,u in pairs(s.units) do if u.owner=="1" and u.kind=="Giant" then after=after+1 end end
print("giants",before,"->",after)
while s.wish.event do tick(1) end
-- direct interpreter checks
for _,t in ipairs({"meteor on enemies","freeze enemies","steal their wood","build instantly","give me gold","give me stone and planks","heal my army","boost my army","fortify my base","дай золото","призови 2 мага","заморозь врагов","hello there"}) do
    print(t,"=>",W.parse(t))
end
-- run each effect through a forced event with Execute forced
local function run(prompt)
    while s.wish.event do tick(1) end
    local p1=s.players["1"]
    local snap={gold=p1.resources.Gold,log=p1.resources.Log}
    W.force(s,"1");typeText("1","Wish",prompt)
    local g=0
    while s.wish.event and s.wish.event.phase~="Applied" and g<3000 do
        local ev=s.wish.event
        if ev.phase=="Roulette" then ev.choice="Execute" end
        tick(1);g=g+1
    end
    local ev=s.wish.event
    print(("%-22s %-9s %s | gold %d->%d log %d->%d"):format(prompt,tostring(ev.outcome),tostring(ev.effect),snap.gold,p1.resources.Gold,snap.log,p1.resources.Log))
end
for _,t in ipairs({"give me gold","steal their wood","meteor on enemies","freeze enemies","build instantly","give me planks"}) do run(t) end
print("bot2 slowUntil",s.players["-2"].slowUntil,"elapsed",s.elapsed)
-- veto: wait for a bot event
while s.wish.event do tick(1) end
W.force(s,"-1")
guard=0
while s.wish.event and s.wish.event.phase~="Announcement" and guard<500 do tick(1);guard=guard+1 end
print("phase before veto",s.wish.event and s.wish.event.phase, "canVeto",W.canVeto(s,"1"),W.canVeto(s,"2"))
print("veto",State.action(s,"1","Veto",{}))
print("after veto",s.wish.event.phase,s.wish.event.outcome,s.wish.event.effect)
print("second veto",State.action(s,"1","Veto",{}))
tick(3000)
print("final t",s.elapsed,"status",s.status,"units",(function() local n=0 for _ in pairs(s.units) do n=n+1 end return n end)())
for _,uid in ipairs(uids) do local p=s.players[uid];local lv=0;for _,b in pairs(p.buildings) do lv=lv+b.level end;print(uid,"levels",lv,"log",math.floor(p.resources.Log),"gold",math.floor(p.resources.Gold)) end
local snap=State.snapshot(s,"1");print("snapshot ok",snap.tokenReady,snap.wish.phase,snap.boosts.army)
