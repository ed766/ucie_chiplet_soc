"""Positive and negative architectural qualification, independent of RTL logs."""
import unittest

from rv32_iss import RV32ISS, rv32m_result


def event(op, *, enabled=True, trap=False, rd=3):
    insn = (1 << 25) | (2 << 20) | (1 << 15) | (op << 12) | (rd << 7) | 0x33
    row = dict(order="0", epoch="0", insn=f"{insn:08x}", pc_rdata="00000000",
               pc_wdata="00000300" if trap else "00000004", trap=str(int(trap)), intr="0",
               rs1_addr="1", rs2_addr="2", rs1_rdata="00000007", rs2_rdata="00000003",
               rd_addr="0" if trap else str(rd), rd_wdata="00000000" if trap or not rd else
               f"{rv32m_result(op, 7, 3):08x}", mem_addr="00000000", mem_rmask="0",
               mem_wmask="0", mem_rdata="00000000", mem_wdata="00000000",
               mstatus="00001800", mie="00000000", mtvec="00000300", mscratch="00000000",
               mepc="00000000", mcause="00000002" if trap else "00000000",
               mtval=f"{insn:08x}" if trap else "00000000")
    iss = RV32ISS(enable_m=enabled)
    iss.regs[1], iss.regs[2] = 7, 3
    return iss, row


class MLegalityTests(unittest.TestCase):
    def test_all_enabled_results(self):
        for op in range(8):
            with self.subTest(op=op):
                iss, row = event(op)
                iss.check_row(row)
                self.assertEqual(iss.mismatches, [])

    def test_all_disabled_traps(self):
        for op in range(8):
            with self.subTest(op=op):
                iss, row = event(op, enabled=False, trap=True)
                before = iss.regs[:], dict(iss.memory)
                iss.check_row(row)
                self.assertEqual(iss.mismatches, [])
                self.assertEqual((iss.regs, iss.memory), before)

    def test_reject_all_disabled_retirements(self):
        for op in range(8):
            with self.subTest(op=op):
                iss, row = event(op, enabled=False)
                iss.check_row(row)
                self.assertTrue(any("non-trapping" in m for m in iss.mismatches))

    def test_reject_all_spurious_enabled_traps(self):
        for op in range(8):
            with self.subTest(op=op):
                iss, row = event(op, trap=True)
                iss.check_row(row)
                self.assertTrue(any("trap on legal" in m for m in iss.mismatches))

    def test_x0_and_no_memory_effects(self):
        for op in range(8):
            iss, row = event(op, rd=0)
            iss.check_row(row)
            self.assertEqual(iss.mismatches, [])
            iss, row = event(op)
            row["mem_wmask"] = "f"
            iss.check_row(row)
            self.assertTrue(any("memory effects" in m for m in iss.mismatches))

    def test_disabled_trap_suppresses_memory_effects(self):
        for op in range(8):
            iss, row = event(op, enabled=False, trap=True)
            row['mem_wmask'] = 'f'
            iss.check_row(row)
            self.assertTrue(any('memory effects' in m for m in iss.mismatches))

    def test_csr_legality_uses_encoded_source_not_runtime_zero(self):
        iss = RV32ISS()
        iss.regs[1] = 0
        for funct3 in (2, 3):
            self.assertFalse(iss.legal_encoding((0x301 << 20) | (1 << 15) | (funct3 << 12) | 0x73))
            self.assertTrue(iss.legal_encoding((0x301 << 20) | (funct3 << 12) | 0x73))

    def test_irq_enable_and_enabled_source_priority(self):
        for global_enable, source_enable, cause, should_pass in (
                (True, 0x880, 0x8000000b, True),
                (True, 0x80, 0x80000007, True),
                (False, 0x880, 0x8000000b, False),
                (True, 0, 0x80000007, False)):
            iss, row = event(4)
            iss.csrs[0x300] = 0x1808 if global_enable else 0x1800
            iss.csrs[0x304] = source_enable
            row.update(intr='1', pc_wdata='00000300', rd_addr='0', rd_wdata='00000000',
                       irq_level='1', irq_timer_level='1', mcause=f'{cause:08x}',
                       mie=f'{source_enable:08x}', mstatus=f'{iss.csrs[0x300]:08x}')
            iss.check_row(row)
            self.assertEqual(not iss.mismatches, should_pass, iss.mismatches)


if __name__ == "__main__":
    unittest.main()
