#!/usr/bin/env python3
"""
AI-Driven Game Development Pipeline Orchestrator

Unified Claude Code Session Mode:
- Claude Code generates game files directly (no API calls)
- This orchestrator handles test execution and feedback collection
- Claude Code analyzes results and iterates

Usage:
    # Test-only mode (for Claude Code workflow):
    python orchestrator.py --test-only --build-dir /path/to/build

    # Full pipeline (legacy API mode):
    python orchestrator.py --prompt /path/to/prompt.txt
"""

import os
import sys
import json
import argparse
import subprocess
import time
import re
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

# Available features that can be injected
AVAILABLE_FEATURES = ["rl_agents", "fisheye"]


class GameDevOrchestrator:
    """Main orchestration class for the AI-driven game development pipeline"""

    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root
        self.prompts_dir = workspace_root / "prompts"
        self.code_dir = workspace_root / "code"
        self.tests_dir = workspace_root / "tests"
        self.docs_dir = workspace_root / "docs"

        # Ensure directories exist
        for dir_path in [self.prompts_dir, self.code_dir, self.tests_dir, self.docs_dir]:
            dir_path.mkdir(exist_ok=True)

        # Configuration
        self.config = {
            "target_fps": 60,
            "max_iterations": 5,
        }

    def load_prompt(self, prompt_path: Path) -> str:
        """Load scene description from file"""
        with open(prompt_path, 'r') as f:
            return f.read()

    def run_tests_only(self, build_dir: Path) -> Dict:
        """
        Run tests on an existing build directory (for Claude Code unified session).

        This is the primary method for the unified workflow where Claude Code
        generates code directly and then calls this to test it.

        The TestRunner autoload is added before tests and removed after,
        so the game runs normally when launched outside of testing.

        Args:
            build_dir: Path to directory containing game code files

        Returns:
            Dict with test results, movement metrics, and feedback
        """
        print("=" * 80)
        print("Test-Only Mode (Claude Code Unified Session)")
        print("=" * 80)
        print(f"Build directory: {build_dir}")

        if not build_dir.exists():
            return {
                "status": "error",
                "error": f"Build directory not found: {build_dir}",
                "feedback": {"has_issues": True, "errors": ["Build directory not found"]}
            }

        # Validate the build has required files
        required_files = ["project.godot", "main.tscn", "player.gd"]
        missing = [f for f in required_files if not (build_dir / f).exists()]
        if missing:
            return {
                "status": "error",
                "error": f"Missing required files: {missing}",
                "feedback": {"has_issues": True, "errors": [f"Missing: {missing}"]}
            }

        # Validate and auto-fix code issues
        print("\nValidating generated code...")
        issues = self._validate_generated_code(build_dir)
        if issues:
            print(f"Found {len(issues)} issue(s):")
            for issue in issues:
                print(f"  - {issue}")
            print("Attempting auto-fix...")
            self._fix_common_issues(build_dir, issues)

        # Run tests
        test_results = self.run_game_tests(build_dir)

        # Find the test run directory
        test_run_dirs = sorted(self.tests_dir.glob(f"{build_dir.name}_*"))
        test_run_dir = test_run_dirs[-1] if test_run_dirs else None

        # Evaluate performance
        perf_passed, perf_issues = self.evaluate_performance(test_results)

        # Collect feedback (without visual analysis - Claude Code will do that)
        feedback = {
            "has_issues": False,
            "movement_issues": [],
            "visual_issues": [],
            "performance_issues": perf_issues,
            "errors": test_results.get("errors", []),
            "movement_summary": test_results.get("movement_summary", {})
        }

        # Check movement summary
        movement_summary = test_results.get("movement_summary", {})
        if movement_summary.get("overall_status") in ["issues_detected", "no_player", "no_data"]:
            feedback["has_issues"] = True
            feedback["movement_issues"] = movement_summary.get("issues", [])

        if perf_issues or test_results.get("errors"):
            feedback["has_issues"] = True

        # Prepare comprehensive result
        result = {
            "status": "completed",
            "build_dir": str(build_dir),
            "test_run_dir": str(test_run_dir) if test_run_dir else None,
            "test_results": test_results,
            "performance": test_results.get("performance", {}),
            "movement_metrics": test_results.get("movement_metrics", {}),
            "movement_summary": movement_summary,
            "feedback": feedback,
            "screenshots": []
        }

        # List screenshots for Claude Code to analyze
        if test_run_dir and test_run_dir.exists():
            result["screenshots"] = [str(p) for p in sorted(test_run_dir.glob("*.png"))]

        # Print summary
        print(f"\n{'=' * 80}")
        print("TEST RESULTS SUMMARY")
        print(f"{'=' * 80}")
        print(f"Status: {test_results.get('status', 'unknown')}")
        print(f"Movement: {movement_summary.get('overall_status', 'unknown')}")
        print(f"  Passed: {movement_summary.get('passed_tests', 0)}")
        print(f"  Failed: {movement_summary.get('failed_tests', 0)}")
        print(f"Screenshots: {len(result['screenshots'])}")
        print(f"Has issues: {feedback['has_issues']}")

        if feedback['has_issues']:
            print("\nIssues found:")
            for issue in feedback.get('movement_issues', [])[:5]:
                print(f"  - {issue}")
            for issue in feedback.get('performance_issues', []):
                print(f"  - {issue}")
            for error in feedback.get('errors', [])[:3]:
                print(f"  - {error}")

        print(f"{'=' * 80}\n")

        # Save results
        results_file = build_dir / "test_feedback.json"
        with open(results_file, 'w') as f:
            json.dump(result, f, indent=2)
        print(f"Results saved to: {results_file}")

        # Clean up: remove TestRunner autoload so game runs normally
        self._cleanup_test_harness(build_dir)

        return result

    def format_feedback_for_iteration(self, feedback: Dict) -> str:
        """
        Format feedback into a string that can be used in the next code generation.

        This is useful for Claude Code to include in context when regenerating code.
        """
        lines = []

        if feedback.get('movement_issues'):
            lines.append("MOVEMENT ISSUES:")
            for issue in feedback['movement_issues']:
                if isinstance(issue, dict):
                    lines.append(f"  - {issue.get('test', 'unknown')}: {issue.get('issue', str(issue))}")
                else:
                    lines.append(f"  - {issue}")

        if feedback.get('performance_issues'):
            lines.append("\nPERFORMANCE ISSUES:")
            for issue in feedback['performance_issues']:
                lines.append(f"  - {issue}")

        if feedback.get('errors'):
            lines.append("\nERRORS:")
            for error in feedback['errors']:
                lines.append(f"  - {error}")

        movement_summary = feedback.get('movement_summary', {})
        if movement_summary:
            lines.append(f"\nMOVEMENT STATUS: {movement_summary.get('overall_status', 'unknown')}")
            if movement_summary.get('issues'):
                for issue in movement_summary['issues'][:5]:
                    lines.append(f"  - {issue}")

        return "\n".join(lines) if lines else "No issues found."

    def _validate_generated_code(self, build_dir: Path) -> List[str]:
        """Validate generated code for common issues"""
        issues = []

        # Run comprehensive validator
        try:
            from godot_validator import validate_build
            result = validate_build(build_dir)

            # Convert validator errors to issues list
            for error in result.errors:
                issues.append(f"{error['file']}:{error['line']}: {error['message']}")

            # Also include warnings as issues (but mark them)
            for warning in result.warnings:
                issues.append(f"[WARNING] {warning['file']}:{warning['line']}: {warning['message']}")

        except ImportError:
            # Fall back to basic validation if validator not available
            pass

        # Additional checks not in validator
        tscn_file = build_dir / "main.tscn"
        if tscn_file.exists():
            content = tscn_file.read_text()

            # Check if Player has a collision shape assigned
            if 'type="CharacterBody3D"' in content or 'CharacterBody3D' in content:
                # Look for CollisionShape3D with a shape assigned
                if 'CollisionShape3D' in content:
                    if 'shape = SubResource' not in content and 'shape = ExtResource' not in content:
                        issues.append("Player CollisionShape3D has no shape assigned - player will fall through floor")
                else:
                    if "Player has no CollisionShape3D" not in str(issues):
                        issues.append("Player has no CollisionShape3D - player will fall through floor")

            # Check if Camera3D exists for player
            if 'type="CharacterBody3D"' in content and 'Camera3D' not in content:
                if "No Camera3D found" not in str(issues):
                    issues.append("No Camera3D found - player won't be able to see")

            # Check for lighting
            if 'DirectionalLight3D' not in content and 'OmniLight3D' not in content and 'SpotLight3D' not in content:
                if "No light" not in str(issues) and "no lights" not in str(issues):
                    issues.append("No light source found - scene will be dark")

        # Check player.gd for common issues
        player_file = build_dir / "player.gd"
        if player_file.exists():
            content = player_file.read_text()

            # Check for incomplete functions (just 'return' without value)
            lines = content.split('\n')
            for i, line in enumerate(lines):
                if line.strip() == 'return' and i > 0:
                    # Check if previous line suggests this should return something
                    prev_lines = '\n'.join(lines[max(0,i-5):i])
                    if '-> Vector' in prev_lines or '-> float' in prev_lines or '-> int' in prev_lines:
                        issues.append(f"player.gd line {i+1}: 'return' without value in function with return type")

        return issues

    def _fix_common_issues(self, build_dir: Path, issues: List[str]) -> None:
        """Attempt to fix common issues found during validation"""
        tscn_file = build_dir / "main.tscn"

        for issue in issues:
            if "CollisionShape3D has no shape assigned" in issue:
                print(f"Auto-fixing: {issue}")
                if tscn_file.exists():
                    content = tscn_file.read_text()

                    # Add CapsuleShape3D sub_resource if not present
                    if 'CapsuleShape3D' not in content:
                        # Find load_steps and increment it
                        match = re.search(r'load_steps=(\d+)', content)
                        if match:
                            old_steps = int(match.group(1))
                            content = content.replace(f'load_steps={old_steps}', f'load_steps={old_steps + 1}')

                        # Add the shape sub_resource after existing sub_resources
                        shape_resource = '''
[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_player_auto"]
radius = 0.4
height = 1.8
'''
                        # Insert before first [node
                        node_idx = content.find('[node name=')
                        if node_idx > 0:
                            content = content[:node_idx] + shape_resource + '\n' + content[node_idx:]

                    # Fix the CollisionShape3D node to use the shape
                    if 'CollisionShape3D" parent="Player"]\n' in content:
                        content = content.replace(
                            'CollisionShape3D" parent="Player"]\n',
                            'CollisionShape3D" parent="Player"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)\nshape = SubResource("CapsuleShape3D_player_auto")\n'
                        )

                    tscn_file.write_text(content)
                    print("Fixed: Added CapsuleShape3D to player")

            if "No Camera3D found" in issue:
                print(f"Auto-fixing: {issue}")
                if tscn_file.exists():
                    content = tscn_file.read_text()

                    # Add Camera3D as child of Player - find the Player node and add camera after it
                    camera_node = '\n[node name="Camera3D" type="Camera3D" parent="Player"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.7, 0)\ncurrent = true\n'

                    # Find the first child node of Player (or end of file) and insert camera before it
                    # Look for pattern: Player node with script, then insert camera
                    pattern = r'(\[node name="Player"[^\]]*\]\n(?:transform[^\n]*\n)?(?:script[^\n]*\n)?)'
                    match = re.search(pattern, content)
                    if match:
                        insert_pos = match.end()
                        content = content[:insert_pos] + camera_node + content[insert_pos:]
                        tscn_file.write_text(content)
                        print("Fixed: Added Camera3D to player")

            if "No light source found" in issue:
                print(f"Auto-fixing: {issue}")
                if tscn_file.exists():
                    content = tscn_file.read_text()

                    # Add DirectionalLight3D after Main node
                    light_node = '\n[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]\ntransform = Transform3D(0.866, -0.433, 0.25, 0, 0.5, 0.866, -0.5, -0.75, 0.433, 5, 8, 5)\nlight_energy = 1.0\nshadow_enabled = false\n'

                    # Find main node and insert after it
                    pattern = r'(\[node name="Main"[^\]]*\]\n(?:script[^\n]*\n)?)'
                    match = re.search(pattern, content)
                    if match:
                        insert_pos = match.end()
                        content = content[:insert_pos] + light_node + content[insert_pos:]
                        tscn_file.write_text(content)
                        print("Fixed: Added DirectionalLight3D")

    def save_generated_code(self, code_files: Dict[str, str], build_name: str) -> Path:
        """Save generated code to filesystem"""
        build_dir = self.code_dir / build_name
        build_dir.mkdir(exist_ok=True)

        file_mapping = {
            "main_scene": "main.tscn",
            "player_script": "player.gd",
            "main_script": "main.gd",
            "project_file": "project.godot"
        }

        for key, filename in file_mapping.items():
            if key in code_files:
                (build_dir / filename).write_text(code_files[key])

        # If main.tscn wasn't generated or is incomplete, create a basic one
        tscn_file = build_dir / "main.tscn"
        if not tscn_file.exists() or tscn_file.stat().st_size < 100:
            print("Generating basic main.tscn scene file...")
            self._generate_basic_scene(build_dir)

        # Validate generated code and fix common issues
        print("Validating generated code...")
        issues = self._validate_generated_code(build_dir)
        if issues:
            print(f"Found {len(issues)} issue(s):")
            for issue in issues:
                print(f"  - {issue}")
            print("Attempting auto-fix...")
            self._fix_common_issues(build_dir, issues)

            # Re-validate after fixes
            remaining_issues = self._validate_generated_code(build_dir)
            if remaining_issues:
                print(f"Warning: {len(remaining_issues)} issue(s) could not be auto-fixed:")
                for issue in remaining_issues:
                    print(f"  - {issue}")
            else:
                print("All issues fixed!")

        print(f"Code saved to: {build_dir}")
        return build_dir

    def _generate_basic_scene(self, build_dir: Path):
        """Generate a basic Godot scene file"""
        scene_content = """[gd_scene load_steps=5 format=3 uid="uid://main_scene"]

[ext_resource type="Script" path="res://main.gd" id="1"]
[ext_resource type="Script" path="res://player.gd" id="2"]

[sub_resource type="BoxMesh" id="BoxMesh_room"]
size = Vector3(10, 4, 15)

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_player"]
radius = 0.4
height = 1.8

[node name="Main" type="Node3D"]
script = ExtResource("1")

[node name="RoomMesh" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2, 0)
mesh = SubResource("BoxMesh_room")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.707107, 0.707107, 0, -0.707107, 0.707107, 5, 5, 0)
shadow_enabled = false

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]

[node name="Player" type="CharacterBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0)
script = ExtResource("2")

[node name="Camera3D" type="Camera3D" parent="Player"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.7, 0)
current = true

[node name="CollisionShape3D" type="CollisionShape3D" parent="Player"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
shape = SubResource("CapsuleShape3D_player")
"""

        tscn_file = build_dir / "main.tscn"
        tscn_file.write_text(scene_content)
        print(f"Generated basic main.tscn")

    def run_game_tests(self, build_dir: Path) -> Dict:
        """Run game in Docker container and capture test results"""
        print(f"\nRunning tests for build: {build_dir.name}")

        test_run_dir = self.tests_dir / f"{build_dir.name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        test_run_dir.mkdir(exist_ok=True)

        # Prepare the project for testing
        self._prepare_project_for_testing(build_dir)

        # Check if Docker is available
        docker_available = self._check_docker()

        if not docker_available:
            print("Warning: Docker not available, using fallback results")
            return self._get_fallback_test_results(build_dir, test_run_dir)

        # Run tests in Docker container
        try:
            test_results = self._run_docker_tests(build_dir, test_run_dir)
        except Exception as e:
            print(f"Error running Docker tests: {e}")
            test_results = self._get_fallback_test_results(build_dir, test_run_dir)
            test_results["errors"].append(f"Docker execution failed: {str(e)}")

        # Save test results
        results_file = test_run_dir / "results.json"
        with open(results_file, 'w') as f:
            json.dump(test_results, f, indent=2)

        return test_results

    def _check_docker(self) -> bool:
        """Check if Docker is available"""
        try:
            result = subprocess.run(
                ["docker", "--version"],
                capture_output=True,
                timeout=5
            )
            return result.returncode == 0
        except (subprocess.SubprocessError, FileNotFoundError):
            return False

    def _prepare_project_for_testing(self, build_dir: Path):
        """Prepare Godot project for automated testing"""
        # Detect movement type and customize tests
        movement_info = self._detect_movement_type(build_dir)
        if movement_info:
            print(f"Detected movement type: {movement_info['detected_type']} (confidence: {movement_info['confidence']:.2f})")

        # Check if dynamic tests.json exists - use dynamic test runner
        tests_json = build_dir / "tests.json"
        if tests_json.exists():
            print(f"Found tests.json - using dynamic test runner")
            test_runner_src = self.workspace_root / "scripts" / "dynamic_test_runner.gd"
        else:
            test_runner_src = self.workspace_root / "scripts" / "test_runner.gd"

        # Copy test_runner.gd to build directory
        if test_runner_src.exists():
            test_runner_dst = build_dir / "test_runner.gd"
            test_runner_dst.write_text(test_runner_src.read_text())
            print(f"Copied {test_runner_src.name} to {build_dir.name}")

        # Update project.godot to include TestRunner as autoload
        project_file = build_dir / "project.godot"
        if project_file.exists():
            project_content = project_file.read_text()

            # Add TestRunner autoload if not present
            if "TestRunner" not in project_content:
                # Find or create [autoload] section
                if "[autoload]" not in project_content:
                    project_content += "\n[autoload]\n"

                # Add TestRunner entry
                autoload_line = '\nTestRunner="*res://test_runner.gd"\n'
                project_content = project_content.replace("[autoload]", "[autoload]" + autoload_line)

                project_file.write_text(project_content)
                print("Added TestRunner autoload to project.godot")

    def _cleanup_test_harness(self, build_dir: Path):
        """Remove test harness so game runs normally after testing"""
        project_file = build_dir / "project.godot"
        if project_file.exists():
            content = project_file.read_text()

            # Remove TestRunner autoload line
            lines = content.split('\n')
            new_lines = []
            for line in lines:
                if 'TestRunner=' in line and 'test_runner.gd' in line:
                    continue  # Skip this line
                new_lines.append(line)

            # Clean up empty [autoload] section if it's now empty
            content = '\n'.join(new_lines)
            content = re.sub(r'\[autoload\]\s*\n\s*\n', '', content)

            project_file.write_text(content)

        # Optionally remove test_runner.gd (keep it for reference)
        # test_runner_file = build_dir / "test_runner.gd"
        # if test_runner_file.exists():
        #     test_runner_file.unlink()

        print("Cleaned up test harness - game will run normally")

    def _detect_movement_type(self, build_dir: Path) -> Optional[Dict]:
        """Detect movement type from build code"""
        try:
            from movement_detector import MovementDetector
            detector = MovementDetector()
            return detector.detect_from_directory(build_dir)
        except ImportError:
            print("Warning: movement_detector module not available")
            return None
        except Exception as e:
            print(f"Warning: movement detection failed: {e}")
            return None

    def _run_docker_tests(self, build_dir: Path, test_run_dir: Path) -> Dict:
        """Execute tests in Docker container"""
        print("Starting Docker test execution...")

        # Build Docker image if needed
        self._ensure_docker_image()

        # Run Godot in container
        container_project_path = f"/workspace/code/{build_dir.name}"
        container_test_path = f"/workspace/tests/{test_run_dir.name}"

        # Docker command to run Godot headless
        docker_cmd = [
            "docker", "run", "--rm",
            "-v", f"{self.workspace_root}/code:/workspace/code",
            "-v", f"{self.workspace_root}/tests:/workspace/tests",
            "-e", "DISPLAY=:99",
            "ai-game-pipeline:latest",
            "godot", "--headless", "--rendering-driver", "opengl3",
            "--path", container_project_path,
            "--", f"--test-output={container_test_path}"
        ]

        print(f"Running: {' '.join(docker_cmd[:5])} ...")

        # Run with timeout
        try:
            result = subprocess.run(
                docker_cmd,
                capture_output=True,
                text=True,
                timeout=60  # 60 second timeout
            )

            print("Docker execution completed")
            if result.stdout:
                print(f"Output: {result.stdout[:500]}")  # First 500 chars
            if result.stderr:
                print(f"Errors: {result.stderr[:500]}")

        except subprocess.TimeoutExpired:
            print("Warning: Docker test execution timed out")
            return self._get_fallback_test_results(build_dir, test_run_dir)

        # Find results in build directory (test_runner.gd saves to res://test_output/)
        test_output_dir = build_dir / "test_output"
        results_file = None
        test_results = None

        if test_output_dir.exists():
            # Find the most recent results directory
            result_dirs = sorted(test_output_dir.iterdir(), reverse=True)
            for result_dir in result_dirs:
                if result_dir.is_dir():
                    candidate = result_dir / "results.json"
                    if candidate.exists():
                        results_file = candidate
                        break

        if results_file and results_file.exists():
            with open(results_file, 'r') as f:
                test_results = json.load(f)
                print(f"Loaded test results: {test_results.get('status', 'unknown')}")

            # Copy results and screenshots to test_run_dir
            import shutil
            result_dir = results_file.parent
            for item in result_dir.iterdir():
                dest = test_run_dir / item.name
                if item.is_file():
                    shutil.copy2(item, dest)
            print(f"Copied results to: {test_run_dir}")

            return test_results
        else:
            print("Warning: No results.json found, using fallback")
            return self._get_fallback_test_results(build_dir, test_run_dir)

    def _ensure_docker_image(self):
        """Ensure Docker image is built"""
        # Check if image exists
        check_cmd = ["docker", "images", "-q", "ai-game-pipeline:latest"]
        result = subprocess.run(check_cmd, capture_output=True, text=True)

        if not result.stdout.strip():
            print("Docker image not found, building...")
            print("This will take 5-10 minutes on first run...")

            build_cmd = ["docker-compose", "build"]
            subprocess.run(build_cmd, cwd=self.workspace_root, check=True)
            print("Docker image built successfully")

    def _get_fallback_test_results(self, build_dir: Path, test_run_dir: Path) -> Dict:
        """Generate fallback test results when Docker is unavailable"""
        return {
            "status": "fallback",
            "timestamp": datetime.now().isoformat(),
            "build": build_dir.name,
            "screenshots": [],
            "performance": {
                "avg_fps": 0,
                "min_fps": 0,
                "max_fps": 0,
                "avg_memory_mb": 0
            },
            "errors": ["Tests not executed - Docker unavailable or execution failed"]
        }

    def get_screenshots_for_analysis(self, test_run_dir: Path) -> List[Path]:
        """
        Get list of screenshots for Claude Code to analyze directly.

        In unified session mode, Claude Code reads and analyzes images directly
        using its multimodal capabilities.
        """
        if not test_run_dir or not test_run_dir.exists():
            return []
        return sorted(test_run_dir.glob("*.png"))

    def evaluate_performance(self, test_results: Dict) -> Tuple[bool, List[str]]:
        """Evaluate if performance meets targets"""
        perf = test_results.get("performance", {})
        avg_fps = perf.get("avg_fps", 0)

        issues = []

        if avg_fps > 0 and avg_fps < self.config["target_fps"]:
            issues.append(f"FPS below target: {avg_fps:.1f} < {self.config['target_fps']}")

        passed = len(issues) == 0
        return passed, issues

    def log_test_run(self, build_dir: Path, test_results: Dict):
        """Log test run details for analysis"""
        log_entry = {
            "timestamp": datetime.now().isoformat(),
            "build": str(build_dir),
            "test_results": test_results
        }

        log_file = self.docs_dir / "test_log.jsonl"
        with open(log_file, 'a') as f:
            f.write(json.dumps(log_entry) + '\n')

    def inject_feature(self, build_dir: Path, feature: str) -> Dict:
        """
        Inject a feature into a game build.

        Args:
            build_dir: Path to the game build directory
            feature: Feature name to inject (e.g., "rl_agents")

        Returns:
            Dictionary with injection results
        """
        print(f"Injecting feature '{feature}' into {build_dir}")

        if feature not in AVAILABLE_FEATURES:
            return {
                "status": "error",
                "error": f"Unknown feature: {feature}. Available: {AVAILABLE_FEATURES}"
            }

        if feature == "rl_agents":
            return self._inject_rl_agents(build_dir)

        if feature == "fisheye":
            return self._inject_fisheye(build_dir)

        return {"status": "error", "error": f"Feature {feature} not implemented"}

    def _inject_rl_agents(self, build_dir: Path) -> Dict:
        """Inject RL agents feature into a build."""
        try:
            from rl_injector import inject_rl_support
            result = inject_rl_support(build_dir, workspace_root=self.workspace_root)
            return result
        except ImportError as e:
            return {
                "status": "error",
                "error": f"Failed to import rl_injector: {e}"
            }
        except Exception as e:
            return {
                "status": "error",
                "error": f"Failed to inject RL support: {e}"
            }

    def _inject_fisheye(self, build_dir: Path) -> Dict:
        """Inject fisheye camera effect into a build."""
        try:
            from effects_injector import inject_effect
            result = inject_effect(build_dir, "fisheye", workspace_root=self.workspace_root)
            return result
        except ImportError as e:
            return {
                "status": "error",
                "error": f"Failed to import effects_injector: {e}"
            }
        except Exception as e:
            return {
                "status": "error",
                "error": f"Failed to inject fisheye effect: {e}"
            }


def main():
    parser = argparse.ArgumentParser(
        description="Game Development Pipeline - Test Runner for Claude Code",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run tests on a build directory (primary use case for Claude Code):
  python orchestrator.py --test-only --build-dir ./code/my_build

  # Create a new build directory:
  python orchestrator.py --create-build my_game_v1

  # Inject RL training support into a build:
  python orchestrator.py --feature rl_agents --build-dir ./code/my_build
        """
    )

    parser.add_argument("--test-only", action="store_true",
                       help="Run tests only on existing build (for Claude Code workflow)")
    parser.add_argument("--build-dir", type=str,
                       help="Path to build directory to test")
    parser.add_argument("--create-build", type=str,
                       help="Create a new empty build directory with this name")
    parser.add_argument("--feature", type=str, choices=AVAILABLE_FEATURES,
                       help=f"Inject a feature into the build. Available: {', '.join(AVAILABLE_FEATURES)}")

    args = parser.parse_args()

    # Get workspace root (parent of scripts directory)
    workspace_root = Path(__file__).parent.parent

    # Create orchestrator
    orchestrator = GameDevOrchestrator(workspace_root)

    if args.create_build:
        # Create empty build directory
        build_dir = orchestrator.code_dir / args.create_build
        build_dir.mkdir(exist_ok=True)
        print(f"Created build directory: {build_dir}")
        print("\nRequired files:")
        print("  - project.godot")
        print("  - main.tscn")
        print("  - main.gd")
        print("  - player.gd")
        sys.exit(0)

    if args.feature:
        # Inject a feature into a build
        if not args.build_dir:
            print("Error: --build-dir required with --feature")
            sys.exit(1)

        build_dir = Path(args.build_dir)
        if not build_dir.is_absolute():
            build_dir = workspace_root / args.build_dir

        result = orchestrator.inject_feature(build_dir, args.feature)

        if result.get("status") == "error":
            print(f"Error: {result.get('error')}")
            sys.exit(1)

        print(f"\nFeature '{args.feature}' injected successfully!")
        sys.exit(0)

    if args.test_only:
        if not args.build_dir:
            print("Error: --build-dir required with --test-only")
            sys.exit(1)

        build_dir = Path(args.build_dir)
        if not build_dir.is_absolute():
            build_dir = workspace_root / args.build_dir

        result = orchestrator.run_tests_only(build_dir)

        # Exit with appropriate code
        if result.get("feedback", {}).get("has_issues"):
            sys.exit(1)  # Issues found
        sys.exit(0)  # Success

    # Default: show help
    parser.print_help()


if __name__ == "__main__":
    main()
