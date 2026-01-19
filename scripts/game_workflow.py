#!/usr/bin/env python3
"""
Unified Claude Code Game Development Workflow

This script provides helper functions for the Claude Code unified session workflow.
Claude Code generates game files directly, then uses this to run tests and collect feedback.

Workflow:
1. Claude Code writes game files to a build directory
2. Run: python game_workflow.py test <build_dir>
3. Claude Code reads results and screenshots
4. Claude Code fixes issues and repeats

Example session:
    # Claude Code creates files in code/my_game/
    # Then run tests:
    python game_workflow.py test code/my_game

    # View results:
    python game_workflow.py results code/my_game

    # List screenshots for analysis:
    python game_workflow.py screenshots code/my_game
"""

import sys
import json
import argparse
from pathlib import Path
from datetime import datetime

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent))

from orchestrator import GameDevOrchestrator
from visual_analyzer import VisualAnalyzer


def cmd_test(args):
    """Run tests on a build directory"""
    workspace_root = Path(__file__).parent.parent
    orchestrator = GameDevOrchestrator(workspace_root)

    build_dir = Path(args.build_dir)
    if not build_dir.is_absolute():
        build_dir = workspace_root / args.build_dir

    result = orchestrator.run_tests_only(build_dir)

    # Output as JSON for Claude Code to parse
    if args.json:
        print(json.dumps(result, indent=2))

    return 0 if not result.get('feedback', {}).get('has_issues') else 1


def cmd_results(args):
    """Show results from a previous test run"""
    build_dir = Path(args.build_dir)

    # Look for test_feedback.json
    feedback_file = build_dir / "test_feedback.json"
    if feedback_file.exists():
        with open(feedback_file) as f:
            result = json.load(f)
        print(json.dumps(result, indent=2))
        return 0

    print(f"No test results found in {build_dir}", file=sys.stderr)
    return 1


def cmd_screenshots(args):
    """List screenshots from test results"""
    workspace_root = Path(__file__).parent.parent

    build_dir = Path(args.build_dir)
    if not build_dir.is_absolute():
        build_dir = workspace_root / args.build_dir

    # Find test run directory
    tests_dir = workspace_root / "tests"
    test_runs = sorted(tests_dir.glob(f"{build_dir.name}_*"))

    if not test_runs:
        print(f"No test runs found for {build_dir.name}", file=sys.stderr)
        return 1

    test_run_dir = test_runs[-1]  # Most recent
    analyzer = VisualAnalyzer()

    if args.pairs:
        # Get movement test pairs
        pairs = analyzer.get_movement_test_pairs(test_run_dir)
        print(json.dumps(pairs, indent=2))
    else:
        # List all screenshots
        info = analyzer.list_screenshots(test_run_dir)
        print(json.dumps(info, indent=2))

    return 0


def cmd_create(args):
    """Create a new build directory"""
    workspace_root = Path(__file__).parent.parent
    code_dir = workspace_root / "code"

    build_name = args.name or f"build_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    build_dir = code_dir / build_name
    build_dir.mkdir(parents=True, exist_ok=True)

    print(f"Created: {build_dir}")
    print("\nRequired files for Claude Code to generate:")
    print("  - project.godot  (Godot project configuration)")
    print("  - main.tscn      (Main scene file)")
    print("  - main.gd        (Main script)")
    print("  - player.gd      (Player controller script)")

    return 0


def cmd_feedback(args):
    """Get formatted feedback for next iteration"""
    build_dir = Path(args.build_dir)

    feedback_file = build_dir / "test_feedback.json"
    if not feedback_file.exists():
        print("No feedback file found. Run tests first.", file=sys.stderr)
        return 1

    with open(feedback_file) as f:
        result = json.load(f)

    feedback = result.get('feedback', {})

    if not feedback.get('has_issues'):
        print("No issues found - build successful!")
        return 0

    # Format feedback for Claude Code to use
    lines = ["ISSUES FROM PREVIOUS TEST RUN:", ""]

    if feedback.get('movement_issues'):
        lines.append("Movement Issues:")
        for issue in feedback['movement_issues']:
            if isinstance(issue, dict):
                lines.append(f"  - {issue.get('test', 'unknown')}: {issue.get('issue', str(issue))}")
            else:
                lines.append(f"  - {issue}")

    if feedback.get('performance_issues'):
        lines.append("\nPerformance Issues:")
        for issue in feedback['performance_issues']:
            lines.append(f"  - {issue}")

    if feedback.get('errors'):
        lines.append("\nErrors:")
        for error in feedback['errors']:
            lines.append(f"  - {error}")

    movement_summary = feedback.get('movement_summary', {})
    if movement_summary.get('issues'):
        lines.append("\nMovement Test Details:")
        for issue in movement_summary['issues'][:10]:
            lines.append(f"  - {issue}")

    print("\n".join(lines))
    return 0


def main():
    parser = argparse.ArgumentParser(
        description="Claude Code Game Development Workflow",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Commands:
  test         Run tests on a build directory
  results      Show results from previous test run
  screenshots  List screenshots for analysis
  create       Create a new build directory
  feedback     Get formatted feedback for iteration

Example workflow:
  1. python game_workflow.py create my_game
  2. [Claude Code generates files in code/my_game/]
  3. python game_workflow.py test code/my_game
  4. python game_workflow.py feedback code/my_game
  5. [Claude Code reads feedback and fixes issues]
  6. Repeat from step 3
        """
    )

    subparsers = parser.add_subparsers(dest='command', help='Command to run')

    # test command
    test_parser = subparsers.add_parser('test', help='Run tests on build')
    test_parser.add_argument('build_dir', help='Path to build directory')
    test_parser.add_argument('--json', action='store_true', help='Output as JSON')

    # results command
    results_parser = subparsers.add_parser('results', help='Show test results')
    results_parser.add_argument('build_dir', help='Path to build directory')

    # screenshots command
    screenshots_parser = subparsers.add_parser('screenshots', help='List screenshots')
    screenshots_parser.add_argument('build_dir', help='Path to build directory')
    screenshots_parser.add_argument('--pairs', action='store_true',
                                    help='Show before/after pairs for movement tests')

    # create command
    create_parser = subparsers.add_parser('create', help='Create build directory')
    create_parser.add_argument('name', nargs='?', help='Build name (auto-generated if not provided)')

    # feedback command
    feedback_parser = subparsers.add_parser('feedback', help='Get iteration feedback')
    feedback_parser.add_argument('build_dir', help='Path to build directory')

    args = parser.parse_args()

    if args.command == 'test':
        return cmd_test(args)
    elif args.command == 'results':
        return cmd_results(args)
    elif args.command == 'screenshots':
        return cmd_screenshots(args)
    elif args.command == 'create':
        return cmd_create(args)
    elif args.command == 'feedback':
        return cmd_feedback(args)
    else:
        parser.print_help()
        return 0


if __name__ == "__main__":
    sys.exit(main())
