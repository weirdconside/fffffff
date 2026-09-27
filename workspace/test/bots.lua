local Data=__req("RoundData");local State=__req("RoundState");local Bots=__req("RoundBots");local W=__req("WishRules")
local seed=777
local function rng() seed=(seed*1103515245+12345)%2147483648;return seed/2147483648 end
local uids={"-1","-2","-3","-4"};local layouts={}
for i,uid in ipairs(uids) do
    local ox=i*300;local L={lands={},buildings={},nodes={}}
    for name,d in pairs(Data.Lands) do L.lands[name]={x=d.pos.x+ox,y=d.pos.y+0.5,z=d.pos.z} end
    for key,d in pairs(Data.Buildings) do L.buildings[key]={x=d.pos.x+ox,y=L.lands[d.land].y,z=d.pos.z} end
    for key,d in pairs(Data.ResourceNodes) do L.nodes[key]={x=d.pos.x+ox,y=L.lands[d.land].y,z=d.pos.z} end
    layouts[uid]=L
end
local bots={};for _,u in ipairs(uids) do bots[u]=true end
local s=State.new(Data,layouts,{},{},{names={},bots=bots,colors={},perks={},rng=rng})
local roster={};for _,u in ipairs(uids) do roster[#roster+1]={UserId=tonumber(u),IsBot=true} end
local B=Bots.attach(s,roster,State)
local seen={}
for i=1,20000 do
    State.step(s,0.1);Bots.step(B,0.1)
    for _,job in ipairs(W.pending(s)) do W.approve(s,job.uid,job.eventId,job.phase,job.text) end
    local e=s.wish.event
    if e and e.phase=="Applied" and not seen[e.id] then seen[e.id]=true;print(math.floor(s.elapsed),e.recipient,e.finalPrompt,"=>",e.outcome,e.effect) end
end
for _,uid in ipairs(uids) do local p=s.players[uid];local lv=0;for _,b in pairs(p.buildings) do lv=lv+b.level end;print(uid,"levels",lv) end
