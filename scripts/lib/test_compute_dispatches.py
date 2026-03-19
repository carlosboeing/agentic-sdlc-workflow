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
# Story column tests (breakdown table)
# ──────────────────────────────────────────────────────────────────────────────

class TestBreakdownStoryColumn(unittest.TestCase):
    """Tests for the Story column in the breakdown table."""

    def setUp(self):
        self.pricing_file = _write_json(PRICING_FIXTURE)
        self.config_file = _write_json({})

    def tearDown(self):
        for f in [self.pricing_file, self.config_file]:
            os.unlink(f)

    def _pricing(self):
        return cd.load_pricing(self.pricing_file, self.config_file)

    def test_breakdown_has_six_columns(self):
        """Breakdown rows have 6 columns: Agent | Story | Task | Duration | Tokens | Est. Cost."""
        pricing = self._pricing()
        result = cd.compute_from_dispatches(DISPATCHES_FIXTURE, pricing)
        breakdown_lines = result["breakdown"].splitlines()
        # Each row should have exactly 6 pipe-delimited cells (7 pipe chars)
        for line in breakdown_lines:
            # Count pipes: "| a | b | c | d | e | f |" has 7 pipes
            pipe_count = line.count("|")
            self.assertEqual(
                pipe_count, 7,
                f"Expected 7 pipes (6 columns) in breakdown row, got {pipe_count}: {line!r}"
            )

    def test_breakdown_story_column_dash_for_non_story_phase(self):
        """Design/plan/retro dispatches show '--' in Story column."""
        dispatches_with_story_code = [
            {
                "agent": "Designer (opus)",
                "model": "opus",
                "task": "Design Doc (#55)",
                "duration_ms": 294973,
                "tokens": 86265,
                "phase": "Design",
                "story_code": "",  # Non-story dispatch: empty story_code
            },
        ]
        pricing = self._pricing()
        result = cd.compute_from_dispatches(dispatches_with_story_code, pricing)
        breakdown_lines = result["breakdown"].splitlines()
        # First line is the designer row, should have '--' in the Story column
        data_line = breakdown_lines[0]
        cells = [c.strip() for c in data_line.split("|") if c.strip()]
        # cells: [Agent, Story, Task, Duration, Tokens, Cost]
        story_cell = cells[1]
        self.assertEqual(story_cell, "--", f"Expected '--' in Story column, got: {story_cell!r}")

    def test_breakdown_story_column_shows_code_for_builder(self):
        """Builder dispatches with story_code show the code in Story column."""
        dispatches_with_story_code = [
            {
                "agent": "Builder (sonnet)",
                "model": "sonnet",
                "task": "Destination Profiles (#72)",
                "duration_ms": 146479,
                "tokens": 49691,
                "phase": "Build",
                "story_code": "E01-S01",
            },
        ]
        pricing = self._pricing()
        result = cd.compute_from_dispatches(dispatches_with_story_code, pricing)
        breakdown_lines = result["breakdown"].splitlines()
        data_line = breakdown_lines[0]
        cells = [c.strip() for c in data_line.split("|") if c.strip()]
        story_cell = cells[1]
        self.assertEqual(story_cell, "E01-S01", f"Expected 'E01-S01' in Story column, got: {story_cell!r}")

    def test_breakdown_story_column_shows_code_for_reviewer(self):
        """Reviewer dispatches with story_code show the code in Story column."""
        dispatches_with_story_code = [
            {
                "agent": "Reviewer (sonnet)",
                "model": "sonnet",
                "task": "Review Destination Profiles (#72)",
                "duration_ms": 72000,
                "tokens": 18000,
                "phase": "Review",
                "story_code": "E01-S01",
            },
        ]
        pricing = self._pricing()
        result = cd.compute_from_dispatches(dispatches_with_story_code, pricing)
        breakdown_lines = result["breakdown"].splitlines()
        data_line = breakdown_lines[0]
        cells = [c.strip() for c in data_line.split("|") if c.strip()]
        story_cell = cells[1]
        self.assertEqual(story_cell, "E01-S01", f"Expected 'E01-S01' in Story column, got: {story_cell!r}")

    def test_breakdown_story_column_dash_when_no_story_code_field(self):
        """Dispatches without story_code field (e.g., --dispatches mode) show '--'."""
        # DISPATCHES_FIXTURE has no story_code field
        pricing = self._pricing()
        result = cd.compute_from_dispatches(DISPATCHES_FIXTURE, pricing)
        breakdown_lines = result["breakdown"].splitlines()
        # All data rows (not the total row) should have '--' in Story column
        for line in breakdown_lines[:-1]:  # Exclude total row
            cells = [c.strip() for c in line.split("|") if c.strip()]
            story_cell = cells[1]
            self.assertEqual(
                story_cell, "--",
                f"Expected '--' in Story column for dispatch without story_code, got: {story_cell!r} in row: {line!r}"
            )

    def test_breakdown_total_row_has_empty_story_cell(self):
        """Total row has empty Story cell (not '--')."""
        pricing = self._pricing()
        result = cd.compute_from_dispatches(DISPATCHES_FIXTURE, pricing)
        breakdown_lines = result["breakdown"].splitlines()
        total_row = breakdown_lines[-1]
        self.assertIn("**Total (4 dispatches)**", total_row)
        # Total row Story cell should be empty
        cells = [c.strip() for c in total_row.split("|")]
        # Total row format: "| | **Total (N dispatches)** | **dur** | **tokens** | **cost** |"
        # pipe[0] = "", pipe[1] = "", pipe[2] = "**Total...**", pipe[3] = "**dur**", ...
        # cells after split: ["", "", "**Total...**", ...]
        # Story cell is index 2 (after the leading empty, then agent empty, then story)
        # Let's check the raw format directly:
        self.assertIn("| |", total_row, "Total row should start with empty Agent cell '| |'")

    def test_state_to_dispatches_has_story_code_field(self):
        """state_to_dispatches() attaches story_code to each dispatch."""
        dispatches = cd.state_to_dispatches(STATE_FIXTURE)
        for d in dispatches:
            self.assertIn("story_code", d, f"Dispatch missing story_code field: {d}")

    def test_state_to_dispatches_story_code_for_builder(self):
        """Builder dispatch for known story gets ENN-SNN story_code."""
        dispatches = cd.state_to_dispatches(STATE_FIXTURE)
        # Issue 72 is in e01-s01 → story_code = "E01-S01"
        builder_dispatch_72 = next(
            d for d in dispatches
            if d["phase"] == "Build" and "#72" in d["task"]
        )
        self.assertEqual(builder_dispatch_72["story_code"], "E01-S01")

    def test_state_to_dispatches_story_code_for_reviewer(self):
        """Reviewer dispatch for known story gets ENN-SNN story_code."""
        dispatches = cd.state_to_dispatches(STATE_FIXTURE)
        reviewer_dispatch = next(
            d for d in dispatches
            if d["phase"] == "Review"
        )
        self.assertEqual(reviewer_dispatch["story_code"], "E01-S01")

    def test_state_to_dispatches_story_code_empty_for_designer(self):
        """Designer dispatch gets empty story_code."""
        dispatches = cd.state_to_dispatches(STATE_FIXTURE)
        designer_dispatch = next(d for d in dispatches if d["phase"] == "Design")
        self.assertEqual(designer_dispatch["story_code"], "")

    def test_state_to_dispatches_story_code_empty_for_planner(self):
        """Planner dispatch gets empty story_code."""
        dispatches = cd.state_to_dispatches(STATE_FIXTURE)
        planner_dispatch = next(d for d in dispatches if d["phase"] == "Plan")
        self.assertEqual(planner_dispatch["story_code"], "")

    def test_state_to_dispatches_story_code_empty_for_retro(self):
        """Retro dispatch gets empty story_code."""
        state_with_retro = {
            **STATE_FIXTURE,
            "dispatches": [
                {
                    "id": 1, "agent": "retro", "model": "opus",
                    "issue": 80, "started_at": "2026-03-15T11:00:00Z",
                    "duration_ms": 180000, "tokens": 50000,
                },
            ],
        }
        dispatches = cd.state_to_dispatches(state_with_retro)
        retro_dispatch = next(d for d in dispatches if d["phase"] == "Retro")
        self.assertEqual(retro_dispatch["story_code"], "")

    def test_from_state_breakdown_shows_story_codes(self):
        """compute_from_state breakdown includes ENN-SNN codes in Story column for builders."""
        pricing = self._pricing()
        result = cd.compute_from_state(STATE_FIXTURE, pricing)
        # Issues 72 and 73 are in e01-s01 and e01-s02
        # Their breakdown rows should show E01-S01 and E01-S02
        self.assertTrue(
            "E01-S01" in result["breakdown"] or "E01-S02" in result["breakdown"],
            f"No story code found in breakdown:\n{result['breakdown']}"
        )

    def test_from_state_breakdown_shows_dash_for_designer(self):
        """compute_from_state breakdown shows '--' in Story column for designer."""
        pricing = self._pricing()
        result = cd.compute_from_state(STATE_FIXTURE, pricing)
        breakdown_lines = result["breakdown"].splitlines()
        designer_line = next(l for l in breakdown_lines if "Designer" in l)
        cells = [c.strip() for c in designer_line.split("|") if c.strip()]
        story_cell = cells[1]
        self.assertEqual(story_cell, "--", f"Expected '--' for designer Story cell, got: {story_cell!r}")


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


# ──────────────────────────────────────────────────────────────────────────────
# Fix cycle detection tests
# ──────────────────────────────────────────────────────────────────────────────

# State fixture with one fix cycle: issue 72 was built, reviewed, then re-built
# (fix cycle) and re-reviewed.
STATE_WITH_FIX_CYCLE = {
    **STATE_FIXTURE,
    "dispatches": [
        {
            "id": 1, "agent": "builder-sonnet", "model": "sonnet",
            "issue": 72, "started_at": "2026-03-15T10:00:00Z",
            "duration_ms": 146479, "tokens": 49691,
        },
        {
            "id": 2, "agent": "builder-sonnet", "model": "sonnet",
            "issue": 73, "started_at": "2026-03-15T10:00:00Z",
            "duration_ms": 193000, "tokens": 60000,
        },
        {
            "id": 3, "agent": "reviewer", "model": "sonnet",
            "issue": 72, "started_at": "2026-03-15T10:05:00Z",
            "duration_ms": 72000, "tokens": 18000,
        },
        {
            "id": 4, "agent": "reviewer", "model": "sonnet",
            "issue": 73, "started_at": "2026-03-15T10:05:00Z",
            "duration_ms": 65000, "tokens": 16000,
        },
        # Fix cycle: re-build issue 72 after review
        {
            "id": 5, "agent": "builder-sonnet", "model": "sonnet",
            "issue": 72, "started_at": "2026-03-15T10:08:00Z",
            "duration_ms": 120000, "tokens": 35000,
        },
        # Re-review issue 72 after fix
        {
            "id": 6, "agent": "reviewer", "model": "sonnet",
            "issue": 72, "started_at": "2026-03-15T10:10:00Z",
            "duration_ms": 55000, "tokens": 14000,
        },
    ],
}

# State fixture with two fix cycles on the same story (two re-builds)
STATE_WITH_TWO_FIX_CYCLES_SAME_STORY = {
    **STATE_FIXTURE,
    "dispatches": [
        {
            "id": 1, "agent": "builder-sonnet", "model": "sonnet",
            "issue": 72, "started_at": "2026-03-15T10:00:00Z",
            "duration_ms": 146479, "tokens": 49691,
        },
        {
            "id": 2, "agent": "reviewer", "model": "sonnet",
            "issue": 72, "started_at": "2026-03-15T10:05:00Z",
            "duration_ms": 72000, "tokens": 18000,
        },
        # First fix cycle
        {
            "id": 3, "agent": "builder-sonnet", "model": "sonnet",
            "issue": 72, "started_at": "2026-03-15T10:08:00Z",
            "duration_ms": 120000, "tokens": 35000,
        },
        {
            "id": 4, "agent": "reviewer", "model": "sonnet",
            "issue": 72, "started_at": "2026-03-15T10:10:00Z",
            "duration_ms": 55000, "tokens": 14000,
        },
        # Second fix cycle
        {
            "id": 5, "agent": "builder-sonnet", "model": "sonnet",
            "issue": 72, "started_at": "2026-03-15T10:12:00Z",
            "duration_ms": 90000, "tokens": 28000,
        },
        {
            "id": 6, "agent": "reviewer", "model": "sonnet",
            "issue": 72, "started_at": "2026-03-15T10:14:00Z",
            "duration_ms": 50000, "tokens": 12000,
        },
    ],
}

# State fixture with fix cycles on two different stories
STATE_WITH_FIX_CYCLES_TWO_STORIES = {
    **STATE_FIXTURE,
    "dispatches": [
        {
            "id": 1, "agent": "builder-sonnet", "model": "sonnet",
            "issue": 72, "started_at": "2026-03-15T10:00:00Z",
            "duration_ms": 146479, "tokens": 49691,
        },
        {
            "id": 2, "agent": "builder-sonnet", "model": "sonnet",
            "issue": 73, "started_at": "2026-03-15T10:00:00Z",
            "duration_ms": 193000, "tokens": 60000,
        },
        {
            "id": 3, "agent": "reviewer", "model": "sonnet",
            "issue": 72, "started_at": "2026-03-15T10:05:00Z",
            "duration_ms": 72000, "tokens": 18000,
        },
        {
            "id": 4, "agent": "reviewer", "model": "sonnet",
            "issue": 73, "started_at": "2026-03-15T10:05:00Z",
            "duration_ms": 65000, "tokens": 16000,
        },
        # Fix cycle on issue 72
        {
            "id": 5, "agent": "builder-sonnet", "model": "sonnet",
            "issue": 72, "started_at": "2026-03-15T10:08:00Z",
            "duration_ms": 120000, "tokens": 35000,
        },
        {
            "id": 6, "agent": "reviewer", "model": "sonnet",
            "issue": 72, "started_at": "2026-03-15T10:10:00Z",
            "duration_ms": 55000, "tokens": 14000,
        },
        # Fix cycle on issue 73
        {
            "id": 7, "agent": "builder-sonnet", "model": "sonnet",
            "issue": 73, "started_at": "2026-03-15T10:12:00Z",
            "duration_ms": 100000, "tokens": 30000,
        },
        {
            "id": 8, "agent": "reviewer", "model": "sonnet",
            "issue": 73, "started_at": "2026-03-15T10:14:00Z",
            "duration_ms": 60000, "tokens": 15000,
        },
    ],
}


class TestFixCycleDetection(unittest.TestCase):
    """Tests for fix cycle detection in compute_fix_cycles()."""

    def setUp(self):
        self.pricing_file = _write_json(PRICING_FIXTURE)
        self.config_file = _write_json({})

    def tearDown(self):
        for f in [self.pricing_file, self.config_file]:
            os.unlink(f)

    def _pricing(self):
        return cd.load_pricing(self.pricing_file, self.config_file)

    # ── Zero fix cycles ────────────────────────────────────────────────────────

    def test_no_fix_cycles_returns_none(self):
        """When no fix cycles exist, compute_fix_cycles returns None."""
        result = cd.compute_fix_cycles(STATE_FIXTURE["dispatches"], self._pricing())
        self.assertIsNone(result)

    def test_no_fix_cycles_absent_from_state_result(self):
        """When no fix cycles, fix_cycles key absent from compute_from_state output."""
        pricing = self._pricing()
        result = cd.compute_from_state(STATE_FIXTURE, pricing)
        self.assertNotIn("fix_cycles", result)

    def test_no_fix_cycles_no_fix_footer(self):
        """When no fix cycles, fix_footer absent from compute_from_state output."""
        pricing = self._pricing()
        result = cd.compute_from_state(STATE_FIXTURE, pricing)
        self.assertNotIn("fix_footer", result)

    def test_no_fix_cycles_no_fix_summary_row(self):
        """When no fix cycles, no Fix Cycles row in summary."""
        pricing = self._pricing()
        result = cd.compute_from_state(STATE_FIXTURE, pricing)
        self.assertNotIn("Fix Cycles", result["summary"])

    # ── One fix cycle ──────────────────────────────────────────────────────────

    def test_one_fix_cycle_count(self):
        """One re-build for an issue = count of 1."""
        pricing = self._pricing()
        result = cd.compute_fix_cycles(STATE_WITH_FIX_CYCLE["dispatches"], pricing)
        self.assertIsNotNone(result)
        self.assertEqual(result["count"], 1)

    def test_one_fix_cycle_stories_affected(self):
        """One story re-built = stories_affected of 1."""
        pricing = self._pricing()
        result = cd.compute_fix_cycles(STATE_WITH_FIX_CYCLE["dispatches"], pricing)
        self.assertEqual(result["stories_affected"], 1)

    def test_one_fix_cycle_duration_ms(self):
        """Fix cycle duration = sum of re-build + re-review duration_ms."""
        pricing = self._pricing()
        result = cd.compute_fix_cycles(STATE_WITH_FIX_CYCLE["dispatches"], pricing)
        # Re-build (id 5): 120000ms, re-review (id 6): 55000ms
        expected_duration = 120000 + 55000
        self.assertEqual(result["duration_ms"], expected_duration)

    def test_one_fix_cycle_tokens(self):
        """Fix cycle tokens = sum of re-build + re-review tokens."""
        pricing = self._pricing()
        result = cd.compute_fix_cycles(STATE_WITH_FIX_CYCLE["dispatches"], pricing)
        # Re-build (id 5): 35000 tokens, re-review (id 6): 14000 tokens
        expected_tokens = 35000 + 14000
        self.assertEqual(result["tokens"], expected_tokens)

    def test_one_fix_cycle_cost_is_numeric_string(self):
        """Fix cycle cost is a two-decimal string."""
        pricing = self._pricing()
        result = cd.compute_fix_cycles(STATE_WITH_FIX_CYCLE["dispatches"], pricing)
        cost = float(result["cost"])
        self.assertGreater(cost, 0)
        self.assertRegex(result["cost"], r"^\d+\.\d{2}$")

    def test_one_fix_cycle_rate_is_ratio_string(self):
        """Fix cycle rate = fix cycles / unique builder issues as string."""
        pricing = self._pricing()
        result = cd.compute_fix_cycles(STATE_WITH_FIX_CYCLE["dispatches"], pricing)
        # 1 fix cycle / 2 unique builder issues = 0.50
        rate = float(result["rate"])
        self.assertAlmostEqual(rate, 0.50, places=2)

    def test_one_fix_cycle_present_in_state_result(self):
        """When one fix cycle, fix_cycles key present in compute_from_state."""
        pricing = self._pricing()
        result = cd.compute_from_state(STATE_WITH_FIX_CYCLE, pricing)
        self.assertIn("fix_cycles", result)
        self.assertIsNotNone(result["fix_cycles"])

    # ── Two fix cycles on the same story ──────────────────────────────────────

    def test_two_fix_cycles_same_story_count(self):
        """Two re-builds for same issue = count of 2."""
        pricing = self._pricing()
        result = cd.compute_fix_cycles(
            STATE_WITH_TWO_FIX_CYCLES_SAME_STORY["dispatches"], pricing
        )
        self.assertEqual(result["count"], 2)

    def test_two_fix_cycles_same_story_stories_affected(self):
        """Two fix cycles on same issue = stories_affected of 1."""
        pricing = self._pricing()
        result = cd.compute_fix_cycles(
            STATE_WITH_TWO_FIX_CYCLES_SAME_STORY["dispatches"], pricing
        )
        self.assertEqual(result["stories_affected"], 1)

    def test_two_fix_cycles_same_story_duration(self):
        """Duration includes both fix cycle re-build+re-review pairs."""
        pricing = self._pricing()
        result = cd.compute_fix_cycles(
            STATE_WITH_TWO_FIX_CYCLES_SAME_STORY["dispatches"], pricing
        )
        # First fix cycle: 120000 + 55000, second: 90000 + 50000
        expected = 120000 + 55000 + 90000 + 50000
        self.assertEqual(result["duration_ms"], expected)

    # ── Fix cycles on two different stories ───────────────────────────────────

    def test_fix_cycles_two_stories_count(self):
        """One fix cycle per story = count of 2."""
        pricing = self._pricing()
        result = cd.compute_fix_cycles(
            STATE_WITH_FIX_CYCLES_TWO_STORIES["dispatches"], pricing
        )
        self.assertEqual(result["count"], 2)

    def test_fix_cycles_two_stories_stories_affected(self):
        """Fix cycles on two different stories = stories_affected of 2."""
        pricing = self._pricing()
        result = cd.compute_fix_cycles(
            STATE_WITH_FIX_CYCLES_TWO_STORIES["dispatches"], pricing
        )
        self.assertEqual(result["stories_affected"], 2)

    def test_fix_cycles_two_stories_rate(self):
        """Rate = 2 fix cycles / 2 unique builder issues = 1.00."""
        pricing = self._pricing()
        result = cd.compute_fix_cycles(
            STATE_WITH_FIX_CYCLES_TWO_STORIES["dispatches"], pricing
        )
        rate = float(result["rate"])
        self.assertAlmostEqual(rate, 1.00, places=2)

    # ── fix_footer field ──────────────────────────────────────────────────────

    def test_fix_footer_present_when_fix_cycles(self):
        """When fix cycles exist, fix_footer key present in output."""
        pricing = self._pricing()
        result = cd.compute_from_state(STATE_WITH_FIX_CYCLE, pricing)
        self.assertIn("fix_footer", result)

    def test_fix_footer_format(self):
        """fix_footer matches expected italic markdown format."""
        pricing = self._pricing()
        result = cd.compute_from_state(STATE_WITH_FIX_CYCLE, pricing)
        footer = result["fix_footer"]
        self.assertTrue(footer.startswith("*Fix cycles:"))
        self.assertIn("fix rate", footer)
        self.assertIn("adding", footer)
        self.assertIn("of total cost", footer)
        self.assertTrue(footer.endswith(".*"))

    def test_fix_footer_contains_correct_count(self):
        """fix_footer contains '1 / 2 stories' for one fix cycle over two stories."""
        pricing = self._pricing()
        result = cd.compute_from_state(STATE_WITH_FIX_CYCLE, pricing)
        self.assertIn("1 / 2 stories", result["fix_footer"])

    def test_fix_footer_contains_pct(self):
        """fix_footer contains '50%' fix rate for 1 cycle over 2 stories."""
        pricing = self._pricing()
        result = cd.compute_from_state(STATE_WITH_FIX_CYCLE, pricing)
        self.assertIn("50%", result["fix_footer"])

    # ── Fix cycle summary row ─────────────────────────────────────────────────

    def test_summary_has_fix_cycles_row(self):
        """Summary includes Fix Cycles row when fix cycles exist."""
        pricing = self._pricing()
        result = cd.compute_from_state(STATE_WITH_FIX_CYCLE, pricing)
        self.assertIn("Fix Cycles", result["summary"])

    def test_summary_fix_cycles_row_before_total(self):
        """Fix Cycles summary row appears before the Total row."""
        pricing = self._pricing()
        result = cd.compute_from_state(STATE_WITH_FIX_CYCLE, pricing)
        lines = result["summary"].splitlines()
        fix_idx = next(i for i, l in enumerate(lines) if "Fix Cycles" in l)
        total_idx = next(i for i, l in enumerate(lines) if "**Total**" in l)
        self.assertLess(fix_idx, total_idx)

    def test_summary_fix_cycles_row_format(self):
        """Fix Cycles summary row has pipe-delimited format with count and story info."""
        pricing = self._pricing()
        result = cd.compute_from_state(STATE_WITH_FIX_CYCLE, pricing)
        lines = result["summary"].splitlines()
        fix_row = next(l for l in lines if "Fix Cycles" in l)
        self.assertTrue(fix_row.startswith("|"))
        self.assertTrue(fix_row.endswith("|"))
        self.assertIn("1 cycle", fix_row)
        self.assertIn("1 story", fix_row)

    def test_summary_fix_cycles_row_plural(self):
        """Fix Cycles row uses plural 'cycles'/'stories' when count/affected > 1."""
        pricing = self._pricing()
        result = cd.compute_from_state(STATE_WITH_FIX_CYCLES_TWO_STORIES, pricing)
        lines = result["summary"].splitlines()
        fix_row = next(l for l in lines if "Fix Cycles" in l)
        self.assertIn("2 cycles", fix_row)
        self.assertIn("2 stories", fix_row)

    # ── Required fields in fix_cycles object ─────────────────────────────────

    def test_fix_cycles_object_has_required_fields(self):
        """fix_cycles object has count, duration_ms, cost, rate, stories_affected, tokens."""
        pricing = self._pricing()
        result = cd.compute_fix_cycles(STATE_WITH_FIX_CYCLE["dispatches"], pricing)
        for field in ["count", "duration_ms", "cost", "rate", "stories_affected", "tokens"]:
            self.assertIn(field, result, f"Missing field in fix_cycles: {field}")

    # ── CLI output includes fix_cycles ────────────────────────────────────────

    def test_cli_output_includes_fix_cycles_when_present(self):
        """End-to-end CLI output includes fix_cycles when fix cycles detected."""
        import io
        from unittest.mock import patch

        state_file = _write_json(STATE_WITH_FIX_CYCLE)
        pricing_file = _write_json(PRICING_FIXTURE)
        config_file = _write_json({})

        try:
            captured = io.StringIO()
            with patch("sys.stdout", captured):
                cd.main([
                    "--from-state", state_file,
                    "--pricing", pricing_file,
                    "--config", config_file,
                ])
            parsed = json.loads(captured.getvalue())
            self.assertIn("fix_cycles", parsed)
            self.assertEqual(parsed["fix_cycles"]["count"], 1)
        finally:
            for f in [state_file, pricing_file, config_file]:
                os.unlink(f)

    def test_cli_output_no_fix_cycles_key_when_absent(self):
        """End-to-end CLI output: fix_cycles absent when no fix cycles."""
        import io
        from unittest.mock import patch

        state_file = _write_json(STATE_FIXTURE)
        pricing_file = _write_json(PRICING_FIXTURE)
        config_file = _write_json({})

        try:
            captured = io.StringIO()
            with patch("sys.stdout", captured):
                cd.main([
                    "--from-state", state_file,
                    "--pricing", pricing_file,
                    "--config", config_file,
                ])
            parsed = json.loads(captured.getvalue())
            self.assertNotIn("fix_cycles", parsed)
        finally:
            for f in [state_file, pricing_file, config_file]:
                os.unlink(f)


# Gantt generation tests
# ──────────────────────────────────────────────────────────────────────────────

# State fixture for Gantt tests — extends STATE_FIXTURE with a retro dispatch
# and varied timing to exercise all tag and label scenarios
GANTT_STATE_FIXTURE = {
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
        # Designer at T+1m (60s offset)
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
        # Planner at T+6m (360s offset)
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
        # Parallel builders at T+12m (720s offset)
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
        # Sequential reviewer for issue 72
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
        # Fix cycle: builder re-dispatch for issue 72 (second builder for same issue)
        {
            "id": 6,
            "agent": "builder-sonnet",
            "model": "sonnet",
            "issue": 72,
            "started_at": "2026-03-15T10:18:00Z",
            "duration_ms": 90000,
            "tokens": 25000,
            "tool_uses": 10,
            "result": "success",
        },
        # Re-review: second reviewer for issue 72
        {
            "id": 7,
            "agent": "reviewer",
            "model": "sonnet",
            "issue": 72,
            "started_at": "2026-03-15T10:20:00Z",
            "duration_ms": 45000,
            "tokens": 12000,
            "tool_uses": 5,
            "result": "success",
        },
        # PR review: reviewer on backlog issue (not in any epic's stories)
        {
            "id": 8,
            "agent": "reviewer",
            "model": "sonnet",
            "issue": 69,
            "started_at": "2026-03-15T10:22:00Z",
            "duration_ms": 60000,
            "tokens": 15000,
            "tool_uses": 6,
            "result": "success",
        },
        # Retro at the end
        {
            "id": 9,
            "agent": "retro",
            "model": "opus",
            "issue": 80,
            "started_at": "2026-03-15T10:24:00Z",
            "duration_ms": 180000,
            "tokens": 50000,
            "tool_uses": 20,
            "result": "success",
        },
    ],
}


class TestGanttGeneration(unittest.TestCase):
    """Tests for generate_gantt() function."""

    def _generate(self, state=None):
        """Helper: run generate_gantt on GANTT_STATE_FIXTURE (or given state)."""
        if state is None:
            state = GANTT_STATE_FIXTURE
        return cd.generate_gantt(state)

    def test_returns_string(self):
        """generate_gantt returns a non-empty string."""
        result = self._generate()
        self.assertIsInstance(result, str)
        self.assertGreater(len(result), 0)

    def test_header_title(self):
        """Gantt body includes 'title Full Lifecycle Timeline'."""
        result = self._generate()
        self.assertIn("title Full Lifecycle Timeline", result)

    def test_header_date_format(self):
        """Gantt body includes 'dateFormat HH:mm:ss'."""
        result = self._generate()
        self.assertIn("dateFormat HH:mm:ss", result)

    def test_tick_interval_under_30m(self):
        """Under 30m total run duration → tickInterval 2minute."""
        state = {
            **GANTT_STATE_FIXTURE,
            "session": {**GANTT_STATE_FIXTURE["session"], "started_at": "2026-03-15T10:00:00Z"},
            "dispatches": [
                {
                    "id": 1, "agent": "builder-sonnet", "model": "sonnet",
                    "issue": 72, "started_at": "2026-03-15T10:00:00Z",
                    "duration_ms": 600000,  # 10m — session ends at T+10m
                    "tokens": 10000, "tool_uses": 5, "result": "success",
                },
            ],
        }
        result = self._generate(state)
        self.assertIn("tickInterval 2minute", result)

    def test_tick_interval_30_to_90m(self):
        """30-90m total run duration → tickInterval 5minute."""
        state = {
            **GANTT_STATE_FIXTURE,
            "session": {**GANTT_STATE_FIXTURE["session"], "started_at": "2026-03-15T10:00:00Z"},
            "dispatches": [
                {
                    "id": 1, "agent": "builder-sonnet", "model": "sonnet",
                    "issue": 72, "started_at": "2026-03-15T10:00:00Z",
                    "duration_ms": 2400000,  # 40m
                    "tokens": 10000, "tool_uses": 5, "result": "success",
                },
            ],
        }
        result = self._generate(state)
        self.assertIn("tickInterval 5minute", result)

    def test_tick_interval_90m_plus(self):
        """90m+ total run duration → tickInterval 10minute."""
        state = {
            **GANTT_STATE_FIXTURE,
            "session": {**GANTT_STATE_FIXTURE["session"], "started_at": "2026-03-15T10:00:00Z"},
            "dispatches": [
                {
                    "id": 1, "agent": "builder-sonnet", "model": "sonnet",
                    "issue": 72, "started_at": "2026-03-15T10:00:00Z",
                    "duration_ms": 6600000,  # 110m
                    "tokens": 10000, "tool_uses": 5, "result": "success",
                },
            ],
        }
        result = self._generate(state)
        self.assertIn("tickInterval 10minute", result)

    def test_task_ids_sequential(self):
        """Task IDs are t1, t2, t3, ... in chronological order."""
        result = self._generate()
        self.assertIn(":t1,", result)
        self.assertIn(":t2,", result)
        self.assertIn(":t3,", result)

    def test_absolute_offsets_not_after(self):
        """Tasks use absolute HH:MM:SS offsets, not 'after' syntax."""
        result = self._generate()
        self.assertNotIn("after ", result)
        # Verify HH:MM:SS format is present (00:01:00 = T+1min for designer)
        self.assertIn("00:01:00", result)

    def test_designer_offset(self):
        """Designer started_at = T+1min → offset 00:01:00."""
        result = self._generate()
        # Designer dispatch is at 10:01:00, session started at 10:00:00 → offset = 60s
        self.assertIn("00:01:00", result)

    def test_designer_color_tag_active(self):
        """Designer dispatch gets :active color tag."""
        result = self._generate()
        self.assertIn(":active,", result)
        # The designer label line should contain :active
        designer_lines = [l for l in result.splitlines() if "Designer" in l]
        self.assertTrue(len(designer_lines) > 0, "No designer lines found in Gantt")
        self.assertTrue(
            any(":active," in l for l in designer_lines),
            f"No :active tag on designer line. Lines: {designer_lines}"
        )

    def test_planner_color_tag_active(self):
        """Planner dispatch gets :active color tag."""
        result = self._generate()
        planner_lines = [l for l in result.splitlines() if "Planner" in l]
        self.assertTrue(len(planner_lines) > 0, "No planner lines found in Gantt")
        self.assertTrue(
            any(":active," in l for l in planner_lines),
            f"No :active tag on planner line. Lines: {planner_lines}"
        )

    def test_builder_no_color_tag(self):
        """Builder dispatches have no color tag (emerald)."""
        result = self._generate()
        # Find a "Build" line that is NOT a fix cycle (first build for issue 73)
        build_lines = [l for l in result.splitlines() if "Build" in l and "Fix" not in l]
        # At least one non-fix build should have no color tag (no colon before task ID)
        # Format: "    Label (dur)  :tN, HH:MM:SS, Xs"
        # Tag-free format: no extra colon before tN
        has_no_tag = any(
            # The pattern for tag-free: "  Label (dur)  :tN, ..." without extra ":done," or ":active," or ":crit,"
            not any(tag in l for tag in [":active,", ":done,", ":crit,"])
            for l in build_lines
        )
        self.assertTrue(has_no_tag, f"Expected at least one tag-free build line. Build lines: {build_lines}")

    def test_reviewer_color_tag_done(self):
        """First reviewer dispatch (not re-review) gets :done color tag."""
        result = self._generate()
        review_lines = [l for l in result.splitlines() if "Review" in l]
        self.assertTrue(len(review_lines) > 0, "No review lines found in Gantt")
        self.assertTrue(
            any(":done," in l for l in review_lines),
            f"No :done tag on any review line. Lines: {review_lines}"
        )

    def test_retro_color_tag_active(self):
        """Retro dispatch gets :active color tag."""
        result = self._generate()
        retro_lines = [l for l in result.splitlines() if "Retro" in l]
        self.assertTrue(len(retro_lines) > 0, "No retro lines found in Gantt")
        self.assertTrue(
            any(":active," in l for l in retro_lines),
            f"No :active tag on retro line. Lines: {retro_lines}"
        )

    def test_fix_cycle_builder_color_tag_crit(self):
        """Second builder dispatch for same issue gets :crit tag (Fix label)."""
        result = self._generate()
        fix_lines = [l for l in result.splitlines() if "Fix" in l]
        self.assertTrue(len(fix_lines) > 0, "No Fix lines found in Gantt")
        self.assertTrue(
            any(":crit," in l for l in fix_lines),
            f"No :crit tag on fix line. Lines: {fix_lines}"
        )

    def test_fix_cycle_reviewer_label_rereview(self):
        """Second reviewer dispatch for same issue gets 'Re-review' label."""
        result = self._generate()
        self.assertIn("Re-review", result)

    def test_fix_cycle_reviewer_color_tag_crit(self):
        """Second reviewer dispatch for same issue gets :crit tag."""
        result = self._generate()
        rereview_lines = [l for l in result.splitlines() if "Re-review" in l]
        self.assertTrue(len(rereview_lines) > 0, "No Re-review lines found in Gantt")
        self.assertTrue(
            any(":crit," in l for l in rereview_lines),
            f"No :crit tag on re-review line. Lines: {rereview_lines}"
        )

    def test_pr_review_label(self):
        """Reviewer dispatch where issue not in any epic's stories → 'PR Review' label."""
        result = self._generate()
        self.assertIn("PR Review", result)

    def test_builder_label_includes_enn_snn(self):
        """Build tasks include story code like E01-S01."""
        result = self._generate()
        # Issues 72 and 73 are in epic e01
        # Their branches are e01-s01/destination-profiles and e01-s02/travel-advisory
        self.assertTrue(
            "E01-S01" in result or "E01-S02" in result,
            "No E01-SNN label found in Gantt"
        )

    def test_builder_label_format(self):
        """Build task label follows '<ENN-SNN> Build (<dur>)' format."""
        result = self._generate()
        # Match e.g. "E01-S02 Build (3m 13s)" for issue 73 (193000 ms = 3m 13s)
        import re
        build_pattern = re.compile(r'E\d\d-S\d\d Build \(\d+[ms]')
        build_lines = [l for l in result.splitlines() if re.search(build_pattern, l)]
        self.assertTrue(len(build_lines) > 0, f"No labeled Build lines found in:\n{result}")

    def test_fix_label_format(self):
        """Fix task label follows '<ENN-SNN> Fix (<dur>)' format."""
        result = self._generate()
        import re
        fix_pattern = re.compile(r'E\d\d-S\d\d Fix \(\d+[ms]')
        fix_lines = [l for l in result.splitlines() if re.search(fix_pattern, l)]
        self.assertTrue(len(fix_lines) > 0, f"No labeled Fix lines found in:\n{result}")

    def test_designer_label_format(self):
        """Designer task label follows 'Designer (<dur>)' format."""
        result = self._generate()
        import re
        designer_pattern = re.compile(r'Designer \(\d+[ms]')
        designer_lines = [l for l in result.splitlines() if re.search(designer_pattern, l)]
        self.assertTrue(len(designer_lines) > 0, f"No Designer lines found in:\n{result}")

    def test_planner_label_format(self):
        """Planner task label follows 'Planner (<dur>)' format."""
        result = self._generate()
        import re
        planner_pattern = re.compile(r'Planner \(\d+[ms]')
        planner_lines = [l for l in result.splitlines() if re.search(planner_pattern, l)]
        self.assertTrue(len(planner_lines) > 0, f"No Planner lines found in:\n{result}")

    def test_duration_in_seconds_format(self):
        """Duration in task line is rendered in seconds (e.g. '294s')."""
        result = self._generate()
        # designer: 294973ms = 294s
        self.assertIn("294s", result)

    def test_no_section_directives(self):
        """Gantt output does not include 'section' directives per project convention."""
        result = self._generate()
        self.assertNotIn("section", result)

    def test_parallel_tolerance_within_5s(self):
        """Dispatches within 5 seconds of each other share the same Gantt offset (parallel wave)."""
        state = {
            **GANTT_STATE_FIXTURE,
            "session": {**GANTT_STATE_FIXTURE["session"], "started_at": "2026-03-15T10:00:00Z"},
            "dispatches": [
                {
                    "id": 1, "agent": "builder-sonnet", "model": "sonnet",
                    "issue": 72, "started_at": "2026-03-15T10:05:00Z",
                    "duration_ms": 120000, "tokens": 10000, "tool_uses": 5, "result": "success",
                },
                # 3 seconds later — within 5s tolerance window, should be parallel
                {
                    "id": 2, "agent": "builder-sonnet", "model": "sonnet",
                    "issue": 73, "started_at": "2026-03-15T10:05:03Z",
                    "duration_ms": 150000, "tokens": 12000, "tool_uses": 6, "result": "success",
                },
            ],
        }
        result = self._generate(state)
        # Both tasks should have the same starting offset (from id 1's timestamp)
        # 10:05:00 - 10:00:00 = 300s → 00:05:00
        # Both should have offset 00:05:00 (tolerance: id 2 is only 3s later)
        task_lines = [l for l in result.splitlines() if ":t1," in l or ":t2," in l]
        self.assertEqual(len(task_lines), 2, f"Expected 2 task lines, found: {task_lines}")
        # Both should use the same offset (the earlier one: 00:05:00)
        self.assertTrue(
            all("00:05:00" in l for l in task_lines),
            f"Expected both tasks to use 00:05:00 offset. Lines: {task_lines}"
        )

    def test_parallel_tolerance_beyond_5s_sequential(self):
        """Dispatches more than 5 seconds apart are treated as sequential."""
        state = {
            **GANTT_STATE_FIXTURE,
            "session": {**GANTT_STATE_FIXTURE["session"], "started_at": "2026-03-15T10:00:00Z"},
            "dispatches": [
                {
                    "id": 1, "agent": "builder-sonnet", "model": "sonnet",
                    "issue": 72, "started_at": "2026-03-15T10:05:00Z",
                    "duration_ms": 120000, "tokens": 10000, "tool_uses": 5, "result": "success",
                },
                # 10 seconds later — beyond 5s tolerance, should be sequential (different offset)
                {
                    "id": 2, "agent": "builder-sonnet", "model": "sonnet",
                    "issue": 73, "started_at": "2026-03-15T10:05:10Z",
                    "duration_ms": 150000, "tokens": 12000, "tool_uses": 6, "result": "success",
                },
            ],
        }
        result = self._generate(state)
        # t1 should use 00:05:00, t2 should use 00:05:10 (different offsets)
        t1_lines = [l for l in result.splitlines() if ":t1," in l]
        t2_lines = [l for l in result.splitlines() if ":t2," in l]
        self.assertEqual(len(t1_lines), 1)
        self.assertEqual(len(t2_lines), 1)
        self.assertIn("00:05:00", t1_lines[0])
        self.assertIn("00:05:10", t2_lines[0])

    def test_dispatches_sorted_by_started_at_then_id(self):
        """Dispatches are sorted by started_at first, then by id for stable ordering."""
        state = {
            **GANTT_STATE_FIXTURE,
            "session": {**GANTT_STATE_FIXTURE["session"], "started_at": "2026-03-15T10:00:00Z"},
            "dispatches": [
                # Later timestamp
                {
                    "id": 1, "agent": "builder-sonnet", "model": "sonnet",
                    "issue": 73, "started_at": "2026-03-15T10:05:00Z",
                    "duration_ms": 120000, "tokens": 10000, "tool_uses": 5, "result": "success",
                },
                # Earlier timestamp — should appear first despite higher id
                {
                    "id": 2, "agent": "designer", "model": "opus",
                    "issue": 71, "started_at": "2026-03-15T10:02:00Z",
                    "duration_ms": 300000, "tokens": 50000, "tool_uses": 20, "result": "success",
                },
            ],
        }
        result = self._generate(state)
        # t1 should be the designer (earlier timestamp), t2 should be the builder
        t1_lines = [l for l in result.splitlines() if ":t1," in l]
        t2_lines = [l for l in result.splitlines() if ":t2," in l]
        self.assertEqual(len(t1_lines), 1)
        self.assertEqual(len(t2_lines), 1)
        self.assertIn("Designer", t1_lines[0], "t1 should be the designer (earlier)")
        # t2 should be the builder
        self.assertTrue("Build" in t2_lines[0] or "Fix" in t2_lines[0], "t2 should be a builder")

    def test_no_dispatches_returns_header_only(self):
        """Empty dispatches list returns Gantt header only."""
        state = {
            **GANTT_STATE_FIXTURE,
            "session": {**GANTT_STATE_FIXTURE["session"], "started_at": "2026-03-15T10:00:00Z"},
            "dispatches": [],
        }
        result = self._generate(state)
        self.assertIn("title Full Lifecycle Timeline", result)
        self.assertIn("dateFormat HH:mm:ss", result)

    def test_offset_format_is_hhmmss(self):
        """Offsets are in HH:MM:SS format."""
        result = self._generate()
        import re
        # Should find at least one HH:MM:SS offset
        offset_pattern = re.compile(r'\b\d{2}:\d{2}:\d{2}\b')
        matches = offset_pattern.findall(result)
        self.assertTrue(len(matches) > 0, "No HH:MM:SS offsets found in Gantt")


class TestGanttCLI(unittest.TestCase):
    """Tests for --gantt flag in the CLI entry point."""

    def setUp(self):
        self.state_file = _write_json(GANTT_STATE_FIXTURE)
        self.pricing_file = _write_json(PRICING_FIXTURE)
        self.config_file = _write_json({})

    def tearDown(self):
        for f in [self.state_file, self.pricing_file, self.config_file]:
            os.unlink(f)

    def _run_cli(self, extra_args=None):
        """Run main() with --from-state and optional extra args, capture JSON output."""
        import io
        from unittest.mock import patch

        args = [
            "--from-state", self.state_file,
            "--pricing", self.pricing_file,
            "--config", self.config_file,
        ]
        if extra_args:
            args.extend(extra_args)

        captured = io.StringIO()
        with patch("sys.stdout", captured):
            cd.main(args)

        return json.loads(captured.getvalue())

    def test_gantt_flag_adds_gantt_field(self):
        """--gantt flag causes output to include 'gantt' field."""
        result = self._run_cli(["--gantt"])
        self.assertIn("gantt", result)
        self.assertIsInstance(result["gantt"], str)
        self.assertGreater(len(result["gantt"]), 0)

    def test_without_gantt_flag_no_gantt_field(self):
        """Without --gantt, output does not include 'gantt' field."""
        result = self._run_cli()
        self.assertNotIn("gantt", result)

    def test_gantt_without_from_state_exits_error(self):
        """--gantt without --from-state exits with error."""
        dispatches_file = _write_json([
            {"agent": "Builder (sonnet)", "model": "sonnet", "task": "S01",
             "duration_ms": 100000, "tokens": 30000, "phase": "Build"},
        ])
        try:
            import io
            from unittest.mock import patch

            captured = io.StringIO()
            with self.assertRaises(SystemExit) as cm:
                with patch("sys.stderr", io.StringIO()):
                    cd.main([
                        "--dispatches", dispatches_file,
                        "--gantt",
                        "--pricing", self.pricing_file,
                        "--config", self.config_file,
                    ])
            self.assertNotEqual(cm.exception.code, 0)
        finally:
            os.unlink(dispatches_file)

    def test_gantt_output_contains_mermaid_content(self):
        """--gantt output's 'gantt' field contains valid Mermaid Gantt content."""
        result = self._run_cli(["--gantt"])
        gantt = result["gantt"]
        self.assertIn("title Full Lifecycle Timeline", gantt)
        self.assertIn("dateFormat HH:mm:ss", gantt)

    def test_gantt_does_not_affect_other_fields(self):
        """--gantt flag does not change the breakdown/summary/cost/duration_ms fields."""
        without_gantt = self._run_cli()
        with_gantt = self._run_cli(["--gantt"])

        for field in ["breakdown", "summary", "cost", "duration_ms", "tokens", "wall_clock_ms"]:
            self.assertEqual(
                without_gantt[field], with_gantt[field],
                f"Field '{field}' differs with/without --gantt"
            )


# ──────────────────────────────────────────────────────────────────────────────
# Overhead computation tests
# ──────────────────────────────────────────────────────────────────────────────

# Wall-clock for STATE_FIXTURE:
# designer:  10:01-10:06 = 294973ms  → wave 1
# planner:   10:06-10:11 = 300000ms  → wave 2
# builders:  10:12 parallel, max(146479, 193000) = 193000ms  → wave 3
# reviewer:  10:16 = 72000ms  → wave 4
# wall_clock = 294973 + 300000 + 193000 + 72000 = 859973ms


def _make_overhead_state(overhead_duration_ms=None, lifecycle_duration_ms=None):
    """
    Build a state fixture for overhead tests by extending STATE_FIXTURE.

    Args:
        overhead_duration_ms: value for state.overhead.duration_ms (None = unset)
        lifecycle_duration_ms: value for session.lifecycle_duration_ms (None = unset)
    """
    state = {
        **STATE_FIXTURE,
        "session": {**STATE_FIXTURE["session"]},
        "overhead": {"duration_ms": overhead_duration_ms, "estimated_cost": None},
    }
    if lifecycle_duration_ms is not None:
        state["session"]["lifecycle_duration_ms"] = lifecycle_duration_ms
    return state


class TestComputeOverhead(unittest.TestCase):
    """Unit tests for compute_overhead() function."""

    def _pricing(self):
        return cd.load_pricing("/dev/null", "/dev/null")

    # Wall-clock for STATE_FIXTURE dispatches (computed from started_at grouping):
    #   wave 1 (10:01): 294973ms
    #   wave 2 (10:06): 300000ms
    #   wave 3 (10:12): max(146479, 193000) = 193000ms
    #   wave 4 (10:16): 72000ms
    #   wall_clock_ms = 859973ms
    WALL_CLOCK_MS = 859973

    def test_overhead_direct_from_state_overhead_field(self):
        """When state.overhead.duration_ms is set, use that value directly."""
        state = _make_overhead_state(overhead_duration_ms=120000)
        result = cd.compute_overhead(state)
        self.assertEqual(result["overhead_ms"], 120000)

    def test_overhead_zero_from_state_is_valid(self):
        """overhead.duration_ms = 0 is a valid direct value (not treated as missing)."""
        state = _make_overhead_state(overhead_duration_ms=0)
        result = cd.compute_overhead(state)
        self.assertEqual(result["overhead_ms"], 0)

    def test_overhead_fallback_from_lifecycle_duration(self):
        """When overhead.duration_ms is null, compute lifecycle_duration_ms - wall_clock_ms."""
        lifecycle_ms = self.WALL_CLOCK_MS + 50000  # 50s overhead
        state = _make_overhead_state(overhead_duration_ms=None, lifecycle_duration_ms=lifecycle_ms)
        result = cd.compute_overhead(state)
        self.assertEqual(result["overhead_ms"], 50000)

    def test_overhead_clamped_to_zero_when_negative(self):
        """Overhead clamped to 0 when lifecycle_duration_ms < wall_clock_ms (clock skew)."""
        lifecycle_ms = self.WALL_CLOCK_MS - 5000  # would be negative
        state = _make_overhead_state(overhead_duration_ms=None, lifecycle_duration_ms=lifecycle_ms)
        result = cd.compute_overhead(state)
        self.assertEqual(result["overhead_ms"], 0)

    def test_overhead_null_when_neither_field_set(self):
        """When neither overhead.duration_ms nor lifecycle_duration_ms is set, overhead_ms is null."""
        state = {
            **STATE_FIXTURE,
            "session": {**STATE_FIXTURE["session"]},
            # No "overhead" key, no lifecycle_duration_ms
        }
        result = cd.compute_overhead(state)
        self.assertIsNone(result["overhead_ms"])

    def test_overhead_null_when_overhead_key_missing(self):
        """Missing 'overhead' key in state → overhead_ms is null (no lifecycle fallback either)."""
        state = {**STATE_FIXTURE}
        # STATE_FIXTURE has no overhead key and no lifecycle_duration_ms
        result = cd.compute_overhead(state)
        self.assertIsNone(result["overhead_ms"])

    def test_overhead_row_present_when_computable(self):
        """overhead_row is a non-empty string when overhead_ms is computable."""
        state = _make_overhead_state(overhead_duration_ms=120000)
        result = cd.compute_overhead(state)
        self.assertIsNotNone(result["overhead_row"])
        self.assertIsInstance(result["overhead_row"], str)
        self.assertGreater(len(result["overhead_row"]), 0)

    def test_overhead_row_null_when_overhead_ms_null(self):
        """overhead_row is null when overhead_ms is null."""
        state = {**STATE_FIXTURE}
        result = cd.compute_overhead(state)
        self.assertIsNone(result["overhead_row"])

    def test_overhead_row_format(self):
        """overhead_row matches the expected markdown table row format."""
        state = _make_overhead_state(overhead_duration_ms=750000)  # 12m 30s
        result = cd.compute_overhead(state)
        row = result["overhead_row"]
        # Must be a pipe-delimited markdown table row
        self.assertTrue(row.startswith("| "), f"Row should start with '| ', got: {row!r}")
        self.assertTrue(row.endswith(" |"), f"Row should end with ' |', got: {row!r}")
        # Must contain "Orchestrator"
        self.assertIn("Orchestrator", row)
        # Must contain the formatted duration (12m 30s)
        self.assertIn("12m 30s", row)
        # Must contain dash placeholders for tokens and cost
        self.assertIn("---", row)

    def test_overhead_row_duration_formatting(self):
        """overhead_row uses fmt_duration for the duration column."""
        state = _make_overhead_state(overhead_duration_ms=62000)  # 1m 2s
        result = cd.compute_overhead(state)
        self.assertIn("1m 2s", result["overhead_row"])

    def test_overhead_zero_row_shows_zero_duration(self):
        """When overhead_ms is 0, overhead_row still renders with '0s' duration."""
        state = _make_overhead_state(overhead_duration_ms=0)
        result = cd.compute_overhead(state)
        self.assertIsNotNone(result["overhead_row"])
        self.assertIn("0s", result["overhead_row"])

    def test_overhead_no_overhead_key_with_lifecycle_fallback(self):
        """No 'overhead' key but lifecycle_duration_ms set → uses fallback computation."""
        lifecycle_ms = self.WALL_CLOCK_MS + 30000
        state = {
            **STATE_FIXTURE,
            "session": {
                **STATE_FIXTURE["session"],
                "lifecycle_duration_ms": lifecycle_ms,
            },
            # No "overhead" key at all
        }
        result = cd.compute_overhead(state)
        self.assertEqual(result["overhead_ms"], 30000)


class TestOverheadCLI(unittest.TestCase):
    """Tests for --overhead flag in the CLI entry point."""

    def setUp(self):
        self.pricing_file = _write_json(PRICING_FIXTURE)
        self.config_file = _write_json({})

    def tearDown(self):
        for f in [self.pricing_file, self.config_file]:
            os.unlink(f)

    def _run_cli(self, state, extra_args=None):
        """Write state to temp file, run main() with --from-state and --overhead."""
        import io
        from unittest.mock import patch

        state_file = _write_json(state)
        try:
            args = [
                "--from-state", state_file,
                "--pricing", self.pricing_file,
                "--config", self.config_file,
                "--overhead",
            ]
            if extra_args:
                args.extend(extra_args)

            captured = io.StringIO()
            with patch("sys.stdout", captured):
                cd.main(args)
            return json.loads(captured.getvalue())
        finally:
            os.unlink(state_file)

    def test_overhead_flag_adds_overhead_ms_to_output(self):
        """--overhead adds overhead_ms field to JSON output."""
        state = _make_overhead_state(overhead_duration_ms=90000)
        result = self._run_cli(state)
        self.assertIn("overhead_ms", result)

    def test_overhead_flag_adds_overhead_row_to_output(self):
        """--overhead adds overhead_row field to JSON output."""
        state = _make_overhead_state(overhead_duration_ms=90000)
        result = self._run_cli(state)
        self.assertIn("overhead_row", result)

    def test_overhead_flag_direct_value(self):
        """--overhead with state.overhead.duration_ms uses that value."""
        state = _make_overhead_state(overhead_duration_ms=90000)
        result = self._run_cli(state)
        self.assertEqual(result["overhead_ms"], 90000)

    def test_overhead_flag_fallback_value(self):
        """--overhead with lifecycle fallback computes correctly."""
        wall_clock_ms = 859973  # STATE_FIXTURE wall-clock
        lifecycle_ms = wall_clock_ms + 45000
        state = _make_overhead_state(overhead_duration_ms=None, lifecycle_duration_ms=lifecycle_ms)
        result = self._run_cli(state)
        self.assertEqual(result["overhead_ms"], 45000)

    def test_overhead_flag_null_when_no_data(self):
        """--overhead with no overhead or lifecycle data yields null overhead_ms."""
        result = self._run_cli(STATE_FIXTURE)  # no overhead key, no lifecycle_duration_ms
        self.assertIsNone(result["overhead_ms"])
        self.assertIsNone(result["overhead_row"])

    def test_overhead_without_from_state_exits_error(self):
        """--overhead without --from-state exits with a non-zero error code."""
        import io
        from unittest.mock import patch

        dispatches_file = _write_json([
            {"agent": "Builder (sonnet)", "model": "sonnet", "task": "S01",
             "duration_ms": 100000, "tokens": 30000, "phase": "Build"},
        ])
        try:
            with self.assertRaises(SystemExit) as cm:
                with patch("sys.stderr", io.StringIO()):
                    cd.main([
                        "--dispatches", dispatches_file,
                        "--overhead",
                        "--pricing", self.pricing_file,
                        "--config", self.config_file,
                    ])
            self.assertNotEqual(cm.exception.code, 0)
        finally:
            os.unlink(dispatches_file)

    def test_overhead_does_not_affect_other_fields(self):
        """--overhead flag does not change breakdown/summary/cost/duration_ms/wall_clock_ms."""
        import io
        from unittest.mock import patch

        state = _make_overhead_state(overhead_duration_ms=90000)
        state_file = _write_json(state)
        try:
            # Without --overhead
            args_base = [
                "--from-state", state_file,
                "--pricing", self.pricing_file,
                "--config", self.config_file,
            ]
            captured = io.StringIO()
            with patch("sys.stdout", captured):
                cd.main(args_base)
            without = json.loads(captured.getvalue())

            # With --overhead
            captured = io.StringIO()
            with patch("sys.stdout", captured):
                cd.main(args_base + ["--overhead"])
            with_oh = json.loads(captured.getvalue())

            for field in ["breakdown", "summary", "cost", "duration_ms", "tokens", "wall_clock_ms"]:
                self.assertEqual(
                    without[field], with_oh[field],
                    f"Field '{field}' differs with/without --overhead"
                )
        finally:
            os.unlink(state_file)


if __name__ == "__main__":
    unittest.main(verbosity=2)
