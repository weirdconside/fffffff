import copy, sys, base64
import numpy as np
from lxml import etree
from lib import *
import lobby as L

SRC = {  # existing script name -> new source file
    'RoundServer': 'new/RoundServer.server.lua', 'RoundState': 'new/RoundState.lua', 'WishRules': 'new/WishRules.lua',
    'RoundBots': 'new/RoundBots.lua', 'DonationServer': 'new/DonationServer.server.lua', 'DonationCatalog': 'new/DonationCatalog.lua',
    'DonationShop': 'new/DonationShop.lua', 'DonationClient': 'new/DonationClient.client.lua', 'LobbyUI': 'new/LobbyUI.lua',
    'AdminUI': 'new/AdminUI.lua', 'RoundClient': 'new/RoundClient.client.lua',
}
tree = etree.parse('orig.rbxlx')
root = tree.getroot()
top = {name_of(i): i for i in root.findall('Item')}
ws = top['Workspace']; rs = top['ReplicatedStorage']; sss = top['ServerScriptService']; sp = top['StarterPlayer']
lighting = top['Lighting']
# ------------------------------------------------------------------ lobby
old = child(ws, 'LobbyWorld')
idx = list(ws).index(old)
ws.remove(old)
lobby, ctx, tiles, spawn_cf = L.build(tree)
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
add_script(sss, 'ModuleScript', 'Perks', 'new/Perks.lua')
sps = child(sp, 'StarterPlayerScripts')
add_script(sps, 'LocalScript', 'LobbyAmbience', 'new/LobbyAmbience.client.lua')
rf = item('ReplicatedFirst', 'ReplicatedFirst', ())
add_script(rf, 'LocalScript', 'TitleScreen', 'new/TitleScreen.client.lua')
root.insert(list(root).index(rs), rf)
# ------------------------------------------------------------------ lighting: lobby preset shares the round's bright cartoon look
envs = child(rs, 'SceneEnvironments')
lob = child(envs, 'Lobby'); army = child(envs, 'Army')
for c in list(lob.findall('Item')):
    lob.remove(c)
VALUES = [('Color3Value', 'Ambient', 'Color3', (150, 150, 158)), ('NumberValue', 'Brightness', 'double', 3.0),
          ('Color3Value', 'ColorShift_Bottom', 'Color3', (255, 255, 255)), ('Color3Value', 'ColorShift_Top', 'Color3', (255, 250, 214)),
          ('NumberValue', 'EnvironmentDiffuseScale', 'double', 0.35), ('NumberValue', 'EnvironmentSpecularScale', 'double', 0.3),
          ('NumberValue', 'ExposureCompensation', 'double', 0.05), ('Color3Value', 'FogColor', 'Color3', (196, 222, 240)),
          ('NumberValue', 'FogEnd', 'double', 100000), ('NumberValue', 'FogStart', 'double', 0),
          ('NumberValue', 'GeographicLatitude', 'double', 24), ('BoolValue', 'GlobalShadows', 'bool', True),
          ('Color3Value', 'OutdoorAmbient', 'Color3', (122, 170, 196)), ('NumberValue', 'ShadowSoftness', 'double', 0.25),
          ('StringValue', 'TimeOfDay', 'string', '15:10:00')]
for cls, name, typ, v in VALUES:
    item(cls, name, [('Value', typ, v)], lob)
sky = copy.deepcopy(child(army, 'Skybox'))
for it in sky.iter('Item'): it.set('referent', new_ref())
set_prop(sky, 'Name', 'string', 'Sky')
effects = [
    item('Atmosphere', 'Atmosphere', [('Color', 'Color3', (199, 222, 240)), ('Decay', 'Color3', (110, 146, 186)), ('Density', 'float', 0.26),
                                      ('Glare', 'float', 0.15), ('Haze', 'float', 0.9), ('Offset', 'float', 0.18)]),
    sky,
    item('BloomEffect', 'Bloom', [('Intensity', 'float', 0.55), ('Size', 'float', 24), ('Threshold', 'float', 1.7), ('Enabled', 'bool', True)]),
    item('ColorCorrectionEffect', 'ColorCorrection', [('Brightness', 'float', 0.02), ('Contrast', 'float', 0.08), ('Saturation', 'float', 0.22),
                                                      ('TintColor', 'Color3', (255, 252, 244)), ('Enabled', 'bool', True)]),
    item('SunRaysEffect', 'SunRays', [('Intensity', 'float', 0.05), ('Spread', 'float', 0.5), ('Enabled', 'bool', True)]),
]
for e in effects: lob.append(e)
# Lighting service mirrors the lobby preset for Studio edit mode
for c in list(lighting.findall('Item')):
    lighting.remove(c)
for e in effects:
    d = copy.deepcopy(e)
    for it in d.iter('Item'): it.set('referent', new_ref())
    lighting.append(d)
LP = {'Ambient': ('Color3', (150, 150, 158)), 'Brightness': ('float', 3.0), 'ColorShift_Bottom': ('Color3', (255, 255, 255)),
      'ColorShift_Top': ('Color3', (255, 250, 214)), 'EnvironmentDiffuseScale': ('float', .35), 'EnvironmentSpecularScale': ('float', .3),
      'ExposureCompensation': ('float', .05), 'FogColor': ('Color3', (196, 222, 240)), 'GeographicLatitude': ('float', 24),
      'OutdoorAmbient': ('Color3', (122, 170, 196)), 'ShadowSoftness': ('float', .25), 'TimeOfDay': ('string', '15:10:00')}
for k, (t, v) in LP.items():
    set_prop(lighting, k, t, v)
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
