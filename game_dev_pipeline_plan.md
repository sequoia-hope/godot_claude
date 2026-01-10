# AI-Driven Game Development Pipeline

## System Overview

A comprehensive workflow where you describe game environments in narrative form, Claude Code generates playable game code, automated testing validates and debugs the implementation, and you iterate based on visual feedback and performance metrics.

## Core Architecture

### 1. Creative Input Layer
- You describe environments and gameplay scenarios in natural language
- Descriptions focus on narrative and design intent rather than technical implementation
- Git tracks all prompts and design iterations for later analysis

### 2. Code Generation Layer
- Claude Code generates game engine code (Godot/Unity) based on your descriptions
- System creates containerized game engine environments
- Code is version-controlled and tied to specific design prompts

### 3. Automated Testing & Validation Layer
- **Headless Rendering**: Game engine runs headless in Docker container with GPU passthrough
- **Programmatic Input Simulation**: Automated player movement tests (forward, backward, jump, turn)
- **Screenshot Capture**: Key frames captured at defined test points
- **Visual Analysis**: Multimodal AI model (Claude, GPT-4 Vision, or Gemini) analyzes screenshots for:
  - Correctness of rendered environment
  - Player movement validation
  - Animation playback verification
  - Visual artifacts or rendering errors
  - Overall scene composition
- **Performance Profiling**: Automated measurement of:
  - Frame rate / render times
  - Memory usage
  - GPU utilization
  - CPU bottlenecks
- **Feedback Generation**: AI suggests fixes, optimizations, or algorithmic alternatives if performance is unacceptable

### 4. Iteration Loop
- Test results are logged and presented back to Claude Code
- Claude Code refines code based on feedback
- Visual issues are flagged with specific screenshot evidence
- Performance bottlenecks trigger architectural suggestions
- Loop continues until quality thresholds are met

### 5. Asset Generation Pipeline (Phase 2)
- Text descriptions converted to 3D assets using:
  - Shap-E (text-to-3D)
  - 3D Gaussian Splatting
  - Diffusion-based 3D models
- Pre-rendered on GPU machine (acceptable to take 10+ minutes per world)
- Assets imported into game engine
- Richer visual fidelity without real-time computational overhead

### 6. Distributed Rendering (Phase 2)
- Laptop as creative interface / controller
- GPU desktop machine for rendering and computation
- SSH for command/control layer
- VNC or Steam Remote Play for gameplay testing on laptop
- Clean separation between logic server and display client

## First Milestone: Test Room MVP

**Goal**: Prove the entire pipeline works end-to-end

**Description to Claude Code**: "Create a rectangular room. The walls have a simple grid placeholder texture. The player starts inside and can move forward, backward, left, right, and jump. The camera follows the player. Lighting is basic but adequate to see the environment."

**Expected Output**:
- Playable Godot/Unity executable
- Player can walk around empty rectangular room
- Grid-textured walls
- Functional camera
- No complex assets or advanced features

**Testing Steps**:
1. Capture starting position screenshot
2. Move player forward, capture screenshot
3. Move player to each corner, capture screenshots
4. Test jump mechanics
5. Verify grid textures visible
6. Check frame rate stays above target

**Success Criteria**:
- Game runs without crashes
- Player movement responds to simulated input
- Camera follows player correctly
- Environment renders without major visual errors
- Frame rate acceptable (target: 60 FPS)

## Comprehensive System Components

### A. Orchestration & Workflow Management
- Master script or system that:
  - Accepts natural language scene descriptions
  - Submits prompts to Claude Code
  - Monitors code generation
  - Triggers test suite
  - Collects and analyzes results
  - Decides whether to iterate or accept
  - Manages state transitions

### B. Version Control & Experiment Tracking
- **Git Repository Structure**:
  - `/prompts/` - Design descriptions and Claude Code prompts (tagged by iteration)
  - `/code/` - Generated game code
  - `/tests/` - Test screenshots and performance logs
  - `/assets/` - Generated 3D models (Phase 2)
  - `/docs/` - Design decisions and architecture notes

- **Meta-Logging System**:
  - Timestamp of each prompt submission
  - Design rationale and goals for that iteration
  - Test results and analysis
  - Decision points where you chose to iterate vs. restart
  - Performance bottleneck identification
  - Complexity assessment at each stage

- **Commit Messages** capture:
  - What was attempted
  - Why that approach was chosen
  - Results observed
  - Next steps or pivot decisions

### C. Quality Assessment System
- **Visual Quality**:
  - Multimodal AI reviews screenshots
  - Checks for rendering errors, missing elements, visual coherence
  - Compares against design intent from original prompt

- **Gameplay Quality**:
  - Player input correctly mapped to character movement
  - Camera behavior smooth and intuitive
  - No clipping, falling through geometry, or physics errors
  - Animation state transitions work correctly

- **Performance Quality**:
  - Frame rate meets target (configurable, e.g., 60 FPS)
  - Memory usage within bounds
  - GPU/CPU not bottlenecked by specific algorithms
  - If performance unacceptable, system flags computational dead ends
  - Suggests algorithmic alternatives (spatial partitioning for collision detection, LOD for rendering, etc.)

### D. Containerization & Environment
- **Docker Configuration**:
  - Image with game engine (Godot or Unity)
  - GPU passthrough for rendering
  - Linux-based (your existing Linux machines)
  - Headless mode capabilities
  - SSH accessibility for remote execution

- **Local Development**:
  - Laptop: Creative interface, prompt writing, result analysis
  - GPU Desktop: Docker containers, code execution, rendering
  - SSH tunneling for seamless remote workflow
  - Optional: VNC for playing games on laptop with GPU rendering

### E. Testing Automation Framework
- **Input Simulation**:
  - Script that sends programmatic input to game engine
  - Predefined test sequences (walk forward 5 units, jump, turn 90°, etc.)
  - Configurable test scenarios per project

- **Screenshot Pipeline**:
  - Capture at test start, key movement points, test end
  - Save with metadata (timestamp, test case, frame number)
  - Store in version control for comparison across iterations

- **Analysis System**:
  - Multimodal AI analyzes each screenshot
  - Identifies issues: missing objects, broken textures, incorrect lighting, etc.
  - Generates detailed feedback for Claude Code
  - Suggests specific code fixes when possible

- **Performance Telemetry**:
  - Automated FPS measurement
  - Memory profiling
  - GPU/CPU usage tracking
  - Bottleneck identification

### F. Iteration Management
- **Decision Logic**:
  - If tests pass and performance is good: Accept build, optionally add complexity
  - If visual issues: Return feedback to Claude Code with screenshots
  - If performance bottleneck: Return performance data + algorithmic suggestions
  - If complexity spiraled: Option to restart from clean slate (tracked in git history)

- **Clean Slate Option**:
  - Previous iteration fully documented in git
  - New attempt starts fresh without accumulated baggage
  - Debrief compares approach 1 vs approach 2
  - Lessons learned inform future iterations

## Phase-Based Implementation Plan

### Phase 1: Core Pipeline (MVP)
1. **Setup**: Docker + headless game engine on GPU machine
2. **Simple Testing**: Manual screenshot capture + basic input simulation
3. **First Milestone**: Test room (rectangular room with grid, player movement)
4. **Claude Code Integration**: Generate code for test room
5. **Visual Verification**: Multimodal AI reviews test room screenshots
6. **Iteration Loop**: Refine based on feedback until test room works

### Phase 2: Rich Assets & Advanced Testing
1. **3D Asset Generation**: Implement Shap-E or Gaussian Splatting pipeline
2. **Pre-Rendering**: GPU machine handles 10+ minute asset generation
3. **Advanced Performance Testing**: Automated profiling and optimization suggestions
4. **Distributed Rendering**: Implement VNC/streaming for gameplay on laptop
5. **Complex Scene Support**: Graduate beyond test room to actual game environments

### Phase 3: Advanced Features (Optional)
1. **Fine-tuning**: Customize asset generation to your visual style
2. **Collaborative Testing**: Multiple agents testing different aspects simultaneously
3. **Procedural Generation**: Blend real-time generation with pre-rendered assets
4. **Full Game Loop**: Support for multiple scenes, story progression, etc.

## Key Decisions & Open Questions

- **Game Engine Choice**: Godot (lightweight, open source) vs Unity (industry standard)?
- **Primary Multimodal Model**: Claude for consistency vs GPT-4 Vision vs Gemini? (Can use separate from Claude Code)
- **Performance Targets**: Define FPS, memory, and GPU utilization thresholds
- **Test Complexity**: Start with simple movement tests, evolve to complex scenarios
- **Asset Strategy**: Pure real-time generation vs hybrid (pre-rendered + simple real-time)?
- **Restart Threshold**: How many iterations before you prefer a clean slate?

## Success Metrics

- Can describe a simple scene and see it playable within 1 complete iteration cycle
- System catches and communicates visual bugs autonomously
- Performance bottlenecks identified and alternative approaches suggested
- Clean git history allows you to analyze the entire process post-project
- Meta-logging captures enough detail to write a debrief on what worked/didn't

## Next Steps

1. Choose game engine (Godot recommended for lightweight + good open source support)
2. Set up Docker container with headless game engine and GPU passthrough
3. Write basic input simulation and screenshot capture scripts
4. Create Claude Code prompt for generating test room code
5. Implement visual analysis integration (Claude multimodal API)
6. Build orchestration script to tie everything together
7. Execute MVP milestone: Generate and test the simple rectangular room
8. Iterate based on results and decide on Phase 2 priorities
