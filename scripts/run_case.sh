#!/usr/bin/env bash
# Run one of the cases in cases/ with cable-free and convert the output for the notebook.
#
#   scripts/run_case.sh <case> [extra cable options]
#   e.g. scripts/run_case.sh southland_front_30m
#        scripts/run_case.sh swex_free -auto
#
# Results go in runs/<case>/: a copy of the .cbl, <case>.cab (Cable output),
# <case>.mat (read by the notebook) and <case>.log (solver messages).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ $# -lt 1 ]; then
    echo "Usage: $0 <case> [extra cable options]"
    echo "Cases:"; ls "$REPO/cases" | sed -n 's/\.cbl$//p' | sed 's/^/  /'
    exit 1
fi
CASE="$(basename "${1%.cbl}")"; shift
SRC="$REPO/cases/$CASE.cbl"
[ -f "$SRC" ] || { echo "No such case: $SRC" >&2; exit 1; }

# use the programs from build/ if present, otherwise from PATH
CABLE="$REPO/build/free/cli/cable"
[ -x "$CABLE" ] || CABLE="$(command -v cable-free || true)"
RES2MAT="$REPO/build/stock/cli/res2mat"
[ -x "$RES2MAT" ] || RES2MAT="$(command -v res2mat || true)"
[ -n "$CABLE" ] && [ -n "$RES2MAT" ] || { echo "cable-free not found. Run: conda activate whoi-cable; scripts/build.sh" >&2; exit 1; }

OUT="$REPO/runs/$CASE"
mkdir -p "$OUT"
cp "$SRC" "$OUT/"
cd "$OUT"

echo "Running $CASE with $CABLE $* ..."
start=$(date +%s)
if ! "$CABLE" -in "$CASE.cbl" -out "$CASE.cab" -terminals -sample 0.1 -snap_dt 0.2 -quiet "$@" > "$CASE.log" 2>&1; then
    echo "cable-free failed; last lines of $OUT/$CASE.log:" >&2
    tail -5 "$CASE.log" >&2
    exit 1
fi
if grep -qi "never converged\|could not get static" "$CASE.log"; then
    echo "WARNING: the static solve did not converge (see $CASE.log)." >&2
    echo "         Raise static-outer-iterations, or add -auto if the buoy starts at the surface." >&2
fi
"$RES2MAT" -in "$CASE.cab" -out "$CASE.mat" -totals > /dev/null
echo "Done in $(( $(date +%s) - start )) s. Output in $OUT"
