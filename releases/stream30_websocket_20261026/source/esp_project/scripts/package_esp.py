from pathlib import Path
import subprocess,json,shutil,hashlib,re
R=Path(__file__).resolve().parents[1];E=R/'esp32';B=E/'build-xmc';D=R/'dist/esp32';D.mkdir(parents=True,exist_ok=True)
py='C:/Espressif/tools/python/v5.5.6/venv/Scripts/python.exe'
cfg=(E/'sdkconfig').read_text();expected=['CONFIG_IDF_TARGET="esp32s3"','CONFIG_ESP32S3_REV_MIN_FULL=0','CONFIG_ESPTOOLPY_FLASHSIZE_16MB=y','CONFIG_ESPTOOLPY_FLASHMODE_DIO=y','CONFIG_ESPTOOLPY_FLASHFREQ_40M=y','CONFIG_SPIRAM_MODE_OCT=y','CONFIG_SPIRAM_SPEED_40M=y','CONFIG_SPIRAM_IGNORE_NOTFOUND=y','CONFIG_HTTPD_WS_SUPPORT=y']
for v in expected:assert v in cfg,v
for v in ['CONFIG_SECURE_BOOT=y','CONFIG_SECURE_FLASH_ENC_ENABLED=y']:assert v not in cfg,v
args=json.loads((B/'flasher_args.json').read_text());assert args['flash_files']=={'0x0':'bootloader/bootloader.bin','0x10000':'artflow_wifi_stream.bin','0x8000':'partition_table/partition-table.bin'},args['flash_files']
# Fail closed if an old CMake cache builds the unpatched SDK component.
cc=json.loads((B/'bootloader/compile_commands.json').read_text())
boot_sources=[x['file'].replace(chr(92),'/') for x in cc if x['file'].replace(chr(92),'/').endswith('bootloader_flash/src/bootloader_flash.c')]
assert len(boot_sources)==1 and '/bootloader_components/bootloader_support/' in boot_sources[0],boot_sources
patched=E/'bootloader_components/bootloader_support/bootloader_flash/src/bootloader_flash.c'
assert hashlib.sha256(patched.read_bytes()).hexdigest()=='efe07577fd134f98f3a87ac48d0cae96431dae6fe1bd1113927d0294611c70dc'
files=['bootloader/bootloader.bin','partition_table/partition-table.bin','artflow_wifi_stream.bin','artflow_wifi_stream.elf','artflow_wifi_stream.map','flash_args','flasher_args.json']
for n in files:(D/n).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(B/n,D/n)
for n in ['sdkconfig','sdkconfig.defaults','partitions.csv']:shutil.copy2(E/n,D/n)
for name,n in [('app','artflow_wifi_stream.bin'),('bootloader','bootloader/bootloader.bin')]:
 p=subprocess.run([py,'-m','esptool','--chip','esp32s3','image_info',str(B/n)],capture_output=True,text=True,check=True)
 (R/'logs'/('esp-'+name+'-image-info.txt')).write_text(p.stdout)
 assert 'Validation Hash: ' in p.stdout and '(valid)' in p.stdout,p.stdout
result={'status':'PASS_OFFLINE_ONLY','hardware_tested':False,'idf':'5.5.6','gcc':'14.2.0 (esp-14.2.0_20260121)','esptool':'4.12.0','flash_addresses':args['flash_files'],'expected_config':expected,'files':{n:{'bytes':(D/n).stat().st_size,'sha256':hashlib.sha256((D/n).read_bytes()).hexdigest()} for n in files}}
(D/'manifest.json').write_text(json.dumps(result,indent=2));(R/'logs/esp-verification.json').write_text(json.dumps(result,indent=2));print(json.dumps({'status':result['status'],'app_bytes':(D/'artflow_wifi_stream.bin').stat().st_size,'flash_addresses':result['flash_addresses']},indent=2))

compat={'patched_sha256':hashlib.sha256(patched.read_bytes()).hexdigest(),'bootloader_compile_source':boot_sources[0],'stream_bootloader_sha256':hashlib.sha256((D/'bootloader/bootloader.bin').read_bytes()).hexdigest(),'reference_hardware_bootloader_sha256':'7fc05e044756c03adb76efade050602f6d8da90d4e5776378b5f7eeb38ea12fc'}
compat['exact_match_to_board_verified_bootloader']=compat['stream_bootloader_sha256']==compat['reference_hardware_bootloader_sha256']
for p in [D/'manifest.json',R/'logs/esp-verification.json']:
 d=json.loads(p.read_text());d['xmc_compatibility']=compat;d['hardware_scope']='Local exact-ID patch verified in separate baseline hardware task; stream app not flashed or hardware-tested';p.write_text(json.dumps(d,indent=2),encoding='utf-8')
for name,n in [('app','artflow_wifi_stream.bin'),('bootloader','bootloader/bootloader.bin')]:
 q=subprocess.run([py,'-m','esptool','--chip','esp32s3','image_info','--version','2',str(D/n)],capture_output=True,text=True,check=True).stdout
 for token in ['Flash size: 16MB','Flash freq: 40m','Flash mode: DIO','Minimal chip revision: v0.0','(valid)']:assert token in q,token
 (R/'logs'/('esp-'+name+'-image-info-v2.txt')).write_text(q)
print('Verified isolated XMC component, extended image parameters and actual partition addresses; no hardware accessed')
