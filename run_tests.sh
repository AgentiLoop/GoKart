#!/bin/zsh
# Runs GoKart unit tests headless. Exit code 1 on failure.
cd "$(dirname "$0")" && godot --headless --path . -s tests/test_runner.gd
