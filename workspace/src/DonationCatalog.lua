local Catalog={}
Catalog.Version=1
Catalog.Items={
 {id='trail_egg',kind='Trail',title='EGG TRAIL',detail='Pastel spark trail behind your avatar.',passId=0,colors={Color3.fromRGB(255,221,74),Color3.fromRGB(255,116,177)}},
 {id='trail_leaf',kind='Trail',title='LEAF TRAIL',detail='Green leaf colored trail.',passId=0,colors={Color3.fromRGB(58,204,94),Color3.fromRGB(157,244,92)}},
 {id='trail_gold',kind='Trail',title='GOLD SPARK',detail='Warm golden trail.',passId=0,colors={Color3.fromRGB(255,204,67),Color3.fromRGB(255,245,167)}},
 {id='trail_ice',kind='Trail',title='ICE TRAIL',detail='Cool blue trail.',passId=0,colors={Color3.fromRGB(92,220,255),Color3.fromRGB(132,130,255)}},
 {id='aura_camp',kind='Aura',title='CAMPFIRE AURA',detail='Soft orange glow around your avatar.',passId=0,color=Color3.fromRGB(255,151,62)},
 {id='aura_admin',kind='Aura',title='ADMIN AURA',detail='Gold outline for admin supporters.',passId=0,color=Color3.fromRGB(255,221,74)},
 {id='aura_star',kind='Aura',title='STAR AURA',detail='Purple outline with a bright core.',passId=0,color=Color3.fromRGB(196,112,255)},
 {id='aura_frost',kind='Aura',title='FROST AURA',detail='Cyan outline for a cool camp look.',passId=0,color=Color3.fromRGB(106,223,255)},
 {id='tag_founder',kind='NameTag',title='FOUNDER TAG',detail='Gold FOUNDER label above your name.',passId=0,color=Color3.fromRGB(255,221,74)},
 {id='tag_builder',kind='NameTag',title='BUILDER TAG',detail='Green BUILDER label above your name.',passId=0,color=Color3.fromRGB(102,224,112)},
 {id='tag_conqueror',kind='NameTag',title='CONQUEROR TAG',detail='Red CONQUEROR label above your name.',passId=0,color=Color3.fromRGB(255,102,88)},
 {id='tag_night',kind='NameTag',title='NIGHT WATCH',detail='Blue NIGHT WATCH label above your name.',passId=0,color=Color3.fromRGB(116,184,255)},
 {id='banner_emerald',kind='Banner',title='EMERALD FLAG',detail='Green banner plate behind your name.',passId=0,color=Color3.fromRGB(60,196,98)},
 {id='banner_royal',kind='Banner',title='ROYAL FLAG',detail='Blue banner plate behind your name.',passId=0,color=Color3.fromRGB(74,150,255)},
 {id='banner_sunset',kind='Banner',title='SUNSET FLAG',detail='Orange banner plate behind your name.',passId=0,color=Color3.fromRGB(255,133,76)},
 {id='banner_violet',kind='Banner',title='VIOLET FLAG',detail='Purple banner plate behind your name.',passId=0,color=Color3.fromRGB(183,102,255)},
}
local byId={};for _,item in ipairs(Catalog.Items) do byId[item.id]=item end
function Catalog.get(id)return type(id)=='string' and byId[id] or nil end
function Catalog.list()return Catalog.Items end
function Catalog.isValid(id)return byId[id]~=nil end
function Catalog.hasPass(item)return item and tonumber(item.passId or 0) and tonumber(item.passId or 0)>0 end
return Catalog
