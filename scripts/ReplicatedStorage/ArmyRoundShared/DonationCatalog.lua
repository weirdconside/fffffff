-- Robux-only shop catalog.
--
-- HOW TO CONNECT REAL PRODUCTS
--   Creator Dashboard -> your experience -> Monetization:
--   * Passes: create "VIP" and "ADMIN" and paste their IDs into `id` below.
--   * Developer Products: create the five ticket packs and paste their IDs.
--   `price` is only shown until Roblox returns the real price.
-- While an id is 0 the item shows "SOON" in live servers; in Studio it can be
-- test-bought so the whole flow can be tried without publishing.
local Catalog={}
Catalog.Version=3
-- Round rules for the passes (used by RoundState / WishRules).
Catalog.Rules={
    VipRoundTickets=1,      -- free tickets every round for VIP
    AdminRoundTickets=10,   -- free tickets every round for ADMIN
    AdminChanceBonus=.20,   -- ADMIN: +20% weight in the admin panel random pick
}
Catalog.Items={
    {key='VIP',kind='Pass',id=0,price=299,icon='Crown',color=Color3.fromRGB(64,200,120),accent=Color3.fromRGB(255,214,74),
        title='VIP',perks={'ALWAYS gets the FIRST admin panel','+1 ticket every round','[VIP] tag in chat and over your head'}},
    {key='Admin',kind='Pass',id=0,price=999,icon='Gavel',color=Color3.fromRGB(226,52,48),accent=Color3.fromRGB(255,214,74),
        title='ADMIN',perks={'+10 tickets every round','+20% chance to get the admin panel','[ADMIN] tag in chat and over your head'},badge='BEST'},
    {key='Ticket1',kind='Product',id=0,price=25,icon='Ticket',count=1,grant={token='Ticket',amount=1},title='1 TICKET'},
    {key='Ticket3',kind='Product',id=0,price=69,icon='Ticket',count=3,grant={token='Ticket',amount=3},title='3 TICKETS'},
    {key='Ticket7',kind='Product',id=0,price=149,icon='Ticket',count=7,grant={token='Ticket',amount=7},title='7 TICKETS',badge='POPULAR'},
    {key='Ticket10',kind='Product',id=0,price=199,icon='Ticket',count=10,grant={token='Ticket',amount=10},title='10 TICKETS'},
    {key='Ticket20',kind='Product',id=0,price=349,icon='Ticket',count=20,grant={token='Ticket',amount=20},title='20 TICKETS',badge='BEST VALUE'},
}
Catalog.Tokens={Ticket=true}
-- Game owners: an OWNER tag over the head and the whole shop for free.
-- Usernames are matched case-insensitively. For extra safety you can also
-- list their numeric UserIds (a username can be renamed, a UserId never changes).
Catalog.Owners={'zoy0m','mm2garry'}
Catalog.OwnerUserIds={}
Catalog.TicketHelp='A ticket opens the admin panel for YOU right now in a round (or right after the current one).'
local byKey,byPass,byProduct={},{},{}
for index,item in ipairs(Catalog.Items) do
    item.order=index;byKey[item.key]=item
    local id=tonumber(item.id) or 0
    if id>0 then if item.kind=='Pass' then byPass[id]=item else byProduct[id]=item end end
end
function Catalog.get(key) return type(key)=='string' and byKey[key] or nil end
function Catalog.list() return Catalog.Items end
function Catalog.isValid(key) return byKey[key]~=nil end
function Catalog.configured(item) return item~=nil and (tonumber(item.id) or 0)>0 end
function Catalog.byPass(id) return byPass[tonumber(id) or -1] end
function Catalog.byProduct(id) return byProduct[tonumber(id) or -1] end
function Catalog.passes()
    local out={};for _,item in ipairs(Catalog.Items) do if item.kind=='Pass' then out[#out+1]=item end end;return out
end
function Catalog.tickets()
    local out={};for _,item in ipairs(Catalog.Items) do if item.kind=='Product' then out[#out+1]=item end end;return out
end
return Catalog
