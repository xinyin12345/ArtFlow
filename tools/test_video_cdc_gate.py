"""Synthetic report fixtures prove missing, swapped and over-budget CDC fail.

These are parser tests, never post-route implementation evidence.
"""
import unittest
from check_video_cdc import GROUPS, parse_reports


def fixture(groups=GROUPS, tied_minima=False):
    summaries, skew_blocks, slow_blocks = [], [], []
    for group in groups:
        budget = group['budget_ns']
        prefix = f'[get_pins {{{group["source"]}}}] | [get_pins {{{group["destination"]}}}]'
        summaries.append(f'{prefix} | Slow | {budget:.3f} | 0.500 | {budget-0.5:.3f}\n')
        command = (f'set_bus_skew -from [get_pins {{{group["source"]}}}] '
                   f'-to [get_pins {{{group["destination"]}}}] {budget:.3f}\n')
        skew_blocks.append(command+f'Requirement: {budget:.3f} ns\nEndpoints: {group["bits"]}\n')
        details = []
        pins = sorted(group['pins'])
        for pin in pins if tied_minima else pins[1:]:
            def source(destination):
                if group['name'] == 'gain_mailbox':
                    return destination.replace('camera_gain_', 'u_control/mailbox_').replace('|D', '|CLK')
                stem = 'capture_words_gray' if group['name'] == 'count_meta' else 'display_epoch_gray'
                return destination.replace(group['name'], stem).replace('|D', '|CLK')
            reference = pins[1] if pin == pins[0] else pins[0]
            endpoint_delay = 0.5 if tied_minima and pin in pins[:2] else 1.0
            details.append(f'Slack: {budget-0.5:.3f} ns\n'
                           f'Endpoint Source: {source(pin)} (clock)\n'
                           f'Endpoint Destination: {pin} (clock)\n'
                           f'Reference Source: {source(reference)} (clock)\n'
                           f'Reference Destination: {reference} (clock)\n'
                           'Path Type: Max at Slow Process Corner\n'
                           f'Endpoint Relative Delay: {endpoint_delay:.3f} ns\n'
                           'Reference Relative Delay: 0.500 ns\n'
                           '+ Clock To Q + Data Path Delay : 1.000\n'
                           '+ Clock To Q + Data Path Delay : 0.500\n')
        comparisons = group['bits'] if tied_minima else group['bits']-1
        slow_blocks.append(command+f'Requirement: {budget:.3f} ns\nEndpoints: {comparisons}\n'
                           + ''.join(details))
    header = ''.join(summaries)+'\n'
    return header+''.join(skew_blocks), header+''.join(slow_blocks)


class CdcGate(unittest.TestCase):
    def test_three_complete_groups(self):
        self.assertEqual([r['endpoints'] for r in parse_reports(*fixture())], [32,32,48])

    def test_legacy_two_groups_keep_original_budget(self):
        self.assertEqual([r['budget_ns'] for r in parse_reports(*fixture(GROUPS[:2]), GROUPS[:2])], [2.5,2.5])

    def test_legacy_cannot_sign_off_v05(self):
        with self.assertRaises(ValueError): parse_reports(*fixture(GROUPS[:2]))

    def test_tied_minimum_reference_reports_all_n_comparisons(self):
        rows = parse_reports(*fixture(tied_minima=True))
        self.assertEqual([r['slow_comparisons'] for r in rows], [32,32,48])

    def test_extra_comparison_requires_real_tied_minima(self):
        skew, slow = fixture(tied_minima=True)
        bad_slow = slow.replace('Endpoint Relative Delay: 0.500 ns',
                                'Endpoint Relative Delay: 0.800 ns', 1)
        with self.assertRaises(ValueError): parse_reports(skew, bad_slow)

    def test_reject_report_mutations(self):
        skew, slow = fixture()
        bad_pairs = [
            (skew.replace('Endpoints: 48', 'Endpoints: 47'), slow),
            (skew, slow.replace('camera_gain_r[15]~FF|D','camera_gain_r[14]~FF|D')),
            (skew, slow.replace('u_control/mailbox_b[15]~FF|CLK','u_control/mailbox_b[14]~FF|CLK')),
            (skew.replace('20.000','25.000'), slow),
            (skew, slow.replace('Endpoint Relative Delay: 1.000 ns','Endpoint Relative Delay: 21.000 ns',1)),
            (skew, slow.replace('+ Clock To Q + Data Path Delay : 1.000','+ Clock To Q + Data Path Delay : 21.000',1)),
            (skew, slow.replace('Slack: 2.000 ns','Slack: -0.001 ns',1)),
            (skew, slow.replace('Max at Slow Process Corner','Min at Fast Process Corner',1)),
            (skew, slow.replace('Reference Relative Delay: 0.500 ns','Missing delay',1)),
            (skew, slow.replace('Endpoints: 47','Endpoints: 46')),
            (skew.replace(' | 0.500 | 2.000',' | 0.500 | -1.000',1), slow),
        ]
        for number, (bad_skew, bad_slow) in enumerate(bad_pairs):
            with self.subTest(mutation=number), self.assertRaises(ValueError):
                parse_reports(bad_skew, bad_slow)


if __name__ == '__main__':
    unittest.main()
