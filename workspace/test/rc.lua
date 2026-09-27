do local m=Instance.new("ModuleScript");m.Name="TitleLogo";m.Parent=game:GetService("ReplicatedFirst") end
if __VPW then camera.ViewportSize=Vector2.new(__VPW,__VPH) end
for name in pairs(__modules) do local m=Instance.new("ModuleScript");m.Name=name;m.Parent=shared end
local command=Instance.new("RemoteEvent");command.Name="Command";command.Parent=shared
local snapshots=Instance.new("RemoteEvent");snapshots.Name="Snapshot";snapshots.Parent=shared
local sent={}
function command:FireServer(...) sent[#sent+1]={...} end
local hud=Instance.new("ScreenGui");hud.Name="ArmyRoundHUD";hud.Parent=playerGui
local char=Instance.new("Model");local hum=Instance.new("Humanoid");hum.Parent=char;localPlayer.Character=char
local function frames(n) for i=1,n do clockValue=clockValue+0.016;runService.RenderStepped:Fire(0.016);runService.Heartbeat:Fire(0.016);runDeferred(clockValue) end end
local ok,e=pcall(__scripts.RoundClient);if not ok then report("RoundClient load: "..tostring(e)) end
frames(10)
-- lobby snapshot for a ship
snapshots.OnClientEvent:Fire({lobby={room=1,fleet="AZURE FLEET",host="1",choosing=true,count=1},message="CHOOSE"})
frames(5)
localPlayer:SetAttribute("ScenePhase","Transferring");frames(30)
-- build a real state snapshot
local Data=require(shared.RoundData);local State=require(shared.RoundState)
local layouts={}
for i,uid in ipairs({"1","-1"}) do
    local L={lands={},buildings={},nodes={}}
    for name,d in pairs(Data.Lands) do L.lands[name]={x=d.pos.x+i*300,y=d.pos.y,z=d.pos.z} end
    for key,d in pairs(Data.Buildings) do L.buildings[key]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
    for key,d in pairs(Data.ResourceNodes) do L.nodes[key]={x=d.pos.x+i*300,y=L.lands[d.land].y,z=d.pos.z} end
    layouts[uid]=L
end
local s=State.new(Data,layouts,{},{},{names={["1"]="Tester",["-1"]="Bot"},bots={["-1"]=true},colors={},perks={["1"]={VIP=true}},tickets={["1"]=1}})
localPlayer:SetAttribute("RoundHome",Vector3.new(0,0,0));localPlayer:SetAttribute("RoundBoundsMin",Vector3.new(-100,0,-100));localPlayer:SetAttribute("RoundBoundsMax",Vector3.new(100,0,100))
localPlayer:SetAttribute("RoundModel","ArmyRound_x");localPlayer:SetAttribute("RoundToken","tok");localPlayer:SetAttribute("ScenePhase","Round")
frames(60)
local seq=0
local function push(msg) seq=seq+1;local snap=State.snapshot(s,"1");snap.token="tok";snap.sequence=seq;snap.message=msg;snapshots.OnClientEvent:Fire(snap) end
push("hello");frames(5)
localPlayer:SetAttribute("Token_Ticket",2);frames(2)
local boost=playerGui:FindFirstChild("RoundBoosts");assert(boost and boost.Enabled,"boost gui")
local btn=boost:FindFirstChild("Ticket",true);assert(btn and btn.Visible,"ticket button visible");print("   ticket btn:",btn.Text)
btn.Activated:Fire();assert(sent[#sent][2]=="UseTicket","use ticket sent")
State.useTicket(s,"1");push(nil);frames(5)
print("   timer:",boost:FindFirstChild("AdminTimer",true).Caption.Text)
for i=1,200 do State.step(s,.1) end
push(nil);frames(5)
s.players["1"].armyBoostUntil=s.elapsed+10;push(nil);frames(2)
assert(boost:FindFirstChild("army",true).Visible,"army chip")
if __VPW then dumpGui("round_hud",{playerGui}) end
localPlayer:SetAttribute("ScenePhase","Lobby");frames(120)
print("sent ops:");for _,x in ipairs(sent) do io=nil;print("  ",x[2]) end
print("ERRORS:",#ERRORS)
