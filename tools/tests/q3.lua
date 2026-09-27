local Data=__req("RoundData");local State=__req("RoundState");local C=__req("AdminCommands");local A=__req("AdminActions");local W=__req("WishRules")
local layouts={}
for i,uid in ipairs({"1","2"}) do local L={lands={},buildings={},nodes={}}
 for n,d in pairs(Data.Lands) do L.lands[n]={x=d.pos.x+i*300,y=d.pos.y,z=d.pos.z} end
 for k,d in pairs(Data.Buildings) do L.buildings[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 for k,d in pairs(Data.ResourceNodes) do L.nodes[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 layouts[uid]=L end
local s=State.new(Data,layouts,{},{},{names={["1"]="Alice",["2"]="Bob"},bots={},colors={}})
local function army() local n=0;for _,u in pairs(s.units) do if u.owner=="1" and u.role=="Troop" then n+=1 end end;return n end
local function run(t,strict)
  local e={id=t,recipient="1",prompt=t,rawPrompt=t,additions={},rawAdditions={},pending={},buffers={},submitted={},phase="Test",deadline=math.huge,started=0}
  s.wish.event=e
  local plan=C.plan(s,e,strict)
  if not plan then return "-> AI" end
  local ok,msg=A.execute(s,e,plan);return ok,(tostring(msg):gsub("\n"," / "))
end
local function stepN(n) for _=1,n do State.step(s,.1) end end
print("summon 300:",run("дай мне 300 бойцов",true));stepN(60);print("  army",army())
print("summon again:",run("дай мне 300 бойцов",true))
local k=0;for id,u in pairs(s.units) do if u.owner=="1" and u.role=="Troop" and k<50 then u.hp=0;k+=1 end end;stepN(2)
print("  after 50 died",army())
print("summon 300 again:",run("дай мне 300 бойцов",true));stepN(30);print("  army",army())
-- typos: strict goes to the AI, the best-effort parse (AI down) still understands one wrong letter
for _,t in ipairs({"дай мне 100 золта","метеоы на врагов","заморзь врагов","вылечи мою армиб","give me 100 gld","ускрь рабочих","телепортируй армию в цент"}) do
  print(t,"strict:",C.plan(s,{recipient="1",prompt=t,rawPrompt=t,additions={}},true)==nil and "AI" or "instant","| fallback:",run(t,false))
end
-- the submit carries the final text: a lost draft never cuts the last letter
s.wish.event=nil;s.wish.nextAt=0;stepN(1);local ev=s.wish.event
local author=ev.recipient
print("phone: whole word inserted at once:",State.action(s,author,"WishDraft",{eventId=ev.id,prompt="дай"}),State.action(s,author,"WishDraft",{eventId=ev.id,prompt="дай мне 100 золот"}))
print("submit with final text:",State.action(s,author,"WishSubmit",{eventId=ev.id,prompt="дай мне 100 золота"}))
for _,j in ipairs(W.pending(s)) do print("  server got:",j.text) end
