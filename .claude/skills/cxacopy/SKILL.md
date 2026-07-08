---
name: cxacopy
description: Push raw files to copyparty (copy.graynet.lan / CXACopy). List the tree first via ?ls, then upload via u2c.py/curl into per-project folders under /cxa/releases/. Not for packages (use uv/nix/docker).
---

# CXACopy (raw-file push)

Upload **raw files** (ISOs, tarballs, blobs, datasets, images) to
**copy.graynet.lan** — the CXACopy push side. It mirrors to `copy.irad.dn.lan`
(darknet, read-only) over the S3 sync (~6 min).

## Not for packages
Publish packages with their native tooling + CI, not raw uploads:
- **PyPI** → `uv publish` (lands under `/pypi/`)
- **Nix** → `attic push` / `nix copy` (see [Nix (attic push)](#nix-attic-push) below)
- **Docker** → `docker push` + the `inf/s3-sync` catalog
- **Maven / Gradle / Android** → resolve through the Reposilite proxy at `/maven/`
  (pull-through cache of Maven Central + Google + Gradle plugins); anon `mvn deploy`
  first-party artifacts to `/maven-internal/`; `/gradle/` wrapper distros +
  `/android-sdk/` SDK mirror. Client setup (JVM truststore, `init.gradle`,
  `settings.xml` mirror, warming with a throwaway local repo) is in the
  **[Maven / Gradle / Android](../../docs/cxacopy/maven.md)** user doc (served at
  `/help/cxacopy/maven/`). Curated Google-Maven groups refresh daily.
- **Git repos** → the `inf/s3-sync/git-mirror` component (mirrors branches +
  tags + LFS to gitea at `/git/`; darknet clones `copy.irad.dn.lan/git/...`)
Prefer **git-commit / CI automation** for repeatable release uploads — see
`references/s3-sync-ci.md` for ready `.gitlab-ci.yml` snippets that wire a repo up
for git / docker / pypi / nix / raw pushes via the `inf/s3-sync` catalog. Use this
skill for ad-hoc raw pushes.

## Auth (non-sensitive)
User `admin` / password `admin`, or the upload token `upload`.
- u2c: `-a admin:admin` (or `-a upload`)
- curl basic: `-u admin:admin`
- curl token: header `-H "PW: upload"` or `?pw=upload`

**Always pass `-k` to curl.** copyparty serves the graynet wildcard cert (internal
CA) — trusted on graynet hosts, but **not** in CI runners / containers, where curl
fails TLS without `-k`. Harmless on graynet, required off it.

## Nix (attic push)
Push nix store paths to the copyparty-hosted atticd binary cache. **This is the
package path — don't `curl -T` `.narinfo`/`.nar` blobs into `/cxa/releases/`.**

- **Cache endpoint:** `https://copy.graynet.lan/nix/` (the **trailing slash is
  required** by attic-client). Cache name: `main`.
- **Public key (anonymous reads, no token):**
  `main:b8OO6tyPaSeO18oQ2tzBCDs3XeATSdJ/NZlMhhqeHuk=`
- **Push token** (JWT, `sub: gitlab-ci`, scope pull on `*` + push to `main`, exp
  2033-06-11). In CI it's the `ATTIC_TOKEN` var, sourced from SOPS `attic_token`
  in `builder/automation/ansible/vars/environments/graynet.secrets.yml` (and the
  gitlab-runner secrets). Re-minted with `attic-mint-token` on copy.graynet.lan;
  must be re-minted whenever the atticd HS256 secret rotates, or it silently 403s:
  ```
  eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjIwMDIwNjA4MDAsIm5iZiI6MTc4MTIxNzI5Nywic3ViIjoiZ2l0bGFiLWNpIiwiaHR0cHM6Ly9qd3QuYXR0aWMucnMvdjEiOnsiY2FjaGVzIjp7IioiOnsiciI6MX0sIm1haW4iOnsiciI6MSwidyI6MX19fX0.-NdoTGwan-koiEnPSTBAiD7ZkauPaww_Pp1VBxJsy4Y
  ```

```bash
ATTIC_TOKEN='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjIwMDIwNjA4MDAsIm5iZiI6MTc4MTIxNzI5Nywic3ViIjoiZ2l0bGFiLWNpIiwiaHR0cHM6Ly9qd3QuYXR0aWMucnMvdjEiOnsiY2FjaGVzIjp7IioiOnsiciI6MX0sIm1haW4iOnsiciI6MSwidyI6MX19fX0.-NdoTGwan-koiEnPSTBAiD7ZkauPaww_Pp1VBxJsy4Y'
attic login attic https://copy.graynet.lan/nix/ "$ATTIC_TOKEN"
attic push attic:main /nix/store/<paths…>        # or:  attic push attic:main ./result
```

**Off-graynet pushers** (CI runners / containers) need the graynet **internal CA**
in their trust store — attic-client has no `-k` equivalent and will fail TLS
without it. On-graynet hosts already trust the wildcard cert.

For CI, prefer the ready template `just/utils/ci/attic-push.gitlab-ci.yml` in
`builder/automation` (extend `.attic-push`, set `ATTIC_PACKAGES`) over hand-rolling
the login/push — see `references/s3-sync-ci.md`.

## Workflow — ALWAYS list first
1. **List the target tree** so you reuse folders and never clobber:
   ```bash
   python3 scripts/cpls.py /cxa/releases/                 # what groups exist
   python3 scripts/cpls.py /cxa/releases/<project>/       # existing versions
   ```
   (raw: `curl -sk -u admin:admin "https://copy.graynet.lan/cxa/releases/?ls"`)
2. **Choose the folder** per layout (below). Reuse an existing `<project>/`;
   don't create near-duplicates — check the listing first.
3. **Upload**:
   - folders / releases / many or large files → **u2c.py** (resumable, dedup,
     auto-creates dirs):
     ```bash
     python3 scripts/u2c.py -a admin:admin \
       https://copy.graynet.lan/cxa/releases/<project>/<version>/ ./dist/
     ```
   - one raw file → **curl PUT** (also auto-creates parent dirs):
     ```bash
     curl -k -u admin:admin -T ./build.iso \
       https://copy.graynet.lan/cxa/releases/<project>/<version>/build.iso
     ```
4. **Verify**: re-run `cpls.py` on the folder; confirm file count + sizes.

## Folder layout under /cxa/releases/
- **Versioned release** → `<project>/<version>/`
  (e.g. `copyparty/cxacopy-v1.2.3/`). Matches the existing ISO layout.
- **Non-versioned raw items** → group by item type: `<project>/<type>/`
  (e.g. `edgeos/images/`, `docker-sync/<name>/`).
- One folder per logical group; put files **inside** it, never loose at the
  `/cxa/releases/` root.

## Resources
- `scripts/cpls.py` — list a copyparty path (the query-first helper). `--json` for raw.
- `scripts/u2c.py` — copyparty up2k client (bundled). `-h` for all flags.
- `scripts/cpmirror.py` — mirror a local dir to copyparty with overwrite
  (DELETE-then-PUT per file, `--prune` removes stale). e.g. publish a built site.
- `references/copyparty-api.md` — `?ls` JSON fields, PUT/u2c/mkdir behavior, hosts.
- `references/inf-docs.md` — update the inf-docs site: graynet/darknet tags, edits, build & verify.
- `references/s3-sync-ci.md` — wire a repo for git/docker/pypi/nix/raw pushes via CI.
- For working **on** the appliance itself (the copyparty flake, push/pull roles,
  darknet pull side, deploys), use the **cxacopy-infra** skill.

## Distribution
Published as a zip at `https://copy.graynet.lan/cxa/skills/cxacopy/cxacopy.zip` by
the `docs-publish-skill` CI job whenever `.claude/skills/cxacopy/` changes. copyparty
**auto-renames on collision**, so the job does **DELETE then PUT** to keep one
canonical file (PUT alone would leave `cxacopy.zip-<ts>_.zip` dupes).
