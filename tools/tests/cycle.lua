local Data=__req("RoundData");local State=__req("RoundState");local Bots=__req("RoundBots");local W=__req("WishRules")
local uids={"-1","-2","-3"};local layouts={}
for i,uid in ipairs(uids) do local L={lands={},buildings={},nodes={}}
 for n,d in pairs(Data.Lands) do L.lands[n]={x=d.pos.x+i*300,y=d.pos.y,z=d.pos.z} end
 for k,d in pairs(Data.Buildings) do L.buildings[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 for k,d in pairs(Data.ResourceNodes) do L.nodes[k]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
 layouts[uid]=L end
local s=State.new(Data,layouts,{},{},{names={["-1"]="Bot1",["-2"]="Bot2",["-3"]="Bot3"},bots={["-1"]=true,["-2"]=true,["-3"]=true},colors={}})
local B=Bots.attach(s,{{UserId=-1,IsBot=true},{UserId=-2,IsBot=true},{UserId=-3,IsBot=true}},State)
local seen,done={},{}
for i=1,9000 do State.step(s,.1);Bots.step(B,.1);s.fx={}
 for _,j in ipairs(W.pending(s)) do W.approve(s,j.uid,j.eventId,j.phase,j.text) end
 local e=s.wish.event
 if e and e.phase=="Applied" and not done[e.id] then done[e.id]=true;print(math.floor(s.elapsed),e.id,e.outcome,e.finalPrompt or e.prompt,"=>",(tostring(e.effect):gsub("\n"," / "))) end
end
print("events",#(function() local t={} for k in pairs(done) do t[#t+1]=k end return t end)(),"status",s.status)
