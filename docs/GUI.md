# Running the WHOI Cable GUI on Windows (WSL)

WHOI Cable includes a graphical program, `wcable`, for building a mooring from
component databases, solving it, and plotting and animating the results. It is
a Linux (GTK 2) program, but Windows can display Linux programs run inside WSL,
so it works there like a normal Windows app.

The scripts here build two versions:

| Program | What it is |
|---|---|
| `wcable` | the GUI with stock WHOI Cable |
| `wcable-free` | the GUI with the free-floating surface buoy patch (`patches/cable-free-surface-buoy.patch`) |

## How this differs from the rest of the repository

- **It uses Ubuntu's packages, not the conda environment.** The GUI needs GTK 2
  and FFmpeg's libraries, installed with `apt` (so `sudo` is needed once). The
  GUI build ignores any active conda environment.
- **It uses a newer plotting library than Cable was written for.** The GUI
  needs GtkExtra, a GTK 2 plotting library that Ubuntu no longer packages.
  Cable was written for GtkExtra 2.1, which is only available from SourceForge;
  the build script instead builds its successor, GtkExtra 3.0.2, from a copy on
  GitHub. Cable's GUI compiles and plots with it unchanged.
- **The movie export is patched for current FFmpeg.** The original code used
  FFmpeg functions removed years ago. `patches/gui-modern-ffmpeg.patch` ports it
  to the current interface; it still writes MPEG-1 video.

These were tested on Ubuntu 24.04 using a virtual display: the GUI opened the
example cases, solved them, and showed the results table and plots, and the
ported movie writer produced valid MPEG-1 video. They have not been tested on
a real Windows display, so tell the repository's maintainer if something looks
wrong.

## 1. Check Windows can show Linux programs

This needs **Windows 11**, or **Windows 10 version 21H2 or later** with WSL
installed from the Microsoft Store. In **PowerShell**, update WSL and restart it:

```powershell
wsl --update
wsl --shutdown
```

Then open your Ubuntu terminal again.

## 2. Install the system packages (once)

From the repository folder (`~/whoi_cable`):

```bash
scripts/setup_gui.sh
```

This asks for your Linux password and installs GTK 2, FFmpeg's libraries, the
tools to build GtkExtra, fonts, and some small test programs. Then check that
Linux windows appear on your Windows desktop:

```bash
xeyes
```

A small window with a pair of eyes should open. Close it to continue. If
nothing appears, see Troubleshooting.

## 3. Build the GUI

```bash
scripts/build_gui.sh
```

The first time, this builds GtkExtra (about a minute) and installs it in
`~/.local/share/whoi-cable-gui`. It then builds both versions of the GUI and
installs them as `~/.local/bin/wcable` and `~/.local/bin/wcable-free`. It ends
with:

```
Installed to /home/<you>/.local/bin: wcable, wcable-free
```

If it says it added `~/.local/bin` to your PATH, run `source ~/.bashrc` (or
open a new terminal) before the next step.

It also copies Cable's component databases (materials, buoys, connectors,
anchors and current profiles) to `~/.cable`, where the GUI looks for them. Any
copies already there are left alone, so your own additions are kept.

## 4. Run it

```bash
wcable-free cases/slb600_waves.cbl &
```

The `&` gives you your terminal back while the GUI is open. Use `wcable`
instead for stock Cable, or leave off the file name to start with an empty
model.

In the GUI:

- The **layout** tab shows the mooring from the buoy (terminal 2) down to the
  anchor (terminal 1), with the materials, buoys and anchors in their own tabs.
- **Model → Solve** runs the simulation. A window shows its progress.
- When it finishes, a dialog lets you choose results to show: a table, the
  mooring shape, and position and tension time series and snapshots.
- **Model → Results** reopens that dialog. **File → Save** and **Save As**
  save the model as a `.cbl` file.
- **File → Open Results** is meant for opening saved results. Whether it
  opens the `.cab` files that `scripts/run_case.sh` writes hasn't been tested.

`wcable-free` only changes the behaviour of surface moorings with the forcing
type set to **morison**; the notes in the main `README.md` apply in the GUI too.

**To analyse a GUI run in the notebook,** save the `.cbl` into `cases/` and run
it with `scripts/run_case.sh`, which writes the `.mat` file the notebook
reads.

## Troubleshooting

| Problem | Fix |
|---|---|
| `xeyes` or `wcable` says `cannot open display` | Windows isn't set up to show Linux programs. In PowerShell run `wsl --update` and `wsl --shutdown`, then reopen Ubuntu. `echo $DISPLAY` should print `:0` |
| `Missing: ...` from `build_gui.sh` | Run `scripts/setup_gui.sh` first |
| `GtkExtra build failed` | Look at the end of `build/gtkextra.log`. Delete `~/.local/share/whoi-cable-gui` and `build/gtkextra-src`, then run `scripts/build_gui.sh` again |
| `Build failed in gui` (or `solver`, `model`, `results`) | Look at the first `error:` line in `build/gui-stock/build.log` or `build/gui-free/build.log` |
| `database(1): Unable to open ~/.cable/material.db` | The databases are missing. Rerun `scripts/build_gui.sh`, or copy them: `mkdir -p ~/.cable && cp gui/database/* ~/.cable/` |
| `program c:\Program Files\Cable\cpp.exe does not exist, pre-processing disabled` | The GUI's settings still point to the old Windows preprocessor. Fix them with `sed -i -e 's/\r$//' -e 's|^cpp=.*|cpp=/usr/bin/cpp|' ~/.cable/prefs.ini` (newer versions of `build_gui.sh` do this for you) |
| `wcable: command not found` | Run `source ~/.bashrc`, or open a new terminal |
| The GUI is tiny or blurry on a high-resolution screen | Start it with scaling, e.g. `GDK_SCALE=2 wcable-free &` |
| Windows open off-screen or behind others | Use Alt+Tab, or the program's icon on the Windows taskbar |

## Removing the GUI

```bash
rm -f ~/.local/bin/wcable ~/.local/bin/wcable-free
rm -rf ~/.local/share/whoi-cable-gui
rm -rf build/gui-stock build/gui-free build/gtkextra-src build/gtkextra.log
rm -rf ~/.cable                  # only if you don't want to keep the component databases
```
