from pathlib import Path
import hashlib,json,datetime
R=Path(__file__).resolve().parents[1]
def restore_only_eol(path,before,work,flow):
 after=path.read_bytes()
 if after==before:return
 assert after.replace(b'\r\n',b'\n')==before.replace(b'\r\n',b'\n'), 'Tool changed XML beyond newline encoding: '+str(path)
 d=work/(flow+'_xml_eol');d.mkdir(exist_ok=False)
 (d/'original.xml').write_bytes(before);(d/'tool_modified.xml').write_bytes(after)
 path.write_bytes(before)
 (d/'receipt.json').write_text(json.dumps(dict(utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),reason='Tool newline-only XML rewrite; exact original restored before full source/functional validation',original_sha256=hashlib.sha256(before).hexdigest(),tool_sha256=hashlib.sha256(after).hexdigest()),indent=2),encoding='utf-8')
def accepted_summary(work):
 s=work/'map_summary.json';a=work/'map_accepted_summary.json'
 d=json.loads(s.read_text())
 if d['status']=='PASS':return d,s
 assert a.is_file(), 'Failed map without validated recovery receipt'
 x=json.loads(a.read_text());assert x['status']=='PASS' and x['accepted_existing_native_map'] and d['returncode']==0
 for n,h in x['sha256'].items():assert hashlib.sha256((R/n).read_bytes()).hexdigest()==h,n
 return x,a
