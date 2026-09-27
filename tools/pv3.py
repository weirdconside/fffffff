import sys
from lxml import etree
from rbx import parts as rparts
from render import render
from lib import name_of, child
import numpy as np
t=etree.parse('out.rbxlx');r=t.getroot()
ws=[i for i in r.findall('Item') if i.get('class')=='Workspace'][0]
lob=child(ws,'LobbyWorld')
ps=[]
for p in rparts(lob):
    par=p['it'].getparent()
    if p['cls']=='MeshPart' and name_of(par) in ('Tile','MiniTile') and p['name'] in ('Land','Under'): p['shape']='hex'
    if p['name']=='OceanBottom': continue
    if p['name']=='OceanTop': p['size']=np.array([900,0.01,900])
    if p['name'] in ('Collision','Wall','RailBarrier','EndBarrier','Ground','SeaFloor','BeamPart'): continue
    ps.append(p)
views={'hero':((-60,70,-150),(60,5,0),55),'deck':((104,14,-40),(104,10,-80),70),'plaza':((30,9,30),(-10,8,-10),70),'table':((-2,14,20),(-2,8,8),55)}
for k in sys.argv[1:]:
    eye,target,fov=views[k]
    render(ps,eye=eye,target=target,fov=fov,W=1100,H=620,sky=(150,200,240)).save(f'f_{k}.png')
