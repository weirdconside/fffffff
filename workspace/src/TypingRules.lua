-- Shared, pure UTF-8 edit validation. Limits insertions to one code point per edit.
-- This rejects bulk clipboard edits; it is not a claim that clients are trusted.
local Typing={MAX_BYTES=120}
local function points(text)
    if type(text)~='string' or not utf8.len(text) then return nil end
    local out={};for _,code in utf8.codes(text) do out[#out+1]=code end;return out
end
function Typing.validEdit(previous,nextText,maxBytes)
    if type(nextText)~='string' or #nextText>(maxBytes or Typing.MAX_BYTES) or nextText:find('[%c]') then return false end
    local a,b=points(previous),points(nextText);if not a or not b then return false end
    local first=1
    while first<=#a and first<=#b and a[first]==b[first] do first=first+1 end
    local x,y=#a,#b
    while x>=first and y>=first and a[x]==b[y] do x=x-1;y=y-1 end
    local inserted=math.max(0,y-first+1)
    return inserted<=1,inserted
end
function Typing.clip(text,maxBytes)
    if type(text)~='string' or not utf8.len(text) then return '' end
    text=text:gsub('[%c]',' '):sub(1,maxBytes or Typing.MAX_BYTES)
    while #text>0 and not utf8.len(text) do text=text:sub(1,-2) end
    return text
end
return Typing
