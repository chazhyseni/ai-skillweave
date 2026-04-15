#!/bin/bash
# =============================================================================
# codesight-redirect.sh — PreToolUse hook
# =============================================================================
# Intercepts broad Glob/Grep codebase searches when codesight is configured.
# Reminds Claude to call codesight_get_summary first (once per session/project).
#
# Exit 2 = block tool + send message to Claude
# Exit 0 = allow tool to proceed
# =============================================================================

input=$(cat)

# Extract tool name, pattern, and path from hook payload
tool=$(echo "$input" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('tool_name', ''))
" 2>/dev/null)

session_id=$(echo "$input" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('session_id', 'default')[:24])
" 2>/dev/null || echo "default")

pattern=$(echo "$input" | python3 -c "
import json, sys
inp = json.load(sys.stdin).get('tool_input', {})
print(inp.get('pattern', '') or inp.get('glob', ''))
" 2>/dev/null)

path=$(echo "$input" | python3 -c "
import json, sys
inp = json.load(sys.stdin).get('tool_input', {})
print(inp.get('path', '') or inp.get('file_path', ''))
" 2>/dev/null)

# Only intercept broad searches (** glob patterns indicating codebase exploration)
is_broad=false
[[ "$pattern" == *"**"* ]] && is_broad=true
[[ -z "$path" && "$tool" == "Glob" ]] && is_broad=true
$is_broad || exit 0

# Walk up from search path to find nearest .codesight/ directory
check_dir="${path:-$(pwd)}"
[[ -f "$check_dir" ]] && check_dir=$(dirname "$check_dir")
codesight_dir=""
depth=0
while [[ "$check_dir" != "/" && $depth -lt 10 ]]; do
    if [[ -d "$check_dir/.codesight" ]]; then
        codesight_dir="$check_dir"
        break
    fi
    check_dir=$(dirname "$check_dir")
    ((depth++))
done

# No codesight configured — allow through
[[ -n "$codesight_dir" ]] || exit 0

# Only remind once per session per project (state tracked in /tmp)
state_dir="/tmp/claude-hooks-${session_id}"
mkdir -p "$state_dir"
# Hash the project dir for a short key
state_key=$(echo "$codesight_dir" | md5 2>/dev/null || echo "$codesight_dir" | cksum | cut -d' ' -f1)
state_key="${state_key:0:8}"
reminded_file="$state_dir/codesight-${state_key}.done"

# Already reminded this session — allow through
[[ -f "$reminded_file" ]] && exit 0

touch "$reminded_file"

cat << EOF
CODESIGHT REDIRECT: $codesight_dir has codesight configured.

Before running broad $tool searches, call codesight_get_summary first:
  mcp__codesight__codesight_get_summary(directory="$codesight_dir")

This returns a compact project map (~500 tokens) — routes, schema, hot files, env vars.
After calling codesight_get_summary, run targeted searches as needed (this reminder won't repeat).
EOF
exit 2
