# WHOI Cable with a free-floating surface buoy

This repository is [WHOI Cable](https://github.com/jgobat/cable), the
time-domain mooring and towed-cable simulator by Jason Gobat and Mark
Grosenbaugh, plus a small patch, scripts and example cases for simulating
surface moorings whose float can be **pulled under by current or waves and
resurface again**.

Stock Cable can't do that: with `forcing-method = morison` it fixes a surface
buoy's draft at its full height, so the buoy has constant buoyancy and never
sinks or rises with the waves. The patch makes the draft follow the buoy's
position relative to the local wave surface. It touches three source files and
only affects 2D surface moorings with Morison forcing. See
[docs/PATCH.md](docs/PATCH.md) for what changed, why, and its limitations.

The upstream source is left untouched. The build script compiles two programs
side by side:

| Program (installed into the `whoi-cable` environment) | What it is |
|---|---|
| `cable` | stock WHOI Cable |
| `cable-free` | WHOI Cable with `patches/cable-free-surface-buoy.patch` applied |
| `res2mat`, `res2asc` | Cable's output converters (unchanged) |

## Quick start (Windows with WSL and conda)

Everything — compilers, Cable and the notebook's Python packages — lives in
one conda environment, `whoi-cable`, defined in `environment.yml`. No `sudo`
is needed. Full step-by-step instructions are in [docs/SETUP.md](docs/SETUP.md).
In short, in a WSL (Ubuntu) terminal with conda (e.g. Miniconda) installed:

```bash
git clone https://github.com/robertowainsmith/whoi_cable.git ~/whoi_cable
cd ~/whoi_cable
scripts/setup_env.sh          # one-off: creates the whoi-cable environment and Jupyter kernel
conda activate whoi-cable
scripts/build.sh              # builds cable and cable-free into the environment
scripts/run_case.sh southland_front_30m
```

The run's output is in `runs/southland_front_30m/`. To plot it, open
`notebooks/plot_run.ipynb` in your Jupyter with the **Python (whoi-cable)**
kernel, set `RUN_NAME` in the Settings cell, and run all cells.

## What's in the repository

| Folder | Contents |
|---|---|
| `cli/`, `model/`, `solver/`, `include/`, `results/`, `gui/`, `widgets/`, `examples/` | upstream WHOI Cable source, unchanged |
| `patches/` | `cable-free-surface-buoy.patch`, the change that makes `cable-free` |
| `scripts/` | `setup_env.sh` (one-off: conda environment and Jupyter kernel), `build.sh` (build both programs), `run_case.sh` (run a case) |
| `cases/` | example input files (`.cbl`) for `cable-free` |
| `notebooks/` | `plot_run.ipynb`: summary, anchor estimate, figures and animations (MP4) for a run |
| `environment.yml` | the `whoi-cable` conda environment: compilers and build tools, Python packages, `ipykernel` and `ffmpeg` (conda-forge only) |
| `docs/` | upstream Cable manuals (`WHOI_Cable_manual-2.0.pdf`, `cable_manual.html`), plus `SETUP.md` (setup) and `PATCH.md` (the patch: changes, justification, limitations) |

`build/` and `runs/` are created by the scripts and are not tracked by git.
Before committing changes to the notebook, clear its outputs (**Edit → Clear
Outputs of All Cells** in Jupyter Lab, then save) so embedded videos don't
bloat the repository.

## Example cases

Run any of these with `scripts/run_case.sh <case>`. Each `.cbl` file starts
with a comment block describing the mooring, the conditions and the
assumptions behind it.

| Case | Mooring and conditions | Run time* |
|---|---|---|
| `southland_front_30m` | Polyform LD-1 buoy (13 kg) on 40 m of 12 mm polypropylene in 30 m; 2 m, 8 s waves; current 0.7 m/s at the surface to 0.1 m/s at the bed | 20 s |
| `southland_front` | LD-1 buoy on 130 m of polypropylene in 110 m; same waves and current | 50 s |
| `southland_front_invcat` | inverse-catenary version: LD-1, 3 kg downweight, 5 kg subsurface float, polypropylene and chain in 110 m; 0.5 m/s current | 80 s |
| `slb600_waves` | Sealite SL-B600 marker buoy on chain, polypropylene and chain in 40 m; 2 m, 8 s waves; 0.5 m/s | 15 s |
| `slb600_pulldown` | SL-B600 mooring with the current ramped 0.2 → 2 → 0.2 m/s; buoy pulled under and resurfacing | 35 s |
| `swex_pulldown` | Cable's SWEX example mooring with the current ramped 1 → 4.5 → 1 m/s | 25 s |
| `swex_free` | SWEX mooring in 2 m, 8 s waves; **run with** `scripts/run_case.sh swex_free -auto` | 15 s |
| `wirewalker_southland` | Wirewalker profiler mooring in 100 m, translated from a ProteusDS Designer template | 2.5 min |

\* on a typical laptop core; yours will differ.

Component properties in these cases (buoy shapes, rope stiffness, drag
coefficients) are typical or estimated values, not manufacturer data. Check
them before relying on a result.

## Notes for writing your own cases

- Use `type = surface` and `forcing-method = morison`, or the patch has no effect.
- If the buoy might start submerged, use `static-initial-guess = catenary` and
  `static-solution = relaxation` and run **without** `-auto`. If the buoy
  starts at the surface and the static solve fails, try `-auto`.
- If the log says the static solve "never converged", raise
  `static-outer-iterations` (1000 works for the cases here).
- Light buoys on near-taut lines may need a small `time-step` (0.005 s for the
  LD-1 cases).
- Set `ramp-time` to a whole number of wave periods.
- For a time-varying current, put `x-current-modulation` before `x-current`
  and write it as an expression in `t` or as `(time, factor)` pairs. A plain
  constant crashes Cable.

## The graphical interface (optional)

Cable's GUI, `wcable`, can also be built and run under WSL, as a stock version
(`wcable`) and one with the buoy patch (`wcable-free`). It uses Ubuntu's GTK 2
packages rather than the conda environment. See [docs/GUI.md](docs/GUI.md):

```bash
scripts/setup_gui.sh      # once; installs system libraries (needs sudo)
scripts/build_gui.sh
wcable-free cases/slb600_waves.cbl &
```

## Credit and licence

WHOI Cable is copyright Woods Hole Oceanographic Institution, Jason Gobat,
and (for parts of the input parser) Jason Gobat and Darren Atkinson, as
stated in the source files. It is distributed under the GNU General Public
License v3 (see `COPYING`). The patch, scripts, cases and notebook in this
repository are distributed under the same licence.

If you use WHOI Cable in published work, cite the Cable manual and
Gobat & Grosenbaugh's papers (listed in [docs/PATCH.md](docs/PATCH.md)), and
say that the free-floating surface buoy patch was used.

See NOTICE for the original copyright holders and a dated list of the modifications.
