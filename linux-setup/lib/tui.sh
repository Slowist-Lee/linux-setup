#!/usr/bin/env bash
# Inline terminal interaction helpers. No full-screen whiptail/dialog pages.

TUI_BACKEND="inline"
TUI_TITLE="Linux Setup"

tui_init() {
  TUI_BACKEND="inline"
}

tui_is_interactive() {
  [ -t 0 ] && [ -t 2 ]
}

tui_msgbox() {
  local title="$1"
  local message="$2"
  printf -v message '%b' "$message"
  printf '\n== %s ==\n%s\n' "$title" "$message" >&2
}

tui_infobox() {
  local message="$1"
  printf -v message '%b' "$message"
  printf '%s\n' "$message" >&2
}

tui_yesno() {
  local title="$1"
  local message="$2"
  local default="${3:-yes}"
  local prompt="[Y/n]"
  local answer=""

  printf -v message '%b' "$message"
  [ "$default" = "no" ] && prompt="[y/N]"
  printf '\n== %s ==\n%s\n%s ' "$title" "$message" "$prompt" >&2

  if ! tui_is_interactive; then
    [ "$default" = "yes" ]
    return
  fi

  while true; do
    IFS= read -r answer || return 1
    case "$answer" in
      "") [ "$default" = "yes" ]; return ;;
      y|Y|yes|YES) return 0 ;;
      n|N|no|NO) return 1 ;;
      *) printf '请输入 y 或 n：' >&2 ;;
    esac
  done
}

tui_inputbox() {
  local title="$1"
  local message="$2"
  local default="${3:-}"
  local answer=""

  printf -v message '%b' "$message"
  printf '\n== %s ==\n%s\n' "$title" "$message" >&2
  if ! tui_is_interactive; then
    printf '%s\n' "$default"
    return 0
  fi
  IFS= read -r -p "输入${default:+ [$default]}： " answer || return 1
  printf '%s\n' "${answer:-$default}"
}

tui_menu() {
  local title="$1"
  local message="$2"
  shift 2
  local -a tags=() labels=()
  local i choice

  while [ "$#" -gt 0 ]; do
    tags+=("$1")
    labels+=("$2")
    shift 2
  done
  printf -v message '%b' "$message"
  printf '\n== %s ==\n%s\n' "$title" "$message" >&2
  for i in "${!tags[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "${labels[$i]}" >&2
  done

  while true; do
    IFS= read -r -p "选择 [1-${#tags[@]}]： " choice || return 1
    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#tags[@]})); then
      printf '%s\n' "${tags[$((choice - 1))]}"
      return 0
    fi
    printf '无效选项，请重新输入。\n' >&2
  done
}

tui_checklist() {
  local title="$1"
  local message="$2"
  shift 2
  local -a tags=() labels=() selected=() defaults=()
  local i mark input token

  while [ "$#" -gt 0 ]; do
    tags+=("$1")
    labels+=("$2")
    if [ "$3" = "ON" ]; then
      selected+=(1)
      defaults+=(1)
    else
      selected+=(0)
      defaults+=(0)
    fi
    shift 3
  done

  printf -v message '%b' "$message"
  if ! tui_is_interactive; then
    for i in "${!tags[@]}"; do
      [ "${selected[$i]}" = "1" ] && printf '%s\n' "${tags[$i]}"
    done
    return 0
  fi

  printf '\n== %s ==\n%s\n' "$title" "$message" >&2
  while true; do
    printf '\n' >&2
    for i in "${!tags[@]}"; do
      mark=" "
      [ "${selected[$i]}" = "1" ] && mark="x"
      printf '  [%s] %2d) %s\n' "$mark" "$((i + 1))" "${labels[$i]}" >&2
    done
    printf '\n输入编号切换选择；a=全选并确认，n=全不选并确认，r=恢复默认并确认，回车=确认。\n' >&2
    IFS= read -r -p '> ' input || return 1
    [ -z "$input" ] && break

    case "$input" in
      a|A)
        for i in "${!selected[@]}"; do selected[$i]=1; done
        break
        ;;
      n|N)
        for i in "${!selected[@]}"; do selected[$i]=0; done
        break
        ;;
      r|R)
        for i in "${!selected[@]}"; do selected[$i]="${defaults[$i]}"; done
        break
        ;;
    esac

    input="${input//,/ }"
    for token in $input; do
      if [[ "$token" =~ ^[0-9]+$ ]] && ((token >= 1 && token <= ${#tags[@]})); then
        i=$((token - 1))
        if [ "${selected[$i]}" = "1" ]; then
          selected[$i]=0
        else
          selected[$i]=1
        fi
      else
        printf '忽略无效编号：%s\n' "$token" >&2
      fi
    done
  done

  for i in "${!tags[@]}"; do
    [ "${selected[$i]}" = "1" ] && printf '%s\n' "${tags[$i]}"
  done
  return 0
}
