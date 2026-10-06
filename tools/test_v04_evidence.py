"""Exercise regression evidence lifecycle without starting any EDA process."""
import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import run_v04 as runner


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        (runner.ROOT/'work').mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix='v04_evidence_', dir=runner.ROOT/'work')
        self.addCleanup(self.temp.cleanup)
        self.run = Path(self.temp.name)
        self.summary = self.run/'summary.json'
        self.summary.write_text('{"status":"PASS","old_evidence":true}\n')
        self.addCleanup(patch.stopall)
        patch.object(runner, 'RUN', self.run).start()
        patch.object(runner, 'EVIDENCE', {}).start()

    def invoke(self):
        with patch.object(sys, 'argv', ['run_v04.py', '--smoke', '--run-dir', str(self.run)]):
            with contextlib.redirect_stdout(io.StringIO()):
                return runner.main()

    def test_emit_tcl_cannot_reuse_old_pass(self):
        (self.run/'old.log').write_text('OLD PASS\n')
        result = subprocess.run([sys.executable, '-B', runner.ROOT/'tools/run_v04.py',
                                 '--smoke', '--run-dir', self.run,
                                 '--emit-tcl', self.run/'plan.tcl'],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('REGRESSION PREPARED', result.stdout)
        self.assertNotIn('REGRESSION PASS', result.stdout)
        data = json.loads(self.summary.read_text())
        self.assertEqual(data['status'], 'PREPARED')
        self.assertNotIn('old_evidence', data)
        self.assertNotIn('old.log', data['evidence_sha256'])
        self.assertTrue((self.run/'plan.tcl').is_file())
        self.assertFalse((self.run/'compile.log').exists())
        self.assertEqual(data['source_sha256'], runner.input_hashes())
        for name, digest in data['evidence_sha256'].items():
            self.assertEqual(runner.sha(self.run/name), digest)

    def test_failure_invalidates_old_pass_before_command(self):
        def fail(*args, **kwargs):
            self.assertEqual(json.loads(self.summary.read_text())['status'], 'RUNNING')
            raise RuntimeError('injected preparation failure')
        with patch.object(runner, 'command', side_effect=fail):
            self.assertTrue(self.invoke())
        self.assertEqual(json.loads(self.summary.read_text())['status'], 'FAIL')

    def test_interrupt_leaves_running_not_old_pass(self):
        with patch.object(runner, 'command', side_effect=KeyboardInterrupt):
            with self.assertRaises(KeyboardInterrupt):
                self.invoke()
        self.assertEqual(json.loads(self.summary.read_text())['status'], 'RUNNING')

    def test_changed_input_cannot_finish_pass(self):
        result = dict(name='scheduler', status='PASS')
        with patch.object(runner, 'input_hashes', side_effect=[{'input':'before'}, {'input':'after'}]), \
             patch.object(runner, 'command', return_value=result), \
             patch.object(runner, 'sim', return_value=result), \
             patch.object(runner, 'generate'), \
             patch.object(runner, 'plan', return_value=[('scheduler', 'tb_video_axi_scheduler', {}, 1)]):
            self.assertTrue(self.invoke())
        data = json.loads(self.summary.read_text())
        self.assertEqual(data['status'], 'FAIL')
        self.assertEqual(data['tests'][-1]['name'], 'Regression inputs changed during run')

    def test_command_binds_replaced_log(self):
        log = self.run/'probe.log'
        log.write_text('OLD PASS\n')
        with contextlib.redirect_stdout(io.StringIO()):
            result = runner.command([sys.executable, '-c', 'print("probe PASS")'],
                                    'probe', 'probe PASS')
        self.assertNotIn('OLD', log.read_text())
        self.assertEqual(result['log_sha256'], runner.sha(log))
        self.assertEqual(runner.EVIDENCE['probe.log'], runner.sha(log))

    def test_timeout_cannot_leave_old_log(self):
        log = self.run/'timeout.log'
        log.write_text('OLD PASS\n')
        with self.assertRaises(subprocess.TimeoutExpired):
            runner.command([sys.executable, '-c', 'import time; time.sleep(2)'],
                           'timeout', timeout=0.05)
        self.assertNotIn('OLD', log.read_text())
        self.assertEqual(runner.EVIDENCE['timeout.log'], runner.sha(log))

    def test_full_registry_has_all_72_results(self):
        config = runner.load_config()
        cases = runner.plan(config, full=True)
        names = runner.required_full_results(config)
        self.assertEqual(len(cases), 32)
        self.assertEqual(sum(top=='tb_v04_checked' for _,top,_,_ in cases), 28)
        self.assertEqual(len(names), 72)
        self.assertEqual(len(runner.NEGATIVE_CASE_NAMES), 9)
        self.assertIn('check_full_30fps', names)
        self.assertIn('check_endurance', names)
        self.assertTrue(set(runner.NEGATIVE_CASE_NAMES) <= names)
        for required in ('tools/run_v04.py', 'tools/v04_golden.py',
                         'tools/v04_config.py', 'tools/test_v04_config.py',
                         'rtl/gamma_conrrection/2P2.mem',
                         'rtl/gamma_conrrection/gamma_2p2_8b.mem'):
            self.assertIn(required, runner.INPUTS)


if __name__ == '__main__':
    unittest.main(verbosity=2)
