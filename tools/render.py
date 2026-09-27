import numpy as np
from PIL import Image
# Simple z-buffer rasterizer for Roblox part lists.
def box_tris(shape,cls):
    # unit geometry in [-.5,.5]^3 ; returns (verts, faces)
    if cls=='WedgePart' or shape=='wedge':
        # Roblox wedge: slope rises toward -Z? WedgePart: full at back (+Z), top slopes down to front (-Z)
        v=np.array([[-.5,-.5,-.5],[.5,-.5,-.5],[.5,-.5,.5],[-.5,-.5,.5],[-.5,.5,.5],[.5,.5,.5]])
        f=[(0,1,2),(0,2,3),(3,2,5),(3,5,4),(0,4,5),(0,5,1),(0,3,4),(1,5,2)]
        return v,f
    if shape=='hex':
        verts=[];faces=[]
        for y in (-.5,.5):
            for k in range(6):
                a=np.pi/3*k; verts.append([.5*np.cos(a),y,.5*np.sin(a)/(np.sqrt(3)/2)])
        for k in range(6):
            a=k;b=(k+1)%6
            faces+=[(a,b,6+a),(b,6+b,6+a)]
        for k in range(1,5):
            faces+=[(0,k,k+1),(6,6+k+1,6+k)]
        return np.array(verts),faces
    if shape==0 or shape=='ball':
        n=10;m=7;verts=[];faces=[]
        for i in range(m+1):
            th=np.pi*i/m
            for j in range(n):
                ph=2*np.pi*j/n
                verts.append([.5*np.sin(th)*np.cos(ph),.5*np.cos(th),.5*np.sin(th)*np.sin(ph)])
        for i in range(m):
            for j in range(n):
                a=i*n+j;b=i*n+(j+1)%n;c=(i+1)*n+j;d=(i+1)*n+(j+1)%n
                faces+= [(a,c,b),(b,c,d)]
        return np.array(verts),faces
    if shape==2 or shape=='cyl':
        # cylinder along X
        n=14;verts=[];faces=[]
        for s in (-.5,.5):
            for j in range(n):
                ph=2*np.pi*j/n; verts.append([s,.5*np.cos(ph),.5*np.sin(ph)])
        verts.append([-.5,0,0]);verts.append([.5,0,0])
        for j in range(n):
            a=j;b=(j+1)%n;c=n+j;d=n+(j+1)%n
            faces+=[(a,b,c),(b,d,c),(2*n,b,a),(2*n+1,c,d)]
        return np.array(verts),faces
    v=np.array([[x,y,z] for x in (-.5,.5) for y in (-.5,.5) for z in (-.5,.5)])
    f=[(0,1,3),(0,3,2),(4,6,7),(4,7,5),(0,4,5),(0,5,1),(2,3,7),(2,7,6),(0,2,6),(0,6,4),(1,5,7),(1,7,3)]
    return v,f
GEOM={}
def geom(shape,cls):
    k=(shape,cls)
    if k not in GEOM: GEOM[k]=box_tris(shape,cls)
    return GEOM[k]
def lookat(eye,target,up=np.array([0,1,0.])):
    f=target-eye;f/=np.linalg.norm(f)
    r=np.cross(f,up);r/=np.linalg.norm(r);u=np.cross(r,f)
    return eye,r,u,f
def render(parts,eye,target,W=960,H=540,fov=60,sky=(170,205,235),light=np.array([-.4,-.8,-.45]),ortho=None,skipTransp=0.95):
    eye=np.array(eye,float);target=np.array(target,float)
    e,r,u,f=lookat(eye,target)
    zb=np.full((H,W),np.inf);img=np.zeros((H,W,3));img[:]=sky
    L=-light/np.linalg.norm(light)
    fl=(H/2)/np.tan(np.radians(fov/2))
    for p in parts:
        if p.get('transp',0)>=skipTransp: continue
        v,fs=geom(p.get('shape',1),p.get('cls','Part'))
        wv=(v*p['size'])@p['R'].T+p['pos']
        rel=wv-e
        cx=rel@r;cy=rel@u;cz=rel@f
        if ortho:
            sx=W/2+cx*ortho;sy=H/2-cy*ortho;depth=cz
            if np.all(cz<0): continue
        else:
            if np.all(cz<0.5): continue
            czc=np.maximum(cz,0.05)
            sx=W/2+cx/czc*fl;sy=H/2-cy/czc*fl;depth=cz
        col=np.array(p['color'],float)
        a=1-p.get('transp',0)
        for (i,j,k) in fs:
            if not ortho and (cz[i]<0.5 or cz[j]<0.5 or cz[k]<0.5): continue
            n=np.cross(wv[j]-wv[i],wv[k]-wv[i]);nn=np.linalg.norm(n)
            if nn<1e-9: continue
            n/=nn
            x0,y0,x1,y1,x2,y2=sx[i],sy[i],sx[j],sy[j],sx[k],sy[k]
            minx=max(int(np.floor(min(x0,x1,x2))),0);maxx=min(int(np.ceil(max(x0,x1,x2))),W-1)
            miny=max(int(np.floor(min(y0,y1,y2))),0);maxy=min(int(np.ceil(max(y0,y1,y2))),H-1)
            if minx>maxx or miny>maxy: continue
            den=(y1-y2)*(x0-x2)+(x2-x1)*(y0-y2)
            if abs(den)<1e-9: continue
            xs=np.arange(minx,maxx+1)+.5;ys=np.arange(miny,maxy+1)+.5
            X,Y=np.meshgrid(xs,ys)
            w0=((y1-y2)*(X-x2)+(x2-x1)*(Y-y2))/den
            w1=((y2-y0)*(X-x2)+(x0-x2)*(Y-y2))/den
            w2=1-w0-w1
            m=(w0>=-1e-4)&(w1>=-1e-4)&(w2>=-1e-4)
            if not m.any(): continue
            if ortho: d=w0*depth[i]+w1*depth[j]+w2*depth[k]
            else:
                iz=w0/depth[i]+w1/depth[j]+w2/depth[k];d=1/iz
            sub=zb[miny:maxy+1,minx:maxx+1]
            m&=d<sub
            if not m.any(): continue
            shade=0.45+0.55*abs(float(n@L)) if True else 1
            c=col*shade
            if a<1:
                im=img[miny:maxy+1,minx:maxx+1]
                im[m]=im[m]*(1-a)+c*a
            else:
                sub[m]=d[m]
                img[miny:maxy+1,minx:maxx+1][m]=c
    return Image.fromarray(np.clip(img,0,255).astype(np.uint8))
