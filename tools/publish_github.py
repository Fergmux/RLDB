"""Publish RLDB to GitHub (github.com/Fergmux/RLDB, PUBLIC).

    python -I tools/publish_github.py sync               # upload the source (history without QA evidence)
    python -I tools/publish_github.py release            # sync, then release the current builds as v<version>
    python -I tools/publish_github.py release --clobber  # replace the assets of an existing v<version>

sync: makes a throwaway hardlinked bare clone of this repo with only `main` and `build/rldb-game`,
strips `production/qa/evidence/` from all history with git-filter-repo (5.9 GB of screenshots; GitHub
takes at most 2 GB per push), and pushes both branches. The filter is deterministic, so every sync
re-creates the same commits and the push is a fast-forward; it is never forced. Commit hashes on
GitHub therefore differ from local ones.

release: zips the playtest build (build/windows -> build/RLDB-friends.zip) and the dev build
(build/windows-dev -> build/RLDB-dev.zip) and creates the GitHub release v<config/version> at the
tip of build/rldb-game. Builds must have been exported first; this never exports.

Needs: git, gh (logged in), uvx (for git-filter-repo). Credentials stay in gh's keyring.
"""
import argparse
import datetime
import os
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = "Fergmux/RLDB"
REMOTE = "https://github.com/%s.git" % REPO
BRANCHES = ["main", "build/rldb-game"]
RELEASE_BRANCH = "build/rldb-game"
STRIP_PATHS = ["production/qa/evidence/"]
MIRROR = os.path.join(os.path.dirname(ROOT), ".rldb-github-mirror")
GH_CANDIDATES = [shutil.which("gh") or "", r"C:\Program Files\GitHub CLI\gh.exe"]
SHARED_FILES = ["libgodotsteam.windows.template_release.x86_64.dll", "steam_api64.dll", "steam_appid.txt"]
BUILDS = {
    # asset name: (folder, exe, pck)
    "RLDB-friends.zip": ("build/windows", "RLDB.exe", "RLDB.pck"),
    "RLDB-dev.zip": ("build/windows-dev", "RLDB-dev.exe", "RLDB-dev.pck"),
}


def gh_exe():
    for c in GH_CANDIDATES:
        if c and os.path.exists(c):
            return c
    sys.exit("gh (GitHub CLI) not found. Install: winget install --id GitHub.cli, then gh auth login.")


def run(cmd, cwd=ROOT, capture=False, check=True):
    print("+ " + " ".join(cmd), flush=True)
    r = subprocess.run(cmd, cwd=cwd, text=True, capture_output=capture)
    if check and r.returncode != 0:
        if capture:
            sys.stderr.write((r.stdout or "") + (r.stderr or ""))
        sys.exit("Command failed (exit %d): %s" % (r.returncode, " ".join(cmd)))
    return r


def git(*args, cwd=ROOT, capture=True, check=True):
    return run(["git", *args], cwd=cwd, capture=capture, check=check)


def version():
    with open(os.path.join(ROOT, "rldb", "project.godot"), encoding="utf-8") as f:
        m = re.search(r'^config/version="([^"]+)"', f.read(), re.M)
    if not m:
        sys.exit("No config/version in rldb/project.godot.")
    return m.group(1)


def sync():
    gh = gh_exe()
    run([gh, "auth", "status"], capture=True)
    run([gh, "auth", "setup-git"], capture=True)   # git uses gh's keyring token for github.com
    if os.path.exists(MIRROR):
        shutil.rmtree(MIRROR, onerror=lambda f, p, e: (os.chmod(p, 0o700), f(p)))
    # Local clone = hardlinked objects: fast and no extra disk until the filter repacks.
    git("clone", "--bare", "--no-tags", ROOT, MIRROR, capture=False)
    keep = {"refs/heads/" + b for b in BRANCHES}
    for ref in git("for-each-ref", "--format=%(refname)", "refs/heads", cwd=MIRROR).stdout.split():
        if ref not in keep:
            git("update-ref", "-d", ref, cwd=MIRROR)
    filt = ["uvx", "git-filter-repo", "--force", "--invert-paths"]
    for p in STRIP_PATHS:
        filt += ["--path", p]
    run(filt, cwd=MIRROR)
    big = git("rev-list", "--objects", "--all", cwd=MIRROR).stdout
    pack_mb = sum(os.path.getsize(os.path.join(MIRROR, "objects", "pack", f))
                  for f in os.listdir(os.path.join(MIRROR, "objects", "pack"))) / 1048576
    print("Filtered repository: %.0f MB packed, %d objects." % (pack_mb, len(big.splitlines())))
    if pack_mb > 1800:
        sys.exit("Filtered history is still over 1.8 GB; GitHub would refuse the push. Not pushed.")
    r = git("push", REMOTE, *["refs/heads/%s:refs/heads/%s" % (b, b) for b in BRANCHES], cwd=MIRROR,
            capture=True, check=False)
    sys.stdout.write((r.stdout or "") + (r.stderr or ""))
    if r.returncode != 0:
        sys.exit("Push refused (not forced). If GitHub has commits this PC does not, sort that out by hand.")
    tip = git("rev-parse", "refs/heads/" + RELEASE_BRANCH, cwd=MIRROR).stdout.strip()
    print("Synced. GitHub %s is at %s." % (RELEASE_BRANCH, tip[:10]))
    return tip


def zip_build(asset, folder, exe, pck):
    src = os.path.join(ROOT, folder)
    files = [exe, pck] + SHARED_FILES
    missing = [f for f in files if not os.path.exists(os.path.join(src, f))]
    if missing:
        sys.exit("%s is missing %s. Export the builds first." % (folder, ", ".join(missing)))
    out = os.path.join(ROOT, "build", asset)
    tmp = out + ".tmp"
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for f in files:
            z.write(os.path.join(src, f), f)
    os.replace(tmp, out)
    built = datetime.datetime.fromtimestamp(os.path.getmtime(os.path.join(src, pck)))
    print("%s: %.0f MB (pck exported %s)" % (asset, os.path.getsize(out) / 1048576, built.strftime("%Y-%m-%d %H:%M")))
    return out, built


def release(clobber, notes_extra):
    gh = gh_exe()
    ver = version()
    tag = "v" + ver
    if git("status", "--porcelain", "--untracked-files=no", "--", "rldb").stdout.strip():
        print("WARNING: rldb/ has uncommitted changes; the builds may not match the uploaded source.")
    assets = [zip_build(a, *spec) for a, spec in BUILDS.items()]
    head_time = datetime.datetime.fromtimestamp(int(git("log", "-1", "--format=%ct", "--", "rldb", ":!*.uid").stdout.strip()))
    for path, built in assets:
        if built < head_time:
            print("WARNING: %s was exported before the last commit to rldb/ (%s); it may be stale."
                  % (os.path.basename(path), head_time.strftime("%Y-%m-%d %H:%M")))
    sync()
    local = git("rev-parse", "--short", "HEAD").stdout.strip()
    log = git("log", "-15", "--format=- %s", RELEASE_BRANCH).stdout
    notes = ("RLDB %s\n\n- **RLDB-friends.zip**: the playtest build (RLDB.exe). Unzip and run RLDB.exe; Steam must be running for online play.\n"
             "- **RLDB-dev.zip**: the dev build (RLDB-dev.exe); records telemetry as `dev`.\n\n"
             "Built from local commit %s.\n\n%sRecent changes:\n%s" % (ver, local, (notes_extra + "\n\n") if notes_extra else "", log))
    exists = run([gh, "release", "view", tag, "--repo", REPO], capture=True, check=False).returncode == 0
    files = [p for p, _ in assets]
    if exists:
        if not clobber:
            sys.exit("Release %s already exists. Bump config/version for a new release, or pass --clobber to replace its files." % tag)
        run([gh, "release", "upload", tag, *files, "--repo", REPO, "--clobber"])
        run([gh, "release", "edit", tag, "--repo", REPO, "--notes", notes])
    else:
        run([gh, "release", "create", tag, *files, "--repo", REPO, "--target", RELEASE_BRANCH,
             "--title", "RLDB " + ver, "--notes", notes, "--latest"])
    url = run([gh, "release", "view", tag, "--repo", REPO, "--json", "url", "-q", ".url"], capture=True).stdout.strip()
    print("Released: " + url)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("sync")
    r = sub.add_parser("release")
    r.add_argument("--clobber", action="store_true", help="replace the files of an existing release")
    r.add_argument("--notes", default="", help="extra text at the top of the release notes")
    a = ap.parse_args()
    if a.cmd == "sync":
        sync()
    else:
        release(a.clobber, a.notes)


if __name__ == "__main__":
    main()
