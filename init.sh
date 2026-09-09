#!/usr/bin/env bash
# init.sh — 一键初始化开发环境
# 安装顺序：代理 → Miniconda → uv → tools 环境 → oh-my-zsh → .zshrc → bash→zsh → Node → tmux → projects → agents
# 用法：bash init.sh

set -euo pipefail

# 项目根目录
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ZSHRC="${PROJECT_ZSHRC:-$SCRIPT_DIR/.zshrc}"

# ----------------------------- 可配置变量 -------------------------------------
MINICONDA_INSTALLER="Miniconda3-latest-Linux-x86_64.sh"
MINICONDA_URL="https://repo.anaconda.com/miniconda/${MINICONDA_INSTALLER}"
MINICONDA_INSTALLER_PATH="${MINICONDA_INSTALLER_PATH:-/tmp/miniconda.sh}"
MINICONDA_SHA256="e8b25b92b262499141c5bd57a98d3c008024185fa951494b9cd9b6d94e72338b"
CONDA_ROOT="${CONDA_ROOT:-$HOME/miniconda3}"

SSD_ROOT="${SSD_ROOT:-/ssd/lixin/conda}"
CONDA_ENVS="$SSD_ROOT/conda_envs"
CONDA_PKGS="$SSD_ROOT/conda_pkgs"
TOOLS_ENV="$CONDA_ENVS/tools"

# SSD 项目目录，软链到 $HOME
SSD_PROJECTS="${SSD_PROJECTS:-/ssd/lixin/projects}"
PROJECTS_LINK="${PROJECTS_LINK:-$HOME/projects}"

ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
NVM_VERSION="v0.40.4"
NODE_DEFAULT="22"

# oh-my-zsh 主题
ZSH_THEME="${ZSH_THEME:-robbyrussell}"

# 代理；PROXY_ENABLED=0 可禁用
PROXY_ENABLED="${PROXY_ENABLED:-1}"
PROXY_HOST="${PROXY_HOST:-172.20.0.76}"
PROXY_PORT="${PROXY_PORT:-10808}"

log()  { printf '\n\033[1;34m[init]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✔\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*"; }

# 非 root 时使用 sudo
SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

# ------------------------------- 1. Miniconda --------------------------------
install_miniconda() {
  # 仅在 conda 不可用时重装
  if [ -x "$CONDA_ROOT/bin/conda" ] && "$CONDA_ROOT/bin/conda" --version >/dev/null 2>&1; then
    ok "Miniconda 已安装于 $CONDA_ROOT（跳过）"
  else
    if [ -e "$CONDA_ROOT" ]; then
      log "清理上次残留的 Miniconda 安装：$CONDA_ROOT"
      rm -rf -- "${CONDA_ROOT:?CONDA_ROOT must not be empty}"
    fi

    log "重新下载 Miniconda：$MINICONDA_URL"
    rm -f -- "$MINICONDA_INSTALLER_PATH"
    wget --timeout=30 --tries=3 "$MINICONDA_URL" -O "$MINICONDA_INSTALLER_PATH"

    log "校验 Miniconda 安装包 SHA256"
    actual_sha256="$(sha256sum "$MINICONDA_INSTALLER_PATH" | awk '{print $1}')"
    if [ "$actual_sha256" != "$MINICONDA_SHA256" ]; then
      warn "期望 SHA256: $MINICONDA_SHA256"
      warn "实际 SHA256: $actual_sha256"
      echo "Miniconda installer checksum mismatch: $MINICONDA_INSTALLER_PATH" >&2
      exit 1
    fi
    ok "Miniconda 安装包校验通过"

    log "安装 Miniconda -> $CONDA_ROOT"
    bash "$MINICONDA_INSTALLER_PATH" -b -p "$CONDA_ROOT"
    rm -f -- "$MINICONDA_INSTALLER_PATH"
  fi

# 加载 conda
  source "$CONDA_ROOT/etc/profile.d/conda.sh"
  # 不自动激活 base
  conda config --set auto_activate_base false || true
  ok "conda: $(conda --version)"
}

# --------------------------------- 2. uv -------------------------------------
install_uv() {
  if command -v uv >/dev/null 2>&1; then
    ok "uv 已安装：$(uv --version)"
  else
    log "安装 uv"
    curl -LsSf --connect-timeout 10 --max-time 120 https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
}

# ---------------------- 3. tools conda 环境 (zsh/tmux/htop) -------------------
# 新版 conda 需要先接受 ToS
accept_conda_tos() {
  log "接受 Anaconda 默认 channel 的 Terms of Service（新版 conda 必需）"
  conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2>/dev/null || true
  conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r    2>/dev/null || true
  ok "conda ToS 已处理（如无此命令会自动忽略）"
}

make_tools_env() {
  log "准备 tools conda 环境（zsh / tmux / htop）"
  accept_conda_tos
  # 配置 SSD 目录
  mkdir -p "$CONDA_ENVS" "$CONDA_PKGS"
  conda config --append envs_dirs "$CONDA_ENVS" || true
  conda config --append pkgs_dirs "$CONDA_PKGS" || true

  if [ -x "$TOOLS_ENV/bin/zsh" ] && [ -x "$TOOLS_ENV/bin/tmux" ] && [ -x "$TOOLS_ENV/bin/htop" ]; then
    ok "tools 环境已就绪（$TOOLS_ENV，已安装跳过）"
  else
    # 安装 tools 环境依赖
    conda create -n tools -y || true
    conda install -n tools -c conda-forge zsh tmux htop -y
  fi
  # 使用 tools 环境
  export PATH="$TOOLS_ENV/bin:$PATH"
  ok "zsh : $(command -v zsh)  tmux: $(command -v tmux)  htop: $(command -v htop)"
}

# ----------------------------- 4. oh-my-zsh + 插件 ---------------------------
install_ohmyzsh() {
  # 避免已有 ZSH 变量干扰安装
  unset ZSH
  local omz="$HOME/.oh-my-zsh"
  local zshrc="$HOME/.zshrc"

  # 用 git 安装 oh-my-zsh
  if [ -f "$omz/oh-my-zsh.sh" ]; then
    ok "oh-my-zsh 文件已就绪（跳过安装）"
  else
    log "安装 oh-my-zsh（git clone）"
    # 处理残缺目录
    if [ -e "$omz" ] && [ ! -f "$omz/oh-my-zsh.sh" ]; then
      mv "$omz" "${omz}.bak.$(date +%s)"
    fi
    if git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$omz"; then
      ok "oh-my-zsh 已通过 git 安装"
    else
      warn "oh-my-zsh git 安装失败（请检查网络/代理后重跑）"
    fi
  fi

  # 仅在 oh-my-zsh 可用时写配置
  [ -f "$zshrc" ] || touch "$zshrc"
  if [ -f "$omz/oh-my-zsh.sh" ]; then
    if ! grep -q "source .*oh-my-zsh.sh" "$zshrc"; then
      # 初始化或补写 omz 配置
      if ! grep -q "plugins=" "$zshrc"; then
        cp "$omz/templates/zshrc.zsh-template" "$zshrc"
        ok "已用 oh-my-zsh 模板初始化 ~/.zshrc"
      else
        {
          echo ""
          echo "export ZSH=\"$HOME/.oh-my-zsh\""
          echo "source \$ZSH/oh-my-zsh.sh"
        } >> "$zshrc"
        ok "已在 ~/.zshrc 追加 oh-my-zsh 加载"
      fi
    else
      ok "~/.zshrc 已加载 oh-my-zsh（跳过）"
    fi
  else
    warn "oh-my-zsh 未安装成功：$omz/oh-my-zsh.sh 不存在"
  fi

  # 设置主题
  if [ -f "$omz/oh-my-zsh.sh" ]; then
    if grep -q "^ZSH_THEME=\"$ZSH_THEME\"" "$zshrc"; then
      ok "主题已是 $ZSH_THEME（跳过）"
    else
      # 替换主题
      sed -i "s/^#\?ZSH_THEME=.*/ZSH_THEME=\"$ZSH_THEME\"/" "$zshrc"
      # 主题行缺失时补写
      if ! grep -q "^ZSH_THEME=\"$ZSH_THEME\"" "$zshrc"; then
        awk -v t="$ZSH_THEME" '
          /source .*oh-my-zsh.sh/ && !done { print "ZSH_THEME=\"" t "\""; done=1 }
          { print }
          END { if (!done) print "ZSH_THEME=\"" t "\"" }
        ' "$zshrc" > "$zshrc.tmp" && mv "$zshrc.tmp" "$zshrc"
      fi
      ok "主题已设为 $ZSH_THEME"
    fi
  fi

  # 安装 zsh 插件
  if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" ]; then
    git clone -q https://github.com/zsh-users/zsh-autosuggestions.git \
      "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
  fi
  if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" ]; then
    git clone -q https://github.com/zsh-users/zsh-syntax-highlighting.git \
      "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
  fi
  # 确保 plugins 配置存在
  ensure_plugins_block() {
    local zshrc="$HOME/.zshrc"
    [ -f "$zshrc" ] || touch "$zshrc"
    if ! grep -q "^[[:space:]]*plugins=(" "$zshrc"; then
      awk -v list="git zsh-autosuggestions zsh-syntax-highlighting" '
        /source .*oh-my-zsh.sh/ && !done {
          print "plugins=("
          n = split(list, a, " ")
          for (i = 1; i <= n; i++) print "  " a[i]
          print ")"
          done = 1
        }
        { print }
        END { if (!done) print "plugins=(git zsh-autosuggestions zsh-syntax-highlighting)" }
      ' "$zshrc" > "$zshrc.tmp" && mv "$zshrc.tmp" "$zshrc"
      ok "已创建 plugins 块"
    fi
  }
  # 启用插件
  enable_plugin() {
    local plugin="$1"
    local zshrc="$HOME/.zshrc"
    if grep -q "\b$plugin\b" "$zshrc" 2>/dev/null; then
      return 0
    fi
    awk -v p="$plugin" '
      /^plugins=\(/ { in_plugins=1 }
      in_plugins && /)/ {
        if ($0 ~ /^plugins=\(.*\)/) { sub(/\)$/, " " p ")", $0) }
        else { print "  " p }
        in_plugins=0
      }
      { print }
    ' "$zshrc" > "$zshrc.tmp" && mv "$zshrc.tmp" "$zshrc"
    ok "已加入插件: $plugin"
  }
  ensure_plugins_block
  enable_plugin git
  enable_plugin zsh-autosuggestions
  enable_plugin zsh-syntax-highlighting
  ok "oh-my-zsh + 插件完成"
}

# --------------------- 4.1 安装项目版 .zshrc --------------------------------
install_zshrc_config() {
  if [ ! -f "$PROJECT_ZSHRC" ]; then
    warn "项目版 zshrc 不存在：$PROJECT_ZSHRC，保留当前 ~/.zshrc"
    return 0
  fi

  if cmp -s "$PROJECT_ZSHRC" "$HOME/.zshrc" 2>/dev/null; then
    ok "~/.zshrc 已是项目版配置（跳过）"
    return 0
  fi

  if [ -f "$HOME/.zshrc" ]; then
    local backup="$HOME/.zshrc.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$HOME/.zshrc" "$backup"
    ok "已备份原 ~/.zshrc -> $backup"
  fi

  install -m 0644 "$PROJECT_ZSHRC" "$HOME/.zshrc"
  ok "已安装项目版 ~/.zshrc <- $PROJECT_ZSHRC"
}

# ---------------------------- 5. nvm + Node 22 -------------------------------
install_node() {
  if [ -d "$HOME/.nvm" ]; then
    ok "nvm 已安装（跳过）"
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  else
    log "安装 nvm $NVM_VERSION"
    curl -o- --connect-timeout 10 --max-time 120 "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  fi
  # 安装并设置默认 Node
  nvm install "$NODE_DEFAULT" || true
  nvm alias default "$NODE_DEFAULT" || true
  nvm use "$NODE_DEFAULT" >/dev/null || true
  ok "node: $(node -v 2>/dev/null || echo '未知')"
}

# ------------------------------ 6. tmux 配置 ----------------------------------
setup_tmux() {
  if [ -f "$HOME/.tmux.conf" ]; then
    ok "~/.tmux.conf 已存在（跳过）"
  else
    log "写入 ~/.tmux.conf"
    cat > "$HOME/.tmux.conf" <<'TMUX'
set -g status-style "bg=#4c7ccc, fg=black"
set -g mouse on
TMUX
  fi
  ok "tmux 配置完成"
}

# --------------------------- 7. 编码 Agent 工具 ------------------------------
install_agents() {
  # codex CLI
  if command -v codex >/dev/null 2>&1; then
    ok "codex 已安装：$(codex --version 2>/dev/null || echo ok)"
  else
    log "安装 codex CLI"
    curl -fsSL --connect-timeout 10 --max-time 120 https://chatgpt.com/codex/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi

  # cc-switch
  if command -v cc-switch >/dev/null 2>&1; then
    ok "cc-switch 已安装：$(cc-switch --version 2>/dev/null || echo ok)"
  else
    log "安装 cc-switch"
    # 下载失败不中断，后面用版本命令确认
    curl -L --connect-timeout 10 --max-time 180 -o cc-switch.tgz "https://github.com/saladday/cc-switch-cli/releases/latest/download/cc-switch-cli-linux-x64-musl.tar.gz" || true
    tar -xzf cc-switch.tgz 2>/dev/null || true
    mkdir -p "$HOME/.local/bin"
    mv -f cc-switch "$HOME/.local/bin/" 2>/dev/null || true
    find . -maxdepth 1 -name "cc-switch.tgz" -delete 2>/dev/null || true
    # 版本校验
    if command -v cc-switch >/dev/null 2>&1 && cc-switch --version >/dev/null 2>&1; then
      ok "cc-switch 已安装：$(cc-switch --version 2>/dev/null)"
    else
      warn "cc-switch 安装未成功（二进制缺失或版本校验失败，可稍后重试）"
    fi
  fi
}

# ----------- 让交互式 bash 自动进入 zsh（写入 ~/.bashrc，幂等） ----------
setup_shell_switch() {
  local bashrc="$HOME/.bashrc"
  [ -f "$bashrc" ] || touch "$bashrc"

  # 确保 tools zsh 在 PATH
  if ! grep -qF "conda_envs/tools/bin" "$bashrc"; then
    echo 'export PATH="'"$TOOLS_ENV"'/bin:$HOME/.local/bin:$PATH"' >> "$bashrc"
    ok "已把 zsh(tools) 写入 ~/.bashrc 的 PATH"
  fi

  # 交互式 bash 自动进 zsh
  if grep -q "exec zsh" "$bashrc"; then
    ok "~/.bashrc 已有自动进 zsh（跳过）"
  else
    cat >> "$bashrc" <<'EOF'

# 交互式会话自动进入 zsh（由 init.sh 写入；先 activate tools 补动态库）
if [ -n "$PS1" ]; then
  exec zsh
fi
EOF
    ok "已在 ~/.bashrc 写入自动进 zsh"
  fi
}

# --------------- 0. 预检：检测已安装工具（已装的自动跳过） ----------------
check_installed() {
  # 检测 ~/.local/bin 工具
  export PATH="$HOME/.local/bin:$PATH"

  check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
      ok "$name 已安装（跳过）"
    else
      warn "$name 未安装"
    fi
  }

  log "预检已安装工具（已装的将自动跳过）"
  check "Miniconda(conda)"        test -x "$CONDA_ROOT/bin/conda"
  check "uv"                      command -v uv
  check "tools(zsh/tmux/htop)"    test -x "$TOOLS_ENV/bin/zsh" -a -x "$TOOLS_ENV/bin/tmux" -a -x "$TOOLS_ENV/bin/htop"
  check "oh-my-zsh"               test -d "$HOME/.oh-my-zsh"
  check "nvm"                     test -d "$HOME/.nvm"
  check "tmux 配置"                test -f "$HOME/.tmux.conf"
  check "codex"                   command -v codex
  check "cc-switch"               command -v cc-switch
  check "zoxide"                  command -v zoxide
  check "projects 软链"            test -L "$PROJECTS_LINK"
  echo ""
}

# ------------------- 8. 代理设置（export + 持久化到 .zshrc） --------------
setup_proxy() {
  if [ "$PROXY_ENABLED" != "1" ]; then
    warn "已禁用代理（PROXY_ENABLED=0），跳过"
    return 0
  fi

  local proxy="$PROXY_HOST:$PROXY_PORT"
  # 代理连通性探测
  if ! timeout 3 bash -c "exec 3<>/dev/tcp/$PROXY_HOST/$PROXY_PORT" 2>/dev/null; then
    warn "代理 $proxy 不可达，已跳过 export（防止联网安装卡死）"
    warn "请检查代理地址，或用 PROXY_ENABLED=0 关闭"
    return 0
  fi

  export http_proxy="$proxy"
  export https_proxy="$proxy"
  export HTTP_PROXY="$proxy"
  export HTTPS_PROXY="$proxy"
  log "已 export 代理：$proxy"

  persist_proxy_to_zshrc "$proxy"
}

# 幂等写入代理配置
persist_proxy_to_zshrc() {
  local proxy="$1"
  local zshrc="$HOME/.zshrc"
  local open="# >>> init.sh proxy >>>"
  local close="# <<< init.sh proxy <<<"
  local tmp="${zshrc}.proxy.tmp"

  [ -f "$zshrc" ] || touch "$zshrc"
  awk -v begin="$open" -v endm="$close" '
    $0==begin { skip=1 }
    skip && $0==endm { skip=0; next }
    !skip { print }
  ' "$zshrc" > "$tmp" && mv "$tmp" "$zshrc"

  cat >> "$zshrc" <<EOF

$open
export http_proxy=$proxy
export https_proxy=$proxy
export HTTP_PROXY=$proxy
export HTTPS_PROXY=$proxy
$close
EOF
  ok "已写入 ~/.zshrc（幂等覆盖，无残留旧块）"
}

# ------------------- 9. 在 SSD 创建 projects 并软链到 $HOME --------------
setup_projects() {
  log "准备项目目录：SSD=$SSD_PROJECTS -> $PROJECTS_LINK"
  # 创建 SSD 项目软链
  mkdir -p "$SSD_PROJECTS"

  if [ -L "$PROJECTS_LINK" ]; then
    ok "软链已存在：$PROJECTS_LINK -> $(readlink "$PROJECTS_LINK")"
  elif [ -d "$PROJECTS_LINK" ] && [ ! -L "$PROJECTS_LINK" ]; then
    warn "$PROJECTS_LINK 是真实目录，跳过软链（避免覆盖已有数据）"
  else
    ln -s "$SSD_PROJECTS" "$PROJECTS_LINK"
    ok "已创建软链：$PROJECTS_LINK -> $SSD_PROJECTS"
  fi
}

# ================================= 主流程 =====================================
main() {
  log "开始工具配置初始化"
  check_installed       # 预检：已安装的将自动跳过
  setup_proxy           # 先 export 代理，防止后面联网安装失败
  install_miniconda
  install_uv
  make_tools_env
  install_ohmyzsh
  # 安装项目版 .zshrc
  install_zshrc_config
  setup_shell_switch      # 让 source bashrc / 新开 bash 自动进 zsh
  install_node
  setup_tmux
  setup_projects
  install_agents

  # 固化工具 PATH
  line='export PATH="$HOME/.local/bin:$PATH"'
  if ! grep -qF "$line" "$HOME/.bashrc" 2>/dev/null; then
    echo "$line" >> "$HOME/.bashrc"
  fi

  ok "全部完成！建议：source ~/.bashrc 或重新登录，然后 exec zsh 进入 zsh。"

  # 如需 IPython 配置，可在此扩展
  warn "如需要 IPython/gpustat：conda install -n tools -c conda-forge ipython gpustat"
}

main "$@"
