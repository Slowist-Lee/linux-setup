#!/usr/bin/env bash
# Shared helpers used by the runner and all modules.

if [ -t 1 ]; then
  C_RESET=$'\033[0m'
  C_BLUE=$'\033[1;34m'
  C_GREEN=$'\033[1;32m'
  C_YELLOW=$'\033[1;33m'
  C_RED=$'\033[1;31m'
else
  C_RESET="" C_BLUE="" C_GREEN="" C_YELLOW="" C_RED=""
fi

log()   { printf '\n%s[setup]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()    { printf '%s  ✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf '%s  !%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
error() { printf '%s  ✘%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }

die() {
  error "$*"
  exit 1
}

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

write_managed_file() {
  local path="$1"
  local mode="$2"
  local tmp="${path}.tmp.$$"

  mkdir -p "$(dirname "$path")"
  cat > "$tmp"
  chmod "$mode" "$tmp"
  if [ -f "$path" ] && cmp -s "$tmp" "$path"; then
    rm -f "$tmp"
  else
    mv -f "$tmp" "$path"
  fi
}

remove_managed_block() {
  local file="$1"
  local begin="$2"
  local end="$3"
  local tmp="${file}.tmp.$$"

  [ -f "$file" ] || return 0
  awk -v begin="$begin" -v endm="$end" '
    $0 == begin { skip = 1; next }
    skip && $0 == endm { skip = 0; next }
    !skip { print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

append_managed_block() {
  local file="$1"
  local begin="$2"
  local end="$3"
  local content="$4"

  mkdir -p "$(dirname "$file")"
  touch "$file"
  remove_managed_block "$file" "$begin" "$end"
  {
    printf '\n%s\n' "$begin"
    printf '%s\n' "$content"
    printf '%s\n' "$end"
  } >> "$file"
}

# Put the managed block at the top so an existing `exec zsh` cannot skip it.
prepend_managed_block() {
  local file="$1"
  local begin="$2"
  local end="$3"
  local content="$4"
  local tmp="${file}.tmp.$$"

  mkdir -p "$(dirname "$file")"
  touch "$file"
  awk -v begin="$begin" -v endm="$end" '
    $0 == begin { skip = 1; next }
    skip && $0 == endm { skip = 0; next }
    !skip { print }
  ' "$file" > "$tmp"
  {
    printf '%s\n' "$begin"
    printf '%s\n' "$content"
    printf '%s\n' "$end"
    cat "$tmp"
  } > "${tmp}.new"
  mv -f "${tmp}.new" "$file"
  rm -f "$tmp"
}

path_contains_dir() {
  local wanted="$1"
  case ":$PATH:" in
    *":$wanted:"*) return 0 ;;
    *) return 1 ;;
  esac
}

add_local_bin_to_path() {
  if ! path_contains_dir "$LOCAL_BIN"; then
    export PATH="$LOCAL_BIN:$PATH"
  fi
}
