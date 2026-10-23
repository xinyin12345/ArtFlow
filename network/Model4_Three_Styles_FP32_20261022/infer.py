"""One Model4 instance; swap its full state_dict to change artistic style."""
import argparse
import hashlib
import json
from pathlib import Path

import torch
from torchvision.utils import save_image
from model4 import Model4
from image_io import load_image, denormalize

ROOT = Path(__file__).resolve().parent

class StyleRenderer:
    def __init__(self, device='cpu'):
        self.device = torch.device(device)
        if self.device.type == 'cuda' and not torch.cuda.is_available():
            raise RuntimeError('CUDA is unavailable. Use --device cpu.')
        self.registry = json.loads((ROOT/'styles.json').read_text(encoding='utf-8'))
        if self.registry['architecture'] != Model4.architecture:
            raise ValueError('Architecture mismatch')
        self.model = Model4().to(self.device).eval()
        self.style = None

    def set_style(self, style):
        if style not in self.registry['styles']:
            raise ValueError(f'Unknown style: {style}')
        spec = self.registry['styles'][style]
        path = ROOT/spec['weights']
        if hashlib.sha256(path.read_bytes()).hexdigest() != spec['weights_sha256']:
            raise ValueError(f'Weight checksum mismatch: {path}')
        state = torch.load(path, map_location='cpu', weights_only=True)
        # Includes learned parameters AND all BatchNorm running statistics.
        self.model.load_state_dict(state, strict=True)
        self.model.eval()
        self.style = style

    @torch.inference_mode()
    def render_tensor(self, normalized_rgb):
        if self.style is None:
            raise RuntimeError('Call set_style before rendering.')
        output = self.model(normalized_rgb.to(self.device))
        if not torch.isfinite(output).all():
            raise FloatingPointError('Non-finite model output')
        return denormalize(output).clamp(0, 1).cpu()

    def render(self, input_path, output_path):
        content = load_image(Path(input_path), (270, 480)).unsqueeze(0)
        result = self.render_tensor(content)
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        save_image(result, output_path)
        return output_path.resolve()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--style', choices=['sketch', 'oil', 'pointillism', 'all'], required=True)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True, help='PNG filename; for --style all, an output directory.')
    parser.add_argument('--device', choices=['cpu', 'cuda'], default='cpu')
    args = parser.parse_args()
    if not args.input.is_file():
        parser.error(f'Input does not exist: {args.input}')
    if args.style != 'all' and args.output.suffix.lower() != '.png':
        parser.error('Use a .png output filename to avoid lossy image encoding.')
    if args.style == 'all' and args.output.exists() and not args.output.is_dir():
        parser.error('--style all requires an output directory.')
    torch.set_num_threads(4)
    renderer = StyleRenderer(args.device)
    styles = ['sketch', 'oil', 'pointillism'] if args.style == 'all' else [args.style]
    for style in styles:
        renderer.set_style(style)
        output = args.output/f'{args.input.stem}_{style}.png' if args.style == 'all' else args.output
        print(f'{style}: {renderer.render(args.input, output)}')

if __name__ == '__main__':
    main()
