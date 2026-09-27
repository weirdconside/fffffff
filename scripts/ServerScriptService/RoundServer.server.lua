-- Server-authoritative reconstruction using the supplied BATTLE BUT WITH ADMIN PANEL assets/data.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local HttpService=game:GetService("HttpService")
local TextService=game:GetService("TextService")
local Shared=assert(ReplicatedStorage:FindFirstChild("ArmyRoundShared"),"ArmyRoundShared missing")
local Data=require(Shared.RoundData)
local State=require(script.Parent.RoundState)
local World=require(script.Parent.RoundWorld)
local Bots=require(script.Parent.RoundBots)
local Queue=require(script.Parent.LobbyQueue)
local WishRules=require(script.Parent.WishRules)
local Brain=require(script.Parent.AdminBrain)
local Theme=require(Shared.StudTheme)
local Perks=require(script.Parent.Perks)
local Catalog=require(Shared.DonationCatalog)
local Command=Shared.Command
local Snapshot=Shared.Snapshot
local AdminFX=Shared:FindFirstChild("AdminFX") or Instance.new("RemoteEvent");AdminFX.Name="AdminFX";AdminFX.Parent=Shared
local lobby=assert(Workspace:FindFirstChild("LobbyWorld"),"LobbyWorld missing")
local pads=assert(lobby:FindFirstChild("NativeTeleporters"),"Native squares missing")
local lobbySpawn=assert(Workspace:FindFirstChild("LobbySpawn"),"LobbySpawn missing")
-- Clear only this system's old runtime/cache, never the approved lobby or source templates.
local runtime=Workspace:FindFirstChild("ArmyRounds")
if runtime then runtime:ClearAllChildren() else runtime=Instance.new("Folder");runtime.Name="ArmyRounds";runtime.Parent=Workspace end
local storage=game:GetService("ServerStorage")
for _,o in ipairs(storage:GetChildren()) do if o.Name:sub(1,11)=="RoundCache_" then o:Destroy() end end
-- sessions are keyed by their token: a room can start a new round while older ones are still being played
local rooms,membership,sessions,hidden,limits,addedPlayers={},{},{},{},{},{}
local slots={}   -- world slot -> session; every running round gets its own place far from the lobby
local MAX_PLAYERS,COUNTDOWN=6,15
local LOBBY_WATER_Y=0
local queueSuppressed,lobbyRate={},{}
local LOBBY_OPS={LobbyConfig=true,LobbyLeave=true}
local function root(player)
    local c=player.Character;local h=c and c:FindFirstChildOfClass("Humanoid")
    return h and h.Health>0 and c:FindFirstChild("HumanoidRootPart") or nil
end
local LOBBY_WALK_SPEED=40   -- 16 * 2.5
local function move(player,cf)
    local r=root(player);if not r then return false end
    r.AssemblyLinearVelocity=Vector3.new(0,0,0);r.AssemblyAngularVelocity=Vector3.new(0,0,0)
    player.Character:PivotTo(cf);return true
end
local function restore(player)
    local saved=hidden[player];hidden[player]=nil;if not saved then return end
    if saved.connection then saved.connection:Disconnect() end
    for o,properties in pairs(saved.objects) do
        if o.Parent then for key,value in pairs(properties) do o[key]=value end end
    end
end
local function conceal(player)
    restore(player)
    local character=player.Character;local r=root(player);if not character or not r then return false end
    local saved={objects={}};hidden[player]=saved
    local function set(o,values)
        local props=saved.objects[o] or {};saved.objects[o]=props
        for key,value in pairs(values) do if props[key]==nil then props[key]=o[key] end;o[key]=value end
    end
    local function hide(o)
        if o:IsA("BasePart") then
            set(o,{CanCollide=false});set(o,{CanTouch=false,CanQuery=false,Transparency=1,CastShadow=false})
        elseif o:IsA("Decal") or o:IsA("Texture") then set(o,{Transparency=1})
        elseif o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam") or o:IsA("BillboardGui") then set(o,{Enabled=false}) end
    end
    for _,o in ipairs(character:GetDescendants()) do hide(o) end
    saved.connection=character.DescendantAdded:Connect(hide)
    local h=character:FindFirstChildOfClass("Humanoid")
    set(h,{WalkSpeed=0,JumpPower=0,JumpHeight=0,AutoRotate=false,DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None})
    set(r,{Anchored=true});return true
end
local function label(room,n,text)
    local holder=room.model:FindFirstChild("BillboardHolder",true)
    local gui=holder and holder:FindFirstChildWhichIsA("BillboardGui",true)
    if not gui then gui=room.model:FindFirstChildWhichIsA("BillboardGui",true) end
    if not gui then return end
    gui.Enabled=true
    gui.AlwaysOnTop=true
    local amount=gui:FindFirstChild("Players",true);local timer=gui:FindFirstChild("Timer",true)
    if not amount then amount=gui:FindFirstChild("Count",true) end
    if not timer then timer=gui:FindFirstChild("Status",true) end
    local cap=room.capacity or MAX_PLAYERS
    if amount then amount.Text=tostring(n).."/"..tostring(cap) end
    if timer then
        local shown=tostring(text or "")
        timer.Visible=shown~=""
        timer.Text=type(text)=="number" and (tostring(text).."s") or shown
    end
end
local function styleRoom(room)
    -- Keep the donor cabin geometry while normalizing every status square so
    -- one stale red material cannot make a waiting cabin look broken.
    for _,o in ipairs(room.model:GetDescendants()) do
        if o:IsA("BasePart") and o.Name=="EnterPart" then o.CanCollide=false end
        if o:IsA("BasePart") and (o.Name=="BeamPart" or o.Name=="Base" or o.Name=="Floor") then
            o.Material=Enum.Material.SmoothPlastic
            o.Color=Color3.fromRGB(72,106,142)
        elseif o:IsA("Beam") then
            -- Every cabin uses the same calm blue/cyan signal; no red fallback.
            o.Color=ColorSequence.new(Color3.fromRGB(100,194,246))
            o.Brightness=1.2;o.Enabled=true
        end
    end
    local gui=room.model:FindFirstChildWhichIsA("BillboardGui",true)
    if gui then
        gui.Enabled=true
        for _,o in ipairs(gui:GetDescendants()) do
            if o:IsA("TextLabel") then
                -- All three cabins share one gold counter style.  This removes
                -- the lone red donor label without changing the cabin mesh.
                o.TextColor3=Color3.fromRGB(248,222,133)
                o.TextStrokeColor3=Color3.fromRGB(8,18,32)
                if o.Text=="HARDCORE" then o.Visible=false end
            end
        end
    end
end
local function playerCount(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local function sortedPlayers(t)
    local r={};for p in pairs(t or {}) do r[#r+1]=p end
    table.sort(r,function(a,b)return a.UserId<b.UserId end);return r
end
local function lobbySnapshot(room,player)
    local queued=room.queued or {};local count=playerCount(queued)
    local remaining=room.remaining and math.max(0,math.ceil(room.remaining)) or COUNTDOWN
    return {lobby={room=room.id,host=room.host and tostring(room.host.UserId) or nil,capacity=room.capacity,count=count,remaining=remaining,choosing=room.host~=nil and room.capacity==nil},message=room.host and (room.capacity and ("ROOM "..tostring(room.capacity)) or "CHOOSE") or "JOIN"}
end
local function sendLobby(room)
    for p in pairs(room.queued or {}) do if p.Parent==Players then Snapshot:FireClient(p,lobbySnapshot(room,p)) end end
end
local function setHost(room) return Queue.host(room) end
local function leaveQueue(room,player)
    if Queue.remove(room,player) then
        if player.Parent==Players then Snapshot:FireClient(player,{lobby={room=room.id,left=true}}) end
        sendLobby(room)
    end
end
local function free(session)
    if sessions[session.token]~=session then return end
    sessions[session.token]=nil
    if session.slot and slots[session.slot]==session then slots[session.slot]=nil end
    if session.world then World.destroy(session.world) end
end
-- the cabin is ready for the next group as soon as the previous one has been sent away
local function resetRoom(room)
    room.busy=false;room.deadline=nil;room.remaining=nil;room.queued={};room.order={};room.host=nil;room.capacity=nil;room.launching=nil
    label(room,0,COUNTDOWN);sendLobby(room)
end
local function leave(player,teleport)
    local session=membership[player];membership[player]=nil
    restore(player)
    player:SetAttribute("ScenePhase","Lobby");player:SetAttribute("RoundToken",nil);player:SetAttribute("SceneCover",nil)
    player:SetAttribute("RoundHome",nil);player:SetAttribute("RoundCenter",nil);player:SetAttribute("RoundModel",nil)
    player:SetAttribute("RoundBoundsMin",nil);player:SetAttribute("RoundBoundsMax",nil)
    if session then
        session.players[player]=nil
        if session.state then State.remove(session.state,tostring(player.UserId)) end
        if not next(session.players) then free(session) end
    end
    if teleport then move(player,lobbySpawn.CFrame+Vector3.new(0,4,0)) end
end
local function finish(session)
    local list={};for p in pairs(session.players) do list[#list+1]=p end
    for _,p in ipairs(list) do leave(p,true) end
    free(session)
end
-- The client needs ~1 s to close the brick curtain; players are only moved
-- once the screen is covered, so nobody sees the world pop in or out.
local COVER_SECONDS=1.1
local RESULT_SECONDS=5   -- the winner is announced for a few seconds, then everyone goes back to the lobby
local function coveredLeave(session,player)
    session.leaving=session.leaving or {}
    if session.leaving[player] then return end
    session.leaving[player]=true
    player:SetAttribute("SceneCover",os.clock())
    task.delay(COVER_SECONDS,function()
        if membership[player]==session then leave(player,true) end
    end)
end
local function coveredFinish(session)
    if session.finishing then return end
    session.finishing=true
    for p in pairs(session.players) do if p.Parent==Players then p:SetAttribute("SceneCover",os.clock()) end end
    task.delay(COVER_SECONDS,function()
        if sessions[session.token]==session then finish(session) end
    end)
end
local function send(session,player,message)
    if membership[player]~=session or not session.state then return end
    local snapshot=State.snapshot(session.state,tostring(player.UserId));if not snapshot then return end
    snapshot.token=session.token;snapshot.message=message;snapshot.sequence=session.sequence
    if session.endedAt then snapshot.returnIn=math.max(0,math.ceil(RESULT_SECONDS-(os.clock()-session.endedAt))) end
    if snapshot.winner then local winner=session.state.players[snapshot.winner];snapshot.winnerName=winner and winner.name or snapshot.winner end
    Snapshot:FireClient(player,snapshot)
end
local function launch(room,group,prebusy)
    if room.busy and not prebusy then return end
    room.busy=true;room.deadline=nil;room.remaining=nil
    local capacity=room.capacity
    local token=HttpService:GenerateGUID(false):gsub("%-","")
    local slot=1;while slots[slot] do slot=slot+1 end
    local session={room=room,token=token,slot=slot,players={},botIds={},sequence=0,defeatedAt={},wishSerial={}}
    sessions[token]=session;slots[slot]=session;room.launching=session
    local humans={}
    for _,p in ipairs(group) do
        if p.Parent==Players then humans[#humans+1]=p;membership[p]=session;session.players[p]=true;p:SetAttribute("ScenePhase","Transferring") end
    end
    -- Solo rooms deliberately receive three ordinary roster slots, not free resources or combat cheats.
    local fullGroup={table.unpack(humans)}
    if capacity==1 then
        local need=math.max(0,4-#fullGroup)
        for i=1,need do
            local bot={UserId=-1000000-room.id*10-i,Name="Bot "..i,Skill=0.78,IsBot=true}
            fullGroup[#fullGroup+1]=bot;session.botIds[#session.botIds+1]=tostring(bot.UserId)
        end
    end
    label(room,#humans,"...");sendLobby(room)
    local ok,err=pcall(function()
        session.world=World.create(Data,slot,token,fullGroup,runtime)
        local names,bots,colors,perks,tickets={},{},{},{},{}
        for _,rosterPlayer in ipairs(fullGroup) do
            local uid=tostring(rosterPlayer.UserId)
            names[uid]=rosterPlayer.Name or ("Player "..uid)
            bots[uid]=type(rosterPlayer)=="table" and rosterPlayer.IsBot==true
            local color=session.world.players[uid].colour
            colors[uid]={r=math.floor(color.R*255+.5),g=math.floor(color.G*255+.5),b=math.floor(color.B*255+.5)}
            if typeof(rosterPlayer)=="Instance" then
                -- VIP / ADMIN passes: round rules + free tickets for this round
                local owned=Perks.snapshot(rosterPlayer);perks[uid]=owned
                tickets[uid]=(owned.VIP and Catalog.Rules.VipRoundTickets or 0)+(owned.Admin and Catalog.Rules.AdminRoundTickets or 0)
            end
        end
        session.state=State.new(Data,session.world.layouts,session.world.central,session.world.territories,{names=names,bots=bots,colors=colors,perks=perks,tickets=tickets})
        session.bots=Bots.attach(session.state,fullGroup,State)
        World.sync(session.world,session.state)
        for _,p in ipairs(humans) do
            local v=session.world.players[tostring(p.UserId)]
            -- A player can be between CharacterAdded events exactly when a
            -- short (one-player) cabin countdown expires. Keep the session
            -- alive and let the existing CharacterAdded hook finish the move;
            -- missing HumanoidRootPart must never bounce a valid room to lobby.
            if membership[p]==session and p.Parent==Players and v then
                move(p,CFrame.new(v.home+Vector3.new(0,4,0)));conceal(p)
                p:SetAttribute("RoundHome",v.home);p:SetAttribute("RoundCenter",session.world.center);p:SetAttribute("RoundBoundsMin",session.world.cameraMin);p:SetAttribute("RoundBoundsMax",session.world.cameraMax);p:SetAttribute("RoundModel",session.world.model.Name);p:SetAttribute("RoundToken",token);p:SetAttribute("ScenePhase","Round");send(session,p,nil)
            else leave(p,true) end
        end
    end)
    if not ok then warn("[ArmyRound] Start failed: "..tostring(err));finish(session)
    else print("[ArmyRound] Started "..token.." players="..#humans.." bots="..#session.botIds.." slot="..slot) end
    resetRoom(room)
end
for index=1,3 do
    local m=assert(pads:FindFirstChild("Teleporter"..index),"Missing native Teleporter")
    local f=assert(m:FindFirstChild("BeamPart"),"Missing native BeamPart")
    for _,o in ipairs(m:GetChildren()) do if o:IsA("BasePart") and o.Name=="EnterPart" then o.CanCollide=false end end
    local room={id=index,model=m,floor=f,busy=false,queued={},order={},joinSerial=0,host=nil,capacity=nil,remaining=nil,lastQueueAt=os.clock()};rooms[#rooms+1]=room;styleRoom(room);label(room,0,COUNTDOWN)
end
local function inPad(room,r)
    local p=room.floor.CFrame:PointToObjectSpace(r.Position)
    return math.abs(p.X)<=room.floor.Size.X/2 and math.abs(p.Z)<=room.floor.Size.Z/2 and p.Y>=-1 and p.Y<=12
end
local allowed={Collect=true,Expand=true,Train=true,Upgrade=true,Craft=true,Research=true,Order=true,BuyWorker=true,Sync=true,WishDraft=true,WishSubmit=true,AppendDraft=true,AppendSubmit=true,UseTicket=true}
local wishOps={WishDraft=true,WishSubmit=true,AppendDraft=true,AppendSubmit=true}
local function filterPublic(player,text)
    text=WishRules.sanitize(text)
    if text=="" then return "" end
    local ok,value=pcall(function()
        local result=TextService:FilterStringAsync(text,player.UserId,Enum.TextFilterContext.PublicChat)
        return result:GetNonChatStringForBroadcastAsync()
    end)
    if ok and type(value)=="string" then return WishRules.sanitize(value) end
    return nil
end
Command.OnServerEvent:Connect(function(player,token,op,payload)
    if type(op)~="string" then return end
    -- Lobby requests are host-scoped and rate limited independently of a match.
    if LOBBY_OPS[op] then
        if membership[player] then return end
        local now=os.clock()
        if op~="LobbyLeave" and now-(lobbyRate[player] or -100)<.2 then return end
        lobbyRate[player]=now
    end
    if op=="LobbyLeave" then
        for _,room in ipairs(rooms) do if room.queued and room.queued[player] then
            queueSuppressed[player]={room=room.id,untilTime=os.clock()+2}
            leaveQueue(room,player)
            local exit=room.model:FindFirstChild("LeaveHere",true)
            move(player,exit and exit.CFrame or lobbySpawn.CFrame+Vector3.new(0,4,0))
        end end
        return
    elseif op=="LobbyConfig" then
        if type(payload)~="table" then return end
        local rid=tonumber(payload.room);local room=rid and rooms[rid]
        local cap=tonumber(payload.capacity)
        if not room or room.busy or cap==nil or cap%1~=0 or cap<1 or cap>MAX_PLAYERS then return end
        if not room.queued[player] or room.host~=player then return end
        local ok,message=Queue.configure(room,player,cap,MAX_PLAYERS,COUNTDOWN)
        sendLobby(room)
        if not ok then local snapshot=lobbySnapshot(room,player);snapshot.message=message;Snapshot:FireClient(player,snapshot) end
        return
    end
    if not allowed[op] then return end
    local now=os.clock();local bucket=limits[player] or {time=now,tokens=10,sync=0,wish=0};limits[player]=bucket
    if wishOps[op] then
        bucket.inputTokens=math.min(12,(bucket.inputTokens or 12)+(now-(bucket.inputAt or now))*30);bucket.inputAt=now
        if bucket.inputTokens<1 then return end;bucket.inputTokens=bucket.inputTokens-1
    else
        bucket.tokens=math.min(10,bucket.tokens+(now-bucket.time)*5);bucket.time=now
        if bucket.tokens<1 then return end;bucket.tokens=bucket.tokens-1
    end
    local session=membership[player]
    if not session or not session.state or type(token)~="string" or token~=session.token then return end
    if op=="Sync" then
        if now-bucket.sync>=0.5 then bucket.sync=now;send(session,player,nil) end
        return
    end
    if type(payload)~="table" then return end
    -- Strip all unknown/deep fields before they reach game state.
    local clean={}
    for _,field in ipairs({"key","kind","mode","prompt","text","eventId","target","enemy","camp","owner","choice"}) do
        if payload[field]~=nil then
            if type(payload[field])~="string" or #payload[field]>240 then return end
            clean[field]=payload[field]
        end
    end
    if type(payload.pos)=="table" then clean.pos={x=payload.pos.x,y=payload.pos.y,z=payload.pos.z} end
    if payload.ids~=nil then
        if type(payload.ids)~="table" or #payload.ids>60 then return end
        clean.ids={};local seen={};local length=#payload.ids
        for key in pairs(payload.ids) do if type(key)~="number" or key%1~=0 or key<1 or key>length then return end end
        for i,id in ipairs(payload.ids) do if type(id)~="string" or #id>12 or seen[id] then return end;clean.ids[i]=id;seen[id]=true end
    end
    if op=="UseTicket" then
        -- Free round tickets first, then saved (bought) tickets. A ticket is
        -- spent only after the round confirms the admin panel can open.
        local uid=tostring(player.UserId)
        local ok,message=State.canUseTicket(session.state,uid)
        if ok then
            if State.spendRoundTicket(session.state,uid) or Perks.consume(player,"Ticket") then
                ok,message=State.useTicket(session.state,uid)
            else ok=false;message="You have no tickets. Get more in the shop!" end
        end
        session.sequence=session.sequence+1;send(session,player,message);return
    end
    if wishOps[op] and not State.canWish(session.state,tostring(player.UserId),op,clean.eventId) then return end
    local ok,message=State.action(session.state,tostring(player.UserId),op,clean)
    local draft=op=="WishDraft" or op=="AppendDraft"
    if not draft or not ok then session.sequence=session.sequence+1;send(session,player,message) end
end)
local function added(player)
    if addedPlayers[player] then return end;addedPlayers[player]=true
    player.RespawnLocation=lobbySpawn;leave(player,false)
    player.CharacterAdded:Connect(function(character)
        task.spawn(function()
        character:WaitForChild("HumanoidRootPart",10);character:WaitForChild("Humanoid",10)
        if player.Character~=character or player.Parent~=Players then return end
        -- lobby: 2.5x the default walk speed (conceal() saves and restores it around rounds)
        local humanoid=character:FindFirstChildOfClass("Humanoid")
        if humanoid and not hidden[player] then humanoid.WalkSpeed=LOBBY_WALK_SPEED end
        local session=membership[player]
        if session and session.world and session.world.players[tostring(player.UserId)] then
            task.defer(function()
                local v=session.world and session.world.players[tostring(player.UserId)]
                if membership[player]==session and v then
                    move(player,CFrame.new(v.home+Vector3.new(0,4,0)));conceal(player)
                end
            end)
        elseif not session then
            -- CharacterAdded can fire while launch is still constructing World/state.
            -- Keep a queued solo session alive; launch owns the first move/conceal.
            leave(player,false)
        end
        end)
    end)
end
Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(function(player) for _,room in ipairs(rooms) do leaveQueue(room,player) end;leave(player,false);limits[player]=nil;addedPlayers[player]=nil;queueSuppressed[player]=nil;lobbyRate[player]=nil end)
for _,player in ipairs(Players:GetPlayers()) do added(player) end
local simClock,queueClock,snapshotClock=0,0,0
RunService.Heartbeat:Connect(function(dt)
    simClock=simClock+math.min(dt,0.5);queueClock=queueClock+dt;snapshotClock=snapshotClock+dt
    local steps=0
    while simClock>=0.1 and steps<5 do
        simClock=simClock-0.1;steps=steps+1
        for _,session in pairs(sessions) do
            if session.state then
                local ok,err=pcall(function()
                    State.step(session.state,0.1);if session.bots then Bots.step(session.bots,0.1) end
                    for _,job in ipairs(WishRules.pending(session.state)) do
                        local author=Players:GetPlayerByUserId(tonumber(job.uid) or 0)
                        if not author or membership[author]~=session then
                            WishRules.approve(session.state,job.uid,job.eventId,job.phase,nil)
                        else
                            task.spawn(function()
                                local filtered=filterPublic(author,job.text)
                                if sessions[session.token]==session and membership[author]==session then
                                    WishRules.approve(session.state,job.uid,job.eventId,job.phase,filtered)
                                    session.sequence=session.sequence+1
                                    for p in pairs(session.players) do send(session,p,nil) end
                                end
                            end)
                        end
                    end
                    -- the final admin command goes to Gemini; no answer -> local interpreter
                    local think=WishRules.thinking(session.state)
                    if think then
                        task.spawn(function()
                            local plan=Brain.ask(think)
                            if type(plan)=="table" then
                                local viewer=Players:GetPlayerByUserId(tonumber(think.authorUid) or 0)
                                if not viewer or membership[viewer]~=session then viewer=next(session.players) end
                                -- AI text is shown to everyone, so it goes through the same filter as player text
                                for _,key in ipairs({"caption","reason"}) do
                                    if type(plan[key])=="string" then plan[key]=viewer and filterPublic(viewer,plan[key]) or nil end
                                end
                                if type(plan.actions)=="table" then
                                    for _,action in ipairs(plan.actions) do
                                        if type(action)=="table" and type(action.text)=="string" then action.text=viewer and filterPublic(viewer,action.text) or nil end
                                    end
                                end
                            end
                            if sessions[session.token]==session and session.state then
                                WishRules.resolve(session.state,think.eventId,plan)
                                session.sequence=session.sequence+1
                                for p in pairs(session.players) do send(session,p,nil) end
                            end
                        end)
                    end
                    local effects=session.state.fx
                    if effects and #effects>0 then
                        session.state.fx={}
                        for p in pairs(session.players) do if p.Parent==Players then AdminFX:FireClient(p,effects) end end
                    end
                    local rendered,renderError=pcall(World.sync,session.world,session.state)
                    if not rendered and os.clock()-(session.lastRenderWarning or -100)>5 then
                        session.lastRenderWarning=os.clock();warn("[ArmyRound] Presentation retry; state preserved: "..tostring(renderError))
                    end
                    local eliminated={}
                    if session.state.status=="Active" then
                        for player in pairs(session.players) do
                            local p=session.state.players[tostring(player.UserId)]
                            if p and p.defeated then
                                session.defeatedAt[player]=session.defeatedAt[player] or os.clock()
                                if os.clock()-session.defeatedAt[player]>=5 then eliminated[#eliminated+1]=player end
                            end
                        end
                    end
                    for _,player in ipairs(eliminated) do coveredLeave(session,player) end
                    if session.state.status=="Ended" then
                        if not session.endedAt then session.endedAt=os.clock() end
                        if os.clock()-session.endedAt>=RESULT_SECONDS then coveredFinish(session) end
                    end
                end)
                if not ok then warn("[ArmyRound] Simulation stopped safely: "..tostring(err));finish(session) end
            end
        end
    end
    if snapshotClock>=0.3 then
        snapshotClock=0
        for _,session in pairs(sessions) do if session.state then
            session.sequence=session.sequence+1
            for player in pairs(session.players) do send(session,player,nil) end
        end end
    end
    if queueClock>=0.2 then
        local qdt=queueClock;queueClock=0
        local list=Players:GetPlayers();table.sort(list,function(a,b) return a.UserId<b.UserId end)
        local now=os.clock()
        -- anybody who falls off the island into the water is brought back to the spawn
        for _,player in ipairs(list) do
            local r=not membership[player] and root(player)
            if r and r.Position.Y<LOBBY_WATER_Y-1.5 and math.abs(r.Position.X)<1500 and math.abs(r.Position.Z)<1500 then
                move(player,lobbySpawn.CFrame+Vector3.new(0,4,0))
            end
        end
        for _,room in ipairs(rooms) do
            if not room.busy then
                local candidates={}
                for _,player in ipairs(list) do
                    local r=root(player);local inside=r and inPad(room,r)
                    local suppressed=queueSuppressed[player]
                    -- LEAVE blocks re-entry for two seconds only; walking back in afterwards re-queues.
                    if suppressed and suppressed.room==room.id and now>=suppressed.untilTime then queueSuppressed[player]=nil;suppressed=nil end
                    if not membership[player] and inside and not (suppressed and suppressed.room==room.id) and player:GetAttribute("ScenePhase")~="Transferring" then candidates[#candidates+1]=player end
                end
                local departed,rejected=Queue.reconcile(room,candidates,MAX_PLAYERS)
                for _,player in ipairs(rejected) do
                    local exit=room.model:FindFirstChild("LeaveHere",true)
                    move(player,exit and exit.CFrame+Vector3.new(0,2,0) or lobbySpawn.CFrame+Vector3.new(0,4,0))
                end
                for _,player in ipairs(departed) do
                    if player.Parent==Players then Snapshot:FireClient(player,{lobby={room=room.id,left=true}}) end
                end
                local group=Queue.advance(room,qdt,COUNTDOWN)
                local n=playerCount(room.queued)
                label(room,n,not room.host and "" or not room.capacity and "CHOOSE" or math.ceil(room.remaining or COUNTDOWN))
                sendLobby(room)
                if group and #group>0 then
                    room.queued={};room.order={}
                    -- 1) close the curtain on every client, 2) build and move once it is shut
                    room.busy=true;room.deadline=nil;room.remaining=nil
                    for _,p in ipairs(group) do if p.Parent==Players then p:SetAttribute("ScenePhase","Transferring") end end
                    label(room,#group,"...")
                    task.delay(COVER_SECONDS,function()
                        -- A crash while launching must never leave a room stuck.
                        local launched,crash=pcall(launch,room,group,true)
                        if not launched then
                            warn("[ArmyRound] Launch crashed safely: "..tostring(crash))
                            local session=room.launching
                            if session then pcall(finish,session) end
                            resetRoom(room)
                            for _,p in ipairs(group) do if p.Parent==Players and not membership[p] then p:SetAttribute("ScenePhase","Lobby") end end
                            label(room,0,COUNTDOWN)
                        end
                    end)
                end
            else
                for _,player in ipairs(list) do
                    local r=root(player)
                    if not membership[player] and r and inPad(room,r) and player:GetAttribute("ScenePhase")~="Transferring" then
                        local exit=room.model:FindFirstChild("LeaveHere",true)
                        move(player,exit and exit.CFrame+Vector3.new(0,2,0) or lobbySpawn.CFrame+Vector3.new(0,4,0))
                    end
                end
            end
        end
    end
end)
print("[ArmyRound] Ready: fresh English conquest rounds, neutral islands, eight resource counters.")

