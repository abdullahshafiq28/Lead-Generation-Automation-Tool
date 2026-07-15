#!/bin/zsh
# Launch n8n for the Lead-Generation project.
# Double-click this file in Finder, or run:  ./start-n8n.command
#
# Why the env vars:
#   n8n's file nodes are sandboxed to ~/.n8n-files by default (a security feature).
#   N8N_RESTRICT_FILE_ACCESS_TO allow-lists THIS project folder so the workflow can
#   write output/leads.csv here instead.

cd "$(dirname "$0")"
export N8N_SECURE_COOKIE=false
export N8N_RESTRICT_FILE_ACCESS_TO="$(pwd)"

# Optional AI/ML stretch: load Gemini key (and any other vars) from .env so the
# workflow can read them via {{ $env.GEMINI_API_KEY }}. Absent .env = LLM step
# is skipped and the workflow runs exactly as before.
if [ -f .env ]; then set -a; . ./.env; set +a; echo "  Loaded .env (AI_PROVIDER=${AI_PROVIDER:-unset})"; fi
export N8N_BLOCK_ENV_ACCESS_IN_NODE=false   # allow {{ $env.* }} in nodes

# Where the CSV is written. Absolute + per-machine so it works from any clone
# location; honours OUTPUT_DIR from .env if you set one.
mkdir -p output
: "${OUTPUT_DIR:=$(pwd)/output}"; export OUTPUT_DIR

echo "Starting n8n…"
echo "  Project (writable by n8n): $(pwd)"
echo "  Open http://localhost:5678 once it says 'Editor is now accessible'."
npx -y n8n start
