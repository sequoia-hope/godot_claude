#!/usr/bin/env python3
"""
AI-Driven Game Development Pipeline Orchestrator

This script manages the complete workflow:
1. Load scene description
2. Generate Godot game code using Claude API
3. Build and run game in Docker container
4. Capture screenshots and performance metrics
5. Analyze results using multimodal AI
6. Iterate based on feedback or accept build
"""

import os
import sys
import json
import argparse
import subprocess
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

try:
    import anthropic
except ImportError:
    print("Warning: anthropic package not installed. Install with: pip install anthropic")
    anthropic = None


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

        # Initialize Anthropic client
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if api_key and anthropic:
            self.client = anthropic.Anthropic(api_key=api_key)
        else:
            self.client = None
            print("Warning: ANTHROPIC_API_KEY not set or anthropic not installed")

        # Configuration
        self.config = {
            "target_fps": 60,
            "max_iterations": 5,
            "model": "claude-sonnet-4-5-20250929",
        }

    def load_prompt(self, prompt_path: Path) -> str:
        """Load scene description from file"""
        with open(prompt_path, 'r') as f:
            return f.read()

    def generate_game_code(self, scene_description: str, iteration: int = 0) -> Dict[str, str]:
        """
        Generate Godot game code using Claude API

        Returns dict with:
        - 'main_scene': GDScript for main scene
        - 'player_script': GDScript for player controller
        - 'project_file': Godot project.godot configuration
        """
        if not self.client:
            print("Error: Claude API client not initialized")
            return self._get_fallback_code()

        system_prompt = """You are an expert Godot game developer. Generate complete, working Godot 4.x code based on scene descriptions.

Requirements:
- Use GDScript (not C#)
- Create main scene with Node3D structure
- Implement CharacterBody3D for player
- Include camera as child of player
- Add basic lighting (DirectionalLight3D)
- Use simple placeholder materials/meshes
- Include performance monitoring code
- Export screenshot capture functionality
- Make code clean, well-commented, and production-ready"""

        user_prompt = f"""Generate complete Godot 4.x code for this scene:

{scene_description}

Iteration: {iteration}

Provide the following files:
1. main.tscn (scene file) - as text representation
2. player.gd (player controller)
3. main.gd (main scene script with screenshot and performance capture)
4. project.godot (project configuration)

Format your response as JSON with keys: 'main_scene', 'player_script', 'main_script', 'project_file'"""

        try:
            response = self.client.messages.create(
                model=self.config["model"],
                max_tokens=4000,
                system=system_prompt,
                messages=[{"role": "user", "content": user_prompt}]
            )

            # Parse response - assume it's JSON or extract JSON from markdown
            content = response.content[0].text

            # Try to extract JSON if wrapped in markdown code blocks
            if "```json" in content:
                json_start = content.find("```json") + 7
                json_end = content.find("```", json_start)
                content = content[json_start:json_end].strip()
            elif "```" in content:
                json_start = content.find("```") + 3
                json_end = content.find("```", json_start)
                content = content[json_start:json_end].strip()

            code_files = json.loads(content)
            return code_files

        except Exception as e:
            print(f"Error generating code: {e}")
            return self._get_fallback_code()

    def _get_fallback_code(self) -> Dict[str, str]:
        """Fallback code for when API is unavailable"""
        return {
            "main_scene": "# Placeholder main scene",
            "player_script": "# Placeholder player script",
            "main_script": "# Placeholder main script",
            "project_file": "# Placeholder project file"
        }

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

        print(f"Code saved to: {build_dir}")
        return build_dir

    def run_game_tests(self, build_dir: Path) -> Dict:
        """Run game in Docker container and capture test results"""
        print(f"\nRunning tests for build: {build_dir.name}")

        test_run_dir = self.tests_dir / f"{build_dir.name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        test_run_dir.mkdir(exist_ok=True)

        # TODO: Implement actual Docker execution
        # For now, create placeholder test results
        test_results = {
            "status": "placeholder",
            "timestamp": datetime.now().isoformat(),
            "build": build_dir.name,
            "screenshots": [],
            "performance": {
                "avg_fps": 0,
                "min_fps": 0,
                "max_fps": 0,
                "avg_memory_mb": 0
            },
            "errors": []
        }

        # Save test results
        results_file = test_run_dir / "results.json"
        with open(results_file, 'w') as f:
            json.dump(test_results, f, indent=2)

        return test_results

    def analyze_visual_results(self, test_results: Dict) -> Dict:
        """Use multimodal AI to analyze screenshots"""
        if not self.client or not test_results.get("screenshots"):
            return {
                "status": "skipped",
                "issues": [],
                "suggestions": []
            }

        # TODO: Implement actual visual analysis with Claude Vision
        analysis = {
            "status": "placeholder",
            "issues": [],
            "suggestions": [],
            "confidence": 0.0
        }

        return analysis

    def evaluate_performance(self, test_results: Dict) -> Tuple[bool, List[str]]:
        """Evaluate if performance meets targets"""
        perf = test_results.get("performance", {})
        avg_fps = perf.get("avg_fps", 0)

        issues = []

        if avg_fps < self.config["target_fps"]:
            issues.append(f"FPS below target: {avg_fps} < {self.config['target_fps']}")

        passed = len(issues) == 0
        return passed, issues

    def decide_iteration(self, test_results: Dict, visual_analysis: Dict,
                        performance_issues: List[str], iteration: int) -> str:
        """Decide whether to iterate, accept, or restart"""

        if iteration >= self.config["max_iterations"]:
            return "max_iterations_reached"

        if test_results.get("errors"):
            return "iterate"

        if performance_issues:
            return "iterate"

        if visual_analysis.get("issues"):
            return "iterate"

        return "accept"

    def log_iteration(self, iteration: int, test_results: Dict, visual_analysis: Dict,
                     decision: str):
        """Log iteration details for meta-analysis"""
        log_entry = {
            "iteration": iteration,
            "timestamp": datetime.now().isoformat(),
            "test_results": test_results,
            "visual_analysis": visual_analysis,
            "decision": decision
        }

        log_file = self.docs_dir / "iteration_log.jsonl"
        with open(log_file, 'a') as f:
            f.write(json.dumps(log_entry) + '\n')

    def run_pipeline(self, prompt_file: Path, build_name: Optional[str] = None):
        """Execute the complete pipeline"""
        print("=" * 80)
        print("AI-Driven Game Development Pipeline")
        print("=" * 80)

        # Load prompt
        scene_description = self.load_prompt(prompt_file)
        print(f"\nScene Description:\n{scene_description}\n")

        if not build_name:
            build_name = f"build_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

        # Save prompt
        prompt_save_path = self.prompts_dir / f"{build_name}.txt"
        prompt_save_path.write_text(scene_description)

        iteration = 0
        decision = "iterate"

        while decision == "iterate" and iteration < self.config["max_iterations"]:
            print(f"\n{'=' * 80}")
            print(f"ITERATION {iteration + 1}")
            print(f"{'=' * 80}\n")

            # Generate code
            print("Generating game code...")
            code_files = self.generate_game_code(scene_description, iteration)

            # Save code
            build_dir = self.save_generated_code(code_files, f"{build_name}_iter{iteration}")

            # Run tests
            test_results = self.run_game_tests(build_dir)

            # Analyze visuals
            print("Analyzing visual results...")
            visual_analysis = self.analyze_visual_results(test_results)

            # Evaluate performance
            print("Evaluating performance...")
            perf_passed, perf_issues = self.evaluate_performance(test_results)

            # Decide next step
            decision = self.decide_iteration(test_results, visual_analysis,
                                            perf_issues, iteration)

            # Log iteration
            self.log_iteration(iteration, test_results, visual_analysis, decision)

            print(f"\nDecision: {decision}")
            if perf_issues:
                print("Performance issues:")
                for issue in perf_issues:
                    print(f"  - {issue}")

            iteration += 1

        print(f"\n{'=' * 80}")
        print(f"Pipeline completed after {iteration} iteration(s)")
        print(f"Final decision: {decision}")
        print(f"{'=' * 80}\n")


def main():
    parser = argparse.ArgumentParser(description="AI-Driven Game Development Pipeline Orchestrator")
    parser.add_argument("--prompt", type=str, required=True,
                       help="Path to scene description prompt file")
    parser.add_argument("--build-name", type=str, default=None,
                       help="Name for this build (default: auto-generated)")
    parser.add_argument("--max-iterations", type=int, default=5,
                       help="Maximum number of iterations (default: 5)")

    args = parser.parse_args()

    # Get workspace root (parent of scripts directory)
    workspace_root = Path(__file__).parent.parent

    # Create orchestrator
    orchestrator = GameDevOrchestrator(workspace_root)
    orchestrator.config["max_iterations"] = args.max_iterations

    # Run pipeline
    prompt_path = Path(args.prompt)
    if not prompt_path.exists():
        print(f"Error: Prompt file not found: {prompt_path}")
        sys.exit(1)

    orchestrator.run_pipeline(prompt_path, args.build_name)


if __name__ == "__main__":
    main()
