# fzf-tab configuration
# Load this AFTER fzf-tab plugin is loaded

local extract="
in=\${\${\"\$(<{f})\"%\$'\0'*}#*\$'\0'}
local -A ctxt=(\"\${(@ps:\2:)CTXT}\")
"

# fzf-tab general settings
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
zstyle ':fzf-tab:*' show-group full
zstyle ':fzf-tab:*' prefix ''
zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:*' popup-min-size 400 400

# Preview commands
zstyle ':fzf-tab:complete:ln:*' fzf-preview 'fzf.zsh $realpath'
zstyle ':fzf-tab:complete:file:*' fzf-preview 'fzf.zsh $realpath'
zstyle ':fzf-tab:complete:mv:*' fzf-preview 'fzf.zsh $realpath'
zstyle ':fzf-tab:complete:pip:*' fzf-preview 'fzf.zsh $realpath'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'fzf.zsh $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'fzf.zsh $realpath'
zstyle ':fzf-tab:complete:zoxide:*' fzf-preview 'fzf.zsh $realpath'
zstyle ':fzf-tab:complete:z:*' fzf-preview 'fzf.zsh $realpath'
zstyle ':fzf-tab:complete:ls:*' fzf-preview 'fzf.zsh $realpath'
zstyle ':fzf-tab:complete:lsd:*' fzf-preview 'fzf.zsh $realpath'
zstyle ':fzf-tab:complete:cat:*' fzf-preview 'fzf.zsh $realpath'
zstyle ':fzf-tab:complete:bat:*' fzf-preview 'fzf.zsh $realpath'

# just: show recipe source (use make syntax - closest to just)
zstyle ':fzf-tab:complete:just:*' fzf-preview 'just --show $word 2>/dev/null | bat --color=always --language=make --style=plain || echo "No preview available"'
zstyle ':completion:*:*:just:*' list-separator ' → '
zstyle ':fzf-tab:complete:j:*' fzf-preview 'just --show $word 2>/dev/null | bat --color=always --language=make --style=plain || echo "No preview available"'
zstyle ':completion:*:*:j:*' list-separator ' → '

# systemctl preview
zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word'
zstyle ':fzf-tab:complete:kill:argument-rest' extra-opts --preview=$extract'ps --pid=$in[(w)1] -o cmd --no-headers -w -w' --preview-window=down:3:wrap

# Initialize zoxide (deferred)
eval "$(zoxide init --cmd z zsh)"
