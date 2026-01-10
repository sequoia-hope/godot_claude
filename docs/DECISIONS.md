# Architectural Decisions

This document tracks key technical decisions and their rationale for the AI-driven game development pipeline.

## Decision Log

### 2026-01-10: Initial Architecture Decisions

#### Game Engine: Godot

**Chosen**: Godot
**Alternatives Considered**: Unity

**Rationale**:
- Lightweight and open source
- Excellent Linux support for headless operation
- Simpler Docker integration
- Better suited for automated testing workflows
- GDScript is easier to generate programmatically than C#
- Lower resource overhead for MVP validation

#### Development Platform: Local Laptop First

**Chosen**: Local laptop for initial development
**Alternatives Considered**: GPU desktop via SSH from start

**Rationale**:
- Prove concepts locally before adding distributed complexity
- Faster iteration during MVP phase
- Can migrate to GPU desktop once pipeline is validated
- Simpler debugging and development workflow initially

#### Performance Targets: 60 FPS, Relaxed Memory

**Chosen**: 60 FPS minimum, no strict memory constraints initially
**Alternatives Considered**: 30 FPS with strict resource limits

**Rationale**:
- Focus on getting the pipeline working end-to-end
- 60 FPS is standard for smooth gameplay experience
- Memory optimization can come later once system is functional
- Avoid premature optimization that could block progress

#### Implementation Approach: Full Automation Immediately

**Chosen**: Build complete orchestration system from the start
**Alternatives Considered**: Manual steps first, automate incrementally

**Rationale**:
- Automation is core to the vision of this pipeline
- Building the orchestrator early ensures all components integrate correctly
- Manual steps risk accumulating technical debt
- Easier to debug individual components within automated framework
- Demonstrates full pipeline capability sooner

## Technology Stack

### Core Components
- **Game Engine**: Godot 4.x (headless mode)
- **Containerization**: Docker with GPU passthrough
- **Language**: Python for orchestration and automation
- **Version Control**: Git with structured workflow
- **AI Services**:
  - Claude Code for game code generation
  - Claude multimodal API for visual analysis
  - Claude API for performance feedback and suggestions

### Testing Infrastructure
- **Input Simulation**: Godot headless mode with programmatic input
- **Screenshot Capture**: Godot's get_viewport().get_texture().get_image()
- **Performance Profiling**: Godot performance monitors + OS-level metrics
- **Visual Analysis**: Claude Vision API for screenshot validation

## Open Questions

- [ ] Should we use Godot 3.x or 4.x? (4.x has better rendering, 3.x more stable)
- [ ] Best practice for GPU passthrough on laptop? (may not have discrete GPU)
- [ ] How to handle test flakiness in automated visual analysis?
- [ ] Threshold for acceptable visual analysis confidence scores?
- [ ] When to trigger "clean slate" restart vs continue iterating?

## Future Considerations (Phase 2+)

- 3D asset generation pipeline (Shap-E, Gaussian Splatting)
- Distributed rendering between laptop and GPU desktop
- VNC/Steam Remote Play for gameplay testing
- Pre-rendered asset caching strategy
- Multi-scene support and scene transitions
