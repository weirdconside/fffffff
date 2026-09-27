do local m=Instance.new("ModuleScript");m.Name="TitleLogo";m.Parent=game:GetService("ReplicatedFirst") end
-- Builds every lobby-side UI in a known state and dumps it for guirender.py.
camera.ViewportSize=Vector2.new(__VPW,__VPH)
local char=Instance.new("Model");char.Name="Character";local hrp=Instance.new("Part");hrp.Name="HumanoidRootPart";hrp.Parent=char
local hum=Instance.new("Humanoid");hum.Parent=char;localPlayer.Character=char
for name in pairs(__modules) do local m=Instance.new("ModuleScript");m.Name=name;m.Parent=shared end
local remote=Instance.new("RemoteEvent");remote.Name="DonationShopRemote";remote.Parent=shared
function remote:FireServer() end
local command=Instance.new("RemoteEvent");command.Name="Command";function command:FireServer() end
local function frames(n) for i=1,n do clockValue=clockValue+0.016;runService.RenderStepped:Fire(0.016);runService.Heartbeat:Fire(0.016);runDeferred(clockValue) end end
local function only(gui) for _,g in ipairs(playerGui:GetChildren()) do if g~=gui and g.ClassName=="ScreenGui" then g.Enabled=false end end;gui.Enabled=true end
local function section(name,fn) local ok,e=pcall(fn);if not ok then report(name..": "..tostring(e)) end end
section("lobby",function()
    local LobbyUI=require(shared.LobbyUI)
    local ui=LobbyUI.new(playerGui,1,command);only(ui.gui)
    ui:update({room=2,host="1",choosing=true,count=1,remaining=15},false,"CHOOSE");frames(5)
    dumpGui("lobby_picker",{ui.gui})
    ui:update({room=2,host="1",capacity=1,count=1,remaining=0},false,"ROOM");frames(5)
    dumpGui("lobby_bar_starting",{ui.gui})
    ui:update({room=3,host="1",capacity=6,count=4,remaining=15},false,"ROOM");frames(5)
    dumpGui("lobby_bar_wait",{ui.gui})
    ui:update({room=1,host="2",choosing=true,count=1},false,"CHOOSE");frames(5)
    dumpGui("lobby_bar_host",{ui.gui})
    ui.gui.Enabled=false
end)
section("shop",function()
    local Shop=require(shared.DonationShop);local Catalog=require(shared.DonationCatalog)
    local shop=Shop.new(playerGui,remote,Catalog)
    shop:applyState({passes={VIP=true},tokens={Ticket=13},studio=false,message="Thank you! +7 tickets"})
    shop:openShop();frames(40)
    local g=playerGui:FindFirstChild("AdminShop") or shop.gui
    dumpGui("shop",{g or playerGui})
end)
section("admin",function()
    local AdminUI=require(shared.AdminUI)
    local admin=AdminUI.new(playerGui,function() end)
    local base={eventId="1",recipient="1",recipientName="SuperLongPlayerName_123",recipientColor={r=200,g=100,b=50},prompt="",remaining=10,remainingExact=10,phaseElapsed=0}
    local function with(t) local o={};for k,v in pairs(base) do o[k]=v end;for k,v in pairs(t) do o[k]=v end;return o end
    admin:update(with({phase="Prompt",canType=true,ticket=true,examples={"heal my army","meteor on the enemy base"}}));frames(5)
    dumpGui("admin_prompt",{admin.gui or playerGui})
    admin:update(with({eventId="2",phase="Prompt",canType=false}));frames(5)
    dumpGui("admin_watch",{admin.gui or playerGui})
    admin:update(with({eventId="2",phase="Roulette",choice="Append",prompt="give every soldier a golden shield and double speed"}));frames(10)
    dumpGui("admin_roulette",{admin.gui or playerGui})
    admin:update(with({eventId="2",phase="Applied",outcome="Executed",effect="EXECUTED: Meteors rain on every enemy base for 20 seconds."}));frames(5)
    dumpGui("admin_applied",{admin.gui or playerGui})
end)
section("curtain",function()
    local T=require(shared.StudTransition)
    local t=T.new(playerGui);task.spawn(function() t:cover("LOADING BATTLE...","ROOM 2  -  4 PLAYERS") end);frames(90)
    dumpGui("curtain",{t.gui})
end)
section("title",function()
    __scripts.TitleScreen()
    local snd=game:GetService("SoundService"):FindFirstChild("TitleMusic")
    if snd then snd.IsPlaying=true;snd.IsLoaded=true;snd.TimeLength=32.5
        runService.RenderStepped:Connect(function(dt) snd.TimePosition=(snd.TimePosition+dt)%snd.TimeLength end) end
    frames(700)
    dumpGui("title",{playerGui:FindFirstChild("TitleScreen")})
end)
print("ERRORS:",#ERRORS)
