#!/usr/bin/env bash
MODULE_ID="codex-feishu-notice"
MODULE_NAME="Codex Feishu Notice 插件"
MODULE_DESCRIPTION="飞书通知脚本与 Codex marketplace 插件注册"
MODULE_DEFAULT="${CUSTOM_TOOLS_ENABLED}"
MODULE_REQUIRES="codex"
MODULE_NEEDS_NETWORK=0
MODULE_PROBE_URLS=()

codex_feishu_notice_is_installed() {
  [ -x "$LOCAL_BIN/codex-feishu-notice" ]
}

codex_feishu_notice_install() {
  local root="$CODEX_FEISHU_NOTICE_ROOT"
  local config_dir="$HOME/.config/codex-feishu-notice"
  local config_file="$config_dir/config.json"

  if [ ! -f "$root/scripts/install_skill.py" ]; then
    warn "codex-feishu-notice 项目不存在：$root（跳过）"
    return 0
  fi

  mkdir -p "$config_dir"
  if [ ! -f "$config_file" ] && [ -f "$root/config.example.json" ]; then
    cp "$root/config.example.json" "$config_file"
    warn "已创建 $config_file，请填写 webhook_url / signing_secret"
  fi
  [ -f "$config_file" ] && chmod 600 "$config_file"

  if python3 "$root/scripts/install_skill.py" >/dev/null 2>&1; then
    ok "用户级 notice skill 已安装"
  else
    warn "用户级 notice skill 安装失败"
  fi

  write_managed_file "$LOCAL_BIN/codex-feishu-notice" 0755 <<WRAPPER
#!/usr/bin/env bash
exec python3 "$root/scripts/notice.py" "\$@"
WRAPPER

  add_local_bin_to_path
  if ! command -v codex >/dev/null 2>&1; then
    warn "Codex 不可用，跳过插件注册"
    return 0
  fi
  if [ ! -f "$SSD_PROJECTS/.agents/plugins/marketplace.json" ]; then
    warn "未找到本地 marketplace：$SSD_PROJECTS/.agents/plugins/marketplace.json"
    return 0
  fi

  if ! codex plugin marketplace list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -qx 'projects-local'; then
    if codex plugin marketplace add "$SSD_PROJECTS" >/dev/null 2>&1; then
      ok "已注册 Codex marketplace：projects-local"
    else
      warn "Codex marketplace 注册失败"
    fi
  else
    ok "Codex marketplace 已注册"
  fi

  if codex plugin list --marketplace projects-local 2>/dev/null | grep -q 'codex-feishu-notice@projects-local'; then
    ok "codex-feishu-notice 插件已安装"
  elif codex plugin add codex-feishu-notice@projects-local >/dev/null 2>&1; then
    ok "codex-feishu-notice 插件已安装"
  else
    warn "codex-feishu-notice 插件安装失败"
  fi
  warn "插件的 UserPromptSubmit/Stop hooks 需要在 Codex 的 /hooks 中确认信任"
}
