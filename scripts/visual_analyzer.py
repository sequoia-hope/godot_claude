#!/usr/bin/env python3
"""
Visual Analysis Module

Uses Claude's multimodal API to analyze game screenshots and validate:
- Correctness of rendered environment
- Player movement validation
- Animation playback verification
- Visual artifacts or rendering errors
- Overall scene composition
"""

import os
import sys
import json
import base64
import argparse
from pathlib import Path
from typing import List, Dict, Optional

try:
    import anthropic
except ImportError:
    print("Error: anthropic package not installed. Install with: pip install anthropic")
    sys.exit(1)


class VisualAnalyzer:
    """Analyzes game screenshots using multimodal AI"""

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        if not self.api_key:
            raise ValueError("ANTHROPIC_API_KEY not found in environment")

        self.client = anthropic.Anthropic(api_key=self.api_key)
        self.model = "claude-sonnet-4-5-20250929"

    def load_image_base64(self, image_path: Path) -> str:
        """Load image and convert to base64"""
        with open(image_path, 'rb') as f:
            image_data = f.read()
        return base64.standard_b64encode(image_data).decode('utf-8')

    def analyze_screenshot(self, image_path: Path, context: Dict) -> Dict:
        """
        Analyze a single screenshot

        Args:
            image_path: Path to screenshot PNG file
            context: Dict with test context (test_name, description, expected_result)

        Returns:
            Dict with analysis results
        """
        print(f"Analyzing: {image_path.name}")

        # Load image
        image_base64 = self.load_image_base64(image_path)

        # Determine media type
        media_type = "image/png"
        if image_path.suffix.lower() in ['.jpg', '.jpeg']:
            media_type = "image/jpeg"

        # Build prompt
        test_name = context.get('test_name', 'unknown')
        description = context.get('description', '')
        expected = context.get('expected_result', '')

        prompt = f"""Analyze this game screenshot from a test run.

Test: {test_name}
Description: {description}
Expected: {expected}

Please evaluate:
1. Visual Quality: Is the scene rendered correctly? Any visual artifacts, missing textures, or rendering errors?
2. Environment: Are all expected elements visible (walls, floor, objects)?
3. Lighting: Is lighting adequate to see the environment?
4. Camera: Is the camera positioned and oriented correctly?
5. Player: If a player character should be visible, is it rendered properly?

Provide your analysis in JSON format:
{{
    "overall_quality": "good|acceptable|poor",
    "issues": ["list of specific issues found"],
    "observations": ["list of notable observations"],
    "recommendations": ["suggested fixes or improvements"],
    "confidence": 0.0-1.0
}}"""

        try:
            response = self.client.messages.create(
                model=self.model,
                max_tokens=1024,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "image",
                                "source": {
                                    "type": "base64",
                                    "media_type": media_type,
                                    "data": image_base64
                                }
                            },
                            {
                                "type": "text",
                                "text": prompt
                            }
                        ]
                    }
                ]
            )

            # Parse response
            response_text = response.content[0].text

            # Extract JSON if wrapped in markdown
            if "```json" in response_text:
                json_start = response_text.find("```json") + 7
                json_end = response_text.find("```", json_start)
                response_text = response_text[json_start:json_end].strip()
            elif "```" in response_text:
                json_start = response_text.find("```") + 3
                json_end = response_text.find("```", json_start)
                response_text = response_text[json_start:json_end].strip()

            analysis = json.loads(response_text)
            analysis['screenshot'] = str(image_path)

            return analysis

        except Exception as e:
            print(f"Error analyzing screenshot: {e}")
            return {
                "overall_quality": "error",
                "issues": [f"Analysis failed: {str(e)}"],
                "observations": [],
                "recommendations": [],
                "confidence": 0.0,
                "screenshot": str(image_path)
            }

    def analyze_test_sequence(self, screenshots: List[Path], test_results: Dict) -> Dict:
        """
        Analyze a sequence of screenshots from a test run

        Args:
            screenshots: List of screenshot paths
            test_results: Dict with test metadata

        Returns:
            Dict with comprehensive analysis
        """
        print(f"\nAnalyzing {len(screenshots)} screenshots...")

        analyses = []
        all_issues = []
        all_recommendations = []

        for screenshot in screenshots:
            # Extract test name from filename
            # Format: 001_test_name_start.png
            parts = screenshot.stem.split('_', 1)
            test_name = parts[1] if len(parts) > 1 else screenshot.stem

            context = {
                "test_name": test_name,
                "description": f"Screenshot from test: {test_name}",
                "expected_result": "Clean render with no artifacts"
            }

            analysis = self.analyze_screenshot(screenshot, context)
            analyses.append(analysis)

            # Collect issues
            if analysis.get('issues'):
                all_issues.extend(analysis['issues'])

            if analysis.get('recommendations'):
                all_recommendations.extend(analysis['recommendations'])

        # Aggregate results
        quality_scores = [a.get('overall_quality', 'poor') for a in analyses]
        good_count = quality_scores.count('good')
        acceptable_count = quality_scores.count('acceptable')
        poor_count = quality_scores.count('poor')

        overall_status = "passed"
        if poor_count > len(analyses) * 0.3:  # More than 30% poor quality
            overall_status = "failed"
        elif poor_count > 0 or acceptable_count > len(analyses) * 0.5:
            overall_status = "needs_improvement"

        comprehensive_analysis = {
            "status": overall_status,
            "screenshot_count": len(screenshots),
            "quality_breakdown": {
                "good": good_count,
                "acceptable": acceptable_count,
                "poor": poor_count
            },
            "all_issues": list(set(all_issues)),  # Deduplicate
            "all_recommendations": list(set(all_recommendations)),  # Deduplicate
            "individual_analyses": analyses,
            "summary": self._generate_summary(analyses, overall_status)
        }

        return comprehensive_analysis

    def _generate_summary(self, analyses: List[Dict], overall_status: str) -> str:
        """Generate human-readable summary"""
        if overall_status == "passed":
            return "All screenshots show good visual quality with no major issues."
        elif overall_status == "needs_improvement":
            return "Some screenshots show acceptable quality but there are areas for improvement."
        else:
            return "Multiple screenshots show poor quality or significant rendering issues."


def main():
    parser = argparse.ArgumentParser(description="Visual Analysis Module")
    parser.add_argument("test_dir", type=str, help="Directory containing test screenshots and results")
    parser.add_argument("--output", type=str, default=None,
                       help="Output file for analysis results (default: test_dir/visual_analysis.json)")

    args = parser.parse_args()

    test_dir = Path(args.test_dir)
    if not test_dir.exists():
        print(f"Error: Test directory not found: {test_dir}")
        sys.exit(1)

    # Load test results if available
    results_file = test_dir / "results.json"
    test_results = {}
    if results_file.exists():
        with open(results_file, 'r') as f:
            test_results = json.load(f)

    # Find all screenshots
    screenshots = sorted(test_dir.glob("*.png"))
    if not screenshots:
        print(f"Warning: No screenshots found in {test_dir}")
        sys.exit(0)

    # Analyze
    analyzer = VisualAnalyzer()
    analysis = analyzer.analyze_test_sequence(screenshots, test_results)

    # Save results
    output_file = Path(args.output) if args.output else test_dir / "visual_analysis.json"
    with open(output_file, 'w') as f:
        json.dump(analysis, f, indent=2)

    print(f"\nAnalysis complete!")
    print(f"Status: {analysis['status']}")
    print(f"Quality: {analysis['quality_breakdown']}")
    print(f"Issues found: {len(analysis['all_issues'])}")
    print(f"Results saved to: {output_file}")


if __name__ == "__main__":
    main()
