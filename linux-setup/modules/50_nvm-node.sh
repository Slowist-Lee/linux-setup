#!/usr/bin/env bash
MODULE_ID="nvm-node"
MODULE_NAME="nvm + Node.js"
MODULE_DESCRIPTION="nvm 版本管理，默认安装 Node ${NODE_DEFAULT}"
MODULE_DEFAULT=1
MODULE_REQUIRES=""
MODULE_NEEDS_NETWORK=1
MODULE_PROBE_URLS=(
  "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh"
  "https://nodejs.org/dist/"
)

nvm_node_is_installed() {
  [ -s "$HOME/.nvm/nvm.sh" ] || return 1
  (
    # shellcheck disable=SC1090
    . "$HOME/.nvm/nvm.sh"
    command -v node >/dev/null 2>&1 && node -v >/dev/null 2>&1
  )
}

nvm_node_install() {
  export NVM_DIR="$HOME/.nvm"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    log "安装 nvm $NVM_VERSION"
    if ! command -v curl >/dev/null 2>&1; then
      error "缺少 curl，无法安装 nvm"
      return 1
    fi
    curl -o- --connect-timeout 10 --max-time 180 \
      "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
  else
    ok "nvm 已安装（跳过安装脚本）"
  fi

  # shellcheck disable=SC1090
  . "$NVM_DIR/nvm.sh"
  log "安装 Node.js $NODE_DEFAULT"
  nvm install "$NODE_DEFAULT" || return 1
  nvm alias default "$NODE_DEFAULT" || return 1
  nvm use "$NODE_DEFAULT" >/dev/null || return 1
  ok "node: $(node -v 2>/dev/null || echo 未知)"
}
