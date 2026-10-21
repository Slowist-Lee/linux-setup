#!/usr/bin/env bash
MODULE_ID="gpu-who"
MODULE_NAME="gpu-who"
MODULE_DESCRIPTION="链接 SSD 中的 GPU 状态查询工具"
MODULE_DEFAULT="${CUSTOM_TOOLS_ENABLED}"
MODULE_REQUIRES="projects"
MODULE_NEEDS_NETWORK=0
MODULE_PROBE_URLS=()

gpu_who_is_installed() {
  [ -x "$LOCAL_BIN/gpu-who" ] && [ -x "$GPU_WHO_ROOT/gpu-who" ]
}

gpu_who_install() {
  if [ ! -x "$GPU_WHO_ROOT/gpu-who" ]; then
    warn "gpu-who 不存在或不可执行：$GPU_WHO_ROOT/gpu-who（跳过）"
    return 0
  fi
  mkdir -p "$LOCAL_BIN"
  ln -sfn "$GPU_WHO_ROOT/gpu-who" "$LOCAL_BIN/gpu-who"
  ok "gpu-who -> $LOCAL_BIN/gpu-who"
}
