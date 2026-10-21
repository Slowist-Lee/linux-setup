#!/usr/bin/env bash
MODULE_ID="codex"
MODULE_NAME="Codex CLI + wrappers"
MODULE_DESCRIPTION="OpenAI Codex CLI，以及 HPC 直连/后台运行 wrapper"
MODULE_DEFAULT=1
MODULE_REQUIRES=""
MODULE_NEEDS_NETWORK=1
MODULE_PROBE_URLS=("https://chatgpt.com/codex/install.sh")

codex_is_installed() {
  [ -x "$LOCAL_BIN/codex" ] \
    && [ -x "$LOCAL_BIN/codex.real" ] \
    && "$LOCAL_BIN/codex" --version >/dev/null 2>&1
}

_codex_find_real() {
  local candidate
  if [ -n "${CODEX_BIN_REAL:-}" ] && [ -x "$CODEX_BIN_REAL" ]; then
    printf '%s\n' "$CODEX_BIN_REAL"
    return 0
  fi
  for candidate in \
      "$LOCAL_BIN/codex.real" \
      "$LOCAL_BIN/codex.bin" \
      /usr/local/bin/codex \
      /usr/bin/codex; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  if [ -x "$LOCAL_BIN/codex" ] \
      && ! grep -qF 'linux-setup managed codex wrapper' "$LOCAL_BIN/codex" 2>/dev/null; then
    mv -f "$LOCAL_BIN/codex" "$LOCAL_BIN/codex.bin"
    printf '%s\n' "$LOCAL_BIN/codex.bin"
    return 0
  fi
  return 1
}

_codex_install_wrappers() {
  local codex_actual
  if ! codex_actual="$(_codex_find_real)"; then
    error "未找到 Codex 真实可执行文件"
    return 1
  fi

  write_managed_file "$LOCAL_BIN/codex.real" 0755 <<WRAPPER
#!/usr/bin/env bash
# Managed by linux-setup. The real CLI is: $codex_actual
set -euo pipefail
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
export NO_PROXY="hpc.westlake.edu.cn,hpc-api.westlake.edu.cn,.westlake.edu.cn"
export no_proxy="\$NO_PROXY"

REAL_CODEX="\${CODEX_BIN_REAL:-$codex_actual}"

if [ "\${1:-}" = "research" ]; then
  shift
  dir="\$PWD"
  project_root=""
  while [ "\$dir" != "/" ]; do
    if [ -d "\$dir/AI-WorkSpace" ]; then
      project_root="\$dir"
      break
    fi
    dir="\$(dirname "\$dir")"
  done
  if [ -z "\$project_root" ]; then
    echo "codex research: no AI-WorkSpace found in project ancestors" >&2
    exit 1
  fi
  workspace="\$(find -L "\$project_root/AI-WorkSpace" -mindepth 2 -maxdepth 2 -type d -printf '%P\\n' 2>/dev/null | sort | tail -1)"
  if [ -z "\$workspace" ]; then
    echo "codex research: no workspace found in \$project_root/AI-WorkSpace" >&2
    exit 1
  fi
  cd "\$project_root/AI-WorkSpace/\$workspace"
  exec "\$REAL_CODEX" --dangerously-bypass-approvals-and-sandbox "\$@"
fi

exec "\$REAL_CODEX" "\$@"
WRAPPER

  write_managed_file "$LOCAL_BIN/codex" 0755 <<'WRAPPER'
#!/usr/bin/env bash
# linux-setup managed codex wrapper: bypass proxy for HPC/Codex gateway.
set -euo pipefail
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
export NO_PROXY="hpc.westlake.edu.cn,hpc-api.westlake.edu.cn,.westlake.edu.cn"
export no_proxy="$NO_PROXY"
exec "$HOME/.local/bin/codex.real" "$@"
WRAPPER

  write_managed_file "$LOCAL_BIN/codex-direct" 0755 <<'WRAPPER'
#!/usr/bin/env bash
# linux-setup managed: alias for the no-proxy Codex wrapper.
set -euo pipefail
exec "$HOME/.local/bin/codex" "$@"
WRAPPER

  write_managed_file "$LOCAL_BIN/codex-noproxy" 0755 <<'WRAPPER'
#!/usr/bin/env bash
# linux-setup managed: compatibility alias for direct/no-proxy Codex.
set -euo pipefail
exec "$HOME/.local/bin/codex" "$@"
WRAPPER

  write_managed_file "$LOCAL_BIN/codex-detached" 0755 <<'WRAPPER'
#!/usr/bin/env bash
# linux-setup managed: start Codex in a detached tmux session.
set -euo pipefail
SESSION="codex-$(date +%Y%m%d-%H%M%S)"
if command -v tmux >/dev/null 2>&1; then
  tmux new-session -d -s "$SESSION" "$HOME/.local/bin/codex" "$@"
  echo "Codex started in tmux session: $SESSION"
  echo "Attach with: tmux attach-session -t $SESSION"
else
  LOG="/tmp/codex-detached-$(date +%Y%m%d-%H%M%S).log"
  nohup "$HOME/.local/bin/codex" "$@" >"$LOG" 2>&1 &
  echo "Codex started in background (pid $!); log: $LOG"
fi
WRAPPER
  ok "Codex wrappers 已安装：codex / codex.real / codex-direct / codex-noproxy / codex-detached"
}

codex_install() {
  add_local_bin_to_path
  if ! command -v codex >/dev/null 2>&1 || ! codex --version >/dev/null 2>&1; then
    log "安装 Codex CLI"
    if ! command -v curl >/dev/null 2>&1; then
      error "缺少 curl，无法安装 Codex CLI"
      return 1
    fi
    curl -fsSL --connect-timeout 10 --max-time 180 https://chatgpt.com/codex/install.sh | sh || return 1
    add_local_bin_to_path
  else
    ok "Codex CLI 已安装"
  fi
  _codex_install_wrappers || return 1
  codex_is_installed || { error "Codex wrapper 校验失败"; return 1; }
  ok "Codex CLI 与 wrappers 配置完成"
}
