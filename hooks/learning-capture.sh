#!/bin/bash
# BMO-Style Learning Event Capture
# Runs on UserPromptSubmit to detect corrections as they happen
# Based on: https://github.com/joelhans/bmo-agent/blob/main/skills/learning-event-capture.md

set -e

LEARNINGS_DIR="$HOME/.claude/skills/learned/events"
mkdir -p "$LEARNINGS_DIR"

# Read stdin from Claude Code hook
INPUT_JSON=$(cat)
if [ -z "$INPUT_JSON" ]; then
  exit 0
fi

# Extract user message
USER_MSG=$(echo "$INPUT_JSON" | python3 << 'PYEOF'
import json, sys
try:
    data = json.load(sys.stdin)
    msg = data.get("message", "")
    session = data.get("session_id", "unknown")
    project = data.get("cwd", "unknown")
    print(f"{session}\t{project}\t{msg}")
except Exception as e:
    print("")
PYEOF
)

if [ -z "$USER_MSG" ]; then
  exit 0
fi

SESSION_ID=$(echo "$USER_MSG" | cut -f1)
PROJECT=$(echo "$USER_MSG" | cut -f2)
MESSAGE=$(echo "$USER_MSG" | cut -f3-)

# Detect learning events using BMO's recognition cues
LEARNING_TYPE=""
CONFIDENCE="low"

# === CORRECTIONS (type: "correction") ===
# User says "no", "not that", "wrong", "actually..."
# User repeats an instruction you missed
# User undoes something you did
if echo "$MESSAGE" | grep -qiE "^no[,\.!]|\b(not that|wrong|incorrect|that's not|that's not what|you should|you must)\b"; then
  LEARNING_TYPE="correction"
  CONFIDENCE="high"
fi

# User provides the correct answer after your attempt
if echo "$MESSAGE" | grep -qiE "\b(actually|i meant|what i meant|what i want|instead use|use .* instead)\b"; then
  LEARNING_TYPE="correction"
  CONFIDENCE="high"
fi

# === PREFERENCES (type: "preference") ===
# User specifies a style choice
# User chooses between options you offered
# User describes their workflow or habits
# User says "I always...", "I prefer...", "I like..."
if echo "$MESSAGE" | grep -qiE "\b(i prefer|we prefer|i always|we always|i usually|we usually|i like|we like)\b"; then
  LEARNING_TYPE="preference"
  CONFIDENCE="medium"
fi

# === PATTERNS (type: "pattern") ===
# Recurring task types or workflows
if echo "$MESSAGE" | grep -qiE "\b(best practice|convention|standard|idiomatic|typically|usually|normally)\b"; then
  LEARNING_TYPE="pattern"
  CONFIDENCE="medium"
fi

# If we detected a learning event, log it
if [ -n "$LEARNING_TYPE" ]; then
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  EVENT_FILE="$LEARNINGS_DIR/${TIMESTAMP}_${SESSION_ID:0:8}.json"
  
  # Escape message for JSON
  ESCAPED_MSG=$(echo "$MESSAGE" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')
  
  cat > "$EVENT_FILE" << EVENTEOF
{
  "timestamp": "$(date -Iseconds)",
  "session": "$SESSION_ID",
  "project": "$PROJECT",
  "type": "$LEARNING_TYPE",
  "confidence": "$CONFIDENCE",
  "message": $ESCAPED_MSG,
  "status": "pending",
  "captured_by": "learning-capture.sh"
}
EVENTEOF
  
  echo "[LEARNING] Captured $LEARNING_TYPE ($CONFIDENCE): ${MESSAGE:0:80}..."
fi

exit 0
