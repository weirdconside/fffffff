-- Built-in dictionary of admin commands (Russian + English).
-- plan(s,e,true)  -> instant plan when EVERY word of the command (and of each addition) is known, else nil (ask the AI)
-- plan(s,e,false) -> best-effort plan when the AI is unavailable; unknown words are ignored
local Commands={}

-- ------------------------------------------------------------------ text
-- string.lower does not touch Cyrillic, so it is lowered by hand (and ё -> е)
function Commands.lower(text)
    text=string.lower(tostring(text or ''))
    local ok,out=pcall(function()
        local parts={}
        for _,c in utf8.codes(text) do
            if c>=0x410 and c<=0x42F then c=c+0x20 elseif c==0x401 or c==0x451 then c=0x435 end
            parts[#parts+1]=utf8.char(c)
        end
        return table.concat(parts)
    end)
    return ok and out or text
end
local lower=Commands.lower
local function set(list) local t={};for _,v in ipairs(list) do t[v]=true end;return t end

-- ------------------------------------------------------------------ vocabulary
-- English words match exactly or with a plain suffix (s, es, ed, ing, er...); a trailing * means "any ending".
-- Russian entries are stems and match any ending. Entries with a space are exact phrases.
local G={
    summon={'spawn','summon','create','recruit','hire','reinforce','reinforcements','call','conjure','заспавн','спавн','призов','призыв','призва','призвать','созда','вызов','вызови','вызвать','найм','найми','наним','подкреп','рекрут','зарекрут','наколдуй'},
    give={'give','grant','add','gift','rain','more','want','need','get','drop','send me','дай','дать','дайте','выдай','выда','добав','начисл','подар','насып','отсып','получ','хочу','нужн','больше','накин','закин','отправь мне','пришли'},
    double={'double','doubled','triple','tripled','twice','удво','утро','вдвое','втрое','двойн','тройн'},
    take={'remove','take','delete','lose','reset','zero','drain','clear','убер','отним','отобр','забер','забрать','обнул','удал','сбрось','сбрас','лиши','отними','слей','обанкроть','bankrupt'},
    steal={'steal','rob','loot','heist','pickpocket','укра','укради','ограб','стащ','своруй','сворова','стыр','отжать','отожми','грабь','обчист'},
    swap={'swap','switch','exchange','trade','поменя','обменя','обмен','смени'},
    convert={'convert','betray','traitor','defect','join','переман','перевербу','завербу','предат','предад','перейд','переход'},
    teleport={'teleport','tp','warp','blink','телепорт','тп','перенес','перемест','переброс','закинь'},
    attack={'attack','invade','raid','charge','assault','march','send','атак','напад','напасть','рейд','штурм','вперед','иди','идите','пошли','отправ','марш','наступ','в бой'},
    kill={'kill','destroy','annihilate','obliterate','exterminate','murder','slay','eliminate','wipe','erase','убей','убить','убив','убейте','уничтож','сотри','истреб','перебей','ликвид','прикончи','грохни','замочи','снеси','разнеси','разруш','сломай','сломать'},
    damage={'meteor','meteors','meteorite','meteorites','nuke','bomb','bombs','fireball','explode','explosion','explo*','rocket','rockets','missile','missiles','strike','smite','hurt','hit','blast','shoot','burn','fire','airstrike','artillery','asteroid','asteroids','deal','blow','smash','crush','bombard','огненн','шар','shower','метеор','ядер','бомб','огн','огонь','взорв','ракет','удар','поджар','сожги','сжечь','подожги','атомн','обстрел','артилл','ранить','рань','бей','бомбан','стрельн','стреля','жахни','вдарь','астероид','нанеси','нанести'},
    lightning={'lightning','thunder','storm','zap','bolt','молни','гром','шторм','буря','бурю'},
    heal={'heal','cure','restore','revive','regen','regenerate','medic','fix','repair','лечи','лечен','вылеч','исцел','хил','восстан','реген','почин','отремонт','ремонт','оживи','воскрес','подлеч'},
    freeze={'freeze','frozen','frost','ice','stun','stop','paralyze','petrify','замороз','заморож','лед','льд','стоп','останов','оглуш','парализ','застын','окамен','обездвиж'},
    slow={'slow','slower','snail','sleep','sleepy','tired','sluggish','замедл','медлен','улитк','усып','сонн','тормоз'},
    haste={'fast','faster','speed','speedy','haste','hurry','sprint','quick','quicker','rapid','ускор','быстр','скорост','разгон','шустр'},
    power={'boost','strong','stronger','power','powerful','buff','rage','damage','усил','сильн','мощ','бафф','ярост','урон','прокач'},
    bigger={'bigger','huge','tank','tanky','health','hp','tough','tougher','огромн','здоров','танк','крепк','прочн','хп','живуч'},
    weaken={'weaken','nerf','debuff','weaker','ослаб','нерф','дебафф'},
    invincible={'invincible','invulnerable','immortal','godmode','unkillable','god mode','неуязв','бессмерт','неубиваем'},
    peace={'no kill','dont kill','do not kill','stop fighting','peace','ceasefire','мир','перемири','не убив','не атак','не драт','без драк','не нападать'},
    shield={'shield','shields','protect','protection','fortify','wall','walls','defend','defense','defence','armor','armour','dome','щит','защит','укреп','оборон','брон','стен','купол'},
    workers={'worker','workers','production','economy','farm','farming','mining','gather','gathering','miner','miners','lumberjack','lumberjacks','рабоч','эконом','производ','добыч','фарм','шахтер','лесоруб','сбор'},
    build={'build','construct','construction','finish','instant','instantly','постро','строй','стройк','строит','достро','мгновен','моментал'},
    level={'upgrade','level','levels','lvl','levelup','max','maximum','improve','улучш','прокач','уровн','апгрейд','апни','макс','повыс'},
    down={'downgrade','delevel','lower','demote','понизь','пониз','даунгрейд','ухудш','откат'},
    research={'research','study','tech','technology','исследов','изучи','изуч','технолог'},
    expand={'expand','expansion','unlock','open','расшир','разблок','откр'},
    land={'land','lands','plot','plots','territory','territories','земл','участ','территор'},
    bridge={'bridge','мост'},
    island={'island','islands','остров'},
    capture={'capture','conquer','take over','claim','захват','завоюй','завоев','займи','присвой'},
    lock={'disable','block','lock','turn off','switch off','отключ','заблок','выключ','блокир','запрет'},
    controls={'control','controls','keyboard','keyboards','mouse','mice','input','click','clicks','button','buttons','клав','мыш','управлен','кнопк','ввод','клик'},
    blind={'blind','blindness','blackout','black screen','ослеп','слеп','черный экран','темный экран','затемн'},
    shake={'shake','earthquake','quake','tremble','shaking','тряс','тряск','землетряс','затряс','встряхн'},
    flip={'flip','upside','upsidedown','invert','rotate','перевер','вверх ногами','кверх','вращ'},
    blur={'blur','blurry','dizzy','drunk','размыт','размой','мыло','пьян','головокруж'},
    rainbow={'rainbow','colorful','psychedelic','радуг','радужн','психодел'},
    night={'night','dark','midnight','ночь','ночн','темнот','стемн'},
    day={'day','sun','sunny','daylight','день','дневн','солнц','светло'},
    rain={'rain','rainy','дожд','ливень','ливн'},
    snow={'snow','snowy','winter','blizzard','снег','снеж','зим','метел'},
    fog={'fog','foggy','mist','туман'},
    disco={'disco','party','дискотек','диско','вечерин','тусов'},
    say={'say','announce','write','tell','shout','broadcast','скажи','напиши','объяви','крикни','сообщи','передай'},
    army={'army','armies','troop','troops','unit','units','force','forces','squad','military','soldier','soldiers','warrior','warriors','арми','войск','отряд','юнит','солдат','воин','бойц','боец','военн'},
    base={'base','bases','castle','townhall','hall','fort','fortress','tower','hq','town hall','баз','замок','замк','ратуш','крепост','башн','штаб'},
    home={'home','домой','дом','дому'},
    center={'center','centre','middle','центр','середин'},
    half={'half','weak','slightly','little','половин','вполсил','слабо','чуть','немного'},
    short={'short','briefly','shortly','коротк','ненадолго'},
    long={'long','forever','longer','долг','надолго','навсегда'},
    cancel={'cancel','block this','nothing happens','never mind','nevermind','отмен','ничего не будет','не выполн','не сработ'},
    sec={'sec','secs','second','seconds','сек','секунд'},
    min={'min','mins','minute','minutes','мин','минут'},
    max={'max','maximum','макс','максимум'},
    zero={'zero','reset','обнул','сбрось','сбрас'},
    buildingWord={'building','buildings','structure','structures','здани','строени','сооружен'},
    pct={'percent','процент'},
    me={'me','my','mine','myself','i','мне','меня','мой','моя','мое','мои','моих','моим','моей','мою','моему','моими','себе','себя','я','свою','свой','свои','своих','своим'},
    author={'author','the author','автор','тому кто написал','того кто написал','him','her','ему','его','ей'},
    enemies={'enemies','enemy','others','opponents','opponent','rivals','them','their','foes','everyone else','враг','вражеск','противник','остальн','чужих','чужие','других','их','им','ими','соперник'},
    everyone={'everyone','everybody','all players','each','всем','каждому','каждого','все игроки','всех игроков','всем игрокам'},
    allword={'all','все','всех','весь','всю','вся'},
    except={'except me','but me','not me','except for me','кроме меня','кроме себя','но не мне','не меня','не мне'},
    random={'random','someone','somebody','randomly','случайн','рандом','кому нибудь','кого нибудь','кому то'},
}
local UNITS={
    {kind='Giant',words={'giant','giants','гигант','великан'}},
    {kind='Wizard',words={'wizard','wizards','mage','mages','magician','magicians','sorcerer','sorcerers','маг','мага','магов','магам','магами','маги','волшебн','колдун','чародей'}},
    {kind='Archer',words={'archer','archers','bowman','bowmen','лучник','лучн','стрелк'}},
    {kind='Barbarian',words={'barbarian','barbarians','soldier','soldiers','warrior','warriors','military','fighter','fighters','troop','troops','варвар','солдат','воин','бойц','боец','военн','пехот'}},
}
local RESOURCES={
    {r='Gold',words={'gold','coin','coins','money','cash','золот','монет','деньг','бабк','бабл'}},
    {r='Plank',words={'plank','planks','board','boards','доск','досок'}},
    {r='Iron Ore',words={'ore','руд'}},
    {r='Iron Bar',words={'iron','ingot','ingots','желез','слит'}},
    {r='Crystal',words={'crystal','crystals','gem','gems','diamond','diamonds','кристал','алмаз','самоцвет'}},
    {r='Stone',words={'stone','stones','rock','rocks','камн','камен','камень'}},
    {r='Log',words={'wood','log','logs','timber','tree','trees','дерев','древес','брев','дров'}},
    {r='Trophy',words={'trophy','trophies','cup','cups','трофе','кубк'}},
    {r='all',words={'resource','resources','everything','ресурс','всего'}},
}
local BUILDINGS={
    {kind='Townhall',words={'townhall','town hall','hall','base','castle','ратуш','баз','замок','замк','штаб'}},
    {kind='Barracks',words={'barracks','barrack','казарм'}},
    {kind='Campsite',words={'campsite','camp','camps','лагер'}},
    {kind='GoldMine',words={'gold mine','goldmine','mine','золотая шахта','золотую шахту','шахт','рудник'}},
    {kind='LumberHut',words={'lumber hut','lumberhut','хижину лесоруба','хижина лесоруба'}},
    {kind='Sawmill',words={'sawmill','лесопилк'}},
    {kind='Foundry',words={'foundry','smelter','литейн','плавильн','кузниц'}},
    {kind='TrainingCamp',words={'training camp','trainingcamp','тренировочн'}},
    {kind='BuilderHut',words={'builder hut','builderhut','хижину строителя','строител'}},
}
local FILLER=set({
    'a','an','the','of','on','onto','to','for','from','at','in','into','with','and','or','but','then','also','plus','please','pls','plz','now',
    'right','just','only','very','so','some','lot','lots','bunch','many','much','up','down','let','lets','make','do','is','are','be','it','this',
    'that','these','those','its','every','as','like','than','too','really','super','mega','ultra','big','small','few','couple','pair','times',
    'x','by','over','around','near','there','here','ok','okay','yes','hey','admin','panel','command','go','who','whose','what','which','we',
    'us','our','you','your','he','she','they','his','hers','instead','again','each','other','own','same','both','until','till','while','during',
    'amount','number','full','fully','completely','totally','entire','whole','new','extra','free','rn','asap','immediately','quickly',
    'и','а','но','или','на','в','во','у','к','ко','с','со','по','за','из','от','до','для','о','об','при','под','над','же','ну','вот','это',
    'этот','эта','эти','эту','этим','того','тот','те','та','пожалуйста','плиз','пж','пжлст','сейчас','щас','очень','еще','тоже','также',
    'только','чуть','пару','пара','много','кучу','куча','немножко','сразу','срочно','давай','давайте','пусть','будет','будут','сделай',
    'сделать','сделайте','делай','штук','штуки','штуку','штука','раз','раза','х','как','чтобы','что','чтоб','так','такой','весь','свою',
    'нему','ним','ней','них','наш','наши','нашим','кто','кого','кому','нибудь','либо','туда','сюда','там','тут','здесь','го','ок','админ',
    'панель','команда','прямо','мега','супер','ультра','полностью','целиком','всё','новых','новые','новый','дополнительно','бесплатно',
    'количество','число','потом','затем','плюс','тоже','вместо','снова','опять','каждый','каждую','каждое','свое','своего','своей','том',
    'самый','самые','самых','целую','целый','всякий','любой','любых','разных','разные','кучку','мешок','гору','уровня','уровень','раунд',
    'включи','включить','запусти','устрой','устроить','start','enable','turn','on','пойдет','идет','пошел','пусть','сделайте','нам','вам',
    'случится','начнется','начни','let','lets','out','everywhere','везде','повсюду','am','ко','всему','миру','силы','силу','сила','силой','strength','hits','hit','попадет','попадёт','бьет','ударит','instead','вместо',
})
local NUMWORDS={one=1,two=2,three=3,four=4,five=5,six=6,seven=7,eight=8,nine=9,ten=10,twenty=20,fifty=50,hundred=100,thousand=1000,dozen=12,
    ['один']=1,['одного']=1,['одну']=1,['два']=2,['двух']=2,['две']=2,['три']=3,['трех']=3,['четыре']=4,['пять']=5,['пяти']=5,['шесть']=6,
    ['семь']=7,['восемь']=8,['девять']=9,['десять']=10,['десяти']=10,['двадцать']=20,['пятьдесят']=50,['сто']=100,['сотню']=100,['сотня']=100,
    ['двести']=200,['тысячу']=1000,['тысяча']=1000,['дюжину']=12}
local NEGATION=set({'не','ни','нельзя','dont','not','never','no','nobody','никто','никому','никого'})

local function cyr(s) return s:find('[\128-\255]')~=nil end
local SUFFIX={'','s','es','ed','d','ing','er','ers','n','ly','y'}
local function match(tok,stem)
    if stem:sub(-1)=='*' then local st=stem:sub(1,-2);return tok:sub(1,#st)==st end
    if cyr(stem) then
        if tok:sub(1,#stem)~=stem then return false end
        -- short Russian stems only take short endings (маг -> магов, but not магазин)
        local sl=utf8.len(stem) or 0;local extra=(utf8.len(tok) or 0)-sl
        if sl<=2 then return extra==0 end
        if sl==3 then return extra<=3 end
        return true
    end
    if tok==stem then return true end
    if tok:sub(1,#stem)~=stem then
        if stem:sub(-1)=='y' and tok==stem:sub(1,-2)..'ies' then return true end
        if stem:sub(-1)=='e' and tok==stem:sub(1,-2)..'ing' then return true end
        return false
    end
    local rest=tok:sub(#stem+1)
    for _,suf in ipairs(SUFFIX) do if rest==suf then return true end end
    return false
end
-- all single words of the vocabulary, for the "is every word known" test
local KNOWN={}
local function learn(list) for _,w in ipairs(list) do for part in w:gmatch('%S+') do KNOWN[#KNOWN+1]=part end end end
for _,list in pairs(G) do learn(list) end
for _,row in ipairs(UNITS) do learn(row.words) end
for _,row in ipairs(RESOURCES) do learn(row.words) end
for _,row in ipairs(BUILDINGS) do learn(row.words) end

-- ------------------------------------------------------------------ tokens
local function tokenize(text,players)
    local t=' '..lower(text)..' '
    t=t:gsub("n't",' not'):gsub("’",' ')
    t=t:gsub('(%d+)%s*%%',' %1 percent ')
    t=t:gsub("'s ",' ')
    -- whole player names become placeholders before punctuation is stripped (names may contain _)
    local names={}
    for _,pl in ipairs(players) do
        local n=lower(pl.name)
        if #n>=3 then
            local from=t:find(n,1,true)
            while from do
                local before,after=t:sub(from-1,from-1),t:sub(from+#n,from+#n)
                if before:match('[%w]') or after:match('[%w]') then from=t:find(n,from+#n,true)
                else
                    t=t:sub(1,from-1)..' zzname'..pl.index..'zz '..t:sub(from+#n):gsub("^'s",'')
                    from=t:find(n,1,true)
                end
            end
        end
        names[pl.index]=pl
    end
    t=t:gsub('[%p]',' ')
    local tokens={}
    for w in t:gmatch('%S+') do
        local tok={t=w}
        local idx=w:match('^zzname(%d+)zz$')
        if idx then tok.name=names[tonumber(idx)].name
        elseif tonumber(w) then tok.num=tonumber(w)
        elseif w:match('^[xх]%d+$') then tok.mult=tonumber(w:match('(%d+)$'))
        elseif NUMWORDS[w] then tok.num=NUMWORDS[w] end
        tokens[#tokens+1]=tok
    end
    -- a word that is not in the dictionary but starts a player's name is that player
    for _,tok in ipairs(tokens) do
        if not tok.name and not tok.num and not tok.mult and #tok.t>=3 then
            local known=FILLER[tok.t]
            if not known then for _,stem in ipairs(KNOWN) do if match(tok.t,stem) then known=true;break end end end
            if not known then
                for _,pl in ipairs(players) do if lower(pl.name):sub(1,#tok.t)==tok.t then tok.name=pl.name;break end end
            end
        end
    end
    return tokens
end
local function isKnown(tok)
    if tok.name or tok.num or tok.mult or FILLER[tok.t] then return true end
    for _,stem in ipairs(KNOWN) do if match(tok.t,stem) then return true end end
    return false
end
local function piece(tokens)
    local words={}
    for _,tok in ipairs(tokens) do words[#words+1]=tok.t end
    return {tokens=tokens,str=' '..table.concat(words,' ')..' '}
end
local function has(p,list)
    for _,entry in ipairs(list) do
        if entry:find(' ',1,true) then
            if p.str:find(' '..entry..' ',1,true) then return true end
        else
            for _,tok in ipairs(p.tokens) do if not tok.name and not tok.num and match(tok.t,entry) then return true end end
        end
    end
    return false
end
local function g(p,name) return has(p,G[name]) end
local function rowOf(p,rows)
    for _,row in ipairs(rows) do if has(p,row.words) then return row end end
end
-- splits a clause on "and / и / then / , ;" and glues parameter-only parts to the previous part
local SPLIT=set({'and','then','also','plus','и','потом','затем','плюс','а'})
local VERBS={'summon','give','double','take','steal','swap','convert','teleport','attack','kill','damage','lightning','heal','freeze','slow',
    'haste','power','bigger','weaken','invincible','peace','shield','build','level','down','research','expand','bridge','capture','lock',
    'blind','shake','flip','blur','rainbow','night','day','snow','fog','disco','say'}
local function hasVerb(p)
    for _,v in ipairs(VERBS) do if g(p,v) then return true end end
    -- "100 giants" on its own is a summon
    for i,tok in ipairs(p.tokens) do if tok.num and p.tokens[i+1] and rowOf(piece({p.tokens[i+1]}),UNITS) then return true end end
    return false
end
local function split(tokens)
    local parts,cur={},{}
    for _,tok in ipairs(tokens) do
        if SPLIT[tok.t] and not tok.name then if #cur>0 then parts[#parts+1]=cur;cur={} end
        else cur[#cur+1]=tok end
    end
    if #cur>0 then parts[#parts+1]=cur end
    local out={}
    for _,list in ipairs(parts) do
        local p=piece(list)
        if #out>0 and not hasVerb(p) then
            local prev=out[#out].tokens;for _,tok in ipairs(list) do prev[#prev+1]=tok end
            out[#out]=piece(prev)
        else out[#out+1]=p end
    end
    return out
end

-- ------------------------------------------------------------------ one part -> actions
-- ctx: {speaker=name, speakerIsAuthor=bool}
local function targetTag(p)
    if g(p,'except') then return 'except' end
    for _,tok in ipairs(p.tokens) do if tok.name then return 'name',tok.name end end
    if g(p,'everyone') then return 'everyone' end
    if g(p,'random') then return 'random' end
    if g(p,'enemies') then return 'enemies' end
    if g(p,'author') then return 'author' end
    if g(p,'me') then return 'me' end
    if g(p,'allword') then return 'all' end
    return nil
end
local function resolve(ctx,tag,value,harmful)
    if tag=='name' then return value end
    if tag=='author' and not ctx.speakerIsAuthor then return 'author' end
    if tag=='me' then return ctx.speakerIsAuthor and 'author' or ctx.speaker end
    if tag=='everyone' then return 'everyone' end
    if tag=='random' then return 'random_enemy' end
    -- "all" alone means all enemies for attacks and "all of mine" for everything else
    if tag=='all' then if not harmful then return ctx.speakerIsAuthor and 'author' or ctx.speaker end;tag='enemies' end
    -- him/her in the author's own command points at the others
    if tag=='author' and ctx.speakerIsAuthor then if harmful then tag='enemies' else return 'author' end end
    if tag=='enemies' or tag=='except' or tag==nil then
        if tag==nil and not harmful then return ctx.speakerIsAuthor and 'author' or ctx.speaker end
        return ctx.speakerIsAuthor and 'enemies' or ('except:'..ctx.speaker)
    end
    return nil
end
local function numbers(p)
    local info={}
    for i,tok in ipairs(p.tokens) do
        local nextTok=p.tokens[i+1]
        if tok.num then
            local unit=nextTok and piece({nextTok})
            if unit and has(unit,G.sec) then info.seconds=tok.num
            elseif unit and has(unit,G.min) then info.seconds=tok.num*60
            elseif unit and has(unit,G.pct) then info.percent=tok.num
            elseif nextTok and (nextTok.t=='раз' or nextTok.t=='раза' or nextTok.t=='times') then info.mult=tok.num
            elseif not info.plain then info.plain=tok.num end
        elseif tok.mult then info.mult=tok.mult end
    end
    return info
end
local function unitPairs(p)
    local out={}
    for i,tok in ipairs(p.tokens) do
        if not tok.num and not tok.name then
            local row=rowOf(piece({tok}),UNITS)
            if row then
                local prev=p.tokens[i-1];local prev2=p.tokens[i-2]
                local count=(prev and prev.num) or (prev2 and prev2.num and FILLER[prev.t] and prev2.num) or nil
                -- "soldiers" after "army" words is not a separate unit type
                out[#out+1]={kind=row.kind,count=count}
            end
        end
    end
    -- merge duplicates of the generic Barbarian group ("my soldiers" + number elsewhere)
    return out
end
local function parsePart(ctx,p)
    local acts={}
    local n=numbers(p)
    local tag,tagValue=targetTag(p)
    local function T(harmful) return resolve(ctx,tag,tagValue,harmful) end
    local function add(a) acts[#acts+1]=a;return a end
    local res=rowOf(p,RESOURCES)
    local rpairs={}
    for i,tok in ipairs(p.tokens) do
        if not tok.num and not tok.name then
            local row=rowOf(piece({tok}),RESOURCES)
            if row then
                local prev=p.tokens[i-1];local prev2=p.tokens[i-2]
                rpairs[#rpairs+1]={r=row.r,amount=(prev and prev.num) or (prev2 and prev2.num and FILLER[prev.t] and prev2.num) or nil}
            end
        end
    end
    local building=rowOf(p,BUILDINGS)
    local secs=n.seconds or (g(p,'min') and 60) or (n.plain and n.plain<=600 and n.plain) or nil
    local speakerTo=ctx.speakerIsAuthor and 'author' or ctx.speaker
    if g(p,'peace') then add({type='invincible',target='everyone',seconds=n.seconds or 30});return acts end
    if g(p,'lock') and g(p,'controls') then add({type='disable_controls',target=T(true),seconds=secs});return acts end
    for _,fxName in ipairs({'blind','shake','flip','blur','rainbow'}) do
        if g(p,fxName) then add({type='screen',effect=fxName,target=T(true),seconds=secs});return acts end
    end
    if g(p,'disco') then add({type='weather',effect='disco',seconds=secs});return acts end
    if g(p,'night') then add({type='weather',effect='night',seconds=secs});return acts end
    if g(p,'snow') then add({type='weather',effect='snow',seconds=secs});return acts end
    if g(p,'fog') then add({type='weather',effect='fog',seconds=secs});return acts end
    local attackWords=g(p,'damage') or g(p,'kill') or g(p,'lightning')
    if g(p,'rain') and not res and not rowOf(p,UNITS) and not attackWords then add({type='weather',effect='rain',seconds=secs});return acts end
    if g(p,'day') and not g(p,'freeze') then add({type='weather',effect='day',seconds=secs});return acts end
    if g(p,'steal') then add({type='steal',target=T(true),resource=res and res.r or 'all',percent=n.percent or (n.plain and n.plain<=100 and n.plain) or nil,to=speakerTo});return acts end
    if g(p,'swap') then add({type='swap_resources',target=tag and T(true) or 'random_enemy',to=speakerTo});return acts end
    if g(p,'convert') then add({type='convert_troops',target=T(true),percent=n.percent or (n.plain and n.plain<=100 and n.plain) or nil,to=speakerTo});return acts end
    if g(p,'teleport') then
        local to=g(p,'center') and 'center' or g(p,'home') and 'home' or (tag=='name' and tagValue) or 'enemies'
        add({type='teleport_troops',target=(tag=='everyone' and 'everyone') or speakerTo,to=to});return acts
    end
    if g(p,'bridge') then add({type='bridge',target=T(false)});return acts end
    if g(p,'island') then add({type='capture_island',target=T(false),count=n.plain or (g(p,'allword') and 20) or nil});return acts end
    if g(p,'land') or (g(p,'expand') and not building) then add({type='expand',target=T(false),count=n.plain});return acts end
    if g(p,'research') then local u=rowOf(p,UNITS);add({type='research_up',target=T(false),unit=u and u.kind or nil,levels=n.plain});return acts end
    if g(p,'level') or (g(p,'down') and (building or g(p,'buildingWord'))) then
        local levels=g(p,'max') and 10 or n.plain
        if g(p,'down') then add({type='level_down',target=T(true),building=building and building.kind or nil,levels=levels})
        else add({type='level_up',target=T(false),building=building and building.kind or nil,levels=levels}) end
        return acts
    end
    if g(p,'workers') and (g(p,'haste') or g(p,'power') or g(p,'give')) then add({type='boost_workers',target=T(false),seconds=secs,power=n.mult});return acts end
    if g(p,'build') then add({type='instant_build',target=T(false)});return acts end
    if g(p,'attack') and not g(p,'damage') and not g(p,'kill') and not g(p,'lightning') and not g(p,'give') and not res and #unitPairs(p)==0 then
        add({type='attack',target=speakerTo,victim=(tag=='name' and tagValue) or nil});return acts
    end
    if g(p,'heal') then add({type=g(p,'base') and 'heal_base' or 'heal_troops',target=T(false),percent=n.percent}) end
    if g(p,'freeze') then add({type='freeze',target=T(true),seconds=secs})
    elseif g(p,'slow') then add({type='slow',target=T(true),seconds=secs}) end
    if g(p,'invincible') then add({type='invincible',target=T(false),seconds=secs}) end
    if g(p,'shield') then add({type='shield',target=T(false),seconds=secs}) end
    if g(p,'weaken') then add({type='buff_troops',target=T(true),percent=-(n.percent or 50)})
    elseif g(p,'bigger') and (g(p,'army') or #acts==0) then add({type='buff_troops',target=T(false),percent=n.percent or 100}) end
    local harmfulWords=g(p,'kill') or g(p,'damage') or g(p,'lightning')
    if g(p,'haste') and not harmfulWords then add({type='haste',target=T(false),seconds=secs,power=n.mult}) end
    if g(p,'power') and not harmfulWords and not g(p,'bigger') and (g(p,'army') or not (tag=='enemies' or tag=='name' or tag=='all')) then
        add({type='boost_army',target=T(false),seconds=secs,power=n.mult})
    end
    -- resources
    local giveWord=g(p,'give') or g(p,'double')
    if #rpairs>0 and g(p,'take') then
        local pct=(g(p,'zero') or g(p,'allword')) and 100 or n.percent or (n.plain and n.plain<=100 and n.plain) or nil
        for _,pair in ipairs(rpairs) do add({type='take',target=T(true),resource=pair.r,percent=pct}) end
    elseif #rpairs>0 and (giveWord or (#acts==0 and not harmfulWords)) then
        local factor=g(p,'double') and ((has(p,{'triple','tripled','утро','втрое','тройн'}) and 3) or 2) or n.mult
        for _,pair in ipairs(rpairs) do
            add({type='give',target=T(false),resource=pair.r,amount=pair.amount or (#rpairs==1 and n.plain) or nil,factor=factor})
        end
    end
    -- troops
    local pairs_=unitPairs(p)
    local summonWord=g(p,'summon') or g(p,'give')
    if #pairs_>0 and (summonWord or n.plain or #acts==0) and not harmfulWords and not g(p,'heal') then
        local seen={}
        for _,pair in ipairs(pairs_) do
            if not seen[pair.kind] or pair.count then
                seen[pair.kind]=true
                add({type='summon',target=T(false),unit=pair.kind,count=pair.count or (#pairs_==1 and n.plain) or nil})
            end
        end
    elseif #pairs_==0 and (g(p,'summon') or (g(p,'give') and g(p,'army'))) and #acts==0 and not harmfulWords and #rpairs==0 then
        add({type='summon',target=T(false),unit='Barbarian',count=n.plain})
    end
    -- attacks
    if g(p,'kill') then
        if g(p,'base') then add({type='damage_base',target=T(true),percent=100}) else add({type='kill_troops',target=T(true)}) end
    elseif g(p,'lightning') then
        add({type=g(p,'base') and 'damage_base' or 'damage_troops',target=T(true),style='lightning',percent=n.percent})
    elseif g(p,'damage') or (g(p,'power') and (tag=='enemies' or tag=='name') and not g(p,'army')) then
        add({type=g(p,'base') and 'damage_base' or 'damage_troops',target=T(true),percent=n.percent})
    end
    return acts
end
-- modifiers written as an addition ("but half strength", "x10", "but on me", "for 5 seconds")
local function applyModifiers(ctx,p,actions)
    local n=numbers(p);local tag,value=targetTag(p);local changed=false
    local mult=n.mult or (g(p,'double') and 2) or (g(p,'half') and .5) or nil
    for _,a in ipairs(actions) do
        if mult then
            for _,k in ipairs({'count','amount','percent'}) do if a[k] then a[k]=a[k]*mult end end
            if not a.count and a.type=='summon' then a.count=10*mult end
            if not a.amount and a.type=='give' then a.factor=nil;a.amountMult=mult end
            if not a.percent and (a.type=='damage_troops' or a.type=='damage_base') then a.percent=math.min(100,60*mult) end
            a.power=mult>=1 and math.min(10,(a.power or 2)*mult) or 1
            changed=true
        end
        if g(p,'short') then a.seconds=5;changed=true end
        if g(p,'long') then a.seconds=120;changed=true end
        if n.seconds then a.seconds=n.seconds;changed=true end
        if tag then
            local harmful=a.type=='damage_troops' or a.type=='kill_troops' or a.type=='freeze' or a.type=='slow' or a.type=='damage_base' or a.type=='take' or a.type=='disable_controls' or a.type=='screen'
            local t=resolve(ctx,tag,value,harmful)
            if t and a.type~='weather' and a.type~='announce' then a.target=t;changed=true end
        end
    end
    return changed
end

-- ------------------------------------------------------------------ clauses
local function roster(s)
    local list={};local ids={}
    for id in pairs(s.players) do ids[#ids+1]=id end;table.sort(ids)
    for i,id in ipairs(ids) do list[#list+1]={index=i,id=id,name=s.players[id].name} end
    table.sort(list,function(a,b) return #a.name>#b.name end)
    return list
end
-- "скажи всем что ..." / "announce ..." -> text shown to everyone (taken from the FILTERED text)
local function announcement(raw,filtered)
    local words=lower(raw):gsub('[%p]',' ')
    local first={}
    for w in words:gmatch('%S+') do first[#first+1]=w;if #first>=4 then break end end
    if not first[1] or not has(piece({{t=first[1]}}),G.say) then return nil end
    local out={};local skip=true;local i=0
    for w in tostring(filtered):gmatch('%S+') do
        i=i+1
        local lw=lower(w):gsub('[%p]','')
        if skip and (i==1 or has(piece({{t=lw}}),G.everyone) or has(piece({{t=lw}}),G.allword) or lw=='что' or lw=='that' or lw=='everyone' or lw=='to') then
        else skip=false;out[#out+1]=w end
    end
    local text=table.concat(out,' ')
    return text~='' and text or nil
end
-- one clause -> actions (or modifiers). confident=false if any word is unknown.
local function parseClause(ctx,s,raw,filtered,existing)
    local tokens=tokenize(raw,roster(s))
    local confident=#tokens>0
    local text=announcement(raw,filtered or raw)
    if text then return {{type='announce',text=text}},true,false end
    for _,tok in ipairs(tokens) do
        if not isKnown(tok) then confident=false end
        if NEGATION[tok.t] then confident=false end
    end
    local whole=piece(tokens)
    if g(whole,'peace') or g(whole,'except') then
        confident=true
        for _,tok in ipairs(tokens) do if not isKnown(tok) then confident=false end end
    end
    if existing and g(whole,'cancel') then return {},true,false,true end
    -- "но по автору" / "but it hits the author": an addition starting with but/но changes the command first
    if existing and tokens[1] and (tokens[1].t=='but' or tokens[1].t=='но' or tokens[1].t=='только' or tokens[1].t=='only') then
        if applyModifiers(ctx,whole,existing) then return {},confident,true end
    end
    local acts={}
    for _,p in ipairs(split(tokens)) do
        for _,a in ipairs(parsePart(ctx,p)) do acts[#acts+1]=a end
    end
    local modified=false
    if #acts==0 and existing then modified=applyModifiers(ctx,whole,existing) end
    if #acts==0 and not modified then confident=false end
    return acts,confident,modified
end
function Commands.plan(s,e,strict)
    local authorName=s.players[e.recipient] and s.players[e.recipient].name or 'Player'
    local base=e.rawPrompt or e.prompt or ''
    local acts,confident=parseClause({speaker=authorName,speakerIsAuthor=true},s,base,e.prompt,nil)
    if strict and not confident then return nil end
    if #acts==0 then return {refused=true,reason='This command does not exist in the game.',actions={}} end
    local plan={actions=acts,rejected_additions={}}
    local ids={};for id in pairs(e.additions or {}) do ids[#ids+1]=id end;table.sort(ids)
    if s.wish and s.wish.ids then ids=s.wish.ids end
    for _,id in ipairs(ids) do
        local shown=e.additions and e.additions[id]
        if shown and shown~='' then
            local raw=(e.rawAdditions and e.rawAdditions[id]) or shown
            local who=s.players[id] and s.players[id].name or 'Player'
            local extra,ok,modified,cancel=parseClause({speaker=who,speakerIsAuthor=id==e.recipient},s,raw,shown,plan.actions)
            if strict and not ok then return nil end
            if cancel then plan.cancelled=true;plan.caption=who..' cancelled the command!';return plan end
            if #extra>0 then for _,a in ipairs(extra) do plan.actions[#plan.actions+1]=a end
            elseif not modified then plan.rejected_additions[#plan.rejected_additions+1]=who end
        end
    end
    for _,a in ipairs(plan.actions) do
        if a.amountMult then a.amount=math.floor((a.amount or 100)*a.amountMult);a.amountMult=nil end
    end
    return plan
end
Commands.tokenizeForTest=tokenize
return Commands
