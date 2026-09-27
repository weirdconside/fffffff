import sys, math
sys.path.insert(0,'.')
from lib import *
import lobby as L, lobby3 as L3
import numpy as np
from lxml import etree
from PIL import Image, ImageDraw
tree = etree.parse('orig.rbxlx', etree.XMLParser(huge_tree=True))
lobby, ctx, tiles, spawn_cf = L3.build(tree)
S=3.0; W=H=900; C=W/2
def P(x,z): return (C+x*S, C+z*S)
img=Image.new('RGB',(W,H),(40,110,190)); d=ImageDraw.Draw(img)
for (q,r),lift in tiles.items():
    cx,cz=L.hex_center(q,r)
    pts=[P(cx+L.R_HEX*math.cos(math.pi/3*k), cz+L.R_HEX*math.sin(math.pi/3*k)) for k in range(6)]
    d.polygon(pts, fill=(110,160,60) if lift==0 else (90,130,50), outline=(60,90,30))
    d.text(P(cx-4,cz-3), f'{q},{r}', fill=(20,40,10))
cols={'Village':(150,90,50),'Garrison':(255,40,40),'Props':(200,200,60),'Nature':(20,90,30),'Details':(230,200,150),'NativeTeleporters':(80,80,255),'Shop':(0,0,0),'Coast':(90,90,90)}
for f in lobby.iter('Item'):
    if f.get('class') in ('Folder','Model') and name_of(f) in cols:
        grp=name_of(f)
        members=[m for m in f.findall('Item')] if grp!='Shop' else [f]
        for m in members:
            if grp=='Details' and name_of(m)=='Path':
                pass
            lo,hi=world_bbox(m)
            if not np.all(np.isfinite(lo)): continue
            d.rectangle([P(lo[0],lo[2]),P(hi[0],hi[2])], outline=cols[grp], width=2 if grp=='Garrison' else 1)
            if grp in ('Garrison','Village'): d.text(P(lo[0],hi[2]), name_of(m)[:8], fill=(255,255,255))
sx,sz=L3.SPAWN; d.ellipse([P(sx-3,sz-3),P(sx+3,sz+3)], fill=(255,255,0))
for x in range(-150,151,25):
    d.line([P(x,-150),P(x,-148)],fill=(255,255,255)); d.text(P(x,-147),str(x),fill=(255,255,255))
    d.line([P(-150,x),P(-148,x)],fill=(255,255,255)); d.text(P(-147,x),str(x),fill=(255,255,255))
img.save(sys.argv[1] if len(sys.argv)>1 else 'map2d.png')
