#!/usr/bin/env bash
MODULE_ID="shell-switch"
MODULE_NAME="bash → zsh"
MODULE_DESCRIPTION="交互式 bash 自动进入 tools 环境的 zsh"
MODULE_DEFAULT=1
MODULE_REQUIRES="tools-env"
MODULE_NEEDS_NETWORK=0
MODULE_PROBE_URLS=()

shell_switch_is_installed() {
  grep -qF 'exec zsh' "$HOME/.bashrc" 2>/dev/null \
    && grep -qF "$TOOLS_ENV/bin" "$HOME/.bashrc" 2>/dev/null
}

shell_switch_install() {
  local bashrc="$HOME/.bashrc"
  local begin="# >>> linux-setup shell switch >>>"
  local end="# <<< linux-setup shell switch <<<"
  local content

  touch "$bashrc"
  content="export PATH=\"$TOOLS_ENV/bin:\$HOME/.local/bin:\$PATH\"
if [ -n \"\$PS1\" ]; then
  exec zsh
fi"
  remove_managed_block "$bashrc" "$begin" "$end"
  {
    printf '\n%s\n%s\n%s\n' "$begin" "$content" "$end"
  } >> "$bashrc"
  ok "已写入交互式 bash 自动进入 zsh 的配置"
}
