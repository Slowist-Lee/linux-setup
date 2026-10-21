#!/usr/bin/env bash
MODULE_ID="cc-switch"
MODULE_NAME="cc-switch"
MODULE_DESCRIPTION="Claude/Codex 配置切换 TUI"
MODULE_DEFAULT=1
MODULE_REQUIRES=""
MODULE_NEEDS_NETWORK=1
MODULE_PROBE_URLS=("https://github.com/saladday/cc-switch-cli/releases/latest")

cc_switch_is_installed() {
  command -v cc-switch-tui >/dev/null 2>&1 || command -v cc-switch >/dev/null 2>&1
}

cc_switch_install() {
  add_local_bin_to_path
  if cc_switch_is_installed; then
    ok "cc-switch 已安装：$(command -v cc-switch-tui || command -v cc-switch)"
    return 0
  fi

  log "安装 cc-switch"
  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$LOCAL_BIN"
  if ! curl -fL --connect-timeout 10 --max-time 240 \
      -o "$tmpdir/cc-switch.tgz" \
      "https://github.com/saladday/cc-switch-cli/releases/latest/download/cc-switch-cli-linux-x64-musl.tar.gz"; then
    rm -rf -- "$tmpdir"
    error "cc-switch 下载失败"
    return 1
  fi
  if ! tar -xzf "$tmpdir/cc-switch.tgz" -C "$tmpdir"; then
    rm -rf -- "$tmpdir"
    error "cc-switch 压缩包解压失败"
    return 1
  fi
  if [ -f "$tmpdir/cc-switch-tui" ]; then
    install -m 0755 "$tmpdir/cc-switch-tui" "$LOCAL_BIN/cc-switch-tui"
  elif [ -f "$tmpdir/cc-switch" ]; then
    install -m 0755 "$tmpdir/cc-switch" "$LOCAL_BIN/cc-switch-tui"
  else
    rm -rf -- "$tmpdir"
    error "cc-switch 压缩包中未找到可执行文件"
    return 1
  fi
  rm -rf -- "$tmpdir"
  cc_switch_is_installed || { error "cc-switch 安装校验失败"; return 1; }
  ok "cc-switch 已安装"
}
