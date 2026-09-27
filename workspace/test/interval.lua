local Data=__req("RoundData");local State=__req("RoundState");local Bots=__req("RoundBots");local W=__req("WishRules")
local uids={"-1","-2"};local layouts={}
for i,uid in ipairs(uids) do local L={lands={},buildings={},nodes={}}
 for n,d in pairs(Data.Lands) do L.lands[n]={x=d.pos.x+i*300,y=d.pos.y,z=d.pos.z} end
 for k,d in pairs(Data.Buildings) do L.buildings[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 for k,d in pairs(Data.ResourceNodes) do L.nodes[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 layouts[uid]=L end
local s=State.new(Data,layouts,{},{},{names={},bots={["-1"]=true,["-2"]=true},colors={}})
local B=Bots.attach(s,{{UserId=-1,IsBot=true},{UserId=-2,IsBot=true}},State)
local seen={}
for i=1,8000 do State.step(s,.1);Bots.step(B,.1);for _,j in ipairs(W.pending(s)) do W.approve(s,j.uid,j.eventId,j.phase,j.text) end
 local e=s.wish.event;if e and not seen[e.id] then seen[e.id]=true;print("event",e.id,"starts at",math.floor(s.elapsed)) end end
