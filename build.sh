#!/bin/bash
set -eu

project_root="$(cd "$(dirname "$0")" && pwd)"
cd "$project_root"

# --- Unpack Arguments -----------------------------------------------------------------------------
for argument in "$@"; do
  declare "$argument=1"
done

if [[ "$#" == "0" ]]; then
  all="1"
fi

# --- Prep Directories -----------------------------------------------------------------------------
mkdir -p build

# --- Build ----------------------------------------------------------------------------------------
if [[ "${all:-0}" == "1" || "${client:-0}" == "1" ]]; then
  did_build=1 && {
    mkdir -p "$project_root/build/deploy"
    cd "$project_root/build/deploy"

    elm make "$project_root/source/client/Main.elm" --output=main.js

    cp -R \
      "$project_root/source/client/index.html" \
      "$project_root/source/client/static.css" \
      "$project_root/source/server.py" \
      "$project_root/asset/font" \
      "$project_root/asset/background.jpg" .
  }
fi

if [[ "${all:-0}" == "1" || "${docs:-0}" == "1" ]]; then
  did_build=1 && {
    cd "$project_root/build"

    plantuml -tpng "$project_root"/documentation/*.puml -o "$project_root/build"

    export TEXINPUTS="$project_root/documentation:"

    report_files=("process-report" "product-report")
    for file in "${report_files[@]}"; do
      pdflatex -interaction=nonstopmode "$project_root/documentation/$file.tex"
      biber "$file"
      pdflatex -interaction=nonstopmode "$project_root/documentation/$file.tex"
      pdflatex -interaction=nonstopmode "$project_root/documentation/$file.tex"
    done
  }
fi

if [[ "${all:-0}" == "1" || "${test:-0}" == "1" ]]; then
  did_build=1 && {
    cd "$project_root/source"
    python -m unittest test_server.py
  }
fi

cd "$project_root"

# --- Warn On No Builds ----------------------------------------------------------------------------
if [[ "${did_build:-0}" == "0" ]]; then
  echo "[WARNING] no valid build target specified; must use build target names as arguments \
       to this script, like \`./build.sh all\`, \`./build.sh client\` or \`./build.sh docs\`."
  exit 1
fi