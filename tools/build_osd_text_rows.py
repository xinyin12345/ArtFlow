"""Build a 2048x5 aligned atlas; exactly reconstructs the original 8x8 glyphs."""
from pathlib import Path
import argparse,hashlib,json
R=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--write',action='store_true');a=p.parse_args()
labels=['ARTFLOW','ORIGINAL','DUAL','STYLE','CAP','OUT','WAITING','0123456789-','STAINED GLASS','SKETCH','OIL PAINTING','STARRY NIGHT','HALFTONE COMIC','SAND ART','INK','RICH WOODCUT']
characters=''.join(s.ljust(16) for s in labels)
assert len(characters)==256
font=[int(v,16) for v in (R/'rtl/video/osd_font.mem').read_text().split()];assert len(font)==1024
rows=[font[ord(c)*8+y] for c in characters for y in range(8)]
assert all((v & ~0x7c)==0 for v in rows), 'A glyph has nonzero columns outside the five stored columns'
packed=[v>>2 for v in rows];assert all((v<<2)==o for v,o in zip(packed,rows))
body=''.join(f'{v:02x}\n' for v in packed);target=R/'rtl/video/osd_text_rows.mem'
if a.write:target.write_text(body)
assert target.read_text()==body
print(json.dumps(dict(status='PASS_EXACT_8X8_GLYPH_RECONSTRUCTION',characters=256,rows=2048,width=5,sha256=hashlib.sha256(target.read_bytes()).hexdigest())))
