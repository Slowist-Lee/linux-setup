#!/usr/bin/env bash
MODULE_ID="miniconda"
MODULE_NAME="Miniconda"
MODULE_DESCRIPTION="Python 环境管理器（官方 SHA256 动态校验）"
MODULE_DEFAULT=1
MODULE_REQUIRES=""
MODULE_NEEDS_NETWORK=1
MODULE_PROBE_URLS=("https://repo.anaconda.com/miniconda/")

miniconda_is_installed() {
  [ -x "$CONDA_ROOT/bin/conda" ] && "$CONDA_ROOT/bin/conda" --version >/dev/null 2>&1
}

miniconda_expected_sha256() {
  local checksum="${MINICONDA_SHA256:-}"
  local index_file=""

  if [ -n "$checksum" ]; then
    if ! [[ "$checksum" =~ ^[[:xdigit:]]{64}$ ]]; then
      error "MINICONDA_SHA256 格式无效：$checksum"
      return 1
    fi
    printf '%s\n' "${checksum,,}"
    return 0
  fi

  if ! index_file="$(mktemp)"; then
    error "无法创建临时文件以获取 Miniconda SHA256"
    return 1
  fi
  if command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL --retry 2 --retry-all-errors --retry-delay 1 \
        --connect-timeout 8 --max-time "$MINICONDA_INDEX_MAX_TIME" \
        "$MINICONDA_INDEX_URL" -o "$index_file"; then
      rm -f -- "$index_file"
      error "无法获取 Miniconda 官方 SHA256 列表"
      return 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if ! wget -q --timeout="$MINICONDA_INDEX_MAX_TIME" --tries=2 \
        "$MINICONDA_INDEX_URL" -O "$index_file"; then
      rm -f -- "$index_file"
      error "无法获取 Miniconda 官方 SHA256 列表"
      return 1
    fi
  else
    rm -f -- "$index_file"
    error "缺少 curl/wget，无法获取 Miniconda SHA256"
    return 1
  fi

  checksum="$(grep -A6 -F "href=\"$MINICONDA_INSTALLER\"" "$index_file" \
    | grep -oE '[[:xdigit:]]{64}' | head -n 1 || true)"
  rm -f -- "$index_file"
  if ! [[ "$checksum" =~ ^[[:xdigit:]]{64}$ ]]; then
    error "无法从官方目录找到 $MINICONDA_INSTALLER 的 SHA256"
    return 1
  fi
  printf '%s\n' "${checksum,,}"
}

miniconda_install() {
  if miniconda_is_installed; then
    ok "Miniconda 已安装于 $CONDA_ROOT（跳过）"
  else
    local expected_sha256 actual_sha256

    if [ -e "$CONDA_ROOT" ]; then
      log "清理上次残留的 Miniconda 安装：$CONDA_ROOT"
      rm -rf -- "${CONDA_ROOT:?CONDA_ROOT must not be empty}"
    fi

    if [ -n "${MINICONDA_SHA256:-}" ]; then
      log "使用手动指定的 Miniconda SHA256"
    else
      log "从 Anaconda 官方目录获取 Miniconda SHA256"
    fi
    if ! expected_sha256="$(miniconda_expected_sha256)"; then
      error "Miniconda 安装包校验信息获取失败，取消安装"
      return 1
    fi

    log "下载 Miniconda：$MINICONDA_URL"
    rm -f -- "$MINICONDA_INSTALLER_PATH"
    if command -v wget >/dev/null 2>&1; then
      wget --timeout=30 --tries=3 "$MINICONDA_URL" -O "$MINICONDA_INSTALLER_PATH"
    elif command -v curl >/dev/null 2>&1; then
      curl -fL --connect-timeout 15 --max-time 600 "$MINICONDA_URL" -o "$MINICONDA_INSTALLER_PATH"
    else
      error "缺少 wget/curl，无法下载 Miniconda"
      return 1
    fi

    log "校验 Miniconda 安装包 SHA256"
    actual_sha256="$(sha256sum "$MINICONDA_INSTALLER_PATH" | awk '{print $1}')"
    if [ "$actual_sha256" != "$expected_sha256" ]; then
      error "Miniconda SHA256 不匹配"
      warn "期望: $expected_sha256"
      warn "实际: $actual_sha256"
      return 1
    fi
    ok "Miniconda 安装包校验通过"

    log "安装 Miniconda -> $CONDA_ROOT"
    bash "$MINICONDA_INSTALLER_PATH" -b -p "$CONDA_ROOT"
    rm -f -- "$MINICONDA_INSTALLER_PATH"
  fi

  # shellcheck disable=SC1091
  . "$CONDA_ROOT/etc/profile.d/conda.sh"
  conda config --set auto_activate_base false || true
  ok "conda: $(conda --version)"
}
