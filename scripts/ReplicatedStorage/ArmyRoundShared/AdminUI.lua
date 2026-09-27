-- Admin panel presentation. No windows: everything is floating caption text
-- over the game, like a chat line — the author's name in their colour and
-- then the command. Only the player who types gets an input bar.
local RunService=game:GetService('RunService')
local Workspace=game:GetService('Workspace')
local TextService=game:GetService('TextService')
local Theme=require(script.Parent.StudTheme)
local Manual=require(script.Parent.ManualTyping)
local UISound=require(script.Parent.UISound)
local Admin={};Admin.__index=Admin
local C=Theme.Colors
local FONT=Font.new('rbxasset://fonts/families/FredokaOne.json',Enum.FontWeight.Bold,Enum.FontStyle.Normal)
local INK=C.Ink
local WIDTH=820            -- caption column width (design pixels, scaled down on small screens)
local LINE_SIZE,KICKER_SIZE=30,22
local function make(class,parent,name,props)
    local o=Instance.new(class);o.Name=name or class
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent;return o
end
local function colour(value)
    if type(value)=='table' then return Color3.fromRGB(value.r or 255,value.g or 255,value.b or 255) end
    return C.White
end
local function hex(c) return string.format('#%02X%02X%02X',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)) end
local function escape(s) return (tostring(s or ''):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;')) end
local function plainHeight(text,size,width)
    local ok,dims=pcall(function() return TextService:GetTextSize(text,size,Enum.Font.FredokaOne,Vector2.new(width,2000)) end)
    return ok and math.max(size,dims.Y) or size*(math.ceil(#text*size*.55/width))
end
-- caption text: chunky letters with an ink outline so they read on any background
local function caption(parent,name,size,colourValue,z)
    local o=make('TextLabel',parent,name,{BackgroundTransparency=1,FontFace=FONT,TextSize=size,TextColor3=colourValue or C.White,TextWrapped=true,RichText=true,
        TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Top,ZIndex=z or 12,Text=''})
    make('UIStroke',o,'Ink',{Color=INK,Thickness=size>=26 and 3 or 2.5,LineJoinMode=Enum.LineJoinMode.Round})
    return o
end

function Admin.new(parent,send)
    local self=setmetatable({event=nil,phase='Idle',send=send,received=0,elapsed=0,remaining=0,pending=false,active=true,lines={},plain={},typeFrom=nil},Admin)
    local gui=make('ScreenGui',parent,'AdminSequence',{ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=70,Enabled=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling});self.gui=gui
    Theme.safe(gui)
    -- caption column (top centre, below the HUD chips)
    local column=make('Frame',gui,'Caption',{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,118),Size=UDim2.fromOffset(WIDTH,300),ZIndex=10})
    self.column=column;self.scale=make('UIScale',column,'Fit')
    -- a soft dark haze behind the words (not a window: it fades out at every edge)
    local haze=make('Frame',column,'Haze',{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,-14),Size=UDim2.new(1,160,0,120),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.45,BorderSizePixel=0,ZIndex=10})
    make('UIGradient',haze,'Fade',{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.22,.2),NumberSequenceKeypoint.new(.78,.2),NumberSequenceKeypoint.new(1,1)})})
    make('UICorner',haze,'Round',{CornerRadius=UDim.new(0,40)})
    self.haze=haze
    -- kicker: "ADMIN PANEL" / "ROULETTE" / "COMMAND EXECUTED" + timer pill
    local kicker=caption(column,'Kicker',KICKER_SIZE,C.Gold,13);kicker.Size=UDim2.new(1,0,0,KICKER_SIZE+4);kicker.TextWrapped=false;self.kicker=kicker
    local timer=make('Frame',column,'TimerPill',{AnchorPoint=Vector2.new(.5,0),Size=UDim2.fromOffset(58,28),BackgroundColor3=INK,BackgroundTransparency=.1,BorderSizePixel=0,ZIndex=13})
    make('UICorner',timer,'Round',{CornerRadius=UDim.new(.5,0)});make('UIStroke',timer,'Line',{Color=C.Gold,Thickness=2})
    self.timerPill=timer
    self.timer=make('TextLabel',timer,'Timer',{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),FontFace=FONT,TextSize=18,TextColor3=C.White,Text='15',ZIndex=14})
    -- the quote lines: "<name in colour>: command"
    self.lineHolder=make('Frame',column,'Lines',{BackgroundTransparency=1,Position=UDim2.fromOffset(0,KICKER_SIZE+12),Size=UDim2.new(1,0,0,200),ZIndex=12})
    self.effect=caption(column,'Effect',20,C.Gold,13);self.effect.Visible=false
    -- the typing bar (only for the player who may type right now)
    local card=make('Frame',column,'InputBar',{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,KICKER_SIZE+12),Size=UDim2.new(1,0,0,62),Visible=false,ZIndex=14})
    Theme.skin(card,C.Dark);card.BackgroundTransparency=.05
    local cardCorner=card:FindFirstChildOfClass('UICorner');if cardCorner then cardCorner.CornerRadius=UDim.new(0,14) end
    local outline=card:FindFirstChild('StudOutline');if outline then outline.Color=C.Gold;outline.Thickness=3 end
    self.card=card;self.field=card
    local chip=make('Frame',card,'Chip',{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(46,46),ZIndex=16});Theme.skin(chip,C.Gold)
    local chipCorner=chip:FindFirstChildOfClass('UICorner');if chipCorner then chipCorner.CornerRadius=UDim.new(0,10) end
    make('TextLabel',chip,'Glyph',{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),FontFace=FONT,TextSize=26,TextColor3=INK,Text='>',ZIndex=18})
    local input=make('TextBox',card,'Prompt',{BackgroundTransparency=1,Position=UDim2.fromOffset(64,6),Size=UDim2.new(1,-172,1,-12),ZIndex=17,Text='',
        PlaceholderText='Type a command and press Enter',PlaceholderColor3=C.Muted,ClearTextOnFocus=false,MultiLine=false,TextXAlignment=Enum.TextXAlignment.Left})
    Theme.text(input,20);input.FontFace=FONT;self.input=input
    local sendButton=make('TextButton',card,'Send',{Text='SEND',AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-8,.5,0),Size=UDim2.fromOffset(96,46),ZIndex=17})
    Theme.button(sendButton,C.Green,20);sendButton.Activated:Connect(function() self:submit() end);self.sendButton=sendButton
    self.hint=caption(column,'Hint',16,C.Muted,13);self.hint.Visible=false
    self.error=caption(column,'Error',17,C.Gold,13);self.error.Visible=false
    -- roulette: a strip of EXECUTE / EVERYONE ADDS chips under a pointer
    local viewport=make('Frame',column,'RouletteViewport',{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,0),Size=UDim2.fromOffset(640,86),ClipsDescendants=true,ZIndex=12,Visible=false})
    self.viewport=viewport
    local strip=make('Frame',viewport,'MovingStrip',{BackgroundTransparency=1,Size=UDim2.fromOffset(30*216,84),ZIndex=12});self.strip=strip
    for i=1,30 do
        local cell=make('Frame',strip,'Choice'..i,{Position=UDim2.fromOffset((i-1)*216,6),Size=UDim2.fromOffset(208,72),ZIndex=12})
        Theme.skin(cell,i%2==1 and C.Green or C.Purple)
        local cc=cell:FindFirstChildOfClass('UICorner');if cc then cc.CornerRadius=UDim.new(0,14) end
        local t=make('TextLabel',cell,'Caption',{BackgroundTransparency=1,Position=UDim2.fromOffset(8,4),Size=UDim2.new(1,-16,1,-8),Text=i%2==1 and 'EXECUTE' or 'EVERYONE ADDS',ZIndex=15})
        Theme.text(t,22);t.FontFace=FONT;t.TextWrapped=true
    end
    -- edges of the strip fade out
    for side=0,1 do
        local fade=make('Frame',viewport,'Fade'..side,{AnchorPoint=Vector2.new(side,0),Position=UDim2.fromScale(side,0),Size=UDim2.new(.18,0,1,0),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,ZIndex=16})
        make('UIGradient',fade,'G',{Rotation=side==0 and 0 or 180,Transparency=NumberSequence.new(.35,1)})
    end
    self.marker=caption(column,'Pointer',30,C.Gold,17);self.marker.Text=utf8.char(0x25BC);self.marker.Visible=false
    self.manual=Manual.attach(input,function(text)
        if self.canType and not self.pending then send(self.phase=='Append' and 'AppendDraft' or 'WishDraft',{eventId=self.event,prompt=text}) end
    end)
    input.FocusLost:Connect(function(enter) if enter then self:submit() end end)
    input.ReturnPressedFromOnScreenKeyboard:Connect(function() self:submit() end)
    self.connection=RunService.RenderStepped:Connect(function() self:render() end)
    return self
end
function Admin:submit()
    if not self.gui.Enabled or not self.canType or self.pending then return end
    self.pending=true;self.card.Visible=false;self.hint.Visible=false;self.manual:allow(false)
    self.send(self.phase=='Append' and 'AppendSubmit' or 'WishSubmit',{eventId=self.event})
    if self.input:IsFocused() then self.input:ReleaseFocus() end
    UISound.play('success')
    self:layout()
end
function Admin:reset()
    self.gui.Enabled=false;self.event=nil;self.phase='Idle';self.canType=false;self.pending=false;self.manual:allow(false)
    if self.input:IsFocused() then self.input:ReleaseFocus() end
end
-- typing blocks the camera/world input; the captions never do
function Admin:isBlocking() return self.gui.Enabled and self.card.Visible end

-- one caption line per quote: coloured name, then the text
function Admin:setLines(quotes,typewriter)
    for _,l in ipairs(self.lines) do l:Destroy() end
    self.lines={};self.plain={};self.baseText=nil
    for i,q in ipairs(quotes) do
        local l=caption(self.lineHolder,'Line'..i,i==1 and LINE_SIZE or LINE_SIZE-6,C.White,12)
        local name=q.name and (q.name..(q.suffix or ': ')) or ''
        local body=escape(q.text)
        -- a rejected addition stays readable but crossed out
        if q.rejected then body='<font transparency="0.45"><s>'..body..'</s></font> <font color="'..hex(C.Red)..'">REJECTED</font>' end
        l.Text=(q.name and ('<font color="'..hex(q.color or C.White)..'">'..escape(name)..'</font>') or '')..body
        self.plain[i]=name..(q.text or '')..(q.rejected and ' REJECTED' or '')
        self.lines[i]=l
    end
    self.typeFrom=typewriter and os.clock() or nil
end
function Admin:layout()
    local y=0
    local width=WIDTH
    for i,l in ipairs(self.lines) do
        local h=plainHeight(self.plain[i] or l.Text,l.TextSize,width)+4
        l.Position=UDim2.fromOffset(0,y);l.Size=UDim2.new(1,0,0,h);y+=h+6
    end
    self.lineHolder.Size=UDim2.new(1,0,0,y)
    local top=KICKER_SIZE+12
    local cursor=top+y
    if self.effect.Visible then
        local h=plainHeight(self.effect.Text,self.effect.TextSize,width)+4
        self.effect.Position=UDim2.fromOffset(0,cursor+2);self.effect.Size=UDim2.new(1,0,0,h);cursor+=h+8
    end
    if self.viewport.Visible then
        self.marker.Position=UDim2.new(.5,-20,0,cursor);self.marker.Size=UDim2.fromOffset(40,32);cursor+=26
        self.viewport.Position=UDim2.new(.5,0,0,cursor);cursor+=90
    end
    if self.card.Visible then
        self.card.Position=UDim2.new(.5,0,0,cursor+4);cursor+=72
    end
    if self.error.Visible then self.error.Position=UDim2.fromOffset(0,cursor);self.error.Size=UDim2.new(1,0,0,22);cursor+=24 end
    if self.hint.Visible then
        local h=plainHeight(self.hint.Text,self.hint.TextSize,width)+2
        self.hint.Position=UDim2.fromOffset(0,cursor);self.hint.Size=UDim2.new(1,0,0,h);cursor+=h+4
    end
    self.haze.Size=UDim2.new(1,160,0,cursor+28)
    self.column.Size=UDim2.fromOffset(WIDTH,cursor)
    local kw=TextService:GetTextSize((self.kicker.Text:gsub('<[^>]*>','')),KICKER_SIZE,Enum.Font.FredokaOne,Vector2.new(2000,100)).X
    self.timerPill.Position=UDim2.new(.5,kw/2+40,0,-2)
end
function Admin:update(wish)
    if type(wish)~='table' or not wish.eventId or wish.phase=='Idle' then self:reset();return end
    -- the server spends a second or two turning the command into actions: no extra window,
    -- the last view just stays (without the input box) until the result arrives
    if wish.phase=='Thinking' then
        wish=table.clone(wish);wish.phase=(self.event==wish.eventId and self.phase) or 'Roulette'
        wish.canType=false;wish.remainingExact=0;wish.remaining=0
    end
    local changed=self.event~=wish.eventId or self.phase~=wish.phase
    if changed then self.pending=false;self.error.Visible=false end
    self.event=wish.eventId;self.phase=wish.phase;self.canType=wish.canType==true
    self.remaining=wish.remainingExact or wish.remaining or 0;self.elapsed=wish.phaseElapsed or 0;self.received=os.clock();self.choice=wish.choice
    local typing=self.canType and not self.pending and (self.phase=='Prompt' or self.phase=='Append')
    self.card.Visible=typing
    self.viewport.Visible=self.phase=='Roulette';self.marker.Visible=self.viewport.Visible
    self.hint.Visible=typing and self.phase=='Prompt'
    self.gui.Enabled=true
    local author={name=wish.recipientName or 'Player',color=colour(wish.recipientColor)}
    local kicker,kickerColour,effect='ADMIN PANEL',C.Gold,nil
    if changed then
        if self.phase=='Prompt' or self.phase=='Filtering' then
            if typing then
                kicker=wish.ticket and 'YOUR ADMIN TICKET!' or 'YOU HAVE THE ADMIN PANEL!'
                self:setLines({})
            else
                kicker=wish.ticket and 'ADMIN TICKET' or 'ADMIN PANEL'
                self:setLines({{name=author.name,color=author.color,suffix=' ',text=self.phase=='Filtering' and 'is sending the command...' or 'is typing a command...'}})
            end
        elseif self.phase=='Announcement' then
            kicker='ADMIN COMMAND'
            self:setLines({{name=author.name,color=author.color,text=wish.prompt or ''}},true)
            UISound.play('open')
        elseif self.phase=='Roulette' then
            kicker='ROULETTE: EXECUTE OR EVERYONE ADDS?'
            self:setLines({{name=author.name,color=author.color,text=wish.prompt or ''}})
        elseif self.phase=='Append' then
            kicker=typing and 'EVERYONE ADDS - TYPE YOUR PART!' or 'EVERYONE ADDS TO THE COMMAND'
            self:setLines({{name=author.name,color=author.color,text=wish.prompt or ''}})
        elseif self.phase=='Applied' then
            local ok=wish.outcome=='Executed'
            kicker=ok and 'COMMAND EXECUTED!' or (wish.outcome=='Cancelled' and 'COMMAND CANCELLED' or 'COMMAND REJECTED')
            kickerColour=ok and C.Green or C.Red
            local quotes={}
            for _,q in ipairs(wish.quotes or {}) do quotes[#quotes+1]={name=q.name,color=colour(q.color),text=q.text,rejected=q.rejected} end
            if #quotes==0 then quotes[1]={name=author.name,color=author.color,text=wish.finalPrompt or wish.prompt or ''} end
            self:setLines(quotes)
            effect=wish.effect
            if ok then UISound.play('success') end
        elseif self.phase=='Resolving' then
            kicker='THE ADMIN PANEL IS WORKING'
            self:setLines({{name=author.name,color=author.color,suffix=' ',text='used the admin panel...'}})
        else
            self:setLines({})
        end
        self.kicker.Text=kicker;self.kicker.TextColor3=kickerColour
        self.effect.Visible=effect~=nil and effect~='';self.effect.Text=effect or ''
    end
    if self.hint.Visible then self.hint.Text='TYPE ANYTHING! e.g. meteor on everyone  /  summon 5 giants  /  freeze Bob' end
    self.manual:allow(typing)
    if changed and typing then
        UISound.play('open')
        self.manual:set(self.phase=='Append' and ((wish.prompt or '')..' ') or '',wish.ownDraft or '')
        self.input.PlaceholderText=self.phase=='Append' and 'Add to it and press Enter (e.g. "but at half strength")' or 'Type your admin command and press Enter'
        task.defer(function() if self.gui.Enabled and self.card.Visible then self.input:CaptureFocus();self.input.CursorPosition=#self.input.Text+1 end end)
    elseif not typing and self.input:IsFocused() then self.input:ReleaseFocus() end
    self:layout()
    self:render()
end
function Admin:report(message,serverDraft)
    if not self.canType or not message then return end
    self.pending=false;self.gui.Enabled=true;self.card.Visible=true;self.manual:allow(true)
    self.error.Text=message;self.error.Visible=true
    if serverDraft~=nil then self.manual:set(self.manual.prefix,serverDraft) end
    self:layout()
end
function Admin:render()
    if not self.gui.Enabled then return end
    local camera=Workspace.CurrentCamera
    if camera then
        local v=camera.ViewportSize
        local top=self.top or math.clamp(v.Y*.14,62,118)
        self.scale.Scale=math.clamp(math.min((v.X-24)/WIDTH,(v.Y-top-12)/math.max(120,self.column.Size.Y.Offset+40)),.4,1)
        self.column.Position=UDim2.new(.5,0,0,self.top or math.clamp(v.Y*.14,62,118))
    end
    local age=math.max(0,os.clock()-self.received)
    local left=tostring(math.max(0,math.ceil(self.remaining-age)))
    if self.timer.Text~=left then self.timer.Text=left end
    -- typewriter for the announced command
    if self.typeFrom and self.lines[1] then
        local n=math.floor((os.clock()-self.typeFrom)*45)
        local total=utf8.len(self.plain[1] or '') or #(self.plain[1] or '')
        self.lines[1].MaxVisibleGraphemes=n>=total and -1 or n
        if n>=total then self.typeFrom=nil end
    end
    -- the name/typing line breathes a little so it is noticed
    if self.lines[1] and not self.card.Visible and (self.phase=='Prompt' or self.phase=='Filtering' or self.phase=='Resolving') then
        local l=self.lines[1]
        self.baseText=self.baseText or (l.Text:gsub('%.+$',''))
        local text=self.baseText..string.rep('.',1+math.floor(os.clock()*3)%3)
        if l.Text~=text then l.Text=text end
    end
    if self.phase=='Roulette' then
        -- Animate for 4.6 seconds; hold the selected cell for the last 0.4 seconds.
        -- Snapshots give phase progress so late clients never restart the spin.
        local t=math.clamp((self.elapsed+age)/4.6,0,1);local eased=1-(1-t)^4
        local index=self.choice=='Append' and 24 or 23
        local center=(640-208)/2
        self.strip.Position=UDim2.fromOffset(center-(index-1)*216*eased,0)
    end
end
-- the round HUD tells us where its top chips end, so captions never cover them
function Admin:setTop(y) self.top=y end
function Admin:destroy()self:reset();self.connection:Disconnect();self.manual:destroy();self.gui:Destroy()end
return Admin
