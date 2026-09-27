import sys, importlib
from rbx import parts as rparts
from render import render
from lxml import etree
import numpy as np
import lobby as L
def get_parts(elem):
    ps=rparts(elem)
    out=[]
    for p in ps:
        it=p['it']
        par=it.getparent()
        from lib import name_of
        if p['cls']=='MeshPart' and name_of(par)=='Tile' and p['name'] in ('Land','Under','Land2','Under2'):
            p['shape']='hex'
        if p['name'] in ('OceanBottom',): continue
        if p['name']=='OceanTop': p['size']=np.array([700,0.01,700])
        out.append(p)
    return out
def shots(elem, prefix, views):
    ps=get_parts(elem)
    for i,(eye,target,fov) in enumerate(views):
        render(ps,eye=eye,target=target,fov=fov,W=1100,H=620,sky=(150,200,240)).save(f'{prefix}_{i}.png')
if __name__=='__main__':
    t=etree.parse('orig.rbxlx')
    lob,ctx,tiles,spawn=L.build(t)
    views=[((0,260,160),(0,0,0),60),((-120,45,0),(60,5,0),65),((190,40,-60),(0,5,0),60)]
    shots(lob,'pv',views)
