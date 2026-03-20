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

## Git in Submodules and Subdirectories

Use `git -C <path>` to run git commands in submodules or subdirectories. Do NOT `cd` into a directory to run git commands — `cd` causes permission and hook issues.

```bash
# CORRECT - use git -C:
git -C automation commit -m "Fix something"
git -C services status
git -C just/utils log --oneline -5

# INCORRECT - do NOT cd into submodule:
cd automation && git commit -m "Fix something"
```

## Git Worktrees

When working with git worktrees, use `cd` instead of `git -C`:

```bash
# CORRECT for worktrees - cd then run:
cd .worktrees/feature-branch && git log --oneline
cd .worktrees/feature-branch && git status
```

Worktrees are the exception — `cd` is required for proper worktree resolution.

## Stow Usage

After modifying dotfiles, re-stow to update symlinks:

```bash
# From repo root
stow .
# Or re-stow (handles conflicts)
stow -R .
```

Files in `.stow-local-ignore` are excluded from symlinking.
