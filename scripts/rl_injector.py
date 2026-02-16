#!/usr/bin/env python3
"""
RL Injector - Injects RL training support into Godot game builds.

This script copies the necessary RL scripts and configuration to a game build
and modifies project.godot to enable the RL environment as an autoload.

Usage:
    python scripts/rl_injector.py ./code/nintendo_walk

    # Or from orchestrator.py:
    python scripts/orchestrator.py --feature rl_agents --build-dir ./code/nintendo_walk
"""

import argparse
import json
import re
import shutil
from pathlib import Path
from typing import Dict, List, Optional


class RLInjector:
    """Injects RL training support into Godot game builds."""

    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root
        self.templates_dir = workspace_root / "templates" / "rl"

        # Files to inject
        self.rl_files = [
            "rl_env.gd",
            "rl_server.gd",
            "track_progress.gd",
            "path_progress.gd",
            "rl_config.json",
        ]

    def inject_rl_support(
        self,
        build_dir: Path,
        progress_provider: str = "path_progress",
        config_overrides: Optional[Dict] = None,
    ) -> Dict:
        """
        Inject RL support into a game build.

        Args:
            build_dir: Path to the game build directory
            progress_provider: Name of progress provider to use
            config_overrides: Optional config overrides

        Returns:
            Dictionary with injection results
        """
        result = {
            "status": "success",
            "files_copied": [],
            "files_modified": [],
            "warnings": [],
            "errors": [],
        }

        # Validate build directory
        if not build_dir.exists():
            result["status"] = "error"
            result["errors"].append(f"Build directory not found: {build_dir}")
            return result

        project_file = build_dir / "project.godot"
        if not project_file.exists():
            result["status"] = "error"
            result["errors"].append(f"project.godot not found in {build_dir}")
            return result

        print(f"Injecting RL support into: {build_dir}")

        # Copy RL scripts
        for filename in self.rl_files:
            src = self.templates_dir / filename
            dst = build_dir / filename

            if not src.exists():
                result["warnings"].append(f"Template not found: {src}")
                continue

            shutil.copy2(src, dst)
            result["files_copied"].append(filename)
            print(f"  Copied: {filename}")

        # Copy the specified progress provider as path_progress.gd
        # (This is what rl_env.gd expects to load)
        provider_src = self.templates_dir / f"{progress_provider}.gd"
        provider_dst = build_dir / "path_progress.gd"
        if provider_src.exists() and progress_provider != "path_progress":
            shutil.copy2(provider_src, provider_dst)
            print(f"  Copied: {progress_provider}.gd -> path_progress.gd")

        # Customize config if overrides provided
        if config_overrides:
            config_file = build_dir / "rl_config.json"
            if config_file.exists():
                with open(config_file) as f:
                    config = json.load(f)

                # Deep merge overrides
                self._deep_merge(config, config_overrides)

                with open(config_file, "w") as f:
                    json.dump(config, f, indent=2)
                result["files_modified"].append("rl_config.json")
                print("  Modified: rl_config.json with overrides")

        # Modify project.godot to add RLEnv autoload
        modified = self._add_autoload(project_file, "RLEnv", "res://rl_env.gd")
        if modified:
            result["files_modified"].append("project.godot")
            print("  Modified: project.godot (added RLEnv autoload)")

        # Check for terrain.gd (required for path_progress)
        if progress_provider == "path_progress":
            terrain_file = build_dir / "terrain.gd"
            if not terrain_file.exists():
                result["warnings"].append(
                    "terrain.gd not found - path_progress.gd may not work correctly"
                )

        print(f"\nRL injection complete!")
        print(f"  Files copied: {len(result['files_copied'])}")
        print(f"  Files modified: {len(result['files_modified'])}")

        if result["warnings"]:
            print("\nWarnings:")
            for warning in result["warnings"]:
                print(f"  - {warning}")

        return result

    def remove_rl_support(self, build_dir: Path) -> Dict:
        """
        Remove RL support from a game build.

        Args:
            build_dir: Path to the game build directory

        Returns:
            Dictionary with removal results
        """
        result = {
            "status": "success",
            "files_removed": [],
            "files_modified": [],
            "errors": [],
        }

        print(f"Removing RL support from: {build_dir}")

        # Remove RL files
        for filename in self.rl_files:
            filepath = build_dir / filename
            if filepath.exists():
                filepath.unlink()
                result["files_removed"].append(filename)
                print(f"  Removed: {filename}")

        # Remove autoload from project.godot
        project_file = build_dir / "project.godot"
        if project_file.exists():
            modified = self._remove_autoload(project_file, "RLEnv")
            if modified:
                result["files_modified"].append("project.godot")
                print("  Modified: project.godot (removed RLEnv autoload)")

        print(f"\nRL removal complete!")
        return result

    def _add_autoload(self, project_file: Path, name: str, path: str) -> bool:
        """Add an autoload entry to project.godot."""
        content = project_file.read_text()

        # Check if already present
        if f'{name}=' in content and path in content:
            return False

        # Remove existing entry if present (in case path changed)
        content = self._remove_autoload_from_content(content, name)

        # Add autoload section if not present
        if "[autoload]" not in content:
            content += "\n[autoload]\n"

        # Add autoload entry
        autoload_line = f'\n{name}="*{path}"\n'
        content = content.replace("[autoload]", "[autoload]" + autoload_line)

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
            # Skip lines that define this autoload
            if line.strip().startswith(f'{name}='):
                continue
            new_lines.append(line)

        content = '\n'.join(new_lines)

        # Clean up empty [autoload] section
        content = re.sub(r'\[autoload\]\s*\n\s*\n', '', content)

        return content

    def _deep_merge(self, base: Dict, overrides: Dict):
        """Deep merge overrides into base dict."""
        for key, value in overrides.items():
            if key in base and isinstance(base[key], dict) and isinstance(value, dict):
                self._deep_merge(base[key], value)
            else:
                base[key] = value


def inject_rl_support(
    build_dir: Path,
    workspace_root: Optional[Path] = None,
    progress_provider: str = "path_progress",
    config_overrides: Optional[Dict] = None,
) -> Dict:
    """
    Convenience function to inject RL support.

    Args:
        build_dir: Path to game build directory
        workspace_root: Workspace root (auto-detected if None)
        progress_provider: Progress provider to use
        config_overrides: Optional config overrides

    Returns:
        Injection result dictionary
    """
    if workspace_root is None:
        workspace_root = Path(__file__).parent.parent

    injector = RLInjector(workspace_root)
    return injector.inject_rl_support(
        build_dir,
        progress_provider=progress_provider,
        config_overrides=config_overrides,
    )


def main():
    parser = argparse.ArgumentParser(
        description="Inject RL training support into Godot game builds",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Inject RL support into a build
    python rl_injector.py ./code/nintendo_walk

    # Remove RL support
    python rl_injector.py ./code/nintendo_walk --remove

    # Use custom config
    python rl_injector.py ./code/nintendo_walk --port 12000
        """,
    )

    parser.add_argument(
        "build_dir",
        type=str,
        help="Path to game build directory",
    )
    parser.add_argument(
        "--remove",
        action="store_true",
        help="Remove RL support instead of injecting",
    )
    parser.add_argument(
        "--progress-provider",
        type=str,
        default="path_progress",
        help="Progress provider to use (default: path_progress)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=None,
        help="Override TCP port in config",
    )
    parser.add_argument(
        "--max-steps",
        type=int,
        default=None,
        help="Override max episode steps",
    )

    args = parser.parse_args()

    workspace_root = Path(__file__).parent.parent
    build_dir = Path(args.build_dir)

    if not build_dir.is_absolute():
        build_dir = workspace_root / args.build_dir

    injector = RLInjector(workspace_root)

    if args.remove:
        result = injector.remove_rl_support(build_dir)
    else:
        # Build config overrides
        config_overrides = {}
        if args.port:
            config_overrides["server"] = {"port": args.port}
        if args.max_steps:
            config_overrides["episode"] = {"max_steps": args.max_steps}

        result = injector.inject_rl_support(
            build_dir,
            progress_provider=args.progress_provider,
            config_overrides=config_overrides if config_overrides else None,
        )

    # Exit with appropriate code
    if result.get("errors"):
        for error in result["errors"]:
            print(f"ERROR: {error}")
        exit(1)


if __name__ == "__main__":
    main()
