"""Portable package integrity check. Never promotes NOT_RUN board acceptance."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
def main():
    m=json.loads((ROOT/'doc/verified_files_sha256.json').read_text())
    if m.get('version')!='v06' or m.get('status')!='PASS':raise ValueError('Not a verified v06 manifest')
    for name,digest in m['files'].items():
        path=(ROOT/name).resolve()
        if not path.is_relative_to(ROOT) or not path.is_file():raise ValueError('Unsafe/missing path: '+name)
        if hashlib.sha256(path.read_bytes()).hexdigest()!=digest:raise ValueError('File differs: '+name)
    for folder in ('v06','chain','inherited','video'):
        s=json.loads((ROOT/'doc/verification'/folder/'summary.json').read_text())
        if s['status']!='PASS':raise ValueError('Evidence not PASS: '+folder)
        for name,digest in s.get('source_sha256',{}).items():
            if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=digest:raise ValueError('Stale test '+name)
        for name,digest in s.get('evidence_sha256',{}).items():
            p=ROOT/'doc/verification'/folder/name
            if hashlib.sha256(p.read_bytes()).hexdigest()!=digest:raise ValueError('Stale evidence '+name)
    s=json.loads((ROOT/'doc/verification/implementation_source_sha256.json').read_text())
    for name,digest in s.items():
        if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=digest:raise ValueError('Stale build '+name)
    print(f'V06 VERIFY PASS: {len(m["files"])} files; board status remains NOT_RUN')
if __name__=='__main__':main()
