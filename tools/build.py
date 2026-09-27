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
    'AdminUI': 'new/AdminUI.lua', 'RoundClient': 'new/RoundClient.client.lua', 'MusicController': 'new/MusicController.client.lua',
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
add_script(sss, 'ModuleScript', 'Perks', 'new/Perks.lua')
sps = child(sp, 'StarterPlayerScripts')
add_script(sps, 'LocalScript', 'LobbyAmbience', 'new/LobbyAmbience.client.lua')
rf = item('ReplicatedFirst', 'ReplicatedFirst', ())
add_script(rf, 'LocalScript', 'TitleScreen', 'new/TitleScreen.client.lua')
root.insert(list(root).index(rs), rf)
# Lighting: the original lobby preset is kept untouched (it looked nicer).
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
