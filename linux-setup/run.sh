#!/usr/bin/env bash
set -euo pipefail

SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export SETUP_ROOT

# shellcheck source=config/settings.sh
. "$SETUP_ROOT/config/settings.sh"
# shellcheck source=lib/common.sh
. "$SETUP_ROOT/lib/common.sh"
# shellcheck source=lib/tui.sh
. "$SETUP_ROOT/lib/tui.sh"
# shellcheck source=lib/network.sh
. "$SETUP_ROOT/lib/network.sh"

declare -A REG_NAME=()
declare -A REG_DESCRIPTION=()
declare -A REG_DEFAULT=()
declare -A REG_REQUIRES=()
declare -A REG_NEEDS_NETWORK=()
declare -A REG_PROBES=()
declare -A REG_INSTALL_FUNC=()
declare -A REG_STATUS_FUNC=()
MODULE_ORDER=()

register_module() {
  local id="$MODULE_ID"
  local fn_id="${id//-/_}"
  if [ -n "${REG_NAME[$id]:-}" ]; then
    die "重复的模块 ID：$id"
  fi
  MODULE_ORDER+=("$id")
  REG_NAME[$id]="$MODULE_NAME"
  REG_DESCRIPTION[$id]="$MODULE_DESCRIPTION"
  REG_DEFAULT[$id]="${MODULE_DEFAULT:-0}"
  REG_REQUIRES[$id]="${MODULE_REQUIRES:-}"
  REG_NEEDS_NETWORK[$id]="${MODULE_NEEDS_NETWORK:-0}"
  REG_PROBES[$id]="${MODULE_PROBE_URLS[*]:-}"
  REG_INSTALL_FUNC[$id]="${fn_id}_install"
  REG_STATUS_FUNC[$id]="${fn_id}_is_installed"

  if ! declare -F "${REG_INSTALL_FUNC[$id]}" >/dev/null; then
    die "模块 $id 缺少安装函数：${REG_INSTALL_FUNC[$id]}"
  fi
  if ! declare -F "${REG_STATUS_FUNC[$id]}" >/dev/null; then
    die "模块 $id 缺少状态函数：${REG_STATUS_FUNC[$id]}"
  fi
}

for module_file in "$SETUP_ROOT"/modules/[0-9]*.sh; do
  [ -f "$module_file" ] || continue
  unset MODULE_ID MODULE_NAME MODULE_DESCRIPTION MODULE_DEFAULT MODULE_REQUIRES MODULE_NEEDS_NETWORK MODULE_PROBE_URLS
  # shellcheck disable=SC1090
  . "$module_file"
  register_module
done

module_exists() {
  [ -n "${REG_NAME[$1]:-}" ]
}

module_is_installed() {
  local id="$1"
  "${REG_STATUS_FUNC[$id]}" >/dev/null 2>&1
}

module_status_label() {
  if module_is_installed "$1"; then
    printf '已安装'
  else
    printf '未安装'
  fi
}

module_network_urls() {
  local id="$1"
  local value="${REG_PROBES[$id]:-}"
  [ -n "$value" ] || return 0
  printf '%s\n' $value
}

print_module_list() {
  printf '%-24s %-10s %s\n' "ID" "状态" "工具"
  printf '%-24s %-10s %s\n' "------------------------" "----------" "------------------------------"
  local id
  for id in "${MODULE_ORDER[@]}"; do
    printf '%-24s %-10s %s\n' "$id" "$(module_status_label "$id")" "${REG_NAME[$id]}"
  done
}

# Resolve required modules. Uses the caller's `selected` and `expanded` arrays.
resolve_one_module() {
  local id="$1"
  local dep
  module_exists "$id" || die "未知模块：$id"
  [ -n "${expanded[$id]:-}" ] && return 0
  expanded[$id]=1
  for dep in ${REG_REQUIRES[$id]}; do
    resolve_one_module "$dep"
  done
  selected[$id]=1
}

normalize_selection_order() {
  local id
  for id in "${MODULE_ORDER[@]}"; do
    if [ -n "${selected[$id]:-}" ]; then
      printf '%s\n' "$id"
    fi
  done
}

select_modules_tui() {
  local -a args=()
  local id state output
  for id in "${MODULE_ORDER[@]}"; do
    state="OFF"
    [ "${REG_DEFAULT[$id]}" = "1" ] && state="ON"
    args+=("$id" "$(printf '%-20s [%s] %s' "${REG_NAME[$id]}" "$(module_status_label "$id")" "${REG_DESCRIPTION[$id]}")" "$state")
  done
  if ! output="$(tui_checklist "选择要安装的工具" \
      "输入编号切换选择，回车确认。已安装模块默认会跳过，可稍后选择强制重跑。\n\n依赖项会自动补齐。" \
      "${args[@]}")"; then
    return 1
  fi
  SELECTED_OUTPUT="$output"
}

show_plan() {
  local -a modules=("$@")
  local -a pending=()
  local text="已选择 ${#modules[@]} 个模块（含自动依赖）。\n"
  local id
  for id in "${modules[@]}"; do
    if [ "$FORCE_REINSTALL" = "1" ] || ! module_is_installed "$id"; then
      pending+=("$id")
    fi
  done
  if [ "${#pending[@]}" -eq 0 ]; then
    text+="\n所有模块均已安装，本轮将全部跳过。"
  else
    text+="\n待安装或重跑：${#pending[@]} 个"
    for id in "${pending[@]}"; do
      text+="\n  • ${REG_NAME[$id]}"
    done
  fi
  printf '%b\n' "$text"
}

network_urls_for_selection() {
  local -a modules=("$@")
  local -A seen=()
  local -a urls=()
  local id url
  if [ -n "${NETWORK_CHECK_URLS:-}" ]; then
    read -r -a urls <<< "$NETWORK_CHECK_URLS"
    printf '%s\n' "${urls[@]}"
    return 0
  fi
  for id in "${modules[@]}"; do
    if [ "${REG_NEEDS_NETWORK[$id]}" != "1" ]; then
      continue
    fi
    if [ "$FORCE_REINSTALL" != "1" ] && module_is_installed "$id"; then
      continue
    fi
    while IFS= read -r url; do
      [ -n "$url" ] || continue
      if [ -z "${seen[$url]:-}" ]; then
        seen[$url]=1
        urls+=("$url")
      fi
    done < <(module_network_urls "$id")
  done
  if [ "${#urls[@]}" -eq 0 ]; then
    urls=("https://github.com/")
  fi
  printf '%s\n' "${urls[@]}"
}

ensure_network_for_modules() {
  local -a modules=("$@")
  local -a urls=()
  local url
  while IFS= read -r url; do
    [ -n "$url" ] && urls+=("$url")
  done < <(network_urls_for_selection "${modules[@]}")
  network_require "${urls[@]}"
}

run_selected_modules() {
  local -a modules=("$@")
  local -a succeeded=() failed=() skipped=()
  local id func

  for id in "${modules[@]}"; do
    printf '\n%s━━━━ %s ━━━━%s\n' "$C_BLUE" "${REG_NAME[$id]}" "$C_RESET"
    if [ "$FORCE_REINSTALL" != "1" ] && module_is_installed "$id"; then
      ok "${REG_NAME[$id]} 已安装，跳过（可选择强制重跑）"
      skipped+=("$id")
      continue
    fi
    func="${REG_INSTALL_FUNC[$id]}"
    if "$func"; then
      succeeded+=("$id")
    else
      error "${REG_NAME[$id]} 安装失败"
      failed+=("$id")
    fi
  done

  FINAL_SUCCEEDED=("${succeeded[@]}")
  FINAL_FAILED=("${failed[@]}")
  FINAL_SKIPPED=("${skipped[@]}")
  [ "${#failed[@]}" -eq 0 ]
}

final_report() {
  local text="安装流程结束。\n"
  local id
  text+="\n成功：${#FINAL_SUCCEEDED[@]}"
  for id in "${FINAL_SUCCEEDED[@]}"; do text+="\n  ✔ ${REG_NAME[$id]}"; done
  if [ "${#FINAL_SKIPPED[@]}" -gt 0 ]; then
    text+="\n\n已安装跳过：${#FINAL_SKIPPED[@]}"
    for id in "${FINAL_SKIPPED[@]}"; do text+="\n  • ${REG_NAME[$id]}"; done
  fi
  if [ "${#FINAL_FAILED[@]}" -gt 0 ]; then
    text+="\n\n失败：${#FINAL_FAILED[@]}"
    for id in "${FINAL_FAILED[@]}"; do text+="\n  ✘ ${REG_NAME[$id]}"; done
    text+="\n\n可重新运行安装器，只勾选失败项。"
  else
    text+="\n\n建议重新登录，或执行：source ~/.bashrc"
  fi
  local rendered
  printf -v rendered '%b' "$text"
  printf '%s\n' "$rendered"
}

sync_network_profile() {
  if [ "$NETWORK_SAVE_PROXY" = "1" ]; then
    NETWORK_PROXY_TO_SAVE="$(network_current_proxy)"
    network_persist_proxy || warn "代理配置持久化失败"
  elif [ -f "$PROXY_CONFIG_FILE" ]; then
    network_ensure_rc_proxy_source || warn "代理 shell rc 同步失败"
  fi
}

interactive_flow() {
  local id
  local -A selected=()
  local -A expanded=()
  local -a requested=() modules=()

  tui_init
  if ! tui_is_interactive; then
    error "当前不是交互式终端。自动化请使用 --all、--only 或 --list。"
    return 1
  fi

  if ! select_modules_tui; then
    warn "已取消选择"
    return 1
  fi
  mapfile -t requested <<< "${SELECTED_OUTPUT:-}"
  for id in "${requested[@]}"; do
    [ -n "$id" ] && selected[$id]=1
  done
  if [ "${#selected[@]}" -eq 0 ]; then
    tui_msgbox "未选择工具" "没有勾选任何模块，安装未开始。"
    return 0
  fi

  for id in "${!selected[@]}"; do
    resolve_one_module "$id"
  done
  mapfile -t modules < <(normalize_selection_order)

  if [ "${#modules[@]}" -gt "${#requested[@]}" ]; then
    tui_msgbox "已自动补齐依赖" "依赖模块已加入安装计划，完整计划将在下一步确认。"
  fi

  FORCE_REINSTALL=0
  local -a installed=()
  for id in "${modules[@]}"; do
    module_is_installed "$id" && installed+=("$id")
  done
  if [ "${#installed[@]}" -gt 0 ]; then
    if tui_yesno "强制重跑？" \
        "计划中有 ${#installed[@]} 个已安装模块。\n\n是否强制重新执行这些模块？\n选择“否”将自动跳过已安装模块。" no; then
      FORCE_REINSTALL=1
    fi
  fi

  if ! tui_yesno "确认安装计划" "$(show_plan "${modules[@]}")\n\n下一步会先检测外网，检测不通过不会开始安装。" ; then
    return 0
  fi

  if ! ensure_network_for_modules "${modules[@]}"; then
    tui_msgbox "未开始安装" "外网仍未连通，安装流程已停止。请配置好网络后重新运行。"
    return 1
  fi
  sync_network_profile

  if ! run_selected_modules "${modules[@]}"; then
    final_report
    return 1
  fi
  sync_network_profile
  final_report
}

noninteractive_flow() {
  local -a requested=("${NONINTERACTIVE_MODULES[@]}")
  local -A selected=()
  local -A expanded=()
  local -a modules=()
  local id

  if [ "${#requested[@]}" -eq 0 ]; then
    error "--all/--only 模式没有选择模块"
    return 1
  fi
  for id in "${requested[@]}"; do
    module_exists "$id" || die "未知模块：$id"
    selected[$id]=1
  done
  for id in "${!selected[@]}"; do
    resolve_one_module "$id"
  done
  mapfile -t modules < <(normalize_selection_order)

  FORCE_REINSTALL="${FORCE_REINSTALL:-0}"
  printf '%s\n' "$(show_plan "${modules[@]}")"
  if ! ensure_network_for_modules "${modules[@]}"; then
    error "外网未连通，安装流程已停止"
    return 1
  fi
  sync_network_profile
  if ! run_selected_modules "${modules[@]}"; then
    final_report
    return 1
  fi
  sync_network_profile
  final_report
}

check_network_only() {
  local -a urls=()
  local url
  FORCE_REINSTALL=0

  if [ -n "${NETWORK_CHECK_URLS:-}" ]; then
    read -r -a urls <<< "$NETWORK_CHECK_URLS"
  else
    read -r -a urls <<< "$NETWORK_CORE_URLS"
  fi
  if [ "${#urls[@]}" -eq 0 ]; then
    urls=("https://github.com/")
  fi

  if network_prepare_connectivity; then
    if [ "$NETWORK_ACTIVE_ROUTE" = "proxy" ]; then
      ok "使用代理 $(network_mask_proxy "$NETWORK_ACTIVE_PROXY")"
    else
      warn "未使用代理，当前为直连"
    fi
  else
    warn "未自动找到可用代理，将按当前环境进行检测"
  fi

  if network_check_urls "${urls[@]}"; then
    for url in "${NETWORK_RESULTS[@]}"; do
      ok "$url"
    done
    ok "外网连通性检测通过（${#urls[@]} 个核心目标）"
    return 0
  fi

  error "外网连通性检测失败"
  for url in "${NETWORK_RESULTS[@]}"; do
    ok "$url"
  done
  printf '%s\n' "$(network_failure_text)" >&2
  return 1
}

usage() {
  cat <<'HELP'
用法：
  ./init.sh                         交互式选择工具（当前终端内完成）
  ./init.sh --all                   无交互，安装全部模块（仍强制检查外网）
  ./init.sh --only id1,id2          无交互，安装指定模块及其依赖
  ./init.sh --check-network         只检测外网与代理，不执行安装
  ./init.sh --list                  列出模块及安装状态
  ./init.sh --force                 强制重跑已安装的选中模块
  ./init.sh --help                  显示帮助

常用模块 ID：
  miniconda, uv, tools-env, oh-my-zsh, nvm-node, tmux, codex,
  cc-switch, codex-feishu-agent, codex-feishu-notice, pi,
  projects, shell-switch, gpu-who, zshrc

环境变量覆盖示例：
  PROXY_CONFIG_FILE=/path/proxy.env ./init.sh
  SSD_PROJECTS=/ssd/$USER/projects ./init.sh
HELP
}

main() {
  local mode="interactive"
  NONINTERACTIVE_MODULES=()
  FORCE_REINSTALL=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help) usage; return 0 ;;
      --list) print_module_list; return 0 ;;
      --check-network) mode="check-network"; shift ;;
      --all) mode="noninteractive"; NONINTERACTIVE_MODULES=("${MODULE_ORDER[@]}"); shift ;;
      --only)
        [ "$#" -ge 2 ] || die "--only 需要一个逗号分隔的模块列表"
        mode="noninteractive"
        IFS=',' read -r -a NONINTERACTIVE_MODULES <<< "$2"
        shift 2
        ;;
      --force) FORCE_REINSTALL=1; shift ;;
      *)
        die "未知参数：$1（使用 --help 查看帮助）"
        ;;
    esac
  done

  case "$mode" in
    interactive) interactive_flow ;;
    noninteractive) noninteractive_flow ;;
    check-network) check_network_only ;;
  esac
}

if main "$@"; then
  exit 0
else
  exit $?
fi
