"""Check the committed delivery fingerprint, allowing text CRLF/LF conversion."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--with-generated', action='store_true',
                        help='also require the local bitstream and full build artifacts')
    args = parser.parse_args()
    manifest = json.loads((ROOT/'doc/verified_files_sha256.json').read_text(encoding='utf-8'))
    rows = manifest['sources'] + manifest['evidence']
    if args.with_generated:
        rows += manifest['generated']
    failed = []
    for row in rows:
        path = ROOT / row['path']
        if not path.is_file():
            failed.append(row['path'] + ': missing')
            continue
        data = path.read_bytes()
        if 'lf_sha256' in row:
            actual = hashlib.sha256(data.replace(b'\r\n', b'\n')).hexdigest()
            expected = row['lf_sha256']
        else:
            actual = hashlib.sha256(data).hexdigest()
            expected = row['sha256']
        if actual != expected:
            failed.append(row['path'] + ': changed')
    if failed:
        print('\n'.join(failed))
        return 1
    print(f'DELIVERY PASS: {len(rows)} files match verified fingerprints')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
