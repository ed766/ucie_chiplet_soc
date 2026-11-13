import unittest
from run_rv32m_mutations import qualified_failure


class MutationGateTests(unittest.TestCase):
    def test_intended_failure(self):
        self.assertTrue(qualified_failure(True, 1,
            "RV32M_ACTIVATE|case\nRV32M_FAILURE|case|wrong data", "case", True))

    def test_unrelated_failures_do_not_qualify(self):
        for compiled, code, output, control in (
            (False, 1, "RV32M_ACTIVATE|case\nRV32M_FAILURE|case|", True),
            (True, 1, "RV32M_ACTIVATE|case\nassertion elsewhere", True),
            (True, 124, "RV32M_ACTIVATE|case\ntimeout", True),
            (True, 1, "RV32M_FAILURE|case|", True),
            (True, 1, "RV32M_ACTIVATE|case\nRV32M_FAILURE|other|", True),
            (True, 1, "RV32M_ACTIVATE|case\nRV32M_FAILURE|case|", False),
            (True, 0, "RV32M_ACTIVATE|case\nRV32M_FAILURE|case|", True),
        ):
            with self.subTest(output=output, compiled=compiled, control=control):
                self.assertFalse(qualified_failure(compiled, code, output, "case", control))


if __name__ == '__main__':
    unittest.main()
