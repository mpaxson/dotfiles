# Deploy & update workflows

All recipes run from the `builder/` repo root on a **graynet controller**
workstation. Canonical runbooks (read before any install — they ship with each
ISO release): `automation/flakes/copyparty/docs/push-instructions.md` and
`pull-instructions.md`.

## Which path applies

| Target | Reachable from controller? | Path |
|---|---|---|
| `copy.graynet.lan` (push) | yes | just recipes below |
| `copy-pull.lab.graynet.lan` (lab pull) | yes | just recipes (Path A) |
| `copy.irad.dn.lan` (production darknet pull) | **no — airgap** | Path B manual on-VM, or `copyparty-upgrade` in-place |

## Controller prerequisites (one-time)

1. Clone the builder monorepo:
   `git clone --recurse-submodules git@gitlab.graynet.lan:inf/flakes/builder.git`
   (the flake lives in the `automation` submodule). Install **Determinate Nix** (matches the
   gitlab-runner's nix so flake.lock authoring validates in CI).
2. SOPS age key for the `inf/flakes` vault — verify decryption works.
3. The automation SSH key that `admin@<vm>` trusts (baked into the ISO via
   `os.flake/keys.nix`). If SSH fails `Permission denied (publickey)`:
   `just vm::_common::_ssh_setup && just vm::_common::_ssh_add copyparty-<role> graynet`.

## VM lifecycle recipes (`just/vm/copyparty-{push,pull}.just`)

```bash
just vm::copyparty-push::create graynet        # create the vSphere VM
just vm::copyparty-push::install graynet [ip]  # NixOS install onto live-ISO-booted VM
just vm::copyparty-push::deploy graynet        # create-if-missing + install
just vm::copyparty-push::redeploy graynet      # destroy + create + install
just vm::copyparty-push::update graynet        # config change, no re-image (see below)
just vm::copyparty-push::ssh                   # SSH in as admin
just vm::copyparty-push::ip graynet            # VM IP from vSphere
# same verbs under vm::copyparty-pull:: for the lab pull
just vm::copyparty-push::download-model <hf_model> <rev>  # push-only (pull data dir is RO)
```

## `update` — the normal config-change flow

`just vm::copyparty-push::update graynet` (or `copyparty-pull` for lab):

1. Snapshots local `flakes/copyparty/` into `/tmp/staging/`, stripping secrets.
2. SCPs to the VM at `/tmp/nixos-upload/`.
3. Preserves `/etc/nixos/secrets.sops.yml` (+ `hostname.nix`) on the VM.
4. `nix copy`s the `os` flake closure to the VM first (the VM has no gitlab
   SSH creds, so it can't fetch that input itself).
5. Runs `sudo nixos-rebuild switch --flake /etc/nixos#copyparty-<role>`.

Re-runnable, idempotent, non-interactive. Failure modes:

- **`Permission denied (publickey)`** → regenerate SSH config (see prereq 3).
- **`invalid or unknown remote ssh hostkey` mid-rebuild** → VM lacks
  `gitlab.graynet.lan` in root's known_hosts; `ssh-keyscan -t ed25519,rsa
  gitlab.graynet.lan | ssh admin@copy.graynet.lan 'sudo tee -a /root/.ssh/known_hosts'`.
- **`No such option: edge.dockerRegistryServer.…`** → stale `os` flake on the
  VM; re-run, the recipe pre-copies a fresher closure.
- **authed `git push` / `git-mirror` CI 401s for `admin`/`upload`** (anon clone
  fine) → the gitea account is flagged `must_change_password` and gitea rejects
  basic auth. Caused by the pre-fix `gitea-admin-seed` rotate path. Redeploy
  once the `gitea.nix` fix is in (auto-clears), or run the immediate remediation
  in push-vs-pull.md → "Gotcha: `must_change_password` breaks authed git push".

## ISO release flow

`flakes/copyparty-iso/` bakes the **full system closure + a pre-rendered disko
partition script** into a live ISO per role — install needs zero nix eval and
zero network (true-airgap-safe). Version in `copyparty-iso/version.yaml`; tag
`copyparty-vX.Y.Z` → CI builds both ISOs, uploads to vSphere datastore and to
`https://copy.graynet.lan/cxa/releases/copyparty/cxacopy-vX.Y.Z/` (ISOs + the
two instruction runbooks). A full re-image is only needed when the SOPS schema
or disko layout changes — `update` covers everything else.

## Production darknet pull (`copy.irad.dn.lan`)

No controller can reach it. Two options:

- **In-place upgrade (preferred, v0.6.15+)**: carry the new ISO across, boot
  the host from it, run the baked helper:
  ```bash
  copyparty-upgrade            # mounts existing partitions, refreshes staged
                               # flake, nixos-install — then YOU `sudo reboot`
  copyparty-upgrade --reboot   # same + auto-reboot
  ```
  Never runs disko ⇒ `/etc/sops/age/keys.txt` and `secrets.sops.yml` survive.
  Old generations accumulate across in-place upgrades — GC occasionally.
- **Fresh install (Path B)**: boot ISO → run baked disko script → stage flake →
  set hostname → `nixos-install` the baked closure → reboot → fill SOPS
  placeholder (`sops --set` each REPLACE_ME; needs **read-only** S3 creds,
  `s3_endpoint_url: https://s3.irad.dn.lan`, `ntp_servers`) →
  `switch-to-configuration switch`. Full steps + on-box debugging cheatsheet:
  `pull-instructions.md` §B1–B10.

## Verify after any deploy/update

```bash
# Anon GET on every surface (push host shown; swap host for pull)
curl -sk https://copy.graynet.lan/cxa/releases/?ls | head
curl -sk https://copy.graynet.lan/nix/ | head -1          # attic handshake
curl -sk https://copy.graynet.lan/v2/ -o /dev/null -w '%{http_code}\n'
curl -sk https://copy.graynet.lan/pypi/simple/ | head
# Pull side: confirm writes are rejected (expect 401/403/EROFS)
curl -sk -X PUT https://copy.irad.dn.lan/cxa/test -d x -o /dev/null -w '%{http_code}\n'
# On-box: mount live + services green
ssh admin@<vm> 'mountpoint /srv/copyparty/data; systemctl --failed'
```

Pull-side freshness check: push a file on graynet, expect it on
`copy.irad.dn.lan` within ~6 min (worst ~10: 5-min rclone-sync + 15-min
prewarm tick overlap).
