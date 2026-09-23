#!/usr/bin/env bash

set -e

echo "🚀 Installing WEBCODE CLI, Agent & Knowledge Base..."

# 1. Determine bin directory (Fallback to /usr/local/bin if writable or ~/.local/bin)
CONFIG_DIR="$HOME/.config/opencode"
AGENT_DIR="$CONFIG_DIR/agent"
LOCAL_BIN="$HOME/.local/bin"

mkdir -p "$AGENT_DIR"
mkdir -p "$LOCAL_BIN"

# 2. Install web.md agent
cp -f web.md "$AGENT_DIR/web.md"

# 3. Disable default 'build' agent in opencode.jsonc
CONFIG_FILE="$CONFIG_DIR/opencode.jsonc"

if [ -f "$CONFIG_FILE" ]; then
    python3 -c "
import json, re

path = '$CONFIG_FILE'
try:
    with open(path, 'r') as f:
        content = f.read()
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

# 4. Create binary shortcuts in ~/.local/bin/ AND try /usr/local/bin/ (with sudo if needed/available)
cat << 'BINEOF' > "$LOCAL_BIN/webcode"
#!/usr/bin/env bash
exec opencode "$@"
BINEOF

cat << 'BINEOF' > "$LOCAL_BIN/web"
#!/usr/bin/env bash
exec opencode "$@"
BINEOF

chmod +x "$LOCAL_BIN/webcode"
chmod +x "$LOCAL_BIN/web"

# Try copying to /usr/local/bin if possible
if [ -w "/usr/local/bin" ]; then
    cp -f "$LOCAL_BIN/webcode" /usr/local/bin/webcode
    cp -f "$LOCAL_BIN/web" /usr/local/bin/web
elif command -v sudo >/dev/null 2>&1; then
    sudo cp -f "$LOCAL_BIN/webcode" /usr/local/bin/webcode 2>/dev/null || true
    sudo cp -f "$LOCAL_BIN/web" /usr/local/bin/web 2>/dev/null || true
fi

# 5. Add ~/.local/bin to PATH in shell config files if missing
for RCFILE in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [ -f "$RCFILE" ]; then
        if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$RCFILE"; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RCFILE"
        fi
    fi
done

echo "✅ SUCCESS! WEBCODE is now installed."
echo ""
echo "📌 Catatan Penting:"
echo "   1. Jika 'webcode' belum bisa diketik langsung, jalankan dulu:"
echo "      source ~/.bashrc  (atau source ~/.zshrc)"
echo "   2. Setelah itu, ketik 'webcode' di terminal!"
