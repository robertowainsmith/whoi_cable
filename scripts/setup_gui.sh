#!/usr/bin/env bash
# One-off setup for the WHOI Cable GUI (wcable) on Ubuntu / WSL. Installs, from
# Ubuntu's own packages, the system libraries the GUI needs:
#   GTK 2 (the GUI toolkit), FFmpeg's libraries (for saving movies),
#   the tools to build the GtkExtra plotting library from source, and fonts.
# Needs sudo. Safe to run more than once.
#
# The GUI is built against Ubuntu's GTK rather than the whoi-cable conda
# environment; see docs/GUI.md for why.
set -euo pipefail

echo "Installing the GUI's system packages (you may be asked for your password)..."
sudo apt-get update
sudo apt-get install -y \
    build-essential flex bison zlib1g-dev pkg-config git \
    libgtk2.0-dev libavcodec-dev libavutil-dev \
    autoconf automake libtool gtk-doc-tools \
    fonts-dejavu-core x11-apps

echo
echo "Done. Check that Windows can show Linux windows by running:  xeyes"
echo "(a pair of eyes should appear; close it), then build the GUI with:"
echo "  conda deactivate      # repeat until no environment is active"
echo "  scripts/build_gui.sh"
