-- UI sounds: every GuiButton clicks automatically; code can also play cues.
-- Each cue tries its candidates in order and keeps the first that loads, so a
-- missing asset never breaks anything. Replace ids here to change the sounds.
local SoundService=game:GetService('SoundService')
local ContentProvider=game:GetService('ContentProvider')
local UISound={}
local DEF={
    click={volume=.5,ids={'rbxasset://sounds/clickfast.wav','rbxassetid://12221967','rbxasset://sounds/electronicpingshort.wav'}},
    open={volume=.45,ids={'rbxasset://sounds/swoosh.wav','rbxasset://sounds/clickfast.wav'}},
    success={volume=.6,ids={'rbxasset://sounds/electronicpingshort.wav','rbxassetid://12221967'}},
    whoosh={volume=.35,ids={'rbxasset://sounds/swoosh.wav'}},
}
local sounds={}
local started=false
local function load(kind,def)
    local s=Instance.new('Sound');s.Name='UI_'..kind;s.Volume=def.volume;s.Parent=SoundService
    sounds[kind]=s
    task.spawn(function()
        for _,id in ipairs(def.ids) do
            s.SoundId=id
            local ok=false
            pcall(function()
                ContentProvider:PreloadAsync({s},function(_,status) ok=status==Enum.AssetFetchStatus.Success end)
            end)
            if ok or s.IsLoaded then return end
        end
    end)
end
function UISound.play(kind)
    local s=sounds[kind or 'click']
    if s and s.SoundId~='' then pcall(function() SoundService:PlayLocalSound(s) end) end
end
-- Hook every button inside `root` (now and later). A button may pick its cue
-- with the attribute UISound = "open" / "success" / "none".
function UISound.init(root)
    if not started then started=true;for kind,def in pairs(DEF) do load(kind,def) end end
    local hooked=setmetatable({},{__mode='k'})
    local function hook(o)
        if o:IsA('GuiButton') and not hooked[o] then
            hooked[o]=true
            o.Activated:Connect(function()
                local cue=o:GetAttribute('UISound') or 'click'
                if cue~='none' then UISound.play(cue) end
            end)
        end
    end
    for _,d in ipairs(root:GetDescendants()) do hook(d) end
    root.DescendantAdded:Connect(hook)
end
return UISound
