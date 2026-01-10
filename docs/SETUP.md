# Setup Guide

Complete setup instructions for the AI-driven game development pipeline.

## Prerequisites

### Required
- **Linux**: Ubuntu 20.04+ or similar (tested on your system)
- **Python 3.8+**: For orchestration scripts
- **Docker**: For containerized game engine
- **Anthropic API Key**: For Claude Code generation and visual analysis

### Optional
- **Docker Compose**: Simplifies container management
- **NVIDIA GPU**: For GPU-accelerated rendering (Phase 2)
- **Git**: For version control (already initialized)

## Installation Steps

### 1. Install System Dependencies

```bash
# Update package list
sudo apt update

# Install Docker (if not already installed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER  # Add your user to docker group

# Log out and back in for group changes to take effect
```

### 2. Set Up API Key

Get your Anthropic API key from https://console.anthropic.com/

```bash
# Add to your shell profile (~/.bashrc or ~/.zshrc)
export ANTHROPIC_API_KEY='your-api-key-here'

# Or create a .env file (not tracked by git)
echo "ANTHROPIC_API_KEY=your-api-key-here" > .env
```

### 3. Install Python Dependencies

```bash
cd /home/sequoia/Software/engine
pip3 install -r requirements.txt
```

### 4. Run Setup Script

```bash
cd scripts
chmod +x setup.sh
./setup.sh
```

This will:
- Check all prerequisites
- Install Python packages
- Make scripts executable
- Verify API key configuration

### 5. Build Docker Image

```bash
cd /home/sequoia/Software/engine
docker-compose build
```

This creates the Godot headless container (may take 5-10 minutes on first build).

## Quick Start

### Run the MVP Test

```bash
cd scripts
python3 orchestrator.py --prompt ../prompts/test_room.txt
```

This will:
1. Generate Godot code for a test room
2. Build and run the game in Docker
3. Capture screenshots and performance metrics
4. Analyze results with Claude Vision
5. Iterate until quality targets are met

### Manual Testing

If you want to test individual components:

```bash
# Test Docker container
docker-compose run --rm godot-engine godot --version

# Test visual analyzer
python3 scripts/visual_analyzer.py tests/some_test_run/

# Test performance profiler
python3 scripts/performance_profiler.py tests/some_test_run/results.json
```

## Configuration

### Performance Targets

Edit `scripts/orchestrator.py` to adjust:

```python
self.config = {
    "target_fps": 60,        # Target frame rate
    "max_iterations": 5,     # Max iteration attempts
    "model": "claude-sonnet-4-5-20250929"
}
```

### Test Sequence

Edit `scripts/test_runner.gd` to customize test cases:

```gdscript
test_sequence = [
    {
        "name": "custom_test",
        "description": "Your test description",
        "duration": 3.0,
        "inputs": ["move_forward", "jump"]
    }
]
```

## Troubleshooting

### Docker Issues

**Problem**: Permission denied on Docker socket
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

**Problem**: Docker build fails
```bash
# Clear Docker cache and rebuild
docker system prune -a
docker-compose build --no-cache
```

### API Issues

**Problem**: ANTHROPIC_API_KEY not found
```bash
# Verify it's set
echo $ANTHROPIC_API_KEY

# Set it temporarily
export ANTHROPIC_API_KEY='your-key'
```

**Problem**: API rate limits
- Reduce `max_iterations` in config
- Wait a few minutes between runs
- Check your API usage at console.anthropic.com

### Godot Issues

**Problem**: Headless rendering not working
- Check Xvfb is running in container
- Verify DISPLAY=:99 environment variable
- Look for errors in Docker logs: `docker-compose logs`

**Problem**: No screenshots generated
- Check user:// directory permissions in container
- Verify test_runner.gd is loaded as autoload
- Check Godot console output for errors

## Next Steps

Once setup is complete:

1. **Run MVP Test**: Execute the test room generation
2. **Review Results**: Check `tests/` directory for screenshots and analysis
3. **Iterate**: Refine prompts based on results
4. **Expand**: Add more complex scenes and features

See `game_dev_pipeline_plan.md` for the complete roadmap.

## Directory Structure

```
/home/sequoia/Software/engine/
├── prompts/          # Scene descriptions
├── code/             # Generated Godot projects
├── tests/            # Test results and screenshots
├── assets/           # 3D assets (Phase 2)
├── docs/             # Documentation
│   ├── SETUP.md      # This file
│   └── DECISIONS.md  # Architecture decisions
├── scripts/          # Automation scripts
│   ├── orchestrator.py       # Main pipeline
│   ├── visual_analyzer.py    # Screenshot analysis
│   ├── performance_profiler.py
│   ├── test_runner.gd        # Godot test script
│   └── setup.sh
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
└── README.md
```

## Support

For issues or questions:
- Check `docs/DECISIONS.md` for architecture rationale
- Review `game_dev_pipeline_plan.md` for feature roadmap
- Check Docker logs: `docker-compose logs`
- Review iteration logs: `docs/iteration_log.jsonl`
