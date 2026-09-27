-- Apply the donor lighting presets while keeping water styling local and bounded.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
local environments = ReplicatedStorage:WaitForChild("SceneEnvironments", 15)
if not environments then warn("[SourceScene] Missing environment data"); return end
local previous=nil
local waterOriginal={}
local function isWater(object)
    if not object:IsA("BasePart") then return false end
    if object:GetAttribute("RoundWater")==true then return true end
    local n=object.Name:lower()
    -- Exact surface names only; never match a whole island/terrain model merely
    -- because a descendant happens to contain the word "water".
    return n=="water" or n=="oceantop" or n=="riversurface" or n=="pondsurface" or n=="lakesurface"
end
local function styleObject(object,enabled)
    if not isWater(object) then return end
    if enabled then
        if not waterOriginal[object] then waterOriginal[object]={Color=object.Color,Material=object.Material,Transparency=object.Transparency,Reflectance=object.Reflectance} end
        object:SetAttribute("RoundWater",true)
        object.Material=Enum.Material.SmoothPlastic;object.Color=Color3.fromRGB(45,181,220);object.Transparency=math.min(object.Transparency,.18);object.Reflectance=.12
    elseif waterOriginal[object] then
        local old=waterOriginal[object];object.Color=old.Color;object.Material=old.Material;object.Transparency=old.Transparency;object.Reflectance=old.Reflectance;waterOriginal[object]=nil
    end
end
local function styleWater(enabled)
    for _,object in ipairs(Workspace:GetDescendants()) do styleObject(object,enabled) end
end
-- MusicController owns the two soundtrack objects.  Lighting changes must not
-- restart or replace the active song.
local function playMusic(_) end
local function apply()
    local target = player:GetAttribute("ScenePhase") == "Round" and "Army" or "Lobby"
    if previous == target then return end
    local folder = environments:FindFirstChild(target)
    if not folder then return end
    previous = target
    for _, object in ipairs(Lighting:GetChildren()) do
        if object:IsA("Sky") or object:IsA("Atmosphere") or object:IsA("PostEffect") then object:Destroy() end
    end
    for _, object in ipairs(folder:GetChildren()) do
        if object:IsA("ValueBase") then
            local ok,err=pcall(function() Lighting[object.Name]=object.Value end)
            if not ok then warn("[SourceScene] Lighting: "..object.Name..": "..tostring(err)) end
        else object:Clone().Parent=Lighting end
    end
    styleWater(target=="Army")
    playMusic(target)
end
player:GetAttributeChangedSignal("ScenePhase"):Connect(apply)
Workspace.DescendantAdded:Connect(function(object)
    if previous=="Army" then task.defer(function() styleObject(object,true) end) end
end)
-- A sound inserted by a streamed model must not reintroduce combat effects.
SoundService.DescendantAdded:Connect(function(object)
    if not object:IsA("Sound") then return end
    if object.Name=="LobbyMusic" or object.Name=="RoundMusic" or object.Name=="TitleMusic" or object.Name:sub(1,3)=="UI_" then return end
    object:Stop();object.Playing=false;object.Volume=0
end)
apply()
