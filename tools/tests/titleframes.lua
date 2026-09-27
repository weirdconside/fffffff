do local m=Instance.new("ModuleScript");m.Name="TitleLogo";m.Parent=game:GetService("ReplicatedFirst") end
camera.ViewportSize=Vector2.new(__VPW,__VPH)
local char=Instance.new("Model");local hrp=Instance.new("Part");hrp.Name="HumanoidRootPart";hrp.Parent=char;localPlayer.Character=char
for name in pairs(__modules) do local m=Instance.new("ModuleScript");m.Name=name;m.Parent=shared end
local function frames(n) for i=1,n do clockValue=clockValue+0.016;runService.RenderStepped:Fire(0.016);runService.Heartbeat:Fire(0.016);runDeferred(clockValue) end end
__scripts.TitleScreen()
local snd=game:GetService("SoundService"):FindFirstChild("TitleMusic")
snd.IsLoaded=true;snd.TimeLength=32.55
local playing=false
local oldPlay=snd.Play
snd.Play=function() playing=true;snd.IsPlaying=true end
runService.RenderStepped:Connect(function(dt) if playing then snd.TimePosition=(snd.TimePosition+dt)%snd.TimeLength end end)
local gui=playerGui:FindFirstChild("TitleScreen")
dumpGui("t_loading",{gui})
local guard=0
while not playing and guard<2000 do frames(1);guard=guard+1 end
print("started after frames",guard)
for _,target in ipairs({0.3,0.62,0.9,1.1,1.3,1.62,1.9,2.2,2.6,2.9,3.1,3.3,3.5,3.9}) do
    local g2=0
    while snd.TimePosition<target and g2<2000 do frames(1);g2=g2+1 end
    dumpGui(string.format("t_%05.2f",target),{gui})
end
print("ERRORS:",#ERRORS)
