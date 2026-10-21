#!/usr/bin/env bash
MODULE_ID="projects"
MODULE_NAME="projects 目录"
MODULE_DESCRIPTION="在 SSD 创建项目目录并软链到 ~/projects"
MODULE_DEFAULT=1
MODULE_REQUIRES=""
MODULE_NEEDS_NETWORK=0
MODULE_PROBE_URLS=()

projects_is_installed() {
  [ -L "$PROJECTS_LINK" ] && [ -d "$SSD_PROJECTS" ]
}

projects_install() {
  log "准备项目目录：SSD=$SSD_PROJECTS -> $PROJECTS_LINK"
  mkdir -p "$SSD_PROJECTS" || { error "无法创建 $SSD_PROJECTS"; return 1; }

  if [ -L "$PROJECTS_LINK" ]; then
    ok "软链已存在：$PROJECTS_LINK -> $(readlink "$PROJECTS_LINK")"
  elif [ -d "$PROJECTS_LINK" ]; then
    warn "$PROJECTS_LINK 是真实目录，保留现有数据并跳过软链"
  else
    ln -s "$SSD_PROJECTS" "$PROJECTS_LINK" || { error "创建 projects 软链失败"; return 1; }
    ok "已创建软链：$PROJECTS_LINK -> $SSD_PROJECTS"
  fi
}
