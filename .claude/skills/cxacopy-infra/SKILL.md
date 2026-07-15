---
name: cxacopy-infra
description: CXACopy appliance internals — the copyparty flake in builder/automation/flakes (push/pull NixOS roles), the darknet pull side (copy.irad.dn.lan), deploy/update workflows, and which docs to update. Self-updating — run `/cxacopy-infra update` (bash scripts/update.sh) to pull the latest skill from the CXA mirror.
---

# CXACopy infrastructure (copyparty flake)

Operate and modify the **CXACopy appliance**: two NixOS VMs built from one
flake at `builder/automation/flakes/copyparty/`.

Repos (all on `gitlab.graynet.lan`; paths below are relative to a clone):
- **builder** = `inf/flakes/builder` — the monorepo; `automation/` inside it is
  the `inf/flakes/automation` submodule (clone builder with
  `--recurse-submodules`). **This skill lives in builder** at
  `.claude/skills/cxacopy-infra/`; the consumer **cxacopy** skill lives in the
  automation submodule at `automation/.claude/skills/cxacopy/`.
- **inf-docs** = `inf/docs` — the docs site that builds the `/help` pages on
  both copyparty hosts.

```
copy.graynet.lan (PUSH, graynet)          copy.irad.dn.lan (PULL, darknet)
  writable; rclone COPIES data → S3   →   S3 bucket  →   rclone FUSE-mounts S3
  every 5 min (append-only)                              read-only (~6 min lag,
                                                         worst ~10 min)
```

Graynet and darknet are **air-gapped**; the shared S3 bucket is the ONLY thing
crossing. No controller in graynet can reach the darknet VM — this constrains
every install/update path (see `references/deploy-update.md`).

For *uploading files to* CXACopy, use the sibling **cxacopy** skill instead;
this skill is for working **on** the appliance itself.

## Source map — `builder/automation/flakes/`

| Path | What |
|---|---|
| `copyparty/flake.nix` | `nixosConfigurations.copyparty-push` / `copyparty-pull` = `base-common.nix` + `role-<role>.nix`; nixpkgs follows `os.flake` |
| `copyparty/role-push.nix` | push secrets schema, copyparty.conf (admin+upload+anon read), `rclone-sync` 5-min S3 copy |
| `copyparty/role-pull.nix` | pull secrets schema, copyparty.conf (admin+anon read only), `rclone-mount` RO FUSE + 15-min prewarm |
| `copyparty/{attic,gitea,pypi,npm,maven,docker-registry,seaweedfs,hookshot,nginx}.nix` | per-surface modules — each takes `{ role }` and branches internally. `maven.nix` also owns the `[/mirrors/{gradle,maven-internal,android-sdk}]` copyparty volumes + Reposilite (`/maven`); `npm.nix` = Verdaccio; `pypi.nix` = `[/mirrors/pypi]` |
| `copyparty/{intercept-domains,hookshot-pkg}.nix`, `copyparty/{pki,lfs-batch-shim,npm}/` | hookshot intercept domain list; hookshot binary; TLS/PKI assets; pull-side Go LFS batch shim; Verdaccio config |
| `copyparty/s3-env.nix` | renders `/etc/s3.env` from SOPS for all S3 consumers; emits endpoint vars only when `s3_endpoint_url` non-empty |
| `copyparty/base-common.nix` | role-independent base; `network-config.service` + `ntp-config.service` render per-VM net/NTP from SOPS |
| `copyparty/docs/{push,pull}-instructions.md` | install runbooks — ship inside each release ISO dir |
| `copyparty-iso/` | builds live-installer ISOs with the closure + disko script baked in (zero eval/network at install time); `version.yaml`, `copyparty-upgrade.sh` |

Per-VM config (static IP, gateway, DNS, NTP, registry cache size) lives in
**SOPS** (`/etc/nixos/secrets.sops.yml`), not the flake — one generic closure
covers all VMs, and darknet (which can't reach gitlab for a flake re-eval) can
still apply config via `switch-to-configuration switch`. `restartUnits` on each
`sops.secrets.<x>` is what restarts consumers on rotation (`restartTriggers`
would NOT fire — the /run/secrets path string never changes).

## Package-registry surfaces nest under `/mirrors` in the copyparty sidebar

The four package-registry surfaces are copyparty volumes mounted under a
synthetic `/mirrors` parent so copyparty's sidebar groups them under one
collapsible node instead of scattering them at root:
`[/mirrors/pypi]` (pypi.nix), `[/mirrors/{gradle,maven-internal,android-sdk}]`
(maven.nix). copyparty synthesises the `mirrors` parent — no volume defines it.

**The copyparty mount path IS the URL path, but the PUBLIC sourcing URLs are
unchanged** (`/pypi/`, `/gradle/`, `/maven-internal/`, `/android-sdk/`) so
pip/gradle/mvn configs need no edits. `nginx.nix` decouples them:

- `/gradle/`, `/maven-internal/`, `/android-sdk/` (push) are `rewrite … last`
  shims onto `/mirrors/<x>/`, which are the real `proxy_pass` to copyparty.
- `/pypi/` GET stays nginx-static from `/srv/pypi`; only the upload (non-GET)
  fall-through is `rewrite`-ed onto `/mirrors/pypi` (twine PUT + xau hook).
- The `/mirrors/<x>/` locations also serve copyparty's own sidebar/breadcrumb
  links (it emits absolute `/mirrors/...` paths).
- Loopback uploaders that hit copyparty directly must use the new path
  (e.g. `android-sdk-refresh` → `127.0.0.1:3923/mirrors/android-sdk`).

`/maven` (Reposilite) and `/npm` (Verdaccio) are separate proxy processes, NOT
copyparty volumes — they never appear in the copyparty sidebar and are not part
of the `/mirrors` grouping. Pull serves the java surfaces as static nginx
aliases (no copyparty), so the nesting is a push-side visual only.

## Push vs pull — the core differences

| | push (graynet) | pull (darknet) |
|---|---|---|
| Data dir | local disk, writable | rclone FUSE mount of S3, `--read-only` |
| copyparty accounts | `admin` + `upload` + anon read | `admin` + anon read; **no upload user** (EROFS anyway) |
| Indexing | `e2dsa` + `e2ts` on | **off** (would re-download the bucket every cold boot) |
| S3 creds | read-write IAM | **read-only IAM** (`ListBucket`+`GetObject`) — the real write boundary |
| Docker `/v2/` | authed push **and pull** (htpasswd=`upload`, no anon — authed ping makes the `docker push` CLI send creds) | empty htpasswd → all non-GET 401, anon GET ok; registry `readonly=true` |
| Gitea `/git/` | full gitea (web UI, authed push, LFS→S3) | **no gitea** — git http-backend + LFS batch shim over RO mounts |
| atticd `/nix/` | mints tokens, writable DB + 5-min snapshot→S3 | never mints; rclone-copies the DB snapshot every 5 min, anon read |
| Extra services | `rclone-sync*` (push to S3) | `rclone-mount*` + `rclone-mount-prewarm` (15-min re-LIST) |
| Secrets delta | + `copyparty_upload_token`, `gitea_admin_password` | (neither) |

Shared on purpose: `attic_token_hs256_secret_base64` (same value both sides —
S3 IAM is the boundary, not JWT), wildcard TLS cert/key, admin password.
Full detail incl. nginx surface map and write-rejection layers:
`references/push-vs-pull.md`.

## Deploy / update

From `builder/` (a graynet controller with the automation SSH key):

```bash
just vm::copyparty-push::update graynet     # SCP flake + remote nixos-rebuild switch
just vm::copyparty-pull::deploy graynet     # lab pull (copy-pull.lab.graynet.lan) only
just copyparty::upload <file> <project>     # upload a release artifact via ansible
```

- **Push VM / lab pull**: `update` (config change) or `deploy`/`redeploy` (re-image).
- **Production darknet pull**: unreachable from controllers — manual on-VM
  install (Path B) or the baked `copyparty-upgrade` helper (v0.6.15+, boots new
  ISO, no-wipe, keeps SOPS secrets). ISOs land at
  `/cxa/releases/copyparty/cxacopy-vX.Y.Z/` via CI on tag.
- Recipes, failure modes, verify commands: `references/deploy-update.md`.

## Docs to update when the appliance changes

Three doc surfaces track this system — keep them in sync with any change:

1. **Flake runbooks** `flakes/copyparty/docs/{push,pull}-instructions.md` —
   ship with each ISO release; update for any install/upgrade/secrets change.
2. **inf-docs site** `inf-docs/docs/cxacopy/*.md` — user-facing, builds BOTH
   graynet and darknet sites. Edit `docs/` only (`docs-darknet/` is staged by
   the build). Verify: `just docs::lint && just docs::build && just docs::build-darknet`.
3. **Claude skills** `automation/.claude/skills/cxacopy/` (consumer) and this
   skill — endpoints, tokens, cadence numbers.

Change-type → exact pages mapping: `references/docs-to-update.md`.

## Distribution & updating

This skill lives in the **builder** repo (`inf/flakes/builder`) at
`.claude/skills/cxacopy-infra/`. It's published as a zip at
`copy.graynet.lan/cxa/skills/cxacopy-infra/cxacopy-infra.zip` by the
`publish-cxacopy-infra-skill-copyparty` CI job in that repo whenever
`.claude/skills/cxacopy-infra/` changes on `main`. The job also stamps and
publishes a standalone **`manifest.yaml`** (UTC `updated` + short `commit`)
alongside the zip, and uploads with `u2c --ow`, so there's one canonical copy.
The zip's top-level folder is `cxacopy-infra/`, so it unzips straight into
`~/.claude/skills/`.

`manifest.yaml` in this directory records the installed `updated` stamp. The
skill isn't versioned — `updated` is the freshness key; `commit` is provenance.

### `/cxacopy-infra update`

When the user runs **`/cxacopy-infra update`** (or asks to update the
cxacopy-infra skill), run the bundled updater. It fetches the published
`manifest.yaml`, compares its `updated` date to the local one, and only
re-downloads + replaces this skill directory when they differ:

```sh
bash scripts/update.sh   # run from this skill's directory (.../skills/cxacopy-infra)
```

The script resolves its own location, so an absolute path works from anywhere
(e.g. `bash ~/.claude/skills/cxacopy-infra/scripts/update.sh`). It's a no-op when
already current, fails closed if the mirror is unreachable, and leaves the local
skill untouched on any error. After a successful update, tell the user to restart
Claude Code (or reopen the session) so the new version loads. Set
`CXACOPY_MIRROR=copy.irad.dn.lan` on darknet hosts.

If you're running from a **builder checkout** (not `~/.claude/skills/`), the
update rewrites the checked-out directory in place — review + commit it there,
or `git checkout --` to discard.

## References

- `references/push-vs-pull.md` — full role differences: nginx surfaces, write-rejection layers, secrets schemas, service inventory.
- `references/deploy-update.md` — install paths (A controller / B manual darknet), update recipes, in-place ISO upgrade, failure modes, verification.
- `references/docs-to-update.md` — which docs/pages to touch per change type, with build/verify commands.
- `scripts/update.sh` — the `/cxacopy-infra update` self-updater (manifest-compare, then re-fetch from the CXA mirror).
