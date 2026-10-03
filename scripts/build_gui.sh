#!/usr/bin/env bash
# Build the WHOI Cable GUI, in two versions, and install them to ~/.local/bin:
#   wcable        the GUI with stock WHOI Cable
#   wcable-free   the GUI with the free-floating surface buoy patch
#
#   scripts/setup_gui.sh      # once, installs the system libraries (needs sudo)
#   scripts/build_gui.sh
#
# The GUI needs GtkExtra, a GTK 2 plotting library that current Ubuntu no
# longer packages. This script builds GtkExtra 3.0.2 from source (once) and
# installs it under ~/.local/share/whoi-cable-gui. Cable's GUI was written for
# GtkExtra 2.1 and an old FFmpeg; patches/gui-modern-ffmpeg.patch updates its
# movie export for current FFmpeg. The repository's own source is never
# modified: each version is built in a copy under build/.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$REPO/build"
GUI_HOME="${GUI_HOME:-$HOME/.local/share/whoi-cable-gui}"   # GtkExtra goes here
BIN="${BIN:-$HOME/.local/bin}"                               # wcable goes here
GTKEXTRA_REPO="https://github.com/2tim/gtkextra.git"
GTKEXTRA_COMMIT="3c88c7a7364edc98fb3e62b1490f8d63a5f0d6c4"   # GtkExtra 3.0.2

# Use the system's compiler and tools, not a conda environment's, because the
# GUI is built against Ubuntu's GTK libraries.
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
unset CC CXX CFLAGS CPPFLAGS CXXFLAGS LDFLAGS AR RANLIB LD
export PKG_CONFIG_PATH="$GUI_HOME/lib/pkgconfig"

missing=""
for tool in gcc make flex bison patch git pkg-config autoreconf libtoolize gtkdocize; do
    command -v "$tool" >/dev/null || missing="$missing $tool"
done
for lib in gtk+-2.0 libavcodec libavutil zlib; do
    pkg-config --exists "$lib" || missing="$missing $lib"
done
if [ -n "$missing" ]; then
    echo "Missing:$missing" >&2
    echo "Run scripts/setup_gui.sh first." >&2
    exit 1
fi

mkdir -p "$BUILD"

# --- GtkExtra 3.0.2 (once) -----------------------------------------------------
if [ ! -f "$GUI_HOME/lib/pkgconfig/gtkextra-3.0.pc" ]; then
    src="$BUILD/gtkextra-src"
    log="$BUILD/gtkextra.log"
    echo "=== Building GtkExtra 3.0.2 (once; log in $log)"
    rm -rf "$src"
    git clone -q "$GTKEXTRA_REPO" "$src" > "$log" 2>&1
    (
        cd "$src"
        git checkout -q "$GTKEXTRA_COMMIT"
        # configure.in declares its macro folder twice, which newer autoconf rejects
        awk '/AC_CONFIG_MACRO_DIR/ { if (seen++) next } { print }' configure.in > configure.in.new
        mv configure.in.new configure.in
        NOCONFIGURE=1 ./autogen.sh
        # -fgnu89-inline: the library relies on old-style inline functions
        ./configure --prefix="$GUI_HOME" --disable-gtk-doc --enable-introspection=no \
                    CFLAGS="-O2 -fgnu89-inline"
        # build and install just the library, headers and pkg-config file
        # (the full "make" also tries to build optional extras that fail)
        make -C gtkextra libgtkextra-x11-3.0.la
        make -C gtkextra install-libLTLIBRARIES install-gtkextraincludeHEADERS
        make install-pkgconfigDATA
    ) >> "$log" 2>&1 || { echo "GtkExtra build failed; see $log" >&2; exit 1; }
    echo "    ok, installed in $GUI_HOME"
fi

GTK_CFLAGS="$(pkg-config --cflags gtk+-2.0 gtkextra-3.0)"
GTK_LIBS="-lz $(pkg-config --libs gtk+-2.0 gtkextra-3.0) -Wl,-rpath,$GUI_HOME/lib"
# Cable's older C needs C17 (GCC 15 defaults to C23) and -fpermissive (GCC 14+)
GUI_CC="gcc -std=gnu17 -fpermissive"

# --- the GUI, stock and patched ------------------------------------------------
build_gui () {
    local name="$1" dir="$BUILD/gui-$1"
    echo "=== Building the GUI ($name) in $dir"
    rm -rf "$dir"; mkdir -p "$dir"
    (cd "$REPO" && tar cf - --exclude=./build --exclude=./runs --exclude=./.git .) | (cd "$dir" && tar xf -)
    (cd "$dir" && patch -p1 --quiet < "$REPO/patches/gui-modern-ffmpeg.patch")
    if [ "$name" = free ]; then
        (cd "$dir" && patch -p1 --quiet < "$REPO/patches/cable-free-surface-buoy.patch")
        echo "    applied cable-free-surface-buoy.patch"
    fi
    : > "$dir/build.log"
    for sub in solver model results gui; do
        (cd "$dir/$sub" && make CC="$GUI_CC" GTK_CFLAGS="$GTK_CFLAGS" GTK_LIBS="$GTK_LIBS" \
                             >> "$dir/build.log" 2>&1) || {
            echo "Build failed in $sub; see $dir/build.log" >&2; exit 1; }
    done
    [ -x "$dir/gui/wcable" ] || { echo "No wcable produced; see $dir/build.log" >&2; exit 1; }
    echo "    ok"
}

build_gui stock
build_gui free

mkdir -p "$BIN"
install -m 755 "$BUILD/gui-stock/gui/wcable" "$BIN/wcable"
install -m 755 "$BUILD/gui-free/gui/wcable"  "$BIN/wcable-free"

# the GUI reads its component databases (materials, buoys, ...) from ~/.cable
mkdir -p "$HOME/.cable"
for f in "$REPO"/gui/database/*; do
    [ -e "$HOME/.cable/$(basename "$f")" ] || cp "$f" "$HOME/.cable/"
done
# The shipped prefs.ini was written for the old Windows installer and points the
# GUI at a Windows C preprocessor; use Linux's instead (and Unix line endings)
if [ -f "$HOME/.cable/prefs.ini" ] && grep -q '^cpp=.*\.exe' "$HOME/.cable/prefs.ini"; then
    sed -i -e 's/\r$//' -e 's|^cpp=.*|cpp=/usr/bin/cpp|' "$HOME/.cable/prefs.ini"
fi

echo
echo "Installed to $BIN: wcable, wcable-free"
if ! grep -q 'HOME/.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "Added ~/.local/bin to PATH in ~/.bashrc (open a new terminal or run: source ~/.bashrc)"
fi
echo "Start the GUI with:  wcable-free cases/slb600_waves.cbl   (or just: wcable-free)"
