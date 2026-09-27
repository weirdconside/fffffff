import sys
sys.path.insert(0,'.')
from lib import *
import lobby as L, lobby3 as L3
import numpy as np
from rbx import parts as rparts
from render import render
from lxml import etree
from PIL import Image, ImageDraw
tree = etree.parse('orig.rbxlx', etree.XMLParser(huge_tree=True))
lobby, ctx, tiles, spawn_cf = L3.build(tree)
COL={'Torso':(60,110,220),'Head':(250,210,80),'RArm':(220,50,50),'LArm':(60,190,70),'RLeg':(120,40,40),'LLeg':(30,110,40)}
gar=[f for f in lobby.iter('Item') if name_of(f)=='Garrison'][0]
gids=set(it.get('referent') for it in gar.iter('Item'))
ps=[]
for p in rparts(lobby):
    par=p['it'].getparent()
    if p['cls']=='MeshPart' and name_of(par) in ('Tile','MiniTile') and p['name'] in ('Land','Under'): p['shape']='hex'
    if p['name'] in ('OceanBottom','Fireflies','Collision','Wall','RailBarrier','EndBarrier','Ground','SeaFloor','BeamPart'): continue
    if p['name']=='OceanTop': p['size']=np.array([900,0.01,900])
    if p['it'].get('referent') in gids and p['name'] in COL: p['color']=np.array(COL[p['name']])
    ps.append(p)
views={'raid':((14,16,8),(-4,6,38),55),'raid2':((-30,12,20),(-4,6,38),55),'spar':((-19,10,-26),(-19,6,-41),60),'archery':((-14,12,-4),(-32,6,-11),60),
       'lumber':((-8,10,60),(-20,6,69),55),'miner':((-80,10,-32),(-88,6,-43),55),'builder':((-12,10,-82),(-22,6,-92),55),'cheer':((-38,10,-6),(-50,6,-13),55),
       'spawn':((-12,9,0),(60,6,0),70),'south':((-6,9,0),(-4,6,40),70)}
sel=[a for a in sys.argv[1:]] or list(views)
for k in sel:
    eye,target,fov=views[k]
    im=render(ps,eye=eye,target=target,fov=fov,W=800,H=450,sky=(150,200,240))
    ImageDraw.Draw(im).text((6,6),k,fill=(0,0,0)); im.save(f'sc_{k}.png')
print('done')
