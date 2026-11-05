"""Export every RLDB build in one go: Windows playtest + dev, and macOS.

    python -I -X utf8 tools/export_all.py                 # import, then Windows (playtest + dev) and macOS
    python -I -X utf8 tools/export_all.py --only macos    # or: --only windows
    python -I -X utf8 tools/export_all.py --check          # only report whether an export would be allowed
    python -I -X utf8 tools/export_all.py --build-dir D:/somewhere/build   # default: <repo>/build

Outputs (what tools/publish_github.py uploads):
    build/windows/RLDB.exe + RLDB.pck (+ the GodotSteam dll, steam_api64.dll, steam_appid.txt)
    build/windows-dev/RLDB-dev.exe + RLDB-dev.pck (written by the rldb_export editor plugin)
    build/macos/RLDB-macos.zip (RLDB.app, universal, ad-hoc signed)

Safety:
- Refuses to run while any process named RLDB* is running (the game or the dev build): overwriting the
  pck under a live game breaks its art loading. It never kills anything.
- The macOS zip is exported to a scratch folder, checked, and only then moved into build/macos, so a failed
  export never replaces a good zip with a half-written one.
- Every step is verified (exit code, fresh files, contents) and a failed step makes the whole run exit 1
  with FAILED in the summary. Nothing is reported as exported unless it was checked.
- Run it from the repo that holds the commit you want to ship. In a git worktree, pass --build-dir if the
  builds belong in the main tree's build/ folder.

The Godot executable comes from --godot, then the GODOT environment variable, then the default path below.
"""
import argparse
import os
import shutil
import subprocess
import sys
import time
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(ROOT, "rldb")
DEFAULT_GODOT = r"C:\Users\fergm\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
WINDOWS_PRESET = "Windows Desktop"
MACOS_PRESET = "macOS"
WINDOWS_FILES = ["RLDB.exe", "RLDB.pck", "libgodotsteam.windows.template_release.x86_64.dll", "steam_api64.dll",
                 "steam_appid.txt"]
DEV_FILES = ["RLDB-dev.exe", "RLDB-dev.pck"]
MACOS_REQUIRED = ["RLDB.app/Contents/MacOS/RLDB", "RLDB.app/Contents/Info.plist",
                  "RLDB.app/Contents/Resources/RLDB.pck", "RLDB.app/Contents/_CodeSignature/CodeResources",
                  "RLDB.app/Contents/Frameworks/libgodotsteam.macos.template_release.universal.dylib",
                  "RLDB.app/Contents/Frameworks/libsteam_api.dylib"]
FORBIDDEN_IN_PCK = ("tests/", "addons/gdUnit4", "addons/rldb_export", "reports/")


def running_rldb(tasklist_csv):
    """Names of the RLDB* processes in `tasklist /FO CSV /NH` output (one quoted image name per line)."""
    found = []
    for line in tasklist_csv.splitlines():
        line = line.strip()
        if not line.startswith('"'):
            continue
        name = line.split('","')[0].strip('"')
        if name.lower().startswith("rldb"):
            found.append(name)
    return found


def rldb_processes():
    """The running RLDB* processes. Raises RuntimeError if the process list cannot be read: an export must
    not go ahead on a guess."""
    if os.name == "nt":
        r = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True)
        if r.returncode != 0:
            raise RuntimeError("tasklist failed: " + (r.stderr or r.stdout).strip())
        return running_rldb(r.stdout)
    r = subprocess.run(["ps", "-A", "-o", "comm="], capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError("ps failed: " + (r.stderr or r.stdout).strip())
    return [os.path.basename(n) for n in r.stdout.split("\n") if os.path.basename(n).lower().startswith("rldb")]


def pck_paths(data):
    """File paths in a Godot 4 .pck (format 3) held in memory."""
    import struct
    if data[:4] != b"GDPC":
        raise ValueError("not a Godot pck")
    dir_off = struct.unpack("<Q", data[32:40])[0]
    count = struct.unpack("<I", data[dir_off:dir_off + 4])[0]
    p, out = dir_off + 4, []
    for _ in range(count):
        n = struct.unpack("<I", data[p:p + 4])[0]
        out.append(data[p + 4:p + 4 + n].rstrip(b"\0").decode("utf-8"))
        p += 4 + n + 8 + 8 + 16 + 4
    return out


def check_macos_zip(path):
    """Problems with an exported macOS zip, as a list of strings (empty = good)."""
    problems = []
    try:
        with zipfile.ZipFile(path) as z:
            names = set(z.namelist())
            bad = z.testzip()
            if bad:
                problems.append("corrupt member " + bad)
            for n in MACOS_REQUIRED:
                if n not in names:
                    problems.append("missing " + n)
            if not problems:
                head = z.read("RLDB.app/Contents/MacOS/RLDB")[:8]
                if head[:4] != b"\xca\xfe\xba\xbe" or head[4:8] != b"\x00\x00\x00\x02":
                    problems.append("RLDB.app/Contents/MacOS/RLDB is not a 2-architecture universal binary")
                pck = pck_paths(z.read("RLDB.app/Contents/Resources/RLDB.pck"))
                leaked = [n for n in pck if any(f in n for f in FORBIDDEN_IN_PCK)]
                if leaked:
                    problems.append("pck holds excluded paths, e.g. " + leaked[0])
                kinds = {k for k in ("s3tc", "etc2") if any(n.endswith(k + ".ctex") for n in pck)}
                if kinds != {"s3tc", "etc2"}:
                    problems.append("pck lacks a texture format (has %s; needs s3tc and etc2)" % sorted(kinds))
    except (zipfile.BadZipFile, OSError, ValueError) as e:
        problems.append("unreadable: %s" % e)
    return problems


def check_windows(build_dir, since):
    """Problems with the Windows playtest and dev folders after an export that started at `since`."""
    problems = []
    for folder, files in (("windows", WINDOWS_FILES), ("windows-dev", DEV_FILES)):
        for f in files:
            p = os.path.join(build_dir, folder, f)
            if not os.path.exists(p):
                problems.append("missing %s/%s" % (folder, f))
            elif f.endswith((".exe", ".pck")) and os.path.getmtime(p) < since:
                problems.append("%s/%s was not rewritten by this export" % (folder, f))
    return problems


def godot(godot_exe, *args):
    """Runs Godot in rldb/. Returns (exit code, output)."""
    print("+ godot " + " ".join(args), flush=True)
    r = subprocess.run([godot_exe, "--headless", "--path", PROJECT, *args], capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    return r.returncode, (r.stdout or "") + (r.stderr or "")


def tail(text, n=25):
    return "\n".join(text.strip().splitlines()[-n:])


def export_windows(godot_exe, build_dir):
    since = time.time() - 2
    out = os.path.join(build_dir, "windows", "RLDB.exe")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    appid = os.path.join(os.path.dirname(out), "steam_appid.txt")
    if not os.path.exists(appid):   # hand-placed once in build/windows; the exporter does not create it
        with open(appid, "w", encoding="ascii", newline="") as f:
            f.write("480")          # Spacewar, the Steam dev App ID (project.godot [steam] app_id)
        print("Wrote %s (App ID 480)." % appid)
    code, text = godot(godot_exe, "--export-release", WINDOWS_PRESET, out)
    if code != 0:
        return ["godot exited %d:\n%s" % (code, tail(text))]
    # The rldb_export plugin writes the dev copy; if its pck is older, copy it (as the handoff says).
    dev_pck = os.path.join(build_dir, "windows-dev", "RLDB-dev.pck")
    if os.path.exists(dev_pck) and os.path.getmtime(dev_pck) < os.path.getmtime(out.replace(".exe", ".pck")):
        shutil.copyfile(out.replace(".exe", ".pck"), dev_pck)
    return check_windows(build_dir, since)


def export_macos(godot_exe, build_dir):
    scratch = os.path.join(build_dir, "macos", ".export-tmp")
    shutil.rmtree(scratch, ignore_errors=True)
    os.makedirs(scratch)
    tmp_zip = os.path.join(scratch, "RLDB-macos.zip")
    code, text = godot(godot_exe, "--export-release", MACOS_PRESET, tmp_zip)
    if code != 0:
        shutil.rmtree(scratch, ignore_errors=True)
        return ["godot exited %d:\n%s" % (code, tail(text))]
    if not os.path.exists(tmp_zip):
        shutil.rmtree(scratch, ignore_errors=True)
        return ["godot reported success but wrote no zip:\n" + tail(text)]
    problems = check_macos_zip(tmp_zip)
    if not problems:
        os.replace(tmp_zip, os.path.join(build_dir, "macos", "RLDB-macos.zip"))
    shutil.rmtree(scratch, ignore_errors=True)
    return problems


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", choices=["windows", "macos"], help="export just one platform")
    ap.add_argument("--godot", default=os.environ.get("GODOT", DEFAULT_GODOT), help="Godot 4.6.1 console exe")
    ap.add_argument("--build-dir", default=os.path.join(ROOT, "build"))
    ap.add_argument("--skip-import", action="store_true", help="skip the `--import` pass (the .godot cache is fresh)")
    ap.add_argument("--check", action="store_true", help="only check that an export is allowed, then stop")
    a = ap.parse_args()

    try:
        busy = rldb_processes()
    except RuntimeError as e:
        sys.exit("REFUSED: cannot tell whether RLDB is running (%s). Not exporting." % e)
    if busy:
        sys.exit("REFUSED: %s is running. Close it first (overwriting the pck under a live game breaks its art). "
                 "Nothing was exported." % ", ".join(sorted(set(busy))))
    if not os.path.exists(a.godot):
        sys.exit("Godot not found at %s. Pass --godot or set GODOT." % a.godot)
    print("No RLDB process is running; export allowed.")
    if a.check:
        return
    build_dir = os.path.abspath(a.build_dir)
    print("Build folder: " + build_dir)

    if not a.skip_import:
        code, text = godot(a.godot, "--import")
        if code != 0:
            sys.exit("FAILED: godot --import exited %d:\n%s" % (code, tail(text)))
    steps = []
    if a.only in (None, "windows"):
        steps.append(("Windows playtest + dev", export_windows))
    if a.only in (None, "macos"):
        steps.append(("macOS", export_macos))
    failed = False
    for label, fn in steps:
        problems = fn(a.godot, build_dir)
        if problems:
            failed = True
            print("FAILED %s:\n  - %s" % (label, "\n  - ".join(problems)))
        else:
            print("OK     %s (checked)" % label)
    for label, ran in (("Windows playtest + dev", a.only in (None, "windows")), ("macOS", a.only in (None, "macos"))):
        if not ran:
            print("NOT RUN %s (--only %s)" % (label, a.only))
    if failed:
        sys.exit(1)
    print("All requested exports done. Next: python -I -X utf8 tools/publish_github.py release")


if __name__ == "__main__":
    main()
