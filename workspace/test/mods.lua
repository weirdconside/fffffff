local Data=__req("RoundData");local State=__req("RoundState");local C=__req("AdminCommands")
local layouts={}
for i,uid in ipairs({"1","2","3"}) do local L={lands={},buildings={},nodes={}}
 for n,d in pairs(Data.Lands) do L.lands[n]={x=d.pos.x+i*300,y=d.pos.y,z=d.pos.z} end
 for k,d in pairs(Data.Buildings) do L.buildings[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 for k,d in pairs(Data.ResourceNodes) do L.nodes[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 layouts[uid]=L end
local s=State.new(Data,layouts,{},{},{names={["1"]="Alice",["2"]="Bob",["3"]="Carl"},bots={},colors={}})
local function show(base,adds)
  local e={recipient="1",prompt=base,rawPrompt=base,additions=adds or {},rawAdditions={}}
  local p=C.plan(s,e,true)
  local out={}
  for _,a in ipairs(p and p.actions or {}) do out[#out+1]=a.type..":"..tostring(a.target)..(a.count and ("#"..a.count) or "")..(a.percent and ("%"..a.percent) or "")..(a.seconds and ("s"..a.seconds) or "")..(a.power and ("p"..a.power) or "") end
  print(base,"|",adds and (adds["2"] or "") or "","->",p and table.concat(out,", ") or "AI",p and p.cancelled and "CANCELLED" or "")
end
show("заморозь врагов и метеоры на Bob")
show("метеоры на врагов",{["2"]="x10"})
show("метеоры на врагов",{["2"]="в половину силы"})
show("заморозь врагов",{["2"]="на 5 секунд"})
show("метеоры на врагов",{["2"]="но по автору"})
show("метеоры на врагов",{["2"]="но по мне"})
show("дай мне 100 военных",{["2"]="отмена"})
show("дай мне 100 военных",{["2"]="и мне дай 50 лучников"})
show("give me 100 soldiers",{["2"]="but it hits the author"})
show("give me 100 soldiers",{["2"]="and give me 20 giants"})
