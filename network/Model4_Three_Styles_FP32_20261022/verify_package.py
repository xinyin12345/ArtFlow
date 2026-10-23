"""Check source hashes, full/compact weights and one-instance style switching."""
import hashlib
import json
from pathlib import Path
import torch
from model4 import Model4
from image_io import load_image, denormalize
from infer import ROOT, StyleRenderer

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    torch.set_num_threads(4)
    registry = json.loads((ROOT/'styles.json').read_text(encoding='utf-8'))
    assert sha(ROOT/'model4.py') == registry['source_model_sha256']
    assert sha(ROOT/'image_io.py') == registry['source_data_sha256']
    assert sha(ROOT/'examples/input_zebra.jpg') == registry['test_photo_sha256']
    renderer = StyleRenderer('cpu')
    assert sum(p.numel() for p in renderer.model.parameters()) == 7755
    content = load_image(ROOT/'examples/input_zebra.jpg', (270,480)).unsqueeze(0)
    records=[]; first=None
    for style,spec in registry['styles'].items():
        assert sha(ROOT/spec['checkpoint']) == spec['checkpoint_sha256']
        c=torch.load(ROOT/spec['checkpoint'],map_location='cpu',weights_only=True)
        assert c['architecture']==Model4.architecture and c['format_version']==1
        assert c['next_epoch']==10 and c['next_batch']==0 and c['global_step']==3130
        assert c['config']['loss']['content_weight']==spec['content_weight']
        renderer.set_style(style)
        state=renderer.model.state_dict()
        assert len(state)==81 and set(state)==set(c['model'])
        assert all(torch.equal(state[k],c['model'][k]) for k in state)
        full=Model4().eval();full.load_state_dict(c['model'],strict=True)
        with torch.inference_mode():
            expected=denormalize(full(content)).clamp(0,1)
            actual=renderer.render_tensor(content)
        assert torch.equal(actual,expected)
        server=torch.load(ROOT/f'provenance/{style}_cpu_reference_tensor.pt',map_location='cpu',weights_only=True)
        diff=float((actual-server).abs().max())
        assert diff<=5e-5,(style,diff)
        if first is None:first=actual.clone()
        records.append({'style':style,'full_vs_pure_exact':True,'server_cpu_max_abs_difference':diff,'state_tensors':len(state)})
    renderer.set_style('sketch')
    assert torch.equal(renderer.render_tensor(content),first)
    report={'passed':True,'parameter_count':7755,'records':records,'switch_back_exact':True,
            'torch_version':torch.__version__,'device':'cpu','no_training_performed':True}
    destination=ROOT/'verification_local.json'
    destination.write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report,indent=2))

if __name__=='__main__':
    main()
