#!/usr/bin/env bash
MODULE_ID="codex-feishu-agent"
MODULE_NAME="Codex Feishu Agent"
MODULE_DESCRIPTION="飞书机器人 Agent、Python 依赖及启动命令"
MODULE_DEFAULT="${CUSTOM_TOOLS_ENABLED}"
MODULE_REQUIRES="uv"
MODULE_NEEDS_NETWORK=1
MODULE_PROBE_URLS=("https://pypi.org/simple/")

codex_feishu_agent_is_installed() {
  [ -x "$LOCAL_BIN/codex-feishu-agent" ] \
    && [ -x "$CODEX_FEISHU_AGENT_ROOT/.venv/bin/python" ] \
    && "$CODEX_FEISHU_AGENT_ROOT/.venv/bin/python" -c 'import lark_oapi' >/dev/null 2>&1
}

codex_feishu_agent_install() {
  local root="$CODEX_FEISHU_AGENT_ROOT"
  local config_dir="$HOME/.config/codex-feishu-agent"
  local config_file="$config_dir/config.json"

  if [ ! -f "$root/scripts/setup.sh" ]; then
    warn "codex-feishu-agent 项目不存在：$root（跳过）"
    return 0
  fi

  add_local_bin_to_path
  if [ -x "$root/.venv/bin/python" ] \
      && "$root/.venv/bin/python" -c 'import lark_oapi' >/dev/null 2>&1; then
    ok "Feishu Agent Python 环境已就绪"
  elif command -v uv >/dev/null 2>&1; then
    log "安装 Feishu Agent Python 依赖"
    (cd "$root" && bash scripts/setup.sh) || { error "Feishu Agent 依赖安装失败"; return 1; }
  else
    error "uv 不可用，无法安装 Feishu Agent"
    return 1
  fi

  mkdir -p "$config_dir" "$HOME/.local/share/codex-feishu-agent"
  if [ ! -f "$config_file" ] && [ -f "$root/config.example.json" ]; then
    cp "$root/config.example.json" "$config_file"
    warn "已创建 $config_file，请填写 app_id / app_secret"
  fi
  [ -f "$config_file" ] && chmod 600 "$config_file"

  write_managed_file "$LOCAL_BIN/codex-feishu-agent" 0755 <<WRAPPER
#!/usr/bin/env bash
exec bash "$root/scripts/run_tmux.sh" "\$@"
WRAPPER
  write_managed_file "$LOCAL_BIN/codex-feishu-agent-stop" 0755 <<WRAPPER
#!/usr/bin/env bash
exec bash "$root/scripts/stop_tmux.sh" "\$@"
WRAPPER
  write_managed_file "$LOCAL_BIN/codex-feishu-agent-status" 0755 <<WRAPPER
#!/usr/bin/env bash
exec bash "$root/scripts/status_tmux.sh" "\$@"
WRAPPER
  ok "Feishu Agent 命令：codex-feishu-agent / -stop / -status"
}
