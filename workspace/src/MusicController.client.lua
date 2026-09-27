-- The active donor playlist uses public APM tracks.  The two old
-- GameMusics IDs in that place are private and fail with 403 in this experience.
-- Audio is intentionally independent of lighting and the round HUD.
local Players=game:GetService("Players")
local SoundService=game:GetService("SoundService")
local ContentProvider=game:GetService("ContentProvider")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer

local definitions={
    Lobby={name="LobbyMusic",volume=.30,ids={1836009208,1846088038,9045766074,1842150151}},
    Round={name="RoundMusic",volume=.32,ids={1842150151,9045766074,1836009208,1846088038}},
}
local tracks={}
local activeMode=nil
local sync

local function publish(record,status)
    player:SetAttribute(record.mode.."MusicStatus",status)
    player:SetAttribute(record.mode.."MusicTrackId",record.id or 0)
    player:SetAttribute(record.mode.."MusicIsLoaded",record.sound.IsLoaded)
    if record.mode==activeMode then
        player:SetAttribute("MusicStatus",status)
        player:SetAttribute("MusicTrackId",record.id or 0)
        player:SetAttribute("MusicIsLoaded",record.sound.IsLoaded)
    end
end

local function stop(record)
    if record.sound.IsPlaying then
        record.sound:Pause()
        record.paused=true
    end
end

local function play(record)
    local sound=record.sound
    if not record.ready or not sound.IsLoaded then return end
    sound.Volume=record.volume
    if not sound.IsPlaying then
        if record.paused then sound:Resume() else sound:Play() end
        record.paused=false
    end
    publish(record,"Playing")
end

sync=function()
    local mode=player:GetAttribute("ScenePhase")=="Round" and "Round" or "Lobby"
    activeMode=mode
    for key,record in pairs(tracks) do
        if key==mode then
            if record.ready then play(record) else publish(record,record.exhausted and "Unavailable" or "Loading") end
        else stop(record) end
    end
end

local function loadTrack(record)
    for _,id in ipairs(record.ids) do
        record.ready=false
        record.id=id
        record.paused=false
        local sound=record.sound
        sound:Stop()
        sound.SoundId="rbxassetid://"..tostring(id)
        sound.TimePosition=0
        publish(record,"Loading")
        local finished,failed=false,false
        task.spawn(function()
            local ok,err=pcall(function()
                ContentProvider:PreloadAsync({sound},function(_,status)
                    if status~=Enum.AssetFetchStatus.Success then failed=true end
                end)
            end)
            if not ok then
                failed=true
                warn("[BattleMusic] Preload error for "..tostring(id)..": "..tostring(err))
            end
            finished=true
        end)
        local started=os.clock()
        while not sound.IsLoaded and os.clock()-started<10 and not (finished and failed) do
            task.wait(.1)
        end
        if sound.IsLoaded then
            record.ready=true
            publish(record,"Ready")
            print("[BattleMusic] Ready "..record.mode.." rbxassetid://"..tostring(id))
            sync()
            return
        end
        warn("[BattleMusic] Could not load "..record.mode.." rbxassetid://"..tostring(id).."; trying the next public donor track")
    end
    record.exhausted=true
    publish(record,"Unavailable")
    warn("[BattleMusic] All public donor tracks failed for "..record.mode)
end

for mode,definition in pairs(definitions) do
    local sound=SoundService:FindFirstChild(definition.name)
    if sound and not sound:IsA("Sound") then sound=nil end
    if not sound then
        sound=Instance.new("Sound")
        sound.Name=definition.name
        sound.Parent=SoundService
    end
    -- Music is a global 2D Sound, outside the world and any stale muted group.
    sound.SoundGroup=nil
    sound.Looped=true
    sound.PlaybackSpeed=1
    sound.Volume=definition.volume
    local record={mode=mode,sound=sound,volume=definition.volume,ids=definition.ids,ready=false,paused=false}
    tracks[mode]=record
end

player:GetAttributeChangedSignal("ScenePhase"):Connect(sync)
sync()
for _,record in pairs(tracks) do task.spawn(loadTrack,record) end

-- A check repairs an interrupted track without restarting music that is already
-- playing.  Switching phases pauses the previous song and resumes it on return.
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
    elapsed+=dt
    if elapsed<2 then return end
    elapsed=0
    sync()
end)
