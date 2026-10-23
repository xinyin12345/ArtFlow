"""Deterministic image resizing and fixed content-image subset selection."""
import hashlib
from pathlib import Path
import random

from PIL import Image, ImageOps
import torch
from torch.utils.data import Dataset
from torchvision import transforms

MEAN = (0.485, 0.456, 0.406)
STD = (0.229, 0.224, 0.225)
EXTENSIONS = {'.jpg', '.jpeg', '.png', '.bmp', '.webp', '.tif', '.tiff'}


def normalize(rgb):
    mean = rgb.new_tensor(MEAN).reshape(-1, 1, 1)
    std = rgb.new_tensor(STD).reshape(-1, 1, 1)
    return (rgb - mean) / std


def denormalize(normalized):
    mean = normalized.new_tensor(MEAN).reshape(-1, 1, 1)
    std = normalized.new_tensor(STD).reshape(-1, 1, 1)
    return normalized * std + mean


def load_image(path, size=None):
    with Image.open(path) as source:
        rgb = ImageOps.exif_transpose(source).convert('RGB')
        if size is not None:
            rgb = transforms.Resize(tuple(size), antialias=True)(rgb)
        return normalize(transforms.ToTensor()(rgb))


class ContentDataset(Dataset):
    def __init__(self, directory, size=(256, 256), limit=4800, seed=42):
        self.root = Path(directory).resolve()
        self.size = tuple(size)
        files = sorted(p for p in self.root.rglob('*') if p.is_file() and p.suffix.lower() in EXTENSIONS)
        if not files:
            raise ValueError(f'No content images in {self.root}')
        if limit and len(files) > limit:
            files = sorted(random.Random(seed).sample(files, limit))
        self.files = files
        self.manifest = [{'path': str(p), 'bytes': p.stat().st_size, 'mtime_ns': p.stat().st_mtime_ns} for p in files]
        # Includes sizes/mtimes so resuming on a changed input pool is rejected.
        import json
        self.signature = hashlib.sha256(json.dumps(self.manifest, sort_keys=True).encode()).hexdigest()

    def __len__(self):
        return len(self.files)

    def __getitem__(self, index):
        return load_image(self.files[index], self.size)
