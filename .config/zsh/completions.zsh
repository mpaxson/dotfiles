# Add custom completions directory to fpath BEFORE compinit
fpath=(~/.config/zsh/completions $fpath)

# Completions are loaded via fpath, not source
# Files: _just, _inv, _invoke
