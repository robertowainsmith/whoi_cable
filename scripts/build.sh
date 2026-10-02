#!/usr/bin/env bash
# Build stock WHOI Cable and the patched free-floating-buoy version (cable-free)
# with the compilers in the "whoi-cable" conda environment, and install the
# programs into that environment, so they're available whenever it is active:
#   cable             stock WHOI Cable
#   cable-free        with patches/cable-free-surface-buoy.patch applied
#   res2mat, res2asc  output converters (unchanged by the patch)
#
#   conda activate whoi-cable
#   scripts/build.sh
#
# The repository's own source is never modified: each variant is built in a
# copy under build/. Set PREFIX to install somewhere else.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$REPO/build"
PATCH="$REPO/patches/cable-free-surface-buoy.patch"
ENV_NAME="whoi-cable"

if [ "${CONDA_DEFAULT_ENV:-}" != "$ENV_NAME" ] || [ -z "${CONDA_PREFIX:-}" ]; then
    echo "Activate the conda environment first:  conda activate $ENV_NAME" >&2
    echo "(If it doesn't exist yet, run scripts/setup_env.sh.)" >&2
    exit 1
fi
PREFIX="${PREFIX:-$CONDA_PREFIX/bin}"
ENV_BIN="$CONDA_PREFIX/bin"

# --- find the C compiler -----------------------------------------------------
# Normally activating the environment sets CC to conda's compiler. If it
# hasn't (CC empty, or pointing at something that doesn't exist), look for the
# compiler in the environment itself, and only as a last resort use the system
# compiler.
find_cc () {
    if [ -n "${CC:-}" ] && command -v "$CC" >/dev/null; then
        echo "$CC"; return
    fi
    local c
    for c in "$ENV_BIN"/*-conda-linux-gnu-cc "$ENV_BIN"/*-conda-linux-gnu-gcc \
             "$ENV_BIN"/gcc "$ENV_BIN"/cc; do
        [ -x "$c" ] && { echo "$c"; return; }
    done
    for c in gcc cc; do
        command -v "$c" >/dev/null && { echo "SYSTEM:$(command -v "$c")"; return; }
    done
}
CC_FOUND="$(find_cc || true)"
if [ -z "$CC_FOUND" ]; then
    echo "No C compiler found in the $ENV_NAME environment (or on the system)." >&2
    echo "The environment is probably incomplete. Recreate it:" >&2
    echo "  conda deactivate; conda env remove -n $ENV_NAME -y; conda clean --all -y" >&2
    echo "  scripts/setup_env.sh; conda activate $ENV_NAME; scripts/build.sh" >&2
    exit 1
fi
if [ "${CC_FOUND#SYSTEM:}" != "$CC_FOUND" ]; then
    CC_FOUND="${CC_FOUND#SYSTEM:}"
    echo "Warning: no compiler found in the $ENV_NAME environment; using the system's $CC_FOUND." >&2
    echo "         Rerun scripts/setup_env.sh to install conda's compiler." >&2
fi
if [ "${CC:-}" != "$CC_FOUND" ]; then
    echo "Using C compiler: $CC_FOUND"
fi

# --- find ar and ranlib to match ---------------------------------------------
# conda names them like the compiler (e.g. x86_64-conda-linux-gnu-ar)
find_tool () {   # $1 = current value (AR or RANLIB), $2 = tool name
    if [ -n "$1" ] && command -v "${1%% *}" >/dev/null; then echo "$1"; return; fi
    local base prefix
    base="$(basename "$CC_FOUND")"
    case "$base" in
        *-cc)  prefix="${base%cc}" ;;
        *-gcc) prefix="${base%gcc}" ;;
        *)     prefix="" ;;
    esac
    if [ -n "$prefix" ] && [ -x "$ENV_BIN/$prefix$2" ]; then echo "$ENV_BIN/$prefix$2"; return; fi
    if [ -x "$ENV_BIN/$2" ]; then echo "$ENV_BIN/$2"; return; fi
    command -v "$2" || true
}
AR_CMD="$(find_tool "${AR:-}" ar)"
RANLIB_CMD="$(find_tool "${RANLIB:-}" ranlib)"

for tool in "$CC_FOUND" "$AR_CMD" "$RANLIB_CMD" make flex bison patch; do
    { [ -n "$tool" ] && command -v "$tool" >/dev/null; } || {
        echo "Missing '${tool:-ar/ranlib}' in the $ENV_NAME environment. Run scripts/setup_env.sh." >&2; exit 1; }
done

# Cable is written in older C. GCC 15 and later default to the C23 standard,
# under which some of its declarations are errors, so ask for C17 (with GNU
# extensions). Conda's compiler also doesn't search the environment for headers
# and libraries by default, and Cable's Makefiles set their own CFLAGS, so the
# environment's include and lib folders go on the compiler command. The rpath
# lets the programs find the environment's zlib when they run.
CC_CMD="$CC_FOUND -std=gnu17 -isystem $CONDA_PREFIX/include -L$CONDA_PREFIX/lib -Wl,-rpath,$CONDA_PREFIX/lib"

run_make () {   # $1 = build folder, $2 = compiler command
    (cd "$1" && make OS=nox CC="$2" LD="$2" AR="$AR_CMD cq" RANLIB="$RANLIB_CMD" \
                     LDFLAGS="-g" CPPFLAGS="" >> "$1/build.log" 2>&1)
}

build_variant () {
    local name="$1" dir="$BUILD/$1"
    echo "=== Building $name in $dir"
    rm -rf "$dir"; mkdir -p "$dir"
    # copy the source tree, leaving out build products, runs and git metadata
    (cd "$REPO" && tar cf - --exclude=./build --exclude=./runs --exclude=./.git .) | (cd "$dir" && tar xf -)
    if [ "$name" = free ]; then
        (cd "$dir" && patch -p1 --quiet < "$PATCH")
        echo "    applied $(basename "$PATCH")"
    fi
    # Cable links its command-line programs statically; conda provides shared
    # libraries, so link them dynamically instead (in this build copy only)
    sed -i 's/-static //g' "$dir/cli/Makefile"
    : > "$dir/build.log"
    # newer GCC versions reject some of Cable's older C; retry with -fpermissive
    if ! run_make "$dir" "$CC_CMD"; then
        echo "    first build attempt failed; retrying with -fpermissive"
        run_make "$dir" "$CC_CMD -fpermissive" || {
            echo "Build of $name failed; see $dir/build.log" >&2; exit 1; }
    fi
    for prog in cable res2mat res2asc; do
        [ -x "$dir/cli/$prog" ] || { echo "Build of $name did not produce cli/$prog; see $dir/build.log" >&2; exit 1; }
    done
    echo "    ok"
}

build_variant stock
build_variant free

mkdir -p "$PREFIX"
install -m 755 "$BUILD/stock/cli/cable"   "$PREFIX/cable"
install -m 755 "$BUILD/free/cli/cable"    "$PREFIX/cable-free"
install -m 755 "$BUILD/stock/cli/res2mat" "$PREFIX/res2mat"
install -m 755 "$BUILD/stock/cli/res2asc" "$PREFIX/res2asc"

echo
echo "Installed to $PREFIX: cable, cable-free, res2mat, res2asc"
echo "They're available whenever the $ENV_NAME environment is active."
