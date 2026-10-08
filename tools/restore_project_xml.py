"""Preserve user XML formatting only when the Efinity rewrite is semantic-equal."""
from pathlib import Path
import json
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
def structure(e):
    return e.tag,dict(e.attrib),(e.text or '').strip(),(e.tail or '').strip(),[structure(c) for c in e]
def main():
    before=ROOT/'work/ArtFlow.before_compile.xml'
    current=ROOT/'ArtFlow.xml'
    if structure(ET.parse(before).getroot()) != structure(ET.parse(current).getroot()):
        raise ValueError('Efinity changed project settings; original XML saved, automatic restoration refused')
    current.write_bytes(before.read_bytes())
    (ROOT/'work/xml_format_check.json').write_text(json.dumps({'semantic_equal':True,
        'action':'Restored exact user XML bytes after tool-only reformatting'},indent=2)+'\n')
    print('XML preservation PASS: semantic equality checked; original bytes restored')
if __name__=='__main__':main()
