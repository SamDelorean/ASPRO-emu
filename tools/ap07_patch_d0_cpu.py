# license:BSD-3-Clause
# copyright-holders:Sandro Ronco
"""Bounded ASPRO adaptation from SamDelorean/mame-as3k
 c4e48388ca620472643110db2941ce70aa5f3c07, D0 CPU source Git blobs
 a7248de563b572aa586b28a8493ddd087dfbb400 / 375c6e1c2a2f74912661da8dc659e23dfcb44f02.
ASPRO-only D0 CPU post-transfer bootstrap. The independent ASPRO MAME copy
keeps patched files and pristine backups, while the MAME donor is read-only.
"""

DONOR_ENTRY = r'''void mc68hc11_cpu_device::diagnostic_bootstrap_entry(const uint8_t *data, uint16_t size, uint16_t address)
{
	const uint32_t ram_start = 0x0040;
	const uint32_t ram_end = ram_start + m_internal_ram_size;

	if (address < ram_start || uint32_t(address) + size > ram_end)
		fatalerror("HC11 diagnostic bootstrap image $%04X + %u exceeds internal RAM", address, size);

	for (uint16_t i = 0; i < size; i++)
		m_program.write_byte(address + i, data[i]);

	// device_reset() leaves RESET pending and the CPU in reset wait state.
	// A completed bootstrap-ROM transfer has already consumed that reset path,
	// so diagnostic execution starts directly at the downloaded RAM entry.
	m_irq_state = 0;
	m_irq_asserted = false;
	m_wait_state = 0;
	m_stop_state = 0;
	m_ccr = CC_X | CC_I | CC_S;
	m_pc = address;
	m_ppc = address;
}


'''

DONOR_HPRIO = r'''uint8_t mc68hc11d0_device::hprio_r()
{
	// Preserve the pre-patch unmapped-read behavior for normal D0 users.
	return m_diag_bootstrap ? m_hprio : 0xff;
}


void mc68hc11d0_device::hprio_w(uint8_t data)
{
	// This is deliberately a bounded diagnostic subset, not complete D0
	// HPRIO emulation. Outside diagnostic bootstrap mode it is inert.
	if (!m_diag_bootstrap || !(m_hprio & 0x40))
		return;

	const uint8_t old = m_hprio;

	// MDA may change while SMOD=1.
	m_hprio = (m_hprio & ~0x20) | (data & 0x20);

	// RBOOT and SMOD may be cleared, but never reasserted until RESET.
	if (!(data & 0x80))
		m_hprio &= ~0x80;
	if (!(data & 0x40))
		m_hprio &= ~0x40;

	logerror("HC11D0 HPRIO %02X -> %02X\n", old, m_hprio);
}


void mc68hc11d0_device::diag_bootstrap_load(const uint8_t *data, uint16_t size, uint16_t address)
{
	if (!m_diag_bootstrap)
		fatalerror("HC11D0 diagnostic bootstrap load requested while disabled");

	m_hprio = 0xc0; // RBOOT=1, SMOD=1, MDA=0
	m_config |= 0x04; // NOCOP=1 in special mode
	diagnostic_bootstrap_entry(data, size, address);
}

'''

BASE_WAIT = r'''
void mc68hc11_cpu_device::diagnostic_bootstrap_wait_for_serial()
{
	// A D0 special-mode ROM is processing SCI. Pause instruction fetch
	// without accessing base-private CPU state from the D0 subclass.
	m_irq_state = 0;
	m_irq_asserted = false;
	m_wait_state = 1;
	m_stop_state = 0;
	m_ccr = CC_X | CC_I | CC_S;
}

'''

DONOR_SCI = r'''
void mc68hc11d0_device::diag_bootstrap_begin()
{
	if (!m_diag_bootstrap)
		fatalerror("HC11D0 SCI bootstrap started in normal ROM mode");
	m_hprio = 0xc0;
	m_config |= 0x04;
	m_diag_sci_count = 0;
	m_diag_sci_echo_count = 0;
	m_diag_sci_echo_last = 0;
	m_diag_sci_shift = 0;
	m_diag_sci_bit = 0;
	m_diag_sci_idle = 0;
	m_diag_sci_receiving = false;
	m_diag_sci_synced = false;
	m_diag_sci_done = false;
	m_diag_sci_bad = false;
	// CPU execution-control fields are private to the BASE class.
	// Use its encapsulated WAIT entry, leaving the AS2K loader untouched.
	diagnostic_bootstrap_wait_for_serial();
	logerror("ASPRO_AP07_SCI_BOOT_BEGIN hprio=C0 baud=7812.5\n");
}

void mc68hc11d0_device::diag_bootstrap_rx_bit(bool rxd)
{
	if (!m_diag_bootstrap || m_diag_sci_done || m_diag_sci_bad)
		return;
	if (!m_diag_sci_receiving)
	{
		if (!rxd)
		{
			m_diag_sci_receiving = true;
			m_diag_sci_bit = 0;
			m_diag_sci_shift = 0;
			m_diag_sci_idle = 0;
		}
		else if (m_diag_sci_synced && m_diag_sci_count &&
				++m_diag_sci_idle >= 40)
		{
			m_diag_sci_done = true;
			logerror("ASPRO_AP07_SCI_TRANSFER_COMPLETE bytes=%u echoes=%u idle_bits=%u\n",
				unsigned(m_diag_sci_count), unsigned(m_diag_sci_echo_count),
				unsigned(m_diag_sci_idle));
			diag_bootstrap_load(m_diag_sci_ram, m_diag_sci_count, 0x0040);
		}
		return;
	}
	if (m_diag_sci_bit < 8)
	{
		if (rxd)
			m_diag_sci_shift |= uint8_t(1U << m_diag_sci_bit);
		++m_diag_sci_bit;
		return;
	}
	m_diag_sci_receiving = false;
	if (!rxd)
	{
		m_diag_sci_bad = true;
		logerror("ASPRO_AP07_SCI_FRAME_ERROR\n");
		return;
	}
	const uint8_t value = m_diag_sci_shift;
	if (!m_diag_sci_synced)
	{
		if (value != 0xff)
		{
			m_diag_sci_bad = true;
			logerror("ASPRO_AP07_SCI_SYNC_ERROR byte=%02X\n", unsigned(value));
			return;
		}
		m_diag_sci_synced = true;
		logerror("ASPRO_AP07_SCI_SYNC_OK ff\n");
	}
	else
	{
		if (m_diag_sci_count == 192)
		{
			m_diag_sci_bad = true;
			logerror("ASPRO_AP07_SCI_OVERFLOW\n");
			return;
		}
		m_diag_sci_ram[m_diag_sci_count++] = value;
		logerror("ASPRO_AP07_SCI_RX index=%u byte=%02X\n",
			unsigned(m_diag_sci_count - 1), unsigned(value));
	}
	m_diag_sci_echo_last = value;
	++m_diag_sci_echo_count;
	logerror("ASPRO_AP07_SCI_ECHO index=%u byte=%02X\n",
		unsigned(m_diag_sci_echo_count - 1), unsigned(value));
}

'''

DONOR_D0 = r'''	// Bounded diagnostic bootstrap support for the AS2000 takeover tests.
	// Normal D0 users are unchanged unless this mode is explicitly enabled.
	void set_diag_bootstrap(bool enable) { m_diag_bootstrap = enable; }
	bool diag_bootstrap_enabled() const { return m_diag_bootstrap; }
	uint8_t hprio() const { return m_hprio; }
	void diag_bootstrap_load(const uint8_t *data, uint16_t size, uint16_t address = 0x0040);
	void diag_bootstrap_begin();
	void diag_bootstrap_rx_bit(bool rxd);
	bool diag_bootstrap_done() const { return m_diag_sci_done; }
	bool diag_bootstrap_error() const { return m_diag_sci_bad; }
	uint16_t diag_bootstrap_rx_count() const { return m_diag_sci_count; }
	uint16_t diag_bootstrap_echo_count() const { return m_diag_sci_echo_count; }
	uint8_t diag_bootstrap_echo_last() const { return m_diag_sci_echo_last; }


protected:
	virtual void device_start() override ATTR_COLD;
	virtual void device_reset() override ATTR_COLD;

	virtual void mc68hc11_reg_map(memory_view::memory_view_entry &block, offs_t base) override;

private:
	uint8_t reg01_r();
	uint8_t hprio_r();
	void hprio_w(uint8_t data);

	bool m_diag_bootstrap;
	uint8_t m_hprio;
	uint8_t m_diag_sci_ram[192]{};
	uint16_t m_diag_sci_count = 0;
	uint16_t m_diag_sci_echo_count = 0;
	uint8_t m_diag_sci_echo_last = 0;
	uint8_t m_diag_sci_shift = 0;
	uint8_t m_diag_sci_bit = 0;
	uint8_t m_diag_sci_idle = 0;
	bool m_diag_sci_receiving = false;
	bool m_diag_sci_synced = false;
	bool m_diag_sci_done = false;
	bool m_diag_sci_bad = false;
};
'''

def patch_bootstrap(h, c, replace, donor):
    if donor:
        return h, c  # The recognized pinned CPU already supports the bootstrap.
    if "diagnostic_bootstrap_entry" in h or "diag_bootstrap_load" in c:
        raise SystemExit("BLOCKED_CPU_PATCH_CONFLICT: partial previous adaptation")
    h = replace(h, "\tvoid set_irq_state(uint8_t irqn, bool state);",
                "\tvoid set_irq_state(uint8_t irqn, bool state);\n\tvoid diagnostic_bootstrap_entry(const uint8_t *data, uint16_t size, uint16_t address);\n\tvoid diagnostic_bootstrap_wait_for_serial();", "bootstrap entry")
    start = h.index("\nprotected:", h.index("class mc68hc11d0_device :"))
    end = h.index("\nclass mc68hc11e1_device", start)
    h = h[:start] + "\n" + DONOR_D0 + h[end:]
    c = replace(c, "clock, 192, 64, 0, 0, 0x00, 0x06, 0x3b)\n{",
                "clock, 192, 64, 0, 0, 0x00, 0x06, 0x3b)\n\t, m_diag_bootstrap(false)\n\t, m_hprio(0x00)\n{", "D0 constructor")
    anchor = "\tblock(base + 0x3d, base + 0x3d).rw(FUNC(mc68hc11d0_device::init_r), FUNC(mc68hc11d0_device::init_w)); // INIT"
    c = replace(c, anchor,
                "\tblock(base + 0x3c, base + 0x3c).rw(FUNC(mc68hc11d0_device::hprio_r), FUNC(mc68hc11d0_device::hprio_w)); // HPRIO\n" + anchor, "D0 HPRIO")
    c = replace(c, "void mc68hc11d0_device::device_reset()",
                "void mc68hc11d0_device::device_start()\n{\n\tmc68hc11_cpu_device::device_start();\n\tsave_item(NAME(m_hprio));\n\tsave_item(NAME(m_diag_bootstrap));\n\tsave_item(NAME(m_diag_sci_ram));\n\tsave_item(NAME(m_diag_sci_count));\n\tsave_item(NAME(m_diag_sci_echo_count));\n\tsave_item(NAME(m_diag_sci_echo_last));\n\tsave_item(NAME(m_diag_sci_shift));\n\tsave_item(NAME(m_diag_sci_bit));\n\tsave_item(NAME(m_diag_sci_idle));\n\tsave_item(NAME(m_diag_sci_receiving));\n\tsave_item(NAME(m_diag_sci_synced));\n\tsave_item(NAME(m_diag_sci_done));\n\tsave_item(NAME(m_diag_sci_bad));\n}\n\nvoid mc68hc11d0_device::device_reset()", "D0 start")
    c = replace(c, "\tm_port_data[0] &= 0x8f;\n\tddr_w<0>(0x70);\n}",
                "\tm_port_data[0] &= 0x8f;\n\tddr_w<0>(0x70);\n\tm_hprio = m_diag_bootstrap ? 0xc0 : 0x00;\n}", "D0 reset")
    c = replace(c, "void mc68hc11e1_device::device_reset()",
                DONOR_HPRIO + DONOR_SCI + "void mc68hc11e1_device::device_reset()", "HPRIO implementation")
    c = replace(c, "void mc68hc11_cpu_device::execute_set_input(",
                DONOR_ENTRY + BASE_WAIT + "void mc68hc11_cpu_device::execute_set_input(", "bootstrap execution")
    return h, c

def extend_existing_d0(h, c, replace):
    """Reuse the already-patched AS2K D0 CPU exported into ASPRO.
    Never reinstall HPRIO, RAM loader, or PC hook; add SCI RX only.
    """
    begin=h.index("class mc68hc11d0_device :")
    end=h.index("\nclass mc68hc11e1_device",begin)
    d0=h[begin:end]
    required=(
        "void diag_bootstrap_load(", "void set_diag_bootstrap(bool",
        "uint8_t m_hprio;", "bool m_diag_bootstrap"
    )
    if not all(key in d0 for key in required):
        raise ValueError("AS2K donor D0 public ABI is not recognized")
    # AP06's pinned AS2K MAME copy already exports this public ABI.
    # Do not require internal helper spelling or debug-log literals: these
    # differ among known donor revisions and are not needed by SCI.
    if "diag_bootstrap_load(" not in c:
        raise ValueError("D0 loader is not implemented in CPU source")
    api=(
        "\tvoid diag_bootstrap_begin();\n"
        "\tvoid diag_bootstrap_rx_bit(bool rxd);\n"
        "\tbool diag_bootstrap_done() const { return m_diag_sci_done; }\n"
        "\tbool diag_bootstrap_error() const { return m_diag_sci_bad; }\n"
        "\tuint16_t diag_bootstrap_rx_count() const { return m_diag_sci_count; }\n"
        "\tuint16_t diag_bootstrap_echo_count() const { return m_diag_sci_echo_count; }\n"
        "\tuint8_t diag_bootstrap_echo_last() const { return m_diag_sci_echo_last; }\n"
    )
    old="\tvoid diag_bootstrap_load(const uint8_t *data, uint16_t size, uint16_t address = 0x0040);"
    h=replace(h,old,old+"\n"+api,"existing D0 public SCI methods")
    fields=(
        "\tuint8_t m_diag_sci_ram[192]{};\n"
        "\tuint16_t m_diag_sci_count = 0;\n"
        "\tuint16_t m_diag_sci_echo_count = 0;\n"
        "\tuint8_t m_diag_sci_echo_last = 0;\n"
        "\tuint8_t m_diag_sci_shift = 0;\n"
        "\tuint8_t m_diag_sci_bit = 0;\n"
        "\tuint8_t m_diag_sci_idle = 0;\n"
        "\tbool m_diag_sci_receiving = false;\n"
        "\tbool m_diag_sci_synced = false;\n"
        "\tbool m_diag_sci_done = false;\n"
        "\tbool m_diag_sci_bad = false;\n"
    )
    h=replace(h,"\tuint8_t m_hprio;","\tuint8_t m_hprio;\n"+fields,
              "existing D0 private SCI state")
    c=replace(c,"void mc68hc11e1_device::device_reset()",
              DONOR_SCI+"void mc68hc11e1_device::device_reset()",
              "existing D0 SCI receiver implementation")
    h=replace(h,
              "\tvoid diagnostic_bootstrap_entry(const uint8_t *data, uint16_t size, uint16_t address);",
              "\tvoid diagnostic_bootstrap_entry(const uint8_t *data, uint16_t size, uint16_t address);\n\tvoid diagnostic_bootstrap_wait_for_serial();",
              "existing AS2K base diagnostic ABI")
    c=replace(c,"void mc68hc11_cpu_device::execute_set_input(",
              BASE_WAIT+"void mc68hc11_cpu_device::execute_set_input(",
              "existing AS2K base CPU WAIT handler")
    savers="".join("\n\tsave_item(NAME("+n+"));" for n in (
        "m_diag_sci_ram","m_diag_sci_count","m_diag_sci_echo_count",
        "m_diag_sci_echo_last","m_diag_sci_shift","m_diag_sci_bit",
        "m_diag_sci_idle","m_diag_sci_receiving","m_diag_sci_synced",
        "m_diag_sci_done","m_diag_sci_bad"))
    if "\tsave_item(NAME(m_diag_bootstrap));" in c:
        c=replace(c,"\tsave_item(NAME(m_diag_bootstrap));",
                  "\tsave_item(NAME(m_diag_bootstrap));"+savers,
                  "existing D0 save state")
    # Some AS2K donor revisions do not expose a dedicated D0 save-state
    # override. The AP07 campaign uses no save states; keep their original
    # lifecycle unchanged rather than introducing a second device_start().
    return h,c

# ASPRO AP-07: apply AS2K's bounded D0 post-transfer bootstrap patch ONLY
# to independently exported ASPRO-emu/build/send-mame sources.
if __name__ == "__main__":
    import argparse
    import hashlib
    import json
    from pathlib import Path
    import os

    p = argparse.ArgumentParser(description="Apply D0 POST-SCI diagnostic patch in ASPRO only")
    p.add_argument("--tree", required=True, type=Path)
    a = p.parse_args()
    tree=a.tree.absolute()
    owned=(Path(__file__).resolve().parents[1]/"build/send-mame").absolute()
    if tree != owned or tree.is_symlink() or (owned.parent).is_symlink():
        p.error("only ASPRO-owned build/send-mame may be modified")
    hpath=tree/"src/devices/cpu/mc68hc11/mc68hc11.h"
    cpath=tree/"src/devices/cpu/mc68hc11/mc68hc11.cpp"
    if any(x.is_symlink() for x in [hpath,cpath]) or not all(x.is_file() for x in [hpath,cpath]):
        p.error("missing or symlinked independent CPU files")
    h=hpath.read_text(); c=cpath.read_text()
    def blob(v):
        b=v.encode("utf-8")
        return hashlib.sha1(b"blob "+str(len(b)).encode()+b"\0"+b).hexdigest()
    source_ids=(blob(h),blob(c))
    marker_path=tree/".ap07-cpu-marker.json"
    def strict_replace(source, old, new, label):
        if source.count(old)!=1:
            raise ValueError(label+" anchor count "+str(source.count(old)))
        return source.replace(old,new,1)

    marker_path=tree/".ap07-cpu-marker.json"
    has_bootloader="diag_bootstrap_load" in h and "diag_bootstrap_load" in c
    has_sci="diag_bootstrap_rx_bit" in h or "diag_bootstrap_rx_bit" in c
    if has_sci:
        if (not marker_path.is_file()
            or "diag_bootstrap_rx_bit" not in h
            or "diag_bootstrap_rx_bit" not in c):
            p.error("partial/unmarked SCI patch")
        marker=json.loads(marker_path.read_text())
        if (marker.get("feature")!="AP07_SCI_8N1_D0P"
            or marker.get("patched_blobs")!=list(source_ids)
            or marker.get("authentic_sci") is not False):
            p.error("modified CPU files diverge from approved ASPRO SCI hashes")
        print(json.dumps({"status":"SCI_PATCH_ALREADY_VERIFIED","sha":source_ids}))
        raise SystemExit(0)
    if marker_path.exists():
        p.error("stale AP07 CPU marker without SCI")
    existing_mame_marker=json.loads((tree/".aspro-send-source.json").read_text())
    if (existing_mame_marker.get("feature")!="AP06_PC_SEND"
        or existing_mame_marker.get("canonical_upstream")
            !="c4e48388ca620472643110db2941ce70aa5f3c07"):
        p.error("independent AP06 MAME source identity not verified")
    if has_bootloader:
        # The T640 MAME donor *already* includes the tested AS2K
        # post-transfer entry. Reuse it, add only the D0 SCI path.
        if existing_mame_marker.get("source_head")!="a4b99b1a700a1d70b93a798fe7833e4cae28c137":
            p.error("unexpected existing D0 donor revision")
        new_h,new_c=extend_existing_d0(h,c,strict_replace)
        model="REUSED_AS2K_D0_ADDED_SCI"
    else:
        expected_h="a7248de563b572aa586b28a8493ddd087dfbb400"
        expected_c="375c6e1c2a2f74912661da8dc659e23dfcb44f02"
        if source_ids != (expected_h,expected_c):
            p.error("unrecognized fresh D0 CPU source: "+str(source_ids))
        new_h,new_c=patch_bootstrap(h,c,strict_replace,False)
        model="PINNED_UNPATCHED_D0_PLUS_SCI"
    if new_h==h or new_c==c:
        p.error("no CPU changes")
    # Keep independent originals for rollback; never touch donor tree.
    backup=tree/".ap07-cpu-original"
    backup.mkdir(exist_ok=True)
    for target,original in [(backup/"mc68hc11.h",h),(backup/"mc68hc11.cpp",c)]:
        if target.exists() and target.read_text()!=original:
            p.error("backup conflict")
        if not target.exists():
            target.write_text(original)
    hpath.write_text(new_h); cpath.write_text(new_c)
    marker={"feature":"AP07_SCI_8N1_D0P","source_blobs":list(source_ids),
            "patched_blobs":[blob(new_h),blob(new_c)],
            "cpu_patched":True,"model":model,"authentic_sci":False,"uart_8n1_model":True}
    (tree/".ap07-cpu-marker.json").write_text(json.dumps(marker,indent=2)+"\n")
    print(json.dumps(marker))
