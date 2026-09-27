import sys
from lxml import etree
from rbx import parts as rparts
from render import render
from lib import name_of, child
import numpy as np
t=etree.parse('out11.rbxlx',etree.XMLParser(huge_tree=True));r=t.getroot()
ws=[i for i in r.findall('Item') if i.get('class')=='Workspace'][0]
lob=child(ws,'LobbyWorld')
ps=[]
for p in rparts(lob):
    par=p['it'].getparent()
    if p['cls']=='MeshPart' and name_of(par) in ('Tile','MiniTile') and p['name'] in ('Land','Under'): p['shape']='hex'
    if p['name']=='OceanBottom': continue
    if p['name']=='OceanTop': p['size']=np.array([900,0.01,900])
    if p['name'] in ('Fireflies','Collision','Wall','RailBarrier','EndBarrier','Ground','SeaFloor','BeamPart','LabelAnchor'): continue
    ps.append(p)
views={'code1Room':((96,14,10),(77,5,3),60),'code1Front':((30,14,0),(70,5,0),60),'code5Sea':((104,14,-104),(87,1,-88),60),'code5In':((80,12,-78),(87,0,-88),70),'chestTop':((-2,34,-28),(11,5,-53),55),'code2Top':((42,30,-80),(33,6,-56),55),'code5Top':((70,24,-72),(87,1,-88),60),'code3Top':((-45,32,55),(-63,11,74),60),'code1Top':((-14,18,-8),(5,6,10),55),'chest':((-8,16,-30),(14,6,-52),60),'code2':((45,12,-72),(33,7,-56),60),'code4':((-20,22,40),(-33,12,57),60),'code3':((-50,18,62),(-63,11,74),60),'code5':((108,16,60),(120,1,69),60),'code1':((-10,10,-4),(5,7,10),60)}
for k in sys.argv[1:]:
    eye,target,fov=views[k]
    render(ps,eye=eye,target=target,fov=fov,W=800,H=450,sky=(150,200,240)).save(f'r_{k}.png')
