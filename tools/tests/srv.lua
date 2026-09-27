local sss=newInstance("ServerScriptService","ServerScriptService");services.ServerScriptService=sss
local ss=newInstance("ServerStorage","ServerStorage");services.ServerStorage=ss
for _,n in ipairs({"StudTheme","RoundData","TypingRules","DonationCatalog"}) do local m=Instance.new("ModuleScript");m.Name=n;m.Parent=shared;__inst[n]=m end
for _,n in ipairs({"RoundState","RoundBots","LobbyQueue","WishRules","Perks","RoundWorld","RoundServer","DonationServer"}) do local m=Instance.new("ModuleScript");m.Name=n;m.Parent=sss;__inst[n]=m end
local cmd=Instance.new("RemoteEvent");cmd.Name="Command";cmd.Parent=shared
local snap=Instance.new("RemoteEvent");snap.Name="Snapshot";snap.Parent=shared
local toClient={}
function snap:FireClient(p,payload) toClient[#toClient+1]=payload end
local lobby=Instance.new("Model");lobby.Name="LobbyWorld";lobby.Parent=workspace
local nt=Instance.new("Folder");nt.Name="NativeTeleporters";nt.Parent=lobby
for i=1,3 do
    local m=Instance.new("Model");m.Name="Teleporter"..i;m.Parent=nt
    local b=Instance.new("Part");b.Name="BeamPart";b.CFrame=CFrame.new(100,6,(i-2)*68);b.Size=Vector3.new(29,0.2,12);b.Parent=m
    local h=Instance.new("Part");h.Name="BillboardHolder";h.Parent=m
    local bb=Instance.new("BillboardGui");bb.Parent=h
    local pl=Instance.new("TextLabel");pl.Name="Players";pl.Parent=bb
    local tm=Instance.new("TextLabel");tm.Name="Timer";tm.Parent=bb
    local l=Instance.new("Part");l.Name="LeaveHere";l.CFrame=CFrame.new(88,8,(i-2)*68);l.Parent=m
end
local spawnPart=Instance.new("SpawnLocation");spawnPart.Name="LobbySpawn";spawnPart.CFrame=CFrame.new(-8,5,0);spawnPart.Parent=workspace
-- player with character standing on ship 1
local hrp=Instance.new("Part");hrp.Name="HumanoidRootPart";hrp.Position=Vector3.new(100,9,-68);hrp.CFrame=CFrame.new(100,9,-68)
local char=Instance.new("Model");hrp.Parent=char
local hum=Instance.new("Humanoid");hum.Health=100;hum.Parent=char
localPlayer.Character=char
function char:PivotTo(c) hrp.CFrame=c;hrp.Position=c.Position end
function localPlayer:SetAttribute(k,v) self.__attrs[k]=v end
local mps=services.MarketplaceService
local prompted={}
function mps:PromptGamePassPurchase(p,id) prompted[#prompted+1]=id end
function mps:PromptProductPurchase(p,id) prompted[#prompted+1]=id end
function mps:UserOwnsGamePassAsync() return false end
local donation=Instance.new("RemoteEvent");donation.Name="DonationShopRemote";donation.Parent=shared
local dmsgs={}
function donation:FireClient(p,kind,payload) dmsgs[#dmsgs+1]={kind,payload,p} end
function donation:FireAllClients(kind,payload) dmsgs[#dmsgs+1]={kind,payload} end
game.BindToClose=function() end
local ok,e=pcall(__scripts.RoundServer);if not ok then report("RoundServer: "..tostring(e)) end
local ok2,e2=pcall(__scripts.DonationServer);if not ok2 then report("DonationServer: "..tostring(e2)) end
playersService.PlayerAdded:Fire(localPlayer)
local function beats(n) for i=1,n do clockValue=clockValue+0.05;runService.Heartbeat:Fire(0.05);runDeferred(clockValue) end end
beats(20)
local sign=nt.Teleporter1.BillboardHolder
print("sign players:",sign:FindFirstChild("Players",true).Text,"| status:",sign:FindFirstChild("Timer",true).Text)
-- the player is on ship 1 -> host picker snapshot
local last;for _,m in ipairs(toClient) do if m.lobby then last=m end end
assert(last and last.lobby.host=="1" and last.lobby.choosing,"host choosing snapshot")
cmd.OnServerEvent:Fire(localPlayer,nil,"LobbyConfig",{room=1,capacity=2})
beats(10)
print("after config:",sign:FindFirstChild("Players",true).Text,"|",sign:FindFirstChild("Timer",true).Text)
cmd.OnServerEvent:Fire(localPlayer,nil,"LobbyLeave",{})
beats(5)
print("after leave, player at",hrp.Position)
-- fall into the sea
hrp.Position=Vector3.new(0,-4,0);hrp.CFrame=CFrame.new(0,-4,0);beats(6)
print("after sea return, player at",hrp.Position)
-- use token outside a round is ignored
cmd.OnServerEvent:Fire(localPlayer,"x","UseTicket",{})
-- donation flows (Studio test grants)
beats(10)
donation.OnServerEvent:Fire(localPlayer,"Buy","VIP");clockValue=clockValue+1
donation.OnServerEvent:Fire(localPlayer,"Buy","Admin");clockValue=clockValue+1
donation.OnServerEvent:Fire(localPlayer,"Buy","Ticket7");clockValue=clockValue+1
donation.OnServerEvent:Fire(localPlayer,"Buy","VIP");clockValue=clockValue+1
for _,m in ipairs(dmsgs) do if m[1]=="State" then print("state msg:",m[2].message,"tickets:",m[2].tokens.Ticket) elseif m[1]=="Thanks" then print("thanks:",m[2].name,m[2].amount) end end
local Perks=require(__inst.Perks)
print("prompted ids:",table.concat(prompted,","))
assert(#prompted>=3,"real ids open the Roblox purchase prompts")
-- a finished product purchase is granted through ProcessReceipt
local grant=mps.ProcessReceipt({ProductId=3715146126,PlayerId=localPlayer.UserId,PurchaseId="p1"})
assert(grant==Enum.ProductPurchaseDecision.PurchaseGranted,"receipt granted")
print("perks:",Perks.has(localPlayer,"VIP"),Perks.has(localPlayer,"Admin"),"tickets:",Perks.tokens(localPlayer,"Ticket"),"attr:",localPlayer:GetAttribute("Token_Ticket"))
assert(Perks.consume(localPlayer,"Ticket"));print("after consume:",Perks.tokens(localPlayer,"Ticket"))
-- ProcessReceipt without datastore (studio path)
local Catalog=require(__inst.DonationCatalog)
local r=mps.ProcessReceipt
print("ProcessReceipt set:",type(r))
-- solo launch with a failing world: must fail safely and return to the harbour
hrp.Position=Vector3.new(100,9,-68);hrp.CFrame=CFrame.new(100,9,-68)
beats(10)
cmd.OnServerEvent:Fire(localPlayer,nil,"LobbyConfig",{room=1,capacity=1})
beats(160)
print("phase after failed launch:",localPlayer:GetAttribute("ScenePhase"),"pos",hrp.Position)
-- owners: OWNER plate, every pass, free tickets
local owner=Instance.new("Player");owner.Name="ZOY0M";owner.UserId=7;owner.DisplayName="Owner"
local oc=Instance.new("Model");oc.Name="OwnerCharacter";local head=Instance.new("Part");head.Name="Head";head.Parent=oc
local oh=Instance.new("Humanoid");oh.Parent=oc;owner.Character=oc;owner.Parent=playersService
playersService.PlayerAdded:Fire(owner);beats(10)
local ostate;for _,m in ipairs(dmsgs) do if m[1]=="State" and m[3]==owner then ostate=m[2] end end
assert(ostate and ostate.owner==true and ostate.passes.VIP and ostate.passes.Admin,"owner state")
local before=ostate.tokens.Ticket or 0
donation.OnServerEvent:Fire(owner,"Buy","Ticket20");clockValue=clockValue+1
for _,m in ipairs(dmsgs) do if m[1]=="State" and m[3]==owner then ostate=m[2] end end
assert(ostate.tokens.Ticket==before+20 and ostate.message:find("FREE"),"owner free tickets: "..tostring(ostate.message))
local plate=oc:FindFirstChild("ShopCosmetic") and oc.ShopCosmetic:FindFirstChild("RankTag")
assert(plate and plate:GetAttribute("OwnerTag") and plate.Face.Text=="OWNER","owner plate")
assert(owner:GetAttribute("Perk_Owner")==true,"owner attribute")
print("owner:",ostate.message,"tickets",ostate.tokens.Ticket)
print("ERRORS:",#ERRORS)
