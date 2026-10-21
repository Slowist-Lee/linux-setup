#!/usr/bin/env bash
MODULE_ID="miniconda"
MODULE_NAME="Miniconda"
MODULE_DESCRIPTION="Python 环境管理器（固定校验 SHA256）"
MODULE_DEFAULT=1
MODULE_REQUIRES=""
MODULE_NEEDS_NETWORK=1
MODULE_PROBE_URLS=("https://repo.anaconda.com/miniconda/")

miniconda_is_installed() {
  [ -x "$CONDA_ROOT/bin/conda" ] && "$CONDA_ROOT/bin/conda" --version >/dev/null 2>&1
}

miniconda_install() {
  if miniconda_is_installed; then
    ok "Miniconda 已安装于 $CONDA_ROOT（跳过）"
  else
    if [ -e "$CONDA_ROOT" ]; then
      log "清理上次残留的 Miniconda 安装：$CONDA_ROOT"
      rm -rf -- "${CONDA_ROOT:?CONDA_ROOT must not be empty}"
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
    local actual_sha256
    actual_sha256="$(sha256sum "$MINICONDA_INSTALLER_PATH" | awk '{print $1}')"
    if [ "$actual_sha256" != "$MINICONDA_SHA256" ]; then
      error "Miniconda SHA256 不匹配"
      warn "期望: $MINICONDA_SHA256"
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
