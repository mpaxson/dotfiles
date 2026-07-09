# Copyparty HTTP API (for raw-file push)

## Hosts
- **copy.graynet.lan** — push side, read+write. Upload here.
- **copy.irad.dn.lan** — darknet mirror, **read-only** (anonymous). Never upload.
- Same nginx layout on both: `/v2/*` (docker), `/pypi/simple/*` + `/pypi/packages/*`,
  `/nix/main/*`, `/cxa/releases/*` (raw files), `/*` (copyparty data UI).
- TLS uses the graynet wildcard cert (internal CA). On non-graynet hosts pass `-k`
  to curl / disable verify (data is non-sensitive).

## Auth (non-sensitive)
- User `admin`, password `admin` (full perms), or the upload token `upload`.
- copyparty reads the password from the **`PW`** header (or `?pw=`), not basic-auth.
  - curl token:  `-H "PW: upload"`  or  `"...?pw=upload"`
  - curl basic:  `-u admin:admin`  (nginx basic-auth also accepted)
  - u2c:         `-a admin:admin`  (or `-a upload`)

## List a directory — query FIRST (`?ls`)
`GET /<path>/?ls` with auth returns JSON:
```json
{
  "dirs":  [{"href":"copyparty/","sz":90875438617,"ts":1780686007,"tags":{".files":77}}],
  "files": [{"href":"build.iso","sz":123,"ts":...}],
  "perms": ["read","write","move","delete","admin"],
  "srvinf":"copyparty // 5.21 TiB free of 6.94 TiB"
}
```
- `dirs[].tags[".files"]` = file count in that folder; `sz` = bytes.
- Use this before every upload to reuse the right folder and avoid clobbering.
- Bundled helper: `scripts/cpls.py /cxa/releases/` (add `--json` for raw).

## Upload
copyparty **auto-creates parent folders** on upload — no explicit mkdir needed.

**Overwrite:** copyparty **auto-renames on filename collision** (even via PUT) →
re-uploading `x.zip` yields `x.zip-<ts>_.zip`. To replace a canonical file, either
`u2c --ow`, or **DELETE then PUT**:
```bash
curl -sk -u admin:admin -X DELETE "https://copy.graynet.lan/<path>/x.zip" || true
curl -fsSk -u admin:admin -T x.zip "https://copy.graynet.lan/<path>/x.zip"
```

### u2c.py (preferred for folders / releases / big files)
Resumable, chunk-deduplicated, uploads whole trees:
```bash
python3 scripts/u2c.py -a admin:admin \
  https://copy.graynet.lan/cxa/releases/<project>/<version>/ ./dist/
```
Useful flags: `-v` verbose, `--ow` overwrite (default auto-renames), `-x REGEX`
skip, `-s` filesearch-only (dedup check without uploading), `-h` full help.
Note: if the server runs with `--usernames`, pass `-a user:pass` (this one accepts
`admin:admin`).

### curl PUT (single raw file)
`-k` because the graynet wildcard cert (internal CA) isn't trusted in CI/containers.
```bash
curl -k -u admin:admin -T ./build.iso \
  https://copy.graynet.lan/cxa/releases/<project>/<version>/build.iso
```

### curl multipart (alternative)
```bash
curl -k -u admin:admin -F act=bput -F f=@./build.iso \
  https://copy.graynet.lan/cxa/releases/<project>/<version>/
```

## Folder layout under /cxa/releases/
- Versioned release → `<project>/<version>/` (e.g. `copyparty/cxacopy-v1.2.3/`).
- Non-versioned raw items → `<project>/<type>/` (e.g. `edgeos/images/`).
- Existing groups (example): `copyparty/`, `docker-sync/`, `edgeos/`.
- Files go **inside** a group folder, never loose at the `/cxa/releases/` root.

## Not for packages
Use native publishers (they target the right surface + integrate with CI):
- PyPI wheels → `uv publish` (or the `inf/s3-sync` `pypi-publish` component)
- Docker images → `docker push` + `inf/s3-sync` `docker-push` / `docker-build-push`
- Nix store paths → `attic push` / `nix copy`
For repeatable release uploads, drive it from CI (`inf/s3-sync` `copyparty-upload`)
on a tag/commit rather than pushing by hand.
