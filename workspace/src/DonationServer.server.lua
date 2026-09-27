-- Server-authoritative cosmetic entitlements. No prices or client-side grants live here.
local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local MarketplaceService=game:GetService('MarketplaceService')
local DataStoreService=game:GetService('DataStoreService')
local ProximityPromptService=game:GetService('ProximityPromptService')
local RunService=game:GetService('RunService')
local shared=ReplicatedStorage:WaitForChild('ArmyRoundShared')
local Catalog=require(shared:WaitForChild('DonationCatalog'))
local remote=shared:FindFirstChild('DonationShopRemote') or Instance.new('RemoteEvent')
remote.Name='DonationShopRemote';remote.Parent=shared
-- Studio places that are not published are forbidden from opening a
-- DataStore.  Keep the shop fully usable in Studio (preview/equip are local
-- test cosmetics) while enabling persistence automatically in a published
-- server.  The pcall also protects a published place when API access is
-- temporarily disabled.
local store=nil
if not RunService:IsStudio() then
 local ok,got=pcall(function()return DataStoreService:GetDataStore('BattleAdminCosmetics_v1')end)
 if ok then store=got end
end
local sessions={};local rate={}
local function retry(fn)
 local last
 for i=1,4 do local ok,v=pcall(fn);if ok then return true,v end;last=v;task.wait(math.min(8,2^(i-1)+math.random())) end
 return false,last
end
local function cleanOwned(value)
 local out={};if type(value)=='table' and type(value.owned)=='table' then for id,v in pairs(value.owned) do if Catalog.isValid(id) and v==true then out[id]=true end end end
 return out
end
local function save(p,s)
 if not s.loaded or not store then return false end
 local payload={owned=s.owned,equipped=s.equipped,version=1}
 retry(function()return store:UpdateAsync('u:'..p.UserId,function(old)old=type(old)=='table' and old or {};old.owned=payload.owned;old.equipped=payload.equipped;old.version=1;return old end)end)
end
local function loadedEquipped(value)
 if type(value)=='table' and Catalog.isValid(value.equipped) then return value.equipped end
 return nil
end
local function attributes(p,s)
 for _,item in ipairs(Catalog.list()) do p:SetAttribute('DonationOwned_'..item.id,s.owned[item.id]==true) end
 p:SetAttribute('DonationEquipped',s.equipped or '')
 p:SetAttribute('DonationPreview',s.preview or '')
end
local function state(p,msg)
 local s=sessions[p];if not s then return end;attributes(p,s);remote:FireClient(p,'State',{owned=s.owned,equipped=s.equipped,preview=s.preview,message=msg})
end
local function clearCosmetic(p)
 local c=p.Character;local old=c and c:FindFirstChild('BattleDonationCosmetic');if old then old:Destroy()end
end
local function apply(p,id,isPreview)
 clearCosmetic(p);local item=Catalog.get(id);if not item then return false end;local c=p.Character;if not c then return false end
 local root=c:FindFirstChild('HumanoidRootPart');local head=c:FindFirstChild('Head');if not root or not head then return false end
 local folder=Instance.new('Folder');folder.Name='BattleDonationCosmetic';folder.Parent=c
 if item.kind=='Trail' then
  local a=Instance.new('Attachment');a.Name='TrailTop';a.Position=Vector3.new(0,1.3,0);a.Parent=root
  local b=Instance.new('Attachment');b.Name='TrailBottom';b.Position=Vector3.new(0,-1.3,0);b.Parent=root
  local trail=Instance.new('Trail');trail.Name=item.id;trail.Attachment0=a;trail.Attachment1=b;trail.Lifetime=.65;trail.MinLength=.1;trail.LightEmission=.6;trail.WidthScale=NumberSequence.new(1);trail.Color=ColorSequence.new(item.colors[1],item.colors[2] or item.colors[1]);trail.Parent=folder
 elseif item.kind=='Aura' then
  local glow=Instance.new('Highlight');glow.Name=item.id;glow.Adornee=c;glow.FillColor=item.color;glow.OutlineColor=item.color;glow.FillTransparency=.82;glow.OutlineTransparency=.08;glow.DepthMode=Enum.HighlightDepthMode.Occluded;glow.Parent=folder
 elseif item.kind=='NameTag' then
  local gui=Instance.new('BillboardGui');gui.Name=item.id;gui.Size=UDim2.fromOffset(180,34);gui.StudsOffset=Vector3.new(0,3.2,0);gui.AlwaysOnTop=true;gui.MaxDistance=100;gui.Parent=folder;gui.Adornee=head
  local label=Instance.new('TextLabel');label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1;label.Font=Enum.Font.Legacy;label.Text=item.title;label.TextColor3=item.color;label.TextStrokeColor3=Color3.new(0,0,0);label.TextStrokeTransparency=0;label.TextScaled=true;label.Parent=gui
 elseif item.kind=='Banner' then
  local gui=Instance.new('BillboardGui');gui.Name=item.id;gui.Size=UDim2.fromOffset(170,46);gui.StudsOffset=Vector3.new(0,1.2,0);gui.AlwaysOnTop=false;gui.MaxDistance=85;gui.Parent=folder;gui.Adornee=root
  local label=Instance.new('TextLabel');label.Size=UDim2.fromScale(1,1);label.BackgroundColor3=item.color;label.BackgroundTransparency=.14;label.BorderSizePixel=0;label.Font=Enum.Font.Legacy;label.Text='  '..item.title..'  ';label.TextColor3=Color3.new(1,1,1);label.TextStrokeColor3=Color3.new(0,0,0);label.TextStrokeTransparency=0;label.TextScaled=true;label.Parent=gui
  local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,5);corner.Parent=label
 end
 return true
end
local function refreshOwnership(p)
 local s=sessions[p];if not s then return end
 for _,item in ipairs(Catalog.list()) do
  local id=tonumber(item.passId or 0) or 0
  if id>0 and not s.owned[item.id] then
   local ok,owns=pcall(function()return MarketplaceService:UserOwnsGamePassAsync(p.UserId,id)end)
   if ok and owns then s.owned[item.id]=true end
  end
 end
 if s.loaded then save(p,s) end;state(p)
end
local function onPlayer(p)
 local ok,data=true,nil
 if not RunService:IsStudio() then
  if store then ok,data=retry(function()return store:GetAsync('u:'..p.UserId)end) else ok=false end
 end
 local s={owned=cleanOwned(ok and data or nil),equipped=loadedEquipped(ok and data or nil),preview=nil,loaded=ok and not RunService:IsStudio()}
 sessions[p]=s;attributes(p,s);task.spawn(function()refreshOwnership(p)end)
 p.CharacterAdded:Connect(function()task.wait(.5);local active=s.equipped or s.preview;if active then apply(p,active,s.preview~=nil)end end)
end
local function openFor(p)if sessions[p] then remote:FireClient(p,'Open')end end
ProximityPromptService.PromptTriggered:Connect(function(prompt,p)if prompt.Name=='DonationShopPrompt' then openFor(p)end end)
remote.OnServerEvent:Connect(function(p,op,id)
 local s=sessions[p];if not s or type(op)~='string' then return end
 local now=os.clock();if now-(rate[p] or 0)<.15 then return end;rate[p]=now
 if op=='Open' then return openFor(p) end
 if op=='State' then return state(p) end
 if op=='Close' then return end
 if op=='Clear' then s.equipped=nil;s.preview=nil;clearCosmetic(p);save(p,s);return state(p,'Cosmetic cleared.') end
 if not Catalog.isValid(id) then return state(p,'Unknown cosmetic.') end
 local item=Catalog.get(id);local pass=tonumber(item.passId or 0) or 0
 if op=='Preview' then s.preview=id;s.equipped=nil;apply(p,id,true);return state(p,'Previewing '..item.title..'.') end
 if op=='Prompt' then if pass<=0 then return state(p,'UNAVAILABLE: Game Pass ID not configured.') end;return MarketplaceService:PromptGamePassPurchase(p,pass) end
 if op=='Equip' then
  local can=s.owned[id]==true or (RunService:IsStudio() and pass<=0)
  if not can then return state(p,pass<=0 and 'UNAVAILABLE: Game Pass ID not configured.' or 'You do not own this pass.') end
  s.equipped=id;s.preview=nil;apply(p,id,false);save(p,s);return state(p,'Equipped '..item.title..'.')
 end
end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p,passId,wasPurchased)
 if not wasPurchased or not sessions[p] then return end
 task.spawn(function()
  for _,item in ipairs(Catalog.list()) do if tonumber(item.passId or 0)==passId then
   local ok,owns=pcall(function()return MarketplaceService:UserOwnsGamePassAsync(p.UserId,passId)end)
   if ok and owns then sessions[p].owned[item.id]=true;save(p,sessions[p]);state(p,'Pass verified: '..item.title..'.') end
  end end
 end)
end)
Players.PlayerAdded:Connect(onPlayer);Players.PlayerRemoving:Connect(function(p)local s=sessions[p];if s then save(p,s)end;sessions[p]=nil;rate[p]=nil end)
for _,p in ipairs(Players:GetPlayers())do onPlayer(p)end
