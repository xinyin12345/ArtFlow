# -*- coding: utf-8 -*-
"""All-code bounds for the new statistic collection/projection operations."""
from pathlib import Path
import json,hashlib
import numpy as np
R=Path(__file__).resolve().parent
graph=json.loads((R/'reference/integer/graph.json').read_text('utf8'))
nodes={n['name']:n for n in graph['nodes']}
p=np.load(R/'reference/integer/model_int.npz',allow_pickle=False)
results=[]
for n in graph['nodes']:
    if not n['center']:continue
    assert n['stride']==1 and n['groups']==1 and not n['up2_before'] and n['center_n']==8160
    assert np.all(p[n['name']+'.bias']==0)
    source=nodes[n['source']];limit=max(abs(source['qmin']),abs(source['qmax']));area=8160
    tap_bound=area*limit
    weights=p[n['name']+'.weight'].astype(np.int64)
    projection_bounds=area*limit*np.abs(weights).sum((1,2,3))
    one_product=tap_bound*int(np.abs(weights).max())
    assert tap_bound<2**23
    assert limit*4<2**10
    assert one_product<2**47
    assert int(projection_bounds.max())<2**39
    results.append(dict(layer=n['name'],source=n['source'],source_abs_code_bound=int(limit),
        source_tap_sum_abs_bound=int(tap_bound),single_project_product_abs_bound=int(one_product),
        projection_and_prefix_abs_bounds=projection_bounds.tolist()))
baseline_pins=json.loads((R/'baseline/reference_pins.json').read_text('utf8'))
unchanged={}
for path in ['reference/integer/model_int.npz','reference/integer/graph.json']+['mem/shared_'+n+'.mem' for n in ['weights','bias','main','beta']]:
    here=(R/path).read_bytes();unchanged[path]=hashlib.sha256(here).hexdigest()
    assert unchanged[path]==baseline_pins[path],path
proof=dict(scope='all valid source codes, fixed 480x270 graph; no sample-only bound',
    statistic_storage_signed_bits=24,statistic_increment_signed_bits=11,projection_sum_signed_bits=40,
    shared_math_product_signed_bits=61,unchanged_parameters_and_roms=unchanged,layers=results,
    identity='sum_HW(conv_reflect(X,W)) = sum_ci_tap(tap_sums_reflect(X)*W)',
    rounding='no rounding in statistic collection/projection; original single mean division and R24 retained')
(R/'optimization_proof.json').write_text(json.dumps(proof,indent=2),encoding='utf8')
print('PASS all-code statistic/projection bounds and unchanged parameter/ROM bytes')
