from PIL import Image, ImageFilter, ImageDraw
import numpy as np
src = Image.open('buddha-src.jpg').convert('RGB')
S = 2
big = src.resize((src.width*S, src.height*S), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=2.2, percent=60, threshold=2))
a = np.asarray(big).astype(np.float32)
R,G,B = a[...,0],a[...,1],a[...,2]
f = R + G - 0.8*B
alpha = np.clip((f - 12.0)/(40.0-12.0), 0, 1)
hard = (alpha > 0.5)
# flood fill background from border to fill holes
m = Image.fromarray((hard*255).astype(np.uint8))
# keep largest component + fill holes: floodfill the inverse from corner
inv = Image.fromarray(((~hard)*255).astype(np.uint8)).copy()
ImageDraw.floodfill(inv, (0,0), 128)
inv_a = np.asarray(inv)
holes = inv_a == 255   # background regions not connected to border = holes
solid = hard | holes
# remove small specks: open via min/max filter
sm = Image.fromarray((solid*255).astype(np.uint8)).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(5))
solid = np.asarray(sm) > 127
# soft edge: blend hard solid with soft alpha near edges
soft = np.asarray(Image.fromarray((solid*255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.6))).astype(np.float32)/255
final_a = np.maximum(soft, alpha*np.asarray(Image.fromarray((solid*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))).astype(np.float32)/255)
final_a = np.clip(final_a,0,1)
ys,xs = np.where(final_a > 0.02)
y0,y1,x0,x1 = ys.min(),ys.max(),xs.min(),xs.max()
print('bbox', x0,y0,x1,y1, 'size', big.size)
pad=8
x0=max(0,x0-pad);y0=max(0,y0-pad);x1=min(big.width-1,x1+pad);y1=min(big.height-1,y1+pad)
# un-premultiply fringe: replace edge colour bg tint toward figure-ish by keeping rgb as is
rgba = np.dstack([a, final_a*255]).astype(np.uint8)
out = Image.fromarray(rgba,'RGBA').crop((x0,y0,x1+1,y1+1))
out.save('buddha-figure-gold.png', optimize=True)
big.save('buddha-up.png')
np.save('alpha.npy', final_a)
open('figure.json','w').write('{"canvasW":%d,"canvasH":%d,"x":%d,"y":%d,"w":%d,"h":%d}'%(big.width,big.height,x0,y0,x1-x0+1,y1-y0+1))
# preview of mask on magenta
prev = Image.new('RGB', out.size, (255,0,255)); prev.paste(out,(0,0),out); prev.resize((out.width//2,out.height//2)).save('mask-preview.png')
