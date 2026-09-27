import sys, os
from lxml import etree
src, out = sys.argv[1], sys.argv[2]
tree = etree.parse(src, etree.XMLParser(huge_tree=True))
root = tree.getroot()
SERVICES = {'ReplicatedFirst','ReplicatedStorage','ServerScriptService','StarterPlayer','ServerStorage','Workspace','StarterGui'}
def name(it):
    p = it.find('Properties')
    for c in p:
        if c.get('name') == 'Name': return c.text or ''
    return ''
def src_of(it):
    p = it.find('Properties')
    for c in p:
        if c.get('name') == 'Source': return c.text or ''
    return ''
n = 0
def walk(it, path):
    global n
    cls = it.get('class')
    nm = name(it) if it.find('Properties') is not None else cls
    here = path + [nm]
    if cls in ('Script','LocalScript','ModuleScript'):
        ext = {'Script':'.server.lua','LocalScript':'.client.lua','ModuleScript':'.lua'}[cls]
        parts = [p for p in here[:-1] if p not in ('StarterPlayer',)]
        d = os.path.join(out, *parts)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, nm + ext), 'w') as f: f.write(src_of(it))
        n += 1
    for c in it.findall('Item'):
        walk(c, here)
for it in root.findall('Item'):
    if it.get('class') in ('ReplicatedFirst','ReplicatedStorage','ServerScriptService','StarterPlayer'):
        walk(it, [])
print('scripts', n)
