# Steam Deck 上跑 Hermes Agent + Claude Code

> 在游戏机上写代码是什么体验？Steam Deck 能不能当生产力工具？不一定，但可以当个实验平台。

这是一个在 Steam Deck（SteamOS / Linux）上一键安装 **Hermes Agent + Claude Code** 完整开发环境的自动化脚本集合。

## 📦 包含什么

| 文件 | 说明 |
|------|------|
| `install-hermes-claude.sh` | 装基础环境：fnm、Node.js 22、Hermes Agent、Claude Code，配置 DeepSeek 兼容层 |
| `start-hermes-dashboard.sh` | 装 Dashboard Web 聊天界面，创建 systemd 服务，配置开机自启 |

## 🚦 安装顺序

```
先跑 install-hermes-claude.sh  →  按提示完成手动配置  →  跑 start-hermes-dashboard.sh

# 安装前编辑下 install-hermes-claude.sh，搜索 ANTHROPIC_API_KEY ，配置 claude code 使用的 API KEY，默认使用的 deepseek v4。
```

### 步骤 1：安装基础环境

```bash
chmod +x install-hermes-claude.sh
bash install-hermes-claude.sh
```

脚本会自动装：

- [fnm](https://github.com/Schniz/fnm)（Fast Node Manager）
- Node.js 22
- [Hermes Agent](https://github.com/NousResearch/hermes-agent)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)

**跑完后必须手动做两件事**：

```bash
# 1. 配置 Hermes 的模型和 API Key
hermes setup

# 2. 配置 claude code 的 API Key (前面编辑过脚本的 ANTHROPIC_API_KEY 可跳过该步骤)
# 编辑 ~/.bashrc，填入你的 API Key（脚本写的是占位符）
vim ~/.bashrc
# 找到 ANTHROPIC_API_KEY 那行，填上你的 Key 然后取消注释
# 然后使配置生效：
source ~/.bashrc
```

### 步骤 2：安装 Dashboard + 开机自启

```bash
chmod +x start-hermes-dashboard.sh
bash start-hermes-dashboard.sh
```

脚本会自动：

- 安装 Dashboard 依赖（ptyprocess、fastapi、uvicorn）
- 创建 systemd 用户服务
- 配置开机自启
- 启动服务，在 `http://127.0.0.1:9119` 提供 Web 聊天界面

安装过程中会询问是否启用 lingering（让服务在游戏/桌面模式切换后继续运行），选 `1` 即可。

## 🗝️ 核心要点

- **API Key 分两处**：Hermes 模型配置（`hermes setup`）+ Claude Code 环境变量（`~/.bashrc`）
- **游戏模式使用**：浏览器打开 `http://127.0.0.1:9119`，收藏到书签
- **开机自启**：Dashboard 跑在 systemd 用户服务里，无需重复手动启动
- **将浏览器添加到 Steam 游戏库**：桌面模式 Steam → 左下角「添加非 Steam 游戏」→ 选择浏览器，游戏模式下可直接启动

## 📺 能做什么

Hermes 是调度器，Claude Code 是写代码的 Agent。你在 Dashboard 聊天界面里提需求，Hermes 把编码类任务交给 Claude Code 去实现。已验证过的场景：

- 用 3 分钟写了一个 Steam 用户电脑配置分析器（FastAPI + ECharts），全程在游戏模式浏览器中完成

## ⚠️ 注意

- **不是免费的**。DeepSeek API 按 token 收费，Claude Code 写代码消耗量不小，简单应用大概几毛到一两块
- **Claude Code 跑得不算快**。加上网络延迟，一个任务可能要等半分钟到几分钟
- **中文输入**用 Steam Deck 自带键盘（Steam + X 呼出）

## 🛠️ 常用命令

```bash
# Dashboard 状态检查
systemctl --user status hermes-dashboard.service

# 查看日志
journalctl --user -u hermes-dashboard.service --no-pager -n 30

# 重启服务
systemctl --user restart hermes-dashboard.service

# 停止服务
systemctl --user stop hermes-dashboard.service

# 启用 lingering（如果安装时跳过了）
sudo loginctl enable-linger $USER
```

## 📄 许可证

MIT © xjdezhanghao
