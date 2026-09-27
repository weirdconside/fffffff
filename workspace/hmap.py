# top-down height map of COLLIDABLE lobby parts (what a player can stand on), with a coordinate grid
import sys, math, numpy as np
from lxml import etree
from PIL import Image, ImageDraw
from rbx import parts as rparts
from lib import name_of, child
t=etree.parse(sys.argv[1],etree.XMLParser(huge_tree=True));r=t.getroot()
ws=[i for i in r.findall('Item') if i.get('class')=='Workspace'][0]
lob=child(ws,'LobbyWorld')
S=4.0;X0,X1,Z0,Z1=-150,150,-150,150
W=int((X1-X0)*S);H=int((Z1-Z0)*S)
img=Image.new('RGB',(W,H),(30,80,150));d=ImageDraw.Draw(img)
def P(x,z): return ((x-X0)*S,(z-Z0)*S)
from lib import getp
def coll(it):
    c=getp(it,'CanCollide');return c is None or c.text=='true'
ps=[p for p in rparts(lob) if coll(p['it'])]
ps.sort(key=lambda p:p['pos'][1])
cnt=0
for p in ps:
    if p['name'] in ('SeaFloor','OceanTop','OceanBottom','Wall'): continue
    sz=p['size'];R=np.array(p['R']).reshape(3,3);c=p['pos']
    top=c[1]+abs(R[1,0])*sz[0]/2+abs(R[1,1])*sz[1]/2+abs(R[1,2])*sz[2]/2
    hx=abs(R[0,0])*sz[0]/2+abs(R[0,1])*sz[1]/2+abs(R[0,2])*sz[2]/2
    hz=abs(R[2,0])*sz[0]/2+abs(R[2,1])*sz[1]/2+abs(R[2,2])*sz[2]/2
    if hx>60 or hz>60: continue
    k=max(0,min(1,(top-4)/30))
    col=(int(60+195*k),int(170-120*k),int(60))
    d.rectangle([P(c[0]-hx,c[2]-hz),P(c[0]+hx,c[2]+hz)],fill=col)
    cnt+=1
for x in range(X0,X1+1,10):
    d.line([P(x,Z0),P(x,Z1)],fill=(255,255,255) if x%50==0 else (90,110,140))
    d.line([P(X0,x),P(X1,x)],fill=(255,255,255) if x%50==0 else (90,110,140))
    if x%50==0:
        d.text(P(x+1,Z0+1),str(x),fill=(255,255,0));d.text(P(X0+1,x+1),str(x),fill=(255,255,0))
for (x,z,lab) in [(-6,0,'SPAWN'),(26,-46,'SHOP'),(58,-44,'R1'),(64,0,'R2'),(58,44,'R3')]:
    d.ellipse([P(x-2,z-2),P(x+2,z+2)],fill=(255,255,255));d.text(P(x+3,z),lab,fill=(255,255,255))
img.save(sys.argv[2]);print('parts',cnt)
