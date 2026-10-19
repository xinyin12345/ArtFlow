"""Standalone inference: no original project, FP32 model, or VGG required."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image,ImageOps
import torch

def main():
    root=Path(__file__).resolve().parent
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input',default=str(root/'example_input.png'))
    parser.add_argument('--output',default=str(root/'result_int8.png'))
    parser.add_argument('--model',default=str(root/'model_int8.pt'))
    args=parser.parse_args()
    torch.set_num_threads(4)
    with Image.open(args.input) as source:
        image=ImageOps.exif_transpose(source).convert('RGB').resize((480,270),Image.Resampling.BILINEAR)
        value=torch.from_numpy(np.asarray(image).copy()).permute(2,0,1).unsqueeze(0)
    model=torch.jit.load(args.model,map_location='cpu').eval()
    with torch.inference_mode():
        result=model(value)[0]
    path=Path(args.output)
    path.parent.mkdir(parents=True,exist_ok=True)
    Image.fromarray(result.permute(1,2,0).numpy()).save(path)
    print(f'Saved {path.resolve()} (480x270, actual integer CPU reference)')

if __name__=='__main__':
    main()
