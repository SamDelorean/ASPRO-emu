#!/usr/bin/env python3
from pathlib import Path
import base64, hashlib, functools, json, sys
work, out = map(Path, sys.argv[1:3])
# Executed AS2K MV-03 builder, with private asset loading instead of embedded bytes.
# Source: Drive original job ID 1Ud5s5UaY6Z5E0hpQjcUC2ScBt0On0L2Q.
assets = Path(sys.argv[3])
source = {name: None for name in (
    "monitor.bin","overlay_a.bin","overlay_b.bin","overlay_c.bin")}
expected = {
  'monitor.bin': (172, '076c2244d1ce86cbc7ab79a7f5ecbabc7f1f42229f28f5dbb68b0c52422b8896'),
  'overlay_a.bin': (23, 'dfed5bb5f048913207e5be6aa28826fe01c1994ef1d1382661d7793c9470dad2'),
  'overlay_b.bin': (80, '72bdf88f63bab9e8b4bc204cc91e2ffbe9e89c8cc896409f913ef933438b2d4d'),
  'overlay_c.bin': (31, 'c1ebc01c7e274b0594402a44cfaf4ab28a1ebc6767371166d35d2cbe67d51be9'),
}
images = {}
for name, data in source.items():
    raw = (assets/name).read_bytes()
    size, digest = expected[name]
    assert (len(raw), hashlib.sha256(raw).hexdigest()) == (size, digest), name
    (work/name).write_bytes(raw)
    images[name] = raw
monitor = images['monitor.bin']
assert monitor[:3] == bytes.fromhex('7E 00 90')
assert monitor[0x90-0x40:0x94-0x40] == bytes.fromhex('0F 8E 00 FF')
assert monitor[0xDD-0x40:] == bytes.fromhex('36 C6 07 A6 00 8D EE 08 5A 26 F8 32 8D E7 39')
assert monitor[0xBE-0x40:0xC1-0x40] == bytes.fromhex('BD 00 40')
a, b, c = (images[f'overlay_{k}.bin'] for k in 'abc')
assert a[:15] == b[:15] == bytes.fromhex('CE 00 4F C6 08 A6 00 BD 00 E9 08 5A 26 F7 39')
assert a[15:23] == bytes.fromhex('A5 01 10 20 00 A0 01 35')
assert b[15:23] == bytes.fromhex('A5 01 10 20 00 B0 02 26')
assert b[23:] == b'\x00' * 57
assert c[:2] == bytes.fromhex('20 08')
assert c[2:10] == bytes.fromhex('A5 01 10 20 00 C0 03 57')
assert c[10:25] == bytes.fromhex('CE 00 42 C6 08 A6 00 BD 00 E9 08 5A 26 F7 39')
assert c[25:] == b'\x00' * 6

sequence = [('A',a),('B',b),('C',c),('B',b),('A',a)]
frames = []
for name, image in sequence:
    xor = functools.reduce(lambda left,right:left ^ right, image, 0)
    frame = bytes([len(image)]) + image + bytes([xor])
    frames.append(frame)
assert [len(x) for x in frames] == [25, 82, 33, 82, 25]
assert sum(map(len,frames)) == 247
assert all(frame[-1] == 0x07 for frame in frames[:2])  # A and B
assert b'\x00'*57 == frames[1][24:81]  # entire padded B region, 0x18..0x50
assert frames[1][-1] == 0x07 and frames[3] == frames[1]
# One global RX data register selector, 40-byte prefix for C and a special
# last-byte slot for B. No external SRAM is used for debugger staging.
# All numeric literals in MAME expressions are explicit hexadecimal.
hexnum = lambda n: f'0x{n:X}'
def packed(frame):
    prefix = frame[:40].ljust(40,b'\0')
    nums = [int.from_bytes(prefix[i:i+8], 'little') for i in range(0,40,8)]
    lastb = frame[-1] if len(frame) == 82 else 0
    return nums + [lastb]

def cmd(action):
    return '{ ' + ' ; '.join(action) + ' }'

lines = [
    f'load {work}/monitor.bin,0x0040,0xAC',
    'do temp0=0x0',
    'do temp1=0x0',
    'do temp2=0x0',
    'do temp3=0x0',
    'do temp4=0x0',
    'do temp5=0x0',
    'do temp6=0x0',
    'do temp7=0x0',
    'do temp8=0x0',  # TX count
    'do temp9=0x0',  # stage index, 0=setup A; 5=after fifth READY
]
# Install guarded stage transitions; do not let invalid state run forever.
for phase, ((name, _image), frame) in enumerate(zip(sequence, frames)):
    prev_rx = 0 if phase == 0 else len(frames[phase-1])
    prev_tx = 1+10*phase
    guard = f'temp9=={hexnum(phase)}&&temp8=={hexnum(prev_tx)}&&temp0=={hexnum(prev_rx)}&&sp==0xFF'
    setting = [f'do temp{i+1}={hexnum(v)}' for i,v in enumerate(packed(frame))]
    setting += [f'do temp7={hexnum(len(frame))}', 'do temp0=0x0',f'do temp9={hexnum(phase+1)}',
        f'logerror "MV03_STAGE N=%X LEN=%X TX=%X SP=%04X\\n",temp9,temp7,temp8,sp','g']
    lines.append(f'bp 0x0098,{guard},{cmd(setting)}')

# Last READY, after A5; do not execute or reset another overlay.
final_guard = 'temp9==0x5&&temp8==0x33&&temp0==0x19&&sp==0xFF'
lines.append(f'bp 0x0098,{final_guard},{cmd(["logerror \"MV03_COMPLETE STAGE=%X RX=%X TX=%X SP=%04X PC=%04X\\n\",temp9,temp0,temp8,sp,pc", "quit"])}')
lines.append('bp 0x0098,0x1,'+cmd(['logerror "MV03_STAGE_ERROR STAGE=%X RX=%X TX=%X SP=%04X\\n",temp9,temp0,temp8,sp','quit']))

lines.append('bp 0x00DA,temp8>=0x33,' + cmd(['logerror "MV03_TX_OVERRUN TX=%X\\n",temp8','quit']))
lines.append('bp 0x00DA,0x1,'+cmd(['logerror "MV03_TX N=%02X A=%02X STAGE=%X\\n",temp8,a,temp9','do temp8=temp8+0x1','g']))

rx_expr = [
   f'((temp0>={hexnum(i)}&&temp0<{hexnum(i+8)})*((temp{1+i//8}>>(0x8*(temp0&0x7)))&0xFF))'
   for i in range(0,40,8)
]
rx_expr += ['((temp0==0x51)*temp6)']
expr='|'.join(rx_expr)
lines.append('bp 0x00C9,temp0>=temp7,'+cmd(['logerror "MV03_RX_OVERRUN STAGE=%X INDEX=%X LIMIT=%X\\n",temp9,temp0,temp7','quit']))
lines.append('bp 0x00C9,0x1,'+cmd([f'do A=({expr})',
    'logerror "MV03_RX STAGE=%X INDEX=%02X A=%02X\\n",temp9,temp0,a',
    'do temp0=temp0+0x1','do PC=0x00D1','g']))
lines.append('bp 0x00C3,0x1,' + cmd(['logerror "MV03_LOAD_BAD STAGE=%X RX=%X\\n",temp9,temp0','quit']))
for phase in range(5):
    name=sequence[phase][0]
    outfile=out/f'overlay_window_{phase+1}_{name}.bin'
    actions=[f'save {outfile},0x0040,0x50',
        'logerror "MV03_LOAD_OK STAGE=%X RX=%X SP=%04X XOR=%02X CODE0=%02X\\n",temp9,temp0,sp,b@0x00EC,b@0x0040','g']
    lines.append(f'bp 0x00BE,temp9=={hexnum(phase+1)},{cmd(actions)}')
lines.append('bp 0x00BE,0x1,'+cmd(['logerror "MV03_LOAD_STAGE_ERROR STAGE=%X\\n",temp9','quit']))
lines.append('bp 0x00C1,0x1,'+cmd(['logerror "MV03_RTS STAGE=%X SP=%04X PC=%04X\\n",temp9,sp,pc','g']))
lines += ['do CCR=0x10','do SP=0x00FF','do PC=0x0040','g']
script='\n'.join(lines)+'\n'
(work/'mv03.mame').write_text(script)
(out/'mv03.mame').write_text(script)
expected_tx = bytes([0xA0])+b''.join(bytes([0xA1])+bytes.fromhex({'A':'A501102000A00135','B':'A501102000B00226','C':'A501102000C00357'}[name])+bytes([0xA0]) for name,_ in sequence)
assert len(expected_tx)==51
assert len(lines)==34, len(lines)
manifest = dict(source='SamDelorean/AS2K-probe-tools main',hashes={k:d for k,(_,d) in expected.items()},
    sequence=[{'name':name,'frame_len':len(frame),'frame_sha256':hashlib.sha256(frame).hexdigest(),'xor':frame[-1]} for (name,_),frame in zip(sequence,frames)],
    frame_hex=[frame.hex() for frame in frames], rx_total=sum(map(len,frames)),
    tx_expected=expected_tx.hex(), tx_total=len(expected_tx),
    emulation='debugger injected RX, not native SCI', reloads=5, reset_between=0)
(out/'fixture.json').write_text(json.dumps(manifest,indent=2)+'\n')
(out/'binary_identity.txt').write_text('\n'.join(f'{name}: {size} bytes; SHA256 {sha}' for name,(size,sha) in expected.items())+'\n')
(out/'static_preflight.txt').write_text('PASS asset hashes, original assembly invariants, 5 frames (25/82/33/82/25), 247 RX bytes, 51 TX bytes, exact A/B/C/B/A sequence, no monitor reset or recompile\n')
