#!/bin/bash
set -eu
cd "$(dirname "$0")"

# --- Unpack Arguments ------------------------------------------------------------------------------
for argument in "$@";
do declare $argument="1";
done

if [[ "$#" == "0" ]]; then
  all="1";
fi

# --- Prep Directories ------------------------------------------------------------------------------
mkdir -p deploy

# --- Deploy -----------------------------------------------------------------------------------------
cd deploy
if [[ "${all:-0}" == "1" || "${client:-0}" == "1" ]]; then
  did_build=1 && \
    elm make ../source/client/Main.elm --output=main.js && \
    cp -R ../source/client/index.html \
      ../source/client/static.css \
      ../source/server.py \
      ../asset/font \
      ../asset/background.jpg .
fi
if [[ "${all:-0}" == "1" || "${docs:-0}" == "1" ]]; then
  did_build=1 && plantuml -tpng ../documentation/*.puml -o ../asset;
fi
if [[ "${all:-0}" == "1" || "${test:-0}" == "1" ]]; then
  did_build=1 && cd ../source && python -m unittest test_server.py && cd ../deploy
fi
cd ..

# --- Warn On No Builds -----------------------------------------------------------------------------
if [[ "${did_build:-0}" == "0" ]]; then
  echo "[WARNING] no valid build target specified; must use build target names as arguments \
       to this script, like \`./build.sh all\`, \`./build.sh client\` or \`./build.sh docs\`."
  exit 1
fi