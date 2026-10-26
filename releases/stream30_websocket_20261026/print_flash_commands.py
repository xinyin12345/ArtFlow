import argparse
p=argparse.ArgumentParser(description='PRINT ONLY: no hardware, no subprocess')
p.add_argument('--mode',choices=['fresh','app-only'],required=True);p.add_argument('--port',required=True)
a=p.parse_args()
assert a.port.upper().startswith('COM') and a.port[3:].isdigit(), 'Enumerate and confirm actual COM port'
images=('0x0 bootloader/bootloader.bin 0x8000 partition_table/partition-table.bin ' if a.mode=='fresh' else '')+'0x10000 artflow_wifi_stream.bin'
base='& $py -m esptool --chip esp32s3 --port '+a.port+' --baud 115200 '
print('PRINT ONLY. Review disconnect/reconnect precautions in README. Run manually from esp32/.')
print(base+'--stub-version 2 write_flash --flash_mode dio --flash_freq 40m --flash_size 16MB '+images)
print(base+'--no-stub verify_flash '+images)
