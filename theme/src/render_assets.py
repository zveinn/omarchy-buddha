# Asset pipeline (run from theme/src): python3 mask.py; python3 stone.py; python3 render_assets.py
import numpy as np, json
from PIL import Image
import aura as A
fig=Image.open('buddha-figure.png'); fj=json.load(open('figure.json'))
def scene(W,H,t,glow=1.0):
    k=H/1440.0; ox=(W-2560*k)/2
    c=A.aura(W,H,t,ox+1278*k,650*k,1440*k,ox+1276*k,357*k) if glow else None
    img=Image.fromarray((c*255+0.5).astype(np.uint8))
    fs=fig.resize((round(fj['w']*k),round(fj['h']*k)),Image.LANCZOS)
    img.paste(fs,(round(ox+fj['x']*k),round(fj['y']*k)),fs)
    return img
import os; os.makedirs('../backgrounds',exist_ok=True)
scene(2560,1440,2.5).save('../backgrounds/1-buddha-aura.jpg',quality=93,subsampling=0)
scene(2560,1440,2.5).resize((1800,1012),Image.LANCZOS).save('../preview.png',optimize=True)
# night: aura almost gone (only the nimbus and sky), for a quieter static choice
_a=A.aura
def quiet(W,H,t,cx,cy,unit,hx,hy):
    return _a(W,H,t,cx,cy,unit,hx,hy)
scene(2560,1440,0.0).save('../backgrounds/2-buddha-exhale.jpg',quality=93,subsampling=0)
# plymouth unlock emblem + its preview
h=523; s=h/fj['h']; em=fig.resize((round(fj['w']*s),h),Image.LANCZOS)
un=Image.new('RGBA',(1108,523),(0,0,0,0)); un.paste(em,((1108-em.width)//2,0),em); un.save('../unlock.png',optimize=True)
pu=Image.new('RGB',(1920,1080),(21,18,43)); pu.paste(un,((1920-1108)//2,(1080-523)//2-60),un); pu.save('../preview-unlock.png',optimize=True)
os.makedirs('../aura',exist_ok=True)
fig.save('../aura/buddha.png',optimize=True)
