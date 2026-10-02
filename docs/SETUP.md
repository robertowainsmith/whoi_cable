# Setting up and running cable-free on Windows (WSL + conda)

These steps go from a Windows machine to running the `southland_front_30m`
example and plotting it in a Jupyter notebook. They take about 15 minutes,
most of it waiting for downloads.

Everything runs inside WSL (Ubuntu), in one conda environment called
**`whoi-cable`**. That environment holds the C compiler and build tools,
Cable itself once built, and the Python packages the notebook uses. No `sudo`
or system packages are needed.

The guide assumes you already have **Jupyter Notebook** (or Jupyter Lab)
installed **inside WSL**, for example in your conda `base` environment. If
not, step 7 shows how to add it.

All commands below are typed in a **WSL (Ubuntu) terminal** unless a step says
otherwise.

## 1. Install WSL (once per computer)

If you already have an Ubuntu terminal on Windows, skip this step.

1. Open **PowerShell as Administrator** and run:
   ```powershell
   wsl --install
   ```
2. Restart when asked. Ubuntu then opens and asks you to choose a Linux user
   name and password.

Afterwards, open Ubuntu from the Start menu whenever you need a WSL terminal.

## 2. Install Miniconda inside WSL (once)

If `conda --version` already works in your WSL terminal, skip this step.
Conda installed on the Windows side doesn't count: it has to be inside WSL.

```bash
cd ~
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p ~/miniconda3
~/miniconda3/bin/conda init bash
rm Miniconda3-latest-Linux-x86_64.sh
```

Close the terminal and open a new one. The prompt should now start with
`(base)`, and `conda --version` should print a version number.

The `whoi-cable` environment takes all its packages from the community
**conda-forge** channel, not Anaconda's own "defaults" channel, so it isn't
affected by Anaconda's licence terms for that channel. If conda ever asks you
to accept Terms of Service for the defaults channel while creating it, see
Troubleshooting.

## 3. Get the code

Clone the repository into your **Linux home folder** (not `/mnt/c/...`).
Building and running inside the Linux file system is much faster, and avoids
Windows line-ending and permission problems.

```bash
git clone https://github.com/robertowainsmith/whoi_cable.git ~/whoi_cable
cd ~/whoi_cable
```

(Ubuntu on WSL includes `git`. If yours doesn't: `conda install -n base -c conda-forge git`.)

## 4. Create the environment (once)

```bash
scripts/setup_env.sh
```

This:

- creates the `whoi-cable` conda environment from `environment.yml`: the C
  compiler, `make`, `flex`, `bison`, `zlib` and `patch` for building Cable;
  Python with NumPy, SciPy and Matplotlib; `ipykernel`; and `ffmpeg` for
  saving animations. This takes a few minutes the first time.
- registers the environment as a Jupyter kernel called
  **Python (whoi-cable)**, so the Jupyter you already have can run the notebook
  in this environment.

It's safe to run again: if the environment exists, it's updated to match
`environment.yml`. If you get `Permission denied`, run `chmod +x scripts/*.sh`
and try again.

## 5. Build

From now on, activate the environment at the start of each session:

```bash
conda activate whoi-cable
scripts/build.sh
```

This builds two versions of Cable from the repository's source with the
environment's compiler, each in its own folder under `build/`, and installs
them into the environment:

- `cable`: stock WHOI Cable
- `cable-free`: Cable with the free-floating surface buoy patch
  (`patches/cable-free-surface-buoy.patch`)
- `res2mat`, `res2asc`: Cable's output converters

The repository's own source files are never modified. It takes a minute or
two and should end with:

```
Installed to /home/<you>/miniconda3/envs/whoi-cable/bin: cable, cable-free, res2mat, res2asc
They're available whenever the whoi-cable environment is active.
```

Check with `which cable cable-free res2mat`.

If the build fails, the full compiler output is in `build/stock/build.log` or
`build/free/build.log`. Newer compilers reject some of Cable's older C code;
the script detects this and retries automatically with `-fpermissive`.

## 6. Run the example

With `whoi-cable` active:

```bash
scripts/run_case.sh southland_front_30m
```

It takes about 20 seconds and should end with:

```
Done in 20 s. Output in /home/<you>/whoi_cable/runs/southland_front_30m
```

`runs/southland_front_30m/` then contains:

| File | What it is |
|---|---|
| `southland_front_30m.cbl` | a copy of the input file that was run |
| `southland_front_30m.cab` | Cable's output |
| `southland_front_30m.mat` | the output converted by `res2mat`; the notebook reads this |
| `southland_front_30m.log` | the solver's messages |

Run `scripts/run_case.sh` with no arguments to list all the example cases.
Extra Cable options go after the case name, for example
`scripts/run_case.sh swex_free -auto`.

## 7. Plot it in the notebook

Start your Jupyter from the repository folder, in whichever environment it's
installed in. For example, if it's in `base`, open a second terminal and run:

```bash
cd ~/whoi_cable
conda activate base
jupyter notebook --no-browser
```

(Use `jupyter lab --no-browser` if you prefer Jupyter Lab. If you don't have
Jupyter yet, install it once with `conda install -n base -c conda-forge notebook`.)

Jupyter prints a link starting `http://localhost:8888/...?token=...`.
**Ctrl+click** it, or copy it into a web browser on Windows. Leave that
terminal open while you work; **Ctrl+C** there stops Jupyter.

In the browser:

1. Open `notebooks/plot_run.ipynb`. It's set to use the **Python (whoi-cable)**
   kernel, shown in the top right. If Jupyter asks which kernel to use, or
   shows another one, choose **Kernel → Change Kernel → Python (whoi-cable)**.
2. Check `RUN_NAME = "southland_front_30m"` in the **Settings** cell.
3. Run all cells: **Run → Run All Cells** (Jupyter Lab) or
   **Cell → Run All** (classic Notebook).

The **Summary** cell should print:

```
Run "southland_front_30m": buoy "ld1" (axisymmetric), height 0.48 m, static draft 0.24 m
First fully submerged at t = 8.8 s (surface current 0.70 m/s)
Last  fully submerged at t = 210.0 s (surface current 0.70 m/s)
Time fully submerged: 113.1 s of 210.0 s
Deepest at t = 186.7 s: buoy top 1.16 m below the local surface
Max tension: 0.16 kN at buoy, 0.16 kN at anchor

Anchor: worst at t = 17.0 s (H = 0.12 kN, V = 0.10 kN), mu = 0.5, safety factor 1.5
        needs 0.52 kN in water = 61 kg of material with density 7850 kg/m^3
```

followed by three figures and two animations. The animations are saved as
`southland_front_30m_animation.mp4` and `southland_front_30m_tension.mp4` in
the run folder and shown in the notebook. Building them takes a few minutes for
a 210 s run; to make it faster, raise `FRAME_STEP` in the Settings cell (use
every n-th snapshot), or set `MAKE_ANIMATIONS = False`.

The anchor estimate uses the friction coefficient, safety factor and anchor
density set in the Settings cell.

**Opening the files from Windows.** To see the run folder (and the MP4s) in
Windows Explorer, run `explorer.exe .` in the WSL terminal from that folder.
The address bar shows the Windows path, something like
`\\wsl.localhost\Ubuntu\home\<you>\whoi_cable\runs\southland_front_30m`.

**Using VS Code instead of the browser.** Install VS Code on Windows with its
WSL extension, run `code .` in the repository folder, open
`notebooks/plot_run.ipynb`, and choose **Python (whoi-cable)** (or the
`whoi-cable` conda environment) as the kernel.

## 8. Running Cable by hand

The scripts are a convenience. With `whoi-cable` active, the equivalent
commands for any input file are:

```bash
cable-free -in mycase.cbl -out mycase.cab -terminals -sample 0.1 -snap_dt 0.2 -quiet > mycase.log
res2mat -in mycase.cab -out mycase.mat -totals
```

Use `cable` instead of `cable-free` for stock Cable. `-snap_dt` sets how often
whole-mooring snapshots are saved, which sets how smooth the animations are.
To plot a run made this way, put it in `runs/<name>/` (with its `.cbl`), or set
`RUN_DIR` directly in the notebook's Setup cell.

## 9. Making your own case

Copy an example, edit it, and run it by name:

```bash
cp cases/southland_front_30m.cbl cases/mycase.cbl
nano cases/mycase.cbl          # or edit it in VS Code: code cases/mycase.cbl
scripts/run_case.sh mycase
```

Then set `RUN_NAME = "mycase"` in the notebook. The notes in the main
`README.md` cover the input settings that matter for `cable-free`.

## 10. Updating

```bash
cd ~/whoi_cable
git pull
scripts/setup_env.sh          # only needed if environment.yml changed
conda activate whoi-cable
scripts/build.sh
```

## Removing everything

```bash
conda env remove -n whoi-cable
jupyter kernelspec uninstall whoi-cable    # run where your Jupyter is installed
rm -rf ~/whoi_cable
```

## Troubleshooting

| Problem | Fix |
|---|---|
| `conda: command not found` | Install Miniconda inside WSL (step 2), then open a new terminal |
| `Activate the conda environment first` | Run `conda activate whoi-cable`, then retry |
| conda asks you to accept Terms of Service for `repo.anaconda.com` channels | The environment itself only uses conda-forge. Accept with the `conda tos accept ...` command conda prints, or remove the defaults channel from your conda settings with `conda config --remove channels defaults` |
| `/usr/bin/env: 'bash\r': No such file or directory` | The scripts have Windows line endings, usually because the repository was cloned or edited on the Windows side. Clone it inside WSL (step 3), or run `sed -i 's/\r$//' scripts/*.sh cases/*.cbl` |
| `Permission denied` running a script | `chmod +x scripts/*.sh` |
| `The environment's C compiler isn't set up` | `conda deactivate`, then `conda activate whoi-cable` again. If it persists, rerun `scripts/setup_env.sh` |
| `cable-free: command not found` | Activate `whoi-cable`; if it's still missing, run `scripts/build.sh` |
| **Python (whoi-cable)** isn't in Jupyter's kernel list | Rerun `scripts/setup_env.sh`, then restart Jupyter. Jupyter must be running inside WSL: a Jupyter installed on Windows can't see WSL kernels |
| The notebook prints `Note: this kernel runs Python from ...` | It's using another kernel. Choose **Kernel → Change Kernel → Python (whoi-cable)** |
| `WARNING: the static solve did not converge` | Raise `static-outer-iterations` in the `.cbl`. If the buoy starts at the surface, try `-auto` |
| A run stops early or produces nonsense | Reduce `time-step` in the `.cbl` (light buoys on near-taut lines need 0.005 s) |
| The notebook can't find the `.mat` file | Check `RUN_NAME`, that the case was run with `scripts/run_case.sh`, or set `RUN_DIR` directly |
| `ffmpeg not found, so no video saved` | Rerun `scripts/setup_env.sh` to update the environment |
