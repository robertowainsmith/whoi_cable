"""Reconstruct a WHOI CABLE JONSWAP surface for mooring animations.

Usage in the notebook, after defining E and cbl_file:

    from jonswap_surface import load_jonswap_surface
    surface = load_jonswap_surface(cbl_file)

The returned function has the existing surface(E, x, t) signature, so both
surface calls in animate() can stay unchanged. E is accepted for compatibility;
wave settings are read from cbl_file, not from the older regular-wave parser.

If the wave file has moved, supply wave_dir=Path('/folder/with/wave/file').
Otherwise the loader checks beside the .cbl and the working directory recorded
in its neighbouring run.json, in that order. It never regenerates wave phases.

This implements the upstream WHOI CABLE Morison/random-wave convention from:
https://github.com/jgobat/cable/blob/master/solver/waves.c
https://github.com/jgobat/cable/blob/master/model/setup.c

It displays a reconstructed forcing surface, not a saved model eta diagnostic.
The startup envelope reproduces CABLE's linear forcing ramp. As in CABLE, the
ramped velocities omit the derivative of that envelope during startup.
"""

import json
import re
from pathlib import Path

import numpy as np


def load_jonswap_surface(cbl_file, wave_dir=None):
    """Return surface(E, x, t), with x in metres and t in run-time seconds.

    x may be a scalar or any-shaped NumPy array; t is a scalar. Elevation is
    measured upward from mean sea level, with waves travelling toward +x.
    Supports the supplied CABLE random wave-file format: omega, S(omega), phase.
    """
    cbl_file = Path(cbl_file).expanduser().resolve()
    text = re.sub(r"/\*.*?\*/|//[^\n]*", "", cbl_file.read_text(), flags=re.S)
    # Restrict the search to the actual Environment block, not title/comments.
    match = re.search(
        r"(?ms)^\s*Environment\s*$\n(.*?)(?=^\s*(?:Materials|Connectors|Buoys|Anchors|Layout|End)\s*$|\Z)",
        text,
    )
    if match is None:
        raise ValueError(f"No Environment block found in {cbl_file}")
    env = match.group(1)
    if not re.search(r"\binput-type\s*=\s*random\b", env):
        raise ValueError("This helper requires input-type = random.")
    match = re.search(r'\bwave-file\s*=\s*"([^"\n]+)"', env)
    if match is None:
        raise ValueError("No quoted wave-file entry found in Environment.")
    wave_name = Path(match.group(1)).expanduser()

    def number(block, key, default=None):
        pattern = rf"(?m)^\s*{re.escape(key)}\s*=\s*([-+0-9.eEdD]+)"
        match = re.search(pattern, block)
        if match is not None:
            return float(match.group(1).replace("D", "e").replace("d", "e"))
        if default is None:
            raise ValueError(f"No {key} value found in {cbl_file}")
        return default

    depth = number(env, "depth")
    gravity = number(env, "gravity", 9.81)
    ramp_time = number(text, "ramp-time", 0.0)
    if depth <= 0 or gravity <= 0 or ramp_time < 0:
        raise ValueError("Require positive depth/gravity and non-negative ramp-time.")

    if wave_name.is_absolute():
        candidates = [wave_name]
    elif wave_dir is not None:
        candidates = [Path(wave_dir).expanduser() / wave_name]
    else:
        candidates = [cbl_file.parent / wave_name]
        run_file = cbl_file.parent / "run.json"
        if run_file.is_file():
            run = json.loads(run_file.read_text())
            if run.get("cwd"):
                candidates.append(Path(run["cwd"]).expanduser() / wave_name)
    wave_file = next((path for path in candidates if path.is_file()), None)
    if wave_file is None:
        tried = "\n".join(str(path) for path in candidates)
        raise FileNotFoundError(
            f"Wave file {wave_name} not found. Supply wave_dir explicitly. Tried:\n{tried}"
        )

    data = np.loadtxt(wave_file, ndmin=2)
    if data.shape[0] < 2 or data.shape[1] != 3 or not np.isfinite(data).all():
        raise ValueError("Wave file must have at least two finite omega/S/phase rows.")
    omega_file, spectral_density, phase = data.T
    delta_omega = omega_file[1] - omega_file[0]
    if delta_omega <= 0 or np.any(omega_file <= 0) or np.any(spectral_density < 0):
        raise ValueError("Require increasing positive frequencies and non-negative S.")
    if not np.allclose(np.diff(omega_file), delta_omega, rtol=1e-5, atol=1e-8):
        raise ValueError("CABLE expects an evenly spaced angular-frequency grid.")
    amplitude = np.sqrt(2.0 * spectral_density * delta_omega)
    # Upstream InitializeWaveFile computes its first row before updating d_om.
    # Reproduce its initial 0.05 rad/s for that row; the difference is tiny here.
    amplitude[0] = np.sqrt(2.0 * spectral_density[0] * 0.05)
    # Its time loop reconstructs omega from the first two rows, while computing
    # k from the individual rounded frequencies in the input file.
    omega = omega_file[0] + delta_omega * np.arange(len(omega_file))

    # Same finite-depth dispersion approximation as CABLE's model/setup.c.
    c = omega_file**2 * depth / gravity
    k = np.where(
        c > 20.0,
        c,
        np.where(
            c > 2.0,
            c * (1.0 + 2.0 * np.exp(-2.0 * c) - 12.0 * np.exp(-4.0 * c)),
            np.sqrt(c) * (1.0 + 0.169 * c + 0.031 * c**2),
        ),
    ) / depth

    def surface(E, x, t):
        """Elevation above mean sea level; E retained for existing animation."""
        x = np.asarray(x, dtype=float)
        t = float(t)
        ramp = np.clip(t / ramp_time, 0.0, 1.0) if ramp_time else 1.0
        angles = x[..., None] * k - omega * t - phase
        eta = ramp * np.sum(amplitude * np.cos(angles), axis=-1)
        return float(eta) if eta.ndim == 0 else eta

    return surface
