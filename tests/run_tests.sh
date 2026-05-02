#!/bin/bash

# GUT Test Runner for Godot 4.x
# Usage: Run tests headlessly with GUT framework

# Check for Godot executable
GODOT=""
if command -v godot4 &> /dev/null; then
    GODOT="godot4"
elif command -v godot &> /dev/null; then
    GODOT="godot"
else
    echo "Error: Godot executable not found in PATH"
    echo "Please install Godot 4.6 and add it to PATH"
    exit 1
fi

echo "Running GUT tests with $GODOT..."

# Run tests headlessly
# GUT needs to be installed as an addon in the project
# For now, use placeholder command that will work once GUT is installed

$GODOT --headless --quit-after 10 --script res://addons/gut/gut_cmdln.gd

echo "Test run complete"

# Notes for setup:
# 1. Install GUT addon: https://github.com/bitwes/Gut
# 2. Copy to res://addons/gut/
# 3. Enable in Project Settings → Plugins
# 4. Configure test directories in gut_config.gd