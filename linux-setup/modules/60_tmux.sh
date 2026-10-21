#!/usr/bin/env bash
MODULE_ID="tmux"
MODULE_NAME="tmux 配置"
MODULE_DESCRIPTION="状态栏颜色与鼠标支持"
MODULE_DEFAULT=1
MODULE_REQUIRES="tools-env"
MODULE_NEEDS_NETWORK=0
MODULE_PROBE_URLS=()

tmux_is_installed() {
  [ -f "$HOME/.tmux.conf" ]
}

tmux_install() {
  if [ -f "$HOME/.tmux.conf" ]; then
    ok "~/.tmux.conf 已存在（保留用户配置）"
    return 0
  fi
  log "写入 ~/.tmux.conf"
  cat > "$HOME/.tmux.conf" <<'TMUX'
set -g status-style "bg=#4c7ccc, fg=black"
set mouse on
TMUX
  ok "tmux 配置完成"
}
