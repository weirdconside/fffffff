local Data=__req("RoundData");local State=__req("RoundState");local Bots=__req("RoundBots");local W=__req("WishRules")
local seed=7
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
local uids={"-1","-2","-3","-4","-5","-6"}
local bots={};for _,u in ipairs(uids) do bots[u]=true end
local s=State.new(Data,layouts(uids),{},{},{names={},bots=bots,colors={},rng=rng})
local list={};for _,u in ipairs(uids) do list[#list+1]={UserId=tonumber(u),IsBot=true} end
local B=Bots.attach(s,list,State)
local function size(v,depth)
    depth=depth or 0
    local t=type(v)
    if t=="table" then local n=2;for k,x in pairs(v) do n=n+size(k,depth+1)+size(x,depth+1)+1 end;return n
    elseif t=="string" then return #v+2 elseif t=="number" then return 8 elseif t=="boolean" then return 1 end
    return 4
end
for minute=1,6 do
    for _=1,600 do State.step(s,0.1);Bots.step(B,0.1);for _,j in ipairs(W.pending(s)) do W.approve(s,j.uid,j.eventId,j.phase,j.text) end end
    local snap=State.snapshot(s,"-1")
    local units=0;for _ in pairs(s.units) do units=units+1 end
    local parts={}
    for k,v in pairs(snap) do parts[#parts+1]={k,size(v)} end
    table.sort(parts,function(a,b) return a[2]>b[2] end)
    local top="";for i=1,math.min(4,#parts) do top=top..parts[i][1].."="..parts[i][2].." " end
    print("min",minute,"units",units,"snapshot bytes~",size(snap),top)
end
