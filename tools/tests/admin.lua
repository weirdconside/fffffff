local Data=__req("RoundData");local State=__req("RoundState");local W=__req("WishRules")
local seed=7;local function rng() seed=(seed*1103515245+12345)%2147483648;return seed/2147483648 end
local uids={"1","2","3"};local layouts={}
for i,uid in ipairs(uids) do local L={lands={},buildings={},nodes={}}
 for n,d in pairs(Data.Lands) do L.lands[n]={x=d.pos.x+i*300,y=d.pos.y,z=d.pos.z} end
 for k,d in pairs(Data.Buildings) do L.buildings[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 for k,d in pairs(Data.ResourceNodes) do L.nodes[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 layouts[uid]=L end
local s=State.new(Data,layouts,{},{},{names={["1"]="Alice",["2"]="Bob",["3"]="Carl"},bots={},colors={},rng=rng})
State.setRng(s,rng)
for _,id in ipairs(uids) do s.wishHooks.summon(s,s.players[id],"Barbarian",4) end
local function army(uid) local n,hp=0,0;for _,u in pairs(s.units) do if u.owner==uid and u.role=="Troop" then n=n+1;hp=hp+u.hp end end;return n,hp end
local function fresh(prompt,adds)
  s.wish.event=nil;s.fx={}
  local e={id="t"..tostring(rng()),recipient="1",prompt=prompt,buffers={},submitted={},pending={},additions=adds or {},applied=false}
  s.wish.event=e;return e
end
local phrases={
 "meteor on enemies","метеориты на врагов","summon 50 giants","призови 5 гигантов","heal my army","вылечи мою армию",
 "freeze everyone except me","заморозь Bob","give me 100 gold","дай мне золото","steal their wood","укради дерево у Carl",
 "upgrade my town hall","улучши ратушу","shield my base","защити мою базу","kill Bob","убей всех врагов",
 "destroy Carl's base","уничтожь базу Bob","boost my army and nuke them","ускорь рабочих","make my army huge",
 "attack Bob","атакуй Carl","I win","turn everyone into chickens","asdfgh","build everything instantly","дай все ресурсы",
 "lightning on Bob","замедли врагов","мир во всем мире"}
local fails=0
for _,text in ipairs(phrases) do
  local e=fresh(text)
  local plan=W.localPlan(s,e)
  local ok,msg,outcome=W.execute(s,e,plan)
  local types={};for _,a in ipairs(plan.actions or {}) do types[#types+1]=a.type..":"..tostring(a.target) end
  print(string.format("%-34s %-5s %-40s | %s",text,tostring(ok),table.concat(types,","),tostring(msg):gsub("\n"," / ")))
  if not ok then fails=fails+1 end
  -- restore armies so later lines have something to hit
  for _,id in ipairs(uids) do if army(id)<3 then s.wishHooks.summon(s,s.players[id],"Barbarian",4) end;s.players[id].slowUntil=0 end
end
print("local fails",fails)
-- additions
local e=fresh("meteor on enemies",{["2"]="but it hits the author",["3"]="x2"})
local p=W.localPlan(s,e);print("adds:",p.actions[1].type,p.actions[1].target,p.actions[1].percent)
e=fresh("summon 5 giants",{["2"]="cancel"});print("cancel:",W.execute(s,e,W.localPlan(s,e)))
-- AI plan path + clamps + bad data
e=fresh("x");local before=s.players["1"].resources.Gold or 0
print("ai:",W.execute(s,e,{caption="Gold rain!",actions={{type="give",target="author",resource="Gold",amount=999999},{type="summon",target="Bob",unit="Dragon",count=1000},{type="nope"},{type="freeze",target="everyone",seconds=99999}}}))
print("gold gained",(s.players["1"].resources.Gold or 0)-before,"bob army",army("2"),"freeze left",s.players["3"].slowUntil-s.elapsed)
print("junk:",W.execute(s,e,"garbage"),W.execute(s,e,{actions={}}),W.execute(s,e,{refused=true,reason="no"}))
-- full flow: Thinking -> resolve (AI) and Thinking -> timeout (local)
s.wish.event=nil;s.wish.nextAt=0
local fxCount=0
local function step(n) for _=1,n do State.step(s,.1);if s.fx then fxCount=fxCount+#s.fx;s.fx={} end end end
step(2)
local ev=s.wish.event;assert(ev and ev.phase=="Prompt","event opened")
local author=ev.recipient
for i=1,#"meteor on everyone" do assert(State.action(s,author,"WishDraft",{eventId=ev.id,prompt=("meteor on everyone"):sub(1,i)})) end
assert(State.action(s,author,"WishSubmit",{eventId=ev.id}))
for _,j in ipairs(W.pending(s)) do W.approve(s,j.uid,j.eventId,j.phase,j.text) end
local guard=0
while ev.phase~="Thinking" and guard<400 do step(1);guard=guard+1
  if ev.phase=="Append" then for _,id in ipairs(uids) do if id~=author and not ev.submitted[id] then
    for i=1,#"and freeze them" do State.action(s,id,"AppendDraft",{eventId=ev.id,text=("and freeze them"):sub(1,i)}) end end end end
  for _,j in ipairs(W.pending(s)) do W.approve(s,j.uid,j.eventId,j.phase,j.text) end
end
print("phase",ev.phase,"choice",ev.choice,"final",ev.finalPrompt)
local job=W.thinking(s);assert(job and job.command=="meteor on everyone",'job');assert(W.thinking(s)==nil,'job once')
step(95)
print("timeout ->",ev.phase,ev.outcome,ev.effect,"fx",fxCount)
-- strict rules
e=fresh("turn everyone into chickens");print("chickens:",W.execute(s,e,W.localPlan(s,e)))
e=fresh("meteor on enemies",{["2"]="and paint the sky pink",["3"]="but half strength"})
local ok2,msg2=W.execute(s,e,W.localPlan(s,e));print("bad addition:",ok2,msg2,"rejected2",e.rejected and e.rejected["2"],"rejected3",e.rejected and e.rejected["3"])
e=fresh("meteor on enemies",{["2"]="x"});print("ai reject add:",W.execute(s,e,{caption="Boom",actions={{type="damage_troops",target="enemies"}},rejected_additions={"Bob"}}),e.rejected["2"])
-- author cannot append
s.wish.event=nil;local ev2=fresh("meteor");ev2.phase="Append";ev2.deadline=s.elapsed+10
print("author append allowed:",State.canWish(s,"1","AppendDraft",ev2.id),"other:",State.canWish(s,"2","AppendDraft",ev2.id))
