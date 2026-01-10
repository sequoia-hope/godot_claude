#!/usr/bin/env python3
"""
Performance Profiling Module

Analyzes game performance metrics and provides optimization suggestions
when performance targets are not met.
"""

import json
import argparse
from pathlib import Path
from typing import Dict, List, Tuple


class PerformanceProfiler:
    """Analyzes performance data and suggests optimizations"""

    def __init__(self, target_fps: int = 60):
        self.target_fps = target_fps
        self.acceptable_fps_threshold = target_fps * 0.8  # 80% of target

    def analyze_results(self, test_results: Dict) -> Dict:
        """
        Analyze performance results from test run

        Args:
            test_results: Dict containing performance metrics

        Returns:
            Dict with analysis and recommendations
        """
        performance = test_results.get("performance", {})

        if not performance:
            return {
                "status": "no_data",
                "passed": False,
                "issues": ["No performance data available"],
                "recommendations": []
            }

        avg_fps = performance.get("avg_fps", 0)
        min_fps = performance.get("min_fps", 0)
        max_fps = performance.get("max_fps", 0)
        avg_memory_mb = performance.get("avg_memory_mb", 0)

        # Analyze results
        issues = []
        recommendations = []
        bottlenecks = []

        # FPS Analysis
        if avg_fps < self.acceptable_fps_threshold:
            issues.append(f"Average FPS ({avg_fps:.1f}) below acceptable threshold ({self.acceptable_fps_threshold:.1f})")
            bottlenecks.append("frame_rate")

        if min_fps < self.target_fps * 0.5:
            issues.append(f"Minimum FPS ({min_fps:.1f}) indicates severe frame drops")
            bottlenecks.append("frame_drops")

        # Memory Analysis
        if avg_memory_mb > 512:  # More than 512 MB for a simple test room is excessive
            issues.append(f"High memory usage: {avg_memory_mb:.1f} MB")
            bottlenecks.append("memory")

        # Generate recommendations based on bottlenecks
        recommendations = self._generate_recommendations(bottlenecks, performance)

        # Determine pass/fail
        passed = len(issues) == 0

        analysis = {
            "status": "passed" if passed else "failed",
            "passed": passed,
            "metrics": {
                "avg_fps": avg_fps,
                "min_fps": min_fps,
                "max_fps": max_fps,
                "avg_memory_mb": avg_memory_mb,
                "target_fps": self.target_fps
            },
            "issues": issues,
            "bottlenecks": bottlenecks,
            "recommendations": recommendations,
            "performance_score": self._calculate_performance_score(avg_fps, min_fps, avg_memory_mb)
        }

        return analysis

    def _generate_recommendations(self, bottlenecks: List[str], performance: Dict) -> List[str]:
        """Generate optimization recommendations based on identified bottlenecks"""
        recommendations = []

        if "frame_rate" in bottlenecks or "frame_drops" in bottlenecks:
            recommendations.extend([
                "Consider implementing Level of Detail (LOD) system for meshes",
                "Reduce draw calls by batching similar objects",
                "Optimize shader complexity or use simpler materials",
                "Implement frustum culling to avoid rendering off-screen objects",
                "Check for expensive operations in _process() or _physics_process()",
                "Use object pooling to reduce instantiation overhead"
            ])

        if "memory" in bottlenecks:
            recommendations.extend([
                "Optimize texture sizes and use compression",
                "Implement texture streaming for large assets",
                "Check for memory leaks in script code",
                "Use resource preloading efficiently",
                "Consider using lower-poly models for distant objects"
            ])

        # Algorithmic suggestions
        if performance.get("avg_fps", 0) < 30:
            recommendations.extend([
                "Consider spatial partitioning (octree/quadtree) for collision detection",
                "Switch from per-pixel lighting to lightmaps for static geometry",
                "Implement occlusion culling for complex scenes"
            ])

        return recommendations

    def _calculate_performance_score(self, avg_fps: float, min_fps: float,
                                     avg_memory_mb: float) -> float:
        """
        Calculate overall performance score (0.0 - 1.0)

        Weighted combination of:
        - 50%: Average FPS vs target
        - 30%: Minimum FPS vs target (stability)
        - 20%: Memory efficiency
        """
        # FPS score (50% weight)
        fps_score = min(avg_fps / self.target_fps, 1.0) * 0.5

        # Stability score (30% weight)
        stability_score = min(min_fps / (self.target_fps * 0.8), 1.0) * 0.3

        # Memory score (20% weight) - assume 256 MB is ideal for simple scene
        ideal_memory = 256
        if avg_memory_mb <= ideal_memory:
            memory_score = 0.2
        else:
            # Degrade score as memory increases
            memory_score = max(0, 0.2 * (1 - (avg_memory_mb - ideal_memory) / ideal_memory))

        total_score = fps_score + stability_score + memory_score
        return round(total_score, 3)

    def suggest_next_steps(self, analysis: Dict) -> List[str]:
        """Suggest concrete next steps based on analysis"""
        next_steps = []

        if analysis["passed"]:
            next_steps.append("Performance targets met - ready to add complexity")
            next_steps.append("Consider adding more detailed assets or gameplay features")
        else:
            score = analysis["performance_score"]

            if score < 0.3:
                next_steps.append("Performance severely below target - consider clean slate restart")
                next_steps.append("Simplify scene: reduce geometry, lighting, and effects")
            elif score < 0.7:
                next_steps.append("Performance needs improvement - apply recommended optimizations")
                next_steps.append("Profile specific bottlenecks with Godot's profiler")
            else:
                next_steps.append("Performance close to target - minor optimizations needed")

        return next_steps


def main():
    parser = argparse.ArgumentParser(description="Performance Profiling Module")
    parser.add_argument("results_file", type=str, help="Path to test results JSON file")
    parser.add_argument("--target-fps", type=int, default=60, help="Target FPS (default: 60)")
    parser.add_argument("--output", type=str, default=None,
                       help="Output file for analysis (default: same dir as results)")

    args = parser.parse_args()

    results_file = Path(args.results_file)
    if not results_file.exists():
        print(f"Error: Results file not found: {results_file}")
        return 1

    # Load results
    with open(results_file, 'r') as f:
        test_results = json.load(f)

    # Analyze
    profiler = PerformanceProfiler(target_fps=args.target_fps)
    analysis = profiler.analyze_results(test_results)

    # Get next steps
    next_steps = profiler.suggest_next_steps(analysis)
    analysis["next_steps"] = next_steps

    # Save analysis
    output_file = Path(args.output) if args.output else results_file.parent / "performance_analysis.json"
    with open(output_file, 'w') as f:
        json.dump(analysis, f, indent=2)

    # Print summary
    print("\n" + "=" * 80)
    print("PERFORMANCE ANALYSIS")
    print("=" * 80)
    print(f"Status: {analysis['status'].upper()}")
    print(f"Performance Score: {analysis['performance_score']:.2f}/1.00")
    print(f"\nMetrics:")
    print(f"  Average FPS: {analysis['metrics']['avg_fps']:.1f} (target: {analysis['metrics']['target_fps']})")
    print(f"  Min FPS: {analysis['metrics']['min_fps']:.1f}")
    print(f"  Max FPS: {analysis['metrics']['max_fps']:.1f}")
    print(f"  Memory: {analysis['metrics']['avg_memory_mb']:.1f} MB")

    if analysis["issues"]:
        print(f"\nIssues ({len(analysis['issues'])}):")
        for issue in analysis["issues"]:
            print(f"  - {issue}")

    if analysis["recommendations"]:
        print(f"\nRecommendations ({len(analysis['recommendations'])}):")
        for i, rec in enumerate(analysis["recommendations"][:5], 1):  # Show top 5
            print(f"  {i}. {rec}")

    if analysis["next_steps"]:
        print(f"\nNext Steps:")
        for step in analysis["next_steps"]:
            print(f"  - {step}")

    print(f"\nDetailed analysis saved to: {output_file}")
    print("=" * 80 + "\n")

    return 0 if analysis["passed"] else 1


if __name__ == "__main__":
    exit(main())
