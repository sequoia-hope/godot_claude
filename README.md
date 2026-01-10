# AI-Driven Game Development Pipeline

An automated workflow for creating, testing, and iterating on game environments using AI code generation, headless rendering, and visual analysis.

## Architecture

This system implements a complete development pipeline:

1. **Natural Language Input** → Describe game environments narratively
2. **Code Generation** → Claude Code generates Godot game code
3. **Automated Testing** → Headless engine runs, captures screenshots, simulates player input
4. **Visual Analysis** → Multimodal AI validates rendering, movement, and performance
5. **Iteration Loop** → Automatic refinement based on feedback until quality thresholds are met

## Repository Structure

```
/prompts/     - Design descriptions and generation prompts (tagged by iteration)
/code/        - Generated Godot game code
/tests/       - Test screenshots and performance logs
/assets/      - Generated 3D models (Phase 2)
/docs/        - Architecture decisions and design notes
/scripts/     - Orchestration and automation scripts
```

## Current Status

**Phase**: 1 - Core Pipeline MVP
**Goal**: Prove end-to-end workflow with simple test room

## Configuration

- **Game Engine**: Godot (headless mode)
- **Target Platform**: Linux (local laptop initially, GPU desktop for Phase 2)
- **Performance Target**: 60 FPS minimum
- **Automation Level**: Full pipeline automation

## Quick Start

```bash
# Run the orchestration pipeline
python scripts/orchestrator.py

# Manual testing
./scripts/test_game.sh code/current/
```

See `docs/DECISIONS.md` for architectural rationale and `game_dev_pipeline_plan.md` for the complete vision.
