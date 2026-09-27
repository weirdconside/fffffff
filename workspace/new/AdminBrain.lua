-- Turns an admin command (plus the roulette additions) into a plan of game actions with Gemini.
-- The API key lives in the experience's Secrets store as GEMINI_API_KEY; it never reaches clients.
-- Returns nil on any problem, and WishRules then falls back to its local interpreter.
local HttpService=game:GetService('HttpService')
local Brain={}
local SECRET_NAME='GEMINI_API_KEY'
local MODELS={'gemini-2.5-flash','gemini-flash-latest','gemini-2.0-flash'}
local BASE='https://generativelanguage.googleapis.com/v1beta/models/'
local Actions=require(script.Parent.AdminActions)
local SYSTEM=[[
You are the ADMIN PANEL of the Roblox strategy game "BATTLE BUT WITH ADMIN PANEL".
Players build bases (buildings with levels), gather resources (Log, Stone, Gold, Plank, Iron Ore, Iron Bar, Crystal, Trophy),
train troops (Barbarian, Archer, Giant, Wizard), unlock lands, build a bridge, capture neutral islands and attack each
other's town halls. Every 2 minutes one player (the AUTHOR) types ANY command. Sometimes a roulette lets the other players
append their own text ("additions"). Turn the final command into actions from the list below.

WHAT IS ALLOWED: anything the actions can do, as strong as the player asks. The admin panel is meant to feel HUGE.
Be literal with numbers the player gives: "100 soldiers" = summon 100 Barbarian; "1000 gold" = give 1000 Gold;
"freeze them for a minute" = 60 seconds; "x100" / "в 100 раз" = power 100 or factor 100.
When NO number is given, leave the number field out: the game then uses its own big defaults
(30000 wood, 6000 gold, 50 troops, every land, max building levels, x10 army damage...).
"unlimited / infinite / max / безлимит / бесконечно / максимум / миллион" resources = give with amount 999999
(resource "all" when they ask for all resources). "open all lands / все участки / все локации / вся база" = expand with
no count (unlocks every land) plus bridge. "upgrade everything" = level_up with no building and levels 10.
The only limit is 200 troops per player (the game enforces it; still ask for the full number).
Screen and control tricks are allowed: "disable everyone's keyboards and mice" = disable_controls on everyone,
"flip their screens" = screen flip, "make it night" = weather night.

WHAT MUST BE REFUSED (refused=true, actions=[], short reason in the command's language):
- things that do not exist in this game: creepers, dragons, zombies, cars, guns, planes, new unit types, new buildings,
  moving/spawning/teleporting the PLAYER'S CHARACTER ("spawn me in the middle of the map"), flying, changing the map;
- kicking, banning, removing or eliminating players, ending or winning the round directly;
- anything with Robux, game passes, VIP, ADMIN pass, tickets, donations, admin rights, or anything that lasts after the round;
- sexual, hateful or real-world harmful content.
If the command mixes allowed and not-allowed parts, do the allowed parts and mention the rest in the caption.

TARGETS: "author", "enemies" (everyone except the author), "everyone", "random_enemy", "except:<name>", or an exact
player name from the players list. In the AUTHOR's command "me/my/I/мне/мой" = author. In an ADDITION, "me/my/I" means
the player who wrote that addition (use their exact name), and "him/the author/автору" means the author.
For attack and teleport_troops, target = whose army moves; victim / to = where it goes.

ADDITIONS modify the command, in order: redirect targets ("but it hits the author"), change strength ("x10",
"half"), add new effects ("and give me 100 archers" -> summon for that player), or cancel ("cancel", "nothing happens"
-> cancelled=true). If ONE addition asks for something not allowed or not in the game, skip only that addition and put
its player's name in rejected_additions; everything else still runs.

ACTIONS (fields in brackets):
damage_troops [percent 1-100, style meteor|lightning] meteors/lightning/any attack on troops
kill_troops - wipe out troops;  heal_troops [percent];  damage_base [percent] hits a town hall (never below 1 HP);  heal_base [percent]
summon [unit, count] troops appear at the target's barracks;  give [resource or "all", amount, factor for "double"]
take [resource or "all", percent];  steal [resource or "all", percent, to = receiver];  swap_resources [to]
freeze [seconds] troops and workers stop;  slow [seconds];  haste [seconds, power 1-5] troops move/attack faster
boost_army [seconds, power 1-10] more damage;  buff_troops [percent -90..900] permanent HP+damage of current troops (negative = weaken)
invincible [seconds] nothing can hurt them;  shield [seconds] base takes less damage;  boost_workers [seconds, power]
instant_build - finish upgrades/training/research/crafting now;  level_up [building or empty for all, levels, count]
level_down [building, levels];  research_up [unit or empty for all, levels];  expand [count] unlock lands for free
bridge - build their bridge;  capture_island [count] take neutral/enemy islands (never town halls)
attack [victim] send the army at a player's town hall;  teleport_troops [to: home|center|<player name>]
convert_troops [percent, to] troops switch sides;  disable_controls [seconds] the player cannot give orders
screen [effect blind|shake|flip|blur|rainbow, seconds] on the target's screen;  weather [effect night|day|rain|snow|fog|disco, seconds] for everyone
announce [text] big text on everyone's screen
Seconds: up to 120. Use as many actions as needed (max 16).

caption: one short hype line (max 70 characters) in the SAME language as the command, e.g. "Bob получил 100 воинов!".
Reply with JSON only.]]
local function schema()
    local str={type='STRING'};local int={type='INTEGER'}
    local resources=table.clone(Actions.Resources);resources[#resources+1]='all'
    local effects=table.clone(Actions.ScreenEffects);for _,w in ipairs(Actions.Weather) do effects[#effects+1]=w end
    return {type='OBJECT',properties={
        caption=str,refused={type='BOOLEAN'},cancelled={type='BOOLEAN'},reason=str,rejected_additions={type='ARRAY',items=str},
        actions={type='ARRAY',items={type='OBJECT',properties={
            type={type='STRING',enum=Actions.Types},target=str,
            unit={type='STRING',enum=Actions.UnitKinds},resource={type='STRING',enum=resources},
            building={type='STRING',enum=Actions.Buildings},effect={type='STRING',enum=effects},
            style={type='STRING',enum={'meteor','lightning'}},victim=str,to=str,text=str,
            count=int,amount=int,percent=int,seconds=int,power=int,levels=int,factor=int,
        },required={'type'}}},
    },required={'caption','actions'}}
end
local secret,secretChecked=nil,false
local workingModel,useUrlKey=nil,false
local function getSecret()
    if not secretChecked then
        secretChecked=true
        local ok,value=pcall(function() return HttpService:GetSecret(SECRET_NAME) end)
        if ok then secret=value else warn('[AdminBrain] No '..SECRET_NAME..' secret, using the local interpreter: '..tostring(value)) end
    end
    return secret
end
function Brain.available() return getSecret()~=nil end
local function post(model,body)
    local key=getSecret();if not key then return nil,'no key' end
    local request={Url=BASE..model..':generateContent',Method='POST',Headers={['Content-Type']='application/json'},Body=body}
    if useUrlKey then request.Url=key:AddPrefix(request.Url..'?key=') else request.Headers['x-goog-api-key']=key end
    local ok,response=pcall(function() return HttpService:RequestAsync(request) end)
    if not ok and not useUrlKey then
        -- some runtimes only accept a Secret inside the URL
        useUrlKey=true
        request.Headers['x-goog-api-key']=nil;request.Url=key:AddPrefix(BASE..model..':generateContent?key=')
        ok,response=pcall(function() return HttpService:RequestAsync(request) end)
    end
    if not ok then return nil,tostring(response) end
    return response
end
local function parse(response)
    local ok,data=pcall(function() return HttpService:JSONDecode(response.Body) end)
    if not ok or type(data)~='table' then return nil end
    local c=data.candidates and data.candidates[1]
    local parts=c and c.content and c.content.parts
    local text=''
    for _,part in ipairs(parts or {}) do if type(part.text)=='string' and not part.thought then text=text..part.text end end
    text=text:gsub('^%s*```json',''):gsub('^%s*```',''):gsub('```%s*$','')
    local ok2,plan=pcall(function() return HttpService:JSONDecode(text) end)
    if ok2 and type(plan)=='table' then return plan end
    return nil
end
-- job: see WishRules.thinking
function Brain.ask(job)
    if not getSecret() then return nil end
    local input={author=job.author,command=job.command,additions=job.additions,players=job.players}
    local config={temperature=.4,maxOutputTokens=1500,responseMimeType='application/json',responseSchema=schema()}
    local order={}
    if workingModel then order[1]=workingModel end
    for _,m in ipairs(MODELS) do if m~=workingModel then order[#order+1]=m end end
    local attempts=0
    for _,model in ipairs(order) do
        attempts+=1
        local cfg=table.clone(config)
        if model:find('2.5',1,true) then cfg.thinkingConfig={thinkingBudget=0} end
        local body=HttpService:JSONEncode({systemInstruction={parts={{text=SYSTEM}}},
            contents={{role='user',parts={{text=HttpService:JSONEncode(input)}}}},generationConfig=cfg})
        local response,err=post(model,body)
        if not response then
            -- a dropped connection: one more try (next model) before the built-in dictionary takes over
            warn('[AdminBrain] Request failed: '..tostring(err))
            if attempts>=2 then return nil end
            task.wait(.5)
        elseif response.Success then
            local plan=parse(response)
            if plan then workingModel=model;return plan end
            warn('[AdminBrain] '..model..' returned an unreadable answer')
            if attempts>=2 then return nil end
        elseif response.StatusCode==404 or (response.StatusCode==400 and not tostring(response.Body):find('API key',1,true)) then
            -- model retired or config not supported: try the next one
            warn('[AdminBrain] '..model..' -> HTTP '..response.StatusCode)
        else
            warn('[AdminBrain] HTTP '..tostring(response.StatusCode)..' '..tostring(response.Body):sub(1,200))
            -- busy / overloaded: try once more; a bad key is not going to fix itself
            local code=tonumber(response.StatusCode) or 0
            if attempts>=2 or not (code==429 or code>=500) then return nil end
            task.wait(1)
        end
    end
    return nil
end
return Brain
