"""
Gymnasium-compatible wrapper for Godot RL environments.

Communicates with the game via TCP using a protocol compatible with
Godot RL Agents (4-byte length prefix + JSON).
"""

import json
import socket
import struct
import subprocess
import time
import os
from pathlib import Path
from typing import Any, Dict, Optional, Tuple, List

import numpy as np

try:
    import gymnasium as gym
    from gymnasium import spaces
except ImportError:
    import gym
    from gym import spaces


class GodotEnv(gym.Env):
    """
    Gymnasium environment that connects to a Godot game with RL support.

    The environment communicates with the game via TCP. The game should
    have rl_env.gd loaded as an autoload, which handles:
    - Receiving actions and applying them to the player
    - Computing rewards based on progress
    - Capturing and sending observations
    """

    metadata = {"render_modes": ["rgb_array"], "render_fps": 60}

    def __init__(
        self,
        env_path: Optional[str] = None,
        port: int = 11008,
        obs_size: Tuple[int, int] = (96, 96),
        action_dim: int = 2,
        timeout: float = 30.0,
        headless: bool = True,
        speed_multiplier: float = 1.0,
        render_mode: Optional[str] = None,
    ):
        """
        Initialize the Godot environment.

        Args:
            env_path: Path to Godot project or exported executable
            port: TCP port for communication
            obs_size: Observation image size (height, width)
            action_dim: Number of action dimensions
            timeout: Connection timeout in seconds
            headless: Run Godot in headless mode
            speed_multiplier: Game speed multiplier (1.0 = normal)
            render_mode: Gymnasium render mode
        """
        super().__init__()

        self.env_path = env_path
        self.port = port
        self.obs_size = obs_size
        self.action_dim = action_dim
        self.timeout = timeout
        self.headless = headless
        self.speed_multiplier = speed_multiplier
        self.render_mode = render_mode

        # Define spaces
        self.observation_space = spaces.Box(
            low=0,
            high=255,
            shape=(obs_size[0], obs_size[1], 3),
            dtype=np.uint8,
        )

        self.action_space = spaces.Box(
            low=-1.0,
            high=1.0,
            shape=(action_dim,),
            dtype=np.float32,
        )

        # Connection state
        self.socket: Optional[socket.socket] = None
        self.process: Optional[subprocess.Popen] = None
        self._connected = False

        # Last observation for rendering
        self._last_obs: Optional[np.ndarray] = None

    def _start_game(self):
        """Start the Godot game process."""
        if self.process is not None:
            return

        if self.env_path is None:
            print("GodotEnv: No env_path specified, assuming game is already running")
            return

        env_path = Path(self.env_path)

        # Determine how to launch
        if env_path.suffix in [".exe", ".x86_64", ""]:
            # Exported executable
            cmd = [str(env_path)]
        elif env_path.is_dir() and (env_path / "project.godot").exists():
            # Godot project directory - run with godot
            cmd = ["godot", "--path", str(env_path)]
        else:
            raise ValueError(f"Invalid env_path: {env_path}")

        # Add headless flag
        if self.headless:
            cmd.extend(["--headless", "--rendering-driver", "opengl3"])

        # Environment for display
        env = os.environ.copy()
        if self.headless:
            env["DISPLAY"] = ":99"  # Xvfb display

        print(f"GodotEnv: Starting game: {' '.join(cmd)}")

        self.process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
        )

        # Give the game time to start
        time.sleep(2.0)

    def _connect(self):
        """Establish TCP connection to the game."""
        if self._connected:
            return

        self._start_game()

        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.settimeout(self.timeout)

        start_time = time.time()
        while time.time() - start_time < self.timeout:
            try:
                self.socket.connect(("localhost", self.port))
                self._connected = True
                print(f"GodotEnv: Connected to port {self.port}")
                return
            except (ConnectionRefusedError, socket.timeout):
                time.sleep(0.5)

        raise ConnectionError(
            f"Failed to connect to Godot on port {self.port} after {self.timeout}s"
        )

    def _send_message(self, message: Dict[str, Any]):
        """Send a JSON message with length prefix."""
        json_bytes = json.dumps(message).encode("utf-8")
        length = len(json_bytes)
        length_bytes = struct.pack("<I", length)
        self.socket.sendall(length_bytes + json_bytes)

    def _receive_message(self) -> Dict[str, Any]:
        """Receive a JSON message with length prefix."""
        # Read length (4 bytes, little-endian)
        length_bytes = self._recv_exact(4)
        length = struct.unpack("<I", length_bytes)[0]

        # Read JSON payload
        json_bytes = self._recv_exact(length)
        return json.loads(json_bytes.decode("utf-8"))

    def _recv_exact(self, n: int) -> bytes:
        """Receive exactly n bytes from socket."""
        data = b""
        while len(data) < n:
            chunk = self.socket.recv(n - len(data))
            if not chunk:
                raise ConnectionError("Connection closed")
            data += chunk
        return data

    def _obs_to_array(self, obs_data: List[int]) -> np.ndarray:
        """Convert flat observation data to numpy array."""
        arr = np.array(obs_data, dtype=np.uint8)
        return arr.reshape(self.obs_size[0], self.obs_size[1], 3)

    def reset(
        self,
        *,
        seed: Optional[int] = None,
        options: Optional[Dict[str, Any]] = None,
    ) -> Tuple[np.ndarray, Dict[str, Any]]:
        """Reset the environment and return initial observation."""
        super().reset(seed=seed)

        if not self._connected:
            self._connect()

        self._send_message({"type": "reset"})
        response = self._receive_message()

        if response.get("type") != "reset_response":
            raise RuntimeError(f"Unexpected response: {response}")

        obs = self._obs_to_array(response["observation"])
        self._last_obs = obs

        info = response.get("info", {})
        return obs, info

    def step(
        self, action: np.ndarray
    ) -> Tuple[np.ndarray, float, bool, bool, Dict[str, Any]]:
        """Take a step in the environment."""
        if not self._connected:
            raise RuntimeError("Not connected to game")

        # Send action
        action_list = action.tolist() if hasattr(action, "tolist") else list(action)
        self._send_message({"type": "step", "action": action_list})

        # Receive response
        response = self._receive_message()

        if response.get("type") != "step_response":
            raise RuntimeError(f"Unexpected response: {response}")

        obs = self._obs_to_array(response["observation"])
        reward = float(response["reward"])
        terminated = bool(response["terminated"])
        truncated = bool(response["truncated"])
        info = response.get("info", {})

        self._last_obs = obs

        return obs, reward, terminated, truncated, info

    def render(self) -> Optional[np.ndarray]:
        """Render the environment."""
        if self.render_mode == "rgb_array":
            return self._last_obs
        return None

    def close(self):
        """Close the environment and clean up resources."""
        if self._connected and self.socket:
            try:
                self._send_message({"type": "close"})
                self._receive_message()
            except Exception:
                pass

            self.socket.close()
            self._connected = False

        if self.process is not None:
            self.process.terminate()
            try:
                self.process.wait(timeout=5.0)
            except subprocess.TimeoutExpired:
                self.process.kill()
            self.process = None

    def get_info(self) -> Dict[str, Any]:
        """Get environment info from the game."""
        if not self._connected:
            self._connect()

        self._send_message({"type": "get_info"})
        response = self._receive_message()
        return response


def make_env(
    env_path: str,
    port: int = 11008,
    headless: bool = True,
    rank: int = 0,
) -> callable:
    """
    Create a function that makes a GodotEnv instance.

    Useful for creating vectorized environments with SubprocVecEnv.

    Args:
        env_path: Path to Godot project or executable
        port: Base TCP port (will be offset by rank)
        headless: Run in headless mode
        rank: Environment rank for port offset

    Returns:
        Function that creates the environment
    """

    def _init() -> GodotEnv:
        return GodotEnv(
            env_path=env_path,
            port=port + rank,
            headless=headless,
        )

    return _init
