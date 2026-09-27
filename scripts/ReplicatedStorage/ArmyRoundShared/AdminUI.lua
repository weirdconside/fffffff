-- Only the selected author sees the initial input. Everyone sees the submitted
-- filtered prompt and the same server-selected five-second scrolling roulette.
local RunService=game:GetService('RunService')
local Workspace=game:GetService('Workspace')
local Theme=require(script.Parent.StudTheme)
local Manual=require(script.Parent.ManualTyping)
local UISound=require(script.Parent.UISound)
local Admin={};Admin.__index=Admin
local function make(class,parent,name)
    local o=Instance.new(class);o.Name=name or class;o.Parent=parent;return o
end
local function label(parent,name,text,size,pos,sz,color)
    local o=make('TextLabel',parent,name);o.BackgroundTransparency=1;o.Position=pos;o.Size=sz;o.Text=text;o.ZIndex=8
    Theme.text(o,size,color);return o
end
local function colour(value)
    if type(value)=='table' then return Color3.fromRGB(value.r or 255,value.g or 255,value.b or 255) end
    return Theme.Colors.White
end
function Admin.new(parent,send)
    local self=setmetatable({event=nil,phase='Idle',send=send,received=0,elapsed=0,remaining=0,pending=false,active=true},Admin)
    local gui=make('ScreenGui',parent,'AdminSequence');gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=70;gui.Enabled=false;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;self.gui=gui
    local shade=make('Frame',gui,'Shade');shade.Size=UDim2.fromScale(1,1);shade.BackgroundColor3=Color3.new(0,0,0);shade.BackgroundTransparency=.66;shade.BorderSizePixel=0;shade.Active=true;self.shade=shade
    local card=make('Frame',gui,'Card');card.AnchorPoint=Vector2.new(.5,.5);card.Position=UDim2.fromScale(.5,.5);card.Size=UDim2.fromOffset(600,162);card.ZIndex=3;Theme.skin(card,Theme.Colors.Panel);self.card=card
    local scale=make('UIScale',card);self.scale=scale
    self.title=label(card,'Title','ADMIN PANEL',24,UDim2.fromOffset(20,15),UDim2.new(1,-112,0,30),Theme.Colors.Gold)
    self.title.TextXAlignment=Enum.TextXAlignment.Left
    self.timer=label(card,'Timer','15s',18,UDim2.new(1,-74,0,18),UDim2.fromOffset(54,26));self.timer.TextXAlignment=Enum.TextXAlignment.Right
    local field=make('Frame',card,'Field');field.Position=UDim2.fromOffset(20,62);field.Size=UDim2.new(1,-40,0,60);field.ZIndex=5;Theme.skin(field,Theme.Colors.Dark);self.field=field
    local input=make('TextBox',field,'Prompt');input.BackgroundTransparency=1;input.Position=UDim2.fromOffset(10,4);input.Size=UDim2.new(1,-20,1,-8);input.ZIndex=8;input.Text='';input.PlaceholderText='Type a prompt and press Enter';input.PlaceholderColor3=Theme.Colors.Muted;input.ClearTextOnFocus=false;input.MultiLine=false;input.TextXAlignment=Enum.TextXAlignment.Left;Theme.text(input,18);self.input=input
    local quote=label(card,'PromptMessage','',20,UDim2.fromOffset(20,62),UDim2.new(1,-40,1,-82));quote.TextWrapped=true;quote.TextXAlignment=Enum.TextXAlignment.Left;quote.TextYAlignment=Enum.TextYAlignment.Top;self.quote=quote
    self.error=label(card,'Error','',13,UDim2.fromOffset(20,130),UDim2.new(1,-40,0,22),Theme.Colors.Gold);self.error.Visible=false
    -- Example commands under the input so new players know what the panel understands.
    self.hint=label(card,'Hint','',12,UDim2.fromOffset(20,150),UDim2.new(1,-40,0,20),Theme.Colors.Muted);self.hint.Visible=false;self.hint.TextXAlignment=Enum.TextXAlignment.Left
    local viewport=make('Frame',card,'RouletteViewport');viewport.BackgroundTransparency=1;viewport.Position=UDim2.fromOffset(20,76);viewport.Size=UDim2.new(1,-40,0,84);viewport.ClipsDescendants=true;viewport.ZIndex=5;self.viewport=viewport
    local strip=make('Frame',viewport,'MovingStrip');strip.BackgroundTransparency=1;strip.Size=UDim2.fromOffset(30*216,84);strip.ZIndex=6;self.strip=strip
    for i=1,30 do
        local cell=make('Frame',strip,'Choice'..i);cell.Position=UDim2.fromOffset((i-1)*216,4);cell.Size=UDim2.fromOffset(208,76);cell.ZIndex=6
        Theme.skin(cell,i%2==1 and Theme.Colors.Green or Theme.Colors.Purple)
        local text=label(cell,'Caption',i%2==1 and 'EXECUTE' or 'EVERYONE ADDS',18,UDim2.fromOffset(8,4),UDim2.new(1,-16,1,-8));text.TextWrapped=true;text.ZIndex=9
    end
    self.marker=label(card,'Pointer',utf8.char(0x25BC),22,UDim2.new(.5,-16,0,52),UDim2.fromOffset(32,24),Theme.Colors.Gold)
    self.manual=Manual.attach(input,function(text)
        if self.canType and not self.pending then send(self.phase=='Append' and 'AppendDraft' or 'WishDraft',{eventId=self.event,prompt=text}) end
    end)
    input.FocusLost:Connect(function(enter) if enter then self:submit() end end)
    input.ReturnPressedFromOnScreenKeyboard:Connect(function() self:submit() end)
    self.connection=RunService.RenderStepped:Connect(function()self:render()end)
    return self
end
function Admin:submit()
    if not self.gui.Enabled or not self.canType or self.pending then return end
    self.pending=true;self.gui.Enabled=false;self.manual:allow(false)
    self.send(self.phase=='Append' and 'AppendSubmit' or 'WishSubmit',{eventId=self.event})
    if self.input:IsFocused() then self.input:ReleaseFocus() end
end
function Admin:reset()
    self.gui.Enabled=false;self.event=nil;self.phase='Idle';self.canType=false;self.pending=false;self.manual:allow(false)
    if self.input:IsFocused() then self.input:ReleaseFocus() end
end
function Admin:isBlocking() return self.gui.Enabled and (self.field.Visible or (self.phase=='Roulette' and self.shade.Visible)) end
function Admin:update(wish)
    if type(wish)~='table' or not wish.eventId or wish.phase=='Idle' then self:reset();return end
    local changed=self.event~=wish.eventId or self.phase~=wish.phase
    if changed then self.pending=false;self.error.Visible=false end
    self.event=wish.eventId;self.phase=wish.phase;self.canType=wish.canType==true
    self.remaining=wish.remainingExact or wish.remaining or 0;self.elapsed=wish.phaseElapsed or 0;self.received=os.clock();self.choice=wish.choice
    self.field.Visible=self.canType and not self.pending
    self.viewport.Visible=self.phase=='Roulette';self.marker.Visible=self.viewport.Visible
    local watching=(self.phase=='Prompt' or self.phase=='Filtering') and not self.field.Visible
    self.quote.Visible=self.phase=='Announcement' or self.phase=='Applied' or watching
    self.shade.Visible=self.field.Visible or (self.viewport.Visible and not watching)
    self.gui.Enabled=self.field.Visible or self.viewport.Visible or self.quote.Visible
    self.card.Size=UDim2.fromOffset(600,self.phase=='Applied' and 262 or self.phase=='Announcement' and 208 or self.phase=='Roulette' and 190 or watching and 120 or 162)
    self.card.Position=watching and UDim2.new(.5,0,0,170) or UDim2.fromScale(.5,.5)
    self.hint.Visible=self.field.Visible and self.phase=='Prompt'
    if self.hint.Visible then self.hint.Text='TRY: heal my army  /  meteor on enemies  /  summon 3 giants  /  give me gold' end
    self.card.Size=self.hint.Visible and UDim2.fromOffset(600,178) or self.card.Size
    self.title.Text=wish.ticket and 'ADMIN TICKET' or 'ADMIN PANEL';self.title.TextColor3=Theme.Colors.Gold
    if watching then
        self.title.Text=string.upper(wish.recipientName or 'A PLAYER')..' HAS THE ADMIN PANEL';self.title.TextColor3=colour(wish.recipientColor)
        self.quote.Text=self.phase=='Filtering' and 'Checking the command...' or 'Typing a command...'
    elseif self.phase=='Announcement' then
        self.title.Text=wish.recipientName or 'Player';self.title.TextColor3=colour(wish.recipientColor);self.quote.Text=wish.prompt or ''
    elseif self.phase=='Roulette' then self.title.Text='ROULETTE'
    elseif self.phase=='Applied' then
        self.title.Text=wish.outcome=='Executed' and 'COMMAND EXECUTED' or wish.outcome=='Cancelled' and 'COMMAND CANCELLED' or 'COMMAND REJECTED'
        self.title.TextColor3=wish.outcome=='Executed' and Theme.Colors.Green or Theme.Colors.Red
        self.quote.Text=(wish.finalPrompt or wish.prompt or '')..'\n\n'..(wish.effect or '')
    end
    self.manual:allow(self.field.Visible)
    if changed and self.field.Visible then
        UISound.play('open')
        self.manual:set(self.phase=='Append' and ((wish.prompt or '')..' ') or '',wish.ownDraft or '')
        self.input.PlaceholderText=self.phase=='Append' and 'Add to the command and press Enter (e.g. "but at half strength")' or 'Type your admin command and press Enter'
        task.defer(function() if self.gui.Enabled and self.field.Visible then self.input:CaptureFocus();self.input.CursorPosition=#self.input.Text+1 end end)
    elseif not self.field.Visible and self.input:IsFocused() then self.input:ReleaseFocus() end
    self:render()
end
function Admin:report(message,serverDraft)
    if not self.canType or not message then return end
    self.pending=false;self.gui.Enabled=true;self.field.Visible=true;self.manual:allow(true)
    self.error.Text=message;self.error.Visible=true
    if serverDraft~=nil then self.manual:set(self.manual.prefix,serverDraft) end
end
function Admin:render()
    if not self.gui.Enabled then return end
    local camera=Workspace.CurrentCamera;if camera then
        local v=camera.ViewportSize;self.scale.Scale=math.max(.25,math.min(1,(v.X-28)/600,(v.Y-50)/self.card.Size.Y.Offset))
    end
    local age=math.max(0,os.clock()-self.received)
    self.timer.Text=tostring(math.max(0,math.ceil(self.remaining-age)))..'s'
    if self.phase=='Roulette' then
        -- Animate for 4.6 seconds; hold the selected cell for the last 0.4 seconds.
        -- Snapshots give phase progress so late clients never restart the spin.
        local t=math.clamp((self.elapsed+age)/4.6,0,1);local eased=1-(1-t)^4
        local index=self.choice=='Append' and 24 or 23
        local center=(self.viewport.AbsoluteSize.X/math.max(.001,self.scale.Scale)-208)/2
        self.strip.Position=UDim2.fromOffset(center-(index-1)*216*eased,0)
    end
end
function Admin:destroy()self:reset();self.connection:Disconnect();self.manual:destroy();self.gui:Destroy()end
return Admin
