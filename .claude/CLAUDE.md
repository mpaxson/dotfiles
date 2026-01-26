# Global Claude Code Instructions

## Project Overview

This is a **dotfiles repository** managed with GNU Stow. Files symlink to `$HOME`.

Key paths:
- `.zshrc` - main shell config with zinit plugin manager
- `.config/zsh/` - modular zsh configs (aliases, exports, completions)
- `.claude/skills/` - Claude Code skills (symlinked to ~/.claude/skills/)

## Available Skills

| Skill | Triggers |
|-------|----------|
| `zinit-zsh` | zsh plugins, gh-r binary installs, completions, ice modifiers, .zshrc edits |
| `playwright` | E2E tests, web scraping, browser automation, WebSockets, parallelization |

## Git Commits and PRs

When creating commits and pull requests:
- Do NOT add the "Generated with Claude Code" watermark line
- Do NOT add the "Co-Authored-By: Claude" line
- Keep commit messages and PR descriptions clean and professional

## Git Worktrees

When working with git worktrees, use `cd` instead of `git -C`:

```bash
# CORRECT - cd into worktree then run git commands:
cd .worktrees/feature-branch && git log --oneline
cd .worktrees/feature-branch && git status

# INCORRECT - do NOT use git -C:
git -C .worktrees/feature-branch log --oneline
```

This ensures proper permission handling. The `cd <path> && <git command>` pattern is allowed and matches existing git permission rules.

## Stow Usage

After modifying dotfiles, re-stow to update symlinks:

```bash
# From repo root
stow .
# Or re-stow (handles conflicts)
stow -R .
```

Files in `.stow-local-ignore` are excluded from symlinking.
