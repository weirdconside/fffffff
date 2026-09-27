-- Server-only perk registry shared by DonationServer (ownership/persistence)
-- and RoundServer (round effects). Clients only ever see mirrored attributes.
local Perks={}
local sessions={}
Perks.persist=nil -- set by DonationServer: function(player) that saves the session
local function mirror(player,s)
    for key in pairs(s.passes) do player:SetAttribute('Perk_'..key,s.passes[key]==true) end
    for key,count in pairs(s.tokens) do player:SetAttribute('Token_'..key,count) end
end
function Perks.attach(player,session)
    sessions[player]=session;mirror(player,session)
end
function Perks.detach(player) sessions[player]=nil end
function Perks.session(player) return sessions[player] end
function Perks.refresh(player) local s=sessions[player];if s then mirror(player,s) end end
function Perks.has(player,key)
    local s=sessions[player];return s~=nil and s.passes[key]==true
end
function Perks.tokens(player,key)
    local s=sessions[player];return s and (s.tokens[key] or 0) or 0
end
-- Spend one token. The caller must already have checked that the effect can
-- be applied, so a token is never lost to an impossible action.
function Perks.consume(player,key)
    local s=sessions[player]
    if not s or not s.loaded or (s.tokens[key] or 0)<1 then return false end
    s.tokens[key]=s.tokens[key]-1;s.dirty=true;mirror(player,s)
    if Perks.persist then task.spawn(Perks.persist,player) end
    return true
end
-- Plain table of passes for the deterministic round simulation.
function Perks.snapshot(player)
    local s=sessions[player];local out={}
    if s then for key,owned in pairs(s.passes) do if owned then out[key]=true end end end
    return out
end
return Perks
