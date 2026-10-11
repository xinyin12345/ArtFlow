"""Integer box / half-pixel bilinear reference, independent of RTL scheduling."""
import random
def vectors(width,height,seed=7):
    rng=random.Random(seed)
    src=[tuple(rng.randrange(256) for _ in range(3)) for _ in range(width*height)]
    return src,resize(src,width,height)

def resize(src,width,height):
    low=[]
    for y in range(0,height,2):
        for x in range(0,width,2):
            low.append(tuple((sum(src[(y+dy)*width+x+dx][c] for dy in (0,1) for dx in (0,1))+2)//4 for c in range(3)))
    dst=[]
    for y in range(height):
        # x_in=(x_out+0.5)/2-0.5; exact integer weights over denominator 4.
        y0=(2*y-1)//4; fy=(2*y-1)%4
        for x in range(width):
            x0=(2*x-1)//4; fx=(2*x-1)%4
            out=[]
            for c in range(3):
                total=0
                for dy,wy in ((0,4-fy),(1,fy)):
                    for dx,wx in ((0,4-fx),(1,fx)):
                        yy=max(0,min(height//2-1,y0+dy));xx=max(0,min(width//2-1,x0+dx))
                        total+=low[yy*(width//2)+xx][c]*wx*wy
                out.append((total+8)//16)
            dst.append(tuple(out))
    pack=lambda p:p[0]|p[1]<<8|p[2]<<16
    return dst

def write_vectors(run,width,height,seed=7):
    for name,data in zip(('input.hex','golden.hex'),vectors(width,height,seed)):
        data=[p[0]|p[1]<<8|p[2]<<16 for p in data]
        (run/name).write_text(''.join(f'{v:08x}\n' for v in data),encoding='ascii')
