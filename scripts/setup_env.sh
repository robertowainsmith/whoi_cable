#!/usr/bin/env bash
# One-off setup: create (or update) the "whoi-cable" conda environment from
# environment.yml, and register it as a Jupyter kernel called
# "Python (whoi-cable)" so your existing Jupyter can run the notebook in it.
# Safe to run more than once. Needs conda (e.g. Miniconda) installed in WSL.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_NAME="whoi-cable"

if ! command -v conda >/dev/null; then
    echo "conda not found. Install Miniconda inside WSL first (docs/SETUP.md, step 2)," >&2
    echo "then open a new terminal and run this script again." >&2
    exit 1
fi

if conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
    echo "Updating the existing '$ENV_NAME' environment from environment.yml ..."
    conda env update -n "$ENV_NAME" -f "$REPO/environment.yml" --prune
else
    echo "Creating the '$ENV_NAME' environment from environment.yml (this takes a few minutes) ..."
    conda env create -f "$REPO/environment.yml"
fi

echo
echo "Registering the Jupyter kernel 'Python ($ENV_NAME)' ..."
conda run -n "$ENV_NAME" python -m ipykernel install --user \
      --name "$ENV_NAME" --display-name "Python ($ENV_NAME)"

echo
echo "Setup done. Next:"
echo "  conda activate $ENV_NAME"
echo "  scripts/build.sh"
