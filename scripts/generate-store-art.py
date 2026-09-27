#!/usr/bin/env python3
"""Generate original typographic Store identity assets; requires Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
FONT=ROOT/'components/fonts/Caption-Regular.ttf'
def render(path,size,splash=False):
    w,h=size;scale=3
    image=Image.new('RGB',(w*scale,h*scale),(11,13,18));draw=ImageDraw.Draw(image)
    def text(label,y,fs,color):
        font=ImageFont.truetype(str(FONT),round(fs*scale));box=draw.textbbox((0,0),label,font=font)
        width=box[2]-box[0];draw.text(((w*scale-width)/2,y*scale),label,font=font,fill=color)
    unit=min(w,h)
    cy=h*.29;r=unit*.105;cx=w/2
    draw.rounded_rectangle(((cx-r*1.7)*scale,(cy-r)*scale,(cx+r*1.7)*scale,(cy+r)*scale),radius=r*.24*scale,outline=(229,180,106),width=max(2,round(unit*.01*scale)))
    draw.polygon([((cx-r*.32)*scale,(cy-r*.5)*scale),((cx-r*.32)*scale,(cy+r*.5)*scale),((cx+r*.58)*scale,cy*scale)],fill=(229,180,106))
    text('30nama',h*.46,unit*.15,(248,246,242))
    text('UNOFFICIAL CLIENT',h*.69,unit*.045,(229,180,106))
    if splash:text('For existing 30nama accounts',h*.82,unit*.033,(169,179,195))
    image.resize(size,Image.Resampling.LANCZOS).save(ROOT/path,optimize=True)
for name,size in [('icon-fhd.png',(540,405)),('icon-hd.png',(290,218))]:render('images/'+name,size)
for name,size in [('splash-hd.png',(1280,720)),('splash-sd.png',(720,480)),('splash-fhd.png',(1920,1080))]:render('images/'+name,size,True)
print('Generated 5 original identity assets (not app screenshots)')
