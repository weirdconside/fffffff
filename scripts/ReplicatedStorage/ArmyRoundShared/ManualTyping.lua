-- Clipboard shortcuts + bulk edits are rejected in game-owned prompt fields.
-- One validated Unicode code point is sent per edit; submissions cannot replace it.
local UIS=game:GetService('UserInputService')
local CAS=game:GetService('ContextActionService')
local Typing=require(script.Parent.TypingRules)
local Manual={}
local serial=0
local function held(key) return UIS:IsKeyDown(key) end
local function clipboardKey(input)
    local ctrl=held(Enum.KeyCode.LeftControl) or held(Enum.KeyCode.RightControl) or held(Enum.KeyCode.LeftMeta) or held(Enum.KeyCode.RightMeta)
    local shift=held(Enum.KeyCode.LeftShift) or held(Enum.KeyCode.RightShift)
    return (input.KeyCode==Enum.KeyCode.V and ctrl) or (input.KeyCode==Enum.KeyCode.Insert and shift)
end
function Manual.attach(box,onEdit)
    serial=serial+1
    local self={box=box,prefix='',suffix='',changing=false,enabled=false,blockedUntil=0,lastKey=-100,lastCode=nil,connections={},action='ManualInput'..serial}
    function self:set(prefix,suffix)
        self.prefix=prefix or '';self.suffix=Typing.clip(suffix or '');self.changing=true;box.Text=self.prefix..self.suffix;self.changing=false
    end
    function self:value() return self.suffix end
    function self:allow(enabled) self.enabled=enabled;box.TextEditable=enabled end
    local function restore()
        self.changing=true;box.Text=self.prefix..self.suffix
        if box:IsFocused() then box.CursorPosition=#box.Text+1;box.SelectionStart=-1 end
        self.changing=false
    end
    self.connections[#self.connections+1]=UIS.InputBegan:Connect(function(input)
        if not box:IsFocused() then return end
        if clipboardKey(input) then
            self.blockedUntil=os.clock()+.25;restore()
        elseif input.UserInputType==Enum.UserInputType.Keyboard then
            self.lastKey=os.clock();self.lastCode=input.KeyCode
        end
    end)
    CAS:BindActionAtPriority(self.action,function(_,state,input)
        if box:IsFocused() and clipboardKey(input) then
            if state==Enum.UserInputState.Begin then self.blockedUntil=os.clock()+.25;restore() end
            return Enum.ContextActionResult.Sink
        end
        return Enum.ContextActionResult.Pass
    end,false,10000,Enum.KeyCode.V,Enum.KeyCode.Insert)
    self.connections[#self.connections+1]=box:GetPropertyChangedSignal('Text'):Connect(function()
        if self.changing then return end
        local text=box.Text
        if not self.enabled or os.clock()<self.blockedUntil or text:sub(1,#self.prefix)~=self.prefix then restore();return end
        local nextText=text:sub(#self.prefix+1)
        local valid,inserted=Typing.validEdit(self.suffix,nextText)
        if not valid then restore();return end
        -- Desktop edits adding text need a real key event/held key, not a context-menu paste.
        local adds=inserted>0
        local manualKey=os.clock()-self.lastKey<.3 or (self.lastCode and held(self.lastCode))
        if adds and UIS.KeyboardEnabled and not UIS.TouchEnabled and not manualKey then restore();return end
        if nextText~=self.suffix then self.suffix=nextText;if onEdit then onEdit(nextText) end end
    end)
    self.connections[#self.connections+1]=box:GetPropertyChangedSignal('CursorPosition'):Connect(function()
        if not self.changing and box:IsFocused() and box.CursorPosition>0 and box.CursorPosition<=#self.prefix then
            self.changing=true;box.CursorPosition=#self.prefix+1;box.SelectionStart=-1;self.changing=false
        end
    end)
    function self:destroy() CAS:UnbindAction(self.action);for _,connection in ipairs(self.connections) do connection:Disconnect() end end
    self:set('','');self:allow(false);return self
end
return Manual
