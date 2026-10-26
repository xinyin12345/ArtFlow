from pathlib import Path
import sys,json,re,hashlib
R=Path(__file__).resolve().parents[1];sys.path.insert(0,str(R.parent/'tools'))
import check_round23t_video_cdc as c
fast=(c.WORK/'out/ArtFlow.video_bus_skew.rpt').read_text();slow=(c.WORK/'out/ArtFlow.video_bus_delay.rpt').read_text()
valid=c.parse_reports(fast,slow);assert [x['endpoints'] for x in valid]==[2,32,32,48]
cases={
 'missing_msb_source':slow.replace('stream_epoch[31]~FF|CLK','stream_epoch[30]~FF|CLK'),
 'wrong_msb_destination':slow.replace('epoch_meta[31]~FF|D','epoch_meta[30]~FF|D'),
 'missing_endpoint_count':re.sub(r'Endpoints: 3[12]', 'Endpoints: 30',slow,count=1),
 'over_budget_path':re.sub(r'(Endpoint Relative Delay:\s*)[0-9.]+',r'\g<1>99.000',slow,count=1),
 'negative_detail_slack':re.sub(r'(Slack:\s*)[0-9.]+ ns',r'\g<1>-0.001 ns',slow,count=1)
}
for name,body in cases.items():
 assert body!=slow,name
 try:c.parse_reports(fast,body)
 except ValueError:pass
 else:raise AssertionError('Corrupt audit accepted: '+name)
receipt={'status':'PASS','full_bus_endpoints':[2,32,32,48],'negative_cases_rejected':list(cases),'sha256':{str(p.relative_to(R)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [Path(c.__file__),Path(__file__),c.WORK/'out/ArtFlow.video_bus_skew.rpt',c.WORK/'out/ArtFlow.video_bus_delay.rpt']}}
(R/'logs/cdc-audit-parser-tests.json').write_text(json.dumps(receipt,indent=2))
print('CDC all-bit audit and five corrupt-report rejection tests PASS')
