from pathlib import Path
from PIL import Image,ImageDraw,ImageChops
import json,hashlib,sys
R=Path(__file__).resolve().parents[1];O=R/'outputs';O.mkdir(exist_ok=True)
font=[int(x,16) for x in (R/'rtl/video/osd_font.mem').read_text().split()]
styles=['STAINED GLASS','SKETCH','OIL PAINTING','STARRY NIGHT','HALFTONE COMIC','SAND ART','INK','RICH WOODCUT']
BG='#20242a';TRACK='#454b54';WHITE='#f4f5f7';YELLOW='#ffd34e';GREEN='#50df8a';RED='#ff6470'
raw=bytes(v for y in range(1080) for x in range(1920) for v in (x%256,y%256,(x^y)%256))
base=Image.frombytes('RGB',(1920,1080),raw)
def rect(d,x,y,w,h,c):d.rectangle((x,y,x+w-1,y+h-1),fill=c)
def text(d,s,x,y,scale,c):
 for i,ch in enumerate(s):
  for gy in range(8):
   for gx in range(8):
    if font[ord(ch)*8+gy]&(128>>gx):rect(d,x+(i*8+gx)*scale,y+gy*scale,scale,scale,c)
checks=[]
count=int(sys.argv[1]) if len(sys.argv)>1 else 13
for n in range(count):
 mode=1 if n==8 else 2 if n==9 else 0;enabled=n!=10;valid=n!=11;sv=n!=12;sid=n%8
 cap={5:29,6:0,7:999}.get(n,30);outfps={1:29,2:31,3:0,4:999}.get(n,30)
 cc=WHITE if not valid else GREEN if cap>=30 else RED
 pc=WHITE if not valid else GREEN if outfps>=30 else RED
 im=base.copy();d=ImageDraw.Draw(im)
 if enabled:
  if mode==0:
   rect(d,0,0,1920,270,BG);rect(d,0,810,1920,270,BG)
   rect(d,0,269,1920,1,TRACK);rect(d,0,810,1920,1,TRACK)
   for x,w in [(0,1),(958,4),(1919,1)]:rect(d,x,270,w,540,TRACK)
   text(d,'ARTFLOW',64,48,8,YELLOW);text(d,'DUAL',1696,64,4,WHITE)
   text(d,'ORIGINAL',352,192,4,WHITE)
   label=styles[sid] if sv else 'WAITING';text(d,label,1440-len(label)*16,192,4,YELLOW)
   for x,fps,color,label in [(96,cap,cc,'CAP'),(1056,outfps,pc,'OUT')]:
    text(d,label,x,864,4,WHITE)
    rect(d,x+160,864,480,32,TRACK)
    width=min(30,fps)*16 if valid else 0
    if width:rect(d,x+160,864,width,32,color)
    rect(d,x+638,856,2,48,WHITE)
    text(d,f'{fps:03}' if valid else '---',x+672,864,4,color)
    text(d,'30',x+608,912,4,WHITE)
   text(d,'STYLE',96,992,4,WHITE)
   for i in range(8):
    x=352+i*128
    rect(d,x,984,64,48,YELLOW if sv and sid==i else TRACK)
    if not(sv and sid==i):rect(d,x+2,986,60,44,BG)
    text(d,str(i),x+16,992,4,BG if sv and sid==i else WHITE)
  else:
   rect(d,32,32,768,96,BG);text(d,'ARTFLOW',48,40,4,YELLOW)
   text(d,'STYLE' if mode==1 else 'ORIG',544,40,4,WHITE)
   text(d,'CAP',48,88,4,WHITE);text(d,f'{cap:03}',176,88,4,cc)
   text(d,'OUT',400,88,4,WHITE);text(d,f'{outfps:03}',528,88,4,pc)
 actual=Image.open(R/f'work/osd_tests/frame_{n:2}.ppm').convert('RGB')
 diff=ImageChops.difference(im,actual);bbox=diff.getbbox()
 if bbox:
  diff.save(O/f'FAIL_diff_{n:02}.png');im.save(O/f'expected_{n:02}.png')
  raise AssertionError(f'Frame {n} pixel mismatch bbox={bbox}, actual={actual.getpixel(bbox[:2])}, expected={im.getpixel(bbox[:2])}')
 actual.save(O/f'rtl_frame_{n:02}.png')
 checks.append(dict(frame=n,mode=mode,style=sid,osd=enabled,fps_valid=valid,style_valid=sv,cap=cap,outfps=outfps,pixels=1920*1080,sha256=hashlib.sha256(actual.tobytes()).hexdigest()))
(R/'reports'/('pixel_comparison.json' if count==13 else 'pixel_preview.json')).write_text(json.dumps({'status':'PASS','total_pixels':count*1920*1080,'independent_reference':'Python bitmap rectangles plus existing ROM glyph bits','frames':checks},indent=2))
# A contact sheet preserves actual RTL pixels (scaled only for review).
sheet=Image.new('RGB',(960,8*180),(15,18,22))
for i in range(min(count,8)):
 img=Image.open(O/f'rtl_frame_{i:02}.png');top=img.crop((0,0,1920,270)).resize((960,135))
 sheet.paste(top,(0,i*180));ImageDraw.Draw(sheet).text((32,i*180+145),f'{i:02} {styles[i]} / OUT={checks[i]["outfps"]}',fill='white')
sheet.save(O/'rtl_8_styles.png')
print(f'PASS independent full-raster comparison: {count*1920*1080:,} pixels / {count} frames')
