#!/usr/bin/env bash

set -e

echo "🚀 Installing WEB CLI & Agent for OpenCode..."

# 1. Create target directories
CONFIG_DIR="$HOME/.config/opencode"
AGENT_DIR="$CONFIG_DIR/agent"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$AGENT_DIR"
mkdir -p "$BIN_DIR"

# 2. Install web.md agent
cp -f web.md "$AGENT_DIR/web.md"

# 3. Disable default 'build' agent in opencode.jsonc
CONFIG_FILE="$CONFIG_DIR/opencode.jsonc"

if [ -f "$CONFIG_FILE" ]; then
    # Add agent.build.disable = true if jsonc exists
    python3 -c "
import json

path = '$CONFIG_FILE'
try:
    with open(path, 'r') as f:
        content = f.read()
    # Strip comments if any or parse json
    import re
    cleaned = re.sub(r'//.*', '', content)
    cleaned = re.sub(r'/\*.*?\*/', '', cleaned, flags=re.DOTALL)
    data = json.loads(cleaned) if cleaned.strip() else {}
except Exception:
    data = {}

if 'agent' not in data:
    data['agent'] = {}
if 'build' not in data['agent']:
    data['agent']['build'] = {}
data['agent']['build']['disable'] = True

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null || true
else
    cat << 'JSONEOF' > "$CONFIG_FILE"
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "build": {
      "disable": true
    }
  }
}
JSONEOF
fi

# 4. Create binary shortcut `web` in ~/.local/bin/web
cat << 'BINEOF' > "$BIN_DIR/web"
#!/usr/bin/env bash
exec opencode "$@"
BINEOF

chmod +x "$BIN_DIR/web"

echo "✅ SUCCESS! WEB is now installed."
echo ""
echo "📌 Usage:"
echo "   Ketik 'web' di terminal untuk menjalankan CLI!"
echo "   Saat di dalam CLI, tekan TAB untuk beralih mode (Hanya ada mode 'plan' & 'web', mode 'build' disembunyikan!)."
