-- Turns an admin command (plus the roulette additions) into a plan of game actions with Gemini.
-- The API key lives in the experience's Secrets store as GEMINI_API_KEY; it never reaches clients.
-- Returns nil on any problem, and WishRules then falls back to its local interpreter.
local HttpService=game:GetService('HttpService')
local Brain={}
local SECRET_NAME='GEMINI_API_KEY'
local MODELS={'gemini-2.5-flash','gemini-flash-latest','gemini-2.0-flash'}
local BASE='https://generativelanguage.googleapis.com/v1beta/models/'
local BUILDINGS={'Townhall','Barracks','Campsite','LumberHut','MinerHut','GoldMine','Sawmill','Foundry','OreMinerHut','CrystalMinerHut','TrainingCamp','BuilderHut'}
local ACTIONS={'damage_troops','kill_troops','heal_troops','damage_base','heal_base','summon','give','take','steal',
    'freeze','slow','boost_army','boost_workers','shield','instant_build','level_up','buff_troops','attack'}
local SYSTEM=[[
You are the ADMIN PANEL of the Roblox strategy game "BATTLE BUT WITH ADMIN PANEL".
Players build bases, gather resources, train troops and capture each other's town halls.
Every 2 minutes one player (the author) types ANY command. Sometimes a roulette lets every other
player append their own text to it ("additions"). You turn the final command into game actions.

Rules:
- Execute the command if it can be done with the actions below (any wording, any language, typos are fine;
  obvious equivalents count: "nuke them" = damage_troops, "make me rich" = give Gold, "stop them" = freeze).
- If the command does not fit the game's actions (it asks for something the game has no action for, e.g.
  "turn everyone into chickens", "give me admin", "change the sky colour") or is sexual, hateful or real-world
  harmful: set refused=true, actions=[], and a short reason. Do not invent a substitute effect.
- Additions modify the command, in order. They can redirect the target ("but it hits the author"),
  weaken or strengthen it ("half strength", "x10"), add new effects, or cancel it ("cancel", "nothing happens").
  Set cancelled=true only if an addition clearly cancels the whole command.
- If a single addition does not fit the game's actions, ignore only that addition and put its player's name in
  rejected_additions. The command and the other additions still run.
- target: "author", "enemies" (everyone except the author), "everyone", "random_enemy", or an exact player name
  from the players list. For "attack", target is whose army attacks and victim is the player being attacked.
- Numbers: count 1-15 (summon), amount (give; Gold up to 150, Log up to 1200, Stone up to 800, others up to 80-250),
  percent 10-100, seconds 3-60, power 1-3. Use what the player asked for; the game clamps the rest.
- Actions:
  damage_troops (any attack on troops, percent of HP, style meteor|lightning), kill_troops, heal_troops,
  damage_base (hit a town hall, percent of HP, never fully destroys it), heal_base,
  summon (unit Barbarian|Archer|Giant|Wizard, count), give (resource, amount), take (resource, percent),
  steal (from target to author, resource, percent), freeze (troops fully stop, seconds), slow (seconds),
  boost_army (more damage, seconds, power), boost_workers (faster gathering, seconds, power),
  shield (base takes less damage, seconds), instant_build (finish upgrades/training/research now),
  level_up (building, count), buff_troops (permanent bigger HP and damage for current troops, percent), attack (victim).
- Use 1 to 4 actions.
- caption: one short hype line (max 70 characters) in the SAME language as the command, describing what happens,
  no swearing, e.g. "Метеоритный дождь накрыл армию Bob!" or "Alice summoned 5 giants!".
- reason (when refused): one short line in the SAME language as the command, e.g. "В игре нельзя превращать в куриц".
Reply with JSON only.]]
local function schema()
    local str={type='STRING'};local int={type='INTEGER'}
    local resources={'Log','Stone','Gold','Plank','Iron Ore','Iron Bar','Crystal','Trophy','all'}
    return {type='OBJECT',properties={
        caption=str,refused={type='BOOLEAN'},cancelled={type='BOOLEAN'},reason=str,rejected_additions={type='ARRAY',items=str},
        actions={type='ARRAY',items={type='OBJECT',properties={
            type={type='STRING',enum=ACTIONS},target=str,
            unit={type='STRING',enum={'Barbarian','Archer','Giant','Wizard'}},
            resource={type='STRING',enum=resources},building={type='STRING',enum=BUILDINGS},
            victim=str,style={type='STRING',enum={'meteor','lightning'}},count=int,amount=int,percent=int,seconds=int,power=int,
        },required={'type','target'}}},
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
    local config={temperature=.8,maxOutputTokens=700,responseMimeType='application/json',responseSchema=schema()}
    local order={}
    if workingModel then order[1]=workingModel end
    for _,m in ipairs(MODELS) do if m~=workingModel then order[#order+1]=m end end
    for _,model in ipairs(order) do
        local cfg=table.clone(config)
        if model:find('2.5',1,true) then cfg.thinkingConfig={thinkingBudget=0} end
        local body=HttpService:JSONEncode({systemInstruction={parts={{text=SYSTEM}}},
            contents={{role='user',parts={{text=HttpService:JSONEncode(input)}}}},generationConfig=cfg})
        local response,err=post(model,body)
        if not response then warn('[AdminBrain] Request failed: '..tostring(err));return nil end
        if response.Success then
            local plan=parse(response)
            if plan then workingModel=model;return plan end
            warn('[AdminBrain] '..model..' returned an unreadable answer');return nil
        elseif response.StatusCode==404 or (response.StatusCode==400 and not tostring(response.Body):find('API key',1,true)) then
            -- model retired or config not supported: try the next one
            warn('[AdminBrain] '..model..' -> HTTP '..response.StatusCode)
        else
            warn('[AdminBrain] HTTP '..tostring(response.StatusCode)..' '..tostring(response.Body):sub(1,200));return nil
        end
    end
    return nil
end
return Brain
