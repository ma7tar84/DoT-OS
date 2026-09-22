#!/usr/bin/env python3
"""Diagnose 'manifest unknown': are there CI runs? does the GHCR package
exist? what tags are published?"""
import base64, json, os, subprocess, urllib.request, urllib.error, ssl

BASE = os.path.dirname(os.path.abspath(__file__))
REPO = "ma7tar84/DoT-OS"
API = f"https://api.github.com/repos/{REPO}"
REG = "ghcr.io/ma7tar84"
PKG = "dot-os"

ctx = ssl.create_default_context()


def get_token():
    out = subprocess.check_output(
        ["git", "credential", "fill"],
        input=b"protocol=https\nhost=github.com\n\n",
    ).decode()
    for line in out.splitlines():
        if line.startswith("password="):
            return line.split("=", 1)[1].strip()
    raise SystemExit("no token")


TOK = get_token()
GH = {"Authorization": f"Bearer {TOK}", "Accept": "application/vnd.github+json",
      "User-Agent": "dot-os-check"}


def gh(url):
    r = urllib.request.Request(url, headers=GH)
    try:
        with urllib.request.urlopen(r, timeout=30, context=ctx) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        return {"__error__": e.code, "__body__": e.read().decode(errors="replace")[:300]}


print("=" * 60)
print("[1] GitHub Actions workflow runs (newest first)")
print("=" * 60)
runs = gh(f"{API}/actions/runs?per_page=15").get("workflow_runs", [])
if not runs:
    print("  (none) — the build has never run")
for r in runs:
    print(f"  [{r['status']:>9}] concl={str(r.get('conclusion')):>10}  "
          f"run_id={r['id']}  created={r['created_at']}  event={r['event']}")

if runs:
    latest = runs[0]
    print("\n  -> fetching logs of latest run (run_id=%s)" % latest["id"])
    # need the job id
    jobs = gh(f"{API}/actions/runs/{latest['id']}/jobs?per_page=5").get("jobs", [])
    for job in jobs:
        print(f"      job [{job.get('status')}] {job.get('name')} -> "
              f"https://github.com/ma7tar84/DoT-OS/actions/runs/{latest['id']}/job/{job['id']}")

print()
print("=" * 60)
print("[2] GHCR package + tags (anonymous probe)")
print("=" * 60)
# anonymous GHCR: package token for _catalog may be denied; try package token
tok_url = f"https://{REG}/token?service=ghcr.io&scope=repository:{PKG}:pull"
try:
    with urllib.request.urlopen(tok_url, timeout=30, context=ctx) as resp:
        tok = json.load(resp).get("token", "")
    print("  got anonymous token:", "yes" if tok else "NO")
except Exception as e:
    tok = ""
    print("  anonymous token error:", e)

if tok:
    hdrs = {"Authorization": f"Bearer {tok}", "User-Agent": "dot-os-check"}
    # list tags
    url = f"https://{REG}/v2/{PKG}/tags/list"
    r = urllib.request.Request(url, headers=hdrs)
    try:
        with urllib.request.urlopen(r, timeout=30, context=ctx) as resp:
            tags = json.load(resp).get("tags", [])
        print(f"  tags on ghcr.io/ma7tar84/{PKG}: {tags if tags else '(NONE)'}")
    except urllib.error.HTTPError as e:
        print(f"  tags list HTTP {e.code}: {e.read().decode(errors='replace')[:200]}")
    # try manifest for latest
    for tag in (["latest"] if not tags else tags[:1] + (["latest"] if "latest" not in tags else [])):
        url = f"https://{REG}/v2/{PKG}/manifests/{tag}"
        r = urllib.request.Request(url, headers={**hdrs, "Accept": "application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json"})
        try:
            with urllib.request.urlopen(r, timeout=30, context=ctx) as resp:
                print(f"  manifest [{tag}]: HTTP {resp.status} OK")
        except urllib.error.HTTPError as e:
            print(f"  manifest [{tag}]: HTTP {e.code}")
