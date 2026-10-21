# Modular Linux Setup

`./init.sh` 是入口脚本，实际实现位于本目录。每个工具一个模块文件，
模块可以同时包含该工具的插件、wrapper 和配置。

## 使用

```bash
./init.sh                 # TUI 勾选工具
./init.sh --list          # 查看模块及安装状态
./init.sh --check-network # 只检查外网/代理
./init.sh --only uv,codex # 非交互安装指定模块及依赖
./init.sh --all           # 非交互安装全部模块
```

交互模式下：

1. 用空格勾选工具，回车确认。
2. 自动补齐 `MODULE_REQUIRES` 中声明的依赖。
3. 可选择是否强制重跑已经安装的模块。
4. 安装前强制检查所选工具需要访问的外网地址。
5. 网络不通时只能“重试 / 配置代理 / 清除代理 / 退出”，不会继续安装。

代理成功后可以保存到 `~/.config/linux-setup/proxy.env`（权限 600）。安装器会把一个
受管 source 块放到 `~/.bashrc` 和 `~/.zshrc` 顶部，重新登录后继续生效。

## 目录结构

```text
linux-setup/
├── run.sh                 # TUI、依赖解析、网络门禁和模块调度
├── config/
│   ├── settings.sh        # 可覆盖路径、版本和环境变量
│   └── zshrc              # 可复现的 ~/.zshrc 模板
├── lib/
│   ├── common.sh          # 日志、受管文件写入
│   ├── network.sh         # 并行联网检测、代理交互和持久化
│   └── tui.sh             # whiptail/dialog 封装及纯文本降级
└── modules/
    ├── 10_miniconda.sh
    ├── 20_uv.sh
    ├── 30_tools-env.sh
    ├── 40_oh-my-zsh.sh    # oh-my-zsh + 两个 zsh 插件
    ├── 50_nvm-node.sh
    ├── 60_tmux.sh
    ├── 70_codex.sh        # CLI + HPC wrappers
    ├── 71_cc-switch.sh
    ├── 72_codex-feishu-agent.sh
    ├── 73_codex-feishu-notice.sh # 含 Codex marketplace 插件注册
    ├── 74_pi.sh           # pi coding agent CLI
    ├── 80_projects.sh
    ├── 81_shell-switch.sh
    ├── 82_gpu-who.sh
    └── 84_zshrc.sh
```

## 新增模块

新建 `modules/NN_name.sh`，文件名必须以数字开头。模块 ID 中的 `-` 会自动转换为
函数名中的 `_`：

```bash
#!/usr/bin/env bash
MODULE_ID="my-tool"
MODULE_NAME="My Tool"
MODULE_DESCRIPTION="一句话说明"
MODULE_DEFAULT=1
MODULE_REQUIRES=""              # 空格分隔的模块 ID
MODULE_NEEDS_NETWORK=1
MODULE_PROBE_URLS=("https://example.com/download")

my_tool_is_installed() {
  command -v my-tool >/dev/null 2>&1
}

my_tool_install() {
  # 在这里安装工具、插件、wrapper 和配置。
  :
}
```

模块通过 `run.sh` 注册，必须同时提供 `<id>_is_installed` 和 `<id>_install`。
安装函数返回非零时，TUI 会在最终报告中标记失败，但会继续执行后续模块。

## 常用覆盖变量

```bash
SSD_PROJECTS=/ssd/$USER/projects ./init.sh
CONDA_ROOT=$HOME/miniconda3 ./init.sh
NODE_DEFAULT=22 ./init.sh
CUSTOM_TOOLS_ENABLED=0 ./init.sh
NETWORK_MAX_TIME=15 ./init.sh
NETWORK_CHECK_URLS='https://github.com/ https://repo.anaconda.com/' ./init.sh
```

`NETWORK_CHECK_URLS` 主要用于特殊网络或测试环境，正常安装会根据已选模块自动生成
需要检查的地址列表。
