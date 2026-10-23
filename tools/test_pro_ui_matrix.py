#!/usr/bin/env python3
"""Static contract: ASPRO GTK key injection must use the native Pro matrix.

No ROM, MAME runtime, hardware, Desktop Commander or private files required.
The canonical key matrix is INPUT_PORTS_START(alphasmart), not the AS2K matrix.
"""
from pathlib import Path
import re
import string

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "stable" / "alphasma.cpp"
DIAG_SOURCE = ROOT / "src" / "mame" / "skeleton" / "alphasma.cpp"
DIAG_OBSERVER = ROOT / "tools" / "ap03_startup_observe.lua"
ALIASES = {
    "RBRACKET": "CLOSEBRACE", "LBRACKET": "OPENBRACE",
    "PERIOD": "STOP", "SEMICOLON": "COLON",
    "LCTRL": "LCONTROL", "RCTRL": "RCONTROL",
    "COMMAND": "LWIN", "ENTER": "ENTER_PAD", "RETURN": "ENTER",
    "SEND": "F12", "CLEAR": "DEL", "PRINT": "F9",
    "SPELL": "F10", "GRAVE": "TILDE",
}
ENTRY = re.compile(r'\{\s*"([A-Z0-9_]+)"\s*,\s*(\d+)\s*,\s*0x([a-fA-F0-9]+)\s*\}')
PORT = re.compile(
    r'PORT_BIT\(0x([0-9a-fA-F]+),[^)]*\).*?PORT_CODE\(KEYCODE_([A-Z0-9_]+)\)'
)


def parse_ports(src):
    section = src.split("static INPUT_PORTS_START( alphasmart )", 1)[1].split(
        "INPUT_PORTS_END", 1)[0]
    row = None
    mapping = {}
    for line in section.splitlines():
        heading = re.search(r'PORT_START\("COL\.(\d+)"\)', line)
        if heading:
            row = int(heading.group(1))
            continue
        entry = PORT.search(line)
        if entry and row is not None:
            mask, name = entry.groups()
            if name in mapping:
                raise AssertionError("Ambiguous physical Pro key: " + name)
            mapping[name] = (row, int(mask, 16))
    return mapping


def parse_bridge(src):
    section = src.split("bool aspro_send_state::ui_key_location(", 1)[1].split(
        "void aspro_send_state::ui_key(", 1)[0]
    mapping = {}
    for name, row, mask in ENTRY.findall(section):
        if name in mapping:
            raise AssertionError("Duplicate virtual Pro key: " + name)
        mapping[name] = (int(row), int(mask, 16))
    return mapping


def main():
    src = SOURCE.read_text(encoding="utf-8")
    physical = parse_ports(src)
    virtual = parse_bridge(src)
    assert len(virtual) == 78, len(virtual)
    assert "FIND" not in virtual, "Pro has no documented physical FIND matrix position"
    for name, expected in virtual.items():
        physical_name = ALIASES.get(name, name)
        assert physical_name in physical, (name, physical_name)
        assert expected == physical[physical_name], (
            name, expected, physical[physical_name]
        )
    for name in string.ascii_uppercase + string.digits:
        assert name in virtual, "Missing alphanumeric: " + name
    for name in ("F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8",
                 "ENTER", "RETURN", "SPACE", "BACKSPACE", "ESC",
                 "SEND", "CLEAR", "LSHIFT", "RSHIFT"):
        assert name in virtual, "Missing control: " + name
    assert virtual["A"] == (14, 0x10)
    assert virtual["Z"] == (14, 0x80)
    assert virtual["F1"] == (13, 0x01)
    assert virtual["SEND"] == (7, 0x01)
    assert len(set(virtual.values())) == len(virtual), "Duplicate physical matrix contacts"
    assert "m_keyboard[i]->read() & m_ui_keyboard[i]" in src
    assert "m_ui_keyboard[col] &= ~mask" in src
    assert "m_ui_keyboard[col] |= mask" in src
    print("ASPRO_STABLE_PRO_UI_MATRIX_78_78_STATIC_PASS")

    # DIAG is the already-proven reference: it uses native MAME input ports,
    # not the GUI virtual-key overlay. Do not modify or rebuild its core.
    diag_src = DIAG_SOURCE.read_text(encoding="utf-8")
    diag_physical = parse_ports(diag_src)
    assert diag_physical == physical, "DIAG and Stable disagree on Pro ports"
    assert "data &= m_keyboard[i]->read();" in diag_src
    assert "m_keyboard[i]->read() & m_ui_keyboard[i]" not in diag_src
    assert "bool aspro_send_state::ui_key_location(" not in diag_src

    observer = DIAG_OBSERVER.read_text(encoding="utf-8")
    col, mask = diag_physical["A"]
    assert f'machine.ioport.ports[":COL.{col}"]' in observer
    assert f"field.mask == 0x{mask:02x}" in observer
    assert "key:set_value(1)" in observer
    assert "key:clear_value()" in observer
    assert "screen:pixels()" in observer
    print("ASPRO_DIAG_PRO_NATIVE_KEYBOARD_REFERENCE_STATIC_PASS")


if __name__ == "__main__":
    main()
