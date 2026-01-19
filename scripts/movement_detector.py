#!/usr/bin/env python3
"""
Movement Type Detector

Analyzes player code and behavior to detect movement type:
- Walking (CharacterBody3D + gravity + is_on_floor)
- Driving (VehicleBody3D + steering + engine_force)
- Flying (ascend/descend + pitch/roll/yaw, no gravity)
- Swimming (buoyancy + drag + water)

This allows the test system to select appropriate test sequences
and validation criteria for different movement types.
"""

import re
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
from enum import Enum


class MovementType(Enum):
    UNKNOWN = "unknown"
    WALKING = "walking"
    DRIVING = "driving"
    FLYING = "flying"
    SWIMMING = "swimming"
    PLATFORMER = "platformer"
    TOP_DOWN = "top_down"
    FIRST_PERSON = "first_person"
    THIRD_PERSON = "third_person"


@dataclass
class MovementPattern:
    """Pattern to match in code for movement type detection"""
    name: str
    patterns: List[str]  # Regex patterns to search for
    weight: float  # How strongly this indicates the movement type
    required: bool = False  # Must be present for this type


# Movement type detection patterns
WALKING_PATTERNS = [
    MovementPattern("character_body", [r"CharacterBody3D", r"extends CharacterBody3D"], 0.3, required=True),
    MovementPattern("gravity", [r"gravity", r"GRAVITY", r"get_gravity"], 0.2),
    MovementPattern("floor_check", [r"is_on_floor\s*\(\)", r"is_on_floor"], 0.3),
    MovementPattern("jump", [r"jump", r"JUMP", r"velocity\.y\s*="], 0.2),
    MovementPattern("walk_run", [r"WALK_SPEED", r"RUN_SPEED", r"move_speed", r"SPEED"], 0.1),
]

DRIVING_PATTERNS = [
    MovementPattern("vehicle_body", [r"VehicleBody3D", r"extends VehicleBody3D"], 0.4, required=True),
    MovementPattern("steering", [r"steering", r"steer", r"turn_input"], 0.3),
    MovementPattern("engine", [r"engine_force", r"throttle", r"acceleration"], 0.2),
    MovementPattern("wheel", [r"VehicleWheel", r"wheel", r"tire"], 0.1),
    MovementPattern("brake", [r"brake", r"handbrake"], 0.1),
]

FLYING_PATTERNS = [
    MovementPattern("no_gravity", [r"gravity\s*=\s*0", r"gravity\s*=\s*false", r"# no gravity"], 0.2),
    MovementPattern("ascend_descend", [r"ascend", r"descend", r"altitude", r"height_control"], 0.3),
    MovementPattern("pitch_roll", [r"pitch", r"roll", r"yaw", r"bank"], 0.3),
    MovementPattern("thrust", [r"thrust", r"lift", r"flight"], 0.2),
    MovementPattern("airplane", [r"airplane", r"aircraft", r"plane", r"helicopter"], 0.2),
]

SWIMMING_PATTERNS = [
    MovementPattern("buoyancy", [r"buoyancy", r"float", r"sink"], 0.3),
    MovementPattern("drag", [r"water_drag", r"drag", r"resistance"], 0.2),
    MovementPattern("water", [r"water", r"underwater", r"swim", r"dive"], 0.3),
    MovementPattern("oxygen", [r"oxygen", r"breath", r"air_supply"], 0.1),
    MovementPattern("stroke", [r"stroke", r"paddle", r"kick"], 0.1),
]

PLATFORMER_PATTERNS = [
    MovementPattern("double_jump", [r"double_jump", r"can_double_jump", r"air_jump"], 0.3),
    MovementPattern("wall_jump", [r"wall_jump", r"wall_slide", r"is_on_wall"], 0.3),
    MovementPattern("coyote_time", [r"coyote", r"jump_buffer", r"late_jump"], 0.2),
    MovementPattern("dash", [r"dash", r"air_dash"], 0.2),
]

TOP_DOWN_PATTERNS = [
    MovementPattern("no_y_movement", [r"velocity\.y\s*=\s*0", r"# 2D movement"], 0.2),
    MovementPattern("look_at_mouse", [r"look_at.*mouse", r"rotate.*cursor", r"aim_at_mouse"], 0.3),
    MovementPattern("twin_stick", [r"twin.?stick", r"aim_direction"], 0.3),
    MovementPattern("isometric", [r"isometric", r"iso_"], 0.2),
]

FIRST_PERSON_PATTERNS = [
    MovementPattern("mouse_look", [r"mouse_motion", r"camera.*rotate", r"look_sensitivity"], 0.3),
    MovementPattern("head_bob", [r"head_bob", r"headbob", r"camera_bob"], 0.2),
    MovementPattern("first_person", [r"first.?person", r"fps_camera", r"FPS"], 0.3),
    MovementPattern("crouch", [r"crouch", r"CROUCH", r"is_crouching"], 0.1),
]

THIRD_PERSON_PATTERNS = [
    MovementPattern("camera_arm", [r"SpringArm", r"camera_arm", r"camera_pivot"], 0.3),
    MovementPattern("orbit_camera", [r"orbit", r"follow_camera", r"chase_camera"], 0.3),
    MovementPattern("third_person", [r"third.?person", r"tps_camera", r"TPS"], 0.3),
    MovementPattern("aim_offset", [r"aim_offset", r"camera_offset"], 0.1),
]


class MovementDetector:
    """Detects movement type from code patterns and runtime behavior"""

    def __init__(self):
        self.type_patterns = {
            MovementType.WALKING: WALKING_PATTERNS,
            MovementType.DRIVING: DRIVING_PATTERNS,
            MovementType.FLYING: FLYING_PATTERNS,
            MovementType.SWIMMING: SWIMMING_PATTERNS,
            MovementType.PLATFORMER: PLATFORMER_PATTERNS,
            MovementType.TOP_DOWN: TOP_DOWN_PATTERNS,
            MovementType.FIRST_PERSON: FIRST_PERSON_PATTERNS,
            MovementType.THIRD_PERSON: THIRD_PERSON_PATTERNS,
        }

    def analyze_code(self, code_content: str) -> Dict[MovementType, float]:
        """
        Analyze code content and return confidence scores for each movement type

        Args:
            code_content: String content of player.gd or similar file

        Returns:
            Dict mapping MovementType to confidence score (0.0-1.0)
        """
        scores = {}

        for movement_type, patterns in self.type_patterns.items():
            score = 0.0
            required_found = True

            for pattern in patterns:
                found = False
                for regex in pattern.patterns:
                    if re.search(regex, code_content, re.IGNORECASE):
                        found = True
                        break

                if found:
                    score += pattern.weight
                elif pattern.required:
                    required_found = False

            # If required patterns not found, zero out the score
            if not required_found:
                score = 0.0

            scores[movement_type] = min(score, 1.0)  # Cap at 1.0

        return scores

    def detect_from_file(self, file_path: Path) -> Tuple[MovementType, float, Dict]:
        """
        Detect movement type from a code file

        Args:
            file_path: Path to player.gd or similar file

        Returns:
            Tuple of (detected_type, confidence, all_scores)
        """
        if not file_path.exists():
            return MovementType.UNKNOWN, 0.0, {}

        content = file_path.read_text()
        scores = self.analyze_code(content)

        # Find highest scoring type
        best_type = MovementType.UNKNOWN
        best_score = 0.0

        for movement_type, score in scores.items():
            if score > best_score:
                best_score = score
                best_type = movement_type

        return best_type, best_score, scores

    def detect_from_directory(self, build_dir: Path) -> Dict:
        """
        Detect movement type from a build directory

        Args:
            build_dir: Path to build directory containing player.gd, etc.

        Returns:
            Dict with detection results and recommendations
        """
        results = {
            "detected_type": MovementType.UNKNOWN.value,
            "confidence": 0.0,
            "all_scores": {},
            "recommended_tests": [],
            "validation_criteria": {}
        }

        # Check player.gd first
        player_file = build_dir / "player.gd"
        if player_file.exists():
            detected, confidence, scores = self.detect_from_file(player_file)
            results["detected_type"] = detected.value
            results["confidence"] = confidence
            results["all_scores"] = {k.value: v for k, v in scores.items()}

        # Also check main.gd for additional context
        main_file = build_dir / "main.gd"
        if main_file.exists():
            _, _, main_scores = self.detect_from_file(main_file)
            # Merge scores (average)
            for k, v in main_scores.items():
                if k.value in results["all_scores"]:
                    results["all_scores"][k.value] = (results["all_scores"][k.value] + v) / 2
                else:
                    results["all_scores"][k.value] = v

        # Set recommended tests based on detected type
        detected_type = MovementType(results["detected_type"])
        results["recommended_tests"] = self.get_recommended_tests(detected_type)
        results["validation_criteria"] = self.get_validation_criteria(detected_type)

        return results

    def get_recommended_tests(self, movement_type: MovementType) -> List[Dict]:
        """Get recommended test sequence for a movement type"""

        base_tests = [
            {"name": "initial_position", "description": "Capture starting position", "duration": 2.0}
        ]

        if movement_type == MovementType.WALKING:
            return base_tests + [
                {"name": "move_forward", "description": "Walk forward", "duration": 3.0, "inputs": ["move_forward"]},
                {"name": "move_backward", "description": "Walk backward", "duration": 3.0, "inputs": ["move_backward"]},
                {"name": "move_left", "description": "Strafe left", "duration": 2.0, "inputs": ["move_left"]},
                {"name": "move_right", "description": "Strafe right", "duration": 2.0, "inputs": ["move_right"]},
                {"name": "jump", "description": "Test jump", "duration": 2.0, "inputs": ["jump"]},
            ]

        elif movement_type == MovementType.DRIVING:
            return base_tests + [
                {"name": "accelerate", "description": "Press gas", "duration": 3.0, "inputs": ["accelerate"]},
                {"name": "brake", "description": "Press brake", "duration": 2.0, "inputs": ["brake"]},
                {"name": "steer_left", "description": "Turn left", "duration": 2.0, "inputs": ["steer_left"]},
                {"name": "steer_right", "description": "Turn right", "duration": 2.0, "inputs": ["steer_right"]},
                {"name": "reverse", "description": "Reverse", "duration": 2.0, "inputs": ["reverse"]},
            ]

        elif movement_type == MovementType.FLYING:
            return base_tests + [
                {"name": "fly_forward", "description": "Fly forward", "duration": 3.0, "inputs": ["move_forward"]},
                {"name": "ascend", "description": "Fly up", "duration": 2.0, "inputs": ["ascend", "jump"]},
                {"name": "descend", "description": "Fly down", "duration": 2.0, "inputs": ["descend", "crouch"]},
                {"name": "pitch_up", "description": "Pitch up", "duration": 2.0, "inputs": ["pitch_up"]},
                {"name": "roll_left", "description": "Roll left", "duration": 2.0, "inputs": ["roll_left"]},
            ]

        elif movement_type == MovementType.SWIMMING:
            return base_tests + [
                {"name": "swim_forward", "description": "Swim forward", "duration": 3.0, "inputs": ["move_forward"]},
                {"name": "swim_up", "description": "Swim up", "duration": 2.0, "inputs": ["jump", "ascend"]},
                {"name": "swim_down", "description": "Swim down", "duration": 2.0, "inputs": ["crouch", "descend"]},
                {"name": "surface", "description": "Surface", "duration": 3.0, "inputs": []},
            ]

        elif movement_type == MovementType.PLATFORMER:
            return base_tests + [
                {"name": "move_forward", "description": "Run forward", "duration": 2.0, "inputs": ["move_forward"]},
                {"name": "jump", "description": "Single jump", "duration": 2.0, "inputs": ["jump"]},
                {"name": "double_jump", "description": "Double jump", "duration": 2.0, "inputs": ["jump", "jump"]},
                {"name": "wall_jump", "description": "Wall jump", "duration": 3.0, "inputs": ["move_forward", "jump"]},
            ]

        # Default tests for unknown types
        return base_tests + [
            {"name": "move_forward", "description": "Move forward", "duration": 3.0, "inputs": ["move_forward"]},
            {"name": "move_backward", "description": "Move backward", "duration": 3.0, "inputs": ["move_backward"]},
        ]

    def get_validation_criteria(self, movement_type: MovementType) -> Dict:
        """Get validation criteria for a movement type"""

        if movement_type == MovementType.WALKING:
            return {
                "min_walk_distance": 0.5,
                "min_jump_height": 0.3,
                "require_floor_contact": True,
                "require_gravity": True,
                "max_air_time": 2.0,
            }

        elif movement_type == MovementType.DRIVING:
            return {
                "min_acceleration_distance": 2.0,
                "require_wheel_contact": True,
                "min_turning_angle": 15.0,
                "require_braking": True,
            }

        elif movement_type == MovementType.FLYING:
            return {
                "require_floor_contact": False,
                "require_3d_movement": True,
                "min_altitude_change": 1.0,
                "allow_sustained_air": True,
            }

        elif movement_type == MovementType.SWIMMING:
            return {
                "require_floor_contact": False,
                "require_3d_movement": True,
                "expect_drag": True,
                "min_depth_change": 0.5,
            }

        return {
            "min_distance": 0.1,
            "require_movement": True,
        }


def analyze_build(build_dir: str) -> Dict:
    """
    Analyze a build directory and return movement type detection results

    Args:
        build_dir: Path to build directory

    Returns:
        Dict with detection results
    """
    detector = MovementDetector()
    return detector.detect_from_directory(Path(build_dir))


def main():
    import argparse
    import json

    parser = argparse.ArgumentParser(description="Movement Type Detector")
    parser.add_argument("build_dir", type=str, help="Path to build directory containing player.gd")
    parser.add_argument("--output", type=str, default=None,
                       help="Output file for results (default: stdout)")

    args = parser.parse_args()

    results = analyze_build(args.build_dir)

    output = json.dumps(results, indent=2)

    if args.output:
        Path(args.output).write_text(output)
        print(f"Results saved to: {args.output}")
    else:
        print(output)


if __name__ == "__main__":
    main()
