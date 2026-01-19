#!/usr/bin/env python3
"""
Visual Analysis Module

For Claude Code Unified Session:
- This module provides screenshot listing and metadata extraction
- Claude Code performs actual visual analysis by reading images directly
- API-based analysis is optional and disabled by default

Usage in Claude Code workflow:
    python visual_analyzer.py /path/to/test_results --list-screenshots
    # Returns JSON list of screenshot paths for Claude Code to analyze
"""

import os
import sys
import json
import base64
import argparse
from pathlib import Path
from typing import List, Dict, Optional


class VisualAnalyzer:
    """Analyzes game screenshots - primarily for Claude Code unified session"""

    def __init__(self):
        """Initialize without requiring API key"""
        pass

    def list_screenshots(self, test_dir: Path) -> Dict:
        """
        List all screenshots in a test directory with metadata.

        This is the primary method for Claude Code unified session.
        Claude Code will read these images directly for analysis.
        """
        screenshots = sorted(test_dir.glob("*.png"))

        # Group by test (start/end pairs)
        test_pairs = {}
        for screenshot in screenshots:
            parts = screenshot.stem.split('_')
            if len(parts) >= 3:
                suffix = parts[-1]  # 'start' or 'end'
                test_name = '_'.join(parts[1:-1])
                if test_name not in test_pairs:
                    test_pairs[test_name] = {"start": None, "end": None}
                test_pairs[test_name][suffix] = str(screenshot)

        return {
            "test_dir": str(test_dir),
            "screenshot_count": len(screenshots),
            "screenshots": [str(s) for s in screenshots],
            "test_pairs": test_pairs,
            "tests": list(test_pairs.keys())
        }

    def get_movement_test_pairs(self, test_dir: Path) -> List[Dict]:
        """
        Get before/after screenshot pairs for movement tests.

        Returns list suitable for Claude Code to analyze.
        """
        info = self.list_screenshots(test_dir)
        pairs = []

        movement_tests = ['move_forward', 'move_backward', 'move_left', 'move_right', 'jump']

        for test_name, pair in info['test_pairs'].items():
            if pair['start'] and pair['end']:
                pairs.append({
                    "test_name": test_name,
                    "before": pair['start'],
                    "after": pair['end'],
                    "is_movement_test": test_name in movement_tests,
                    "expected": self._get_expected_movement(test_name)
                })

        return pairs

    def _get_expected_movement(self, test_name: str) -> str:
        """Get expected movement description for a test"""
        expectations = {
            "initial_position": "No movement - baseline capture",
            "move_forward": "Camera moves forward, objects appear closer",
            "move_backward": "Camera moves backward, objects appear further",
            "move_left": "Camera strafes left, scene shifts right",
            "move_right": "Camera strafes right, scene shifts left",
            "jump": "Camera rises then falls, floor distance changes",
            "turn_left": "Scene rotates clockwise",
            "turn_right": "Scene rotates counter-clockwise"
        }
        return expectations.get(test_name, f"Movement for {test_name}")

    def get_movement_fix_suggestion(self, test_name: str) -> str:
        """Generate specific fix suggestions based on test type"""
        suggestions = {
            "move_forward": "Check player.gd _physics_process: ensure velocity.z is set when move_forward action is pressed. Verify Input.is_action_pressed('move_forward') is being checked.",
            "move_backward": "Check player.gd _physics_process: ensure velocity.z is set when move_backward action is pressed.",
            "move_left": "Check player.gd _physics_process: ensure velocity.x is set when move_left action is pressed.",
            "move_right": "Check player.gd _physics_process: ensure velocity.x is set when move_right action is pressed.",
            "jump": "Check player.gd: ensure velocity.y is set to a positive jump value when jump is pressed AND player is_on_floor(). Verify CollisionShape3D is properly configured."
        }
        return suggestions.get(test_name, f"Review player.gd movement handling for {test_name}")

    def _generate_movement_summary(self, analyses: List[Dict],
                                   actionable_feedback: List[Dict]) -> str:
        """Generate summary of movement analysis"""
        if len(actionable_feedback) == 0:
            return "All movement tests passed visual verification."
        elif len(actionable_feedback) == 1:
            return f"1 movement issue detected: {actionable_feedback[0]['issue']} in {actionable_feedback[0]['test']}"
        else:
            test_names = [f['test'] for f in actionable_feedback]
            return f"{len(actionable_feedback)} movement issues detected in tests: {', '.join(test_names)}"


def main():
    parser = argparse.ArgumentParser(
        description="Visual Analysis Module for Claude Code",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # List screenshots for Claude Code to analyze:
  python visual_analyzer.py /path/to/test_results --list-screenshots

  # Get movement test pairs:
  python visual_analyzer.py /path/to/test_results --movement-pairs
        """
    )
    parser.add_argument("test_dir", type=str, help="Directory containing test screenshots and results")
    parser.add_argument("--output", type=str, default=None,
                       help="Output file for results (default: stdout for list modes)")
    parser.add_argument("--list-screenshots", action="store_true",
                       help="List screenshots for Claude Code to analyze directly")
    parser.add_argument("--movement-pairs", action="store_true",
                       help="List before/after pairs for movement tests")

    args = parser.parse_args()

    test_dir = Path(args.test_dir)
    if not test_dir.exists():
        print(f"Error: Test directory not found: {test_dir}", file=sys.stderr)
        sys.exit(1)

    analyzer = VisualAnalyzer()

    # List screenshots mode (for Claude Code)
    if args.list_screenshots:
        result = analyzer.list_screenshots(test_dir)
        output = json.dumps(result, indent=2)
        if args.output:
            Path(args.output).write_text(output)
            print(f"Screenshot list saved to: {args.output}")
        else:
            print(output)
        sys.exit(0)

    # Movement pairs mode (for Claude Code)
    if args.movement_pairs:
        pairs = analyzer.get_movement_test_pairs(test_dir)
        output = json.dumps(pairs, indent=2)
        if args.output:
            Path(args.output).write_text(output)
            print(f"Movement pairs saved to: {args.output}")
        else:
            print(output)
        sys.exit(0)

    # Default: show summary
    info = analyzer.list_screenshots(test_dir)
    print(f"Test directory: {test_dir}")
    print(f"Screenshots found: {info['screenshot_count']}")
    print(f"Tests: {', '.join(info['tests'])}")
    print("\nFor Claude Code workflow, use:")
    print(f"  python {sys.argv[0]} {test_dir} --list-screenshots")
    print(f"  python {sys.argv[0]} {test_dir} --movement-pairs")


if __name__ == "__main__":
    main()
