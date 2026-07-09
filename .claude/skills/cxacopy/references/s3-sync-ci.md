# Set up a repo for darknet pushes (inf/s3-sync catalog)

The **`inf/s3-sync`** CI/CD Catalog mirrors release artifacts from
`copy.graynet.lan` to `copy.irad.dn.lan` (darknet) over the S3 sync (~6 min).
Add the relevant component to your `.gitlab-ci.yml`. All components authenticate
with the group-wide **`COPYPARTY_UPLOAD`** (`user:password`) CI variable — set
once on the `inf/` group, not per repo.

Browse versions + inputs: <https://gitlab.graynet.lan/explore/catalog/inf/s3-sync>

Gate these to releases (run on tags):
```yaml
rules:
  - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
```

## TLS / the internal CA
`copy.graynet.lan` serves the graynet wildcard cert (internal CA). Graynet runners
usually trust it system-wide, but **generic runner images / containers do not**, so:
- `pypi-publish`, `docker-push`, `docker-build-push` expose a **`tls_verify`** input
  → set `tls_verify: false` when the image lacks the graynet CA (the `-k` equivalent).
- raw `curl` → add `-k`.
- `uv publish` / plain `attic` have no `-k` flag → point them at the CA with
  `SSL_CERT_FILE=/path/rootca64.cer` (or run on a graynet host where it's trusted).

## PyPI (wheels) — `pypi-publish`
PUTs wheels to `/pypi/packages/`, which rebuilds the PEP 503 index.
```yaml
build:
  stage: build
  image: ghcr.io/astral-sh/uv:python3.12-bookworm
  script: [uv build]                 # dist/*.whl + dist/*.tar.gz
  artifacts:
    paths: [dist/]
include:
  - component: gitlab.graynet.lan/inf/s3-sync/pypi-publish@~latest
    inputs:
      wheels: "dist/*.whl"
      needs: [{ job: build, artifacts: true }]
```
Consume on darknet: `pip install --index-url https://copy.irad.dn.lan/pypi/simple/ <pkg>`

## Docker images
Build a Dockerfile and push (`docker-build-push`):
```yaml
include:
  - component: gitlab.graynet.lan/inf/s3-sync/docker-build-push@~latest
    inputs:
      image: copy.graynet.lan/$CI_PROJECT_PATH:$CI_COMMIT_TAG
      dockerfile: Dockerfile
```
Or mirror an already-built `$CI_REGISTRY` image (`docker-push`, skopeo):
```yaml
include:
  - component: gitlab.graynet.lan/inf/s3-sync/docker-push@~latest
    inputs:
      source: $CI_REGISTRY_IMAGE:$CI_COMMIT_TAG
      destination_repo: $CI_PROJECT_PATH
      destination_tag: $CI_COMMIT_TAG
```
Consume on darknet: `docker pull copy.irad.dn.lan/<repo>:<tag>` (anonymous).

## Git repositories — `git-mirror`
Mirrors the repo's branches + tags (incl. Git LFS) to the graynet **gitea**
server at `copy.graynet.lan/git/`; gitea replicates the bare repo over the S3
sync to the darknet. Auth is the same `COPYPARTY_UPLOAD` credential as the
other components (the push-side gitea seeds a matching `upload` user).
```yaml
include:
  - component: gitlab.graynet.lan/inf/s3-sync/git-mirror@~latest
    rules:
      - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
```
Lands at `copy.graynet.lan/git/upload/<repo>.git` (default
`destination_repo: upload/$CI_PROJECT_NAME`; push-create makes it).
Consume on darknet (anonymous, read-only):
```bash
git clone https://copy.irad.dn.lan/git/upload/<repo>.git
git -C <repo> remote update --prune   # keep in sync
```
Web UI / by-hand push: <https://copy.graynet.lan/git/> (login `admin`/`admin`).

**Push 401s for `admin`/`upload` but anon clone works?** The push-side gitea
account is flagged `must_change_password` (gitea rejects basic auth for git +
API when set) — an **appliance-side** fault, not your CI config or a wrong
`COPYPARTY_UPLOAD`. Fix/remediation is in the **cxacopy-infra** skill
(push-vs-pull.md → "Gotcha: `must_change_password`"); ping whoever runs the
appliance to redeploy the seed fix or clear the flag.

## Nix (binary cache) — no component yet, use `attic`
```yaml
nix-push:
  tags: [nix]
  script:
    - nix build .#default
    - attic login copy-graynet https://copy.graynet.lan/nix/ "$ATTIC_TOKEN"
    - attic push copy-graynet:main ./result
```
The login URL **must** end in `/nix/` (trailing slash) — without it `attic` strips
the path segment and pushes 404 against copyparty. `attic.graynet.lan` is legacy/retired.
Off-graynet runners need the internal CA: `SSL_CERT_FILE=…/rootca64.cer`.
Consume on darknet (public cache, anonymous):
```ini
substituters = https://copy.irad.dn.lan/nix/main https://cache.nixos.org/
trusted-public-keys = main:b8OO6tyPaSeO18oQ2tzBCDs3XeATSdJ/NZlMhhqeHuk= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
```

## Raw release artifacts (ISOs, tarballs) — `copyparty-upload`
For CI; for ad-hoc pushes use this skill's u2c.py/curl flow instead.
```yaml
include:
  - component: gitlab.graynet.lan/inf/s3-sync/copyparty-upload@~latest
    inputs:
      file: dist/myapp.tar.gz
      destination_subdir: myapp/$CI_COMMIT_TAG
      overwrite: always          # default; replace in place on re-upload
      needs: [{ job: build, artifacts: true }]
```

**`overwrite` (default `always`)** — collision policy when a same-name file
already exists on the server with **different** content:

| Value | u2c flag | Behavior |
|-------|----------|----------|
| `always` | `--ow` | Replace in place. Use for release artifacts so a rebuilt same-version file doesn't pile up as `name-<ts>` dupes. |
| `if-older` | `--owo` | Replace only if the server copy's mtime is older (timestamp-gated, **not** hash-gated). |
| `never` | *(none)* | u2c autorenames the upload → copyparty keeps a `name-<ts>` duplicate (legacy behavior). |

Byte-**identical** re-uploads are always skipped by up2k's content-hash
handshake regardless of `overwrite` — that dedup is inherent, not a flag. So
`always` means "skip if the hashes match, replace cleanly if they differ."
`--ow`/`--owo` require the upload account to have `d` (delete) on the volume
(the graynet `upload` user has `rwd` on `[/]`).

## Component inputs (defaults)
- `pypi-publish`: `wheels="dist/*.whl"`, `pypi_host="copy.graynet.lan"`, `pypi_path="/pypi/packages/"`, `stage="deploy"`, `needs=[]`
- `docker-build-push`: `image="copy.graynet.lan/$CI_PROJECT_PATH:$CI_COMMIT_TAG"`, `dockerfile="Dockerfile"`, `context="$CI_PROJECT_DIR"`, `stage="build"`
- `docker-push`: `source` (required), `destination_repo` (required), `destination_tag="$CI_COMMIT_TAG"`, `destination_host="copy.graynet.lan"`, `stage="deploy"`
- `copyparty-upload`: `file` (required), `destination_subdir` (required), `copyparty_url="https://copy.graynet.lan"`, `stage="package"`, `id_suffix=""`, `overwrite="always"` (`always`|`if-older`|`never`), `needs=[]`
