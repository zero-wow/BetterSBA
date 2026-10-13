"""Safety and mode separation for the local-only SimC comparison runner."""

import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("sba_comparison", ROOT / "scripts/run_sba_comparison.py")
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class ComparisonTests(unittest.TestCase):
    def test_removes_identity_and_custom_rotation(self):
        profile, count = runner.sanitize_profile('monk="Private Name"\nspec=windwalker\nserver=Private Realm\nactions=tiger_palm\nactions+=/blackout_kick\nhead=test,id=123\n')
        self.assertEqual(count, 2)
        self.assertEqual(profile, ['monk="BetterSBA_Comparison"', 'spec=windwalker', 'head=test,id=123'])

    def test_rejects_network_and_arbitrary_output_options(self):
        for option in ('input=other.simc', 'armory=us,realm,name', 'json2=elsewhere.json', 'copy=Other', 'threads=99'):
            with self.subTest(option=option), self.assertRaises(ValueError):
                runner.sanitize_profile('monk=Test\nspec=windwalker\n' + option)

    def test_rejects_multiple_actors(self):
        with self.assertRaises(ValueError):
            runner.sanitize_profile('monk=One\nspec=windwalker\nmonk=Two\n')

    def test_rejects_injected_simc_tokens_in_allowlisted_values(self):
        for option in (
            'spec=windwalker input=other.simc',
            'spec=windwalker\tjson2=outside.json',
            'spec="windwalker input=other.simc"',
            'head=test,id=123 threads=99',
            'level=90\x00input=other.simc',
            'race=$(outside)',
            'food=food\u00a0input=other.simc',
            'professions=engineering=100 input=other.simc',
            'temporary_enchant=main_hand:oil_2 input=other.simc',
            'set_bonus=test=1 input=other.simc',
            'talents=' + 'A' * 30 + ' input=other.simc',
        ):
            with self.subTest(option=option), self.assertRaises(ValueError):
                runner.sanitize_profile('monk=Test\nspec=windwalker\n' + option)

    def test_rejects_item_source_overrides_and_unknown_attributes(self):
        for value in ('test,id=123,source=wowhead', 'test,id=123,source=local',
                      'test,id=123,input=other.simc', 'test,id=123,id=456',
                      'test,id=$(outside)', '"Display Name",id=123'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                runner.sanitize_profile('monk=Test\nspec=windwalker\nhead=' + value)

    def test_preserves_supported_gameplay_export_values(self):
        lines = ['head=test,id=123,bonus_id=1/2,gem_bonus_id=1:2/3:4,crafted_stats=32/49',
                 'professions=engineering=100/mining=100',
                 'temporary_enchant=main_hand:oil_2/off_hand:oil_2',
                 'set_bonus=midnight_4pc=1', 'omnium_talents=136822:1/136819:1']
        profile, _ = runner.sanitize_profile('monk=Test\nspec=windwalker\n' + '\n'.join(lines))
        self.assertEqual(profile[2:], lines)

    def test_replaces_partial_talent_overrides(self):
        code = 'C0Q' + 'A' * 30
        profile, _ = runner.sanitize_profile('monk=Test\nspec=windwalker\ntalents=' + 'A' * 30 + '\nclass_talents=talent:1\nhero_talents=talent:1\n', code)
        self.assertEqual([line for line in profile if 'talents=' in line], ['talents=' + code])

    def test_modes_do_not_confuse_sba_with_manual(self):
        args = dict(iterations=100, threads=2, seconds=60, targets=1, seed=12)
        for mode, expected in [('sba', (1, 1, 0)), ('sba-cooldowns', (1, 1, 1)), ('optimized', (0, 0, 0))]:
            text = runner.make_input(['monk=Test', 'spec=windwalker'], mode, **args)
            for option, value in zip(('use_blizzard_action_list', 'one_button_mode', 'use_cds_with_blizzard_action_list'), expected):
                self.assertIn(f'{option}={value}\n', text)
            self.assertGreater(text.index('one_button_mode='), text.index('monk='))
            self.assertIn('item_db_source=local\n', text)
            self.assertIn('ptr=0\n', text)

    def test_repository_cannot_receive_private_output(self):
        with self.assertRaises(ValueError):
            runner.validate_output(ROOT / 'reports')

    def test_wrong_patch_cannot_receive_compatible_result(self):
        report = {'sim': {'players': [{'dbc': {'version_used': 'Live', 'Live': {'wow_version': '12.0.5.12345'}}}]}}
        with self.assertRaisesRegex(ValueError, 'requested live patch'):
            runner.summarize(report, '12.1.0')

    def test_preserves_warning_counts_without_copying_arbitrary_messages(self):
        report = {'version': '1210-01', 'logs': [
            {'level': 'implementation_not_yet_verified', 'message': 'Private model detail'},
            {'level': 'unexpected private label', 'message': 'Private path'},
            {'level': 'info', 'message': 'An informational entry'},
        ], 'sim': {
            'players': [{'dbc': {'version_used': 'Live', 'Live': {'wow_version': '12.1.0.69933'}},
                         'collected_data': {'dps': {'mean': 100, 'mean_std_dev': 2, 'count': 999}}}],
            'options': {'confidence': 0.95}, 'statistics': {'elapsed_time_seconds': 1},
        }}
        result = runner.summarize(report, '12.1.0')
        self.assertEqual(result['model_warning_count'], 2)
        self.assertEqual(result['model_warning_levels'], {'implementation_not_yet_verified': 1, 'other': 1})
        self.assertEqual(result['model_warning_source'], 'report.json:logs')
        self.assertNotIn('Private', str(result))
        self.assertAlmostEqual(result['dps_error'], 3.91992796908)


if __name__ == '__main__':
    unittest.main()
