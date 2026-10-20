# license:BSD-3-Clause
# copyright-holders:Sandro Ronco
"""Bounded ASPRO adaptation from SamDelorean/mame-as3k
 ae2f3ed97d3230e48fb33386230c27434fa94a25, CPU blobs
 18c27d796c257d79a320639e583cfa52c5a17807 / 25161fb8c9900268b0f37a390dfe695a8f9c94dc.
ASPRO-only CPU bootstrap post-transfer model; no payload image is bundled. Called in-memory by the existing PAI patcher;
its build wrapper restores both CPU files on exit.
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

DONOR_D0 = r'''	// Bounded diagnostic bootstrap support for the AS2000 takeover tests.
	// Normal D0 users are unchanged unless this mode is explicitly enabled.
	void set_diag_bootstrap(bool enable) { m_diag_bootstrap = enable; }
	bool diag_bootstrap_enabled() const { return m_diag_bootstrap; }
	uint8_t hprio() const { return m_hprio; }
	void diag_bootstrap_load(const uint8_t *data, uint16_t size, uint16_t address = 0x0040);

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
};
'''

def patch_bootstrap(h, c, replace, donor):
    if donor:
        return h, c  # The recognized pinned CPU already supports the bootstrap.
    if "diagnostic_bootstrap_entry" in h or "diag_bootstrap_load" in c:
        raise SystemExit("BLOCKED_CPU_PATCH_CONFLICT: partial previous adaptation")
    h = replace(h, "\tvoid set_irq_state(uint8_t irqn, bool state);",
                "\tvoid set_irq_state(uint8_t irqn, bool state);\n\tvoid diagnostic_bootstrap_entry(const uint8_t *data, uint16_t size, uint16_t address);", "bootstrap entry")
    start = h.index("\nprotected:", h.index("class mc68hc11d0_device :"))
    end = h.index("\nclass mc68hc11e1_device", start)
    h = h[:start] + "\n" + DONOR_D0 + h[end:]
    c = replace(c, "clock, 192, 64, 0, 0, 0x00, 0x06, 0x3b)\n{",
                "clock, 192, 64, 0, 0, 0x00, 0x06, 0x3b)\n\t, m_diag_bootstrap(false)\n\t, m_hprio(0x00)\n{", "D0 constructor")
    anchor = "\tblock(base + 0x3d, base + 0x3d).rw(FUNC(mc68hc11d0_device::init_r), FUNC(mc68hc11d0_device::init_w)); // INIT"
    c = replace(c, anchor,
                "\tblock(base + 0x3c, base + 0x3c).rw(FUNC(mc68hc11d0_device::hprio_r), FUNC(mc68hc11d0_device::hprio_w)); // HPRIO\n" + anchor, "D0 HPRIO")
    c = replace(c, "void mc68hc11d0_device::device_reset()",
                "void mc68hc11d0_device::device_start()\n{\n\tmc68hc11_cpu_device::device_start();\n\tsave_item(NAME(m_hprio));\n\tsave_item(NAME(m_diag_bootstrap));\n}\n\nvoid mc68hc11d0_device::device_reset()", "D0 start")
    c = replace(c, "\tm_port_data[0] &= 0x8f;\n\tddr_w<0>(0x70);\n}",
                "\tm_port_data[0] &= 0x8f;\n\tddr_w<0>(0x70);\n\tm_hprio = m_diag_bootstrap ? 0xc0 : 0x00;\n}", "D0 reset")
    c = replace(c, "void mc68hc11e1_device::device_reset()",
                DONOR_HPRIO + "void mc68hc11e1_device::device_reset()", "HPRIO implementation")
    c = replace(c, "void mc68hc11_cpu_device::execute_set_input(",
                DONOR_ENTRY + "void mc68hc11_cpu_device::execute_set_input(", "bootstrap execution")
    return h, c

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
    if "diag_bootstrap_load" in h or "diag_bootstrap_load" in c:
        if "diag_bootstrap_load" in h and "diag_bootstrap_load" in c and "HC11D0 HPRIO" in c:
            print(json.dumps({"status":"ALREADY_PATCHED","source_ids":source_ids}))
            raise SystemExit(0)
        p.error("partial/unrecognized CPU bootstrap patch")
    expected_h="a7248de563b572aa586b28a8493ddd087dfbb400"
    expected_c="375c6e1c2a2f74912661da8dc659e23dfcb44f02"
    if source_ids != (expected_h,expected_c):
        p.error("CPU files are not pinned MAME D0 source; refuse blind patch: "+str(source_ids))
    def strict_replace(s, old, new, label):
        if s.count(old)!=1:
            raise ValueError(label+" anchor count "+str(s.count(old)))
        return s.replace(old,new,1)
    new_h,new_c=patch_bootstrap(h,c,strict_replace,False)
    if new_h==h or new_c==c:
        p.error("no changes")
    # Keep independent originals for rollback; never touch donor tree.
    backup=tree/".ap07-cpu-original"
    backup.mkdir(exist_ok=True)
    for target,original in [(backup/"mc68hc11.h",h),(backup/"mc68hc11.cpp",c)]:
        if target.exists() and target.read_text()!=original:
            p.error("backup conflict")
        if not target.exists():
            target.write_text(original)
    hpath.write_text(new_h); cpath.write_text(new_c)
    marker={"feature":"AP07_POST_SCI_D0P","source_blobs":source_ids,
            "cpu_patched":True,"authentic_sci":False}
    (tree/".ap07-cpu-marker.json").write_text(json.dumps(marker,indent=2)+"\n")
    print(json.dumps(marker))
