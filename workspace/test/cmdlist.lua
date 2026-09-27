local Data=__req("RoundData");local State=__req("RoundState");local W=__req("WishRules");local C=__req("AdminCommands");local A=__req("AdminActions")
local seed=11;local function rng() seed=(seed*1103515245+12345)%2147483648;return seed/2147483648 end
local uids={"1","2","3"};local layouts={}
for i,uid in ipairs(uids) do local L={lands={},buildings={},nodes={}}
 for n,d in pairs(Data.Lands) do L.lands[n]={x=d.pos.x+i*300,y=d.pos.y,z=d.pos.z} end
 for k,d in pairs(Data.Buildings) do L.buildings[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 for k,d in pairs(Data.ResourceNodes) do L.nodes[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 layouts[uid]=L end
local territories={["Island:1"]={tier="Small",pos={x=600,y=-0.78,z=15},goldRate=.05},["Island:2"]={tier="Small",pos={x=450,y=-0.78,z=15},goldRate=.05}}
local s
local function army(uid) local n=0;for _,u in pairs(s.units) do if u.owner==uid and u.role=="Troop" then n=n+1 end end;return n end
local function refill()
  -- like the real map: a walkable centre strip, and one bridge from each home island to it
  local central={}
  local y=layouts["1"].lands.S1.y
  for x=300,900,15 do central["C:"..x]={x=x,y=y,z=15} end
  for _,id in ipairs(uids) do local h=layouts[id].lands.S1;central["Bridge:"..id]={x=h.x,y=y,z=(h.z+15)/2};layouts[id].bridgeLanding={x=h.x,y=y,z=15} end
  s=State.new(Data,layouts,central,territories,{names={["1"]="Alice",["2"]="Bob",["3"]="Carl"},bots={},colors={},rng=rng})
  State.setRng(s,rng)
  for _,id in ipairs(uids) do
    local p=s.players[id]
    s.wishHooks.expand(s,p,12)
    s.wishHooks.summon(s,p,"Barbarian",5)
    for _,r in ipairs(A.Resources) do p.resources[r]=200 end
    for _,b2 in pairs(p.buildings) do
      if b2.kind=="LumberHut" then b2.upgrade={left=30,target=2} end
      if b2.kind=="Townhall" or b2.kind=="Barracks" then s.wishHooks.setLevel(s,p,b2,2) end
    end
  end
  for _=1,8 do State.step(s,.1) end
  for _,id in ipairs(uids) do for _,u in pairs(s.units) do if u.owner==id and u.role=="Troop" then u.hp=u.maxHP*.5 end end end
end
refill()
local function event(prompt,adds,raw)
  s.wish.event=nil;s.fx={}
  local e={id=tostring(rng()),recipient="1",prompt=prompt,rawPrompt=raw or prompt,buffers={},submitted={},pending={},additions=adds or {},rawAdditions={},applied=false,phase="Test",deadline=math.huge,started=0}
  s.wish.event=e;return e
end
local instantFail,execFail,total=0,0,0
local function try(text,expect,cat)
  refill();total=total+1
  local e=event(text)
  local plan=C.plan(s,e,true)
  local types={}
  local found=false
  for _,a in ipairs(plan and plan.actions or {}) do types[#types+1]=a.type..":"..tostring(a.target)..(a.count and ("#"..a.count) or "")..(a.amount and ("$"..a.amount) or "")..(a.unit and ("/"..a.unit) or "")..(a.resource and ("/"..a.resource) or "");if a.type==expect then found=true end end
  if not plan or not found then
    instantFail=instantFail+1
    print(string.format("NOT INSTANT  %-28s expect %-16s got %s",text,expect,table.concat(types,",")))
    return
  end
  local ok,msg=A.execute(s,e,plan)
  if not ok then execFail=execFail+1;print(string.format("EXEC FAIL    %-28s %s -> %s",text,table.concat(types,","),tostring(msg))) end
  if s.status~="Active" or s.players["2"].defeated or s.players["1"].defeated then print("STATE CHANGED after",text,s.status,s.reason,s.players["1"].defeated,s.players["2"].defeated,s.players["3"].defeated);os.exit(1) end
  if VERBOSE then print(string.format("%-40s %s | %s",text,table.concat(types,","),tostring(msg):gsub("\n"," / "))) end
end
for _,row in ipairs(COMMANDS) do try(row[3],row[2],row[1]);try(row[4],row[2],row[1]) end
print(string.format("commands %d, not instant %d, exec failed %d",total,instantFail,execFail))
-- things that must go to the AI (strict dictionary says nil)
for _,text in ipairs({"заспавни пару криперов","spawn me in the middle of the map","kick Bob","забань Bob","give me VIP","дай мне тикеты","give me robux","дай мне донат","turn everyone into chickens","не давай Bob золото"}) do
  local e=event(text);print("to AI:",text,C.plan(s,e,true)==nil)
end
-- the typed text is used, the filtered text is shown
refill();local before=army("1")
local e=event("дай мне ### военных",{},"дай мне 100 военных")
local plan=C.plan(s,e,true);print("hashtags ->",plan and plan.actions[1].type,plan and plan.actions[1].count)
-- additions: "мне" in Bob's addition is Bob
refill()
e=event("дай мне 100 военных",{["2"]="и мне дай 50 лучников",["3"]="x2"})
plan=C.plan(s,e,true)
for _,a in ipairs(plan.actions) do print("  add:",a.type,a.target,a.unit,a.count) end
local ok,msg=A.execute(s,e,plan);print("  exec",ok,(tostring(msg):gsub("\n"," / ")))
for _=1,80 do State.step(s,.1) end
print("  armies after stream: Alice",army("1"),"Bob",army("2"),"queue",#s.summonQueue)
-- 200 cap
e=event("дай мне 500 гигантов");plan=C.plan(s,e,true);print("cap:",A.execute(s,e,plan))
for _=1,200 do State.step(s,.1) end
print("  Alice troops",army("1"))
e=event("дай мне 10 магов");print("full:",A.execute(s,e,C.plan(s,e,true)))
-- cancel and rejected addition (fallback mode)
e=event("метеоры на врагов",{["2"]="отмена"});print("cancel:",A.execute(s,e,C.plan(s,e,true)))
e=event("метеоры на врагов",{["2"]="и покрась небо в розовый",["3"]="x2"})
print("strict with odd addition -> AI:",C.plan(s,e,true)==nil)
plan=C.plan(s,e,false);print("fallback:",A.execute(s,e,plan),"rejected Bob",e.rejected["2"],"Carl",e.rejected["3"])
-- controls lock blocks orders
e=event("отключи всем клавиатуры и мышки");A.execute(s,e,C.plan(s,e,true))
print("locked order:",State.action(s,"2","Train",{kind="Barbarian"}))
print("locked snapshot:",State.snapshot(s,"2").locked)
