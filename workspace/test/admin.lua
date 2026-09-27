local Data=__req("RoundData");local State=__req("RoundState");local W=__req("WishRules")
local seed=7;local function rng() seed=(seed*1103515245+12345)%2147483648;return seed/2147483648 end
local uids={"1","2","3"};local layouts={}
for i,uid in ipairs(uids) do local L={lands={},buildings={},nodes={}}
 for n,d in pairs(Data.Lands) do L.lands[n]={x=d.pos.x+i*300,y=d.pos.y,z=d.pos.z} end
 for k,d in pairs(Data.Buildings) do L.buildings[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 for k,d in pairs(Data.ResourceNodes) do L.nodes[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 layouts[uid]=L end
local s=State.new(Data,layouts,{},{},{names={["1"]="Alice",["2"]="Bob",["3"]="Carl"},bots={},colors={},rng=rng})
local forced="Execute"
State.setRng(s,function() return forced=="Execute" and .1 or .9 end)
local function step(n) for _=1,n do State.step(s,.1);s.fx={} end end
local function typeText(uid,op,text,ev)
  for i=1,utf8.len(text) do local cut=text:sub(1,utf8.offset(text,i+1)-1);local ok,msg=State.action(s,uid,op.."Draft",{eventId=ev.id,prompt=cut,text=cut});if not ok then return false,msg end end
  return State.action(s,uid,op.."Submit",{eventId=ev.id})
end
local function approveAll(filter) for _,j in ipairs(W.pending(s)) do W.approve(s,j.uid,j.eventId,j.phase,filter and filter(j.text) or j.text) end end
local function runEvent(command,roulette,adds,filter)
  forced=roulette
  s.wish.event=nil;s.wish.nextAt=0;step(1)
  local ev=s.wish.event;assert(ev and ev.phase=="Prompt")
  local author=ev.recipient
  assert(typeText(author,"Wish",command,ev))
  approveAll(filter)
  local guard=0
  while ev.phase~="Applied" and ev.phase~="Thinking" and guard<300 do
    step(1);guard=guard+1
    if ev.phase=="Append" and not ev.typed then
      ev.typed=true
      local okAuthor=State.canWish(s,author,"AppendDraft",ev.id)
      print("  author may append:",okAuthor)
      for id,text in pairs(adds or {}) do if id~=author then print("  add by",s.players[id].name,typeText(id,"Append",text,ev)) end end
    end
    approveAll(filter)
  end
  return ev,author
end
-- 1) dictionary command: executes right after the roulette, no Thinking phase
local ev,author=runEvent("дай мне 100 военных","Execute")
print("1 phase",ev.phase,"source",ev.source,ev.effect)
step(60);local n=0;for _,u in pairs(s.units) do if u.owner==author and u.role=="Troop" then n=n+1 end end;print("  troops",n)
-- 2) unknown words: waits for the AI, AI plan executes
ev,author=runEvent("преврати врагов в ледяные статуи","Execute")
print("2 phase",ev.phase)
local job=W.thinking(s);print("  job command:",job and job.command)
W.resolve(s,job.eventId,{caption="Ледяные статуи!",actions={{type="freeze",target="enemies",seconds=30}}})
print("  ",ev.phase,ev.source,ev.outcome,(ev.effect:gsub("\n"," / ")))
-- 3) AI refuses (creepers)
ev=runEvent("заспавни пару криперов","Execute");local job2=W.thinking(s)
W.resolve(s,job2.eventId,{refused=true,reason="В игре нет криперов",actions={}});print("3",ev.outcome,ev.effect)
-- 4) AI unavailable -> dictionary best effort, unknown -> rejected
ev=runEvent("сделай всех розовыми","Execute");local job3=W.thinking(s);W.resolve(s,job3.eventId,nil);print("4",ev.outcome,ev.effect)
-- 5) roulette -> additions: author cannot add, Bob adds for himself, Carl's odd addition goes through the AI
ev,author=runEvent("метеоры на врагов","Append",{["1"]="x",["2"]="и мне дай 50 лучников",["3"]="x2"})
print("5 phase",ev.phase,ev.source,ev.outcome,(tostring(ev.effect):gsub("\n"," / ")))
-- 6) hashtags: everyone sees the filtered text, the command uses what was typed
ev=runEvent("дай мне 100 золота","Execute",nil,function(t) return (t:gsub("%d","#")) end)
print("6 shown:",ev.prompt,"| typed:",ev.rawPrompt,"|",ev.effect)
-- 7) timeout: no answer from the AI within 9 s -> built-in dictionary
ev=runEvent("метеоры на врагов пожалуйста братан","Execute");print("7 phase",ev.phase);W.thinking(s);step(160);print("  ",ev.phase,ev.source,ev.effect)
