#!/usr/bin/env python3
"""Exercise the actual native helper, including all LDAPR register/size fields."""
from pathlib import Path
import re, subprocess, tempfile
root = Path(__file__).resolve().parents[1]
source = (root / 'worktrees/madeira/build/ntdll-unix/signal_arm64_ios.c').read_text()
helper = re.search(r'static BOOL agepad_bus_instruction_is_store\( uint32_t insn \)\n\{.*?\n\}', source, re.S).group()
body = r'''
int main(void) {
    /* LDAPR B/H/W/X encodings; bit22 alone wrongly reports a store. */
    for (unsigned size=0; size<4; ++size)
        for (unsigned regs=0; regs<1024; ++regs) {
            uint32_t op=0x38bfc000u | (size<<30) | regs;
            assert((op & 0x0a000000u)==0x08000000u && !(op & 0x00400000u));
            assert(!agepad_bus_instruction_is_store(op));
        }
    /* Assembled ARMv8.4-A LDARH, LDAPURH, LDRH and matching stores. */
    const uint32_t reads[]={0x48dffd49,0x59407149,0x79400d49};
    const uint32_t writes[]={0x489ffd49,0x59007149,0x79000d49};
    for (unsigned i=0;i<3;++i) {
        assert(!agepad_bus_instruction_is_store(reads[i]));
        assert(agepad_bus_instruction_is_store(writes[i]));
    }
    return 0;
}
'''
with tempfile.TemporaryDirectory() as d:
    p=Path(d)/'test.c'; binary=Path(d)/'test'
    p.write_text('#include <stdint.h>\n#include <assert.h>\n#define BOOL int\n#define FALSE 0\n'+helper+body)
    subprocess.run(['clang','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(p),'-o',str(binary)],check=True)
    subprocess.run([str(binary)],check=True)
print('PASS: 4096 LDAPR encodings and six load/store controls; actual source helper, ASan/UBSan')
