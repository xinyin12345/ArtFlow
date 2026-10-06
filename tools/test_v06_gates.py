"""Exercise rejection paths against copies of actual v06 evidence, not the RTL."""
from pathlib import Path
import json,shutil,tempfile
from run_v06 import ROOT,pixel_check
from package_v06 import validate_run
def main():
    base=ROOT/'work/gate_tests';base.mkdir(parents=True,exist_ok=True)
    passed=[]
    def reject(name,call):
        try:call()
        except (ValueError,RuntimeError,FileNotFoundError):passed.append(name);return
        raise AssertionError('Gate accepted invalid evidence: '+name)
    with tempfile.TemporaryDirectory(dir=base) as d:
        root=Path(d);pixels=root/'pixels.hex'
        original=ROOT/'work/regression_v06/osd_pixels.hex'
        pixels.write_text('xxxxxx\n');reject('unknown_pixel',lambda:pixel_check(pixels))
        pixels.write_text('ffffff\n');reject('wrong_first_pixel',lambda:pixel_check(pixels))
        pixels.write_text('');reject('missing_pixels',lambda:pixel_check(pixels))
        shutil.copyfile(original,pixels)
        with pixels.open('a') as f:f.write('000000\n')
        reject('extra_pixels',lambda:pixel_check(pixels))
        summary=root/'summary.json'
        summary.write_text(json.dumps(dict(status='RUNNING')))
        reject('incomplete_regression',lambda:validate_run(root))
        summary.write_text(json.dumps(dict(status='PASS',source_sha256={'rtl/video/artflow_osd.v':'0'*64})))
        reject('stale_source_hash',lambda:validate_run(root))
        summary.write_text(json.dumps(dict(status='PASS',evidence_sha256={'missing.log':'0'*64})))
        reject('missing_log',lambda:validate_run(root))
    (base/'summary.json').write_text(json.dumps(dict(status='PASS',tests=passed),indent=2)+'\n')
    print(f'V06 GATE TESTS PASS: {len(passed)} expected rejections')
if __name__=='__main__':main()
