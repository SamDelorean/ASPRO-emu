#!/usr/bin/env python3
"""Compile and execute the EXACT AP07 C++ D0 SCI receiver and BASE WAIT snippets.

No MAME build, no ROM, no Commander. This uses a deliberately minimal,
access-control-faithful stub to expose C++ private-member regressions
before a full ASPRO-DIAG incremental compilation.
"""
from __future__ import annotations

import runpy
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DONOR = runpy.run_path(str(ROOT / "tools/ap07_patch_d0_cpu.py"))
SCI = DONOR["DONOR_SCI"]
BASE_WAIT = DONOR["BASE_WAIT"]

PREAMBLE = r'''
#include <array>
#include <cstdint>
#include <cstdio>
#include <stdexcept>
#include <algorithm>
#include <cassert>
#define logerror(...) std::fprintf(stderr, __VA_ARGS__)
#define fatalerror(...) throw std::runtime_error("fatalerror")
static constexpr uint8_t CC_X = 0x40, CC_I = 0x10, CC_S = 0x80;

class mc68hc11_cpu_device {
protected:
    uint8_t m_config=0;
    void diagnostic_bootstrap_wait_for_serial();
    uint8_t get_config() const { return m_config; }
private:
    uint32_t m_irq_state=0;
    bool m_irq_asserted=false;
    uint8_t m_wait_state=0;
    uint8_t m_stop_state=0;
    uint8_t m_ccr=0;
};

class mc68hc11d0_device : public mc68hc11_cpu_device {
public:
    void diag_bootstrap_begin();
    void diag_bootstrap_rx_bit(bool rxd);
    bool diag_bootstrap_tx_bit();
    void diag_bootstrap_load(const uint8_t *data, uint16_t size, uint16_t address) {
        assert(size<=192 && address==0x0040);
        std::copy(data, data+size, loaded.begin());
        loaded_count=size;
        loaded_address=address;
    }
    uint16_t count() const { return m_diag_sci_count; }
    uint16_t echoes() const { return m_diag_sci_echo_count; }
    uint8_t echo_last() const { return m_diag_sci_echo_last; }
    bool done() const { return m_diag_sci_done; }
    bool bad() const { return m_diag_sci_bad; }
    bool enabled() const { return m_diag_bootstrap; }
    std::array<uint8_t,192> loaded{};
    uint16_t loaded_count=0;
    uint16_t loaded_address=0;
private:
    bool m_diag_bootstrap = true;
    uint8_t m_hprio=0;
    uint8_t m_diag_sci_ram[192]{};
    uint16_t m_diag_sci_count=0;
    uint16_t m_diag_sci_echo_count=0;
    uint8_t m_diag_sci_echo_last=0;
    uint8_t m_diag_sci_tx_bit=0;
    bool m_diag_sci_tx_pending=false;
    uint8_t m_diag_sci_shift=0;
    uint8_t m_diag_sci_bit=0;
    uint8_t m_diag_sci_idle=0;
    bool m_diag_sci_receiving=false;
    bool m_diag_sci_synced=false;
    bool m_diag_sci_done=false;
    bool m_diag_sci_bad=false;
};
'''
TESTS = r'''
static void send_byte(mc68hc11d0_device &d, uint8_t value, bool stop=true)
{
    d.diag_bootstrap_rx_bit(false);
    for (int n=0;n<8;n++)
        d.diag_bootstrap_rx_bit((value >> n) & 1);
    d.diag_bootstrap_rx_bit(stop);
}
static uint8_t read_txd_echo(mc68hc11d0_device &d)
{
    uint8_t value=0;
    for(unsigned bit=0;bit<10;bit++)
    {
        d.diag_bootstrap_rx_bit(true);  // separate RX wire remains high
        const bool txd=d.diag_bootstrap_tx_bit();
        if(bit==0) assert(!txd);         // 8N1 start
        else if(bit<=8) { if(txd) value |= uint8_t(1U<<(bit-1)); }
        else assert(txd);                // 8N1 stop
    }
    return value;
}
static void exchange(mc68hc11d0_device &d, uint8_t value)
{
    send_byte(d,value);
    assert(read_txd_echo(d)==value);
}
static void idle(mc68hc11d0_device &d,unsigned n)
{
    for(unsigned k=0;k<n;k++) d.diag_bootstrap_rx_bit(true);
}
int main()
{
    mc68hc11d0_device d;
    d.diag_bootstrap_begin();
    send_byte(d,0xff);
    assert(d.echoes()==0); // Receiving byte is NOT the same as TXD echo.
    assert(read_txd_echo(d)==0xff && d.echoes()==1);
    const uint8_t payload[] = {0x0f,0x20,0xfe};
    for(auto b:payload) exchange(d,b);
    idle(d,29); // 10 TXD echo cells already counted as RX idle.
    assert(!d.done() && d.loaded_count==0);
    idle(d,1);
    assert(d.done() && !d.bad() && d.echoes()==4 && d.count()==3);
    assert(d.echo_last()==0xfe && d.loaded_count==3 && d.loaded_address==0x0040);
    assert(std::equal(std::begin(payload),std::end(payload),d.loaded.begin()));
    std::puts("PASS: FF sync; RX 8N1; physical TXD 8N1 echo; 40 idle cells; RAM handoff");

    mc68hc11d0_device badsync;
    badsync.diag_bootstrap_begin();
    send_byte(badsync,0x55);
    assert(badsync.bad() && !badsync.done() && badsync.loaded_count==0);
    std::puts("PASS: reject invalid sync");

    mc68hc11d0_device badstop;
    badstop.diag_bootstrap_begin();
    send_byte(badstop,0xff,false);
    assert(badstop.bad() && !badstop.done());
    std::puts("PASS: reject bad stop bit");

    mc68hc11d0_device full;
    full.diag_bootstrap_begin();
    exchange(full,0xff);
    for(int i=0;i<192;i++) exchange(full,uint8_t(i));
    idle(full,30);
    assert(full.done() && !full.bad() && full.count()==192 && full.loaded_count==192);
    assert(full.echoes()==193);
    std::puts("PASS: full 192 bytes with 8N1 TXD echo");

    mc68hc11d0_device over;
    over.diag_bootstrap_begin();
    exchange(over,0xff);
    for(int i=0;i<192;i++) exchange(over,uint8_t(i));
    send_byte(over,0x55); // 193rd byte, not permitted; no echo
    idle(over,40);
    assert(over.bad() && !over.done() && over.loaded_count==0);
    std::puts("PASS: 193-byte overflow blocks CPU execution");

    return 0;
}
'''

def main() -> None:
    compiler = shutil.which("g++") or shutil.which("clang++")
    if compiler is None:
        raise SystemExit("BLOCKED: C++ compiler required")
    assert "m_diag_sci_count" in SCI and "m_wait_state" in BASE_WAIT
    assert "diagnostic_bootstrap_wait_for_serial();" in SCI
    with tempfile.TemporaryDirectory(prefix="ap07-cxx-") as td:
        source = Path(td) / "ap07_sci.cpp"
        binary = Path(td) / "ap07_sci"
        source.write_text(PREAMBLE + "\n" + BASE_WAIT + "\n" + SCI + "\n" + TESTS)
        proc = subprocess.run([compiler, "-std=c++20", "-O0", "-Wall",
                "-Wextra", "-Werror", "-pedantic", str(source), "-o", str(binary)],
                capture_output=True, text=True)
        if proc.returncode:
            print(proc.stderr[-12000:])
            raise SystemExit("FAIL: exact C++ D0 SCI/BASE_WAIT snippets did not compile")
        exe = subprocess.run([str(binary)], capture_output=True, text=True, timeout=8)
        if exe.returncode:
            print(exe.stdout[-5000:])
            print(exe.stderr[-5000:])
            raise SystemExit("FAIL: compiled D0 SCI receiver regression")
        print(exe.stdout.strip())
        print("AP07_SCI_CXX_SMOKE_PASS: exact donor snippets; 5 executable cases")
        print("Scope: C++ access, true TXD 8N1 echo, decode and bounds; no MAME/LCD claims")

if __name__ == "__main__":
    main()
