"""Package the user-tested OSD bit and eight-style models. Offline files only."""
from pathlib import Path
import argparse,datetime,hashlib,json,os,shutil,subprocess,sys,zipfile
R=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',type=Path,default=R/'releases/osd_flash_backup_20261031');a=ap.parse_args()
 out=a.out.resolve();assert out.is_relative_to((R/'releases').resolve()) and not out.exists(), 'New release directory required'
 release=read(R/'outputs/release_manifest.json')
 for group in ['source_files_sha256','model_files_sha256','files_sha256']:
  for n,h in release[group].items():assert sha(R/n)==h,('Original release binding mismatch',n)
 assert read(R/'reports/physical_gate.json')['status']=='PASS'
 assert sha(R/'outputs/ArtFlow_osd_blackbars_20261030.bit')=='8ff3f2565d92b7f9e4092d06513b8cefbc771ae21a2bc81f1458ba0fc31d1e50'
 assert sha(R/'outputs/ArtFlow_osd_blackbars_20261030.hex')=='8f0d1b632a34a4397542edb09b7a4d368c2a0f073bebb5aa23ac02d48600b104'
 sys.path.insert(0,str(R/'tools'))
 from verify_package import verify
 from regenerate_package import regenerate
 model=(R/'network/styles8/models8_parameters.bin').read_bytes();meta=read(R/'network/styles8/models8_manifest.json')
 verify(model,(R/'network/styles15/source19_parameters.bin').read_bytes(),meta)
 assert regenerate()==model==bytes.fromhex((R/'network/styles8/models8_parameters.hex').read_text())
 out.mkdir(parents=True)
 for name in ['fpga','models','flash','evidence','tools']:(out/name).mkdir()
 for ext in ['bit','hex']:shutil.copy2(R/'outputs'/('ArtFlow_osd_blackbars_20261030.'+ext),out/'fpga'/('ArtFlow_osd_blackbars_20261030.'+ext))
 for name in ['models8_parameters.bin','models8_parameters.hex','models8_manifest.json','old_new_mapping.csv']:shutil.copy2(R/'network/styles8'/name,out/'models'/name)
 for name in ['physical_gate.json','delivery.json','regression_complete.json','compact_osd_change.json','source_diff.json']:shutil.copy2(R/'reports'/name,out/'evidence'/name)
 for name in ['release_manifest.json','FINAL_ACCEPTANCE.md']:shutil.copy2(R/'outputs'/name,out/'evidence'/('original_'+name))
 for name in ['normal_sta_summary.json','pgm_summary.json','pnr_summary.json']:shutil.copy2(R/'work/osd_impl'/name,out/'evidence'/name)
 for name in ['verify_package.py','regenerate_package.py','package_styles8.py']:shutil.copy2(R/'tools'/name,out/'evidence'/('original_'+name))
 shutil.copy2(__file__,out/'evidence/prepare_osd_flash_backup.py')
 e=Path('D:/soft/Efinity/2026.1');env=os.environ.copy();env.update(EFINITY_HOME=e.as_posix(),EFXPGM_HOME=(e/'pgm').as_posix(),PYTHONHOME=(e/'python311').as_posix(),PYTHONDONTWRITEBYTECODE='1',PYTHONUTF8='1',EFINITY_USER_DIR=str(R/'work/osd_impl/user'))
 env['PATH']=str(e/'bin')+os.pathsep+str(e/'python311/bin')+os.pathsep+env['PATH']
 merged=out/'flash/ArtFlow_osd_8styles_fullflash.hex'
 cmd=[str(e/'python311/bin/python.exe'),str(e/'pgm/bin/multi_image_merger.py'),'-m','generic_comb_image','-ifile',str(out/'fpga/ArtFlow_osd_blackbars_20261030.hex'),'-ifile',str(out/'models/models8_parameters.bin'),'-iaddr','0x0','-iaddr','0x400000','-o',str(merged)]
 (out/'evidence/merge_command.json').write_text(json.dumps(dict(command=cmd,tool_sha256=sha(e/'pgm/bin/multi_image_merger.py'),hardware_access=False),indent=2))
 with (out/'evidence/merge.log').open('w') as log:subprocess.run(cmd,cwd=R,env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
 config=bytes.fromhex((out/'fpga/ArtFlow_osd_blackbars_20261030.hex').read_text());actual=bytes.fromhex(merged.read_text());assert 256<len(config)<0x400000
 expected=config+b'\xff'*(0x400000-len(config))+model
 assert actual==expected and len(actual)==0x420000
 report=merged.with_suffix('.rpt').read_text();assert '0x00400000' in report and '0x00020000' in report
 (out/'tools/verify_backup.py').write_text(VERIFY,encoding='utf-8')
 (out/'README_FLASH_BACKUP.md').write_text(README.format(bitsha=sha(out/'fpga/ArtFlow_osd_blackbars_20261030.bit'),hexsha=sha(out/'fpga/ArtFlow_osd_blackbars_20261030.hex'),modelsha=sha(out/'models/models8_parameters.bin'),mergedsha=sha(merged),configbytes=len(config),configend=f'{len(config)-1:08X}',gapstart=f'{len(config):08X}',gapbytes=0x400000-len(config),hexbytes=merged.stat().st_size),encoding='utf-8')
 result=dict(status='PASS_OFFLINE_FLASH_IMAGE_VERIFIED',utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),source_candidate=str(R),user_reported_bit_board_effect_good=True,flash_programmed_by_assistant=False,flash_cold_boot_verified=False,baseline_commit='4473983390d7009be06fc6f5fdb5ad54fe4bce03',original_release_manifest_sha256=sha(R/'outputs/release_manifest.json'),configuration_address=0,configuration_decoded_bytes=len(config),model_base=0x400000,model_bytes=len(model),model_slot_bytes=16384,merged_decoded_bytes=len(actual),merged_last_address=0x41ffff,gap_fill=255,full_merged_byte_equivalence=True,model_order=['glass','sketch','oil','starry','halftone','sand','inkwash','woodrich'],original_release_unchanged=True)
 (out/'evidence/flash_image_verification.json').write_text(json.dumps(result,indent=2))
 manifest=dict(**result,files={p.relative_to(out).as_posix():dict(bytes=p.stat().st_size,sha256=sha(p)) for p in sorted(out.rglob('*')) if p.is_file()})
 (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
 (out/'SHA256SUMS.txt').write_text(''.join(f'{sha(p)}  {p.relative_to(out).as_posix()}\n' for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256SUMS.txt'))
 subprocess.run([sys.executable,'-B',str(out/'tools/verify_backup.py')],check=True)
 archive=out.with_suffix('.zip');assert not archive.exists()
 with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for p in sorted(out.rglob('*')):
   if p.is_file():z.write(p,(Path(out.name)/p.relative_to(out)).as_posix())
 with zipfile.ZipFile(archive) as z:
  assert z.testzip() is None
  for p in out.rglob('*'):
   if p.is_file():assert hashlib.sha256(z.read((Path(out.name)/p.relative_to(out)).as_posix())).hexdigest()==sha(p)
 archive.with_suffix('.zip.sha256').write_text(f'{sha(archive)}  {archive.name}\n')
 print(json.dumps(dict(status='PASS',directory=str(out),zip=str(archive),zip_bytes=archive.stat().st_size,zip_sha256=sha(archive),merged_hex=str(merged),merged_hex_sha256=sha(merged),merged_decoded_bytes=len(actual)),indent=2))
VERIFY=r'''"""Offline verification only. Standard Python 3; no EDA or hardware access."""
from pathlib import Path
import hashlib,json,struct,zlib,sys
root=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
for n,v in m['files'].items():
 p=root/n
 assert p.resolve().is_relative_to(root) and p.stat().st_size==v['bytes'] and sha(p)==v['sha256'],n
for line in (root/'SHA256SUMS.txt').read_text().splitlines():
 h,n=line.split('  ',1);assert sha(root/n)==h,n
config=bytes.fromhex((root/'fpga/ArtFlow_osd_blackbars_20261030.hex').read_text())
model=(root/'models/models8_parameters.bin').read_bytes();meta=json.loads((root/'models/models8_manifest.json').read_text(encoding='utf-8'))
assert bytes.fromhex((root/'models/models8_parameters.hex').read_text())==model
assert len(model)==0x20000 and hashlib.sha256(model).hexdigest()==meta['sha256']
assert [x['name'] for x in meta['models']]==['glass','sketch','oil','starry','halftone','sand','inkwash','woodrich']
for i,x in enumerate(meta['models']):
 s=model[i*16384:(i+1)*16384];h=struct.unpack_from('<8I',s)
 assert h[:4]==(0x4d534641,1,i,14448) and h[4]==zlib.crc32(s[32:14480])==int(x['crc32'],16)
 assert h[5:]==(0,0,0) and s[14480:]==b'\xff'*1904
 assert hashlib.sha256(s).hexdigest()==x['slot_sha256'] and hashlib.sha256(s[32:14480]).hexdigest()==x['payload_sha256']
 assert x['flash_address']==0x400000+i*16384
actual=bytes.fromhex((root/'flash/ArtFlow_osd_8styles_fullflash.hex').read_text())
assert 0<len(config)<0x400000 and len(actual)==0x420000
assert actual==config+b'\xff'*(0x400000-len(config))+model
print('PASS: all file SHA256; eight model IDs/CRC/payload/padding; configuration/FF gap/models byte-exact; 0x000000..0x41FFFF. No hardware access.')
'''
README='''# ArtFlow OSD + 8 风格 Flash 固化备份

本包使用用户已上板确认显示效果不错的 OSD bit，原始 bit/hex 未重新综合或改写。合并文件已完成离线逐字节校验；本次没有执行烧录，Flash 冷启动仍待用户手动验证。

## 应当选择哪个文件

| 文件 | 用途 |
|---|---|
| `flash/ArtFlow_osd_8styles_fullflash.hex` | **完整固化文件**：FPGA 配置 + 8 风格模型，从 Flash 地址 **0x000000** 写入 |
| `fpga/ArtFlow_osd_blackbars_20261030.bit` | 已上板确认的原始 RTL 构建 bit，供原有加载流程使用 |
| `fpga/ArtFlow_osd_blackbars_20261030.hex` | 同次 Efinity 构建产生的 FPGA 配置 hex，不包含外部模型区域 |
| `models/models8_parameters.bin` | 全部 8 风格运行时模型包，单独写入时地址为 **0x400000** |
| `models/models8_parameters.hex` | 同一模型包的逐字节 hex 表示，偏移从模型包自身的 0 开始 |
| `models/models8_manifest.json` | 模型顺序、地址、CRC、槽位及有效负载 SHA256 |
| `models/old_new_mapping.csv` | 原模型编号与最终 8 风格编号对应 |

这里的 `.hex` 是工程/Efinity 使用的逐字节十六进制文本，不是冒号开头的 Intel HEX。请按原有 Efinity Flash 文件流程选择完整合并文件；无需再次附加模型或对合并文件施加 0x400000 偏移。

## Flash 地址布局

| 区域 | 起始地址 | 结束地址（包含） | 解码后字节数 |
|---|---|---|---:|
| FPGA 配置 hex 原始内容 | 0x00000000 | 0x{configend} | {configbytes} |
| 擦除态填充 FF | 0x{gapstart} | 0x003FFFFF | {gapbytes} |
| 8 风格模型包 | 0x00400000 | 0x0041FFFF | 131072 |
| 完整合并镜像 | 0x00000000 | 0x0041FFFF | 4325376（0x420000） |

合并 hex 文本文件大小为 {hexbytes} 字节；文本大小不等于实际 Flash 占用。

风格顺序与地址：

| ID | 风格 | Flash 地址 |
|---|---|---|
| 0 | 玻璃 | 0x400000 |
| 1 | 素描 | 0x404000 |
| 2 | 油画 | 0x408000 |
| 3 | 星空 | 0x40C000 |
| 4 | 网点 | 0x410000 |
| 5 | 沙画 | 0x414000 |
| 6 | 水墨 | 0x418000 |
| 7 | 富彩粗刀版画 | 0x41C000 |

每槽 16384 字节：32 字节 AFSM 头 + 14448 字节模型有效负载 + 1904 字节 FF。已检查每槽 ID、CRC32、SHA256、填充和地址，并从已有源模型重建核对全包。

## 校验值

- bit SHA256：`{bitsha}`
- FPGA hex SHA256：`{hexsha}`
- 模型 bin SHA256：`{modelsha}`
- 完整合并 hex SHA256：`{mergedsha}`

解压后可运行 `python -B tools/verify_backup.py`。脚本只读本包文件，核对全部 SHA256 和合并镜像，不调用 EDA 或硬件。`SHA256SUMS.txt` 也可用于独立核对。

## 手动固化与验证

1. 解压备份并运行校验脚本，确认 PASS。
2. 在原有 Efinity Flash 编程流程中使用与板载 Flash 匹配的设备配置，选择 `flash/ArtFlow_osd_8styles_fullflash.hex`，起始地址 **0x000000**。
3. 手动执行写入及 Verify。这个合并文件已经包含模型区，不必再单独写模型。
4. 按板卡原有 Flash 启动设置断电重上电，检查 OSD、三个布局、OSD 开关、全部 8 风格及标签，并复查冻结/创意功能和原有 Wi-Fi 推流。

本包不含 ESP 固件更新，也不改变主工程或 FPGA 源码。原物理验收证据位于 `evidence/`：零资源重叠，最终 setup +0.313 ns / hold +0.026 ns，适用 CDC 检查通过。原 `FINAL_ACCEPTANCE` 中“未实板验收”是交付当时的历史状态；本包补充记录了用户随后确认 OSD 上板效果不错，未扩大为 Flash 冷启动验收。

本备份包含运行和固化需要的模型参数，不是整个训练数据/训练 checkpoint 工程备份。原始源码完整哈希清单随证据保留，完整工程仍在独立 OSD 候选目录。
'''
if __name__=='__main__':main()
