# Scripts Directory

Automation and orchestration scripts for the AI-driven game development pipeline.

## Docker Scripts

### Building the Docker Image

```bash
docker-compose build
```

### Running the Container

```bash
# Interactive shell
docker-compose run --rm godot-engine

# Run specific command
docker-compose run --rm godot-engine godot --version
```

## Pipeline Scripts

- `orchestrator.py` - Main orchestration script that manages the full pipeline
- `docker-entrypoint.sh` - Container entrypoint that sets up Xvfb for headless rendering
- `test_game.sh` - Test runner for game builds
- `visual_analyzer.py` - Multimodal AI visual analysis module
- `performance_profiler.py` - Performance monitoring and profiling

## Usage Examples

### Full Pipeline Execution

```bash
python3 scripts/orchestrator.py --prompt "prompts/test_room.txt"
```

### Manual Testing

```bash
# Build Docker image
docker-compose build

# Run test
./scripts/test_game.sh code/test_room/

# Analyze results
python3 scripts/visual_analyzer.py tests/latest/
```
