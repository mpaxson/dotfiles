# Core completion styling (non-fzf-tab)

# Case-insensitive matching
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Use ANSI codes for fzf-tab compatibility (zsh %B/%U codes don't work in fzf)
zstyle ':completion:*:descriptions' format $'\e[1;4m%d\e[0m'
zstyle ':completion:*:messages' format "%F{green}%d%f"

# LS_COLORS for file completions
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Disable menu (fzf-tab handles selection)
zstyle ':completion:*' menu no

# Make targets
zstyle ':completion:*:*:(|g)make::targets' call-command true
zstyle ':completion:*:*:(|g)make:*' tag-order targets

# Vim mode indicators
export NORMAL_MODE_TEXT_DEFAULT="🧭"
export INSERT_MODE_TEXT_DEFAULT="✏️"
