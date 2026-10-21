#!/usr/bin/env bash
MODULE_ID="uv"
MODULE_NAME="uv"
MODULE_DESCRIPTION="高速 Python 包与环境管理器"
MODULE_DEFAULT=1
MODULE_REQUIRES=""
MODULE_NEEDS_NETWORK=1
MODULE_PROBE_URLS=("https://astral.sh/uv/install.sh")

uv_is_installed() {
  command -v uv >/dev/null 2>&1
}

uv_install() {
  add_local_bin_to_path
  if uv_is_installed; then
    ok "uv 已安装：$(uv --version)"
    return 0
  fi

  log "安装 uv"
  if ! command -v curl >/dev/null 2>&1; then
    error "缺少 curl，无法安装 uv"
    return 1
  fi
  curl -LsSf --connect-timeout 10 --max-time 180 https://astral.sh/uv/install.sh | sh
  add_local_bin_to_path
  uv_is_installed || { error "uv 安装后未找到可执行文件"; return 1; }
  ok "uv 已安装：$(uv --version)"
}
