#!/bin/bash
# Compatibility entry: run the same local preview flow as preview.command.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec /bin/bash "$SCRIPT_DIR/preview.command"
