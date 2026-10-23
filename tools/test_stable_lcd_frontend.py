#!/usr/bin/env python3
"""ASPRO Stable LCD GTK regression without GTK, MAME, firmware or display.

Verify exact 240x36 monochrome RGB conversion, cached redraw policy and
no unused virtual Find key. Static GUI tests are not GUI execution.
"""
import ast
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / "stable" / "aspro_ui.py"


def main():
    src = SOURCE.read_text(encoding="utf-8")
    tree = ast.parse(src, filename=str(SOURCE))
    convert = next(node for node in tree.body
                   if isinstance(node, ast.FunctionDef) and node.name == "frame_to_rgb")
    namespace = {"W":240, "H":36, "BG":(138,146,148), "FG":(92,83,88)}
    compiled = ast.fix_missing_locations(ast.Module(body=[convert], type_ignores=[]))
    exec(compile(compiled, str(SOURCE), "exec"), namespace)
    frame_to_rgb = namespace["frame_to_rgb"]
    size = namespace["W"] * namespace["H"]
    bg = bytes(namespace["BG"])
    fg = bytes(namespace["FG"])

    assert frame_to_rgb(bytes(size)) == bg*size
    assert frame_to_rgb(bytes([1])*size) == fg*size
    alternate = bytes([0,1])*(size//2)
    assert frame_to_rgb(alternate) == (bg+fg)*(size//2)
    for damaged in (b"", bytes(size-1), bytes(size+1),
                    bytes([2])*size):
        try:
            frame_to_rgb(damaged)
        except ValueError:
            pass
        else:
            raise AssertionError("Accepted corrupted LCD framebuffer")
    print("ASPRO_STABLE_LCD_RGB_240X36_CONVERSION_PASS")

    window = next(node for node in tree.body
                  if isinstance(node, ast.ClassDef) and node.name == "ProWindow")
    poll = next(node for node in window.body
                if isinstance(node, ast.FunctionDef) and node.name == "poll_lcd")
    body = ast.get_source_segment(src, poll)
    assert "raw==self.frame_cache" in body
    assert "stat.st_mtime_ns==self.frame_stamp" in body
    assert "stat.st_size!=W*H" in body
    assert "rgb=frame_to_rgb(raw)" in body
    assert "next_pix=GdkPixbuf.Pixbuf.new_from_bytes(" in body
    assert "self.pix=next_pix" in body
    assert "self.frame_stamp=stat.st_mtime_ns" in body
    assert "W,H,W*3)" in body
    assert "self.lcd.queue_draw()" in body
    assert "for y in range(" not in body and "for x in range(" not in body
    assert '("Find","FIND")' not in src
    assert '("F1","F1")' in src and '("F8","F8")' in src
    assert '"KEYDOWN "+k' in src and '"KEYUP "+k' in src
    print("ASPRO_STABLE_LCD_CACHE_AND_GUI_KEY_CONTRACT_STATIC_PASS")


if __name__ == "__main__":
    main()
