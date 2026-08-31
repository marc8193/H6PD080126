#!/bin/bash
set -eu
cd "$(dirname "$0")"

# --- Unpack Arguments ------------------------------------------------------------------------------
for argument in "$@";
do declare $argument="1";
done

if [[ "$#" == "0" ]]; then
  main="1";
fi

# --- Prep Directories ------------------------------------------------------------------------------
mkdir -p build

# --- Build -----------------------------------------------------------------------------------------
cd build
if [[ "${main:-0}" == "1" ]]; then
  did_build=1;
fi
if [[ "${docs:-0}" == "1" ]]; then
  did_build=1 && plantuml -tpng ../documentation/*.puml;
fi
cd ..

# --- Warn On No Builds -----------------------------------------------------------------------------
if [[ "${did_build:-0}" == "0" ]]; then
    echo "[WARNING] no valid build target specified; must use build target names as arguments \
         to this script, like \`./build.sh release main\` or \`./build.sh docs\`."
  exit 1
fi
