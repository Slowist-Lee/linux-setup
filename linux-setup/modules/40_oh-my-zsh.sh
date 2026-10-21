#!/usr/bin/env bash
MODULE_ID="oh-my-zsh"
MODULE_NAME="oh-my-zsh + 插件"
MODULE_DESCRIPTION="主题、zsh-autosuggestions、zsh-syntax-highlighting"
MODULE_DEFAULT=1
MODULE_REQUIRES="tools-env"
MODULE_NEEDS_NETWORK=1
MODULE_PROBE_URLS=("https://github.com/ohmyzsh/ohmyzsh.git")

_omz_plugin_enabled() {
  local plugin="$1"
  local zshrc="$HOME/.zshrc"
  [ -f "$zshrc" ] && grep -Fq "$plugin" "$zshrc"
}

_omz_ensure_plugins_block() {
  local zshrc="$HOME/.zshrc"
  touch "$zshrc"
  if grep -q "^[[:space:]]*plugins=(" "$zshrc"; then
    return 0
  fi
  awk -v list="git zsh-autosuggestions zsh-syntax-highlighting" '
    /source .*oh-my-zsh.sh/ && !done {
      print "plugins=("
      n = split(list, a, " ")
      for (i = 1; i <= n; i++) print "  " a[i]
      print ")"
      done = 1
    }
    { print }
    END { if (!done) print "plugins=(git zsh-autosuggestions zsh-syntax-highlighting)" }
  ' "$zshrc" > "$zshrc.tmp" && mv "$zshrc.tmp" "$zshrc"
}

_omz_enable_plugin() {
  local plugin="$1"
  local zshrc="$HOME/.zshrc"
  _omz_plugin_enabled "$plugin" && return 0
  awk -v p="$plugin" '
    /^plugins=\(/ { in_plugins = 1 }
    in_plugins && /)/ {
      if ($0 ~ /^plugins=\(.*\)/) { sub(/\)$/, " " p ")", $0) }
      else { print "  " p }
      in_plugins = 0
    }
    { print }
  ' "$zshrc" > "$zshrc.tmp" && mv "$zshrc.tmp" "$zshrc"
  ok "已启用 zsh 插件：$plugin"
}

oh_my_zsh_is_installed() {
  [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ] \
    && [ -d "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" ] \
    && [ -d "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" ] \
    && grep -q "source .*oh-my-zsh.sh" "$HOME/.zshrc" 2>/dev/null
}

oh_my_zsh_install() {
  local omz="$HOME/.oh-my-zsh"
  local zshrc="$HOME/.zshrc"

  if [ ! -f "$omz/oh-my-zsh.sh" ]; then
    if [ -e "$omz" ]; then
      mv "$omz" "${omz}.bak.$(date +%s)"
    fi
    log "安装 oh-my-zsh"
    if ! git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$omz"; then
      error "oh-my-zsh 安装失败"
      return 1
    fi
  else
    ok "oh-my-zsh 已安装（跳过）"
  fi

  touch "$zshrc"
  if ! grep -q "source .*oh-my-zsh.sh" "$zshrc"; then
    if ! grep -q "plugins=" "$zshrc"; then
      cp "$omz/templates/zshrc.zsh-template" "$zshrc"
      ok "已用 oh-my-zsh 模板初始化 ~/.zshrc"
    else
      {
        printf '\nexport ZSH="%s"\nsource $ZSH/oh-my-zsh.sh\n' "$omz"
      } >> "$zshrc"
    fi
  fi

  if grep -q '^#\?ZSH_THEME=' "$zshrc"; then
    sed -i "s|^#\\?ZSH_THEME=.*|ZSH_THEME=\"$ZSH_THEME\"|" "$zshrc"
  else
    printf 'ZSH_THEME="%s"\n' "$ZSH_THEME" >> "$zshrc"
  fi

  mkdir -p "$ZSH_CUSTOM_DIR/plugins"
  if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" ]; then
    log "安装插件 zsh-autosuggestions"
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
      "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" || return 1
  fi
  if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" ]; then
    log "安装插件 zsh-syntax-highlighting"
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
      "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" || return 1
  fi

  _omz_ensure_plugins_block
  _omz_enable_plugin git
  _omz_enable_plugin zsh-autosuggestions
  _omz_enable_plugin zsh-syntax-highlighting
  ok "oh-my-zsh 与插件配置完成"
}
