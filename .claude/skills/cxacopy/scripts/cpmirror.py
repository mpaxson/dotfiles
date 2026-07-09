#!/usr/bin/env python3
"""Mirror a local directory to a copyparty path, overwriting cleanly.

copyparty auto-renames on filename collision, so each file is uploaded as
DELETE-then-PUT (no `x.html-<ts>_.html` dupes). With --prune, remote files that no
longer exist locally are deleted too (a true mirror). TLS verification is off, so it
works from CI/containers without the graynet internal CA.

    cpmirror.py <local_dir> <dest_url> [--user U --password P --prune]
    cpmirror.py site/ https://copy.graynet.lan/help/ --prune
"""
import argparse
import base64
import os
import ssl
import sys
import urllib.parse
import urllib.request

_CTX = ssl.create_default_context()
_CTX.check_hostname = False
_CTX.verify_mode = ssl.CERT_NONE


def _do(method, url, user, pw, data=None):
    r = urllib.request.Request(url, data=data, method=method)
    r.add_header("Authorization", "Basic " + base64.b64encode(f"{user}:{pw}".encode()).decode())
    if data is not None:
        r.add_header("Content-Type", "application/octet-stream")
    return urllib.request.urlopen(r, timeout=300, context=_CTX)


def _remote_tree(base, user, pw, rel=""):
    """Recursively list remote (files, dirs) as relative paths under base via ?ls."""
    import json
    files, dirs = set(), set()
    url = base + urllib.parse.quote(rel) + "?ls"
    try:
        data = json.load(_do("GET", url, user, pw))
    except Exception:
        return files, dirs
    for f in data.get("files", []):
        files.add(rel + f["href"])
    for d in data.get("dirs", []):
        sub = rel + d["href"]              # e.g. "gitlab/"
        dirs.add(sub.rstrip("/"))
        sf, sd = _remote_tree(base, user, pw, sub)
        files |= sf
        dirs |= sd
    return files, dirs


def main():
    ap = argparse.ArgumentParser(description="mirror a dir to copyparty (overwrite)")
    ap.add_argument("local_dir")
    ap.add_argument("dest_url", help="e.g. https://copy.graynet.lan/help/")
    ap.add_argument("--user", default="admin")
    ap.add_argument("--password", default="admin")
    ap.add_argument("--prune", action="store_true", help="delete remote files not present locally")
    a = ap.parse_args()

    base = a.dest_url.rstrip("/") + "/"
    local = os.path.abspath(a.local_dir)
    local_files, local_dirs, n = set(), set(), 0
    for root, _dirs, files in os.walk(local):
        rdir = os.path.relpath(root, local).replace(os.sep, "/")
        if rdir != ".":
            local_dirs.add(rdir)
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), local).replace(os.sep, "/")
            local_files.add(rel)
            url = base + urllib.parse.quote(rel)
            try:
                _do("DELETE", url, a.user, a.password)  # avoid auto-rename
            except Exception:
                pass
            with open(os.path.join(root, f), "rb") as fh:
                _do("PUT", url, a.user, a.password, data=fh.read())
            n += 1
    print(f"uploaded {n} files -> {base}")

    if a.prune:
        rfiles, rdirs = _remote_tree(base, a.user, a.password)
        stale_files = rfiles - local_files
        for rel in stale_files:
            try:
                _do("DELETE", base + urllib.parse.quote(rel), a.user, a.password)
            except Exception:
                pass
        # delete now-stale dirs deepest-first (so empties go before parents)
        stale_dirs = sorted(rdirs - local_dirs, key=lambda d: d.count("/"), reverse=True)
        for rel in stale_dirs:
            try:
                _do("DELETE", base + urllib.parse.quote(rel) + "/", a.user, a.password)
            except Exception:
                pass
        print(f"pruned {len(stale_files)} file(s) + {len(stale_dirs)} dir(s)")


if __name__ == "__main__":
    sys.exit(main())
