#!/usr/bin/env python3
"""
Godot Code Validator - Checks generated Godot code for common issues.

Validates:
- GDScript syntax and common mistakes
- Scene file structure
- Project.godot configuration
- Known Godot 4.x compatibility issues
"""

import re
from pathlib import Path
from typing import Dict, List, Optional


# Classes that don't exist in Godot 4.x (common mistakes)
REMOVED_CLASSES = {
    "ConeMesh": "Use CylinderMesh with top_radius=0",
    "SpatialMaterial": "Use StandardMaterial3D",
    "Spatial": "Use Node3D",
    "KinematicBody": "Use CharacterBody3D",
    "KinematicBody2D": "Use CharacterBody2D",
    "RigidBody": "Use RigidBody3D",
    "Area": "Use Area3D",
    "Camera": "Use Camera3D",
    "MeshInstance": "Use MeshInstance3D",
    "CollisionShape": "Use CollisionShape3D",
    "RayCast": "Use RayCast3D",
    "DirectionalLight": "Use DirectionalLight3D",
    "OmniLight": "Use OmniLight3D",
    "SpotLight": "Use SpotLight3D",
    "Particles": "Use GPUParticles3D",
    "Position3D": "Use Marker3D",
    "ProceduralSky": "Use ProceduralSkyMaterial with Sky",
    "GIProbe": "Use VoxelGI",
    "BakedLightmap": "Use LightmapGI",
    "Navigation": "Use NavigationServer3D",
    "VisibilityNotifier": "Use VisibleOnScreenNotifier3D",
    "Listener": "Use AudioListener3D",
}

# Common GDScript issues
GDSCRIPT_ISSUES = [
    {
        "pattern": r"\.connect\s*\(\s*[\"'](\w+)[\"']\s*,\s*self\s*,",
        "message": "Old connect syntax. Use: signal.connect(callable) or signal.connect(_method)",
        "severity": "error",
    },
    {
        "pattern": r"yield\s*\(",
        "message": "yield is removed in Godot 4. Use 'await' instead",
        "severity": "error",
    },
    {
        "pattern": r"\.instance\s*\(\s*\)",
        "message": ".instance() is now .instantiate() in Godot 4",
        "severity": "error",
    },
    {
        "pattern": r"export\s*\(",
        "message": "export() syntax changed. Use @export annotation",
        "severity": "error",
    },
    {
        "pattern": r"(?<!@)onready\s+var",
        "message": "onready is now @onready in Godot 4",
        "severity": "error",
    },
    {
        "pattern": r"remote\s+func|puppet\s+func|master\s+func",
        "message": "Networking keywords changed in Godot 4",
        "severity": "error",
    },
    {
        "pattern": r"\.material_override\s*=",
        "message": "material_override works but set_material() on SurfaceTool is more reliable for procedural meshes",
        "severity": "warning",
    },
    {
        "pattern": r"\bvar\s+\w+\s*:=",
        "message": "Type inference with := may cause errors in strict mode. Use explicit types: 'var x: Type = value'",
        "severity": "warning",
    },
]

# SurfaceTool best practices
SURFACE_TOOL_ISSUES = [
    {
        "pattern": r"SurfaceTool\.new\(\)[\s\S]*?\.commit\(\)(?![\s\S]*?set_material)",
        "message": "SurfaceTool: Call set_material() before commit() for reliable material application",
        "severity": "warning",
    },
]

# Starting direction validation patterns
START_DIRECTION_ISSUES = [
    {
        # Warns if get_start_rotation returns 0.0 when there's track/path code
        "pattern": r"func\s+get_start_rotation\s*\([^)]*\)\s*->\s*float\s*:\s*\n\s*return\s+0\.0",
        "context_pattern": r"(track|path|oval|circuit|road)",
        "message": "get_start_rotation() returns 0.0 (facing -Z). Verify player faces along track/path direction. In Godot: 0=-Z, -PI/2=+X, PI=+Z, PI/2=-X",
        "severity": "warning",
    },
]

# Wheel orientation validation
# Wheel geometry:
#   - CylinderMesh local Y axis = height = wheel axle
#   - Axle must be perpendicular to travel direction AND parallel to floor
#   - For car facing -Z: axle along world X, so transform maps local Y → world X
# Spin animation:
#   - Must rotate around the axle (cylinder's local Y)
#   - Use rotate_object_local(Vector3.UP, delta), NOT Euler rotation.x/y/z = spin
WHEEL_ORIENTATION_ISSUES = [
    {
        # Euler-based wheel spin (problematic due to gimbal lock and composition)
        "pattern": r"\.rotation\.[xyz]\s*=.*spin",
        "context_pattern": r"[Ww]heel|mesh",
        "message": "Euler rotation for wheel spin can cause issues. Use rotate_object_local(Vector3.UP, spin_delta) to spin around the cylinder's local Y axis (the axle)",
        "severity": "warning",
    },
]

# Project.godot validation
PROJECT_REQUIRED_SECTIONS = ["application", "display"]


class ValidationResult:
    def __init__(self):
        self.errors: List[Dict] = []
        self.warnings: List[Dict] = []
        self.info: List[Dict] = []

    def add_error(self, file: str, line: int, message: str):
        self.errors.append({"file": file, "line": line, "message": message})

    def add_warning(self, file: str, line: int, message: str):
        self.warnings.append({"file": file, "line": line, "message": message})

    def add_info(self, file: str, line: int, message: str):
        self.info.append({"file": file, "line": line, "message": message})

    @property
    def is_valid(self) -> bool:
        return len(self.errors) == 0

    def to_dict(self) -> Dict:
        return {
            "valid": self.is_valid,
            "errors": self.errors,
            "warnings": self.warnings,
            "info": self.info,
        }

    def print_report(self):
        if self.errors:
            print(f"\n❌ ERRORS ({len(self.errors)}):")
            for e in self.errors:
                print(f"  {e['file']}:{e['line']}: {e['message']}")

        if self.warnings:
            print(f"\n⚠️  WARNINGS ({len(self.warnings)}):")
            for w in self.warnings:
                print(f"  {w['file']}:{w['line']}: {w['message']}")

        if self.info:
            print(f"\nℹ️  INFO ({len(self.info)}):")
            for i in self.info:
                print(f"  {i['file']}:{i['line']}: {i['message']}")

        if self.is_valid and not self.warnings:
            print("\n✅ All validations passed!")
        elif self.is_valid:
            print(f"\n✅ Valid with {len(self.warnings)} warning(s)")
        else:
            print(f"\n❌ Validation failed with {len(self.errors)} error(s)")


class GodotValidator:
    """Validates Godot project files for common issues."""

    def __init__(self, build_dir: Path):
        self.build_dir = Path(build_dir)
        self.result = ValidationResult()

    def validate_all(self) -> ValidationResult:
        """Run all validations on the build directory."""
        if not self.build_dir.exists():
            self.result.add_error(str(self.build_dir), 0, "Build directory not found")
            return self.result

        # Validate project.godot
        project_file = self.build_dir / "project.godot"
        if project_file.exists():
            self._validate_project_godot(project_file)
        else:
            self.result.add_error("project.godot", 0, "project.godot not found")

        # Validate all .gd files
        for gd_file in self.build_dir.glob("**/*.gd"):
            self._validate_gdscript(gd_file)

        # Validate all .tscn files
        for tscn_file in self.build_dir.glob("**/*.tscn"):
            self._validate_scene(tscn_file)

        return self.result

    def _validate_project_godot(self, file_path: Path):
        """Validate project.godot structure."""
        content = file_path.read_text()
        filename = file_path.name

        # Check for required sections
        for section in PROJECT_REQUIRED_SECTIONS:
            if f"[{section}]" not in content:
                self.result.add_warning(filename, 0, f"Missing [{section}] section")

        # Check autoload section structure
        if "autoload]" in content.lower():
            # Verify autoload entries are under [autoload] section
            lines = content.split("\n")
            in_autoload = False
            for i, line in enumerate(lines, 1):
                if line.strip() == "[autoload]":
                    in_autoload = True
                elif line.strip().startswith("[") and line.strip().endswith("]"):
                    in_autoload = False
                elif '="*res://' in line and not in_autoload:
                    self.result.add_error(
                        filename, i,
                        f"Autoload entry outside [autoload] section: {line.strip()}"
                    )

        # Check main scene is set
        if 'run/main_scene="' not in content:
            self.result.add_error(filename, 0, "No main scene configured")

    def _validate_gdscript(self, file_path: Path):
        """Validate a GDScript file."""
        content = file_path.read_text()
        filename = file_path.name
        lines = content.split("\n")

        # Check for removed classes
        for class_name, replacement in REMOVED_CLASSES.items():
            pattern = rf"\b{class_name}\b"
            for i, line in enumerate(lines, 1):
                # Skip comments and strings
                stripped = line.strip()
                if stripped.startswith("#") or stripped.startswith("##"):
                    continue
                # Remove string literals before checking
                line_no_strings = re.sub(r'"[^"]*"', '""', line)
                line_no_strings = re.sub(r"'[^']*'", "''", line_no_strings)
                if re.search(pattern, line_no_strings):
                    self.result.add_error(
                        filename, i,
                        f"'{class_name}' doesn't exist in Godot 4. {replacement}"
                    )

        # Check for common GDScript issues
        for issue in GDSCRIPT_ISSUES:
            for i, line in enumerate(lines, 1):
                if re.search(issue["pattern"], line):
                    if issue["severity"] == "error":
                        self.result.add_error(filename, i, issue["message"])
                    else:
                        self.result.add_warning(filename, i, issue["message"])

        # Check SurfaceTool usage
        if "SurfaceTool" in content:
            self._validate_surface_tool_usage(filename, content)

        # Check for procedural mesh without proper material
        if "SurfaceTool" in content and "commit()" in content:
            if "set_material(" not in content:
                self.result.add_warning(
                    filename, 0,
                    "SurfaceTool used without set_material() - mesh may render without material"
                )

        # Check starting direction alignment
        self._validate_start_direction(filename, content)

        # Check wheel orientation
        if re.search(r"[Ww]heel", content):
            self._validate_wheel_orientation(filename, content, lines)

    def _validate_start_direction(self, filename: str, content: str):
        """Validate that starting direction aligns with track/path."""
        content_lower = content.lower()

        for issue in START_DIRECTION_ISSUES:
            # Check if this file has track/path context
            if "context_pattern" in issue:
                if not re.search(issue["context_pattern"], content_lower):
                    continue

            # Check for the problematic pattern
            if re.search(issue["pattern"], content):
                # Find line number
                lines = content.split("\n")
                for i, line in enumerate(lines, 1):
                    if "get_start_rotation" in line:
                        if issue["severity"] == "error":
                            self.result.add_error(filename, i, issue["message"])
                        else:
                            self.result.add_warning(filename, i, issue["message"])
                        break

    def _validate_wheel_orientation(self, filename: str, content: str, lines: List[str]):
        """Validate wheel orientation follows physics rules.

        Wheel geometry (CylinderMesh):
        - Local Y axis = cylinder height = wheel axle
        - Axle must be perpendicular to travel AND parallel to floor
        - For car facing -Z: transform must map local Y → world X

        Spin animation:
        - Must rotate around the axle (cylinder's local Y axis)
        - Use rotate_object_local(Vector3.UP, delta), NOT Euler angles
        - Euler angles (rotation.x/y/z = spin) cause issues due to composition
        """
        # Check for Euler-based wheel spin (problematic)
        for i, line in enumerate(lines, 1):
            # Skip comments
            if line.strip().startswith("#"):
                continue

            # Check for Euler rotation assignment with spin
            if re.search(r"\.rotation\.[xyz]\s*=.*spin", line, re.IGNORECASE):
                # Check if we're in wheel-related context
                in_wheel_context = False
                for j in range(max(0, i - 15), i):
                    if re.search(r"wheel|_animate", lines[j], re.IGNORECASE):
                        in_wheel_context = True
                        break

                if in_wheel_context:
                    self.result.add_warning(
                        filename, i,
                        "Euler rotation for wheel spin. Use rotate_object_local(Vector3.UP, delta) to spin around cylinder's local Y axis (the axle)"
                    )

    def _validate_surface_tool_usage(self, filename: str, content: str):
        """Validate SurfaceTool usage patterns."""
        # Check if material is set before vertices
        st_match = re.search(
            r"(SurfaceTool\.new\(\)|\.begin\([^)]+\))[\s\S]*?(\.add_vertex|\.commit)",
            content
        )
        if st_match:
            between = st_match.group(0)
            if "set_material" not in between and ".add_vertex" in between:
                self.result.add_info(
                    filename, 0,
                    "Consider calling set_material() before add_vertex() for reliable material application"
                )

    def _validate_scene(self, file_path: Path):
        """Validate a .tscn scene file."""
        content = file_path.read_text()
        filename = file_path.name

        # Check for Camera3D
        if "type=\"Camera3D\"" in content or "type=\"Camera\"" in content:
            if "current = true" not in content and "current=true" not in content:
                self.result.add_warning(
                    filename, 0,
                    "Scene has Camera3D but 'current = true' not set - camera may not be active"
                )

        # Check for collision shapes
        if "CharacterBody3D" in content or "RigidBody3D" in content:
            if "CollisionShape3D" not in content:
                self.result.add_warning(
                    filename, 0,
                    "Scene has physics body but no CollisionShape3D"
                )

        # Check for lights
        light_types = ["DirectionalLight3D", "OmniLight3D", "SpotLight3D"]
        has_light = any(lt in content for lt in light_types)
        if not has_light and "WorldEnvironment" not in content:
            self.result.add_info(
                filename, 0,
                "Scene has no lights or WorldEnvironment - scene may be dark"
            )

        # Check wheel orientation in scene
        self._validate_scene_wheels(filename, content)

    def _validate_scene_wheels(self, filename: str, content: str):
        """Validate wheel orientation in .tscn scene files.

        For wheels using CylinderMesh:
        - Need rotation on Z axis (~1.5708 rad / 90 deg) to orient axle along X
        - This makes the wheel perpendicular to default -Z travel direction
        """
        # Find wheel nodes with CylinderMesh
        # Pattern: [node name="WheelXX" ...] followed by mesh = SubResource with CylinderMesh
        wheel_sections = re.findall(
            r'\[node name="([^"]*[Ww]heel[^"]*).*?\].*?(?=\[node|\[sub_resource|\Z)',
            content, re.DOTALL
        )

        for section in wheel_sections:
            # This is just the node name, find the full section
            section_match = re.search(
                rf'\[node name="{re.escape(section)}"[^\]]*\](.*?)(?=\[node|\[sub_resource|\Z)',
                content, re.DOTALL
            )
            if section_match:
                node_content = section_match.group(1)

                # Check if it has a CylinderMesh reference
                if "CylinderMesh" in content:
                    # Check for proper Z rotation (around 1.5708 or PI/2)
                    rotation_match = re.search(r'rotation\s*=\s*Vector3\(([^)]+)\)', node_content)
                    if rotation_match:
                        rotation_values = rotation_match.group(1).split(',')
                        if len(rotation_values) >= 3:
                            try:
                                z_rot = float(rotation_values[2].strip())
                                # Check if Z rotation is approximately 90 degrees (1.5708 rad)
                                if abs(z_rot) < 0.1:  # No Z rotation
                                    self.result.add_warning(
                                        filename, 0,
                                        f"Wheel node '{section}' has no Z rotation - CylinderMesh needs ~90° Z rotation for correct axle orientation"
                                    )
                            except ValueError:
                                pass  # Can't parse, skip


def validate_build(build_dir: Path) -> ValidationResult:
    """Convenience function to validate a build directory."""
    validator = GodotValidator(build_dir)
    return validator.validate_all()


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Validate Godot project for common issues")
    parser.add_argument("build_dir", type=str, help="Path to build directory")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    args = parser.parse_args()

    build_dir = Path(args.build_dir)
    if not build_dir.is_absolute():
        build_dir = Path(__file__).parent.parent / args.build_dir

    result = validate_build(build_dir)

    if args.json:
        import json
        print(json.dumps(result.to_dict(), indent=2))
    else:
        result.print_report()

    exit(0 if result.is_valid else 1)


if __name__ == "__main__":
    main()
