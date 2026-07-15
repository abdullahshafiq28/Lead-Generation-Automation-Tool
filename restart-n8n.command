#!/bin/zsh
# Restart n8n: stop whatever is on port 5678, then relaunch (reloads .env).
# Your account + imported workflow are kept (stored in ~/.n8n).
cd "$(dirname "$0")"

echo "Stopping any running n8n on port 5678…"
PID=$(lsof -ti:5678 2>/dev/null)
if [ -n "$PID" ]; then kill -9 $PID 2>/dev/null; echo "  stopped PID(s): $PID"; else echo "  nothing running"; fi
sleep 1

echo "Relaunching…"
exec ./start-n8n.command
