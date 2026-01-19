#!/usr/bin/env python3
"""
Telemetry Analyzer - Analyze time series position data from Godot games.

Loads telemetry.jsonl files and computes movement metrics, detects anomalies,
and outputs summaries for programmatic analysis.

Usage:
    python telemetry_analyzer.py <telemetry_file> [options]

Examples:
    python telemetry_analyzer.py code/nintendo_walk/telemetry.jsonl
    python telemetry_analyzer.py code/nintendo_walk/telemetry.jsonl --summary
    python telemetry_analyzer.py code/nintendo_walk/telemetry.jsonl --detect-anomalies
    python telemetry_analyzer.py code/nintendo_walk/telemetry.jsonl --json
"""

import json
import argparse
import sys
import math
from pathlib import Path
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Tuple


@dataclass
class Vec3:
    x: float
    y: float
    z: float

    @classmethod
    def from_list(cls, arr: List[float]) -> 'Vec3':
        return cls(arr[0], arr[1], arr[2])

    def length(self) -> float:
        return math.sqrt(self.x**2 + self.y**2 + self.z**2)

    def horizontal_length(self) -> float:
        return math.sqrt(self.x**2 + self.z**2)

    def distance_to(self, other: 'Vec3') -> float:
        return math.sqrt(
            (self.x - other.x)**2 +
            (self.y - other.y)**2 +
            (self.z - other.z)**2
        )

    def horizontal_distance_to(self, other: 'Vec3') -> float:
        return math.sqrt(
            (self.x - other.x)**2 +
            (self.z - other.z)**2
        )


@dataclass
class Sample:
    t: float
    type: str
    pos: Vec3
    vel: Vec3
    rot: Vec3
    floor: Optional[bool] = None
    ang_vel: Optional[Vec3] = None
    steering: Optional[float] = None
    engine_force: Optional[float] = None
    brake: Optional[float] = None
    inputs: List[str] = field(default_factory=list)

    @classmethod
    def from_dict(cls, d: Dict) -> 'Sample':
        return cls(
            t=d['t'],
            type=d['type'],
            pos=Vec3.from_list(d['pos']),
            vel=Vec3.from_list(d['vel']),
            rot=Vec3.from_list(d['rot']),
            floor=d.get('floor'),
            ang_vel=Vec3.from_list(d['ang_vel']) if 'ang_vel' in d else None,
            steering=d.get('steering'),
            engine_force=d.get('engine_force'),
            brake=d.get('brake'),
            inputs=d.get('inputs', [])
        )


@dataclass
class Anomaly:
    type: str
    time: float
    description: str
    severity: str  # 'low', 'medium', 'high'


@dataclass
class TelemetryAnalysis:
    file_path: str
    sample_count: int
    duration: float
    character_type: str

    # Position metrics
    total_distance: float
    horizontal_distance: float
    displacement: float
    horizontal_displacement: float
    start_pos: Tuple[float, float, float]
    end_pos: Tuple[float, float, float]

    # Velocity metrics
    max_speed: float
    avg_speed: float
    max_horizontal_speed: float
    avg_horizontal_speed: float

    # Floor contact (CharacterBody3D only)
    floor_contact_ratio: Optional[float]
    time_airborne: Optional[float]

    # Direction changes
    direction_changes: int

    # Anomalies
    anomalies: List[Anomaly]

    # Input analysis
    input_activity: Dict[str, float]  # input_name -> time_held


def load_telemetry(file_path: str) -> List[Sample]:
    """Load samples from a JSONL telemetry file."""
    samples = []
    path = Path(file_path)

    if not path.exists():
        raise FileNotFoundError(f"Telemetry file not found: {file_path}")

    with open(path, 'r') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
                samples.append(Sample.from_dict(data))
            except json.JSONDecodeError as e:
                print(f"Warning: Invalid JSON at line {line_num}: {e}", file=sys.stderr)
            except KeyError as e:
                print(f"Warning: Missing key at line {line_num}: {e}", file=sys.stderr)

    return samples


def analyze_telemetry(samples: List[Sample], file_path: str) -> TelemetryAnalysis:
    """Analyze telemetry samples and compute metrics."""
    if not samples:
        raise ValueError("No samples to analyze")

    first = samples[0]
    last = samples[-1]

    # Basic info
    duration = last.t - first.t
    character_type = first.type

    # Distance calculations
    total_distance = 0.0
    horizontal_distance = 0.0

    for i in range(1, len(samples)):
        prev_pos = samples[i-1].pos
        curr_pos = samples[i].pos
        total_distance += prev_pos.distance_to(curr_pos)
        horizontal_distance += prev_pos.horizontal_distance_to(curr_pos)

    displacement = first.pos.distance_to(last.pos)
    horizontal_displacement = first.pos.horizontal_distance_to(last.pos)

    # Velocity stats
    speeds = [s.vel.length() for s in samples]
    horizontal_speeds = [s.vel.horizontal_length() for s in samples]

    max_speed = max(speeds) if speeds else 0.0
    avg_speed = sum(speeds) / len(speeds) if speeds else 0.0
    max_horizontal_speed = max(horizontal_speeds) if horizontal_speeds else 0.0
    avg_horizontal_speed = sum(horizontal_speeds) / len(horizontal_speeds) if horizontal_speeds else 0.0

    # Floor contact analysis (CharacterBody3D only)
    floor_contact_ratio = None
    time_airborne = None
    if first.floor is not None:
        floor_samples = sum(1 for s in samples if s.floor)
        floor_contact_ratio = floor_samples / len(samples)
        time_airborne = duration * (1 - floor_contact_ratio)

    # Direction changes (significant horizontal velocity direction changes)
    direction_changes = count_direction_changes(samples)

    # Anomaly detection
    anomalies = detect_anomalies(samples)

    # Input activity
    input_activity = analyze_inputs(samples)

    return TelemetryAnalysis(
        file_path=file_path,
        sample_count=len(samples),
        duration=duration,
        character_type=character_type,
        total_distance=total_distance,
        horizontal_distance=horizontal_distance,
        displacement=displacement,
        horizontal_displacement=horizontal_displacement,
        start_pos=(first.pos.x, first.pos.y, first.pos.z),
        end_pos=(last.pos.x, last.pos.y, last.pos.z),
        max_speed=max_speed,
        avg_speed=avg_speed,
        max_horizontal_speed=max_horizontal_speed,
        avg_horizontal_speed=avg_horizontal_speed,
        floor_contact_ratio=floor_contact_ratio,
        time_airborne=time_airborne,
        direction_changes=direction_changes,
        anomalies=anomalies,
        input_activity=input_activity
    )


def count_direction_changes(samples: List[Sample], threshold: float = 0.5) -> int:
    """Count significant horizontal direction changes."""
    changes = 0
    prev_dir = None

    for sample in samples:
        h_speed = sample.vel.horizontal_length()
        if h_speed < threshold:
            continue

        # Compute horizontal direction angle
        angle = math.atan2(sample.vel.z, sample.vel.x)

        if prev_dir is not None:
            # Check for significant direction change (> 45 degrees)
            diff = abs(angle - prev_dir)
            if diff > math.pi:
                diff = 2 * math.pi - diff
            if diff > math.pi / 4:
                changes += 1

        prev_dir = angle

    return changes


def detect_anomalies(samples: List[Sample]) -> List[Anomaly]:
    """Detect movement anomalies."""
    anomalies = []

    if len(samples) < 2:
        return anomalies

    # Check for stuck detection (no movement despite input)
    stuck_threshold = 0.01
    stuck_duration = 0.5
    stuck_start = None
    has_movement_input = False

    for i, sample in enumerate(samples):
        # Check if movement input is active
        movement_inputs = ['move_forward', 'move_backward', 'move_left', 'move_right']
        has_input = any(inp in sample.inputs for inp in movement_inputs)

        speed = sample.vel.horizontal_length()

        if has_input and speed < stuck_threshold:
            if stuck_start is None:
                stuck_start = sample.t
                has_movement_input = True
        else:
            if stuck_start is not None and has_movement_input:
                stuck_time = sample.t - stuck_start
                if stuck_time >= stuck_duration:
                    anomalies.append(Anomaly(
                        type='stuck',
                        time=stuck_start,
                        description=f"Player stuck for {stuck_time:.2f}s while pressing movement keys",
                        severity='high'
                    ))
            stuck_start = None
            has_movement_input = False

    # Check for falling (continuous downward velocity)
    fall_threshold = -10.0
    fall_duration = 2.0
    fall_start = None

    for sample in samples:
        if sample.vel.y < fall_threshold:
            if fall_start is None:
                fall_start = sample.t
        else:
            if fall_start is not None:
                fall_time = sample.t - fall_start
                if fall_time >= fall_duration:
                    anomalies.append(Anomaly(
                        type='falling',
                        time=fall_start,
                        description=f"Player falling rapidly for {fall_time:.2f}s",
                        severity='medium'
                    ))
            fall_start = None

    # Check for teleporting (sudden position change)
    teleport_threshold = 10.0  # units per frame at 60fps

    for i in range(1, len(samples)):
        prev = samples[i-1]
        curr = samples[i]
        dt = curr.t - prev.t

        if dt > 0:
            distance = prev.pos.distance_to(curr.pos)
            speed = distance / dt

            # Very high instantaneous speed suggests teleport
            if distance > teleport_threshold:
                anomalies.append(Anomaly(
                    type='teleport',
                    time=curr.t,
                    description=f"Sudden position change of {distance:.2f} units",
                    severity='high'
                ))

    # Check for phasing through floor (CharacterBody3D)
    if samples[0].floor is not None:
        prev_on_floor = samples[0].floor
        prev_y = samples[0].pos.y

        for sample in samples:
            # Detect falling through floor
            if prev_on_floor and not sample.floor and sample.pos.y < prev_y - 1.0:
                anomalies.append(Anomaly(
                    type='floor_phase',
                    time=sample.t,
                    description=f"Player may have phased through floor at y={sample.pos.y:.2f}",
                    severity='high'
                ))

            prev_on_floor = sample.floor
            prev_y = sample.pos.y

    return anomalies


def analyze_inputs(samples: List[Sample]) -> Dict[str, float]:
    """Analyze input activity over time."""
    if not samples or len(samples) < 2:
        return {}

    input_times = {}
    duration = samples[-1].t - samples[0].t

    if duration <= 0:
        return {}

    for i in range(1, len(samples)):
        dt = samples[i].t - samples[i-1].t
        for inp in samples[i].inputs:
            input_times[inp] = input_times.get(inp, 0.0) + dt

    return input_times


def format_summary(analysis: TelemetryAnalysis) -> str:
    """Format analysis as human-readable summary."""
    lines = [
        "=" * 60,
        "TELEMETRY ANALYSIS SUMMARY",
        "=" * 60,
        f"File: {analysis.file_path}",
        f"Character Type: {analysis.character_type}",
        f"Samples: {analysis.sample_count}",
        f"Duration: {analysis.duration:.2f}s",
        "",
        "POSITION",
        f"  Start: ({analysis.start_pos[0]:.2f}, {analysis.start_pos[1]:.2f}, {analysis.start_pos[2]:.2f})",
        f"  End:   ({analysis.end_pos[0]:.2f}, {analysis.end_pos[1]:.2f}, {analysis.end_pos[2]:.2f})",
        f"  Total Distance: {analysis.total_distance:.2f} units",
        f"  Horizontal Distance: {analysis.horizontal_distance:.2f} units",
        f"  Displacement: {analysis.displacement:.2f} units",
        "",
        "VELOCITY",
        f"  Max Speed: {analysis.max_speed:.2f} u/s",
        f"  Avg Speed: {analysis.avg_speed:.2f} u/s",
        f"  Max Horizontal: {analysis.max_horizontal_speed:.2f} u/s",
        f"  Direction Changes: {analysis.direction_changes}",
    ]

    if analysis.floor_contact_ratio is not None:
        lines.extend([
            "",
            "FLOOR CONTACT",
            f"  On Floor: {analysis.floor_contact_ratio*100:.1f}%",
            f"  Time Airborne: {analysis.time_airborne:.2f}s",
        ])

    if analysis.input_activity:
        lines.extend([
            "",
            "INPUT ACTIVITY",
        ])
        for inp, time_held in sorted(analysis.input_activity.items(), key=lambda x: -x[1]):
            pct = (time_held / analysis.duration) * 100 if analysis.duration > 0 else 0
            lines.append(f"  {inp}: {time_held:.2f}s ({pct:.1f}%)")

    if analysis.anomalies:
        lines.extend([
            "",
            "ANOMALIES DETECTED",
        ])
        for anomaly in analysis.anomalies:
            lines.append(f"  [{anomaly.severity.upper()}] {anomaly.type} at t={anomaly.time:.2f}s")
            lines.append(f"    {anomaly.description}")
    else:
        lines.extend([
            "",
            "No anomalies detected",
        ])

    lines.append("=" * 60)
    return "\n".join(lines)


def format_json(analysis: TelemetryAnalysis) -> str:
    """Format analysis as JSON."""
    data = {
        "file_path": analysis.file_path,
        "character_type": analysis.character_type,
        "sample_count": analysis.sample_count,
        "duration": analysis.duration,
        "position": {
            "start": analysis.start_pos,
            "end": analysis.end_pos,
            "total_distance": analysis.total_distance,
            "horizontal_distance": analysis.horizontal_distance,
            "displacement": analysis.displacement,
            "horizontal_displacement": analysis.horizontal_displacement,
        },
        "velocity": {
            "max_speed": analysis.max_speed,
            "avg_speed": analysis.avg_speed,
            "max_horizontal_speed": analysis.max_horizontal_speed,
            "avg_horizontal_speed": analysis.avg_horizontal_speed,
        },
        "direction_changes": analysis.direction_changes,
        "input_activity": analysis.input_activity,
        "anomalies": [
            {
                "type": a.type,
                "time": a.time,
                "description": a.description,
                "severity": a.severity
            }
            for a in analysis.anomalies
        ]
    }

    if analysis.floor_contact_ratio is not None:
        data["floor_contact"] = {
            "ratio": analysis.floor_contact_ratio,
            "time_airborne": analysis.time_airborne,
        }

    return json.dumps(data, indent=2)


def main():
    parser = argparse.ArgumentParser(
        description="Analyze telemetry data from Godot games"
    )
    parser.add_argument(
        "telemetry_file",
        help="Path to telemetry.jsonl file"
    )
    parser.add_argument(
        "--summary", "-s",
        action="store_true",
        help="Print human-readable summary (default)"
    )
    parser.add_argument(
        "--json", "-j",
        action="store_true",
        help="Output as JSON"
    )
    parser.add_argument(
        "--detect-anomalies", "-a",
        action="store_true",
        help="Only show anomalies"
    )
    parser.add_argument(
        "--raw-samples", "-r",
        action="store_true",
        help="Print raw samples"
    )
    parser.add_argument(
        "--limit", "-l",
        type=int,
        default=0,
        help="Limit number of samples to analyze (0 = all)"
    )

    args = parser.parse_args()

    try:
        samples = load_telemetry(args.telemetry_file)

        if args.limit > 0:
            samples = samples[:args.limit]

        if args.raw_samples:
            for sample in samples:
                print(json.dumps({
                    "t": sample.t,
                    "pos": [sample.pos.x, sample.pos.y, sample.pos.z],
                    "vel": [sample.vel.x, sample.vel.y, sample.vel.z],
                    "inputs": sample.inputs
                }))
            return

        analysis = analyze_telemetry(samples, args.telemetry_file)

        if args.detect_anomalies:
            if analysis.anomalies:
                for anomaly in analysis.anomalies:
                    print(f"[{anomaly.severity.upper()}] {anomaly.type} at t={anomaly.time:.2f}s: {anomaly.description}")
            else:
                print("No anomalies detected")
        elif args.json:
            print(format_json(analysis))
        else:
            print(format_summary(analysis))

    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
