#!/usr/bin/env python3
"""
Feature-Driven Development Workflow

This script supports iterative game development with Claude Code:
1. Initialize a feature in a build directory
2. Generate tests.json for the feature
3. Run tests
4. Collect feedback for iteration

Usage:
    # Start a new feature
    python feature_workflow.py init my_game "Add a door that opens with a key"

    # Run tests on a feature
    python feature_workflow.py test my_game

    # Get feedback for iteration
    python feature_workflow.py feedback my_game

    # List discovered objects in a build
    python feature_workflow.py discover my_game
"""

import sys
import json
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional

sys.path.insert(0, str(Path(__file__).parent))

from orchestrator import GameDevOrchestrator


class FeatureWorkflow:
    """Manages feature-driven development workflow"""

    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root
        self.code_dir = workspace_root / "code"
        self.tests_dir = workspace_root / "tests"
        self.scripts_dir = workspace_root / "scripts"

    def init_feature(self, build_name: str, feature_description: str) -> Dict:
        """
        Initialize a feature in a build directory.

        Creates the build directory and a feature.json with the description.
        Claude Code will then generate the actual code and tests.
        """
        build_dir = self.code_dir / build_name
        build_dir.mkdir(parents=True, exist_ok=True)

        # Create feature.json with description
        feature_info = {
            "name": build_name,
            "description": feature_description,
            "created": datetime.now().isoformat(),
            "iteration": 0,
            "status": "initialized"
        }

        feature_file = build_dir / "feature.json"
        with open(feature_file, 'w') as f:
            json.dump(feature_info, f, indent=2)

        print(f"Initialized feature: {build_name}")
        print(f"Description: {feature_description}")
        print(f"Directory: {build_dir}")
        print("\nNext steps for Claude Code:")
        print("1. Generate game code files (project.godot, main.tscn, player.gd, etc.)")
        print("2. Generate tests.json with feature-specific tests")
        print(f"3. Run: python feature_workflow.py test {build_name}")

        return {
            "status": "initialized",
            "build_dir": str(build_dir),
            "feature": feature_info
        }

    def generate_test_template(self, feature_type: str) -> Dict:
        """
        Generate a test template based on feature type.

        Feature types:
        - door: Tests for doors/gates that can be opened
        - pickup: Tests for collectible items
        - enemy: Tests for hostile NPCs
        - npc: Tests for friendly NPCs with dialogue
        - puzzle: Tests for puzzle mechanics
        - vehicle: Tests for drivable vehicles
        - weapon: Tests for combat/weapons
        """
        templates = {
            "door": {
                "feature": "door",
                "tests": [
                    {
                        "name": "find_door",
                        "type": "discovery",
                        "description": "Verify door exists in scene",
                        "duration": 2.0,
                        "steps": [{"action": "wait", "duration": 2.0}],
                        "validate": {"object_in_group": "door"}
                    },
                    {
                        "name": "door_initially_closed",
                        "type": "state",
                        "description": "Door should start closed",
                        "duration": 1.0,
                        "steps": [{"action": "wait", "duration": 1.0}],
                        "validate": {
                            "state_check": {
                                "property_equals": {
                                    "path": "/root/Main/Door",
                                    "property": "is_open",
                                    "value": False
                                }
                            }
                        }
                    },
                    {
                        "name": "approach_door",
                        "type": "movement",
                        "description": "Move player toward door",
                        "duration": 5.0,
                        "steps": [
                            {"action": "move_to", "target_group": "door", "duration": 5.0}
                        ],
                        "validate": {"near_group": "door", "max_distance": 3.0}
                    },
                    {
                        "name": "open_door",
                        "type": "interaction",
                        "description": "Interact with door to open it",
                        "duration": 2.0,
                        "steps": [
                            {"action": "interact", "target_group": "door", "duration": 0.5},
                            {"action": "wait", "duration": 1.5}
                        ],
                        "validate": {
                            "state_check": {
                                "property_equals": {
                                    "path": "/root/Main/Door",
                                    "property": "is_open",
                                    "value": True
                                }
                            }
                        }
                    }
                ]
            },
            "pickup": {
                "feature": "pickup",
                "tests": [
                    {
                        "name": "find_item",
                        "type": "discovery",
                        "description": "Verify collectible exists",
                        "duration": 2.0,
                        "steps": [{"action": "wait", "duration": 2.0}],
                        "validate": {"object_in_group": "pickup"}
                    },
                    {
                        "name": "approach_item",
                        "type": "movement",
                        "description": "Move toward item",
                        "duration": 5.0,
                        "steps": [
                            {"action": "move_to", "target_group": "pickup", "duration": 5.0}
                        ],
                        "validate": {"near_group": "pickup", "max_distance": 2.0}
                    },
                    {
                        "name": "collect_item",
                        "type": "interaction",
                        "description": "Pick up the item",
                        "duration": 2.0,
                        "steps": [
                            {"action": "interact", "target_group": "pickup", "duration": 0.5},
                            {"action": "wait", "duration": 1.5}
                        ],
                        "validate": {
                            "state_check": {
                                "has_item": "key"  # Customize per item
                            }
                        }
                    }
                ]
            },
            "door_with_key": {
                "feature": "door_with_key",
                "tests": [
                    {
                        "name": "initial_state",
                        "type": "state",
                        "description": "Verify initial game state",
                        "duration": 2.0,
                        "steps": [{"action": "wait", "duration": 2.0}],
                        "validate": {"object_in_group": "door", "object_in_group_2": "pickup"}
                    },
                    {
                        "name": "find_key",
                        "type": "movement",
                        "description": "Move to key location",
                        "duration": 5.0,
                        "steps": [
                            {"action": "move_to", "target_group": "pickup", "duration": 5.0}
                        ],
                        "validate": {"near_group": "pickup", "max_distance": 2.0}
                    },
                    {
                        "name": "pickup_key",
                        "type": "interaction",
                        "description": "Collect the key",
                        "duration": 2.0,
                        "steps": [
                            {"action": "interact", "target_group": "pickup", "duration": 0.5},
                            {"action": "wait", "duration": 1.5}
                        ]
                    },
                    {
                        "name": "approach_door",
                        "type": "movement",
                        "description": "Move to door",
                        "duration": 5.0,
                        "steps": [
                            {"action": "move_to", "target_group": "door", "duration": 5.0}
                        ],
                        "validate": {"near_group": "door", "max_distance": 3.0}
                    },
                    {
                        "name": "unlock_door",
                        "type": "interaction",
                        "description": "Use key to open door",
                        "duration": 2.0,
                        "steps": [
                            {"action": "interact", "target_group": "door", "duration": 0.5},
                            {"action": "wait", "duration": 1.5}
                        ],
                        "validate": {
                            "state_check": {
                                "property_equals": {
                                    "path": "/root/Main/Door",
                                    "property": "is_open",
                                    "value": True
                                }
                            }
                        }
                    }
                ]
            },
            "movement": {
                "feature": "basic_movement",
                "tests": [
                    {
                        "name": "move_forward",
                        "type": "movement",
                        "description": "Test forward movement",
                        "duration": 3.0,
                        "steps": [{"action": "input", "inputs": ["move_forward"], "duration": 3.0}],
                        "validate": {"min_distance": 0.5}
                    },
                    {
                        "name": "move_backward",
                        "type": "movement",
                        "description": "Test backward movement",
                        "duration": 3.0,
                        "steps": [{"action": "input", "inputs": ["move_backward"], "duration": 3.0}],
                        "validate": {"min_distance": 0.5}
                    },
                    {
                        "name": "jump",
                        "type": "movement",
                        "description": "Test jump",
                        "duration": 2.0,
                        "steps": [{"action": "input", "inputs": ["jump"], "duration": 2.0}],
                        "validate": {"left_floor": True}
                    }
                ]
            },
            "rl_agents": {
                "feature": "rl_agents",
                "description": "Reinforcement learning training support",
                "tests": [
                    {
                        "name": "rl_env_loaded",
                        "type": "state",
                        "description": "Verify RLEnv autoload is active",
                        "duration": 2.0,
                        "steps": [{"action": "wait", "duration": 2.0}],
                        "validate": {"autoload_exists": "RLEnv"}
                    },
                    {
                        "name": "player_on_path",
                        "type": "state",
                        "description": "Verify player starts on/near path",
                        "duration": 2.0,
                        "steps": [{"action": "wait", "duration": 2.0}],
                        "validate": {"on_track": True}
                    },
                    {
                        "name": "progress_tracking",
                        "type": "movement",
                        "description": "Test progress increases when moving along path",
                        "duration": 5.0,
                        "steps": [{"action": "input", "inputs": ["move_forward"], "duration": 5.0}],
                        "validate": {"progress_increased": True}
                    }
                ],
                "inject_command": "python scripts/orchestrator.py --feature rl_agents --build-dir {build_dir}",
                "training_command": "python scripts/rl/train_ppo.py --env-path {build_dir} --total-timesteps 100000"
            }
        }

        return templates.get(feature_type, templates["movement"])

    def write_tests(self, build_name: str, tests: Dict) -> Path:
        """Write tests.json to build directory"""
        build_dir = self.code_dir / build_name
        tests_file = build_dir / "tests.json"

        with open(tests_file, 'w') as f:
            json.dump(tests, f, indent=2)

        print(f"Wrote tests to: {tests_file}")
        return tests_file

    def run_tests(self, build_name: str) -> Dict:
        """Run tests on a build using the dynamic test runner"""
        build_dir = self.code_dir / build_name

        if not build_dir.exists():
            return {"status": "error", "error": f"Build not found: {build_name}"}

        # Copy dynamic_test_runner.gd to build
        src = self.scripts_dir / "dynamic_test_runner.gd"
        dst = build_dir / "test_runner.gd"  # Use same name for compatibility
        if src.exists():
            dst.write_text(src.read_text())

        # Use orchestrator to run tests
        orchestrator = GameDevOrchestrator(self.workspace_root)
        result = orchestrator.run_tests_only(build_dir)

        return result

    def get_feedback(self, build_name: str) -> str:
        """Get formatted feedback for the next iteration"""
        build_dir = self.code_dir / build_name
        feedback_file = build_dir / "test_feedback.json"

        if not feedback_file.exists():
            return "No test results found. Run tests first."

        with open(feedback_file) as f:
            result = json.load(f)

        feedback = result.get("feedback", {})
        test_results = result.get("test_results", {})

        lines = []

        # Check if tests passed
        summary = test_results.get("summary", {})
        if summary:
            lines.append(f"Tests: {summary.get('passed', 0)}/{summary.get('total', 0)} passed")
            if summary.get("overall_status") == "passed":
                lines.append("\nAll tests passing! Feature is working.")
                return "\n".join(lines)

        lines.append("\nISSUES TO FIX:")

        # Get issues from test results
        tests = test_results.get("tests", [])
        for test in tests:
            if test.get("status") == "failed":
                lines.append(f"\n{test['name']}: FAILED")
                for issue in test.get("issues", []):
                    lines.append(f"  - {issue}")

        # Include movement issues if any
        if feedback.get("movement_issues"):
            lines.append("\nMovement Issues:")
            for issue in feedback["movement_issues"]:
                if isinstance(issue, dict):
                    lines.append(f"  - {issue.get('issue', str(issue))}")
                else:
                    lines.append(f"  - {issue}")

        return "\n".join(lines)

    def increment_iteration(self, build_name: str):
        """Increment the iteration counter for a feature"""
        build_dir = self.code_dir / build_name
        feature_file = build_dir / "feature.json"

        if feature_file.exists():
            with open(feature_file) as f:
                feature = json.load(f)
            feature["iteration"] = feature.get("iteration", 0) + 1
            feature["last_updated"] = datetime.now().isoformat()
            with open(feature_file, 'w') as f:
                json.dump(feature, f, indent=2)


def main():
    parser = argparse.ArgumentParser(
        description="Feature-Driven Development Workflow",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Initialize a new feature
  python feature_workflow.py init my_game "Add a door that opens with a key"

  # Generate test template for a feature type
  python feature_workflow.py template door_with_key --output my_game

  # Run tests
  python feature_workflow.py test my_game

  # Get feedback for next iteration
  python feature_workflow.py feedback my_game
        """
    )

    subparsers = parser.add_subparsers(dest='command', help='Command')

    # init command
    init_p = subparsers.add_parser('init', help='Initialize a feature')
    init_p.add_argument('build_name', help='Name of the build')
    init_p.add_argument('description', help='Feature description')

    # template command
    template_p = subparsers.add_parser('template', help='Generate test template')
    template_p.add_argument('feature_type', help='Type: door, pickup, door_with_key, movement, rl_agents')
    template_p.add_argument('--output', '-o', help='Build name to write tests.json')

    # test command
    test_p = subparsers.add_parser('test', help='Run tests')
    test_p.add_argument('build_name', help='Build to test')

    # feedback command
    feedback_p = subparsers.add_parser('feedback', help='Get iteration feedback')
    feedback_p.add_argument('build_name', help='Build name')

    args = parser.parse_args()
    workspace_root = Path(__file__).parent.parent
    workflow = FeatureWorkflow(workspace_root)

    if args.command == 'init':
        result = workflow.init_feature(args.build_name, args.description)
        print(json.dumps(result, indent=2))

    elif args.command == 'template':
        template = workflow.generate_test_template(args.feature_type)
        if args.output:
            workflow.write_tests(args.output, template)
        else:
            print(json.dumps(template, indent=2))

    elif args.command == 'test':
        result = workflow.run_tests(args.build_name)
        # Result is printed by orchestrator

    elif args.command == 'feedback':
        print(workflow.get_feedback(args.build_name))

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
