#!/usr/bin/env python3
"""List a copyparty path — query the tree BEFORE uploading so raw files stay
clean and nothing is clobbered.

    cpls.py <path> [--host URL] [--user U] [--password P] [--json]

Examples:
    cpls.py /cxa/releases/
    cpls.py /cxa/releases/copyparty/ --json
"""
import argparse
import base64
import json
import ssl
import sys
import urllib.request


def main():
    ap = argparse.ArgumentParser(description="list a copyparty directory (?ls)")
    ap.add_argument("path", help="path on the server, e.g. /cxa/releases/")
    ap.add_argument("--host", default="https://copy.graynet.lan")
    ap.add_argument("--user", default="admin")
    ap.add_argument("--password", default="admin")
    ap.add_argument("--json", action="store_true", help="print raw JSON")
    a = ap.parse_args()

    url = a.host.rstrip("/") + "/" + a.path.strip("/") + "/?ls"
    req = urllib.request.Request(url)
    cred = base64.b64encode(f"{a.user}:{a.password}".encode()).decode()
    req.add_header("Authorization", "Basic " + cred)
    # internal host with a private CA; data is non-sensitive
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    try:
        data = json.load(urllib.request.urlopen(req, timeout=30, context=ctx))
    except Exception as e:  # noqa: BLE001
        print(f"error listing {url}: {e}", file=sys.stderr)
        return 1

    if a.json:
        print(json.dumps(data, indent=2))
        return 0

    print(f"# {url}")
    if data.get("srvinf"):
        print(f"# {data['srvinf']}")
    for d in data.get("dirs", []):
        n = d.get("tags", {}).get(".files", "?")
        print(f"  d  {d['href']:<44} {n} files   {d.get('sz', 0)} B")
    for f in data.get("files", []):
        print(f"  f  {f['href']:<44}            {f.get('sz', 0)} B")
    if not data.get("dirs") and not data.get("files"):
        print("  (empty)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
