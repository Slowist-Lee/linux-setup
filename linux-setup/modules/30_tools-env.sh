#!/usr/bin/env bash
MODULE_ID="tools-env"
MODULE_NAME="tools 环境"
MODULE_DESCRIPTION="zsh / tmux / htop（conda-forge）"
MODULE_DEFAULT=1
MODULE_REQUIRES="miniconda"
MODULE_NEEDS_NETWORK=1
MODULE_PROBE_URLS=("https://conda.anaconda.org/conda-forge/")

tools_env_is_installed() {
  [ -x "$TOOLS_ENV/bin/zsh" ] && [ -x "$TOOLS_ENV/bin/tmux" ] && [ -x "$TOOLS_ENV/bin/htop" ]
}

_conda_config_append_once() {
  local key="$1"
  local value="$2"
  if ! conda config --get "$key" 2>/dev/null | grep -Fxq -- "- $value"; then
    conda config --append "$key" "$value" || true
  fi
}

tools_env_install() {
  if [ ! -x "$CONDA_ROOT/bin/conda" ]; then
    error "Miniconda 未安装，无法创建 tools 环境"
    return 1
  fi
  # shellcheck disable=SC1091
  . "$CONDA_ROOT/etc/profile.d/conda.sh"

  log "接受 Anaconda 默认 channel ToS（旧版 conda 无此命令时忽略）"
  conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2>/dev/null || true
  conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r 2>/dev/null || true

  mkdir -p "$CONDA_ENVS" "$CONDA_PKGS"
  _conda_config_append_once envs_dirs "$CONDA_ENVS"
  _conda_config_append_once pkgs_dirs "$CONDA_PKGS"

  if tools_env_is_installed; then
    ok "tools 环境已就绪（$TOOLS_ENV，跳过）"
  else
    log "准备 tools conda 环境（zsh / tmux / htop）"
    conda create -n tools -y || true
    if ! conda install -n tools -c conda-forge zsh tmux htop -y; then
      error "tools conda 环境安装失败"
      return 1
    fi
  fi

  if ! path_contains_dir "$TOOLS_ENV/bin"; then
    export PATH="$TOOLS_ENV/bin:$PATH"
  fi
  tools_env_is_installed || { error "tools 环境缺少 zsh/tmux/htop"; return 1; }
  ok "zsh: $(command -v zsh)  tmux: $(command -v tmux)  htop: $(command -v htop)"
}
