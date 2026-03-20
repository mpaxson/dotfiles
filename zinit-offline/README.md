# Zinit Offline Package

Snapshot of `~/.local/share/zinit/` for offline or airgapped deployments.
Contains all zinit plugins, binaries, completions, and snippets so a new
machine can bootstrap without internet access.

## Pack (export current zinit state)

```bash
zinit-pack.sh
```

1. Compresses `~/.local/share/zinit/` with zstd (gzip fallback)
2. Bundles the archive + this README into `zinit-offline.tar.gz` at the repo root

Run this on a machine with a working zinit setup after all plugins have loaded
at least once.

## Depack (restore on a new machine)

```bash
zinit-depack.sh
```

Extracts `zinit-offline.tar.gz` (if needed), then restores the zinit archive to
`~/.local/share/zinit/`. Prompts before overwriting an existing installation.

## Typical workflow

```bash
# Source machine — snapshot everything
zinit-pack.sh

# Transfer the single file to the target
scp ~/dotfiles/zinit-offline.tar.gz target:~/dotfiles/

# Target machine — restore and stow
cd ~/dotfiles
zinit-depack.sh
stow -R .
```

## What's included

| Directory      | Contents                                           |
|--------------- |----------------------------------------------------|
| `zinit.git/`   | Zinit plugin manager source                        |
| `plugins/`     | All plugins and gh-r binaries (bat, fd, fzf, etc.) |
| `completions/` | Symlinks to generated/bundled completion files      |
| `snippets/`    | OMZ snippets (docker, ssh, git, etc.)              |
| `polaris/`     | `$ZPFX` — sbin symlinks and built artifacts        |
| `services/`    | Zinit services (if any)                            |

## Notes

- Archive size depends on installed gh-r binaries (~1 GB typical).
- Re-run `zinit-pack.sh` after adding or updating plugins to refresh the snapshot.
- The archive is platform-specific (linux/amd64). Pack on the same arch you deploy to.
