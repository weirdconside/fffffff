-- Minimal Roblox API mock for smoke-testing UI/client code under the Luau CLI.
local __modules,__cache={},{}
local clockValue=0
local ERRORS={}
local task_wait
local function report(msg) ERRORS[#ERRORS+1]=msg;print("ERROR: "..tostring(msg)) end
-- ---------------------------------------------------------------- signals
local Signal={};Signal.__index=Signal
local function newSignal() return setmetatable({handlers={}},Signal) end
function Signal:Connect(fn) local h={fn=fn,connected=true};table.insert(self.handlers,h);return {Disconnect=function() h.connected=false end,Connected=true} end
function Signal:Once(fn) return self:Connect(fn) end
function Signal:Fire(...) for _,h in ipairs(self.handlers) do if h.connected then local ok,e=pcall(h.fn,...);if not ok then report(e) end end end end
function Signal:Wait() return task_wait(0.016) end
-- ---------------------------------------------------------------- datatypes
local function num(x) return type(x)=="number" and x or 0 end
local Vector3={};local V3mt={}
V3mt.__index=function(v,k)
    if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
    if k=="Unit" then local m=math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z);if m==0 then return Vector3.new() end;return Vector3.new(v.X/m,v.Y/m,v.Z/m) end
    if k=="Dot" then return function(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
    if k=="Cross" then return function(a,b) return Vector3.new(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X) end end
    if k=="Lerp" then return function(a,b,t) return a+(b-a)*t end end
    return nil
end
V3mt.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
V3mt.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
V3mt.__mul=function(a,b) if type(a)=="number" then a,b=b,a end;if type(b)=="number" then return Vector3.new(a.X*b,a.Y*b,a.Z*b) end;return Vector3.new(a.X*b.X,a.Y*b.Y,a.Z*b.Z) end
V3mt.__div=function(a,b) if type(b)=="number" then return Vector3.new(a.X/b,a.Y/b,a.Z/b) end;return Vector3.new(a.X/b.X,a.Y/b.Y,a.Z/b.Z) end
V3mt.__unm=function(a) return Vector3.new(-a.X,-a.Y,-a.Z) end
V3mt.__eq=function(a,b) return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
V3mt.__tostring=function(v) return ("V3(%g,%g,%g)"):format(v.X,v.Y,v.Z) end
function Vector3.new(x,y,z) return setmetatable({X=num(x),Y=num(y),Z=num(z),__type="Vector3"},V3mt) end
Vector3.zero=Vector3.new();Vector3.one=Vector3.new(1,1,1);Vector3.yAxis=Vector3.new(0,1,0)
local Vector2={};local V2mt={}
V2mt.__index=function(v,k) if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y) end end
V2mt.__add=function(a,b) return Vector2.new(a.X+b.X,a.Y+b.Y) end
V2mt.__sub=function(a,b) return Vector2.new(a.X-b.X,a.Y-b.Y) end
V2mt.__mul=function(a,b) if type(a)=="number" then a,b=b,a end;if type(b)=="number" then return Vector2.new(a.X*b,a.Y*b) end;return Vector2.new(a.X*b.X,a.Y*b.Y) end
V2mt.__div=function(a,b) return Vector2.new(a.X/b,a.Y/b) end
function Vector2.new(x,y) return setmetatable({X=num(x),Y=num(y),__type="Vector2"},V2mt) end
Vector2.zero=Vector2.new()
-- CFrame: rotation matrix r (row-major 3x3) + position p
local CFrame={};local CFmt={}
local function cf(p,r) return setmetatable({p=p,r=r,__type="CFrame"},CFmt) end
local function matmul(a,b) local o={};for i=0,2 do for j=0,2 do local s=0;for k=0,2 do s=s+a[i*3+k+1]*b[k*3+j+1] end;o[i*3+j+1]=s end end;return o end
local function rotv(r,v) return Vector3.new(r[1]*v.X+r[2]*v.Y+r[3]*v.Z,r[4]*v.X+r[5]*v.Y+r[6]*v.Z,r[7]*v.X+r[8]*v.Y+r[9]*v.Z) end
local function transpose(r) return {r[1],r[4],r[7],r[2],r[5],r[8],r[3],r[6],r[9]} end
local I={1,0,0,0,1,0,0,0,1}
CFmt.__index=function(c,k)
    if k=="Position" then return c.p end
    if k=="X" then return c.p.X elseif k=="Y" then return c.p.Y elseif k=="Z" then return c.p.Z end
    if k=="LookVector" then return Vector3.new(-c.r[3],-c.r[6],-c.r[9]) end
    if k=="RightVector" then return Vector3.new(c.r[1],c.r[4],c.r[7]) end
    if k=="UpVector" then return Vector3.new(c.r[2],c.r[5],c.r[8]) end
    if k=="Inverse" then return function(s) local rt=transpose(s.r);return cf(-rotv(rt,s.p),rt) end end
    if k=="ToObjectSpace" then return function(s,o) return s:Inverse()*o end end
    if k=="ToWorldSpace" then return function(s,o) return s*o end end
    if k=="PointToObjectSpace" then return function(s,v) return s:Inverse()*v end end
    if k=="PointToWorldSpace" then return function(s,v) return s*v end end
    if k=="Lerp" then return function(a,b,t) return cf(a.p+(b.p-a.p)*t,a.r) end end
    return nil
end
CFmt.__mul=function(a,b)
    if type(b)=="table" and b.__type=="CFrame" then return cf(a.p+rotv(a.r,b.p),matmul(a.r,b.r)) end
    if type(b)=="table" and b.__type=="Vector3" then return a.p+rotv(a.r,b) end
    error("bad CFrame mul")
end
CFmt.__add=function(a,v) return cf(a.p+v,a.r) end
CFmt.__sub=function(a,v) return cf(a.p-v,a.r) end
function CFrame.new(x,y,z)
    if type(x)=="table" and x.__type=="Vector3" then return cf(x,I) end
    return cf(Vector3.new(x,y,z),I)
end
function CFrame.Angles(rx,ry,rz)
    local cx,sx,cy,sy,cz,sz=math.cos(rx),math.sin(rx),math.cos(ry),math.sin(ry),math.cos(rz),math.sin(rz)
    local X={1,0,0,0,cx,-sx,0,sx,cx};local Y={cy,0,sy,0,1,0,-sy,0,cy};local Z={cz,-sz,0,sz,cz,0,0,0,1}
    return cf(Vector3.new(),matmul(matmul(X,Y),Z))
end
CFrame.fromEulerAnglesXYZ=CFrame.Angles
function CFrame.fromAxisAngle(axis,a) return CFrame.Angles(axis.X*a,axis.Y*a,axis.Z*a) end
function CFrame.lookAt(eye,target)
    local f=(target-eye).Unit;local r=f:Cross(Vector3.new(0,1,0)).Unit;local u=r:Cross(f)
    return cf(eye,{r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z})
end
CFrame.identity=CFrame.new()
local UDim={};function UDim.new(s,o) return {Scale=num(s),Offset=num(o),__type="UDim"} end
local UDim2={};local U2mt={}
U2mt.__add=function(a,b) return UDim2.new(a.X.Scale+b.X.Scale,a.X.Offset+b.X.Offset,a.Y.Scale+b.Y.Scale,a.Y.Offset+b.Y.Offset) end
U2mt.__sub=function(a,b) return UDim2.new(a.X.Scale-b.X.Scale,a.X.Offset-b.X.Offset,a.Y.Scale-b.Y.Scale,a.Y.Offset-b.Y.Offset) end
function UDim2.new(xs,xo,ys,yo) return setmetatable({X=UDim.new(xs,xo),Y=UDim.new(ys,yo),Width=UDim.new(xs,xo),Height=UDim.new(ys,yo),__type="UDim2"},U2mt) end
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
local Color3={}
local C3mt={__index=function(c,k) if k=="Lerp" then return function(a,b,t) return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t) end end end}
function Color3.new(r,g,b) return setmetatable({R=num(r),G=num(g),B=num(b),__type="Color3"},C3mt) end
function Color3.fromRGB(r,g,b) return Color3.new(num(r)/255,num(g)/255,num(b)/255) end
function Color3.fromHSV(h,s,v) return Color3.new(v,v,v) end
local function seqctor(kind) return {new=function(...) return {__type=kind,args={...}} end} end
local NumberSequence=seqctor("NumberSequence");local ColorSequence=seqctor("ColorSequence")
local NumberSequenceKeypoint=seqctor("NSK");local ColorSequenceKeypoint=seqctor("CSK")
local NumberRange=seqctor("NumberRange");local Rect=seqctor("Rect");local TweenInfo=seqctor("TweenInfo")
local Font={new=function(f,w,s) return {__type="Font",Family=f,Weight=w,Style=s} end}
local RaycastParams={new=function() return {} end}
local PhysicalProperties={new=function() return {} end}
-- ---------------------------------------------------------------- Enum
local EnumItemMt={__tostring=function(e) return "Enum."..e.EnumType.."."..e.Name end}
local Enum=setmetatable({},{__index=function(t,enumName)
    local e=setmetatable({},{__index=function(t2,itemName)
        local it=setmetatable({Name=itemName,EnumType=enumName,Value=#itemName},EnumItemMt);rawset(t2,itemName,it);return it
    end})
    rawset(t,enumName,e);return e
end})
-- ---------------------------------------------------------------- Instances
local Instance={}
local instMt={}
local DEFAULTS={Visible=true,Enabled=true,Size=UDim2.new(),Position=UDim2.new(),AnchorPoint=Vector2.new(),Rotation=0,ZIndex=1,
    BackgroundTransparency=0,TextTransparency=0,ImageTransparency=0,TextSize=14,Text="",Transparency=0,Scale=1,
    AbsolutePosition=Vector2.new(100,100),AbsoluteSize=Vector2.new(200,100),Offset=Vector2.new(),Value=nil,
    CFrame=CFrame.new(),Anchored=true,CanCollide=true,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.new(1,1,1),
    CanvasPosition=Vector2.new(),ViewportSize=Vector2.new(1280,720),GroupTransparency=0,
    IsPlaying=false,IsLoaded=false,TimePosition=0,TimeLength=0,Volume=.5,SoundId=''}
local function newInstance(class,name)
    local o={__class=class,__props={Name=name or class,ClassName=class},__children={},__attrs={},__signals={},__attrSignals={},__propSignals={}}
    return setmetatable(o,instMt)
end
local methods={}
function methods:IsA(c) return self.__class==c or c=="Instance" or (c=="GuiObject" and (self.__class:find("Frame") or self.__class:find("Text") or self.__class:find("Image") or self.__class:find("Button")) ~= nil)
    or (c=="BasePart" and (self.__class=="Part" or self.__class=="WedgePart" or self.__class=="MeshPart")) or (c=="GuiButton" and self.__class:find("Button")~=nil)
    or (c=="LayerCollector" and self.__class:find("Gui")~=nil) end
function methods:FindFirstChild(n,rec)
    for _,c in ipairs(self.__children) do if c.Name==n then return c end end
    if rec then for _,c in ipairs(self.__children) do local f=c:FindFirstChild(n,true);if f then return f end end end
    return nil
end
function methods:WaitForChild(n) local c=self:FindFirstChild(n);if not c then report("WaitForChild would hang: "..tostring(n).." in "..tostring(self.Name)) end;return c end
function methods:FindFirstChildOfClass(c) for _,x in ipairs(self.__children) do if x.__class==c then return x end end end
function methods:FindFirstChildWhichIsA(c,rec) for _,x in ipairs(self:GetDescendants()) do if x:IsA(c) then return x end end end
function methods:GetChildren() local t={};for i,c in ipairs(self.__children) do t[i]=c end;return t end
function methods:GetDescendants() local t={};local function walk(o) for _,c in ipairs(o.__children) do t[#t+1]=c;walk(c) end end;walk(self);return t end
function methods:IsDescendantOf(a) local p=self.Parent;while p do if p==a then return true end;p=p.Parent end;return false end
function methods:Destroy() self.Parent=nil;self.__destroyed=true end
function methods:ClearAllChildren() for _,c in ipairs(self:GetChildren()) do c:Destroy() end end
function methods:Clone() return newInstance(self.__class,self.Name) end
function methods:SetAttribute(k,v) self.__attrs[k]=v;local s=self.__attrSignals[k];if s then s:Fire() end end
function methods:GetAttribute(k) return self.__attrs[k] end
function methods:GetAttributeChangedSignal(k) self.__attrSignals[k]=self.__attrSignals[k] or newSignal();return self.__attrSignals[k] end
function methods:GetPropertyChangedSignal(k) self.__propSignals[k]=self.__propSignals[k] or newSignal();return self.__propSignals[k] end
function methods:PivotTo(c) self.__pivot=c end
function methods:GetPivot() return self.__pivot or CFrame.new() end
function methods:GetBoundingBox() return CFrame.new(),Vector3.new(4,4,4) end
function methods:CaptureFocus() end
function methods:ReleaseFocus() end
function methods:IsFocused() return false end
function methods:Play() end
function methods:Stop() end
function methods:GetGuiObjectsAtPosition() return {} end
function methods:TweenPosition() end
function methods:WorldToViewportPoint(p) return Vector3.new(100,100,10),true end
function methods:ViewportPointToRay() return {Origin=Vector3.new(),Direction=Vector3.new(0,-1,0)} end
function methods:Raycast() return nil end
instMt.__index=function(o,k)
    local props=rawget(o,"__props")
    if type(props[k])=="function" then return props[k] end
    if methods[k] then return methods[k] end
    if k=="Parent" then return props.Parent end
    if props[k]~=nil then return props[k] end
    local child=o:FindFirstChild(k);if child then return child end
    if DEFAULTS[k]~=nil then return DEFAULTS[k] end
    -- events and unknown members: a signal is the most common shape
    local s=o.__signals[k];if not s then s=newSignal();o.__signals[k]=s end
    return s
end
instMt.__newindex=function(o,k,v)
    local props=rawget(o,"__props")
    if k=="Parent" then
        local old=props.Parent
        if old then for i,c in ipairs(old.__children) do if c==o then table.remove(old.__children,i);break end end end
        props.Parent=v
        if v then table.insert(v.__children,o) end
        return
    end
    if type(v)=="table" and v.__type=="Signal" then error("assigning signal") end
    props[k]=v
    local s=rawget(o,"__propSignals")[k];if s then s:Fire() end
end
instMt.__tostring=function(o) return o.__class..":"..tostring(o.Name) end
function Instance.new(class,parent) local o=newInstance(class);if parent then o.Parent=parent end;return o end
-- ---------------------------------------------------------------- services / globals
local function osclock() return clockValue end
local sched={}
local function resume(co,...) local ok,e=coroutine.resume(co,...);if not ok then report(tostring(e)..'\n'..debug.traceback(co)) end end
task_wait=function(t)
    t=t or .03
    if coroutine.isyieldable() then
        local co=coroutine.running();sched[#sched+1]={co=co,at=clockValue+t};coroutine.yield();return t
    end
    clockValue=clockValue+t;return t
end
local task={
    wait=task_wait,
    spawn=function(f,...) resume(coroutine.create(f),...) end,
    defer=function(f,...) sched[#sched+1]={co=coroutine.create(f),args={...},at=clockValue} end,
    delay=function(t,f,...) sched[#sched+1]={co=coroutine.create(f),args={...},at=clockValue+(t or 0)} end,
}
local function runDeferred(maxT)
    local guard=0
    while guard<20000 do
        guard=guard+1
        local best,bi=nil,nil
        for i,d in ipairs(sched) do if d.at<=maxT and (not best or d.at<best.at) then best,bi=d,i end end
        if not best then break end
        table.remove(sched,bi)
        if coroutine.status(best.co)=="suspended" then resume(best.co,table.unpack(best.args or {})) end
    end
end
local camera=newInstance("Camera","Camera");camera.Focus=CFrame.new();camera.CFrame=CFrame.new(0,50,50)
local workspace=newInstance("Workspace","Workspace");workspace.CurrentCamera=camera;camera.Parent=workspace
local playerGui=newInstance("PlayerGui","PlayerGui")
local localPlayer=newInstance("Player","LocalPlayer");localPlayer.UserId=1;localPlayer.DisplayName="Tester";playerGui.Parent=localPlayer
local playersService=newInstance("Players","Players");playersService.LocalPlayer=localPlayer;localPlayer.Parent=playersService
function playersService:GetPlayerByUserId(id) return id==1 and localPlayer or nil end
function playersService:GetPlayers() return {localPlayer} end
local replicatedStorage=newInstance("ReplicatedStorage","ReplicatedStorage")
local shared=newInstance("Folder","ArmyRoundShared");shared.Parent=replicatedStorage
local services={Players=playersService,Workspace=workspace,ReplicatedStorage=replicatedStorage}
local tweenService=newInstance("TweenService","TweenService")
function tweenService:Create(o,info,props) return {Play=function() for k,v in pairs(props) do o[k]=v end end,Cancel=function() end,Completed=newSignal()} end
services.TweenService=tweenService
local runService=newInstance("RunService","RunService");function runService:IsStudio() return true end;function runService:BindToRenderStep() end;services.RunService=runService
local textService=newInstance("TextService","TextService");function textService:GetTextSize(s,size) return Vector2.new(#s*size*.6,size) end;services.TextService=textService
local mps=newInstance("MarketplaceService","MarketplaceService");function mps:GetProductInfo() return {PriceInRobux=99} end;services.MarketplaceService=mps
local uis=newInstance("UserInputService","UserInputService");uis.TouchEnabled=false;uis.KeyboardEnabled=true;uis.MouseEnabled=true
function uis:GetMouseLocation() return Vector2.new(0,0) end;function uis:IsKeyDown() return false end;function uis:GetFocusedTextBox() return nil end;services.UserInputService=uis
local cas=newInstance("ContextActionService","ContextActionService");function cas:BindActionAtPriority() end;function cas:UnbindAction() end;services.ContextActionService=cas
local content=newInstance("ContentProvider","ContentProvider");content.RequestQueueSize=0;function content:PreloadAsync() end;services.ContentProvider=content
local starterGui=newInstance("StarterGui","StarterGui");function starterGui:SetCoreGuiEnabled() end;services.StarterGui=starterGui
local rf=newInstance("ReplicatedFirst","ReplicatedFirst");function rf:RemoveDefaultLoadingScreen() end;services.ReplicatedFirst=rf
local http=newInstance("HttpService","HttpService");function http:GenerateGUID() return "abcd-1234" end;services.HttpService=http
local cs=newInstance("CollectionService","CollectionService");function cs:GetTagged() return {} end;services.CollectionService=cs
local game=newInstance("DataModel","game")
function game:GetService(n) if not services[n] then services[n]=newInstance(n,n) end;return services[n] end
function game:IsLoaded() return true end
local script=newInstance("Script","script");script.Parent=shared
local function require(m)
    local name=type(m)=="table" and m.Name or tostring(m)
    if __cache[name]==nil then local f=__modules[name];assert(f,"no module "..name);__cache[name]=f() end
    return __cache[name]
end
local function typeof(v)
    if type(v)=="table" then if v.__type then return v.__type end;if getmetatable(v)==instMt then return "Instance" end end
    return type(v)
end
local warn=function(...) print("WARN",...) end
local utf8=utf8
local os={clock=osclock,time=function() return 0 end}
local tick=osclock
