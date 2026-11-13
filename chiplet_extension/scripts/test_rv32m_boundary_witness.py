"""Phase coverage must reject requested-but-unreached stimulus."""
import csv
import tempfile
import unittest
from pathlib import Path

from run_rv32m_boundaries import boundary_witness, cases
from test_rv32m_iss import event


class BoundaryWitnessTests(unittest.TestCase):
    def trace(self, rows):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        path = Path(folder.name) / 'trace.csv'
        with path.open('w', newline='') as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
            writer.writeheader(); writer.writerows(rows)
        return path

    def test_matrix_is_unique_and_complete(self):
        matrix = list(cases())
        self.assertEqual(len(matrix), 312)
        self.assertEqual(len({tuple(row.items()) for row in matrix}), 312)
        self.assertEqual(sum(row['mode'] == 'irq' for row in matrix), 192)
        self.assertEqual(sum(row['mode'] == 'reset' for row in matrix), 48)

    def test_disabled_requires_observed_trap(self):
        _, good = event(0, enabled=False, trap=True)
        good['cycle'] = '1'
        knobs = dict(mode='disabled', op=0)
        self.assertTrue(boundary_witness(knobs, self.trace([good]), '')[0])
        good['trap'] = '0'
        self.assertFalse(boundary_witness(knobs, self.trace([good]), '')[0])

    def test_irq_requires_actual_arrival_and_entry(self):
        _, row = event(4)
        row['cycle'] = '10'
        irq = dict(row, order='1', cycle='11', intr='1', mcause='8000000b')
        path = self.trace([row, irq])
        knobs = dict(mode='irq', op=4, source=0, phase=2)
        reached = 'BOUNDARY_EVENT|irq_arrival|cycle=9|phase=2|busy=1|result=1\n'
        self.assertTrue(boundary_witness(knobs, path, reached)[0])
        self.assertFalse(boundary_witness(knobs, path, reached.replace('busy=1', 'busy=0'))[0])
        self.assertFalse(boundary_witness(knobs, path, reached.replace('result=1', 'result=0'))[0])
        self.assertFalse(boundary_witness(knobs, self.trace([row]), reached)[0])


if __name__ == '__main__':
    unittest.main()
