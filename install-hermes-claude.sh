#!/usr/bin/env bash
set -e

echo "=================================================="
echo " SteamOS/Linux installer: fnm + Node/npm + Hermes + Claude Code"
echo "=================================================="
echo ""

CURRENT_USER="$(whoami)"
USER_HOME="$HOME"

BASHRC="$USER_HOME/.bashrc"
NODE_VERSION="22"

FNM_PATH="$USER_HOME/.local/share/fnm"
LOCAL_BIN="$USER_HOME/.local/bin"

FNM_BLOCK_START="# >>> fnm config for SteamOS installer >>>"
FNM_BLOCK_END="# <<< fnm config for SteamOS installer <<<"

LOCAL_BIN_BLOCK_START="# >>> local bin config for Hermes Claude installer >>>"
LOCAL_BIN_BLOCK_END="# <<< local bin config for Hermes Claude installer <<<"

CLAUDE_BLOCK_START="# >>> Claude Code DeepSeek config installer >>>"
CLAUDE_BLOCK_END="# <<< Claude Code DeepSeek config installer <<<"

# ─── 颜色 ───
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ──────────────────────────────────────
# 1. 基础检查
# ──────────────────────────────────────
echo "=== 1. 基础检查 ==="

if ! command -v bash >/dev/null 2>&1; then
    err "未找到 bash。"
fi

if ! command -v curl >/dev/null 2>&1; then
    err "未找到 curl，请先安装：sudo pacman -S curl"
fi

if ! command -v git >/dev/null 2>&1; then
    warn "未找到 git。Hermes 安装需要 git clone。"
    echo "  Steam Deck 上执行：sudo pacman -S git"
    echo "  安装完成后重新运行本脚本。"
    exit 1
fi
info "git: $(git --version | head -1)"

if ! command -v python3 >/dev/null 2>&1; then
    err "未找到 python3。Steam Deck 自带 Python3，如缺失请执行：sudo pacman -S python"
fi
info "python3: $(python3 --version)"

mkdir -p "$LOCAL_BIN"

if [ ! -f "$BASHRC" ]; then
    touch "$BASHRC"
fi

echo "当前用户：$CURRENT_USER"
echo "用户目录：$USER_HOME"
echo "BASHRC：$BASHRC"
echo "FNM_PATH：$FNM_PATH"
echo "LOCAL_BIN：$LOCAL_BIN"
echo ""

# ──────────────────────────────────────
# 2. 备份 .bashrc
# ──────────────────────────────────────
echo "=== 2. 备份 .bashrc ==="

BACKUP="$BASHRC.bak.$(date +%Y%m%d%H%M%S)"
cp "$BASHRC" "$BACKUP"
info "已备份到：$BACKUP"
echo ""

# ──────────────────────────────────────
# 3. 检查旧配置，仅提示，不自动删除
# ──────────────────────────────────────
echo "=== 3. 检查旧配置 ==="

echo "下面是当前 .bashrc 里与 fnm / Hermes / ANTHROPIC / CLAUDE_CODE 相关的内容："
echo "--------------------------------------------------"
grep -n "fnm\|Hermes\|hermes\|ANTHROPIC\|CLAUDE_CODE\|local/bin" "$BASHRC" || echo "未发现相关旧配置。"
echo "--------------------------------------------------"
echo ""
echo "说明：脚本只会覆盖自己管理的配置块，不会自动删除你以前手写的零散配置。"
echo ""

# ──────────────────────────────────────
# 4. 清理本脚本管理的旧配置块（保留用户已填入的 API Key）
# ──────────────────────────────────────
echo "=== 4. 清理旧配置块 ==="

# 重跑时优先保留用户已经填入的 ANTHROPIC_API_KEY（未注释、且不是占位 sk-xxx）
EXISTING_API_KEY_LINE="$(grep -E '^[[:space:]]*export ANTHROPIC_API_KEY=' "$BASHRC" 2>/dev/null | grep -v 'sk-xxx' | tail -1 || true)"
if [ -n "$EXISTING_API_KEY_LINE" ]; then
    info "检测到已填入的 ANTHROPIC_API_KEY，重写配置时会保留它。"
fi

sed -i "/$FNM_BLOCK_START/,/$FNM_BLOCK_END/d" "$BASHRC" || true
sed -i "/$LOCAL_BIN_BLOCK_START/,/$LOCAL_BIN_BLOCK_END/d" "$BASHRC" || true
sed -i "/$CLAUDE_BLOCK_START/,/$CLAUDE_BLOCK_END/d" "$BASHRC" || true

info "旧配置块清理完成"
echo ""

# ──────────────────────────────────────
# 5. 写入 fnm 配置到 .bashrc
# ──────────────────────────────────────
echo "=== 5. 写入 fnm 配置 ==="

cat >> "$BASHRC" <<'EOF'

# >>> fnm config for SteamOS installer >>>
# fnm Node.js version manager
FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --use-on-cd --shell bash)"
fi
# <<< fnm config for SteamOS installer <<<
EOF

info "fnm 配置已写入"
echo ""

# ──────────────────────────────────────
# 6. 写入 ~/.local/bin 配置到 .bashrc
# ──────────────────────────────────────
echo "=== 6. 写入 ~/.local/bin 配置 ==="

cat >> "$BASHRC" <<'EOF'

# >>> local bin config for Hermes Claude installer >>>
# User local binaries for Hermes / Claude Code
if [ -f "$HOME/.local/bin/env" ]; then
  . "$HOME/.local/bin/env"
fi

export PATH="$HOME/.local/bin:$PATH"
# <<< local bin config for Hermes Claude installer <<<
EOF

info "~/.local/bin 配置已写入"
echo ""

# ──────────────────────────────────────
# 7. 安装或修复 fnm
# ──────────────────────────────────────
echo "=== 7. 安装 fnm ==="

if [ -x "$FNM_PATH/fnm" ]; then
    info "fnm 已存在：$FNM_PATH/fnm"
else
    info "开始安装 fnm..."
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
fi
echo ""

# ──────────────────────────────────────
# 8. 当前终端加载 fnm
# ──────────────────────────────────────
echo "=== 8. 加载 fnm ==="

export PATH="$FNM_PATH:$PATH"

if ! command -v fnm >/dev/null 2>&1; then
    err "fnm 安装后仍然找不到。"
fi

eval "$(fnm env --use-on-cd --shell bash)"

info "fnm 路径：$(command -v fnm)"
info "fnm 版本：$(fnm --version)"
echo ""

# ──────────────────────────────────────
# 9. 安装并设置 Node.js / npm
# ──────────────────────────────────────
echo "=== 9. 安装 Node.js $NODE_VERSION ==="

fnm install "$NODE_VERSION"
fnm use "$NODE_VERSION"
fnm default "$NODE_VERSION"

info "node 路径：$(command -v node)"
info "node 版本：$(node -v)"
info "npm 路径：$(command -v npm)"
info "npm 版本：$(npm -v)"
echo ""

# ──────────────────────────────────────
# 10. 安装或修复 Hermes Agent
# ──────────────────────────────────────
echo "=== 10. 安装 Hermes Agent ==="

export PATH="$LOCAL_BIN:$PATH"

if command -v hermes >/dev/null 2>&1; then
    info "检测到已有 Hermes：$(command -v hermes)"
    echo "  仍会重新执行安装脚本，用于修复或更新。"
else
    info "未检测到 Hermes，开始安装。"
fi

curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-setup

export PATH="$LOCAL_BIN:$PATH"
hash -r

if command -v hermes >/dev/null 2>&1; then
    info "Hermes 安装完成：$(command -v hermes)"
    hermes --version 2>/dev/null || true
else
    err "Hermes 安装后仍找不到命令。检查 ~/.local/bin/ 下是否有 hermes。"
fi
echo ""

# ──────────────────────────────────────
# 11. 安装或修复 Claude Code
# ──────────────────────────────────────
echo "=== 11. 安装 Claude Code ==="

if command -v claude >/dev/null 2>&1; then
    info "检测到已有 Claude Code：$(command -v claude)"
    echo "  仍会重新执行安装脚本，用于修复或更新。"
else
    info "未检测到 Claude Code，开始安装。"
fi

curl -fsSL https://claude.ai/install.sh | bash

export PATH="$LOCAL_BIN:$PATH"
hash -r

if command -v claude >/dev/null 2>&1; then
    info "Claude Code 安装完成：$(command -v claude)"
    claude --version 2>/dev/null || true
else
    warn "Claude Code 安装后未在 PATH 中找到 claude 命令。"
    warn "可能是安装脚本的路径问题，请检查 ~/.local/bin/ 或重新打开终端后验证。"
fi
echo ""

# ──────────────────────────────────────
# 12. 写入 Claude Code / DeepSeek 环境变量
# ──────────────────────────────────────
echo "=== 12. 写入 Claude Code 环境变量 ==="

{
cat <<'EOF'

# >>> Claude Code DeepSeek config installer >>>
export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"

export ANTHROPIC_MODEL="deepseek-v4-flash"
EOF

if [ -n "$EXISTING_API_KEY_LINE" ]; then
    echo "$EXISTING_API_KEY_LINE"
else
    echo "# 填入你的 DeepSeek API Key 后，再取消下一行注释"
    echo "# export ANTHROPIC_API_KEY=\"sk-xxx...xxxx\""
fi

cat <<'EOF'
export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-pro[1m]"
export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-pro[1m]"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-flash"
export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-flash"
export CLAUDE_CODE_EFFORT_LEVEL="max"

# <<< Claude Code DeepSeek config installer <<<
EOF
} >> "$BASHRC"

info "Claude Code / DeepSeek 环境变量已写入"
echo ""

# ──────────────────────────────────────
# 13. 当前终端加载最新配置
# ──────────────────────────────────────
echo "=== 13. 加载最新配置 ==="

source "$BASHRC" || true

export PATH="$FNM_PATH:$LOCAL_BIN:$PATH"

if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd --shell bash)" || true
fi

hash -r

echo ""

# ──────────────────────────────────────
# 14. 最终检查
# ──────────────────────────────────────
echo "=== 14. 最终检查 ==="

check_cmd() {
    local name="$1"
    local cmd="$2"
    echo ""
    echo "[$name]"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "  路径：$(command -v "$cmd")"
        "$cmd" --version 2>/dev/null || "$cmd" -v 2>/dev/null || echo "  （版本信息获取失败，但命令可用）"
    else
        warn "  未找到 $cmd"
    fi
}

check_cmd "fnm"    fnm
check_cmd "node"   node
check_cmd "npm"    npm
check_cmd "hermes" hermes
check_cmd "claude" claude

echo ""
echo "[环境变量]"
echo "ANTHROPIC_BASE_URL=$ANTHROPIC_BASE_URL"
echo "ANTHROPIC_MODEL=$ANTHROPIC_MODEL"
echo "ANTHROPIC_DEFAULT_OPUS_MODEL=$ANTHROPIC_DEFAULT_OPUS_MODEL"
echo "ANTHROPIC_DEFAULT_SONNET_MODEL=$ANTHROPIC_DEFAULT_SONNET_MODEL"
echo "ANTHROPIC_DEFAULT_HAIKU_MODEL=$ANTHROPIC_DEFAULT_HAIKU_MODEL"
echo "CLAUDE_CODE_SUBAGENT_MODEL=$CLAUDE_CODE_SUBAGENT_MODEL"
echo "CLAUDE_CODE_EFFORT_LEVEL=$CLAUDE_CODE_EFFORT_LEVEL"

# ──────────────────────────────────────
# 15. 完成 & 下一步
# ──────────────────────────────────────
echo ""
echo "=================================================="
echo " 安装完成！"
echo "=================================================="
echo ""

NEED_SETUP=false
NEED_APIKEY=false

# 检查 Hermes 是否已配置过模型
if [ ! -f "$USER_HOME/.hermes/config.yaml" ]; then
    NEED_SETUP=true
fi

# 检查 API Key（简单判断：注释未取消且无有效值）
if grep -q '^# export ANTHROPIC_API_KEY=' "$BASHRC" 2>/dev/null && \
   ! grep -q '^export ANTHROPIC_API_KEY=sk-' "$BASHRC" 2>/dev/null; then
    NEED_APIKEY=true
fi

if [ "$NEED_SETUP" = true ] || [ "$NEED_APIKEY" = true ]; then
    echo "⚠  还需要手动完成以下步骤，否则无法正常使用："
    echo ""
fi

if [ "$NEED_SETUP" = true ]; then
    echo "  【必须】配置 Hermes 模型和 API Key："
    echo "    hermes setup"
    echo "    按提示选择模型提供商（DeepSeek / OpenRouter 等）并填入 API Key。"
    echo ""
fi

if [ "$NEED_APIKEY" = true ]; then
    echo "  【必须】填入 Claude Code 的 API Key："
    echo "    编辑 ~/.bashrc，找到 'ANTHROPIC_API_KEY' 行，"
    echo "    把注释去掉并填入你的 DeepSeek API Key。"
    echo "    然后执行 source ~/.bashrc 使其生效。"
    echo ""
fi

echo "  配置完成后，关闭终端重新打开，验证："
echo ""
echo "    fnm --version"
echo "    node -v"
echo "    hermes --help"
echo "    claude --version"
echo ""

echo "  如果要安装 Dashboard（Web 聊天界面 + 开机自启）："
echo ""
echo "    bash start-hermes-dashboard.sh"
echo ""
echo "  这会在浏览器里提供一个 Chat 面板，方便 Steam Deck 游戏模式下使用。"
echo ""

echo "  如果要恢复脚本运行前的 .bashrc："
echo ""
echo "    cp \"$BACKUP\" \"$BASHRC\""
echo "    source \"$BASHRC\""
echo ""
