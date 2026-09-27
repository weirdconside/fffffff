local Data=__req("RoundData");local State=__req("RoundState");local C=__req("AdminCommands")
local layouts={}
for i,uid in ipairs({"1","2"}) do local L={lands={},buildings={},nodes={}}
 for n,d in pairs(Data.Lands) do L.lands[n]={x=d.pos.x+i*300,y=d.pos.y,z=d.pos.z} end
 for k,d in pairs(Data.Buildings) do L.buildings[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 for k,d in pairs(Data.ResourceNodes) do L.nodes[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 layouts[uid]=L end
local s=State.new(Data,layouts,{},{},{names={["1"]="Alice",["2"]="Bob"},bots={},colors={}})
for _,t in ipairs({{"скажи всем что я король","скажи всем что я король"},{"say I am the king","say I am the king"},{"объяви что Bob нуб","объяви что Bob ###"},{"Дай Мне 100 Военных","Дай Мне 100 Военных"},{"МЕТЕОРЫ НА ВРАГОВ","МЕТЕОРЫ НА ВРАГОВ"}}) do
  local e={recipient="1",prompt=t[2],rawPrompt=t[1],additions={}}
  local p=C.plan(s,e,true)
  print(t[1],"->",p and p.actions[1].type,p and (p.actions[1].text or p.actions[1].count or p.actions[1].target))
end
