"""
Reinforcement Learning module for Godot game training.

This module provides:
- GodotEnv: Gymnasium-compatible environment wrapper
- Training scripts for PPO and SAC algorithms
- Evaluation and video recording utilities
"""

from .godot_env import GodotEnv

__all__ = ["GodotEnv"]
