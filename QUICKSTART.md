# Quick Start Guide

Get the AI-driven game development pipeline running in under 10 minutes.

## Step 1: Prerequisites Check

```bash
# Check if you have the basics
python3 --version  # Should be 3.8+
docker --version   # Should be installed
```

## Step 2: Install Dependencies

```bash
# Install Python packages
pip3 install anthropic

# Or use requirements file
pip3 install -r requirements.txt
```

## Step 3: Set API Key

```bash
# Set your Anthropic API key
export ANTHROPIC_API_KEY='your-api-key-here'

# Verify it's set
echo $ANTHROPIC_API_KEY
```

## Step 4: Build Docker Image

```bash
# Build the Godot container (takes 5-10 minutes first time)
docker-compose build
```

## Step 5: Run Your First Test

```bash
# Run the test room generation pipeline
cd scripts
python3 orchestrator.py --prompt ../prompts/test_room.txt
```

## What Happens Next?

The orchestrator will:

1. **Generate Code** - Claude creates Godot game code from your prompt
2. **Build Game** - Code is packaged into a Godot project
3. **Run Tests** - Automated player movement tests in Docker
4. **Capture Screenshots** - Visual snapshots at key test points
5. **Analyze Results** - Claude Vision reviews screenshots for issues
6. **Profile Performance** - FPS and memory metrics analyzed
7. **Iterate or Accept** - Automatically refines if needed, or accepts if quality targets met

## Expected Output

```
================================================================================
AI-Driven Game Development Pipeline
================================================================================

Scene Description:
[Your test room prompt...]

================================================================================
ITERATION 1
================================================================================

Generating game code...
Code saved to: code/build_20260110_143022_iter0

Running tests for build: build_20260110_143022_iter0
Analyzing visual results...
Evaluating performance...

Decision: accept

================================================================================
Pipeline completed after 1 iteration(s)
Final decision: accept
================================================================================
```

## View Results

```bash
# Check generated code
ls code/build_*/

# View test screenshots
ls tests/build_*/

# Read detailed analysis
cat tests/build_*/visual_analysis.json
cat tests/build_*/performance_analysis.json

# Review iteration log
cat docs/iteration_log.jsonl
```

## Common Issues

### "ANTHROPIC_API_KEY not set"
```bash
export ANTHROPIC_API_KEY='your-key'
```

### "Docker permission denied"
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

### "anthropic module not found"
```bash
pip3 install anthropic
```

## Next Steps

Once your first test succeeds:

1. **Try Custom Scenes** - Edit `prompts/test_room.txt` or create new prompts
2. **Adjust Performance Targets** - Edit `target_fps` in `scripts/orchestrator.py`
3. **Review Architecture** - Read `docs/DECISIONS.md` and `game_dev_pipeline_plan.md`
4. **Plan Phase 2** - Add 3D asset generation and distributed rendering

## Manual Mode (For Debugging)

If you want to test components individually:

```bash
# Test Docker container
docker-compose run --rm godot-engine /bin/bash

# Inside container, check Godot
godot --version

# Run visual analyzer on existing test
python3 visual_analyzer.py ../tests/some_test_dir/

# Run performance profiler
python3 performance_profiler.py ../tests/some_test_dir/results.json
```

## Full Documentation

- **Setup**: `docs/SETUP.md` - Complete installation guide
- **Architecture**: `docs/DECISIONS.md` - Technical decisions
- **Vision**: `game_dev_pipeline_plan.md` - Full pipeline plan
- **Code**: `scripts/` - All automation scripts

Happy game building! 🎮
