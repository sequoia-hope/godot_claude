#!/usr/bin/env python3
"""
Evaluation script for trained RL agents.

Loads a trained model and runs evaluation episodes with optional
video recording.

Example:
    python scripts/rl/eval_agent.py \
        --model-path ./models/ppo_nintendo_walk/best/best_model.zip \
        --env-path ./code/nintendo_walk \
        --n-episodes 10 \
        --record-video
"""

import argparse
import sys
from pathlib import Path
from typing import Optional

import numpy as np

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))


def evaluate_agent(
    model_path: str,
    env_path: str,
    n_episodes: int = 10,
    record_video: bool = False,
    video_dir: str = "./videos",
    headless: bool = True,
    port: int = 11008,
    deterministic: bool = True,
    verbose: bool = True,
) -> dict:
    """
    Evaluate a trained agent.

    Args:
        model_path: Path to trained model (.zip file)
        env_path: Path to Godot project or executable
        n_episodes: Number of evaluation episodes
        record_video: Whether to record video
        video_dir: Directory to save videos
        headless: Run in headless mode (ignored if recording video)
        port: TCP port for environment
        deterministic: Use deterministic actions
        verbose: Print progress

    Returns:
        Dictionary with evaluation statistics
    """
    try:
        from stable_baselines3 import PPO, SAC
    except ImportError:
        print("Error: stable-baselines3 not installed.")
        print("Install with: pip install stable-baselines3")
        sys.exit(1)

    from rl.godot_env import GodotEnv

    model_path = Path(model_path)
    if not model_path.exists():
        raise FileNotFoundError(f"Model not found: {model_path}")

    # Detect algorithm from model filename
    model_name = model_path.stem.lower()
    if "sac" in model_name:
        Model = SAC
    else:
        Model = PPO  # Default to PPO

    if verbose:
        print(f"Loading model from: {model_path}")
        print(f"Algorithm: {Model.__name__}")

    # Load model
    model = Model.load(str(model_path))

    # Create environment
    # If recording video, we can't run headless
    if record_video:
        headless = False

    env = GodotEnv(
        env_path=env_path,
        port=port,
        headless=headless,
        render_mode="rgb_array" if record_video else None,
    )

    # Setup video recording
    video_writer = None
    if record_video:
        try:
            import imageio
        except ImportError:
            print("Warning: imageio not installed, video recording disabled")
            print("Install with: pip install imageio[ffmpeg]")
            record_video = False

        if record_video:
            video_path = Path(video_dir)
            video_path.mkdir(parents=True, exist_ok=True)

    # Run evaluation episodes
    episode_rewards = []
    episode_lengths = []
    episode_successes = []

    for ep in range(n_episodes):
        obs, info = env.reset()
        done = False
        ep_reward = 0.0
        ep_length = 0
        frames = []

        while not done:
            action, _ = model.predict(obs, deterministic=deterministic)
            obs, reward, terminated, truncated, info = env.step(action)

            ep_reward += reward
            ep_length += 1
            done = terminated or truncated

            if record_video:
                frame = env.render()
                if frame is not None:
                    frames.append(frame)

        episode_rewards.append(ep_reward)
        episode_lengths.append(ep_length)

        # Check if episode was successful
        success = info.get("progress", 0.0) >= 1.0
        episode_successes.append(success)

        if verbose:
            status = "SUCCESS" if success else "FAILED"
            print(
                f"Episode {ep + 1}/{n_episodes}: "
                f"reward={ep_reward:.2f}, length={ep_length}, {status}"
            )

        # Save video
        if record_video and frames:
            video_file = video_path / f"episode_{ep + 1}.mp4"
            imageio.mimsave(str(video_file), frames, fps=30)
            if verbose:
                print(f"  Saved video: {video_file}")

    env.close()

    # Compute statistics
    results = {
        "n_episodes": n_episodes,
        "mean_reward": np.mean(episode_rewards),
        "std_reward": np.std(episode_rewards),
        "min_reward": np.min(episode_rewards),
        "max_reward": np.max(episode_rewards),
        "mean_length": np.mean(episode_lengths),
        "success_rate": np.mean(episode_successes),
        "episode_rewards": episode_rewards,
        "episode_lengths": episode_lengths,
    }

    if verbose:
        print("\n" + "=" * 50)
        print("EVALUATION RESULTS")
        print("=" * 50)
        print(f"Episodes: {n_episodes}")
        print(f"Mean reward: {results['mean_reward']:.2f} +/- {results['std_reward']:.2f}")
        print(f"Min/Max reward: {results['min_reward']:.2f} / {results['max_reward']:.2f}")
        print(f"Mean length: {results['mean_length']:.1f}")
        print(f"Success rate: {results['success_rate'] * 100:.1f}%")
        print("=" * 50)

    return results


def main():
    parser = argparse.ArgumentParser(
        description="Evaluate trained RL agent",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    parser.add_argument(
        "--model-path",
        type=str,
        required=True,
        help="Path to trained model (.zip file)",
    )
    parser.add_argument(
        "--env-path",
        type=str,
        required=True,
        help="Path to Godot project or executable",
    )
    parser.add_argument(
        "--n-episodes",
        type=int,
        default=10,
        help="Number of evaluation episodes",
    )
    parser.add_argument(
        "--record-video",
        action="store_true",
        help="Record video of episodes",
    )
    parser.add_argument(
        "--video-dir",
        type=str,
        default="./videos",
        help="Directory to save videos",
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
        "--port",
        type=int,
        default=11008,
        help="TCP port for environment",
    )
    parser.add_argument(
        "--stochastic",
        action="store_true",
        help="Use stochastic actions instead of deterministic",
    )

    args = parser.parse_args()

    evaluate_agent(
        model_path=args.model_path,
        env_path=args.env_path,
        n_episodes=args.n_episodes,
        record_video=args.record_video,
        video_dir=args.video_dir,
        headless=args.headless,
        port=args.port,
        deterministic=not args.stochastic,
    )


if __name__ == "__main__":
    main()
