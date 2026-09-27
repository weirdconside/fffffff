from rbx import *
from render import render
from lib import world_bbox, clone, at, name_of
from collections import OrderedDict
import numpy as np
from PIL import Image
t=etree.parse('orig.rbxlx');r=t.getroot()
ss=[i for i in r.findall('Item') if i.get('class')=='ServerStorage'][0]
env=[i for i in ss.findall('Item') if pname(i)=='ArmyEnvironment'][0]
assets=[i for i in ss.findall('Item') if pname(i)=='ArmyAssets'][0]
terr=[i for i in env.findall('Item') if pname(i)=='Territories'][0]
plot=[i for i in assets.findall('Item') if pname(i)=='ArmyPlotTemplate'][0]
cands=OrderedDict()
for ch in terr.iter('Item'):
    if ch.get('class')=='Model' and parts(ch):
        lo,hi=world_bbox(ch);ps=parts(ch)
        key=(pname(ch),len(ps),tuple(np.round(hi-lo,0)))
        if key not in cands: cands[key]=ch
for ch in plot.iter('Item'):
    if ch.get('class')=='Model' and pname(ch)=='EnemyCamp':
        key=('EnemyCamp',len(parts(ch)),0)
        if key not in cands: cands[key]=ch
misc=[i for i in plot.findall('Item') if pname(i)=='Misc'][0]
for ch in misc.iter('Item'):
    if ch.get('class')=='Model' and pname(ch) in ('Built','Broken','Barrier'): cands[(pname(ch),0,0)]=ch
tiles=[]
keys=list(cands.keys())
for i,k in enumerate(keys):
    m=cands[k];lo,hi=world_bbox(m);c=(lo+hi)/2;ext=max(hi-lo)
    ps=parts(m)
    img=render(ps,eye=c+np.array([ext*1.2,ext*0.9,ext*1.2]),target=c,fov=50,W=220,H=180,sky=(230,230,235))
    tiles.append((img,f'{i}:{k[0]}{k[1]}'))
W=6;H=(len(tiles)+W-1)//W
sheet=Image.new('RGB',(220*W,195*H),'white')
from PIL import ImageDraw
d=ImageDraw.Draw(sheet)
for i,(img,lab) in enumerate(tiles):
    x,y=(i%W)*220,(i//W)*195
    sheet.paste(img,(x,y));d.text((x+3,y+180),lab,fill='black')
sheet.save('gallery.png');print(len(tiles))
import pickle
open('gallery_keys.txt','w').write('\n'.join(f'{i}\t{k}' for i,k in enumerate(keys)))
