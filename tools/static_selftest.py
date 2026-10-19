#!/usr/bin/env python3
"""Pruebas estáticas internas, no arrancan emulador ni requieren Commander."""
from __future__ import annotations
import pathlib
import tempfile
import zipfile
import json
import io
import unittest
from unittest import mock
import contextlib
import run_diag
import prepare_mame
import rom_audit
from rom_audit import audit_rom, audit_hex

def rec(n, addr, kind, payload):
    raw = bytes([n, addr>>8, addr&0xff, kind]) + payload
    return ":" + (raw + bytes([(-sum(raw)) & 0xff])).hex().upper()

def main():
    with tempfile.TemporaryDirectory() as d:
        d = pathlib.Path(d)
        rom = bytearray(b"\x01"*0x8000)
        rom[0x4000:0x4003] = b"\x8e\x00\xff"
        rom[-2:] = b"\xc0\x00"
        p = d/"synthetic.rom"
        p.write_bytes(rom)
        a = audit_rom(p)
        assert a["reset"] == "C000"
        assert a["reset_lds_00ff"]
        assert not a["expected_212"]
        assert p.read_bytes() == bytes(rom)
        h = d/"synthetic.hex"
        h.write_text(rec(3, 0, 0, b"\x8e\x00\xff")+"\n"+rec(0,0,1,b"")+"\n",encoding="ascii")
        b = audit_hex(h)
        assert b["unique_bytes"] == 3 and b["address_min"] == "00000000"
        bad = d/"bad.hex"
        bad.write_text(rec(3,0,0,b"\x8e\x00\xff")[:-2]+"00\n"+rec(0,0,1,b"")+"\n")
        try:
            audit_hex(bad)
        except ValueError:
            pass
        else:
            raise AssertionError("HEX checksum corrupto aceptado")
    print("STATIC_SELFTEST_PASS: ROM, RESET, invariancia, Intel HEX y rechazo checksum")

class AP02Checks(unittest.TestCase):
    def test_commands_are_bounded_and_do_not_mutate_cpu(self):
        script=run_diag.debugger_script()
        self.assertIn('bp C000,temp0<1',script)
        self.assertIn('bp C003,temp1<1',script)
        self.assertIn('wpset FFFE,2,r,temp2<c',script)
        self.assertIn('wpset 0008,1,w,temp7<c',script)
        self.assertIn('logerror "ASPRO_',script)
        self.assertNotIn('trace ',script)
        self.assertNotIn('do PC',script)
        self.assertEqual(script.count('; g }'),8)
        cmd=run_diag.command(pathlib.Path('/abs/asprodiag'),pathlib.Path('/private/run'),
                             pathlib.Path('/private/roms'),8,'none',[])
        self.assertEqual(cmd[1],'asmapro')
        self.assertIn('-noreadconfig',cmd)
        self.assertEqual(cmd[cmd.index('-debugger')+1],'none')
        self.assertIn('-autoboot_script',cmd)

    def test_capture_pending_is_explicit(self):
        with mock.patch.dict(run_diag.os.environ,{},clear=True), mock.patch('run_diag.shutil.which',return_value=None):
            self.assertEqual(run_diag.video_mode('auto'),('none',[]))
            with self.assertRaises(ValueError): run_diag.video_mode('soft')

    def test_source_ownership_and_hashes(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d)/'ASPRO'; tree=root/'build/mame';tree.mkdir(parents=True)
            driver=tree/'src/mame/skeleton/alphasma.cpp';driver.parent.mkdir(parents=True)
            lcd=tree/'src/devices/video/hd44780.cpp';lcd.parent.mkdir(parents=True)
            driver.write_text('synthetic source');lcd.write_text('synthetic lcd')
            (tree/'makefile').write_text('# fixture, never executed')
            (tree/prepare_mame.MARKER).write_text(json.dumps({'source_commit':prepare_mame.COMMIT,'destination':str(tree)}))
            with mock.patch.object(prepare_mame,'ROOT',root), \
                 mock.patch.object(prepare_mame,'DRIVER_SHA256',prepare_mame.digest(driver)), \
                 mock.patch.object(prepare_mame,'LCD_SHA256',prepare_mame.digest(lcd)):
                prepare_mame.validate_tree(tree)
                driver.write_text('changed synthetic source')
                with self.assertRaises(ValueError): prepare_mame.validate_tree(tree)
                with self.assertRaises(ValueError): prepare_mame.prepare(root/'build',root/'other')
            outside=pathlib.Path(d)/'AS2K';outside.mkdir()
            with mock.patch.object(prepare_mame,'ROOT',root):
                with self.assertRaises(ValueError): prepare_mame.validate_tree(outside)

    def test_strict_auditor_rejects_synthetic_identity(self):
        with tempfile.TemporaryDirectory() as d:
            p=pathlib.Path(d)/'synthetic.rom'; data=bytearray(32768)
            data[-2:]=b'\xc0\x00';data[0x4000:0x4003]=b'\x8e\x00\xff';p.write_bytes(data)
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(rom_audit.main(['--rom',str(p),'--require-212']),2)
            self.assertEqual(p.read_bytes(),data)

    def test_stage_cleanup_on_launch_failure_and_false_success(self):
        # subprocess and *input identity* are mocked only for orchestration
        # tests. No synthetic executable is created and no emulator is run.
        for launch in ['error','exit0_without_observations','timeout']:
            with tempfile.TemporaryDirectory() as d:
                root=pathlib.Path(d)/'ASPRO';root.mkdir()
                rom=root/'synthetic.rom';rom.write_bytes(b'synthetic ROM')
                lcd=root/'synthetic-cgrom';lcd.write_bytes(b'synthetic CGROM')
                fake_audit={'sha256':run_diag.sha(rom)}
                real_sha=run_diag.sha
                process=mock.Mock(pid=999999999)
                process.wait.return_value=0;process.returncode=0
                if launch=='timeout': process.wait.side_effect=[run_diag.subprocess.TimeoutExpired('mock-only',45),0]
                with mock.patch.object(run_diag,'ROOT',root), \
                     mock.patch.object(run_diag,'validate_inputs',return_value=(fake_audit,pathlib.Path('/NO_BINARY/asprodiag'))), \
                     mock.patch.object(run_diag,'KS0066_F05_SHA1',__import__('hashlib').sha1(lcd.read_bytes()).hexdigest()), \
                     mock.patch.object(run_diag,'sha',side_effect=lambda p:'mock-only' if p.name=='asprodiag' else real_sha(p)), \
                     mock.patch.object(run_diag.subprocess,'Popen',side_effect=OSError('synthetic spawn failure') if launch=='error' else None,return_value=process):
                    report=run_diag.run_session(rom,lcd,pathlib.Path('/NO_BINARY/asprodiag'),root/'private/runs',capture='none')
                self.assertFalse(report['functional_pass'])
                self.assertEqual(report['input_cleanup'],'COMPLETE')
                self.assertEqual(list(pathlib.Path(report['run_dir']).glob('roms-*')),[])
                self.assertEqual(report['status'],{'error':'PREPARATION_OR_LAUNCH_FAILED','exit0_without_observations':'INSTRUMENTATION_INCOMPLETE','timeout':'PROCESS_TIMEOUT'}[launch])
                self.assertEqual(report['evidence']['screenshots'],'PENDING')
                self.assertEqual(rom.read_bytes(),b'synthetic ROM')
                self.assertEqual(lcd.read_bytes(),b'synthetic CGROM')

    def test_incomplete_archive_cleanup_and_symlink_boundary(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d)/'ASPRO';root.mkdir()
            out=root/'private';out.mkdir()
            rom=root/'synthetic.rom';rom.write_bytes(b'synthetic')
            lcd=root/'cgrom';lcd.write_bytes(b'synthetic')
            with mock.patch.object(run_diag,'ROOT',root), \
                 mock.patch.object(run_diag,'validate_inputs',return_value=({'sha256':'fixture'},pathlib.Path('/NO_BINARY/asprodiag'))), \
                 mock.patch.object(run_diag,'sha',return_value='fixture'), \
                 mock.patch.object(run_diag.zipfile.ZipFile,'write',side_effect=OSError('staging failed')):
                report=run_diag.run_session(rom,lcd,pathlib.Path('/NO_BINARY/asprodiag'),out,capture='none')
            self.assertEqual(report['input_cleanup'],'COMPLETE')
            self.assertEqual(report['status'],'PREPARATION_OR_LAUNCH_FAILED')
            outside=pathlib.Path(d)/'reference';outside.mkdir()
            (root/'build').symlink_to(outside,target_is_directory=True)
            with mock.patch.object(prepare_mame,'ROOT',root):
                with self.assertRaises(ValueError): prepare_mame.validate_tree(outside/'mame')

if __name__ == "__main__":
    main()
    unittest.main(argv=['static_selftest'],verbosity=2)
