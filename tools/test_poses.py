import sys
sys.path.insert(0,'.')
from lib import *
import lobby as L
import poses
import numpy as np
from rbx import parts as rparts
from render import render
from lxml import etree
from PIL import Image, ImageDraw
tree = etree.parse('orig.rbxlx', etree.XMLParser(huge_tree=True))
ctx = L.Ctx(tree)
only = sys.argv[1:]
cases = [('Barbarian','windup'),('Barbarian','overhead'),('Barbarian','block'),('Archer','aim'),('Giant','giant_smash'),
         ('Wizard','cast'),('Lumberjack','chop'),('Miner','mine'),('Builder','hammer'),('Barbarian','cheer')]
if only: cases=[c for c in cases if c[1] in only]
COL={'Torso':(60,110,220),'Head':(250,210,80),'RArm':(220,50,50),'LArm':(60,190,70),'RLeg':(120,40,40),'LLeg':(30,110,40),'Root':(200,200,200)}
tiles=[]
for i,(kind,pn) in enumerate(cases):
    root = model(None,'T')
    src = child(ctx.entities, kind)
    s = 3.0
    m = L.place_asset(ctx, root, src, (0,0,0), yaw=0, s=s, name=kind, box=False)
    if pn: poses.pose(m, src, pn, s)
    ps=[p for p in rparts(root) if p['name']!='Root']
    for p in ps: p['color']=np.array(COL.get(p['name'],(150,90,40)))
    ps.append(dict(it=None,cls='Part',pos=np.array([0,-0.25,0]),R=np.eye(3),size=np.array([14,0.5,14]),color=np.array([120,170,90]),transp=0,shape=1,name='g',mat=256))
    lo,hi=world_bbox(m); c=(lo+hi)/2; h=max(hi-lo)
    views=[(c+np.array([0,1,-1.9])*h,'front'),(c+np.array([1.9,1,0])*h,'right side'),(c+np.array([-1.4,1.1,-1.4])*h,'3/4')]
    t=Image.new('RGB',(900,300),(255,255,255))
    for k,(eye,lab) in enumerate(views):
        im=render(ps, eye=eye, target=c, fov=40, W=300, H=300)
        ImageDraw.Draw(im).text((5,5),f'{kind} {pn} {lab}',fill=(0,0,0)); t.paste(im,(k*300,0))
    tiles.append(t)
sheet=Image.new('RGB',(900,300*len(tiles)),(255,255,255))
for i,t in enumerate(tiles): sheet.paste(t,(0,i*300))
sheet.save('poses.png')
