local sss=newInstance("ServerScriptService","ServerScriptService");services.ServerScriptService=sss
local ss=newInstance("ServerStorage","ServerStorage");services.ServerStorage=ss
for _,n in ipairs({"StudTheme","RoundData","TypingRules","DonationCatalog"}) do local m=Instance.new("ModuleScript");m.Name=n;m.Parent=shared;__inst[n]=m end
for _,n in ipairs({"RoundState","RoundBots","LobbyQueue","WishRules","Perks","AdminBrain","AdminCommands","AdminActions","RoundWorld","RoundServer","DonationServer"}) do local m=Instance.new("ModuleScript");m.Name=n;m.Parent=sss;__inst[n]=m end
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
local roster={localPlayer}
local guidN=0
for _,svc in pairs(services) do if type(svc)=='table' and rawget(svc,'GenerateGUID')~=nil or (type(svc)=='table' and svc.GenerateGUID) then svc.GenerateGUID=function() guidN+=1;return 'guid-'..guidN end end end
function playersService:GetPlayers() local out={};for _,p in ipairs(roster) do if p==localPlayer or p.Parent==playersService then out[#out+1]=p end end;return out end
function playersService:GetPlayerByUserId(id) for _,p in ipairs(roster) do if p.UserId==id and (p==localPlayer or p.Parent==playersService) then return p end end end
beats(20)
local function newPlayer(name,uid,pos)
  local p=Instance.new("Player");p.Name=name;p.UserId=uid;p.DisplayName=name
  local r=Instance.new("Part");r.Name="HumanoidRootPart";r.Position=pos;r.CFrame=CFrame.new(pos.X,pos.Y,pos.Z)
  local c=Instance.new("Model");c.Name=name.."Char";r.Parent=c
  local h=Instance.new("Humanoid");h.Health=100;h.Parent=c
  function c:PivotTo(cf) r.CFrame=cf;r.Position=cf.Position end
  p.Character=c;p.Parent=playersService;roster[#roster+1]=p;playersService.PlayerAdded:Fire(p)
  return p,r
end
local sign=nt.Teleporter1.BillboardHolder
local function signText() return sign:FindFirstChild("Players",true).Text.." | "..tostring(sign:FindFirstChild("Timer",true).Text) end
-- A (localPlayer) is already on cabin 1; B joins
local B,rb=newPlayer("Bob",2,Vector3.new(101,9,-68))
beats(10)
print("cabin with 2 waiting:",signText())
cmd.OnServerEvent:Fire(localPlayer,nil,"LobbyConfig",{room=1,capacity=2})
beats(400)
print("A phase:",localPlayer:GetAttribute("ScenePhase"),"B phase:",B:GetAttribute("ScenePhase"),"worlds:",#CREATED)
print("cabin right after launch:",signText())
assert(localPlayer:GetAttribute("ScenePhase")=="Round" and B:GetAttribute("ScenePhase")=="Round","both in the round")
assert(sign:FindFirstChild("Players",true).Text:sub(1,2)=="0/","cabin shows 0/ again")
-- C starts a second round from the same cabin while the first one is still running
local C,rc=newPlayer("Carl",3,Vector3.new(100,9,-68))
beats(10)
local lastC;for _,m in ipairs(toClient) do if m.lobby then lastC=m end end
print("C sees cabin:",lastC and lastC.lobby.host,lastC and lastC.lobby.choosing)
cmd.OnServerEvent:Fire(C,nil,"LobbyConfig",{room=1,capacity=1})
beats(400)
print("C phase:",C:GetAttribute("ScenePhase"),"worlds:",#CREATED,"slots:",CREATED[1] and CREATED[1].slot,CREATED[2] and CREATED[2].slot)
assert(C:GetAttribute("ScenePhase")=="Round" and #CREATED==2 and CREATED[2].slot~=CREATED[1].slot,"second concurrent round in its own slot")
print("cabin again:",signText())
-- B leaves the game: A is the last one standing and wins, then returns to the lobby
B.Parent=nil;playersService.PlayerRemoving:Fire(B)
beats(20)
local win;for _,m in ipairs(toClient) do if m.status=="Ended" then win=m end end
print("result:",win and win.winner,win and win.winnerName,"returnIn",win and win.returnIn)
beats(200)
print("A phase after the round:",localPlayer:GetAttribute("ScenePhase"),"A pos",hrp.Position,"world 1 destroyed:",CREATED[1].destroyed)
assert(localPlayer:GetAttribute("ScenePhase")=="Lobby","winner is back in the lobby")
print("C still playing:",C:GetAttribute("ScenePhase"),"world 2 destroyed:",CREATED[2].destroyed==true)
print("ERRORS:",#ERRORS)
