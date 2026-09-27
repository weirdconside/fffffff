-- Shared, pure UTF-8 text checks for the admin panel input.
-- Any edit is accepted (phone keyboards insert whole words: autocorrect, suggestions, swipe typing);
-- only broken UTF-8, control characters and over-long text are refused.
local Typing={MAX_BYTES=240}
local function points(text)
    if type(text)~='string' or not utf8.len(text) then return nil end
    local out={};for _,code in utf8.codes(text) do out[#out+1]=code end;return out
end
function Typing.validEdit(previous,nextText,maxBytes)
    if type(nextText)~='string' or #nextText>(maxBytes or Typing.MAX_BYTES) or nextText:find('[%c]') then return false end
    local a,b=points(previous or ''),points(nextText);if not a or not b then return false end
    local first=1
    while first<=#a and first<=#b and a[first]==b[first] do first=first+1 end
    local x,y=#a,#b
    while x>=first and y>=first and a[x]==b[y] do x=x-1;y=y-1 end
    return true,math.max(0,y-first+1)
end
function Typing.clip(text,maxBytes)
    if type(text)~='string' or not utf8.len(text) then return '' end
    text=text:gsub('[%c]',' '):sub(1,maxBytes or Typing.MAX_BYTES)
    while #text>0 and not utf8.len(text) do text=text:sub(1,-2) end
    return text
end
return Typing
