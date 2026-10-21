#!/usr/bin/env bash
MODULE_ID="pi"
MODULE_NAME="pi coding agent"
MODULE_DESCRIPTION="pi coding agent CLI（不安装 pi-sandbox/PriorKernelGen 扩展）"
MODULE_DEFAULT="${CUSTOM_TOOLS_ENABLED}"
MODULE_REQUIRES="nvm-node"
MODULE_NEEDS_NETWORK=1
MODULE_PROBE_URLS=("https://registry.npmjs.org/@earendil-works%2fpi-coding-agent")

pi_is_installed() {
  command -v pi >/dev/null 2>&1
}

pi_install() {
  export NVM_DIR="$HOME/.nvm"
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck disable=SC1090
    . "$NVM_DIR/nvm.sh"
  fi

  if command -v npm >/dev/null 2>&1 && ! command -v pi >/dev/null 2>&1; then
    log "安装 pi coding agent"
    npm i -g @earendil-works/pi-coding-agent || { error "pi 安装失败"; return 1; }
  elif command -v pi >/dev/null 2>&1; then
    ok "pi 已安装：$(command -v pi)"
  else
    error "npm 不可用，无法安装 pi"
    return 1
  fi

  ok "pi coding agent 安装完成（未安装自定义扩展）"
}
