-- Harbour ambience: cosmetic, client-only motion for the lobby island.
-- Nothing here touches gameplay; all objects stay anchored on the server.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local CollectionService=game:GetService("CollectionService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local lobby=Workspace:WaitForChild("LobbyWorld",60)
if not lobby then return end
local RANGE=380
local spinners,flags,sails,trees,textures={},{},{},{},{}
local function center(model)
    local ok,cf,size=pcall(function() return model:GetBoundingBox() end)
    if ok then return cf,size end
    return model:GetPivot(),Vector3.new(4,4,4)
end
for i,m in ipairs(CollectionService:GetTagged("LobbySpin")) do
    if m:IsA("Model") and m:IsDescendantOf(lobby) then
        local cf=center(m)
        local hub=CFrame.new(cf.Position)
        local parts={}
        for _,p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then parts[#parts+1]={part=p,offset=hub:ToObjectSpace(p.CFrame)} end end
        spinners[#spinners+1]={hub=hub,parts=parts,speed=m.Name=="Beacon" and 1.1 or .45}
    end
end
for i,p in ipairs(CollectionService:GetTagged("LobbyFlag")) do
    if p:IsA("BasePart") and p:IsDescendantOf(lobby) then
        local hinge=p.CFrame*CFrame.new(0,0,p.Size.Z/2)
        flags[#flags+1]={part=p,base=p.CFrame,hinge=hinge,rel=hinge:ToObjectSpace(p.CFrame),seed=i*1.9}
    end
end
for i,p in ipairs(CollectionService:GetTagged("LobbySail")) do
    if p:IsA("BasePart") and p:IsDescendantOf(lobby) then sails[#sails+1]={part=p,base=p.CFrame,seed=i*.7} end
end
-- Lobby figures (tag LobbyNPC) are statues: they keep their pose and never move.
for i,m in ipairs(CollectionService:GetTagged("LobbyTree")) do
    if m:IsA("Model") and m:IsDescendantOf(lobby) then
        local cf,size=center(m)
        trees[#trees+1]={model=m,base=m:GetPivot(),root=CFrame.new(cf.Position-Vector3.new(0,size.Y/2,0)),seed=i*.37}
    end
end
local ocean=lobby:FindFirstChild("Ocean",true)
if ocean then for _,t in ipairs(ocean:GetDescendants()) do if t:IsA("Texture") then textures[#textures+1]={texture=t,u=t.OffsetStudsU,v=t.OffsetStudsV,speed=#textures%2==0 and 1.2 or -.8} end end end
local function near(position,cam) return (position-cam).Magnitude<RANGE end
local clock,slow=0,0
RunService.RenderStepped:Connect(function(dt)
    if player:GetAttribute("ScenePhase")=="Round" then return end
    clock+=dt;slow+=dt
    local camera=Workspace.CurrentCamera;if not camera then return end
    local cam=camera.CFrame.Position
    for _,s in ipairs(spinners) do
        if near(s.hub.Position,cam) then
            local rot=s.hub*CFrame.Angles(0,clock*s.speed,0)
            for _,entry in ipairs(s.parts) do entry.part.CFrame=rot*entry.offset end
        end
    end
    for _,f in ipairs(flags) do
        if near(f.base.Position,cam) then
            local wave=math.sin(clock*3.1+f.seed)*.22+math.sin(clock*7.3+f.seed)*.05
            f.part.CFrame=f.hinge*CFrame.Angles(0,wave,0)*f.rel
        end
    end
    for _,s in ipairs(sails) do
        if near(s.base.Position,cam) then s.part.CFrame=s.base*CFrame.new(math.sin(clock*1.3+s.seed)*.14,0,0) end
    end
    for _,t in ipairs(textures) do
        t.texture.OffsetStudsU=t.u+clock*t.speed;t.texture.OffsetStudsV=t.v+clock*t.speed*.5
    end
    if slow<1/20 then return end
    slow=0
    for _,tr in ipairs(trees) do
        if tr.model.Parent and near(tr.root.Position,cam) then
            local sway=tr.root*CFrame.Angles(math.sin(clock*1.1+tr.seed)*.018,0,math.cos(clock*.9+tr.seed)*.022)*tr.root:Inverse()
            tr.model:PivotTo(sway*tr.base)
        end
    end
end)
