#!/usr/bin/env bash
MODULE_ID="zshrc"
MODULE_NAME="统一 zsh 配置"
MODULE_DESCRIPTION="安装项目内置的 ~/.zshrc（自动备份旧文件）"
MODULE_DEFAULT=1
MODULE_REQUIRES="oh-my-zsh"
MODULE_NEEDS_NETWORK=0
MODULE_PROBE_URLS=()

zshrc_is_installed() {
  local tmp rc=0
  [ -f "$ZSHRC_TEMPLATE" ] && [ -f "$HOME/.zshrc" ] || return 1
  tmp="$(mktemp)"
  cp "$HOME/.zshrc" "$tmp"
  remove_managed_block "$tmp" "$PROXY_BLOCK_BEGIN" "$PROXY_BLOCK_END"
  cmp -s "$ZSHRC_TEMPLATE" "$tmp" || rc=1
  rm -f -- "$tmp"
  return "$rc"
}

zshrc_install() {
  if [ ! -f "$ZSHRC_TEMPLATE" ]; then
    error "zshrc 模板不存在：$ZSHRC_TEMPLATE"
    return 1
  fi
  if cmp -s "$ZSHRC_TEMPLATE" "$HOME/.zshrc" 2>/dev/null; then
    ok "~/.zshrc 已是项目配置（跳过）"
    return 0
  fi
  if [ -f "$HOME/.zshrc" ]; then
    local backup="$HOME/.zshrc.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$HOME/.zshrc" "$backup"
    ok "已备份原 ~/.zshrc -> $backup"
  fi
  install -m 0644 "$ZSHRC_TEMPLATE" "$HOME/.zshrc"
  ok "已安装项目版 ~/.zshrc"
}
