-- Admin Shop: Robux-only purchases. Ownership, tokens and receipts are decided
-- here on the server; the client only asks to open a Roblox purchase prompt.
local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local MarketplaceService=game:GetService('MarketplaceService')
local DataStoreService=game:GetService('DataStoreService')
local ProximityPromptService=game:GetService('ProximityPromptService')
local RunService=game:GetService('RunService')
local shared=ReplicatedStorage:WaitForChild('ArmyRoundShared')
local Catalog=require(shared:WaitForChild('DonationCatalog'))
local Perks=require(script.Parent:WaitForChild('Perks'))
local remote=shared:FindFirstChild('DonationShopRemote') or Instance.new('RemoteEvent')
remote.Name='DonationShopRemote';remote.Parent=shared
local STUDIO=RunService:IsStudio()
local RECEIPT_KEEP=60
-- Unpublished Studio places cannot open DataStores; everything still works
-- there for the session so the full flow can be tested.
local store=nil
if not STUDIO then
    local ok,got=pcall(function() return DataStoreService:GetDataStore('BattleAdminVault_v2') end)
    if ok then store=got else warn('[AdminShop] DataStore unavailable: '..tostring(got)) end
end
local sessions,rate={},{}
local function retry(fn)
    local last
    for attempt=1,4 do
        local ok,value=pcall(fn);if ok then return true,value end
        last=value;task.wait(math.min(8,2^(attempt-1)+math.random()))
    end
    return false,last
end
local function blank() return {passes={},tokens={Ticket=0},tipped=0,loaded=false} end
local function readTokens(data,s)
    if type(data)=='table' and type(data.tokens)=='table' then
        for key in pairs(Catalog.Tokens) do
            local n=tonumber(data.tokens[key]);if n and n==n and n>=0 then s.tokens[key]=math.min(9999,math.floor(n)) end
        end
    end
    if type(data)=='table' and tonumber(data.tipped) then s.tipped=math.max(0,math.floor(tonumber(data.tipped))) end
end
local function key(p) return 'u:'..p.UserId end
local function isOwner(p)
    local name=string.lower(p.Name)
    for _,n in ipairs(Catalog.Owners or {}) do if string.lower(n)==name then return true end end
    for _,id in ipairs(Catalog.OwnerUserIds or {}) do if tonumber(id)==p.UserId then return true end end
    return false
end
local function save(p)
    local s=sessions[p]
    if not s or not s.loaded or not store or not s.dirty then return true end
    s.dirty=false
    local tokens={};for k,v in pairs(s.tokens) do tokens[k]=v end
    local ok,err=retry(function()
        return store:UpdateAsync(key(p),function(old)
            old=type(old)=='table' and old or {}
            -- Only the spend side is written from the session; grants are
            -- written atomically by ProcessReceipt, so never raise counts here.
            old.tokens=type(old.tokens)=='table' and old.tokens or {}
            for k,v in pairs(tokens) do old.tokens[k]=math.min(tonumber(old.tokens[k]) or 0,v) end
            old.version=2;return old
        end)
    end)
    if not ok then s.dirty=true;warn('[AdminShop] Save failed for '..p.Name..': '..tostring(err)) end
    return ok
end
Perks.persist=save
local function publicState(p,message)
    local s=sessions[p];if not s then return end
    Perks.refresh(p)
    remote:FireClient(p,'State',{passes=s.passes,tokens=s.tokens,tipped=s.tipped,studio=STUDIO,owner=s.owner==true,message=message})
end
-- Lobby-only name plate for pass owners (OWNER > ADMIN > VIP).
local PLATES={Admin={text='ADMIN',color=Color3.fromRGB(255,90,80)},VIP={text='VIP',color=Color3.fromRGB(90,230,140)}}
local FREDOKA=Font.new('rbxasset://fonts/families/FredokaOne.json',Enum.FontWeight.Bold,Enum.FontStyle.Normal)
-- Big chunky "OWNER" over the head: gold letters with an ink outline, a dark
-- drop shadow and a crown. Sized in studs so it reads like part of the world.
local function ownerPlate(folder,head)
    local tag=Instance.new('BillboardGui');tag.Name='RankTag';tag.Adornee=head;tag.Size=UDim2.new(8,0,3,0);tag.StudsOffset=Vector3.new(0,3.6,0)
    tag.MaxDistance=180;tag.AlwaysOnTop=true;tag.LightInfluence=0;tag:SetAttribute('OwnerTag',true);tag.Parent=folder
    local crown=Instance.new('TextLabel');crown.Name='Crown';crown.BackgroundTransparency=1;crown.Size=UDim2.fromScale(1,.36);crown.Text=utf8.char(0x1F451)
    crown.TextScaled=true;crown.Parent=tag
    local shadow=Instance.new('TextLabel');shadow.Name='Shadow';shadow.BackgroundTransparency=1;shadow.Position=UDim2.fromScale(.012,.4);shadow.Size=UDim2.fromScale(1,.6)
    shadow.FontFace=FREDOKA;shadow.TextScaled=true;shadow.Text='OWNER';shadow.TextColor3=Color3.fromRGB(140,40,10);shadow.Parent=tag
    local ss=Instance.new('UIStroke');ss.Color=Color3.fromRGB(34,27,20);ss.Thickness=3;ss.Parent=shadow
    local face=Instance.new('TextLabel');face.Name='Face';face.BackgroundTransparency=1;face.Position=UDim2.fromScale(0,.35);face.Size=UDim2.fromScale(1,.6)
    face.FontFace=FREDOKA;face.TextScaled=true;face.Text='OWNER';face.TextColor3=Color3.new(1,1,1);face.Parent=tag
    local fs=Instance.new('UIStroke');fs.Color=Color3.fromRGB(34,27,20);fs.Thickness=3.5;fs.Parent=face
    local shine=Instance.new('UIGradient');shine.Name='Shine';shine.Rotation=90
    shine.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,244,160)),ColorSequenceKeypoint.new(.45,Color3.fromRGB(255,204,58)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(255,120,30))})
    shine.Parent=face
end
local function cosmetic(p)
    local c=p.Character;if not c then return end
    local old=c:FindFirstChild('ShopCosmetic');if old then old:Destroy() end
    if p:GetAttribute('ScenePhase')=='Round' then return end
    local s=sessions[p]
    local head=c:FindFirstChild('Head');if not head then return end
    if s and s.owner then
        local folder=Instance.new('Folder');folder.Name='ShopCosmetic';folder.Parent=c
        ownerPlate(folder,head);return
    end
    local style=(Perks.has(p,'Admin') and PLATES.Admin) or (Perks.has(p,'VIP') and PLATES.VIP)
    if not style then return end
    local folder=Instance.new('Folder');folder.Name='ShopCosmetic';folder.Parent=c
    local tag=Instance.new('BillboardGui');tag.Name='RankTag';tag.Adornee=head;tag.Size=UDim2.fromOffset(96,26);tag.StudsOffset=Vector3.new(0,2.6,0)
    tag.MaxDistance=90;tag.AlwaysOnTop=true;tag.Parent=folder
    local plate=Instance.new('TextLabel');plate.Size=UDim2.fromScale(1,1);plate.BackgroundColor3=Color3.fromRGB(30,24,20);plate.BackgroundTransparency=.15
    plate.Font=Enum.Font.GothamBlack;plate.TextScaled=true;plate.Text=style.text;plate.TextColor3=style.color;plate.Parent=tag
    local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,6);corner.Parent=plate
    local stroke=Instance.new('UIStroke');stroke.Color=style.color;stroke.Thickness=1.5;stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Parent=plate
end
local function checkPasses(p)
    local s=sessions[p];if not s then return end
    for _,item in ipairs(Catalog.passes()) do
        if Catalog.configured(item) and not s.passes[item.key] then
            local ok,owns=pcall(function() return MarketplaceService:UserOwnsGamePassAsync(p.UserId,item.id) end)
            if ok and owns then s.passes[item.key]=true end
        end
    end
end
local function onPlayer(p)
    if sessions[p] then return end
    local s=blank();sessions[p]=s
    if store then
        local ok,data=retry(function() return store:GetAsync(key(p)) end)
        if ok then readTokens(data,s);s.loaded=true else warn('[AdminShop] Could not load '..p.Name..'; tokens are read-only this session') end
    else
        s.loaded=true
    end
    if p.Parent~=Players then sessions[p]=nil;return end
    checkPasses(p)
    if isOwner(p) then
        -- owners own every pass and get every ticket pack for free
        s.owner=true;s.passes.Owner=true
        for _,item in ipairs(Catalog.passes()) do s.passes[item.key]=true end
    end
    Perks.attach(p,s);publicState(p)
    p.CharacterAdded:Connect(function() task.wait(.4);cosmetic(p) end)
    p:GetAttributeChangedSignal('ScenePhase'):Connect(function() cosmetic(p) end)
    if p.Character then cosmetic(p) end
end
local function grantPass(p,item,message)
    local s=sessions[p];if not s then return end
    s.passes[item.key]=true;cosmetic(p);publicState(p,message or ('Unlocked '..item.title..'!'))
end
-- Studio-only simulated purchase, so every card is testable before publishing.
local function studioGrant(p,item)
    local s=sessions[p]
    if item.kind=='Pass' then return grantPass(p,item,'STUDIO TEST: '..item.title..' granted.') end
    local g=item.grant or {}
    if g.token then s.tokens[g.token]=(s.tokens[g.token] or 0)+(g.amount or 1) end
    publicState(p,'STUDIO TEST: '..item.title..' granted.')
end
-- Owners: tickets are added for free, saved atomically like a real purchase.
local function ownerGrant(p,item)
    local s=sessions[p]
    if item.kind=='Pass' then return grantPass(p,item,'OWNER: '..item.title..' - FREE!') end
    local g=item.grant or {}
    if not g.token then return publicState(p) end
    if store then
        local ok,result=pcall(function()
            return store:UpdateAsync(key(p),function(old)
                old=type(old)=='table' and old or {}
                old.tokens=type(old.tokens)=='table' and old.tokens or {}
                old.tokens[g.token]=math.min(9999,(tonumber(old.tokens[g.token]) or 0)+(g.amount or 1))
                old.version=2;return old
            end)
        end)
        if not ok or type(result)~='table' then return publicState(p,'Could not save, try again.') end
        local before={};for k,v in pairs(s.tokens) do before[k]=v end
        readTokens(result,s)
        if s.dirty then s.tokens[g.token]=math.min(s.tokens[g.token],(before[g.token] or 0)+(g.amount or 1)) end
        s.loaded=true
    else
        s.tokens[g.token]=math.min(9999,(s.tokens[g.token] or 0)+(g.amount or 1))
    end
    publicState(p,'OWNER: '..item.title..' - FREE!')
end
remote.OnServerEvent:Connect(function(p,op,itemKey)
    local s=sessions[p];if not s or type(op)~='string' then return end
    local now=os.clock();if now-(rate[p] or 0)<.25 then return end;rate[p]=now
    if op=='State' then return publicState(p) end
    if op~='Buy' then return end
    local item=Catalog.get(itemKey);if not item then return publicState(p,'Unknown item.') end
    if item.kind=='Pass' and s.passes[item.key] then return publicState(p,'You already own '..item.title..'.') end
    if s.owner then return ownerGrant(p,item) end
    if not Catalog.configured(item) then
        if STUDIO then return studioGrant(p,item) end
        return publicState(p,item.title..' is coming soon!')
    end
    if item.kind=='Pass' then MarketplaceService:PromptGamePassPurchase(p,item.id)
    else MarketplaceService:PromptProductPurchase(p,item.id) end
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt,p)
    if prompt.Name=='DonationShopPrompt' and sessions[p] then remote:FireClient(p,'Open') end
end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p,passId,purchased)
    if not purchased or not sessions[p] then return end
    local item=Catalog.byPass(passId);if not item then return end
    task.spawn(function()
        local ok,owns=pcall(function() return MarketplaceService:UserOwnsGamePassAsync(p.UserId,passId) end)
        -- A fresh purchase can take a moment to show up; the prompt result is authoritative for this session.
        if (ok and owns) or purchased then grantPass(p,item) end
    end)
end)
-- Developer products: grant exactly once per PurchaseId, atomically with the
-- player's saved token balance.
MarketplaceService.ProcessReceipt=function(receipt)
    local item=Catalog.byProduct(receipt.ProductId)
    if not item then return Enum.ProductPurchaseDecision.NotProcessedYet end
    local p=Players:GetPlayerByUserId(receipt.PlayerId)
    local s=p and sessions[p]
    if not p or not s then return Enum.ProductPurchaseDecision.NotProcessedYet end
    local g=item.grant or {}
    if store then
        local ok,result=pcall(function()
            return store:UpdateAsync('u:'..receipt.PlayerId,function(old)
                old=type(old)=='table' and old or {}
                old.receipts=type(old.receipts)=='table' and old.receipts or {}
                if old.receipts[receipt.PurchaseId] then return old end
                old.tokens=type(old.tokens)=='table' and old.tokens or {}
                if g.token then old.tokens[g.token]=(tonumber(old.tokens[g.token]) or 0)+(g.amount or 1) end
                if g.tip then old.tipped=(tonumber(old.tipped) or 0)+g.tip end
                old.receipts[receipt.PurchaseId]=os.time()
                -- keep the receipt list bounded
                local ids={};for id,at in pairs(old.receipts) do ids[#ids+1]={id=id,at=tonumber(at) or 0} end
                if #ids>RECEIPT_KEEP then
                    table.sort(ids,function(a,b) return a.at<b.at end)
                    for i=1,#ids-RECEIPT_KEEP do old.receipts[ids[i].id]=nil end
                end
                old.version=2;return old
            end)
        end)
        if not ok or type(result)~='table' then
            warn('[AdminShop] Receipt deferred: '..tostring(result));return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        -- Spent-but-unsaved tokens stay spent: never raise above the session's spend.
        local before={};for k,v in pairs(s.tokens) do before[k]=v end
        readTokens(result,s)
        if g.token and s.dirty then s.tokens[g.token]=math.min(s.tokens[g.token],(before[g.token] or 0)+(g.amount or 1)) end
        s.loaded=true
    else
        if g.token then s.tokens[g.token]=(s.tokens[g.token] or 0)+(g.amount or 1) end
        if g.tip then s.tipped=s.tipped+g.tip end
    end
    publicState(p,'Thank you! '..item.title..' delivered.')
    return Enum.ProductPurchaseDecision.PurchaseGranted
end
Players.PlayerAdded:Connect(onPlayer)
Players.PlayerRemoving:Connect(function(p)
    save(p);Perks.detach(p);sessions[p]=nil;rate[p]=nil
end)
for _,p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer,p) end
game:BindToClose(function()
    if STUDIO then return end
    local pending=0
    for _,p in ipairs(Players:GetPlayers()) do
        pending+=1;task.spawn(function() save(p);pending-=1 end)
    end
    local started=os.clock()
    while pending>0 and os.clock()-started<20 do task.wait(.2) end
end)
