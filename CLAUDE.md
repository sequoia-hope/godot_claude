# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an AI-driven automated game development pipeline that generates and tests Godot 4.5.1 games. Users describe game environments in natural language, Claude generates GDScript code, and automated tests validate the output through headless Docker execution.

## Common Commands

### Running Tests on Generated Code
```bash
# Primary workflow - test a build directory
python scripts/orchestrator.py --test-only --build-dir ./code/my_build

# Create a new empty build directory
python scripts/orchestrator.py --create-build my_game_v1
```

### Feature Workflow (for complex features with custom tests)
```bash
# Initialize a feature
python scripts/feature_workflow.py init my_game "Add a door that opens with a key"

# Generate test template and write to build
python scripts/feature_workflow.py template door_with_key --output my_game

# Run tests
python scripts/feature_workflow.py test my_game

# Get feedback for iteration
python scripts/feature_workflow.py feedback my_game
```

### Docker Commands
```bash
# Build Docker image (first time, takes 5-10 minutes)
docker-compose build

# Interactive shell in container
docker-compose run --rm godot-engine

# Check Godot version
docker-compose run --rm godot-engine godot --version
```

## Architecture

### Pipeline Flow
1. **Code Generation**: Claude generates Godot files (project.godot, main.tscn, player.gd, main.gd)
2. **Validation**: `orchestrator.py` validates code and auto-fixes common issues (missing CollisionShapes, Cameras, Lights)
3. **Test Preparation**: TestRunner autoload is injected into project.godot
4. **Docker Execution**: Godot runs headless with Xvfb, test_runner.gd executes automatically
5. **Results Collection**: Screenshots, performance metrics, and movement data saved to `tests/`
6. **Feedback**: Results analyzed and formatted for next iteration

### Key Components

**orchestrator.py** - Main pipeline controller
- `run_tests_only(build_dir)` - Primary method for testing builds
- `_validate_generated_code()` - Checks for common issues
- `_fix_common_issues()` - Auto-fixes missing CollisionShapes, Cameras, Lights

**test_runner.gd** - Godot autoload for basic movement tests
- Runs predefined movement tests (forward, backward, strafe, jump, turn)
- Captures screenshots at test start/end
- Tracks player position and velocity per frame
- Outputs results to `res://test_output/[timestamp]/results.json`

**dynamic_test_runner.gd** - Advanced test runner for feature-specific tests
- Loads test definitions from `tests.json`
- Supports complex test sequences: move_to target groups, interact, wait
- Used automatically when `tests.json` exists in build directory

**feature_workflow.py** - Manages feature-driven development
- Supports test templates: door, pickup, door_with_key, movement
- Tracks iterations via `feature.json`

### Required Files for a Build

Every build directory must contain:
- `project.godot` - Godot project file
- `main.tscn` - Main scene with Player (CharacterBody3D)
- `player.gd` - Player movement script
- `main.gd` - Main scene script

Optional:
- `tests.json` - Custom test definitions (triggers dynamic_test_runner.gd)
- `feature.json` - Feature metadata for iteration tracking

### Generated Code Requirements

Player must be a CharacterBody3D with:
- CollisionShape3D with a shape assigned (CapsuleShape3D recommended)
- Camera3D as child for player view
- Input handling for: move_forward, move_backward, move_left, move_right, jump

Scene must have:
- At least one light source (DirectionalLight3D, OmniLight3D, or SpotLight3D)
- Floor/ground with collision for player to walk on

### Test Output Structure

Test results are saved to `tests/[build_name]_[timestamp]/`:
- `results.json` - Test metrics, movement data, performance stats
- `*.png` - Screenshots at test start/end points

Key fields in results.json:
- `movement_summary.overall_status`: "healthy", "issues_detected", "no_player", "no_data"
- `performance.avg_fps`: Should be >= 60
- `movement_metrics.[test_name].status`: "success" or "failed"

### tests.json Format

For custom tests, create a tests.json:
```json
{
  "feature": "door_with_key",
  "tests": [
    {
      "name": "find_key",
      "type": "movement",
      "duration": 5.0,
      "steps": [
        {"action": "move_to", "target_group": "pickup", "duration": 5.0}
      ],
      "validate": {"near_group": "pickup", "max_distance": 2.0}
    }
  ]
}
```

Actions: `wait`, `input`, `move_to`, `interact`
Target groups: Objects should be added to groups in Godot (e.g., "door", "pickup")
