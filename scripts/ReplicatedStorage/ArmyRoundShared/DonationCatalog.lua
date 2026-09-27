-- Robux-only catalog for the Admin Vault.
--
-- HOW TO CONNECT REAL PRODUCTS
--   1. Creator Dashboard -> your experience -> Monetization -> Passes: create one
--      Game Pass per entry with kind='Pass' and paste its ID into `id` below.
--   2. Monetization -> Developer Products: create one product per entry with
--      kind='Product' and paste its ID into `id`.
--   3. `price` is only a label shown while Roblox has not answered yet; the real
--      price is read from Roblox (MarketplaceService:GetProductInfo).
-- While an id is 0 the item is shown as "SOON" in live servers. In Studio every
-- item can be test-granted so the whole flow can be tried without publishing.
local Catalog={}
Catalog.Version=2
Catalog.Tabs={
    {id='Powers',title='ADMIN POWERS'},
    {id='Boosts',title='ROUND BOOSTS'},
    {id='Support',title='SUPPORT'},
}
Catalog.Items={
    -- Permanent game passes ------------------------------------------------
    {key='AdminPass',kind='Pass',tab='Powers',id=0,price=399,icon='Crown',color=Color3.fromRGB(255,204,58),
        title='ADMIN PASS',detail='You are picked first for the Admin Panel and get +1 admin turn every round. Gold [ADMIN] chat tag and crown aura.',badge='BEST'},
    {key='RiggedRoulette',kind='Pass',tab='Powers',id=0,price=249,icon='Dice',color=Color3.fromRGB(147,72,213),
        title='RIGGED ROULETTE',detail='When the roulette spins for YOUR command it lands on EXECUTE 75% of the time.'},
    {key='VetoPower',kind='Pass',tab='Powers',id=0,price=199,icon='Veto',color=Color3.fromRGB(226,35,31),
        title='VETO POWER',detail='Once per round, cancel another player\'s admin command before it executes.'},
    {key='OvertimePen',kind='Pass',tab='Powers',id=0,price=99,icon='Hourglass',color=Color3.fromRGB(52,158,216),
        title='OVERTIME PEN',detail='+10 seconds to type your admin command.'},
    {key='MasterBuilder',kind='Pass',tab='Powers',id=0,price=149,icon='Hammer',color=Color3.fromRGB(64,192,29),
        title='MASTER BUILDER',detail='+1 builder in every round: upgrade one more building at the same time.'},
    {key='StarterCrate',kind='Pass',tab='Powers',id=0,price=129,icon='Crate',color=Color3.fromRGB(214,148,24),
        title='STARTER CRATE',detail='Every round starts with 60 Wood, 30 Stone and 5 Gold.'},
    -- Consumable developer products -----------------------------------------
    {key='AdminToken',kind='Product',tab='Boosts',id=0,price=49,icon='Token',color=Color3.fromRGB(255,204,58),
        grant={token='AdminToken',amount=1},title='ADMIN TOKEN',detail='Open the Admin Panel for yourself right now in a round. Unused tokens are saved.'},
    {key='AdminToken5',kind='Product',tab='Boosts',id=0,price=199,icon='Tokens',color=Color3.fromRGB(255,170,40),
        grant={token='AdminToken',amount=5},title='5 ADMIN TOKENS',detail='Five Admin Panel turns. Saved until you use them.',badge='-20%'},
    {key='SupplyDrop',kind='Product',tab='Boosts',id=0,price=35,icon='Drop',color=Color3.fromRGB(64,192,29),
        grant={token='SupplyDrop',amount=1},title='SUPPLY DROP',detail='150 Wood, 80 Stone and 10 Gold delivered to your island during a round.'},
    -- Pure support ---------------------------------------------------------
    {key='TipSmall',kind='Product',tab='Support',id=0,price=25,icon='Heart',color=Color3.fromRGB(255,110,150),
        grant={tip=25},title='THANK YOU!',detail='A small tip for the developer. Everyone in the server sees your support.'},
    {key='TipMedium',kind='Product',tab='Support',id=0,price=100,icon='Hearts',color=Color3.fromRGB(255,80,120),
        grant={tip=100},title='BIG THANKS!',detail='A generous tip. You get a golden shout-out in the harbour.'},
    {key='TipLarge',kind='Product',tab='Support',id=0,price=500,icon='Chest',color=Color3.fromRGB(255,204,58),
        grant={tip=500},title='LEGENDARY PATRON',detail='The biggest tip. Fireworks over the harbour for everyone!'},
}
Catalog.Tokens={AdminToken=true,SupplyDrop=true}
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
return Catalog
