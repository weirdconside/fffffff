-- Original procedural presentation. Cosmetic only: no client damage, movement orders,
-- money or ownership. Anchored logical roots stay server-controlled. Every body/tool
-- uses a recorded rest pose, so animation never accumulates transform drift.
local A={};A.__index=A
local Workspace=game:GetService("Workspace")
local function now() return Workspace:GetServerTimeNow() end
local function ease(t) t=math.clamp(t,0,1);return 1-(1-t)^3 end
local function parts(model)
    local list=model:GetDescendants();if model:IsA("BasePart") then list[#list+1]=model end
    local result={};for _,p in ipairs(list) do if p:IsA("BasePart") then result[#result+1]=p end end
    return result
end
local function pivot(o) return o:IsA("BasePart") and o.CFrame or o:GetPivot() end
local function transformAbout(at,rotation) return CFrame.new(at)*rotation*CFrame.new(-at) end
-- Exported pose calculation is also exercised by the deterministic pose tests.
function A.pose(kind,mode,clock,moving,attackAge)
    local stride=math.sin(clock*(kind=="Giant" and 7 or 13))
    local walk=moving and 1 or 0
    local p={RLeg=.64*stride*walk,LLeg=-.64*stride*walk,RArm=-.53*stride*walk,LArm=.53*stride*walk,
        lean=moving and .07 or 0,bob=moving and math.abs(stride)*.045 or math.sin(clock*2.4)*.014,twist=0,head=math.sin(clock*1.3)*.025}
    if mode=="Chopping" or mode=="Building" then
        local hit=(math.sin(clock*8.5)+1)/2
        p.RArm=-1.75+2.1*hit;p.LArm=-.35;p.lean=.08+.14*hit;p.twist=.09*math.sin(clock*8.5)
    elseif mode=="Carrying" then p.LArm=-.7;p.RArm=-.55+stride*.16*walk end
    -- Attack poses blend from the locomotion pose and return to it at the end.
    -- This removes the one-frame arm snap seen when attackSerial changes.
    if attackAge and attackAge>=0 and attackAge<.65 then
        local phase=math.clamp(attackAge/.65,0,1);local blend=math.sin(phase*math.pi)
        local target={RArm=p.RArm,LArm=p.LArm,lean=p.lean,twist=p.twist,bob=p.bob}
        if kind=="Archer" then target.RArm=-1.35+.7*math.sin(phase*math.pi);target.LArm=-1.25;target.twist=-.18*math.sin(phase*math.pi)
        elseif kind=="Wizard" then target.RArm=-1.6*math.sin(phase*math.pi);target.LArm=-1.6*math.sin(phase*math.pi);target.bob=p.bob+.08*math.sin(phase*math.pi)
        elseif kind=="Giant" then target.RArm=-2.1*math.sin(phase*math.pi);target.LArm=-2.1*math.sin(phase*math.pi);target.lean=.27*math.sin(phase*math.pi)
        else target.RArm=-2+3*ease(phase);target.LArm=-.45;target.twist=.22*math.sin(phase*math.pi) end
        p.RArm=p.RArm+(target.RArm-p.RArm)*blend;p.LArm=p.LArm+(target.LArm-p.LArm)*blend
        p.lean=p.lean+(target.lean-p.lean)*blend;p.twist=p.twist+(target.twist-p.twist)*blend;p.bob=p.bob+(target.bob-p.bob)*blend
    end
    return p
end

function A.new(world)
    local self=setmetatable({world=world,rigs={},effects={},connections={},watched={},pending={},elapsed=0,projectiles={},pulses={},nature={},natureByObject={}},A)
    self.fx=Instance.new("Folder");self.fx.Name="LocalRoundEffects";self.fx.Parent=world
    -- Only explicitly tagged roots are animated. Never climb to Land/plot
    -- parents: doing so pivots the whole terrain when a tree sways.
    local function addNature(o)
        if not (o:IsA("Model") or o:IsA("BasePart")) or self.natureByObject[o] then return end
        local wind=o:GetAttribute("RoundWind")==true
        local water=o:GetAttribute("RoundWater")==true
        if not wind and not water then return end
        local base=o:IsA("BasePart") and o.CFrame or o:GetPivot()
        local entry={object=o,base=base,wind=wind,water=water,seed=(#self.nature+1)*.73,amplitude=o:GetAttribute("RoundWindAmplitude") or .025,baseColor=o:IsA("BasePart") and o.Color or nil}
        self.nature[#self.nature+1]=entry;self.natureByObject[o]=entry
    end
    for _,o in ipairs(world:GetDescendants()) do addNature(o) end
    local function watch(o)
        if not o:IsA("Model") and not o:IsA("BasePart") then return end
        local parent=o.Parent
        local root=parent and parent.Name
        local candidate=o:GetAttribute("RoundUnit") or o:GetAttribute("RoundEffectSerial")~=nil
            or root=="Units" or root=="Land" or root=="Components" or root=="Resources" or root=="Territories"
        if not candidate then return end
        self.pending[o]=true
        if self.watched[o] then return end
        self.watched[o]={
            o:GetAttributeChangedSignal("RoundEffectSerial"):Connect(function()self.pending[o]=true end),
            o:GetAttributeChangedSignal("RoundUnit"):Connect(function()self.pending[o]=true end)
        }
    end
    for _,o in ipairs(world:GetDescendants()) do watch(o) end
    self.connections[#self.connections+1]=world.DescendantAdded:Connect(function(o)
        addNature(o)
        watch(o)
        if o.Parent and o.Parent:IsA("Model") then watch(o.Parent);addNature(o.Parent) end
    end)
    return self
end
function A:register(model)
    if not model.Parent then return end
    if model:GetAttribute("RoundUnit") then
        local root=model:FindFirstChild("Root",true)
        local pose=model:GetAttribute("RoundPose")
        if not root or typeof(pose)~="CFrame" then self.pending[model]=true;return end
        local list={};local incomplete=false
        for _,p in ipairs(parts(model)) do
            local rest=p:GetAttribute("RoundRest")
            if typeof(rest)=="CFrame" then list[#list+1]={part=p,rest=rest,limb=p:GetAttribute("RoundLimb") or "Torso",hinge=p:GetAttribute("RoundHinge") or Vector3.new()}
            elseif p~=root and p.Transparency<1 then incomplete=true end
        end
        if #list==0 then self.pending[model]=true;return end
        if incomplete then self.pending[model]=true end
        if self.rigs[model] then self.rigs[model].parts=list
        else self.rigs[model]={model=model,root=root,parts=list,pose=pose,previous=pose.Position,attack=model:GetAttribute("RoundAttack") or 0,
            attackAt=-100,hp=model:GetAttribute("RoundHP") or 1,flashUntil=0,seed=(tonumber(model:GetAttribute("RoundUnit")) or 1)*.83} end
    end
    local serial=model:GetAttribute("RoundEffectSerial")
    if serial~=nil then
        local old=self.effects[model]
        local at=model:GetAttribute("RoundEffectAt") or 0
        if (not old or old.serial~=serial) and now()-at<2 then
            local kind=model:GetAttribute("RoundEffectKind")
            -- Structural geometry is server-owned. Previous rise effects rewrote
            -- every descendant CFrame and opacity, occasionally hiding houses.
            -- Only independent cosmetic particles are animated now.
            self.effects[model]={model=model,serial=serial,at=at,kind=kind,base={},done=true}
            if kind=="Capture" or kind=="Clear" or kind=="Collect" or kind=="Craft" or kind=="Research" or kind=="Building" or kind=="Land" or kind=="Bridge" then
                self:pulse(pivot(model).Position,kind)
            end
        end
    end
end
function A:shot(from,to,kind)
    if #self.projectiles>=80 or typeof(to)~="Vector3" then return end
    local p=Instance.new("Part");p.Name="CosmeticProjectile";p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
    p.Material=kind=="Wizard" and Enum.Material.Neon or Enum.Material.SmoothPlastic
    p.Color=kind=="Wizard" and Color3.fromRGB(174,120,255) or Color3.fromRGB(230,199,137)
    p.Size=kind=="Wizard" and Vector3.new(.3,.3,.3) or Vector3.new(.065,.065,.85)
    if kind=="Wizard" then p.Shape=Enum.PartType.Ball end
    p.CFrame=CFrame.new(from);p.Parent=self.fx
    self.projectiles[#self.projectiles+1]={part=p,from=from,to=to+Vector3.new(0,.65,0),age=0,duration=.26}
end
function A:pulse(position,kind)
    if #self.pulses>=30 then return end
    local colour=kind=="Capture" and Color3.fromRGB(94,233,154) or (kind=="Research" and Color3.fromRGB(154,130,255) or Color3.fromRGB(255,211,108))
    local ring={age=0,position=position,parts={},large=kind=="Capture" or kind=="Clear"}
    for i=1,12 do
        local p=Instance.new("Part");p.Name="Cosmetic"..kind;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
        p.CastShadow=false;p.Material=Enum.Material.Neon;p.Color=colour;p.Size=Vector3.new(.12,.12,.12);p.Parent=self.fx
        ring.parts[i]=p
    end
    self.pulses[#self.pulses+1]=ring
end
function A:step(dt,cameraPosition)
    dt=math.clamp(dt,0,.1);self.elapsed=self.elapsed+dt
    -- bookkeeping twice a second instead of every frame
    self.sweep=(self.sweep or 0)+dt
    if self.sweep>=.5 then
        self.sweep=0
        for model,connections in pairs(self.watched) do
            if not model.Parent then
                for _,connection in ipairs(connections) do connection:Disconnect() end
                self.watched[model]=nil;self.pending[model]=nil
            end
        end
    end
    local pending=self.pending;self.pending={}
    for model in pairs(pending) do self:register(model) end
    -- wind/water: 12 times a second and only near the camera (trees are many parts each)
    self.natureClock=(self.natureClock or 0)+dt
    local natureNow=self.natureClock>=1/12
    if natureNow then self.natureClock=0 end
    for _,n in ipairs(natureNow and self.nature or {}) do
        if n.object and n.object.Parent and (not cameraPosition or (n.base.Position-cameraPosition).Magnitude<170) then
            if n.wind then
                local sway=math.sin(self.elapsed*1.55+n.seed)*n.amplitude
                if n.object:IsA("BasePart") then n.object.CFrame=n.base*CFrame.Angles(0,0,sway)
                else n.object:PivotTo(n.base*CFrame.Angles(0,0,sway)) end
            elseif n.water and n.object:IsA("BasePart") and n.baseColor then
                -- Surface-only tint modulation gives a light wave shimmer without
                -- changing the colour or transform of terrain below it.
                local amount=.05+.025*math.sin(self.elapsed*1.9+n.seed)
                n.object.Color=n.baseColor:Lerp(Color3.fromRGB(72,196,226),amount)
            end
        end
    end
    for model,r in pairs(self.rigs) do
        if not model.Parent then self.rigs[model]=nil
        else
            local target=model:GetAttribute("RoundPose")
            if typeof(target)=="CFrame" then
                local far=cameraPosition and (target.Position-cameraPosition).Magnitude>280
                local hp=model:GetAttribute("RoundHP") or r.hp
                if hp<r.hp then r.flashUntil=self.elapsed+.16 end;r.hp=hp
                local attack=model:GetAttribute("RoundAttack") or 0
                local kind=model:GetAttribute("RoundKind") or "Barbarian"
                if attack~=r.attack then
                    r.attack=attack;r.attackAt=self.elapsed
                    if not far and (kind=="Archer" or kind=="Wizard") then self:shot(target.Position+Vector3.new(0,1.1,0),model:GetAttribute("RoundTarget"),kind) end
                end
                if not far then
                    r.pose=r.pose:Lerp(target,1-math.exp(-dt*18))
                    local dead=model:GetAttribute("RoundDead")
                    local moving=not dead and model:GetAttribute("RoundMoving")==true
                    local pose=A.pose(kind,model:GetAttribute("RoundMode") or "Idle",self.elapsed+r.seed,moving,self.elapsed-r.attackAt)
                    local death=dead and math.clamp((now()-(model:GetAttribute("RoundDeathAt") or now()))/.7,0,1) or 0
                    local age=now()-(model:GetAttribute("RoundBornAt") or 0)
                    local spawn=math.clamp(age/.45,0,1)
                    local fall=model:GetAttribute("RoundRole")=="Builder" and 0 or death
                    local body=CFrame.new(0,pose.bob-(1-ease(spawn))*.8-death*.5,0)*CFrame.Angles(pose.lean,pose.twist,fall*math.pi*.48)
                    for _,v in ipairs(r.parts) do
                        local p=v.part
                        if p.Parent then
                            local angle=pose[v.limb] or 0
                            local joint=transformAbout(v.hinge,CFrame.Angles(angle,v.limb=="Head" and pose.head or 0,0))
                            p.CFrame=r.pose*body*joint*v.rest
                            local fade=dead and death or (1-spawn)
                            if v.fade~=fade then v.fade=fade;p.LocalTransparencyModifier=fade end
                        end
                    end
                    if r.flashUntil>self.elapsed then
                        if not r.flash then r.flash=Instance.new("Highlight");r.flash.Name="DamageFlash";r.flash.Adornee=model;r.flash.OutlineTransparency=1;r.flash.FillColor=Color3.fromRGB(255,245,230);r.flash.Parent=model end
                        r.flash.Enabled=true;r.flash.FillTransparency=.45
                    elseif r.flash then r.flash.Enabled=false end
                end
            end
        end
    end
    for model in pairs(self.effects) do
        if not model.Parent then self.effects[model]=nil end
    end
    for i=#self.pulses,1,-1 do
        local pulse=self.pulses[i];pulse.age=pulse.age+dt
        local t=math.clamp(pulse.age/.75,0,1);local radius=(pulse.large and 4 or 1.4)*ease(t)+.25
        for index,p in ipairs(pulse.parts) do
            local angle=index*math.pi/6+t*.3
            p.CFrame=CFrame.new(pulse.position+Vector3.new(math.cos(angle)*radius,.2+t*1.8,math.sin(angle)*radius))
            p.Size=Vector3.new(.1,.1,.25+radius*.25);p.Transparency=t
        end
        if t>=1 then for _,p in ipairs(pulse.parts) do p:Destroy() end;table.remove(self.pulses,i) end
    end
    for i=#self.projectiles,1,-1 do
        local shot=self.projectiles[i];shot.age=shot.age+dt
        local t=math.clamp(shot.age/shot.duration,0,1)
        local pos=shot.from:Lerp(shot.to,t)+Vector3.new(0,math.sin(t*math.pi)*.65,0)
        local delta=shot.to-pos
        shot.part.CFrame=delta.Magnitude>.001 and CFrame.lookAt(pos,shot.to) or CFrame.new(pos)
        if t>=1 then shot.part:Destroy();table.remove(self.projectiles,i) end
    end
end
function A:destroy()
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    for _,connections in pairs(self.watched) do for _,connection in ipairs(connections) do connection:Disconnect() end end
    for model,r in pairs(self.rigs) do
        if model.Parent then for _,v in ipairs(r.parts) do if v.part.Parent then v.part.LocalTransparencyModifier=0 end end end
        if r.flash then r.flash:Destroy() end
    end
    for _,n in ipairs(self.nature) do
        if n.object and n.object.Parent then
            if n.object:IsA("BasePart") then n.object.CFrame=n.base else n.object:PivotTo(n.base) end
            if n.water and n.object:IsA("BasePart") and n.baseColor then n.object.Color=n.baseColor end
        end
    end
    if self.fx then self.fx:Destroy() end
    self.rigs={};self.effects={};self.pending={};self.connections={};self.watched={};self.projectiles={};self.pulses={};self.nature={};self.natureByObject={}
end
return A
