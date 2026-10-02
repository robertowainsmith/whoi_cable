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
if [ -z "${CC:-}" ]; then
    echo "The environment's C compiler isn't set up (CC is empty)." >&2
    echo "Try:  conda deactivate && conda activate $ENV_NAME" >&2
    exit 1
fi
PREFIX="${PREFIX:-$CONDA_PREFIX/bin}"
AR_CMD="${AR:-ar}"
RANLIB_CMD="${RANLIB:-ranlib}"

for tool in "$CC" "$AR_CMD" "$RANLIB_CMD" make flex bison patch; do
    command -v "$tool" >/dev/null || {
        echo "Missing '$tool' in the $ENV_NAME environment. Run scripts/setup_env.sh." >&2; exit 1; }
done

# Conda's compiler doesn't search the environment for headers and libraries by
# default, and Cable's Makefiles set their own CFLAGS, so the environment's
# include and lib folders go on the compiler command. The rpath lets the
# programs find the environment's zlib when they run.
CC_CMD="$CC -isystem $CONDA_PREFIX/include -L$CONDA_PREFIX/lib -Wl,-rpath,$CONDA_PREFIX/lib"

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
