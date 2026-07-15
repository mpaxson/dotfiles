#!/usr/bin/env bash
# Update the installed `cxacopy-infra` Claude Code skill from the CXA mirror.
#
# Fetches copy.graynet.lan/cxa/skills/cxacopy-infra/manifest.yaml and compares
# its `updated` timestamp against this skill's local manifest.yaml. If they
# differ, downloads the latest cxacopy-infra.zip and replaces this skill
# directory in place. No-op when already current. (The skill isn't versioned —
# `updated` is the only freshness key; `commit` is shown for provenance but
# never compared.)
#
# Env overrides:
#   CXACOPY_MIRROR  mirror host (default: copy.graynet.lan; darknet: copy.irad.dn.lan)
set -euo pipefail

MIRROR="${CXACOPY_MIRROR:-copy.graynet.lan}"
BASE="http://${MIRROR}/cxa/skills/cxacopy-infra"   # http:// avoids the graynet-cert TLS dance

# This script lives in <skill-dir>/scripts/, so the skill dir is one level up.
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_MANIFEST="$SKILL_DIR/manifest.yaml"

info() { printf '\033[0;34mℹ\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m✓\033[0m %s\n' "$*"; }
die()  { printf '\033[0;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

command -v curl  >/dev/null 2>&1 || die "curl is required."
command -v unzip >/dev/null 2>&1 || die "unzip is required."

# Read a top-level scalar (name/updated/commit) from a simple manifest.yaml.
manifest_field() { # <file> <key>
  grep -E "^$2:" "$1" 2>/dev/null | head -1 | sed -E "s/^$2:[[:space:]]*//; s/[\"']//g; s/[[:space:]]+$//"
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

info "Checking $BASE/manifest.yaml ..."
curl -fsSL "$BASE/manifest.yaml" -o "$work/manifest.yaml" \
  || die "Could not fetch the remote manifest. Is $MIRROR reachable?"

remote_updated="$(manifest_field "$work/manifest.yaml" updated)"
remote_commit="$(manifest_field "$work/manifest.yaml" commit)"
[ -n "$remote_updated" ] || die "Remote manifest has no 'updated' field."

local_updated=""
[ -f "$LOCAL_MANIFEST" ] && local_updated="$(manifest_field "$LOCAL_MANIFEST" updated)"

if [ "$local_updated" = "$remote_updated" ]; then
  ok "cxacopy-infra skill is up to date (updated $remote_updated)."
  exit 0
fi

info "Update available: local='${local_updated:-none}' -> remote='$remote_updated' (${remote_commit:-?}). Downloading ..."
curl -fsSL "$BASE/cxacopy-infra.zip" -o "$work/cxacopy-infra.zip" || die "Download of cxacopy-infra.zip failed."
unzip -q -o "$work/cxacopy-infra.zip" -d "$work/unpacked"
[ -f "$work/unpacked/cxacopy-infra/SKILL.md" ] || die "Archive is missing cxacopy-infra/SKILL.md; aborting (local skill untouched)."

# Replace the skill directory in place, preserving its path/name so Claude Code
# still discovers it. The running script was already read into memory, so
# removing its own file mid-run is safe on Linux.
rm -rf "$SKILL_DIR"
mv "$work/unpacked/cxacopy-infra" "$SKILL_DIR"

ok "Updated cxacopy-infra skill (updated $remote_updated${remote_commit:+, commit $remote_commit})."
info "Restart Claude Code (or reopen the session) to load the new version."
