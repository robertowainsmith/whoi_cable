# WHOI Cable with a free-floating surface buoy

This repository is [WHOI Cable](https://github.com/jgobat/cable), the
time-domain mooring and towed-cable simulator by Jason Gobat and Mark
Grosenbaugh, plus a small patch, Jupyter notebooks, scripts and example cases
for simulating surface moorings whose float can be **pulled under by current
or waves and resurface again**, in regular waves or random (JONSWAP) seas.

Stock Cable can't do that: with `forcing-method = morison` it fixes a surface
buoy's draft at its full height, so the buoy has constant buoyancy and never
sinks or rises with the waves. The patch makes the draft follow the buoy's
position relative to the local wave surface. It touches three source files and
only affects 2D surface moorings with Morison forcing. See
[docs/PATCH.md](docs/PATCH.md) for what changed, why, and its limitations.

A second patch adds **wave kinematic stretching**. Stock Cable sets the wave
orbital velocity to zero above the mean water level, so a buoy riding the
surface feels no flow on crests but the full flow in troughs, and is pushed
steadily up-wave. `cable-free` uses Wheeler stretching instead, which carries
the kinematics up to the instantaneous surface. Set `CABLE_STRETCHING=none`
to get the stock behaviour back for comparison. See
[docs/STRETCHING.md](docs/STRETCHING.md).

The upstream source is left untouched. The build script compiles two programs
side by side:

| Program (installed into the `whoi-cable` environment) | What it is |
|---|---|
| `cable` | stock WHOI Cable |
| `cable-free` | WHOI Cable with `patches/cable-free-surface-buoy.patch` and `patches/cable-wave-stretching.patch` applied |
| `res2mat`, `res2asc` | Cable's output converters (unchanged) |

Two notebooks sit on top of these:

| Notebook | What it does |
|---|---|
| `notebooks/cable_designer.ipynb` | an interactive designer: build a mooring from parts, set the current and a regular wave or a JONSWAP random sea, export the `.cbl` input, run `cable-free` or `cable`, and see the static shape and time series |
| `notebooks/plot_run.ipynb` | plots any run (from the designer or `scripts/run_case.sh`): submergence summary, anchor estimate, time series, mooring shapes, tension along the line, and an MP4 animation coloured by tension |

## Quick start (Windows with WSL and conda)

Everything (compilers, Cable and the notebooks' Python packages) lives in one
conda environment, `whoi-cable`, defined in `environment.yml`. No `sudo` is
needed. Full step-by-step instructions are in [docs/SETUP.md](docs/SETUP.md).
In short, in a WSL (Ubuntu) terminal with conda (e.g. Miniconda) installed:

```bash
git clone https://github.com/robertowainsmith/whoi_cable.git ~/whoi_cable
cd ~/whoi_cable
scripts/setup_env.sh          # one-off: creates the whoi-cable environment and Jupyter kernel
conda activate whoi-cable
scripts/build.sh              # builds cable and cable-free into the environment
```

Then start Jupyter from the repository folder (inside WSL) and open the
notebooks with the **Python (whoi-cable)** kernel:

1. **Design and run** in `notebooks/cable_designer.ipynb`: **Run → Run All
   Cells**, load a case from `cases/` (or start blank) on *Setup & projects*,
   edit it, and run it on *Run & results*. Each run gets its own folder,
   `runs/<case>_<timestamp>/`.
2. **Plot** in `notebooks/plot_run.ipynb`: set `RUN_NAME` to the case name and
   `RUN_DIR_OVERRIDE` to the run folder (the designer prints both), then run
   all cells.

To run an example case without the designer:

```bash
scripts/run_case.sh southland_front_30m     # output in runs/southland_front_30m/
```

and plot it with `RUN_NAME = "southland_front_30m"` and
`RUN_DIR_OVERRIDE = None`.

## The designer (`cable_designer.ipynb`)

The designer is an ipywidgets app with six tabs:

| Tab | What you do there |
|---|---|
| **Setup & projects** | check the repository and solver paths, build the solvers, load a template (any case in `cases/`, or a blank mooring), a saved project or a `.cbl` file, and save projects. **Convert CBL → project JSON** turns a `.cbl` into an editable project |
| **Parts** | create, duplicate and edit materials, connectors, buoys and anchors. Parts are read from `cases/` and the GUI databases in `gui/database/`; your own are saved to `notebook_projects/parts.json` |
| **Mooring** | choose the anchor and buoy, and add segments, connectors and attached instruments or floats from the anchor up |
| **Forcing & solver** | depth, current profile and modulation, and the waves: a **regular wave** (height and period) or a **random sea** from a wave file. *Generate a JONSWAP wave file* writes files for given Hs, Tp, γ, repeat period, number of components and random-phase seeds; *Preview / check wave file* plots the spectrum and the sea surface Cable will apply. Also run length, time step and solver settings |
| **Run & results** | check the input syntax, then run `cable-free` (or stock `cable`), static only or dynamic, with or without `-auto`. The run is converted to `.mat` and its static shape, buoy height and tension are plotted |
| **CABLE input** | the generated `.cbl` text. Tick raw mode to edit it by hand (for syntax the forms don't cover) |

The form builder handles 2D single-anchor surface and subsurface moorings;
anything else can still be run through raw mode.

Where things are saved (none of these are tracked by git):

- `notebook_projects/<case>/`: a saved project, with `project.json`, the
  generated `<case>.cbl` and, for a random sea, its wave file
- `notebook_projects/waves/`: wave files made by the JONSWAP generator, each
  with a `.json` sidecar recording its settings
- `runs/<case>_<timestamp>/`: one folder per run, holding the `.cbl` that was
  run, its wave file, `project.json`, `run.json` (the command), the solver
  log, Cable's `.cab` output and the converted `.mat`

## The plotter (`plot_run.ipynb`)

Set `RUN_NAME` (the case name, without the timestamp) and `RUN_DIR_OVERRIDE`
(the run folder, or `None` for `runs/<RUN_NAME>/` as written by
`scripts/run_case.sh`) in the Settings cell and run all cells. It reads the
`.mat` and `.cbl` in the run folder and gives:

- a summary: when and for how long the buoy was fully submerged, how deep its
  top went below the local surface, the maximum tensions, and an anchor mass
  estimate from the seabed friction coefficient, safety factor and anchor
  density set in the Settings cell
- the surface current, buoy height and tension through time
- the mooring shape: static, snapshots through the run, and at the buoy's
  deepest point
- the static, maximum and minimum tension along the line
- an MP4 animation of the mooring with the line coloured by tension, saved in
  the run folder as `<RUN_NAME>_animation.mp4`

The sea surface is rebuilt from the `.cbl` the way Cable computes it: from
the `x-wave` components for a regular wave, and from the wave file (with
`notebooks/jonswap_surface.py`) for a random sea. Both the designer and
`run_case.sh` copy the wave file into the run folder, so `JONSWAP_DIR = None`
is right unless you've moved it.

## What's in the repository

| Folder | Contents |
|---|---|
| `cli/`, `model/`, `solver/`, `include/`, `results/`, `gui/`, `widgets/`, `examples/` | upstream WHOI Cable source, unchanged (`examples/` holds Cable's own example inputs) |
| `patches/` | `cable-free-surface-buoy.patch` and `cable-wave-stretching.patch` (the changes that make `cable-free`, applied in that order) and `gui-modern-ffmpeg.patch` (for the optional GUI) |
| `scripts/` | `setup_env.sh` (one-off: conda environment and Jupyter kernel), `build.sh` (build both programs), `run_case.sh` (run a case from `cases/`), `setup_gui.sh` and `build_gui.sh` (the optional GUI) |
| `cases/` | example input files (`.cbl`) for `cable-free`, and the JONSWAP wave file used by `slb600_jonswap` |
| `notebooks/` | `cable_designer.ipynb`, `plot_run.ipynb`, and `jonswap_surface.py` (rebuilds a wave file's sea surface; used by both) |
| `environment.yml` | the `whoi-cable` conda environment: compilers and build tools, Python packages, `ipykernel`, `ipywidgets` and `ffmpeg` (conda-forge only) |
| `docs/` | upstream Cable manuals (`WHOI_Cable_manual-2.0.pdf`, `cable_manual.html`), plus `SETUP.md` (setup and use), `PATCH.md` (the free-floating buoy patch: changes, justification, limitations), `STRETCHING.md` (the wave stretching patch) and `GUI.md` (the optional GUI) |

`build/`, `runs/` and `notebook_projects/` are created by the scripts and
notebooks and are not tracked by git. Before committing changes to a notebook,
clear its outputs (**Edit → Clear Outputs of All Cells** in Jupyter Lab, then
save) so embedded figures and videos don't bloat the repository, and check the
Settings cells hold no personal paths.

## Example cases

Each `.cbl` file starts with a comment block describing the mooring, the
conditions and the assumptions behind it. All of them appear as templates in
the designer, and all run with `scripts/run_case.sh <case>`.

| Case | Mooring and conditions | Run time* |
|---|---|---|
| `southland_front_30m` | Polyform LD-1 buoy (13 kg) on 40 m of 12 mm polypropylene in 30 m; 2 m, 8 s waves; current 0.7 m/s at the surface to 0.1 m/s at the bed | 20 s |
| `southland_front` | LD-1 buoy on 130 m of polypropylene in 110 m; same waves and current | 50 s |
| `southland_front_invcat` | inverse-catenary version: LD-1, 3 kg downweight, 5 kg subsurface float, polypropylene and chain in 110 m; 0.5 m/s current | 80 s |
| `slb600_waves` | Sealite SL-B600 marker buoy on chain, polypropylene and chain in 40 m; 2 m, 8 s waves; 0.5 m/s | 15 s |
| `slb600_jonswap` | the `slb600_waves` mooring in a JONSWAP sea, Hs 2 m, Tp 8 s, γ 3.3 (wave file `jonswap_hs2_tp8_s1.dat`, seed 1); 0.5 m/s | 1 min |
| `slb600_pulldown` | SL-B600 mooring with the current ramped 0.2 → 2 → 0.2 m/s; buoy pulled under and resurfacing | 35 s |
| `swex_pulldown` | Cable's SWEX example mooring with the current ramped 1 → 4.5 → 1 m/s | 25 s |
| `swex_free` | SWEX mooring in 2 m, 8 s waves | 15 s |
| `stretching_demo` | SL-B600 on 66 m of chain and sinking polyester in 30 m (slack); 3 m, 12 s waves, no current. Run with and without `CABLE_STRETCHING=none` to see the up-wave drift that stretching removes | 1 min |
| `wirewalker_southland` | Wirewalker profiler mooring in 100 m, translated from a ProteusDS Designer template | 2.5 min |

\* on a typical laptop core; yours will differ.

Component properties in these cases (buoy shapes, rope stiffness, drag
coefficients) are typical or estimated values, not manufacturer data. Check
them before relying on a result.

## Notes for writing your own cases

These apply whether you use the designer's forms, its raw mode, or edit a
`.cbl` by hand.

- Use `type = surface` and `forcing-method = morison`, or the patch has no effect.
- **Static start.** If the buoy might start submerged, use
  `static-initial-guess = catenary` and `static-solution = relaxation` and run
  **without** `-auto` (the designer's default). If the buoy starts at the
  surface and the static solve fails, try `-auto`. Note that
  `scripts/run_case.sh` always adds `-auto`.
- If the log says the static solve "never converged", raise
  `static-outer-iterations` (1000 works for the cases here).
- Light buoys on near-taut lines may need a small `time-step` (0.005 s for the
  LD-1 cases).
- Set `ramp-time` to a whole number of wave periods (peak periods for a random sea).
- For a time-varying current, put `x-current-modulation` before `x-current`
  and write it as an expression in `t` or as `(time, factor)` pairs. A plain
  constant crashes Cable.
- **Random seas.** Use `input-type = random` with `wave-file = "<file>"`, and
  keep an `x-wave` line: with a wave file it only switches waves on, and the
  spectrum and phases come from the file. A wave file has one line per
  component, `omega S(omega) phase` (rad/s, m² s/rad, rad), with evenly spaced
  `omega`, no header and at most 999 lines. Cable reads the first line before
  it knows the spacing, so the designer's files start with a zero-energy line.
  A relative path is read from the folder Cable runs in: keep the file beside
  the `.cbl` in `cases/` and `run_case.sh` copies it into the run folder.
- **Seeds and repeat period.** Different seeds give different realisations of
  the same sea, so compare statistics (e.g. peak tension) across several seeds
  rather than single time series. The sea repeats every repeat period, so keep
  the run after the ramp shorter than that, or later statistics just repeat
  earlier ones.

## The graphical interface (optional)

Cable's original GUI, `wcable`, can also be built and run under WSL, as a
stock version (`wcable`) and one with the buoy patch (`wcable-free`). It uses
Ubuntu's GTK 2 packages rather than the conda environment. The notebook
designer is the recommended way to build and run moorings; see
[docs/GUI.md](docs/GUI.md) if you want the original GUI too:

```bash
scripts/setup_gui.sh      # once; installs system libraries (needs sudo)
scripts/build_gui.sh
wcable-free cases/slb600_waves.cbl &
```

## Credit and licence

WHOI Cable is copyright Woods Hole Oceanographic Institution, Jason Gobat,
and (for parts of the input parser) Jason Gobat and Darren Atkinson, as
stated in the source files. It is distributed under the GNU General Public
License v3 (see `COPYING`). The patch, scripts, cases and notebooks in this
repository are distributed under the same licence.

If you use WHOI Cable in published work, cite the Cable manual and
Gobat & Grosenbaugh's papers (listed in [docs/PATCH.md](docs/PATCH.md)), and
say that the free-floating surface buoy patch was used.

See NOTICE for the original copyright holders and a dated list of the modifications.
