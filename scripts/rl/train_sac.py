#!/usr/bin/env python3
"""
SAC training script for Godot RL environments.

Uses Stable-Baselines3 SAC with CNN policy for pixel observations.
SAC is often more sample-efficient than PPO for continuous control.

Example:
    python scripts/rl/train_sac.py \
        --env-path ./code/nintendo_walk \
        --total-timesteps 500000
"""

import argparse
import os
import sys
from datetime import datetime
from pathlib import Path

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))


def train_sac(
    env_path: str,
    total_timesteps: int = 500_000,
    learning_rate: float = 3e-4,
    buffer_size: int = 100_000,
    batch_size: int = 256,
    tau: float = 0.005,
    gamma: float = 0.99,
    learning_starts: int = 10_000,
    train_freq: int = 1,
    gradient_steps: int = 1,
    ent_coef: str = "auto",
    save_dir: str = "./models",
    log_dir: str = "./logs",
    headless: bool = True,
    seed: int = 42,
    port: int = 11008,
):
    """
    Train a SAC agent on a Godot environment.

    Args:
        env_path: Path to Godot project or exported executable
        total_timesteps: Total training timesteps
        learning_rate: Learning rate
        buffer_size: Replay buffer size
        batch_size: Batch size for training
        tau: Soft update coefficient
        gamma: Discount factor
        learning_starts: Steps before training starts
        train_freq: Update frequency
        gradient_steps: Gradient steps per update
        ent_coef: Entropy coefficient ("auto" for automatic tuning)
        save_dir: Directory to save models
        log_dir: Directory for tensorboard logs
        headless: Run in headless mode
        seed: Random seed
        port: TCP port for environment
    """
    try:
        from stable_baselines3 import SAC
        from stable_baselines3.common.vec_env import DummyVecEnv, VecMonitor
        from stable_baselines3.common.callbacks import (
            CheckpointCallback,
            EvalCallback,
        )
        from stable_baselines3.common.utils import set_random_seed
    except ImportError:
        print("Error: stable-baselines3 not installed.")
        print("Install with: pip install stable-baselines3")
        sys.exit(1)

    from rl.godot_env import GodotEnv

    # Create directories
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    run_name = f"sac_{Path(env_path).name}_{timestamp}"

    model_dir = Path(save_dir) / run_name
    model_dir.mkdir(parents=True, exist_ok=True)

    log_path = Path(log_dir) / run_name
    log_path.mkdir(parents=True, exist_ok=True)

    print(f"Training SAC on {env_path}")
    print(f"  Total timesteps: {total_timesteps:,}")
    print(f"  Buffer size: {buffer_size:,}")
    print(f"  Model dir: {model_dir}")
    print(f"  Log dir: {log_path}")

    # Set random seed
    set_random_seed(seed)

    # Create environment
    env = GodotEnv(env_path=env_path, port=port, headless=headless)
    env = DummyVecEnv([lambda: env])
    env = VecMonitor(env, str(log_path / "monitor"))

    # Create evaluation environment
    eval_env = GodotEnv(env_path=env_path, port=port + 1, headless=headless)
    eval_env = DummyVecEnv([lambda: eval_env])
    eval_env = VecMonitor(eval_env, str(log_path / "eval_monitor"))

    # Setup callbacks
    checkpoint_callback = CheckpointCallback(
        save_freq=50_000,
        save_path=str(model_dir / "checkpoints"),
        name_prefix="sac",
    )

    eval_callback = EvalCallback(
        eval_env,
        best_model_save_path=str(model_dir / "best"),
        log_path=str(log_path / "eval"),
        eval_freq=10_000,
        n_eval_episodes=5,
        deterministic=True,
    )

    # Create SAC model with CNN policy
    model = SAC(
        "CnnPolicy",
        env,
        learning_rate=learning_rate,
        buffer_size=buffer_size,
        batch_size=batch_size,
        tau=tau,
        gamma=gamma,
        learning_starts=learning_starts,
        train_freq=train_freq,
        gradient_steps=gradient_steps,
        ent_coef=ent_coef,
        verbose=1,
        tensorboard_log=str(log_path),
        seed=seed,
    )

    print("\nStarting training...")
    print("Monitor with: tensorboard --logdir", log_path)

    try:
        model.learn(
            total_timesteps=total_timesteps,
            callback=[checkpoint_callback, eval_callback],
            progress_bar=True,
        )
    except KeyboardInterrupt:
        print("\nTraining interrupted by user")
    finally:
        # Save final model
        final_path = model_dir / "final_model"
        model.save(str(final_path))
        print(f"\nSaved final model to: {final_path}")

        # Cleanup
        env.close()
        eval_env.close()

    return str(model_dir)


def main():
    parser = argparse.ArgumentParser(
        description="Train SAC agent on Godot environment",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    parser.add_argument(
        "--env-path",
        type=str,
        required=True,
        help="Path to Godot project or exported executable",
    )
    parser.add_argument(
        "--total-timesteps",
        type=int,
        default=500_000,
        help="Total training timesteps",
    )
    parser.add_argument(
        "--learning-rate",
        type=float,
        default=3e-4,
        help="Learning rate",
    )
    parser.add_argument(
        "--buffer-size",
        type=int,
        default=100_000,
        help="Replay buffer size",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=256,
        help="Batch size",
    )
    parser.add_argument(
        "--gamma",
        type=float,
        default=0.99,
        help="Discount factor",
    )
    parser.add_argument(
        "--learning-starts",
        type=int,
        default=10_000,
        help="Steps before training starts",
    )
    parser.add_argument(
        "--save-dir",
        type=str,
        default="./models",
        help="Directory to save models",
    )
    parser.add_argument(
        "--log-dir",
        type=str,
        default="./logs",
        help="Directory for tensorboard logs",
    )
    parser.add_argument(
        "--headless",
        action="store_true",
        default=True,
        help="Run in headless mode",
    )
    parser.add_argument(
        "--no-headless",
        action="store_false",
        dest="headless",
        help="Run with display",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=11008,
        help="TCP port for environment",
    )

    args = parser.parse_args()

    train_sac(
        env_path=args.env_path,
        total_timesteps=args.total_timesteps,
        learning_rate=args.learning_rate,
        buffer_size=args.buffer_size,
        batch_size=args.batch_size,
        gamma=args.gamma,
        learning_starts=args.learning_starts,
        save_dir=args.save_dir,
        log_dir=args.log_dir,
        headless=args.headless,
        seed=args.seed,
        port=args.port,
    )


if __name__ == "__main__":
    main()
