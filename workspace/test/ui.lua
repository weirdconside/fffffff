do local m=Instance.new("ModuleScript");m.Name="TitleLogo";m.Parent=game:GetService("ReplicatedFirst") end
for name in pairs(__modules) do local m=Instance.new("ModuleScript");m.Name=name;m.Parent=shared end
local remote=Instance.new("RemoteEvent");remote.Name="DonationShopRemote";remote.Parent=shared
local fired={}
function remote:FireServer(...) fired[#fired+1]={...} end
local command=Instance.new("RemoteEvent");command.Name="Command"
local cmdFired={}
function command:FireServer(...) cmdFired[#cmdFired+1]={...} end
local char=Instance.new("Model");char.Name="Character";local hrp=Instance.new("Part");hrp.Name="HumanoidRootPart";hrp.CFrame=CFrame.new(0,8,0);hrp.Position=Vector3.new(0,8,0);hrp.Parent=char
local hum=Instance.new("Humanoid");hum.Parent=char;localPlayer.Character=char
local function frames(n) for i=1,n do clockValue=clockValue+0.016;runService.RenderStepped:Fire(0.016);runService.Heartbeat:Fire(0.016);runDeferred(clockValue) end end
local function section(name,fn) local ok,e=pcall(fn);if not ok then report(name..": "..tostring(e)) else print("ok  "..name) end end
-- Shop -------------------------------------------------------------------------
section("DonationShop",function()
    local Shop=require(shared.DonationShop);local Catalog=require(shared.DonationCatalog)
    local shop=Shop.new(playerGui,remote,Catalog)
    shop:applyState({passes={VIP=true},tokens={Ticket=3},studio=true,message="hi"})
    shop:openShop();frames(30)
    for key,card in pairs(shop.cards) do card.buy.Activated:Fire() end
    assert(#fired>0,"buy fired nothing")
    shop:setAvailable(false);shop:setAvailable(true);shop:setIntro(true);shop:setIntro(false);shop:closeShop()
    assert(shop.cards.VIP.buy.Text=="OWNED",shop.cards.VIP.buy.Text);assert(shop.cards.Admin.buy.Text:find("R%$") or shop.cards.Admin.buy.Text=="BUY",shop.cards.Admin.buy.Text)
    assert(shop.wallet.Text=="3",shop.wallet.Text)
    shop:applyState({passes={VIP=true,Admin=true,Owner=true},tokens={Ticket=5},owner=true})
    assert(shop.cards.Ticket7.buy.Text=="FREE" and shop.cards.Admin.buy.Text=="OWNED","owner shop buttons")
end)
-- Lobby picker ----------------------------------------------------------------
section("LobbyUI",function()
    local LobbyUI=require(shared.LobbyUI)
    local ui=LobbyUI.new(playerGui,1,command)
    ui:update({room=2,host="1",choosing=true,count=1,remaining=15},false,"CHOOSE")
    assert(ui.card.Visible,"picker should show")
    ui.right.Activated:Fire();ui.right.Activated:Fire();assert(ui.selected==3)
    ui.create.Activated:Fire();assert(#cmdFired==1 and cmdFired[1][2]=="LobbyConfig" and cmdFired[1][3].capacity==3)
    ui:update({room=2,host="1",capacity=3,count=1,remaining=12},false,"ROOM 3")
    assert(ui.bar.Visible and not ui.card.Visible);print("   bar:",ui.barText.Text)
    ui:update({room=2,host="2",choosing=true,count=1},false,"CHOOSE")
    print("   bar(non-host):",ui.barText.Text)
    ui.bar.Leave.Activated:Fire();assert(cmdFired[#cmdFired][2]=="LobbyLeave")
    ui:update({room=2,left=true},false);frames(3)
end)
-- Admin panel -----------------------------------------------------------------
section("AdminUI",function()
    local AdminUI=require(shared.AdminUI)
    local sent={}
    local admin=AdminUI.new(playerGui,function(op,p) sent[#sent+1]=op end)
    local base={eventId="1",recipient="1",recipientName="Alice",recipientColor={r=200,g=100,b=50},prompt="",remaining=10,remainingExact=10,phaseElapsed=0}
    local function with(t) local o={};for k,v in pairs(base) do o[k]=v end;for k,v in pairs(t) do o[k]=v end;return o end
    admin:update(with({phase="Prompt",canType=true,ticket=true,examples={"heal my army"}}));frames(3)
    assert(admin.hint.Visible,"hint");assert(admin.card.Visible,"input bar");print("   kicker:",admin.kicker.Text)
    admin:update(with({eventId="2",phase="Prompt",canType=false}));frames(2);assert(not admin.card.Visible,"watchers do not type");print("   watching:",admin.kicker.Text,admin.lines[1].Text)
    admin:update(with({eventId="2",phase="Announcement",prompt="meteor on enemies"}))
    admin:update(with({eventId="2",phase="Roulette",choice="Append",prompt="x"}));frames(10)
    admin:update(with({eventId="2",phase="Applied",outcome="Executed",effect="EXECUTED: Meteors.",quotes={{name="Alice",color={r=200,g=100,b=50},text="meteor on enemies"}}}));print("   applied:",admin.kicker.Text,admin.lines[1].Text,admin.effect.Text)
    admin:update({phase="Idle"})
end)
-- Transition ------------------------------------------------------------------
section("StudTransition",function()
    local T=require(shared.StudTransition)
    local t=T.new(playerGui);task.spawn(function() t:cover("SETTING SAIL...","AZURE FLEET") end);frames(80);assert(t:isActive());t:reveal();frames(120);assert(not t:isActive())
end)
-- Title screen ----------------------------------------------------------------
section("TitleScreen",function()
    __scripts.TitleScreen()
    -- simulate the uploaded title track playing (and looping once)
    local snd=game:GetService("SoundService"):FindFirstChild("TitleMusic");assert(snd and snd.SoundId:find("132472169476353"),"music id")
    snd.IsPlaying=true;snd.IsLoaded=true;snd.TimeLength=32.5
    local musicConn=runService.RenderStepped:Connect(function(dt) snd.TimePosition=(snd.TimePosition+dt)%snd.TimeLength end)
    frames(60)
    local gui=playerGui:FindFirstChild("TitleScreen");assert(gui,"title gui")
    frames(420)
    local pill=gui:FindFirstChild("Start",true);assert(pill and pill.Visible,"press any key not visible")
    uis.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Space})
    frames(200)
    assert(gui.__destroyed,"title did not close")
    assert(localPlayer:GetAttribute("IntroActive")==false)
end)
section("DonationClient",function() __scripts.DonationClient();frames(5) end)
section("LobbyAmbience",function()
    local lw=Instance.new("Model");lw.Name="LobbyWorld";lw.Parent=workspace
    __scripts.LobbyAmbience();frames(5)
end)
section("UISounds",function() __scripts.UISounds();frames(3);local b=Instance.new("TextButton");b.Parent=playerGui;b.Activated:Fire() end)
print("ERRORS:",#ERRORS)
