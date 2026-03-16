#!/usr/bin/env python3
"""
Unit tests for compute-dispatches.py

Run with: python3 scripts/lib/test_compute_dispatches.py
Or:       python3 -m pytest scripts/lib/test_compute_dispatches.py -v
"""
import json
import os
import sys
import tempfile
import unittest

# Ensure we can import the module under test.
# The module file uses a hyphen in the name (compute-dispatches.py) which is not
# a valid Python identifier, so we use importlib to load it by file path.
import importlib.util
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_MODULE_PATH = os.path.join(_SCRIPT_DIR, "compute-dispatches.py")
_spec = importlib.util.spec_from_file_location("compute_dispatches", _MODULE_PATH)
cd = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cd)


# ──────────────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────────────

# Pricing fixture (sonnet + opus rates matching Run 13/14 data)
PRICING_FIXTURE = {
    "rates": {
        "opus": {"inputPerM": 5.0, "outputPerM": 25.0},
        "sonnet": {"inputPerM": 3.0, "outputPerM": 15.0},
        "haiku": {"inputPerM": 1.0, "outputPerM": 5.0},
    }
}

# Dispatch fixture based on Run 13/14 patterns (3 builds + 1 review)
DISPATCHES_FIXTURE = [
    {
        "agent": "Builder (sonnet)",
        "model": "sonnet",
        "task": "E01-S01 (#61)",
        "duration_ms": 146479,
        "tokens": 49691,
        "phase": "Build",
    },
    {
        "agent": "Builder (sonnet)",
        "model": "sonnet",
        "task": "E01-S02 (#62)",
        "duration_ms": 193000,
        "tokens": 60000,
        "phase": "Build",
    },
    {
        "agent": "Reviewer (sonnet)",
        "model": "sonnet",
        "task": "Review E01-S01 (#61)",
        "duration_ms": 72000,
        "tokens": 18000,
        "phase": "Review",
    },
    {
        "agent": "Designer (opus)",
        "model": "opus",
        "task": "Design Doc (#55)",
        "duration_ms": 294973,
        "tokens": 86265,
        "phase": "Design",
    },
]

# State file fixture based on actual orchestrator.json structure
STATE_FIXTURE = {
    "version": 1,
    "session": {
        "backlog": 69,
        "mode": "autonomous",
        "orchestrator_model": "opus",
        "started_at": "2026-03-15T10:00:00Z",
        "repo": "carlosboeing/agentic-sdlc-workflow",
    },
    "pricing": {
        "source": "anthropic-pricing-page",
        "rates": {
            "opus": {"inputPerM": 5.0, "outputPerM": 25.0},
            "sonnet": {"inputPerM": 3.0, "outputPerM": 15.0},
            "haiku": {"inputPerM": 1.0, "outputPerM": 5.0},
        },
    },
    "epics": {
        "e01": {
            "issue": 70,
            "branch": "epic/e01-destination-profiles",
            "stories": {
                "72": {
                    "status": "complete",
                    "branch": "e01-s01/destination-profiles",
                },
                "73": {
                    "status": "complete",
                    "branch": "e01-s02/travel-advisory",
                },
            },
        }
    },
    "dispatches": [
        {
            "id": 1,
            "agent": "designer",
            "model": "opus",
            "issue": 71,
            "started_at": "2026-03-15T10:01:00Z",
            "duration_ms": 294973,
            "tokens": 86265,
            "tool_uses": 41,
            "result": "success",
        },
        {
            "id": 2,
            "agent": "planner",
            "model": "opus",
            "issue": None,
            "started_at": "2026-03-15T10:06:00Z",
            "duration_ms": 300000,
            "tokens": 90000,
            "tool_uses": 50,
            "result": "success",
        },
        # Parallel builders (same started_at)
        {
            "id": 3,
            "agent": "builder-sonnet",
            "model": "sonnet",
            "issue": 72,
            "started_at": "2026-03-15T10:12:00Z",
            "duration_ms": 146479,
            "tokens": 49691,
            "tool_uses": 18,
            "result": "success",
        },
        {
            "id": 4,
            "agent": "builder-sonnet",
            "model": "sonnet",
            "issue": 73,
            "started_at": "2026-03-15T10:12:00Z",
            "duration_ms": 193000,
            "tokens": 60000,
            "tool_uses": 22,
            "result": "success",
        },
        # Sequential reviewer
        {
            "id": 5,
            "agent": "reviewer",
            "model": "sonnet",
            "issue": 72,
            "started_at": "2026-03-15T10:16:00Z",
            "duration_ms": 72000,
            "tokens": 18000,
            "tool_uses": 8,
            "result": "success",
        },
    ],
}


# ──────────────────────────────────────────────────────────────────────────────
# Helper: write fixture to temp file, return path
# ──────────────────────────────────────────────────────────────────────────────

def _write_json(data):
    """Write data as JSON to a temp file; caller is responsible for cleanup."""
    f = tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False)
    json.dump(data, f)
    f.close()
    return f.name


# ──────────────────────────────────────────────────────────────────────────────
# Formatting function tests
# ──────────────────────────────────────────────────────────────────────────────

class TestFmtDuration(unittest.TestCase):

    def test_zero_ms(self):
        self.assertEqual(cd.fmt_duration(0), "0s")

    def test_seconds_only(self):
        self.assertEqual(cd.fmt_duration(45000), "45s")

    def test_minutes_only(self):
        self.assertEqual(cd.fmt_duration(120000), "2m")

    def test_minutes_and_seconds(self):
        self.assertEqual(cd.fmt_duration(146000), "2m 26s")

    def test_large_duration(self):
        # 74m 4s = 4444 seconds = 4444000 ms
        self.assertEqual(cd.fmt_duration(4444000), "74m 4s")

    def test_one_minute_zero_seconds(self):
        self.assertEqual(cd.fmt_duration(60000), "1m")

    def test_one_second(self):
        self.assertEqual(cd.fmt_duration(1000), "1s")

    def test_truncates_subsecond(self):
        # 1500 ms = 1 second (floor division)
        self.assertEqual(cd.fmt_duration(1500), "1s")


class TestFmtTokens(unittest.TestCase):

    def test_small(self):
        self.assertEqual(cd.fmt_tokens(500), "500")

    def test_thousands(self):
        self.assertEqual(cd.fmt_tokens(49691), "49K")

    def test_thousands_exact(self):
        self.assertEqual(cd.fmt_tokens(1000), "1K")

    def test_millions(self):
        self.assertEqual(cd.fmt_tokens(1_500_000), "1.50M")

    def test_millions_exact(self):
        self.assertEqual(cd.fmt_tokens(2_000_000), "2.00M")

    def test_just_under_million(self):
        self.assertEqual(cd.fmt_tokens(999_999), "999K")


class TestFmtCost(unittest.TestCase):

    def test_none_returns_dash(self):
        self.assertEqual(cd.fmt_cost(None), "—")

    def test_zero(self):
        self.assertEqual(cd.fmt_cost(0.0), "~$0.00")

    def test_small_cost(self):
        self.assertEqual(cd.fmt_cost(0.50), "~$0.50")

    def test_larger_cost(self):
        self.assertEqual(cd.fmt_cost(4.79), "~$4.79")

    def test_rounds_to_two_decimal_places(self):
        self.assertEqual(cd.fmt_cost(1.234), "~$1.23")


# ──────────────────────────────────────────────────────────────────────────────
# Pricing tests
# ──────────────────────────────────────────────────────────────────────────────

class TestLoadPricing(unittest.TestCase):

    def setUp(self):
        self.pricing_file = _write_json(PRICING_FIXTURE)
        # Config with no pricing override
        self.config_no_pricing = _write_json({"github": {"repo": "test/test"}})
        # Config with pricing override
        self.config_with_pricing = _write_json({
            "pricing": {
                "sonnet": {"inputPerM": 2.0, "outputPerM": 10.0},
            }
        })

    def tearDown(self):
        for f in [self.pricing_file, self.config_no_pricing, self.config_with_pricing]:
            os.unlink(f)

    def test_loads_from_pricing_file(self):
        rates = cd.load_pricing(
            pricing_cache=self.pricing_file,
            cfg_file=self.config_no_pricing
        )
        self.assertIn("sonnet", rates)
        self.assertEqual(rates["sonnet"], (3.0, 15.0))

    def test_config_override_takes_priority(self):
        rates = cd.load_pricing(
            pricing_cache=self.pricing_file,
            cfg_file=self.config_with_pricing
        )
        # Config override for sonnet
        self.assertEqual(rates["sonnet"], (2.0, 10.0))
        # Pricing file fallback for opus (not in config override)
        self.assertNotIn("opus", rates)

    def test_missing_pricing_file_returns_empty(self):
        rates = cd.load_pricing(
            pricing_cache="/nonexistent/pricing.json",
            cfg_file=self.config_no_pricing
        )
        self.assertEqual(rates, {})

    def test_blended_rate_sonnet(self):
        rates = {"sonnet": (3.0, 15.0)}
        # 3.0 * 0.75 + 15.0 * 0.25 = 2.25 + 3.75 = 6.0 dollars per million
        result = cd.blended_rate("sonnet", rates)
        self.assertAlmostEqual(result, 6.0)

    def test_blended_rate_unknown_model_returns_none(self):
        rates = {"sonnet": (3.0, 15.0)}
        result = cd.blended_rate("unknown-model", rates)
        self.assertIsNone(result)


# ──────────────────────────────────────────────────────────────────────────────
# --dispatches mode tests
# ──────────────────────────────────────────────────────────────────────────────

class TestDispatchesMode(unittest.TestCase):

    def setUp(self):
        self.dispatches_file = _write_json(DISPATCHES_FIXTURE)
        self.pricing_file = _write_json(PRICING_FIXTURE)
        self.config_file = _write_json({})

    def tearDown(self):
        for f in [self.dispatches_file, self.pricing_file, self.config_file]:
            os.unlink(f)

    def _run(self):
        pricing = cd.load_pricing(self.pricing_file, self.config_file)
        return cd.compute_from_dispatches(DISPATCHES_FIXTURE, pricing)

    def test_output_has_required_fields(self):
        result = self._run()
        for field in ["breakdown", "summary", "cost", "duration_ms", "tokens"]:
            self.assertIn(field, result, f"Missing field: {field}")

    def test_duration_is_sum_of_all(self):
        result = self._run()
        expected = 146479 + 193000 + 72000 + 294973
        self.assertEqual(int(result["duration_ms"]), expected)

    def test_tokens_is_sum_of_all(self):
        result = self._run()
        expected = 49691 + 60000 + 18000 + 86265
        self.assertEqual(int(result["tokens"]), expected)

    def test_cost_is_numeric_string(self):
        result = self._run()
        # Should be a numeric string like "4.79"
        cost = float(result["cost"])
        self.assertGreater(cost, 0)

    def test_breakdown_contains_all_dispatches(self):
        result = self._run()
        breakdown = result["breakdown"]
        self.assertIn("E01-S01 (#61)", breakdown)
        self.assertIn("E01-S02 (#62)", breakdown)
        self.assertIn("Review E01-S01 (#61)", breakdown)
        self.assertIn("Design Doc (#55)", breakdown)

    def test_breakdown_has_total_row(self):
        result = self._run()
        breakdown = result["breakdown"]
        self.assertIn("**Total (4 dispatches)**", breakdown)

    def test_summary_groups_by_phase(self):
        result = self._run()
        summary = result["summary"]
        # Build phase with 2 stories
        self.assertIn("Build", summary)
        self.assertIn("(2 stories)", summary)
        # Review phase
        self.assertIn("Review", summary)
        # Design phase
        self.assertIn("Design", summary)

    def test_summary_has_total_row(self):
        result = self._run()
        summary = result["summary"]
        self.assertIn("**Total**", summary)

    def test_breakdown_row_format(self):
        result = self._run()
        breakdown_lines = result["breakdown"].splitlines()
        # Each row starts and ends with |
        for line in breakdown_lines:
            self.assertTrue(line.startswith("|"), f"Row doesn't start with |: {line}")
            self.assertTrue(line.endswith("|"), f"Row doesn't end with |: {line}")

    def test_duration_formatting_in_breakdown(self):
        """Verify fmt_duration is used correctly in the breakdown rows."""
        result = self._run()
        # 146479 ms = 2m 26s
        self.assertIn("2m 26s", result["breakdown"])

    def test_tokens_formatting_in_breakdown(self):
        """Verify fmt_tokens is used correctly in the breakdown rows."""
        result = self._run()
        # 49691 tokens = 49K
        self.assertIn("49K", result["breakdown"])

    def test_mixed_model_phase_description(self):
        """When a phase has multiple models, summary shows 'mixed (...)'."""
        mixed_dispatches = [
            {"agent": "Builder (haiku)", "model": "haiku", "task": "S01", "duration_ms": 100000, "tokens": 20000, "phase": "Build"},
            {"agent": "Builder (sonnet)", "model": "sonnet", "task": "S02", "duration_ms": 150000, "tokens": 50000, "phase": "Build"},
        ]
        pricing = cd.load_pricing(self.pricing_file, self.config_file)
        result = cd.compute_from_dispatches(mixed_dispatches, pricing)
        self.assertIn("mixed (haiku, sonnet)", result["summary"])

    def test_unknown_model_cost_shows_dash(self):
        """When pricing for a model is unavailable, cost shows '—'."""
        unknown_dispatches = [
            {"agent": "Builder (future)", "model": "future", "task": "S01", "duration_ms": 100000, "tokens": 20000, "phase": "Build"},
        ]
        # Empty pricing = no rates
        result = cd.compute_from_dispatches(unknown_dispatches, {})
        self.assertIn("—", result["breakdown"])
        # Total cost should be empty when unknown
        self.assertEqual(result["cost"], "")

    def test_full_cli_output_is_valid_json(self):
        """End-to-end: run the module via its main function and get valid JSON."""
        import io
        from unittest.mock import patch

        captured = io.StringIO()
        with patch("sys.stdout", captured):
            cd.main([
                "--dispatches", self.dispatches_file,
                "--pricing", self.pricing_file,
                "--config", self.config_file,
            ])

        output = captured.getvalue()
        parsed = json.loads(output)
        self.assertIn("breakdown", parsed)
        self.assertIn("summary", parsed)
        self.assertIn("cost", parsed)


# ──────────────────────────────────────────────────────────────────────────────
# --from-state mode tests
# ──────────────────────────────────────────────────────────────────────────────

class TestFromStateMode(unittest.TestCase):

    def setUp(self):
        self.state_file = _write_json(STATE_FIXTURE)
        self.pricing_file = _write_json(PRICING_FIXTURE)
        self.config_file = _write_json({})

    def tearDown(self):
        for f in [self.state_file, self.pricing_file, self.config_file]:
            os.unlink(f)

    def _run(self):
        pricing = cd.load_pricing(self.pricing_file, self.config_file)
        return cd.compute_from_state(STATE_FIXTURE, pricing)

    def test_output_has_required_fields(self):
        result = self._run()
        for field in ["breakdown", "summary", "cost", "duration_ms", "tokens", "wall_clock_ms", "has_parallel"]:
            self.assertIn(field, result, f"Missing field: {field}")

    def test_agent_to_phase_mapping_designer(self):
        """'designer' maps to 'Design' phase."""
        result = self._run()
        self.assertIn("Design", result["summary"])

    def test_agent_to_phase_mapping_planner(self):
        """'planner' maps to 'Plan' phase."""
        result = self._run()
        self.assertIn("Plan", result["summary"])

    def test_agent_to_phase_mapping_builder(self):
        """'builder-sonnet' maps to 'Build' phase."""
        result = self._run()
        self.assertIn("Build", result["summary"])

    def test_agent_to_phase_mapping_reviewer(self):
        """'reviewer' maps to 'Review' phase."""
        result = self._run()
        self.assertIn("Review", result["summary"])

    def test_task_label_for_design(self):
        """Design dispatch generates 'Design Doc (#N)' label."""
        result = self._run()
        self.assertIn("Design Doc (#71)", result["breakdown"])

    def test_task_label_for_plan(self):
        """Plan dispatch without issue generates 'Plan Doc' label."""
        result = self._run()
        self.assertIn("Plan Doc", result["breakdown"])

    def test_task_label_for_build_with_story_lookup(self):
        """Build dispatch for known issue generates label from branch name."""
        result = self._run()
        # Issue 72 has branch e01-s01/destination-profiles
        # Expected label: "Destination Profiles (#72)" (from branch)
        self.assertIn("#72", result["breakdown"])

    def test_task_label_for_review(self):
        """Review dispatch for known story generates 'Review ... (#N)' label."""
        result = self._run()
        self.assertIn("Review", result["breakdown"])
        self.assertIn("#72", result["breakdown"])

    def test_wall_clock_parallel_detection(self):
        """Dispatches with same started_at are treated as parallel (take max)."""
        result = self._run()
        # Dispatches 3 and 4 share started_at "2026-03-15T10:12:00Z"
        # duration_ms: 146479 and 193000 → max = 193000 for that group
        # Dispatch 1: 294973, Dispatch 2: 300000, Group(3,4): 193000, Dispatch 5: 72000
        # Wall clock = 294973 + 300000 + 193000 + 72000 = 859973
        self.assertEqual(result["wall_clock_ms"], 859973)

    def test_wall_clock_has_parallel_is_true(self):
        """has_parallel is True when parallel dispatches detected."""
        result = self._run()
        self.assertTrue(result["has_parallel"])

    def test_wall_clock_no_parallel(self):
        """All sequential dispatches → wall_clock == sum of all durations."""
        state_sequential = {
            **STATE_FIXTURE,
            "dispatches": [
                {
                    "id": 1, "agent": "designer", "model": "opus",
                    "issue": 71, "started_at": "2026-03-15T10:01:00Z",
                    "duration_ms": 100000, "tokens": 10000,
                },
                {
                    "id": 2, "agent": "planner", "model": "opus",
                    "issue": None, "started_at": "2026-03-15T10:03:00Z",
                    "duration_ms": 200000, "tokens": 20000,
                },
            ],
        }
        pricing = cd.load_pricing(self.pricing_file, self.config_file)
        result = cd.compute_from_state(state_sequential, pricing)
        self.assertEqual(result["wall_clock_ms"], 300000)
        self.assertFalse(result["has_parallel"])

    def test_duration_is_sum_of_all(self):
        """Sequential (total) duration is sum of all dispatches, not wall-clock."""
        result = self._run()
        expected = 294973 + 300000 + 146479 + 193000 + 72000
        self.assertEqual(int(result["duration_ms"]), expected)

    def test_agent_label_format_builder(self):
        """Builder agent generates 'Builder (model)' label."""
        result = self._run()
        self.assertIn("Builder (sonnet)", result["breakdown"])

    def test_agent_label_format_reviewer(self):
        """Reviewer agent generates 'Reviewer (model)' label."""
        result = self._run()
        self.assertIn("Reviewer (sonnet)", result["breakdown"])

    def test_agent_label_format_designer(self):
        """Designer agent generates 'Designer (opus)' label."""
        result = self._run()
        self.assertIn("Designer (opus)", result["breakdown"])

    def test_full_cli_output_is_valid_json(self):
        """End-to-end: run the module via its main function and get valid JSON."""
        import io
        from unittest.mock import patch

        captured = io.StringIO()
        with patch("sys.stdout", captured):
            cd.main([
                "--from-state", self.state_file,
                "--pricing", self.pricing_file,
                "--config", self.config_file,
            ])

        output = captured.getvalue()
        parsed = json.loads(output)
        self.assertIn("wall_clock_ms", parsed)
        self.assertIn("has_parallel", parsed)
        self.assertIn("breakdown", parsed)


# ──────────────────────────────────────────────────────────────────────────────
# Edge cases
# ──────────────────────────────────────────────────────────────────────────────

class TestEdgeCases(unittest.TestCase):

    def setUp(self):
        self.pricing_file = _write_json(PRICING_FIXTURE)
        self.config_file = _write_json({})

    def tearDown(self):
        for f in [self.pricing_file, self.config_file]:
            os.unlink(f)

    def test_empty_dispatches(self):
        pricing = cd.load_pricing(self.pricing_file, self.config_file)
        result = cd.compute_from_dispatches([], pricing)
        self.assertEqual(result["duration_ms"], "0")
        self.assertEqual(result["tokens"], "0")

    def test_single_dispatch_no_plural(self):
        """Single dispatch should not show '(1 stories)' in summary."""
        dispatches = [
            {"agent": "Builder (sonnet)", "model": "sonnet", "task": "S01", "duration_ms": 100000, "tokens": 30000, "phase": "Build"},
        ]
        pricing = cd.load_pricing(self.pricing_file, self.config_file)
        result = cd.compute_from_dispatches(dispatches, pricing)
        # Should not show "(1 stories)" — count suffix is only shown for >1
        self.assertNotIn("(1 stories)", result["summary"])
        self.assertNotIn("(1 dispatches)", result["summary"])

    def test_state_with_no_epics(self):
        """State file with no epics still generates valid output."""
        state_no_epics = {
            **STATE_FIXTURE,
            "epics": {},
            "dispatches": [
                {
                    "id": 1, "agent": "designer", "model": "opus",
                    "issue": 10, "started_at": "2026-03-15T10:00:00Z",
                    "duration_ms": 100000, "tokens": 10000,
                },
            ],
        }
        pricing = cd.load_pricing(self.pricing_file, self.config_file)
        result = cd.compute_from_state(state_no_epics, pricing)
        self.assertIn("Design Doc (#10)", result["breakdown"])

    def test_state_with_unknown_issue_falls_back_to_issue_number(self):
        """Build dispatch for issue not in epics generates 'Issue #N' label."""
        state = {
            **STATE_FIXTURE,
            "dispatches": [
                {
                    "id": 1, "agent": "builder-sonnet", "model": "sonnet",
                    "issue": 999, "started_at": "2026-03-15T10:00:00Z",
                    "duration_ms": 100000, "tokens": 10000,
                },
            ],
        }
        pricing = cd.load_pricing(self.pricing_file, self.config_file)
        result = cd.compute_from_state(state, pricing)
        self.assertIn("Issue #999", result["breakdown"])

    def test_retro_phase_mapping(self):
        """'retro' agent maps to 'Retro' phase."""
        state = {
            **STATE_FIXTURE,
            "dispatches": [
                {
                    "id": 1, "agent": "retro", "model": "opus",
                    "issue": 20, "started_at": "2026-03-15T10:00:00Z",
                    "duration_ms": 100000, "tokens": 10000,
                },
            ],
        }
        pricing = cd.load_pricing(self.pricing_file, self.config_file)
        result = cd.compute_from_state(state, pricing)
        self.assertIn("Retro", result["summary"])
        self.assertIn("Retrospective (#20)", result["breakdown"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
