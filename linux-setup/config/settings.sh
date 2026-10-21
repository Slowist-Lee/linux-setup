#!/usr/bin/env bash
# Shared, user-overridable settings for the modular installer.

# Base paths
MINICONDA_INSTALLER="Miniconda3-latest-Linux-x86_64.sh"
MINICONDA_URL="https://repo.anaconda.com/miniconda/${MINICONDA_INSTALLER}"
MINICONDA_INSTALLER_PATH="${MINICONDA_INSTALLER_PATH:-/tmp/miniconda.sh}"
# Empty means read the checksum from Anaconda's official index at install time.
# Set this only when you need to pin a specific installer.
MINICONDA_SHA256="${MINICONDA_SHA256:-}"
MINICONDA_INDEX_URL="${MINICONDA_INDEX_URL:-https://repo.anaconda.com/miniconda/}"
MINICONDA_INDEX_MAX_TIME="${MINICONDA_INDEX_MAX_TIME:-30}"
CONDA_ROOT="${CONDA_ROOT:-$HOME/miniconda3}"

SSD_ROOT="${SSD_ROOT:-/ssd/lixin/conda}"
CONDA_ENVS="${CONDA_ENVS:-$SSD_ROOT/conda_envs}"
CONDA_PKGS="${CONDA_PKGS:-$SSD_ROOT/conda_pkgs}"
TOOLS_ENV="${TOOLS_ENV:-$CONDA_ENVS/tools}"

SSD_PROJECTS="${SSD_PROJECTS:-/ssd/lixin/projects}"
PROJECTS_LINK="${PROJECTS_LINK:-$HOME/projects}"
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"

ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
NVM_VERSION="${NVM_VERSION:-v0.40.4}"
NODE_DEFAULT="${NODE_DEFAULT:-22}"
ZSH_THEME="${ZSH_THEME:-robbyrussell}"

# Optional project-based tools
CUSTOM_TOOLS_ENABLED="${CUSTOM_TOOLS_ENABLED:-1}"
GPU_WHO_ROOT="${GPU_WHO_ROOT:-$SSD_PROJECTS/gpu-who}"
CODEX_FEISHU_AGENT_ROOT="${CODEX_FEISHU_AGENT_ROOT:-$SSD_PROJECTS/codex-feishu-agent}"
CODEX_FEISHU_NOTICE_ROOT="${CODEX_FEISHU_NOTICE_ROOT:-$SSD_PROJECTS/plugins/codex-feishu-notice}"

# Network behavior
NETWORK_CONNECT_TIMEOUT="${NETWORK_CONNECT_TIMEOUT:-8}"
NETWORK_MAX_TIME="${NETWORK_MAX_TIME:-20}"
NETWORK_DISCOVERY_CONNECT_TIMEOUT="${NETWORK_DISCOVERY_CONNECT_TIMEOUT:-4}"
NETWORK_DISCOVERY_MAX_TIME="${NETWORK_DISCOVERY_MAX_TIME:-8}"
NETWORK_DISCOVERY_ATTEMPTS="${NETWORK_DISCOVERY_ATTEMPTS:-2}"
# `--check-network` uses these lightweight addresses instead of every module URL.
NETWORK_CORE_URLS="${NETWORK_CORE_URLS:-https://github.com/}"
NETWORK_PROXY_PROBE_URL="${NETWORK_PROXY_PROBE_URL:-https://github.com/}"
# If the inherited proxy is stale, try these common local proxy endpoints.
NETWORK_PROXY_CANDIDATES="${NETWORK_PROXY_CANDIDATES:-http://127.0.0.1:17890 http://127.0.0.1:7890}"
NETWORK_CHECK_URLS="${NETWORK_CHECK_URLS:-}"
PROXY_CONFIG_DIR="${PROXY_CONFIG_DIR:-$HOME/.config/linux-setup}"
PROXY_CONFIG_FILE="${PROXY_CONFIG_FILE:-$PROXY_CONFIG_DIR/proxy.env}"
NO_PROXY_VALUE="${NO_PROXY_VALUE:-hpc.westlake.edu.cn,hpc-api.westlake.edu.cn,.westlake.edu.cn,localhost,127.0.0.1,::1}"

# Project configs bundled with this installer
ZSHRC_TEMPLATE="${ZSHRC_TEMPLATE:-$SETUP_ROOT/config/zshrc}"

# Load a previously saved proxy if present.
if [ -r "$PROXY_CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$PROXY_CONFIG_FILE"
fi
