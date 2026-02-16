#!/usr/bin/env python3
"""
Smoke test for RL environment integration.

Verifies that the Godot environment is properly set up for RL training
by running a few steps with random actions and checking observations.

Example:
    python scripts/rl/smoke_test.py --build-dir ./code/nintendo_walk
"""

import argparse
import sys
from pathlib import Path

import numpy as np

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))


def smoke_test(
    build_dir: str,
    port: int = 11008,
    n_steps: int = 100,
    save_observation: bool = True,
    output_dir: str = "./tests",
    headless: bool = True,
    timeout: float = 60.0,
) -> dict:
    """
    Run smoke test on RL environment.

    Args:
        build_dir: Path to Godot project directory
        port: TCP port for environment
        n_steps: Number of test steps to run
        save_observation: Save first observation as PNG
        output_dir: Directory to save test outputs
        headless: Run in headless mode
        timeout: Connection timeout in seconds

    Returns:
        Dictionary with test results
    """
    from rl.godot_env import GodotEnv

    build_path = Path(build_dir)
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    print(f"Running RL smoke test on: {build_path}")
    print(f"  Port: {port}")
    print(f"  Steps: {n_steps}")
    print(f"  Headless: {headless}")
    print()

    results = {
        "status": "unknown",
        "errors": [],
        "warnings": [],
        "connection_ok": False,
        "reset_ok": False,
        "step_ok": False,
        "observation_shape": None,
        "reward_range": None,
        "steps_completed": 0,
    }

    env = None
    try:
        # Create environment (don't start game, assume it's running)
        print("1. Creating environment...")
        env = GodotEnv(
            env_path=str(build_path),
            port=port,
            headless=headless,
            timeout=timeout,
        )
        print("   Environment created")

        # Test reset
        print("2. Testing reset...")
        obs, info = env.reset()
        results["connection_ok"] = True
        results["reset_ok"] = True
        results["observation_shape"] = obs.shape
        print(f"   Reset successful, observation shape: {obs.shape}")

        # Save first observation
        if save_observation:
            try:
                from PIL import Image
            except ImportError:
                import imageio

                img_path = output_path / "observation.png"
                imageio.imwrite(str(img_path), obs)
                print(f"   Saved observation to: {img_path}")
            else:
                img = Image.fromarray(obs)
                img_path = output_path / "observation.png"
                img.save(img_path)
                print(f"   Saved observation to: {img_path}")

        # Run test steps
        print(f"3. Running {n_steps} test steps...")
        rewards = []
        terminated_count = 0
        truncated_count = 0

        for i in range(n_steps):
            # Random action
            action = env.action_space.sample()

            obs, reward, terminated, truncated, info = env.step(action)
            rewards.append(reward)

            if terminated:
                terminated_count += 1
                obs, info = env.reset()
            elif truncated:
                truncated_count += 1
                obs, info = env.reset()

            if (i + 1) % 20 == 0:
                print(f"   Step {i + 1}/{n_steps}, reward: {reward:.3f}")

        results["step_ok"] = True
        results["steps_completed"] = n_steps
        results["reward_range"] = (min(rewards), max(rewards))
        results["mean_reward"] = np.mean(rewards)
        results["terminated_episodes"] = terminated_count
        results["truncated_episodes"] = truncated_count

        print(f"   Completed {n_steps} steps")
        print(f"   Reward range: [{min(rewards):.3f}, {max(rewards):.3f}]")
        print(f"   Mean reward: {np.mean(rewards):.3f}")
        print(f"   Episodes: {terminated_count} terminated, {truncated_count} truncated")

        results["status"] = "passed"

    except ConnectionError as e:
        results["status"] = "failed"
        results["errors"].append(f"Connection error: {e}")
        print(f"\nERROR: {e}")
        print("\nMake sure the game is running with RL support enabled.")
        print("The game should be launched with the RLEnv autoload active.")

    except Exception as e:
        results["status"] = "failed"
        results["errors"].append(f"Error: {e}")
        print(f"\nERROR: {e}")
        import traceback
        traceback.print_exc()

    finally:
        if env:
            try:
                env.close()
            except Exception:
                pass

    # Print summary
    print("\n" + "=" * 50)
    print("SMOKE TEST RESULTS")
    print("=" * 50)
    print(f"Status: {results['status'].upper()}")
    print(f"Connection: {'OK' if results['connection_ok'] else 'FAILED'}")
    print(f"Reset: {'OK' if results['reset_ok'] else 'FAILED'}")
    print(f"Step: {'OK' if results['step_ok'] else 'FAILED'}")

    if results['observation_shape']:
        print(f"Observation shape: {results['observation_shape']}")
    if results['reward_range']:
        print(f"Reward range: {results['reward_range']}")

    if results['errors']:
        print("\nErrors:")
        for err in results['errors']:
            print(f"  - {err}")

    print("=" * 50)

    return results


def main():
    parser = argparse.ArgumentParser(
        description="Smoke test for RL environment",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    parser.add_argument(
        "--build-dir",
        type=str,
        required=True,
        help="Path to Godot project directory",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=11008,
        help="TCP port for environment",
    )
    parser.add_argument(
        "--n-steps",
        type=int,
        default=100,
        help="Number of test steps",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default="./tests",
        help="Output directory for test results",
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
        "--timeout",
        type=float,
        default=60.0,
        help="Connection timeout in seconds",
    )

    args = parser.parse_args()

    results = smoke_test(
        build_dir=args.build_dir,
        port=args.port,
        n_steps=args.n_steps,
        output_dir=args.output_dir,
        headless=args.headless,
        timeout=args.timeout,
    )

    # Exit with appropriate code
    sys.exit(0 if results["status"] == "passed" else 1)


if __name__ == "__main__":
    main()
