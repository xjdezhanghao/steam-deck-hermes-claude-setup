#!/usr/bin/env bash
set -e

echo "=============================================="
echo " Hermes Dashboard 启动/安装脚本"
echo " 给 Steam Deck / Linux 用的"
echo "=============================================="
echo ""

USER_HOME="$HOME"
HERMES_HOME="${XDG_DATA_HOME:-$USER_HOME/.hermes}"
HERMES_VENV="$HERMES_HOME/hermes-agent/venv"

FNM_PATH="$USER_HOME/.local/share/fnm"
LOCAL_BIN="$USER_HOME/.local/bin"

# ─── 颜色 ───
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ──────────────────────────────────────
# 0. 主动加载 fnm / ~/.local/bin
# （bash 脚本是非交互式 shell，不会自动 source ~/.bashrc，
#  如果不手动加载，已经装好的 fnm/node/hermes 也会被判成"未安装"）
# ──────────────────────────────────────
[ -d "$FNM_PATH" ] && export PATH="$FNM_PATH:$PATH"
[ -d "$LOCAL_BIN" ] && export PATH="$LOCAL_BIN:$PATH"

if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd --shell bash 2>/dev/null)" || true
fi

hash -r

# ──────────────────────────────────────
# 1. 前置校验：确认 install-hermes-claude.sh 已经跑过
# ──────────────────────────────────────
echo "=== 1. 前置校验 ==="

MISSING_PREREQ=false

if ! command -v fnm >/dev/null 2>&1; then
    warn "fnm 未安装或不在 PATH（应该在 $FNM_PATH）"
    MISSING_PREREQ=true
else
    info "fnm: $(fnm --version 2>/dev/null || echo '已安装')"
fi

if ! command -v node >/dev/null 2>&1; then
    warn "node 未安装（fnm 已装但未 fnm use <version>？）"
    MISSING_PREREQ=true
else
    info "node: $(node -v)"
fi

if [ -f "$HERMES_VENV/bin/hermes" ]; then
    info "Hermes venv: $HERMES_VENV"
elif command -v hermes >/dev/null 2>&1; then
    HERMES_CMD="$(command -v hermes)"
    info "Hermes: $HERMES_CMD（未检测到 venv，将使用 PATH 中的版本）"
else
    warn "Hermes 未安装（install-hermes-claude.sh 应该先装它）"
    MISSING_PREREQ=true
fi

if [ "$MISSING_PREREQ" = true ]; then
    echo ""
    echo "如果你确认已经装过 install-hermes-claude.sh，请先在当前终端执行："
    echo "    source ~/.bashrc"
    echo "再重新运行本脚本。"
    echo ""
    err "缺少前置依赖。请先运行 install-hermes-claude.sh，完成后再执行本脚本。"
fi

echo ""

# ──────────────────────────────────────
# 2. 确认 Hermes 路径（优先用 venv 里的）
# ──────────────────────────────────────
echo "=== 2. 确认 Hermes ==="

if [ -f "$HERMES_VENV/bin/hermes" ]; then
    HERMES_CMD="$HERMES_VENV/bin/hermes"
    HERMES_PIP="$HERMES_VENV/bin/pip"
    info "使用 venv 中的 Hermes: $HERMES_CMD"
else
    HERMES_CMD="$(command -v hermes)"
    HERMES_PIP="pip3"
    info "使用 PATH 中的 Hermes: $HERMES_CMD"
fi

info "版本: $("$HERMES_CMD" --version 2>/dev/null || echo '无法获取')"

# 确认 dashboard 子命令可用
"$HERMES_CMD" dashboard --help >/dev/null 2>&1 && \
    info "dashboard 子命令可用" || \
    err "dashboard 子命令不可用，Hermes 版本可能太旧。升级：hermes update"

echo ""

# ──────────────────────────────────────
# 3. 安装 Dashboard 依赖（装进 Hermes venv）
# ──────────────────────────────────────
echo "=== 3. 安装 Dashboard 依赖 ==="

# 检查依赖是否已在 Hermes 的 Python 环境中可用
if "$HERMES_VENV/bin/python" -c "import ptyprocess, fastapi, uvicorn" 2>/dev/null; then
    info "依赖已存在，跳过安装"
else
    warn "依赖缺失，正在安装到 Hermes venv..."
    if [ -f "$HERMES_VENV/bin/pip" ]; then
        "$HERMES_VENV/bin/pip" install 'hermes-agent[web,pty]'
    else
        # fallback：venv 里没 pip（极端情况），用系统 pip 装到 venv
        python3 -m pip install --target="$HERMES_VENV/lib/python3"*/site-packages 'hermes-agent[web,pty]'
    fi

    # 验证
    if "$HERMES_VENV/bin/python" -c "import ptyprocess, fastapi, uvicorn" 2>/dev/null; then
        info "依赖安装完成"
    else
        err "依赖安装失败。手动尝试：$HERMES_VENV/bin/pip install 'hermes-agent[web,pty]'"
    fi
fi

echo ""

# ──────────────────────────────────────
# 4. 检查端口占用
# ──────────────────────────────────────
echo "=== 4. 检查端口 ==="

DASHBOARD_PORT=9119
if ss -tlnp 2>/dev/null | grep -q ":$DASHBOARD_PORT " || \
   lsof -i ":$DASHBOARD_PORT" 2>/dev/null | grep -q LISTEN; then
    warn "端口 $DASHBOARD_PORT 已被占用，Dashboard 可能已在运行"
    warn "用以下命令检查：systemctl --user status hermes-dashboard.service"
    warn "或在桌面模式打开 http://127.0.0.1:$DASHBOARD_PORT 确认是否可访问"
else
    info "端口 $DASHBOARD_PORT 空闲"
fi

echo ""

# ──────────────────────────────────────
# 5. lingering 检查（Steam Deck 游戏模式必需）
# ──────────────────────────────────────
echo "=== 5. 检查 lingering（游戏模式自启必需） ==="

LINGER_ENABLED=false
if loginctl show-user "$USER" 2>/dev/null | grep -q 'Linger=yes'; then
    LINGER_ENABLED=true
    info "用户 lingering 已启用"
else
    warn "用户 lingering 未启用"
    echo ""
    echo "  这是什么：systemd 用户服务默认在你登出后会被杀掉。"
    echo "  在 Steam Deck 上，游戏模式和桌面模式切换时可能触发登出，"
    echo "  导致 Dashboard 被杀。启用 lingering 后，服务会在后台持续运行。"
    echo ""
    echo "  需要 sudo 权限执行：sudo loginctl enable-linger $USER"
    echo ""
    echo "  选择："
    echo "    [1] 现在启用（需要输入 sudo 密码）"
    echo "    [2] 跳过，我自己稍后处理（Dashboard 可能在切换模式后不可用）"
    echo "    [3] 退出脚本"
    echo ""
    read -r -p "  请输入 1/2/3: " LINGER_CHOICE

    case "$LINGER_CHOICE" in
        1)
            echo ""
            if sudo loginctl enable-linger "$USER" 2>/dev/null; then
                info "lingering 已启用"
                LINGER_ENABLED=true
            else
                warn "启用失败（sudo 权限不足或密码错误），将继续但不保证游戏模式可用"
            fi
            ;;
        2)
            warn "已跳过。Dashboard 服务仍会创建，但在游戏模式下可能不可用。"
            warn "之后可以随时执行：sudo loginctl enable-linger $USER"
            ;;
        3)
            echo "已退出。"
            exit 0
            ;;
        *)
            warn "无效输入，跳过 lingering 设置。"
            ;;
    esac
fi

echo ""

# ──────────────────────────────────────
# 6. 创建 systemd 用户服务
# ──────────────────────────────────────
echo "=== 6. 创建 systemd 服务 ==="

SYSTEMD_DIR="$USER_HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_DIR"

# 构建 PATH：venv 优先 + 系统路径 + fnm/local/bin
SERVICE_PATH="$HERMES_VENV/bin:$USER_HOME/.local/share/fnm:$USER_HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

cat > "$SYSTEMD_DIR/hermes-dashboard.service" << EOF
[Unit]
Description=Hermes Dashboard (Web UI with Chat)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$HERMES_CMD dashboard --tui --port $DASHBOARD_PORT --no-open
WorkingDirectory=$USER_HOME
Environment="HERMES_HOME=$HERMES_HOME"
Environment="PATH=$SERVICE_PATH"
Restart=on-failure
RestartSec=10
RestartMaxDelaySec=60
RestartSteps=3
KillMode=mixed
TimeoutStopSec=30

[Install]
WantedBy=default.target
EOF

info "systemd 服务已写入：$SYSTEMD_DIR/hermes-dashboard.service"

echo ""

# ──────────────────────────────────────
# 7. 启用并启动
# ──────────────────────────────────────
echo "=== 7. 启用开机自启并启动 ==="

systemctl --user daemon-reload

systemctl --user enable hermes-dashboard.service 2>/dev/null && \
    info "已设为开机自启" || \
    err "设置开机自启失败"

# 先停止可能正在运行的同名进程
systemctl --user stop hermes-dashboard.service 2>/dev/null || true
sleep 1

systemctl --user start hermes-dashboard.service 2>/dev/null && \
    info "Dashboard 已启动" || \
    warn "启动失败，检查日志：journalctl --user -u hermes-dashboard.service --no-pager -n 50"

echo ""

# ──────────────────────────────────────
# 8. 状态检查
# ──────────────────────────────────────
echo "=== 8. 等待并检查状态 ==="

sleep 3

STATUS=$(systemctl --user is-active hermes-dashboard.service 2>/dev/null)
if [ "$STATUS" = "active" ]; then
    info "Dashboard 运行中 → http://127.0.0.1:$DASHBOARD_PORT"
    info "点击左侧 Chat 标签即可开始对话"
else
    warn "Dashboard 状态: $STATUS"
    echo ""
    echo "检查日志："
    echo "  journalctl --user -u hermes-dashboard.service --no-pager -n 50"
    echo ""
    echo "手动启动测试："
    echo "  $HERMES_CMD dashboard --tui --no-open"
fi

echo ""

# ──────────────────────────────────────
# 完成
# ──────────────────────────────────────
echo "=============================================="
echo " 完成！"
echo "=============================================="
echo ""
echo "在浏览器打开："
echo ""
echo "  http://127.0.0.1:$DASHBOARD_PORT"
echo ""
echo "Dashboard 左侧点击 Chat 即可开始对话。"
echo "中文输入：用 Steam Deck 自带键盘（Steam + X 键）。"
echo ""

if [ "$LINGER_ENABLED" != true ]; then
    warn "⚠ lingering 未启用，切换游戏/桌面模式后 Dashboard 可能停止。"
    echo "  之后随时执行：sudo loginctl enable-linger $USER"
    echo ""
fi

echo "常用命令："
echo "  查看状态：systemctl --user status hermes-dashboard.service"
echo "  查看日志：journalctl --user -u hermes-dashboard.service --no-pager -n 30"
echo "  重启服务：systemctl --user restart hermes-dashboard.service"
echo "  停止服务：systemctl --user stop hermes-dashboard.service"
echo ""
echo "将浏览器添加到 Steam 游戏库："
echo "  桌面模式 → Steam → 左下角「添加非 Steam 游戏」→ 选择浏览器"
echo "  游戏模式中打开浏览器 → 输入 http://127.0.0.1:9119 → 收藏到书签"
echo ""
