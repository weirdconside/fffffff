local Data=__req("RoundData");local State=__req("RoundState");local Bots=__req("RoundBots");local W=__req("WishRules")
local seed=4242
local function rng() seed=(seed*1103515245+12345)%2147483648;return seed/2147483648 end
local function layouts(uids)
    local out={}
    for i,uid in ipairs(uids) do
        local L={lands={},buildings={},nodes={}}
        for name,d in pairs(Data.Lands) do L.lands[name]={x=d.pos.x+i*300,y=d.pos.y,z=d.pos.z} end
        for key,d in pairs(Data.Buildings) do L.buildings[key]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
        for key,d in pairs(Data.ResourceNodes) do L.nodes[key]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
        out[uid]=L
    end
    return out
end
local uids={"1","2","3","-1"}
local s=State.new(Data,layouts(uids),{},{},{names={["1"]="Vip",["2"]="Admin",["3"]="Plain",["-1"]="Bot"},bots={["-1"]=true},colors={},
    perks={["1"]={VIP=true},["2"]={Admin=true}},tickets={["1"]=1,["2"]=10},rng=rng})
local B=Bots.attach(s,{{UserId=1},{UserId=2},{UserId=3},{UserId=-1,IsBot=true}},State)
local function tick(n) for _=1,n do State.step(s,0.1);Bots.step(B,0.1);for _,j in ipairs(W.pending(s)) do W.approve(s,j.uid,j.eventId,j.phase,j.text) end end end
-- first timer panel must be VIP
local snap=State.snapshot(s,"3");print("nextIn at start",snap.wish.nextIn)
while not s.wish.event do tick(1) end
print("first panel at",math.floor(s.elapsed),"goes to",s.wish.event.recipient);assert(s.wish.event.recipient=="1")
-- ticket while an event runs -> queued
print("admin ticket:",State.spendRoundTicket(s,"2"),State.useTicket(s,"2"));assert(W.queuePosition(s,"2")==1)
print("second ticket same player:",State.useTicket(s,"2"))
local firstId=s.wish.event.id
while s.wish.event and s.wish.event.id==firstId do tick(1) end
while not s.wish.event do tick(1) end
print("next panel",s.wish.event.recipient,"ticket",s.wish.event.ticket);assert(s.wish.event.recipient=="2" and s.wish.event.ticket)
print("round tickets left:",State.roundTickets(s,"2"),State.roundTickets(s,"1"))
-- weighted pick distribution (after the first)
s.wish.firstDone=true
local count={}
for i=1,20000 do local id=W.pickForTest(s);count[id]=(count[id] or 0)+1 end
for _,u in ipairs(uids) do print("pick",u,count[u]) end
print("admin/plain ratio",count["2"]/count["3"])
tick(3000)
print("events so far",s.wish.nextId,"t",math.floor(s.elapsed))
