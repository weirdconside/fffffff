local Data=__req("RoundData");local State=__req("RoundState");local C=__req("AdminCommands")
local layouts={}
for i,uid in ipairs({"1","2"}) do local L={lands={},buildings={},nodes={}}
 for n,d in pairs(Data.Lands) do L.lands[n]={x=d.pos.x+i*300,y=d.pos.y,z=d.pos.z} end
 for k,d in pairs(Data.Buildings) do L.buildings[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 for k,d in pairs(Data.ResourceNodes) do L.nodes[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 layouts[uid]=L end
local s=State.new(Data,layouts,{},{},{names={["1"]="Alice",["2"]="Bob"},bots={},colors={}})
for _,t in ipairs(QUERIES) do
  local e={recipient="1",prompt=t,rawPrompt=t,additions={}}
  local p=C.plan(s,e,true);local q=p or C.plan(s,e,false)
  local out={}
  for _,a in ipairs(q and q.actions or {}) do local f={a.type};for k,v in pairs(a) do if k~="type" then f[#f+1]=k.."="..tostring(v) end end;out[#out+1]=table.concat(f," ") end
  print(p and "INSTANT" or "AI    ",t,"->",table.concat(out," | "),q and q.refused and "REFUSED" or "")
end
