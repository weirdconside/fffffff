local Data=__req("RoundData");local State=__req("RoundState");local C=__req("AdminCommands");local A=__req("AdminActions")
local layouts={}
for i,uid in ipairs({"1","2"}) do local L={lands={},buildings={},nodes={}}
 for n,d in pairs(Data.Lands) do L.lands[n]={x=d.pos.x+i*300,y=d.pos.y,z=d.pos.z} end
 for k,d in pairs(Data.Buildings) do L.buildings[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 for k,d in pairs(Data.ResourceNodes) do L.nodes[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 layouts[uid]=L end
local s=State.new(Data,layouts,{},{},{names={["1"]="Alice",["2"]="Bob"},bots={},colors={}})
local function run(t,adds)
  local e={id=t,recipient="1",prompt=t,rawPrompt=t,additions=adds or {},rawAdditions={},phase="Test",deadline=math.huge,started=0}
  s.wish.event=e
  local ok,msg=A.execute(s,e,C.plan(s,e,true))
  return ok,msg
end
local p=s.players["1"]
local function lands() local n,t=0,0;for _ in pairs(p.cleared) do n+=1 end;for _ in pairs(Data.Lands) do t+=1 end;return n.."/"..t end
print("lands at start",lands())
print(run("открой мне все учатски базы"));print("lands now",lands(),"bridge",p.bridge)
print(run("дай мне безлимит всех ресурсов"))
local r={};for _,k in ipairs(A.Resources) do r[#r+1]=k.."="..math.floor(p.resources[k] or 0) end;print(table.concat(r," "))
local b=s.players["2"]
print(run("дай Bob золото"));print("Bob gold (default)",b.resources.Gold)
print(run("дай Bob золото",{["2"]="x10"}));print("Bob gold after x10 addition",b.resources.Gold)
print(run("улучши все здания"));local lv={};for _,bb in pairs(p.buildings) do lv[#lv+1]=bb.kind..bb.level end;table.sort(lv);print(table.concat(lv," "))
print(run("усиль мою армию"));print("army boost x",p.armyBoostStrength,"for",math.floor(p.armyBoostUntil-s.elapsed),"s")
print(run("усиль мою армию в 100 раз"));print("army boost x",p.armyBoostStrength)
print(run("призови армию"))
