"""Verify the packaged v05 sources/evidence and optionally live build outputs."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]


def verify(records):
    for name, expected in records.items():
        path=(ROOT/name).resolve()
        if not path.is_relative_to(ROOT.resolve()) or not path.is_file():
            raise ValueError('Missing/nonlocal delivery file: '+name)
        if hashlib.sha256(path.read_bytes()).hexdigest()!=expected:
            raise ValueError('Changed delivery file: '+name)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--with-generated',action='store_true')
    args=parser.parse_args()
    manifest=json.loads((ROOT/'doc/verified_files_sha256.json').read_text())
    if manifest['version']!='v05' or manifest['offline_status']!='PASS':
        raise ValueError('Not a verified v05 delivery')
    verify(manifest['files'])
    if args.with_generated: verify(manifest['generated'])
    baseline=ROOT.parent/'v04'
    if baseline.is_dir():
        for name,digest in json.loads((ROOT/'doc/baseline_v04/source_sha256.json').read_text()).items():
            if hashlib.sha256((baseline/name).read_bytes()).hexdigest()!=digest:
                raise ValueError('v04 baseline changed: '+name)
    print(f'DELIVERY PASS: {len(manifest["files"])} v05 files verified; hardware status NOT_RUN')


if __name__=='__main__':
    main()
