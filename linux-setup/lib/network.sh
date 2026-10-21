#!/usr/bin/env bash
# Mandatory external-network gate and proxy configuration.

NETWORK_FAILURES=()
NETWORK_RESULTS=()
NETWORK_PROXY_TO_SAVE=""
NETWORK_SAVE_PROXY=0
NETWORK_ACTIVE_ROUTE=""
NETWORK_ACTIVE_PROXY=""
PROXY_BLOCK_BEGIN="# >>> linux-setup managed proxy >>>"
PROXY_BLOCK_END="# <<< linux-setup managed proxy <<<"

network_clear_proxy() {
  unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
  export NO_PROXY="$NO_PROXY_VALUE"
  export no_proxy="$NO_PROXY_VALUE"
}

network_current_proxy() {
  printf '%s' "${https_proxy:-${HTTPS_PROXY:-${http_proxy:-${HTTP_PROXY:-${all_proxy:-${ALL_PROXY:-}}}}}}"
}

network_mask_proxy() {
  local proxy="$1"
  printf '%s' "$proxy" | sed -E 's#(://)[^/@[:space:]]+@#\1***@#g'
}

network_normalize_proxy() {
  local proxy="${1#"${1%%[![:space:]]*}"}"
  proxy="${proxy%"${proxy##*[![:space:]]}"}"
  [ -n "$proxy" ] || return 1
  case "$proxy" in
    *://*) ;;
    *) proxy="http://$proxy" ;;
  esac
  printf '%s\n' "$proxy"
}

network_set_proxy() {
  local proxy
  proxy="$(network_normalize_proxy "$1")" || return 1
  export http_proxy="$proxy"
  export https_proxy="$proxy"
  export HTTP_PROXY="$proxy"
  export HTTPS_PROXY="$proxy"
  unset all_proxy ALL_PROXY
  export NO_PROXY="$NO_PROXY_VALUE"
  export no_proxy="$NO_PROXY_VALUE"
  printf '%s\n' "$proxy"
}

_network_http_code_ok() {
  [[ "$1" =~ ^[23][0-9][0-9]$ ]]
}

_network_probe_url() {
  local url="$1"
  local code="" rc=0 err="" errfile

  if command -v curl >/dev/null 2>&1; then
    errfile="$(mktemp)"
    code="$(curl -L -sS -o /dev/null \
      --connect-timeout "$NETWORK_CONNECT_TIMEOUT" \
      --max-time "$NETWORK_MAX_TIME" \
      --range 0-0 -w '%{http_code}' "$url" 2>"$errfile")" || rc=$?
    if [ "$rc" -eq 0 ] && _network_http_code_ok "$code"; then
      printf 'HTTP %s\n' "$code"
      rm -f -- "$errfile"
      return 0
    fi
    if [ "$rc" -ne 0 ]; then
      err="$(tail -n 1 "$errfile" 2>/dev/null || true)"
      printf '%s\n' "${err:-curl 退出码 $rc}"
    else
      printf 'HTTP %s\n' "$code"
    fi
    rm -f -- "$errfile"
    return 1
  fi

  if command -v wget >/dev/null 2>&1; then
    if wget -q --spider --timeout="$NETWORK_MAX_TIME" --tries=1 "$url" >/dev/null 2>&1; then
      printf 'reachable\n'
      return 0
    fi
    printf 'wget 检测失败\n'
  fi
  return 1
}

_network_probe_with_curl() {
  local url="$1"
  shift
  local code="" rc=0 errfile attempt

  command -v curl >/dev/null 2>&1 || return 1
  for ((attempt = 1; attempt <= NETWORK_DISCOVERY_ATTEMPTS; attempt++)); do
    rc=0
    errfile="$(mktemp)"
    code="$(curl -L -sS -o /dev/null \
      --connect-timeout "$NETWORK_DISCOVERY_CONNECT_TIMEOUT" \
      --max-time "$NETWORK_DISCOVERY_MAX_TIME" \
      --range 0-0 -w '%{http_code}' "$@" "$url" 2>"$errfile")" || rc=$?
    rm -f -- "$errfile"
    if [ "$rc" -eq 0 ] && _network_http_code_ok "$code"; then
      return 0
    fi
    [ "$attempt" -lt "$NETWORK_DISCOVERY_ATTEMPTS" ] && sleep 1
  done
  return 1
}

network_probe_via_proxy() {
  local proxy
  proxy="$(network_normalize_proxy "$1")" || return 1
  _network_probe_with_curl "$NETWORK_PROXY_PROBE_URL" --proxy "$proxy" --noproxy ''
}

network_probe_direct() {
  _network_probe_with_curl "$NETWORK_PROXY_PROBE_URL" --noproxy '*'
}

# Prefer the inherited proxy, then common local proxy ports, then direct access.
# The chosen route is exported to this process so installers use the same path.
network_prepare_connectivity() {
  local current candidate

  NETWORK_ACTIVE_ROUTE=""
  NETWORK_ACTIVE_PROXY=""
  current="$(network_current_proxy)"

  if [ -n "$current" ] && network_probe_via_proxy "$current"; then
    NETWORK_ACTIVE_ROUTE="proxy"
    NETWORK_ACTIVE_PROXY="$current"
    return 0
  fi

  for candidate in $NETWORK_PROXY_CANDIDATES; do
    candidate="$(network_normalize_proxy "$candidate")" || continue
    [ "$candidate" = "$current" ] && continue
    if network_probe_via_proxy "$candidate"; then
      network_set_proxy "$candidate" >/dev/null
      NETWORK_ACTIVE_ROUTE="proxy"
      NETWORK_ACTIVE_PROXY="$candidate"
      return 0
    fi
  done

  if network_probe_direct; then
    network_clear_proxy
    NETWORK_ACTIVE_ROUTE="direct"
    return 0
  fi
  return 1
}

# Check URLs in parallel. Sets NETWORK_FAILURES and returns non-zero if any fail.
network_check_urls() {
  local -a urls=("$@")
  local -a pids=()
  local -a result_files=()
  local tmpdir i rc=0

  NETWORK_FAILURES=()
  NETWORK_RESULTS=()
  if [ "${#urls[@]}" -eq 0 ]; then
    urls=("https://github.com/")
  fi
  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    NETWORK_FAILURES+=("缺少 curl 或 wget，无法检测网络")
    return 1
  fi

  tmpdir="$(mktemp -d)"
  for i in "${!urls[@]}"; do
    result_files[$i]="$tmpdir/$i"
    (
      if _network_probe_url "${urls[$i]}" >"${result_files[$i]}" 2>&1; then
        exit 0
      fi
      exit 1
    ) &
    pids[$i]=$!
  done

  for i in "${!urls[@]}"; do
    if ! wait "${pids[$i]}"; then
      rc=1
      local detail="unreachable"
      [ -s "${result_files[$i]}" ] && detail="$(head -n 1 "${result_files[$i]}")"
      NETWORK_FAILURES+=("${urls[$i]} — $detail")
    else
      local detail="reachable"
      [ -s "${result_files[$i]}" ] && detail="$(head -n 1 "${result_files[$i]}")"
      NETWORK_RESULTS+=("${urls[$i]} — $detail")
    fi
  done
  rm -rf -- "$tmpdir"
  return "$rc"
}

network_failure_text() {
  local text="以下外网地址无法访问：\n"
  local item
  for item in "${NETWORK_FAILURES[@]}"; do
    text+="\n  • $item"
  done
  text+="\n\n安装尚未开始。请配置代理或修复网络后重新检测；检测通过前不会继续安装。"
  printf '%b' "$text"
}

network_clear_saved_proxy() {
  rm -f -- "$PROXY_CONFIG_FILE"
  remove_managed_block "$HOME/.bashrc" "$PROXY_BLOCK_BEGIN" "$PROXY_BLOCK_END"
  remove_managed_block "$HOME/.zshrc" "$PROXY_BLOCK_BEGIN" "$PROXY_BLOCK_END"
  network_clear_proxy
  NETWORK_SAVE_PROXY=0
  NETWORK_PROXY_TO_SAVE=""
}

network_ensure_rc_proxy_source() {
  local rc_content="if [ -r \"$PROXY_CONFIG_FILE\" ]; then . \"$PROXY_CONFIG_FILE\"; fi"
  prepend_managed_block "$HOME/.bashrc" "$PROXY_BLOCK_BEGIN" "$PROXY_BLOCK_END" "$rc_content"
  prepend_managed_block "$HOME/.zshrc" "$PROXY_BLOCK_BEGIN" "$PROXY_BLOCK_END" "$rc_content"
}

network_persist_proxy() {
  local proxy="${NETWORK_PROXY_TO_SAVE:-}"

  mkdir -p "$PROXY_CONFIG_DIR"
  chmod 700 "$PROXY_CONFIG_DIR" 2>/dev/null || true

  if [ -n "$proxy" ]; then
    {
      printf 'export http_proxy=%q\n' "$proxy"
      printf 'export https_proxy=%q\n' "$proxy"
      printf 'export HTTP_PROXY=%q\n' "$proxy"
      printf 'export HTTPS_PROXY=%q\n' "$proxy"
      printf 'export NO_PROXY=%q\n' "$NO_PROXY_VALUE"
      printf 'export no_proxy=%q\n' "$NO_PROXY_VALUE"
    } > "$PROXY_CONFIG_FILE"
    chmod 600 "$PROXY_CONFIG_FILE"
  else
    rm -f -- "$PROXY_CONFIG_FILE"
  fi

  network_ensure_rc_proxy_source
  if [ -n "$proxy" ]; then
    ok "代理配置已写入 $PROXY_CONFIG_FILE（权限 600）及 shell rc 文件"
  else
    ok "已清除代理配置"
  fi
}

network_configure_proxy_tui() {
  local current default value normalized
  current="$(network_current_proxy)"
  default="${current:-http://127.0.0.1:7890}"
  if ! value="$(tui_inputbox "配置外网代理" \
      "请输入 HTTP(S) 代理地址。\n\n支持格式：\n  http://host:port\n  host:port\n\n输入 none 可清除当前代理并使用直连。" \
      "$default")"; then
    return 1
  fi

  if [ "$value" = "none" ] || [ -z "$value" ]; then
    network_clear_saved_proxy
    warn "已清除当前代理，将使用直连重试"
    return 0
  fi
  if ! normalized="$(network_set_proxy "$value")"; then
    tui_msgbox "代理格式错误" "无法识别代理地址：$value"
    return 1
  fi
  NETWORK_PROXY_TO_SAVE="$normalized"
  if tui_yesno "保存代理配置" \
      "代理已设置：$normalized\n\n是否保存到 $PROXY_CONFIG_FILE，并在以后登录 shell 时自动加载？"; then
    NETWORK_SAVE_PROXY=1
  else
    NETWORK_SAVE_PROXY=0
  fi
  return 0
}

# Enforce connectivity. Interactive mode keeps prompting until the user exits.
network_require() {
  local -a urls=("$@")
  local choice

  while true; do
    if network_prepare_connectivity; then
      if [ "$NETWORK_ACTIVE_ROUTE" = "proxy" ]; then
        ok "使用代理 $(network_mask_proxy "$NETWORK_ACTIVE_PROXY")"
      else
        warn "未使用代理，当前为直连"
      fi
    else
      warn "未自动找到可用代理，将按当前环境继续检测"
    fi
    tui_infobox "正在并行检测外网连通性，请稍候…"
    if network_check_urls "${urls[@]}"; then
      ok "外网连通性检测通过（${#urls[@]} 个目标）"
      return 0
    fi

    error "外网连通性检测失败"
    printf '%s\n' "${NETWORK_FAILURES[@]}" >&2
    if ! tui_is_interactive; then
      printf '%s\n' "$(network_failure_text)" >&2
      return 1
    fi

    tui_msgbox "网络未连通" "$(network_failure_text)" || true
    if ! choice="$(tui_menu "网络未连通" \
        "请选择下一步。网络恢复前不会开始安装。" \
        retry "重新检测" \
        proxy "配置 HTTP(S) 代理" \
        direct "清除代理并使用直连" \
        quit "退出安装")"; then
      return 1
    fi
    case "$choice" in
      retry) ;;
      proxy) network_configure_proxy_tui || true ;;
      direct) network_clear_saved_proxy ;;
      quit) return 1 ;;
    esac
  done
}
