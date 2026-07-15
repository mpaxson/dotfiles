# Push vs pull — full role differences

One flake, two roles: `mkCopyparty "push"` / `mkCopyparty "pull"` in
`flakes/copyparty/flake.nix`. Each role imports the same surface modules
(`pypi.nix`, `npm.nix`, `maven.nix`, `nginx.nix`, `docker-registry.nix`,
`attic.nix`, `gitea.nix`, `seaweedfs.nix`, `hookshot.nix`) parameterized by
`{ role }`, plus its own `role-<role>.nix`.

## Hosts

| Role | Production | Lab/test |
|---|---|---|
| push | `copy.graynet.lan` (172.20.10.43, graynet) | — |
| pull | `copy.irad.dn.lan` (darknet, airgapped) | `copy-pull.lab.graynet.lan` (172.20.10.105) |

`hostname.nix` (optional, gitignored, preserved across `update` runs) overrides
`edge.copyparty.publicHostname` for lab VMs off the production DNS.

## Data path

- **Push**: `/srv/copyparty/data` is local disk. `rclone-sync.service` (+timer,
  5 min) does `rclone copy` (NOT `sync` — **append-only**; local deletes never
  propagate; evict via `aws s3 rm` + registry GC) to `:s3:$S3_BUCKET/copyparty`,
  excluding `.hist/`. `rclone-sync-pypi` mirrors the pypi index tree, staggered.
- **Pull**: `rclone-mount.service` FUSE-mounts the same prefix at
  `/srv/copyparty/data` with `--read-only --vfs-cache-mode full
  --vfs-cache-max-size 50G --dir-cache-time 24h`. Runs as **root** in foreground
  (`Type=exec`, no `--daemon` — fuse3 + rclone 1.74 break every non-root
  variant), with `--uid/--gid 999` so files appear copyparty-owned.
  `ExecStartPost` blocks until `mountpoint -q` succeeds so
  `copyparty.service` (`after`+`requires` rclone-mount) never races the mount.
  `rclone-mount-prewarm` (15-min timer): `find -type d` discovers new dirs,
  then RC `vfs/refresh recursive=true` (127.0.0.1:5572) re-LISTs + resets TTLs
  — new pushes visible within one tick. Also `rclone-mount-git`,
  `rclone-mount-git-lfs`, `rclone-mount-pypi`.

## copyparty.conf (rendered by `copyparty-config.service` from SOPS)

| | push | pull |
|---|---|---|
| `[accounts]` | `admin`, `upload` | `admin` only |
| `[/]` accs | `rwmda: admin`, `rwd: upload`, `r: *` | `rwmda: admin`, `r: *` |
| `[/help]` accs | `rwd: upload` (docs CI mirror needs DELETE-then-PUT + `--prune`), `h: *` | `h: *` only |
| Indexing | `e2dsa` + `e2ts` | neither (full walk would re-download the bucket per cold boot) |
| Flags | `dothidden` | `dedup`, `dothidden` |

`upload` needs `d` (delete) because copyparty requires it to OVERWRITE an
existing path — without it, replace-PUTs 403 and mirrors leave `name-<ts>` dupes.
`.hidden` in the data root lists reserved names; synced to S3 so pull honours it.

## nginx surfaces (nginx.nix, both roles, addSSL — same locations on 80+443)

| Location | push | pull |
|---|---|---|
| `/nix/` → atticd :8080 | token-authed push, anon read | anon read; push refused |
| `/v2/` → docker registry | **all methods** require htpasswd (`upload`) — no anon pull; the authed ping is also what makes the `docker push` CLI send creds | empty htpasswd ⇒ non-GET 401, anon GET allowed; `readonly=true` |
| `/v2/.../blobs/sha256:*` | proxy_cache blob cache (`registry_cache_*` SOPS-tunable) | same |
| `/pypi/` | static PEP 503 index (GET); non-GET rewrites → copyparty `[/mirrors/pypi]` (twine PUT + xau) | static, read-only |
| `/npm/` → Verdaccio :4873 | anon publish + serve | non-GET 401; anon GET |
| `/maven/` → Reposilite :`maven.port` | proxy-cache of upstream mirrors, on-demand | static alias of RO `/srv/java/maven` |
| `/maven-internal/`, `/gradle/`, `/android-sdk/` | `rewrite … last` → `/mirrors/<x>/` → copyparty `[/mirrors/<x>]` (see below) | static alias of RO `/srv/java/<x>` |
| `/mirrors/{pypi,gradle,maven-internal,android-sdk}/` | real proxy targets for the nested copyparty volumes + copyparty's own sidebar links | pull: static aliases (no copyparty for java) |
| `/git/` | gitea :3000 (web UI, authed push, anon clone) | git http-backend (fastcgi) + cgit-static; clone-only |
| `/git/.../info/lfs/*` | gitea LFS → S3 | LFS **batch shim** (`lfs-batch-shim/`, Go) over RO mounts |
| `/help/` | copyparty `h` volume (rendered docs site) | same |
| `/` | copyparty data UI | same (read-only view) |

**`/mirrors` nesting.** The package-registry copyparty volumes are mounted at
`[/mirrors/pypi]` (pypi.nix) and `[/mirrors/{gradle,maven-internal,android-sdk}]`
(maven.nix) so copyparty's sidebar groups them under one synthetic `mirrors`
node. Public sourcing URLs are unchanged — nginx `rewrite`s the old prefixes
onto `/mirrors/*`. `/maven` (Reposilite) and `/npm` (Verdaccio) are separate
proxy processes, not copyparty volumes, so they never appear in the sidebar.
Loopback uploaders that hit copyparty directly use the new path
(`android-sdk-refresh` → `127.0.0.1:3923/mirrors/android-sdk`).

## Write rejection on pull (defense in depth — outermost to innermost)

1. nginx: non-GET/HEAD on `/v2/` 401s against the empty htpasswd.
2. copyparty: no `upload` account, no write perms in any volume.
3. FUSE: mount is `--read-only` ⇒ EROFS regardless of app config.
4. Registry: `storage.maintenance.readonly=true`.
5. **S3 IAM (the real boundary)**: pull creds have only `s3:ListBucket` +
   `s3:GetObject`. A forged attic JWT or app bug still hits this wall.

## attic (nix binary cache)

- Both roles run atticd on 127.0.0.1:8080, storage in S3 `<bucket>/nix-cache/`,
  exposed at `/nix/`. Cache `main`; trailing slash required by attic-client.
- Push: writable sqlite at `/var/lib/atticd/db.sqlite`, snapshotted to S3 every
  5 min (`attic-db-snapshot`); mints tokens via `attic-mint-token` on the VM.
- Pull: `attic-db-restore` rclone-copies that snapshot every 5 min; anon reads.
- `attic_token_hs256_secret_base64` (32 rand bytes, base64) is **deliberately
  the same value on both sides** — HS256 is symmetric, one vault entry, one
  rotation; push-minted tokens validate on either VM. Rotating it requires
  re-minting all tokens (incl. CI `ATTIC_TOKEN`) or pushes silently 403.

## git — two different servers (gitea.nix)

`/git/` is **not** one server mirrored; it's two stacks sharing an nginx surface.

- **push**: full **gitea** (`:3000`) — web UI, authed `git push`/receive-pack,
  SQLite, push-create repos, **pull-mirror repos**, LFS → S3 (`git-lfs/` prefix).
- **pull**: **no gitea.** `git-http-backend` (smart-HTTP clone/fetch, `fcgiwrap-git`,
  `GIT_HTTP_EXPORT_ALL=1`) + **cgit** browse + Go **`lfs-batch-shim`**, all reading
  the RO mounts (`rclone-mount-git` at `/srv/git`, `rclone-mount-git-lfs`). No
  accounts exist on pull; anon clone only. receive-pack is impossible (RO mount +
  not advertised + nginx method filter).

Replication is **file-level** (`rclone-sync-git`, 5-min timer): Phase 1
`rclone copy` objects (append-only; excludes `refs/**`, `packed-refs`, `hooks/**`,
`*.sample`), Phase 2 `rclone sync` `refs/**` + `packed-refs` (with deletes → exact
ref view). The pull side runs no git ops against origin.

### Gotcha: fully-packed / mirror repos 404 on darknet clone

A pull-mirror repo (or any repo after gitea's `git gc`→`pack-refs`) keeps **all
refs in `packed-refs` and an EMPTY `refs/` dir**. S3/rclone don't replicate empty
dirs, so the RO pull mount has no `refs/` → git's repo-validity check fails →
git-http-backend returns `repository not found` (cgit shows it empty). Objects +
packed-refs are complete; only the empty `refs/` dir is missing. Hand-pushed repos
survive because they keep ≥1 loose ref (`refs/heads/main`) that forces `refs/` to
materialize. **Not** an auth/account issue (no accounts on pull). Fix in
`gitea.nix` `rclone-sync-git`: `touch refs/.keep` in every bare repo before sync
so `refs/` always replicates (git ignores dot-prefixed refs entries). Needs a
push deploy + one sync tick + pull dir-cache refresh to clear. Verified on the
pull test VM: `mkdir refs` alone restores the clone.

### Gotcha: `must_change_password` breaks authed git push (admin + upload)

Symptom: authed `git push` (and the `git-mirror` CI component) to
`copy.graynet.lan/git/` fails auth for `admin` or `upload` **with the correct
password** — gitea rejects HTTP basic auth (git + API) whenever the account is
flagged **must-change-password**. Anon clone (no account) is unaffected, so
`/git/` looks half-broken: reads work, pushes 401.

Cause: the `gitea-admin-seed` **rotate path** (`gitea admin user
change-password`, taken on every `nixos-rebuild` once the users exist). gitea's
`change-password` **defaults `--must-change-password` to true**, unlike `create`
(which we call with `=false`). So accounts are created correctly, then re-flagged
on the next deploy. Fixed in `gitea.nix` by passing `--must-change-password=false`
on the rotate path too — a push deploy re-runs the seed and clears the flag.

Immediate remediation on `copy.graynet.lan` (no full redeploy; mirrors exactly
what the fixed seed does):

```bash
sudo -u gitea env GITEA_WORK_DIR=/srv/gitea GITEA_CUSTOM=/srv/gitea/custom \
  gitea -c /srv/gitea/custom/conf/app.ini admin user change-password \
  --username admin  --password "$(sudo cat /run/gitea-secrets/admin-password)" \
  --must-change-password=false
sudo -u gitea env GITEA_WORK_DIR=/srv/gitea GITEA_CUSTOM=/srv/gitea/custom \
  gitea -c /srv/gitea/custom/conf/app.ini admin user change-password \
  --username upload --password "$(sudo cat /run/gitea-secrets/upload-password)" \
  --must-change-password=false
```

Verify the flag is clear: `sudo -u gitea gitea -c /srv/gitea/custom/conf/app.ini
admin user list` (or push a test commit). **Deploy the `gitea.nix` fix too** —
without it the next rebuild's rotate path re-flags both accounts.

## SOPS secrets schema (placeholder seeded by `bootstrapSopsPlaceholder`)

Common: `aws_access_key_id`, `aws_secret_access_key`, `s3_bucket`, `s3_region`,
`s3_endpoint_url`, `static_ip(_prefix)`, `gateway`, `dns_nameservers`,
`network_interface`, `ntp_servers`, `registry_cache_max_size/_inactive`,
`copyparty_admin_password`, `attic_token_hs256_secret_base64`,
`wildcard_cert`, `wildcard_key`.

Push-only: `copyparty_upload_token` (also the docker-registry htpasswd password
and the gitea `upload` user cred — owner=gitea), `gitea_admin_password`
(defaults `admin`; gitea-admin-seed fail-closes on REPLACE_ME/empty).

Notes:
- `s3_endpoint_url`: empty on graynet (AWS-native, region-derived endpoint);
  `https://s3.irad.dn.lan` on darknet. `s3-env.nix` emits `AWS_ENDPOINT_URL_S3`
  / `ATTIC_SERVER_STORAGE_S3_ENDPOINT` / `REGISTRY_STORAGE_S3_REGIONENDPOINT`
  only when non-empty.
- `ntp_servers`: required on darknet — S3 SigV4 has a 15-min clock-skew window
  and the airgap has no public NTP.
- Empty `static_ip` ⇒ DHCP (`99-dhcp.network`); non-empty renders
  `10-static.network` via `network-config.service`.
- On upgrade, the placeholder deep-merges UNDER the existing file: new schema
  keys arrive as REPLACE_ME, existing values win, failures non-fatal
  (fallback: `sops --set`).
