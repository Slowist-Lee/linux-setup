#!/usr/bin/env bash
# Small whiptail wrapper with a non-TUI fallback for minimal systems.

TUI_BACKEND=""
TUI_TITLE="Linux Setup"

tui_init() {
  if command -v whiptail >/dev/null 2>&1; then
    TUI_BACKEND="whiptail"
  elif command -v dialog >/dev/null 2>&1; then
    TUI_BACKEND="dialog"
  else
    TUI_BACKEND="plain"
  fi
}

tui_is_interactive() {
  [ -t 0 ] && [ -t 2 ]
}

_tui_cmd() {
  local tool="$1"
  shift
  if [ "$tool" = "dialog" ]; then
    dialog "$@"
  else
    whiptail "$@"
  fi
}


# Sets TUI_WIDTH/TUI_HEIGHT, keeping whiptail inside the current terminal.
_tui_dimensions() {
  local max_width="$1"
  local max_height="$2"
  local cols="${COLUMNS:-}"
  local lines="${LINES:-}"

  if [ -z "$cols" ] || ! [[ "$cols" =~ ^[0-9]+$ ]]; then
    cols="$(tput cols 2>/dev/null || printf '80')"
  fi
  if [ -z "$lines" ] || ! [[ "$lines" =~ ^[0-9]+$ ]]; then
    lines="$(tput lines 2>/dev/null || printf '24')"
  fi
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
  [[ "$lines" =~ ^[0-9]+$ ]] || lines=24

  TUI_WIDTH=$((cols - 4))
  TUI_HEIGHT=$((lines - 2))
  [ "$TUI_WIDTH" -gt "$max_width" ] && TUI_WIDTH="$max_width"
  [ "$TUI_HEIGHT" -gt "$max_height" ] && TUI_HEIGHT="$max_height"
  [ "$TUI_WIDTH" -lt 50 ] && TUI_WIDTH=50
  [ "$TUI_HEIGHT" -lt 10 ] && TUI_HEIGHT=10
}

tui_msgbox() {
  local title="$1"
  local message="$2"
  printf -v message '%b' "$message"
  if [ "$TUI_BACKEND" = "plain" ] || ! tui_is_interactive; then
    printf '\n== %s ==\n%s\n' "$title" "$message" >&2
    return 0
  fi
  _tui_dimensions 92 20
  _tui_cmd "$TUI_BACKEND" --title "$title" --backtitle "$TUI_TITLE" --msgbox "$message" "$TUI_HEIGHT" "$TUI_WIDTH"
}

tui_yesno() {
  local title="$1"
  local message="$2"
  local default="${3:-yes}"
  printf -v message '%b' "$message"

  if [ "$TUI_BACKEND" = "plain" ]; then
    local prompt="[Y/n]"
    local answer=""
    [ "$default" = "no" ] && prompt="[y/N]"
    printf '\n== %s ==\n%s\n%s ' "$title" "$message" "$prompt" >&2
    IFS= read -r answer || return 1
    if [ -z "$answer" ]; then
      if [ "$default" = "yes" ]; then
        return 0
      fi
      return 1
    fi
    case "$answer" in
      y|Y|yes|YES) return 0 ;;
      *) return 1 ;;
    esac
  fi
  if ! tui_is_interactive; then
    return 0
  fi
  _tui_dimensions 92 22
  if [ "$TUI_BACKEND" = "dialog" ]; then
    dialog --title "$title" --backtitle "$TUI_TITLE" --yesno "$message" "$TUI_HEIGHT" "$TUI_WIDTH"
    return $?
  fi
  local flag="--defaultno"
  [ "$default" = "yes" ] && flag=""
  whiptail --title "$title" --backtitle "$TUI_TITLE" $flag --yesno "$message" "$TUI_HEIGHT" "$TUI_WIDTH"
}

tui_inputbox() {
  local title="$1"
  local message="$2"
  local default="${3:-}"
  local answer=""
  printf -v message '%b' "$message"

  if [ "$TUI_BACKEND" = "plain" ] || ! tui_is_interactive; then
    printf '%s\n' "$message" >&2
    if ! IFS= read -r -p "> " answer; then
      return 1
    fi
    printf '%s\n' "${answer:-$default}"
    return 0
  fi
  _tui_dimensions 88 14
  if ! answer=$(_tui_cmd "$TUI_BACKEND" --title "$title" --backtitle "$TUI_TITLE" \
      --inputbox "$message" "$TUI_HEIGHT" "$TUI_WIDTH" "$default" 3>&1 1>&2 2>&3); then
    return 1
  fi
  printf '%s\n' "$answer"
}

tui_menu() {
  local title="$1"
  local message="$2"
  shift 2
  local answer=""
  printf -v message '%b' "$message"

  if [ "$TUI_BACKEND" = "plain" ] || ! tui_is_interactive; then
    local -a tags=() labels=()
    while [ "$#" -gt 0 ]; do
      tags+=("$1")
      labels+=("$2")
      shift 2
    done
    printf '\n== %s ==\n%s\n' "$title" "$message" >&2
    local i
    for i in "${!tags[@]}"; do
      printf '  %d) %s\n' "$((i + 1))" "${labels[$i]}" >&2
    done
    local choice=""
    IFS= read -r -p "Select [1-${#tags[@]}]: " choice || return 1
    [[ "$choice" =~ ^[0-9]+$ ]] || return 1
    (( choice >= 1 && choice <= ${#tags[@]} )) || return 1
    printf '%s\n' "${tags[$((choice - 1))]}"
    return 0
  fi

  local -a args=()
  while [ "$#" -gt 0 ]; do
    args+=("$1" "$2")
    shift 2
  done
  _tui_dimensions 96 22
  local list_height=$((TUI_HEIGHT - 8))
  [ "$list_height" -gt 12 ] && list_height=12
  [ "$list_height" -lt 4 ] && list_height=4
  local -a item_flag=()
  [ "$TUI_BACKEND" = "whiptail" ] && item_flag=(--notags)
  if ! answer=$(_tui_cmd "$TUI_BACKEND" --title "$title" --backtitle "$TUI_TITLE" \
      "${item_flag[@]}" --menu "$message" "$TUI_HEIGHT" "$TUI_WIDTH" "$list_height" "${args[@]}" 3>&1 1>&2 2>&3); then
    return 1
  fi
  printf '%s\n' "$answer"
}

tui_checklist() {
  local title="$1"
  local message="$2"
  shift 2
  local answer=""
  printf -v message '%b' "$message"

  if [ "$TUI_BACKEND" = "plain" ] || ! tui_is_interactive; then
    local -a tags=() labels=() states=()
    while [ "$#" -gt 0 ]; do
      tags+=("$1")
      labels+=("$2")
      states+=("$3")
      shift 3
    done
    printf '\n== %s ==\n%s\n' "$title" "$message" >&2
    local i
    for i in "${!tags[@]}"; do
      local mark=" "
      [ "${states[$i]}" = "ON" ] && mark="x"
      printf '  [%s] %d) %s\n' "$mark" "$((i + 1))" "${labels[$i]}" >&2
    done
    local input=""
    IFS= read -r -p "Input numbers to select (e.g. 1,3,5; empty=defaults): " input || return 1
    if [ -z "$input" ]; then
      for i in "${!tags[@]}"; do
        [ "${states[$i]}" = "ON" ] && printf '%s\n' "${tags[$i]}"
      done
      return 0
    fi
    input="${input//,/ }"
    local n
    for n in $input; do
      [[ "$n" =~ ^[0-9]+$ ]] || continue
      (( n >= 1 && n <= ${#tags[@]} )) && printf '%s\n' "${tags[$((n - 1))]}"
    done
    return 0
  fi

  local -a args=()
  while [ "$#" -gt 0 ]; do
    args+=("$1" "$2" "$3")
    shift 3
  done
  _tui_dimensions 110 28
  local list_height=$((TUI_HEIGHT - 10))
  [ "$list_height" -gt 18 ] && list_height=18
  [ "$list_height" -lt 4 ] && list_height=4
  local -a item_flag=()
  [ "$TUI_BACKEND" = "whiptail" ] && item_flag=(--notags)
  if ! answer=$(_tui_cmd "$TUI_BACKEND" --title "$title" --backtitle "$TUI_TITLE" \
      "${item_flag[@]}" --separate-output --checklist "$message" "$TUI_HEIGHT" "$TUI_WIDTH" "$list_height" "${args[@]}" 3>&1 1>&2 2>&3); then
    return 1
  fi
  printf '%s\n' "$answer"
}

tui_infobox() {
  local message="$1"
  printf -v message '%b' "$message"
  if [ "$TUI_BACKEND" = "plain" ] || ! tui_is_interactive; then
    printf '%s\n' "$message" >&2
    return 0
  fi
  _tui_dimensions 88 10
  _tui_cmd "$TUI_BACKEND" --title "$TUI_TITLE" --backtitle "$TUI_TITLE" --infobox "$message" "$TUI_HEIGHT" "$TUI_WIDTH"
}
