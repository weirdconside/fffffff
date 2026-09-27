-- Stable room membership. Before Create, the first entrant owns a private selector.
local Queue={}
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
function Queue.ordered(room)
    local out={};for p in pairs(room.queued) do out[#out+1]=p end
    table.sort(out,function(a,b)return (room.order[a] or math.huge)<(room.order[b] or math.huge) end);return out
end
function Queue.host(room)
    if room.host and room.queued[room.host] then return false end
    local old=room.host;room.host=Queue.ordered(room)[1]
    if not room.host then room.capacity=nil;room.remaining=nil end
    return old~=room.host
end
function Queue.remove(room,p)
    if not room.queued[p] then return false end
    room.queued[p]=nil;room.order[p]=nil;Queue.host(room);return true
end
function Queue.reconcile(room,candidates,maxPlayers)
    local present={};for _,p in ipairs(candidates) do present[p]=true end
    local departed,rejected={},{}
    for p in pairs(room.queued) do if not present[p] then room.queued[p]=nil;room.order[p]=nil;departed[#departed+1]=p end end
    Queue.host(room)
    local n=count(room.queued);local cap=room.capacity or 1
    for _,p in ipairs(candidates) do if not room.queued[p] then
        if not room.busy and n<math.min(cap,maxPlayers) then
            room.joinSerial=(room.joinSerial or 0)+1;room.queued[p]=true;room.order[p]=room.joinSerial;n=n+1
        else rejected[#rejected+1]=p end
    end end
    Queue.host(room);return departed,rejected
end
function Queue.configure(room,p,cap,maxPlayers,seconds)
    if room.busy or room.host~=p or not room.queued[p] then return false,'Only the room owner can create this room.' end
    if room.capacity then return false,'This room has already been created.' end
    if type(cap)~='number' or cap~=cap or cap%1~=0 or cap<1 or cap>maxPlayers then return false,'Choose between 1 and 6 players.' end
    if count(room.queued)~=1 then return false,'Room selection is private.' end
    room.capacity=cap;room.remaining=seconds;return true
end
function Queue.advance(room,dt,seconds)
    if not room.host or not room.capacity then room.remaining=nil;return nil end
    -- Waiting cabins tick at half speed; a full cabin launches five times faster.
    -- The countdown remains deterministic even when a player steps out.
    local rate=count(room.queued)>=room.capacity and 5 or .5
    room.remaining=math.max(0,(room.remaining or seconds)-math.max(0,dt)*rate)
    if room.remaining==0 then
        local group=Queue.ordered(room)
        if #group>room.capacity then
            while #group>room.capacity do table.remove(group) end
        end
        return group
    end
end
return Queue
