-- Prints a GUI subtree as GUIDUMP lines for tools/guirender.py.
local function __esc(s) return (tostring(s):gsub("[\n\t\r]",function(c) return c=="\n" and "\\n" or " " end)) end
local __DUMP_KEYS={"Visible","Enabled","ZIndex","Rotation","BackgroundTransparency","TextTransparency","ImageTransparency","TextSize","TextScaled",
    "TextWrapped","DisplayOrder","IgnoreGuiInset","Scale","MaxTextSize","MinTextSize","Thickness","Transparency","LayoutOrder","ClipsDescendants",
    "Image","Text","GroupTransparency","TextStrokeTransparency","ScaleType"}
local function __val(v)
    if type(v)=="table" then
        if v.__type=="UDim2" then return string.format("u2:%g,%g,%g,%g",v.X.Scale,v.X.Offset,v.Y.Scale,v.Y.Offset)
        elseif v.__type=="UDim" then return string.format("u:%g,%g",v.Scale,v.Offset)
        elseif v.__type=="Vector2" then return string.format("v2:%g,%g",v.X,v.Y)
        elseif v.__type=="Color3" then return string.format("c3:%d,%d,%d",math.floor(v.R*255+.5),math.floor(v.G*255+.5),math.floor(v.B*255+.5))
        elseif v.__type=="Font" then return "font:"..tostring(v.Family)
        elseif v.EnumType then return "enum:"..v.Name
        end
        return nil
    end
    if type(v)=="userdata" then return nil end
    return tostring(v)
end
function dumpGui(label,roots)
    print("GUIDUMP_BEGIN\t"..label)
    local n=0
    local function walk(o,pid)
        n=n+1;local id=n
        local props=rawget(o,"__props")
        local out={"id="..id,"pid="..pid,"class="..o.ClassName,"name="..__esc(o.Name)}
        for k,v in pairs(props) do
            if k~="Parent" and k~="Name" and k~="ClassName" then
                local s=__val(v);if s~=nil then out[#out+1]=k.."="..__esc(s) end
            end
        end
        print("GUIDUMP\t"..table.concat(out,"\t"))
        for _,c in ipairs(o.__children) do walk(c,id) end
    end
    for _,r in ipairs(roots) do walk(r,0) end
    print("GUIDUMP_END\t"..label)
end
