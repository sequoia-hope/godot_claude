#!/bin/bash
set -e

# Start Xvfb (X virtual framebuffer) for headless rendering
Xvfb :99 -screen 0 1920x1080x24 &
XVFB_PID=$!

# Wait for Xvfb to be ready
sleep 2

# Cleanup function
cleanup() {
    echo "Stopping Xvfb..."
    kill $XVFB_PID 2>/dev/null || true
}
trap cleanup EXIT

# Set default rendering driver for software rendering (no GPU)
export GODOT_RENDERING_DRIVER="${GODOT_RENDERING_DRIVER:-opengl3}"

# Execute the main command
exec "$@"
