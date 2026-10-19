# -*- coding: utf-8 -*-
"""Integer-only 480x270 inference with the frozen accepted U8 model."""
from pathlib import Path
import argparse,sys
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parent
sys.path.insert(0,str(R/'reference'))
from integer_model import IntegerStudent
a=argparse.ArgumentParser();a.add_argument('image');a.add_argument('output');args=a.parse_args()
im=Image.open(args.image).convert('RGB').resize((480,270))
rgb=np.asarray(im)[None].transpose(0,3,1,2)
out=IntegerStudent(R/'reference/integer').forward(rgb,verify_statistics=True)
dest=Path(args.output);dest.parent.mkdir(parents=True,exist_ok=True)
Image.fromarray(out[0].transpose(1,2,0)).save(dest)
print(dest)
