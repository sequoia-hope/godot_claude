#!/usr/bin/env python3
"""
Effects Injector - Injects visual effects into Godot game builds.

Supports:
- fisheye: Barrel distortion fisheye camera effect

Usage:
    python scripts/effects_injector.py ./code/my_game --effect fisheye

    # Or from orchestrator.py:
    python scripts/orchestrator.py --feature fisheye --build-dir ./code/my_game
"""

import argparse
import json
import re
import shutil
from pathlib import Path
from typing import Dict, List, Optional


AVAILABLE_EFFECTS = ["fisheye"]


class EffectsInjector:
    """Injects visual effects into Godot game builds."""

    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root
        self.templates_dir = workspace_root / "templates" / "effects"

    def inject_effect(
        self,
        build_dir: Path,
        effect: str,
        config: Optional[Dict] = None,
    ) -> Dict:
        """
        Inject a visual effect into a game build.

        Args:
            build_dir: Path to the game build directory
            effect: Effect name (e.g., "fisheye")
            config: Optional effect configuration

        Returns:
            Dictionary with injection results
        """
        result = {
            "status": "success",
            "effect": effect,
            "files_copied": [],
            "files_modified": [],
            "warnings": [],
            "errors": [],
        }

        if effect not in AVAILABLE_EFFECTS:
            result["status"] = "error"
            result["errors"].append(f"Unknown effect: {effect}. Available: {AVAILABLE_EFFECTS}")
            return result

        if not build_dir.exists():
            result["status"] = "error"
            result["errors"].append(f"Build directory not found: {build_dir}")
            return result

        project_file = build_dir / "project.godot"
        if not project_file.exists():
            result["status"] = "error"
            result["errors"].append(f"project.godot not found in {build_dir}")
            return result

        print(f"Injecting '{effect}' effect into: {build_dir}")

        if effect == "fisheye":
            return self._inject_fisheye(build_dir, config or {}, result)

        return result

    def _inject_fisheye(self, build_dir: Path, config: Dict, result: Dict) -> Dict:
        """Inject fisheye effect into a build."""

        # Copy shader file
        shader_src = self.templates_dir / "fisheye.gdshader"
        shader_dst = build_dir / "fisheye.gdshader"
        if shader_src.exists():
            shutil.copy2(shader_src, shader_dst)
            result["files_copied"].append("fisheye.gdshader")
            print(f"  Copied: fisheye.gdshader")
        else:
            result["warnings"].append("fisheye.gdshader template not found")

        # Copy wrapper script
        wrapper_src = self.templates_dir / "fisheye_wrapper.gd"
        wrapper_dst = build_dir / "fisheye_wrapper.gd"
        if wrapper_src.exists():
            # Read and optionally modify with config
            content = wrapper_src.read_text()

            # Apply config overrides
            distortion = config.get("distortion_strength", 0.4)
            vignette = config.get("vignette_strength", 0.3)

            content = re.sub(
                r'@export var distortion_strength: float = [\d.]+',
                f'@export var distortion_strength: float = {distortion}',
                content
            )
            content = re.sub(
                r'@export var vignette_strength: float = [\d.]+',
                f'@export var vignette_strength: float = {vignette}',
                content
            )

            wrapper_dst.write_text(content)
            result["files_copied"].append("fisheye_wrapper.gd")
            print(f"  Copied: fisheye_wrapper.gd (distortion={distortion}, vignette={vignette})")
        else:
            result["errors"].append("fisheye_wrapper.gd template not found")
            result["status"] = "error"
            return result

        # Add autoload to project.godot
        project_file = build_dir / "project.godot"
        modified = self._add_autoload(project_file, "FisheyeWrapper", "res://fisheye_wrapper.gd")
        if modified:
            result["files_modified"].append("project.godot")
            print(f"  Modified: project.godot (added FisheyeWrapper autoload)")

        print(f"\nFisheye effect injected successfully!")
        return result

    def remove_effect(self, build_dir: Path, effect: str) -> Dict:
        """Remove an effect from a game build."""
        result = {
            "status": "success",
            "effect": effect,
            "files_removed": [],
            "files_modified": [],
            "errors": [],
        }

        print(f"Removing '{effect}' effect from: {build_dir}")

        if effect == "fisheye":
            # Remove files
            files_to_remove = ["fisheye.gdshader", "fisheye_wrapper.gd"]
            for filename in files_to_remove:
                filepath = build_dir / filename
                if filepath.exists():
                    filepath.unlink()
                    result["files_removed"].append(filename)
                    print(f"  Removed: {filename}")

            # Remove autoload
            project_file = build_dir / "project.godot"
            if project_file.exists():
                modified = self._remove_autoload(project_file, "FisheyeWrapper")
                if modified:
                    result["files_modified"].append("project.godot")
                    print(f"  Modified: project.godot (removed FisheyeWrapper autoload)")

        print(f"\nEffect removal complete!")
        return result

    def _add_autoload(self, project_file: Path, name: str, path: str) -> bool:
        """Add an autoload entry to project.godot."""
        content = project_file.read_text()
        autoload_line = f'{name}="*{path}"'

        # Check if already present with correct path
        if autoload_line in content:
            return False

        # Remove existing entry if present (might have different path)
        content = self._remove_autoload_from_content(content, name)

        # Check if [autoload] section exists
        if '[autoload]' in content:
            # Add entry after [autoload] section header
            content = re.sub(
                r'(\[autoload\]\n)',
                f'\\1{autoload_line}\n',
                content
            )
        else:
            # No [autoload] section - create one
            # Try to insert before [rendering]
            if '[rendering]' in content:
                content = re.sub(
                    r'(\n?)(\[rendering\])',
                    f'\n[autoload]\n{autoload_line}\n\\2',
                    content
                )
            else:
                # Add at end
                content = content.rstrip() + f'\n\n[autoload]\n{autoload_line}\n'

        project_file.write_text(content)
        return True

    def _remove_autoload(self, project_file: Path, name: str) -> bool:
        """Remove an autoload entry from project.godot."""
        content = project_file.read_text()

        if f'{name}=' not in content:
            return False

        content = self._remove_autoload_from_content(content, name)
        project_file.write_text(content)
        return True

    def _remove_autoload_from_content(self, content: str, name: str) -> str:
        """Remove autoload entry from content string."""
        lines = content.split('\n')
        new_lines = []

        for line in lines:
            if line.strip().startswith(f'{name}='):
                continue
            new_lines.append(line)

        content = '\n'.join(new_lines)

        # Clean up empty [autoload] section
        content = re.sub(r'\[autoload\]\s*\n\s*\n\[', '[', content)
        content = re.sub(r'\[autoload\]\s*$', '', content)

        return content


def inject_effect(
    build_dir: Path,
    effect: str,
    workspace_root: Optional[Path] = None,
    config: Optional[Dict] = None,
) -> Dict:
    """
    Convenience function to inject an effect.

    Args:
        build_dir: Path to game build directory
        effect: Effect name
        workspace_root: Workspace root (auto-detected if None)
        config: Optional effect configuration

    Returns:
        Injection result dictionary
    """
    if workspace_root is None:
        workspace_root = Path(__file__).parent.parent

    injector = EffectsInjector(workspace_root)
    return injector.inject_effect(build_dir, effect, config)


def main():
    parser = argparse.ArgumentParser(
        description="Inject visual effects into Godot game builds",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Available effects: {', '.join(AVAILABLE_EFFECTS)}

Examples:
    # Inject fisheye effect
    python effects_injector.py ./code/my_game --effect fisheye

    # Inject with custom distortion
    python effects_injector.py ./code/my_game --effect fisheye --distortion 0.5

    # Remove effect
    python effects_injector.py ./code/my_game --effect fisheye --remove
        """,
    )

    parser.add_argument(
        "build_dir",
        type=str,
        help="Path to game build directory",
    )
    parser.add_argument(
        "--effect",
        type=str,
        required=True,
        choices=AVAILABLE_EFFECTS,
        help="Effect to inject",
    )
    parser.add_argument(
        "--remove",
        action="store_true",
        help="Remove the effect instead of injecting",
    )
    parser.add_argument(
        "--distortion",
        type=float,
        default=0.4,
        help="Fisheye distortion strength (0.0-1.0)",
    )
    parser.add_argument(
        "--vignette",
        type=float,
        default=0.3,
        help="Fisheye vignette strength (0.0-1.0)",
    )

    args = parser.parse_args()

    workspace_root = Path(__file__).parent.parent
    build_dir = Path(args.build_dir)

    if not build_dir.is_absolute():
        build_dir = workspace_root / args.build_dir

    injector = EffectsInjector(workspace_root)

    if args.remove:
        result = injector.remove_effect(build_dir, args.effect)
    else:
        config = {
            "distortion_strength": args.distortion,
            "vignette_strength": args.vignette,
        }
        result = injector.inject_effect(build_dir, args.effect, config)

    if result.get("errors"):
        for error in result["errors"]:
            print(f"ERROR: {error}")
        exit(1)


if __name__ == "__main__":
    main()
