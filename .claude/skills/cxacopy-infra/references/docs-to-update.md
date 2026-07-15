# Docs to update per change type

Three surfaces document CXACopy. A change to the appliance usually touches at
least two of them — work through this checklist before calling the change done.

## Surface 1 — flake runbooks (ship with each ISO release)

`builder/automation/flakes/copyparty/docs/`:

- `push-instructions.md` — graynet push install, atticd cache bootstrap +
  token minting, consuming the services, update flow, operational notes.
- `pull-instructions.md` — darknet pull install (Path A lab / Path B manual),
  in-place upgrade, verification, on-box debugging cheatsheet.

These are referenced by `copyparty-iso/flake.nix` via the copyparty flake's
outPath and uploaded next to the ISOs in each `cxacopy-vX.Y.Z/` release dir —
**stale runbooks ship forever with that release**, so update them in the same
MR as the flake change.

## Surface 2 — inf-docs site (`docs/cxacopy/` in this repo)

All pages are tagged `[graynet, darknet]` (shared) and build into BOTH sites.
**Edit `docs/` only** — `docs-darknet/` is staged automatically by
`just docs::build-darknet`; never hand-edit it.

| Page | Covers — update when… |
|---|---|
| `index.md` | endpoint/host table (both hosts + IPs), capability cards, access notes — hosts, IPs, or surfaces change |
| `release-automation.md` | CI catalog components, release artifact layout, overwrite behavior, endpoint map — `inf/s3-sync` components or `/cxa/releases/` conventions change |
| `git.md` | `/git/` clone/push endpoints — gitea config, LFS, or pull-side git serving changes |
| `nix.md` | `/nix/` substituter setup, public key, token flow — attic cache name, key, or token policy changes |
| `docker.md` | `/v2/` push/pull usage — registry auth or cache behavior changes |
| `pypi.md` | `/pypi/` publish/install — index layout or publish flow changes |
| `claude-setup.md` | the consumer skill install + release wiring — the cxacopy skill zip or its workflow changes |
| `_includes/cards/cxacopy.md` | reusable card snippet — name/tagline/link changes (needs `--clean` rebuild) |

Verify (from the inf-docs repo root):

```bash
just docs::lint                                   # pymarkdown + codespell
just docs::build && just docs::build-darknet      # both must pass --strict
grep -ciE 'gitlab-runner|static ip|subnet' site-darknet/search.json   # want 0
```

New pages need front matter (`icon:` + `tags:`) and a `nav` entry in
`graynet.toml` and/or `darknet.toml` (darknet nav = Home + CXACopy only).
Full site mechanics: `automation/.claude/skills/cxacopy/references/inf-docs.md`.

## Surface 3 — Claude skills

- `automation/.claude/skills/cxacopy/` (consumer skill, in the automation
  submodule) — update when endpoints, auth tokens, attic cache key/token, folder
  layout, or sync cadence change. It is published as a zip to
  `https://copy.graynet.lan/cxa/skills/cxacopy/cxacopy.zip` by the
  `publish-cxacopy-skill-copyparty` CI job in automation whenever the directory
  changes on `main` — committing the edit IS the release.
- `.claude/skills/cxacopy-infra/` (this skill, in builder) — update when the
  flake layout, role differences, just recipes, or install paths change.
  Published the same way, by `publish-cxacopy-infra-skill-copyparty` in
  builder's `.gitlab-ci.yml` → `cxa/skills/cxacopy-infra/`.

## Quick mapping — change type → surfaces

| Change | Runbooks | inf-docs pages | Skills |
|---|---|---|---|
| New/changed SOPS secret | both runbooks (bootstrap + schema sections) | — | infra |
| New nginx surface / endpoint | both | `index.md` + the surface's page | both |
| attic token/key rotation or policy | push (§10) | `nix.md` | consumer (token block) + infra |
| Sync cadence / lag numbers | push (operational notes) | `index.md` notes | both |
| Install/upgrade flow change | the affected runbook | `claude-setup.md` if consumer-visible | infra |
| `/cxa/releases/` layout convention | — | `release-automation.md` | consumer (folder layout) |
| just recipe rename/addition | runbooks where referenced | — | infra |
