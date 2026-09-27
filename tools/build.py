import copy, sys, base64
import numpy as np
from lxml import etree
from lib import *
import lobby as L
import lobby3 as L3

SRC = {  # existing script name -> new source file
    'RoundServer': 'new/RoundServer.server.lua', 'RoundState': 'new/RoundState.lua', 'WishRules': 'new/WishRules.lua',
    'RoundBots': 'new/RoundBots.lua', 'DonationServer': 'new/DonationServer.server.lua', 'DonationCatalog': 'new/DonationCatalog.lua',
    'DonationShop': 'new/DonationShop.lua', 'DonationClient': 'new/DonationClient.client.lua', 'LobbyUI': 'new/LobbyUI.lua',
    'AdminUI': 'new/AdminUI.lua', 'RoundClient': 'new/RoundClient.client.lua', 'MusicController': 'new/MusicController.client.lua', 'StudTheme': 'new/StudTheme.lua', 'RoundWorld': 'new/RoundWorld.lua',
    'RoundAnimations': 'new/RoundAnimations.lua', 'SceneEnvironment': 'new/SceneEnvironment.client.lua',
}
tree = etree.parse('orig.rbxlx')
root = tree.getroot()
top = {name_of(i): i for i in root.findall('Item')}
ws = top['Workspace']; rs = top['ReplicatedStorage']; sss = top['ServerScriptService']; sp = top['StarterPlayer']
lighting = top['Lighting']
# ------------------------------------------------------------------ lobby
lobby, ctx, tiles, spawn_cf = L3.build(tree)
old = child(ws, 'LobbyWorld')
idx = list(ws).index(old)
ws.remove(old)
ws.insert(idx, lobby)
spawn = child(ws, 'LobbySpawn')
set_prop(spawn, 'CFrame', 'CFrame', spawn_cf)
# Studio edit camera: open the place looking over the new harbour
cam = child(ws, 'Camera')
if cam is not None:
    set_prop(cam, 'CFrame', 'CFrame', look_at((-70, 75, -160), (55, 5, 0)))
    set_prop(cam, 'Focus', 'CFrame', at(55, 5, 0))
# ------------------------------------------------------------------ scripts
def set_source(it, path):
    src = open(path).read()
    set_prop(it, 'Source', 'ProtectedString', src)
found = set()
for it in root.iter('Item'):
    if it.get('class') in ('Script', 'LocalScript', 'ModuleScript'):
        n = name_of(it)
        if n in SRC:
            set_source(it, SRC[n]); found.add(n)
missing = set(SRC) - found
assert not missing, missing
shared = child(rs, 'ArmyRoundShared')
def add_script(parent, cls, name, path):
    props = [('Source', 'ProtectedString', open(path).read())]
    if cls != 'ModuleScript':
        props.append(('Disabled', 'bool', False))
    return item(cls, name, props, parent)
add_script(shared, 'ModuleScript', 'ShopIcons', 'new/ShopIcons.lua')
add_script(shared, 'ModuleScript', 'StudTransition', 'new/StudTransition.lua')
add_script(shared, 'ModuleScript', 'UISound', 'new/UISound.lua')
add_script(sss, 'ModuleScript', 'Perks', 'new/Perks.lua')
add_script(sss, 'ModuleScript', 'AdminBrain', 'new/AdminBrain.lua')
add_script(sss, 'ModuleScript', 'AdminCommands', 'new/AdminCommands.lua')
add_script(sss, 'ModuleScript', 'AdminActions', 'new/AdminActions.lua')
sps = child(sp, 'StarterPlayerScripts')
add_script(sps, 'LocalScript', 'LobbyAmbience', 'new/LobbyAmbience.client.lua')
add_script(sps, 'LocalScript', 'AdminFX', 'new/AdminFX.client.lua')
rf = item('ReplicatedFirst', 'ReplicatedFirst', ())
add_script(rf, 'ModuleScript', 'TitleLogo', 'new/TitleLogo.lua')   # shared with the round loading curtain
add_script(rf, 'LocalScript', 'TitleScreen', 'new/TitleScreen.client.lua')
root.insert(list(root).index(rs), rf)
# Lighting: the original lobby look, but without the washed-out "heaven" glare.
envs = child(rs, 'SceneEnvironments')
def setv(folder_, name, typ, value):
    it = child(folder_, name)
    if it is None:
        cls = {'Color3': 'Color3Value', 'double': 'NumberValue', 'string': 'StringValue', 'bool': 'BoolValue'}[typ]
        it = item(cls, name, (), folder_)
    set_prop(it, 'Value', typ, value)
def setfx(folder_, name, props):
    it = child(folder_, name)
    if it is not None:
        for k, t, v in props: set_prop(it, k, t, v)
LOBBY_VALUES = [('Brightness', 'double', 2.3), ('ExposureCompensation', 'double', -0.15), ('EnvironmentDiffuseScale', 'double', 0.6),
                ('EnvironmentSpecularScale', 'double', 0.35), ('Ambient', 'Color3', (150, 140, 140)), ('OutdoorAmbient', 'Color3', (92, 96, 110))]
LOBBY_FX = {'Bloom': [('Intensity', 'float', 0.3), ('Size', 'float', 18), ('Threshold', 'float', 2.6)],
            'ColorCorrection': [('Brightness', 'float', 0.0), ('Contrast', 'float', 0.08), ('Saturation', 'float', 0.12)],
            'SunRays': [('Intensity', 'float', 0.008)],
            'Atmosphere': [('Density', 'float', 0.26), ('Haze', 'float', 0.4), ('Glare', 'float', 0.0), ('Color', 'Color3', (190, 204, 220))]}
lob = child(envs, 'Lobby')
for n, t, v in LOBBY_VALUES: setv(lob, n, t, v)
for n, props in LOBBY_FX.items(): setfx(lob, n, props)
for n, props in LOBBY_FX.items(): setfx(lighting, n, props)
LP = {'Brightness': ('float', 2.3), 'ExposureCompensation': ('float', -0.15), 'EnvironmentDiffuseScale': ('float', 0.6),
      'EnvironmentSpecularScale': ('float', 0.35), 'Ambient': ('Color3', (150, 140, 140)), 'OutdoorAmbient': ('Color3', (92, 96, 110))}
for k, (t, v) in LP.items(): set_prop(lighting, k, t, v)
army = child(envs, 'Army')
for n, t, v in [('ColorShift_Top', 'Color3', (140, 132, 108)), ('ColorShift_Bottom', 'Color3', (60, 60, 60)),
                ('ExposureCompensation', 'double', -0.1), ('Brightness', 'double', 2.8)]:
    setv(army, n, t, v)
# faster walking in the lobby (16 * 2.5); rounds freeze the character anyway
starter = top['StarterPlayer']
set_prop(starter, 'CharacterWalkSpeed', 'float', 40)
# Gemini admin panel needs outgoing HTTP (Game Settings > Security > Allow HTTP Requests)
http = top.get('HttpService')
if http is None:
    http = item('HttpService', 'HttpService', ())
    root.insert(list(root).index(rs), http)
set_prop(http, 'HttpEnabled', 'bool', True)
# ------------------------------------------------------------------ validate references
refs = {}
for it in root.iter('Item'):
    r = it.get('referent')
    assert r not in refs, 'duplicate referent ' + r
    refs[r] = it
bad = 0
for it in root.iter('Item'):
    pr = props_of(it)
    if pr is None: continue
    for c in pr:
        if c.tag == 'Ref' and c.text and c.text != 'null' and c.text not in refs:
            bad += 1; print('  dangling', it.get('class'), name_of(it), c.get('name'), c.text); c.text = 'null'
print('dangling refs fixed:', bad)
out = sys.argv[1] if len(sys.argv) > 1 else 'out.rbxlx'
tree.write(out, encoding='utf-8', xml_declaration=True)
print('items', sum(1 for _ in root.iter('Item')), 'written', out)
