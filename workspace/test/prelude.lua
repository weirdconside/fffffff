local __modules,__cache={},{}
local function __req(name)
    if __cache[name]==nil then
        local f=__modules[name];assert(f,"no module "..tostring(name))
        __cache[name]=f()
    end
    return __cache[name]
end
local function proxy(name)
    return setmetatable({__module=name},{__index=function(t,k)
        if k=="WaitForChild" or k=="FindFirstChild" then return function(self,n) return proxy(n) end end
        return proxy(k)
    end})
end
local game={GetService=function(self,n) return proxy(n) end}
local script=proxy("script")
local function require(x)
    if type(x)=="table" and rawget(x,"__module") then return __req(rawget(x,"__module")) end
    if type(x)=="string" then return __req((x:match("([%w_]+)%.ModuleScript$")) or x:match("([%w_]+)$")) end
    error("bad require")
end
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end,new=function(r,g,b) return {R=r,G=g,B=b} end}
local warn=function(...) print("WARN",...) end
