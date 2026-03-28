#!/bin/bash
# Generate a single game art asset via MuleRouter Nano-Banana Pro
# Usage: gen_asset.sh <output_path> <prompt> [aspect_ratio] [resolution]
set -e
OUT="$1"
PROMPT="$2"
ASPECT="${3:-1:1}"
RES="${4:-2K}"

if [ -f "$OUT" ] && [ $(stat -c%s "$OUT") -gt 1000 ]; then
    echo "SKIP $(basename $OUT)"
    exit 0
fi

cd /workspace/.claude/skills/mulerouter-skills
RESULT=$(uv run python models/google/nano-banana-pro/generation.py \
    --prompt "$PROMPT" \
    --aspect-ratio "$ASPECT" \
    --resolution "$RES" 2>&1)

URL=$(echo "$RESULT" | grep -oP 'https://[^\s]+\.png' | head -1)
if [ -n "$URL" ]; then
    curl -sL -o "$OUT" "$URL"
    if [ -f "$OUT" ] && [ $(stat -c%s "$OUT") -gt 1000 ]; then
        echo "OK $(basename $OUT)"
    else
        echo "FAIL $(basename $OUT) (download failed)"
        exit 1
    fi
else
    echo "FAIL $(basename $OUT) (no URL in output)"
    echo "$RESULT" | tail -5
    exit 1
fi
