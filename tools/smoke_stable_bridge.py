#!/usr/bin/env python3
"""ASPRO Stable ARM smoke: exercise its real GTK-to-MAME command bridge.

Runs a candidate *reduced Pro* MAME binary twice with identical synthetic
empty NVRAM. The second run injects ABC123 via the same KEY queue used by
GTK. Compares final native LCD pixels against the no-key baseline.
No GTK, personal NVRAM, installed binary replacement or ROM upload.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import zipfile

FW_SHA1 = "c3c6a421c9ced92db97431d04b4a3f09a39de716"
LCD_SHA1 = "0196e871584ee5d370856e7307c0f9d1466e3e51"
LUA = r"""
local machine = manager.machine
local screen = assert(machine.screens[":screen"])
local control = assert(os.getenv("ASPRO_UI_CONTROL_FILE"))
local typed = os.getenv("ASPRO_SMOKE_TYPE") == "1"
local frame = 0
local keys = { "A", "B", "C", "1", "2", "3" }
local function writefile(name, contents)
    local f = assert(io.open(name, "wb"))
    f:write(contents)
    f:close()
end
local function screenshot(name)
    local pix,w,h = screen:pixels()
    assert(w==240 and h==36, "LCD geometry unexpected")
    writefile(name .. ".rgba", pix)
end
emu.register_frame_done(function()
    frame = frame + 1
    if frame==690 then screenshot("before") end
    if typed then
        for i,key in ipairs(keys) do
            if frame==720+(i-1)*60 then
                local out=assert(io.open(control,"a"))
                out:write("KEY ",key,"\n")
                out:close()
                local marker=assert(io.open("keys.log","a"))
                marker:write(key,"\n")
                marker:close()
            end
        end
    end
    if frame==1130 then
        screenshot("after")
        writefile("complete.marker", tostring(frame))
    end
end, "aspro_stable_bridge_smoke")
"""


def validate_asset(path: Path, length: int, digest: str) -> None:
    if not path.is_file() or path.stat().st_size != length:
        raise RuntimeError("Private ROM preflight failed: " + path.name)
    if hashlib.sha1(path.read_bytes()).hexdigest() != digest:
        raise RuntimeError("Private ROM identity mismatch: " + path.name)


def trial(binary: Path, root: Path, zips: Path, mode: str, timeout: int) -> dict:
    directory = root / mode
    directory.mkdir(mode=0o700)
    for name in ("nvram", "cfg", "states", "snap"):
        (directory / name).mkdir(mode=0o700)
    (directory / "command.queue").write_bytes(b"")
    (directory / "events.queue").write_bytes(b"")
    (directory / "smoke.lua").write_text(LUA, encoding="utf-8")
    env = dict(os.environ)
    env.update(ASPRO_UI_CONTROL_FILE=str(directory / "command.queue"),
               ASPRO_UI_EVENT_FILE=str(directory / "events.queue"),
               ASPRO_UI_FRAME_FILE=str(directory / "lcd.bin"),
               ASPRO_SMOKE_TYPE="1" if mode == "typed" else "0",
               SDL_VIDEODRIVER="dummy")
    cmd = [str(binary), "asmapro", "-noreadconfig", "-rompath", str(zips),
           "-cfg_directory", str(directory / "cfg"),
           "-nvram_directory", str(directory / "nvram"),
           "-state_directory", str(directory / "states"),
           "-snapshot_directory", str(directory / "snap"),
           "-autoboot_script", str(directory / "smoke.lua"),
           "-autoboot_delay", "0", "-seconds_to_run", "24",
           "-sound", "none", "-video", "none", "-nothrottle",
           "-skip_gameinfo"]
    before = time.monotonic()
    with (directory / "core.log").open("wb") as log:
        try:
            finished = subprocess.run(cmd, cwd=directory, env=env,
                                      stdout=log, stderr=subprocess.STDOUT,
                                      timeout=timeout, check=False)
        except subprocess.TimeoutExpired as exc:
            raise RuntimeError("Stable bridge smoke timed out: " + mode) from exc
    if finished.returncode != 0:
        raise RuntimeError("Stable MAME exit failure %s in %s" %
                           (finished.returncode, mode))
    marker = directory / "complete.marker"
    if not marker.is_file() or marker.read_text() != "1130":
        raise RuntimeError("LCD observer did not complete in " + mode)
    before_pixels = (directory / "before.rgba").read_bytes()
    after_pixels = (directory / "after.rgba").read_bytes()
    if len(before_pixels) != 240*36*4 or len(after_pixels) != 240*36*4:
        raise RuntimeError("Unexpected native LCD RGBA size in " + mode)
    if not (directory / "lcd.bin").is_file() or (directory / "lcd.bin").stat().st_size != 240*36:
        raise RuntimeError("Core GUI framebuffer missing in " + mode)
    events = (directory / "events.queue").read_text(errors="replace")
    if "Unrecognized Pro key" in events or "Unknown UI command" in events:
        raise RuntimeError("Core bridge rejected a GTK key command in " + mode)
    if mode == "typed" and (directory / "keys.log").read_text().splitlines() != list("ABC123"):
        raise RuntimeError("Command sequence incomplete")
    return {
        "mode": mode, "wall_s": round(time.monotonic()-before, 3),
        "before_sha256": hashlib.sha256(before_pixels).hexdigest(),
        "after_sha256": hashlib.sha256(after_pixels).hexdigest(),
        "lcd_rgba": len(after_pixels), "frame_bytes": 240*36,
        "image": after_pixels,
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--binary", required=True, type=Path)
    p.add_argument("--private", required=True, type=Path)
    p.add_argument("--timeout", type=int, default=240)
    args = p.parse_args()
    binary = args.binary.resolve(strict=True)
    if not binary.is_file() or not os.access(binary, os.X_OK):
        raise RuntimeError("MAME candidate missing or non-executable")
    priv = args.private.resolve(strict=True)
    fw = priv / "roms/firmware.bin"
    lcd = priv / "roms/ks0066_f05.bin"
    validate_asset(fw, 32768, FW_SHA1)
    validate_asset(lcd, 4096, LCD_SHA1)
    with tempfile.TemporaryDirectory(prefix="aspro-bridge-smoke-") as temp:
        root = Path(temp)
        zips = root / "roms"
        zips.mkdir()
        for name, source, member in (
            ("asmapro.zip", fw, "alphasmartpro212.rom"),
            ("ks0066.zip", lcd, "ks0066_f05.bin"),
        ):
            with zipfile.ZipFile(zips/name, "w", zipfile.ZIP_STORED) as dest:
                dest.write(source, arcname=member)
        control = trial(binary, root, zips, "control", args.timeout)
        print("ASPRO_STABLE_BRIDGE_CONTROL_PASS wall_s=" + str(control["wall_s"]), flush=True)
        typed = trial(binary, root, zips, "typed", args.timeout)
        print("ASPRO_STABLE_BRIDGE_ABC123_INJECTED_PASS wall_s=" + str(typed["wall_s"]), flush=True)
        if control["before_sha256"] != typed["before_sha256"]:
            raise RuntimeError("Baseline screens differed before keyboard injection")
        pixels = sum(a != b for a,b in zip(control["image"], typed["image"]))
        if pixels == 0:
            raise RuntimeError("ABC123 key bridge produced no LCD pixel change")
        print("ASPRO_STABLE_BRIDGE_LCD_CHANGED_PASS diff_rgba_bytes=" + str(pixels), flush=True)
        print("ASPRO_STABLE_BRIDGE_SMOKE_PASS", flush=True)


if __name__ == "__main__":
    main()
