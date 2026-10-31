import numpy as np, sys
from PIL import Image
TAU=6.283185307
SAFF=np.array([0.93,0.71,0.38]); PINK=np.array([0.92,0.60,0.76]); VIOL=np.array([0.60,0.50,0.92]); TEAL=np.array([0.38,0.80,0.80])
def smooth(a,b,x):
    t=np.clip((x-a)/(b-a),0,1); return t*t*(3-2*t)
def pal(x):
    x=(x%1.0)*4.0
    cs=[SAFF,PINK,VIOL,TEAL,SAFF]
    i=np.floor(x).astype(int); f=x-i; f=f*f*(3-2*f)
    out=np.zeros(x.shape+(3,))
    for k in range(4):
        m=(i==k)[...,None]
        out+=m*(cs[k]*(1-f[...,None])+cs[k+1]*f[...,None])
    return out
def rot(v,a):
    c,s=np.cos(a),np.sin(a); return np.stack([c*v[...,0]-s*v[...,1], s*v[...,0]+c*v[...,1]],-1)
def aura(W,H,t,cx,cy,unit,hx,hy):
    yy,xx=np.mgrid[0:H,0:W].astype(np.float32)+0.5
    p=np.stack([(xx-cx)/unit,(yy-cy)/unit],-1)
    r=np.linalg.norm(p,axis=-1); a=np.arctan2(p[...,1],p[...,0])
    b=0.5-0.5*np.cos(TAU*t/5.0)           # breath 0..1, 5 s
    s=1.0+0.045*b
    # background: deep indigo night, lighter violet bloom around the figure
    vg=np.linalg.norm(np.stack([(xx-W/2)/H,(yy-H*0.5)/H],-1),axis=-1)
    bg=np.array([0.071,0.058,0.150])*(1-smooth(0.0,0.95,vg)[...,None])+np.array([0.030,0.026,0.070])*smooth(0.0,0.95,vg)[...,None]
    bg=bg+np.array([0.10,0.06,0.16])[None,None]*np.exp(-r/0.38)[...,None]*(0.35+0.25*b)
    rs=r/s
    rot1=TAU*t/240.0
    # 1 scalloped lotus ring (16 petals)
    R1=0.40
    d1=np.abs(rs-R1*(0.93+0.07*np.abs(np.cos(8*(a+rot1)))))
    g1=np.exp(-d1*160)*0.9
    # 2 big petal outlines (8 petals), counter-rotating
    ang=a-rot1*2
    pet=np.abs(np.cos(4*ang))**0.6
    R2=0.50*(0.62+0.38*pet)
    g2=np.exp(-np.abs(rs-R2)*190)*0.55*smooth(0.25,0.33,rs)
    # 3 KIFS fractal filigree in an annulus
    sec=TAU/12.0
    fa=np.abs(np.mod(a+rot1*0.5,sec)-0.5*sec)
    q=np.stack([rs*np.cos(fa),rs*np.sin(fa)],-1)*2.4
    acc=np.zeros_like(r); sc=1.0
    for i in range(5):
        q=np.abs(q)-np.array([0.62,0.20+0.03*b])
        q=rot(q,0.58+0.06*np.sin(TAU*t/60.0))
        q=q*1.42; sc*=1.42
        acc+=np.exp(-np.abs(q[...,1])/sc*260)*(0.55**i*0+0.35)
    env=smooth(0.30,0.40,rs)*(1-smooth(0.52,0.66,rs))
    g3=acc*env*0.75
    # 3b flower-of-life garland: 12 circles strung on a ring, breathing outward
    fsec=TAU/12.0
    fa2=np.mod(a-rot1*1.5,fsec)-0.5*fsec
    RF=0.64*s; rc=0.22
    gf=np.zeros_like(r)
    for off in (0.0,):
        q2=np.stack([r*np.cos(fa2+off),r*np.sin(fa2+off)],-1)
        for k in (-1,0,1):
            cc=np.array([RF*np.cos(k*fsec),RF*np.sin(k*fsec)])
            dd=np.abs(np.linalg.norm(q2-cc,axis=-1)-rc)
            gf=np.maximum(gf,np.exp(-dd*220))
    g3=g3+gf*0.45*(0.75+0.25*b)
    # 4 soft rays
    g4=((0.5+0.5*np.cos(24*a-rot1*3))**10)*np.exp(-rs*2.2)*0.18*smooth(0.12,0.3,rs)
    # 5 outer breathing ripples
    g5=(np.exp(-np.abs(rs-0.84)*150)*0.30+np.exp(-np.abs(rs-0.98)*160)*0.18)*(0.6+0.4*b)
    # 6 nimbus behind the head
    hd=np.linalg.norm(np.stack([(xx-hx)/unit,(yy-hy)/unit],-1),axis=-1)
    g6=np.exp(-np.maximum(hd-0.06,0)/0.05)*0.45*(0.7+0.3*b)+np.exp(-np.abs(hd-0.10*s)*200)*0.35
    hue=rs*0.9-t/80.0+0.05*np.sin(a*6+TAU*t/40.0)
    col=bg.copy()
    inten=0.55+0.45*b
    col+= pal(hue)*(g1*inten)[...,None]*0.75
    col+= pal(hue+0.25)*(g2*inten)[...,None]*0.7
    col+= pal(hue+0.5)*(g3*inten)[...,None]*0.6
    col+= pal(hue+0.1)*(g4)[...,None]
    col+= pal(hue+0.6)*(g5)[...,None]*0.7
    col+= SAFF*(g6*inten)[...,None]*0.8
    # soft tonemap so nothing clips harshly
    col=1-np.exp(-col*1.4)
    return np.clip(col,0,1)
if __name__=='__main__':
    W,H=int(sys.argv[1]),int(sys.argv[2]); t=float(sys.argv[3]); out=sys.argv[4]
    k=H/1440.0; ox=(W-2560*k)/2
    c=aura(W,H,t,ox+1278*k,650*k,1440*k,ox+1276*k,357*k)
    img=Image.fromarray((c*255+0.5).astype(np.uint8))
    fig=Image.open('buddha-figure.png'); fj=eval(open('figure.json').read())
    fs=fig.resize((round(fj['w']*k),round(fj['h']*k)),Image.LANCZOS)
    img.paste(fs,(round(ox+fj['x']*k),round(fj['y']*k)),fs)
    img.save(out)
