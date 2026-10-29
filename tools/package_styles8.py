"""Publish only a fully gated eight-style streaming build. No hardware access."""
from pathlib import Path
import argparse, datetime, hashlib, json, os, shutil, subprocess, sys
from check_round23t_project import verify, W, SNAP

R = Path(__file__).resolve().parents[1]

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', type=Path, default=R/'releases/styles8_stream30_20261030')
    args = ap.parse_args()
    source = verify()
    assert source == json.loads(SNAP.read_text())
    for name in ['map','interface','pnr','normal_sta','cnn_cdc','ui_cdc','video_cdc','style_io_cdc','return_ram_cdc','stream_io','pgm']:
        receipt = json.loads((W/(name+'_summary.json')).read_text())
        assert receipt['status']==('PASS_CONDITIONAL_EXTERNAL_BUDGET' if name=='stream_io' else 'PASS'),name
        for n,h in receipt.get('sha256',{}).items() if isinstance(receipt.get('sha256'),dict) else []:
            assert sha(R/n)==h,('Stale implementation evidence',name,n)
    functional=json.loads((R/'reports/styles8/round23t_functional_receipt.json').read_text())
    assert functional['status']=='PASS' and functional['implementation']==source
    for n,h in functional['sha256'].items():assert sha(R/n)==h,('Stale functional evidence',n)
    subprocess.run([sys.executable,'-B','stream/scripts/verify_regression_evidence.py'],cwd=R,check=True)
    subprocess.run([sys.executable,'-B','tools/verify_package.py'],cwd=R,check=True)
    subprocess.run([sys.executable,'-B','tools/regenerate_package.py'],cwd=R,check=True)
    fpga=json.loads((R/'stream/logs/fpga-final.json').read_text())
    assert fpga['status']=='PASS_OFFLINE_CONDITIONAL_IO_BUDGET'
    for n,h in fpga['artifacts'].items():assert sha(W/'out'/n)==h
    out=args.out.resolve();assert out.is_relative_to(R.resolve()) and not out.exists()
    out.mkdir(parents=True)
    for ext in ['bit','hex']:
        shutil.copy2(W/'out'/('ArtFlow.'+ext),out/('ArtFlow_styles8_stream30.'+ext))
    for p in (R/'network/styles8').iterdir():shutil.copy2(p,out/p.name)
    e=Path(os.environ.get('EFINITY_ROOT','D:/soft/Efinity/2026.1'))
    env=os.environ.copy()
    env.update(EFINITY_HOME=e.as_posix(),EFXPGM_HOME=(e/'pgm').as_posix(),PYTHONHOME=(e/'python311').as_posix(),EFINITY_USER_DIR=(W/'user').as_posix())
    env['PATH']=str(e/'bin')+os.pathsep+str(e/'python311/bin')+os.pathsep+env['PATH']
    merged=out/'ArtFlow_styles8_stream30_with_models.hex'
    cmd=[str(e/'python311/bin/python.exe'),str(e/'pgm/bin/multi_image_merger.py'),'-m','generic_comb_image','-ifile',str(out/'ArtFlow_styles8_stream30.hex'),'-ifile',str(out/'models8_parameters.bin'),'-iaddr','0x0','-iaddr','0x400000','-o',str(merged)]
    with (out/'merge.log').open('w') as log:subprocess.run(cmd,cwd=R,env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
    config=bytes.fromhex((out/'ArtFlow_styles8_stream30.hex').read_text())
    model=(out/'models8_parameters.bin').read_bytes()
    actual=bytes.fromhex(merged.read_text())
    assert 256<len(config)<0x400000 and len(model)==0x20000
    expected=config+b'\xff'*(0x400000-len(config))+model
    assert actual==expected and len(actual)==0x420000,'Merged image byte mismatch'
    report=merged.with_suffix('.rpt').read_text()
    assert '0x00400000' in report and '0x00020000' in report
    evidence=out/'evidence';evidence.mkdir()
    for p in W.glob('*summary.json'):shutil.copy2(p,evidence/p.name)
    for pattern in ['*.rpt','*.out']:
        for p in (W/'out').glob(pattern):shutil.copy2(p,evidence/p.name)
    for p in W.glob('*.log'):shutil.copy2(p,evidence/p.name)
    shutil.copy2(W/'map_warnings_snapshot.log',evidence/'map_warnings_snapshot.log')
    shutil.copy2(SNAP,evidence/SNAP.name)
    for p in (R/'reports/styles8').glob('*.json'):shutil.copy2(p,evidence/p.name)
    for p in (R/'work').glob('styles8_v2_*/summary.json'):
        d=evidence/p.parent.name;d.mkdir();shutil.copy2(p,d/p.name);shutil.copy2(p.parent/'simulation.log',d/'simulation.log')
        for dump in p.parent.glob('system_*.hex'):shutil.copy2(dump,d/dump.name)
    for p in [R/'outputs/firmware/host_tests.json',R/'outputs/firmware/build_manifest.json',R/'stream/logs/fpga-final.json',R/'stream/logs/current-regression-binding.json',R/'stream/logs/cdc-audit-parser-tests.json',R/'stream/logs/host-tests.json',R/'stream/logs/browser-tests.json']:
        shutil.copy2(p,evidence/p.name)
    for group in ['rtl','tap','reset-equivalence','protocol']:
        d=evidence/('stream_'+group);d.mkdir();shutil.copy2(R/'stream/logs'/group/'summary.json',d/'summary.json')
    for attempt in (R/'work').glob('styles8_attempt_seed*'):
        d=evidence/attempt.name;d.mkdir()
        for rel in ['pnr_summary.json','implementation_source_sha256.json','out/ArtFlow.route.out','out/ArtFlow.place.rpt']:
            p=attempt/rel
            if p.is_file():shutil.copy2(p,d/p.name)
    info={'status':'PASS_OFFLINE_REQUIRES_BOARD_ACCEPTANCE','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'hardware_programmed':False,'previous15_order':[0,5,1,3,2,14,7,8],'model_base':0x400000,'model_bytes':len(model),'merged_bytes':len(actual),'configuration_bytes':len(config),'full_merged_byte_equivalence':True,'gap_all_ff':True,'source_sha256':source,'sha256':{p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file()}}
    info['packaging_script_sha256']=sha(Path(__file__))
    (out/'manifest.json').write_text(json.dumps(info,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'status':info['status'],'release':str(out),'artifacts':{n:info['sha256'][n] for n in ['ArtFlow_styles8_stream30.bit','ArtFlow_styles8_stream30.hex','ArtFlow_styles8_stream30_with_models.hex','models8_parameters.bin']}},indent=2))

if __name__=='__main__':main()
