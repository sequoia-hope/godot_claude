#!/usr/bin/env python3
"""
PPO training script for Godot RL environments.

Uses Stable-Baselines3 PPO with CNN policy for pixel observations.

Example:
    python scripts/rl/train_ppo.py \
        --env-path ./code/nintendo_walk \
        --total-timesteps 1000000 \
        --n-envs 4
"""

import argparse
import os
import sys
from datetime import datetime
from pathlib import Path

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))


def train_ppo(
    env_path: str,
    total_timesteps: int = 1_000_000,
    n_envs: int = 1,
    learning_rate: float = 3e-4,
    n_steps: int = 2048,
    batch_size: int = 64,
    n_epochs: int = 10,
    gamma: float = 0.99,
    gae_lambda: float = 0.95,
    clip_range: float = 0.2,
    ent_coef: float = 0.01,
    save_dir: str = "./models",
    log_dir: str = "./logs",
    headless: bool = True,
    seed: int = 42,
    base_port: int = 11008,
):
    """
    Train a PPO agent on a Godot environment.

    Args:
        env_path: Path to Godot project or exported executable
        total_timesteps: Total training timesteps
        n_envs: Number of parallel environments
        learning_rate: Learning rate
        n_steps: Steps per environment per update
        batch_size: Minibatch size
        n_epochs: Number of epochs per update
        gamma: Discount factor
        gae_lambda: GAE lambda
        clip_range: PPO clip range
        ent_coef: Entropy coefficient
        save_dir: Directory to save models
        log_dir: Directory for tensorboard logs
        headless: Run environments in headless mode
        seed: Random seed
        base_port: Base TCP port for environments
    """
    try:
        from stable_baselines3 import PPO
        from stable_baselines3.common.vec_env import SubprocVecEnv, VecMonitor
        from stable_baselines3.common.callbacks import (
            CheckpointCallback,
            EvalCallback,
        )
        from stable_baselines3.common.utils import set_random_seed
    except ImportError:
        print("Error: stable-baselines3 not installed.")
        print("Install with: pip install stable-baselines3")
        sys.exit(1)

    from rl.godot_env import make_env

    # Create directories
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    run_name = f"ppo_{Path(env_path).name}_{timestamp}"

    model_dir = Path(save_dir) / run_name
    model_dir.mkdir(parents=True, exist_ok=True)

    log_path = Path(log_dir) / run_name
    log_path.mkdir(parents=True, exist_ok=True)

    print(f"Training PPO on {env_path}")
    print(f"  Total timesteps: {total_timesteps:,}")
    print(f"  Parallel envs: {n_envs}")
    print(f"  Model dir: {model_dir}")
    print(f"  Log dir: {log_path}")

    # Set random seed
    set_random_seed(seed)

    # Create vectorized environment
    if n_envs > 1:
        env_fns = [
            make_env(env_path, port=base_port + i, headless=headless, rank=i)
            for i in range(n_envs)
        ]
        env = SubprocVecEnv(env_fns)
    else:
        from rl.godot_env import GodotEnv
        env = GodotEnv(env_path=env_path, port=base_port, headless=headless)

    env = VecMonitor(env, str(log_path / "monitor"))

    # Create evaluation environment
    eval_env = make_env(env_path, port=base_port + n_envs, headless=headless, rank=0)()
    eval_env = VecMonitor(eval_env, str(log_path / "eval_monitor"))

    # Setup callbacks
    checkpoint_callback = CheckpointCallback(
        save_freq=50_000 // n_envs,
        save_path=str(model_dir / "checkpoints"),
        name_prefix="ppo",
    )

    eval_callback = EvalCallback(
        eval_env,
        best_model_save_path=str(model_dir / "best"),
        log_path=str(log_path / "eval"),
        eval_freq=10_000 // n_envs,
        n_eval_episodes=5,
        deterministic=True,
    )

    # Create PPO model with CNN policy
    model = PPO(
        "CnnPolicy",
        env,
        learning_rate=learning_rate,
        n_steps=n_steps,
        batch_size=batch_size,
        n_epochs=n_epochs,
        gamma=gamma,
        gae_lambda=gae_lambda,
        clip_range=clip_range,
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
        description="Train PPO agent on Godot environment",
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
        default=1_000_000,
        help="Total training timesteps",
    )
    parser.add_argument(
        "--n-envs",
        type=int,
        default=1,
        help="Number of parallel environments",
    )
    parser.add_argument(
        "--learning-rate",
        type=float,
        default=3e-4,
        help="Learning rate",
    )
    parser.add_argument(
        "--n-steps",
        type=int,
        default=2048,
        help="Steps per environment per update",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=64,
        help="Minibatch size",
    )
    parser.add_argument(
        "--gamma",
        type=float,
        default=0.99,
        help="Discount factor",
    )
    parser.add_argument(
        "--ent-coef",
        type=float,
        default=0.01,
        help="Entropy coefficient",
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
        help="Base TCP port for environments",
    )

    args = parser.parse_args()

    train_ppo(
        env_path=args.env_path,
        total_timesteps=args.total_timesteps,
        n_envs=args.n_envs,
        learning_rate=args.learning_rate,
        n_steps=args.n_steps,
        batch_size=args.batch_size,
        gamma=args.gamma,
        ent_coef=args.ent_coef,
        save_dir=args.save_dir,
        log_dir=args.log_dir,
        headless=args.headless,
        seed=args.seed,
        base_port=args.port,
    )


if __name__ == "__main__":
    main()
