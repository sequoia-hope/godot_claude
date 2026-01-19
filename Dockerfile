FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    libxcursor1 \
    libxinerama1 \
    libxi6 \
    libxrandr2 \
    libgl1 \
    libglu1-mesa \
    libasound2 \
    libpulse0 \
    xvfb \
    x11vnc \
    scrot \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set Godot version
ENV GODOT_VERSION=4.5.1

# Download and install Godot headless
RUN wget https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip \
    && unzip Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip \
    && mv Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip

# Create working directory
WORKDIR /workspace

# Set up virtual display for headless rendering
ENV DISPLAY=:99

# Copy entrypoint script
COPY scripts/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/bash"]
