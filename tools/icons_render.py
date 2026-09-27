# runs ShopIcons under the Roblox mock, then renders each 3D glyph like the shop's ViewportFrame camera
import subprocess, sys, numpy as np
from PIL import Image
from render import render
specs=sys.argv[1] if len(sys.argv)>1 else 'new/ShopIcons.lua'
out=[open('test/rbxmock.lua').read(),'__modules={} ',f'__modules["ShopIcons"]=function()\n{open(specs).read()}\nend\n',
     'ICON_SPECS={{"Crown"},{"Gavel"},{"Ticket",1},{"Ticket",7},{"Ticket",20}}',open('test/icondump.lua').read()]
open('test/iconbundle.lua','w').write('\n'.join(out))
res=subprocess.run(['bin/luau','test/iconbundle.lua'],capture_output=True,text=True)
if res.returncode: print(res.stdout[-2000:],res.stderr[-2000:]);sys.exit(1)
groups={}
SHAPE={'Enum.PartType.Ball':0,'Enum.PartType.Cylinder':2,'Block':1,'Enum.PartType.Block':1}
for line in res.stdout.splitlines():
    if not line.startswith('PART|'): continue
    _,kind,cls,shape,size,pos,rot,col,tr=line.split('|')
    R=np.array([float(x) for x in rot.split()]).reshape(3,3)
    groups.setdefault(kind,[]).append(dict(cls=cls,shape=SHAPE.get(shape,1),size=np.array([float(x) for x in size.split()]),
        pos=np.array([float(x) for x in pos.split()]),R=R,color=tuple(int(float(c)*255) for c in col.split()),transp=float(tr),name='p',mat=272))
tiles=[]
for kind,ps in groups.items():
    im=render(ps,eye=(2.4*1.05,1.7*1.05,4.4*1.05),target=(0,0,0),fov=32,W=320,H=320,sky=(60,50,80))
    tiles.append((kind,im))
sheet=Image.new('RGB',(320*len(tiles),340),(30,30,40))
from PIL import ImageDraw
d=ImageDraw.Draw(sheet)
for i,(k,im) in enumerate(tiles): sheet.paste(im,(i*320,0));d.text((i*320+8,322),k,fill=(255,255,255))
sheet.save(sys.argv[2] if len(sys.argv)>2 else 'icons_now.png');print('rendered',[k for k,_ in tiles])
