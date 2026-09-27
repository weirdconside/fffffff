from lxml import etree
import numpy as np
PARTCLS={'Part','MeshPart','UnionOperation','WedgePart','CornerWedgePart','SpawnLocation','TrussPart','Seat','VehicleSeat','NegateOperation','IntersectOperation'}
def props(it):
    p=it.find('Properties'); return p
def prop(it,name):
    p=props(it)
    if p is None: return None
    for c in p:
        if c.get('name')==name: return c
    return None
def pname(it):
    c=prop(it,'Name'); return c.text if c is not None else ''
def cframe(it,name='CFrame'):
    c=prop(it,name)
    if c is None: return None
    g=lambda k: float(c.find(k).text)
    pos=np.array([g('X'),g('Y'),g('Z')])
    R=np.array([[g('R00'),g('R01'),g('R02')],[g('R10'),g('R11'),g('R12')],[g('R20'),g('R21'),g('R22')]])
    return pos,R
def vec3(it,name):
    c=prop(it,name)
    if c is None: return None
    return np.array([float(c.find(k).text) for k in 'XYZ'])
def color(it):
    c=prop(it,'Color3uint8')
    if c is not None:
        v=int(c.text); return ((v>>16)&255,(v>>8)&255,v&255)
    c=prop(it,'Color')
    if c is not None and c.find('R') is not None:
        return tuple(int(float(c.find(k).text)*255) for k in 'RGB')
    return (163,162,165)
def num(it,name,default=0.0):
    c=prop(it,name)
    if c is None: return default
    try: return float(c.text)
    except: return default
def path(it):
    names=[]
    while it is not None and it.tag=='Item':
        names.append(pname(it)); it=it.getparent()
    return '/'.join(reversed(names))
def parts(root):
    out=[]
    for it in root.iter('Item'):
        cls=it.get('class')
        if cls in PARTCLS:
            cf=cframe(it)
            size=vec3(it,'size')
            if size is None: size=vec3(it,'Size')
            if cf is None or size is None: continue
            shape=int(num(it,'shape',1))
            out.append(dict(it=it,cls=cls,pos=cf[0],R=cf[1],size=size,color=color(it),transp=num(it,'Transparency',0),shape=shape,name=pname(it),mat=int(num(it,'Material',256))))
    return out
