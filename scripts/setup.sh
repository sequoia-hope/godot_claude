#!/bin/bash
# Setup script for AI-driven game development pipeline

set -e

echo "============================================"
echo "AI-Driven Game Development Pipeline Setup"
echo "============================================"
echo ""

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required but not found"
    exit 1
fi

echo "✓ Python 3 found: $(python3 --version)"

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is required but not found"
    echo "Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

echo "✓ Docker found: $(docker --version)"

# Check for docker-compose
if ! command -v docker-compose &> /dev/null; then
    echo "Warning: docker-compose not found (optional but recommended)"
else
    echo "✓ docker-compose found: $(docker-compose --version)"
fi

# Install Python dependencies
echo ""
echo "Installing Python dependencies..."
pip3 install -r ../requirements.txt

# Check for ANTHROPIC_API_KEY
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo ""
    echo "⚠ Warning: ANTHROPIC_API_KEY environment variable not set"
    echo "Please set it before running the pipeline:"
    echo "  export ANTHROPIC_API_KEY='your-api-key-here'"
else
    echo "✓ ANTHROPIC_API_KEY is set"
fi

# Make scripts executable
echo ""
echo "Making scripts executable..."
chmod +x setup.sh
chmod +x docker-entrypoint.sh
chmod +x ../scripts/*.sh 2>/dev/null || true

echo ""
echo "============================================"
echo "Setup Complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "1. Build Docker image:"
echo "   docker-compose build"
echo ""
echo "2. Run the MVP test:"
echo "   python3 orchestrator.py --prompt ../prompts/test_room.txt"
echo ""
echo "For more information, see docs/ directory"
