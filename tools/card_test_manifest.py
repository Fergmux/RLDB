#!/usr/bin/env python3
"""Generate rldb/tests/cards/manifest.json -- the F26 per-card test coverage manifest.

A card's tests are found by scanning every *.gd under rldb/tests for:
  * functions named  test_cNNN_...            (NNN = zero-padded card id), and
  * functions preceded by a comment line  # @cards 1,2,3  (shared/parameterised tests).

Status per card:
  * pending(<reason>) when the id is listed in rldb/tests/cards/pending.json
    (an exact unresolved or suspected-wrong behaviour), whatever tests exist;
  * covered            when at least one test exists;
  * pending(no behaviour test yet) otherwise.

Deterministic: ids sorted, files and tests sorted, LF line endings.
Usage: python tools/card_test_manifest.py [--check]   (--check: exit 1 if the file is stale)
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.join(ROOT, "rldb")
TESTS = os.path.join(GODOT, "tests")
CARDS_JSON = os.path.join(GODOT, "data", "cards.json")
PENDING = os.path.join(TESTS, "cards", "pending.json")
OUT = os.path.join(TESTS, "cards", "manifest.json")
DIFF = os.path.join(ROOT, "design", "card-database-diff-2026-10-17.md")
CHANGED_REASON = ("changed in the 2026-10-17 CSV; existing tests target pre-migration behaviour "
	"-- revalidate after the A1 migration and add the id to pending.json _revalidated")
# 2026-10-18 update: the changed/new ids come from comparing the two dated exports directly.
SOURCES = os.path.join(ROOT, "rules", "sources")
CSV_17 = os.path.join(SOURCES, "RLDB Master - Card Database (2026-10-17).csv")
CSV_18 = os.path.join(SOURCES, "RLDB Master - Card Database (2026-10-18).csv")
# Position and art-reference columns move with every inserted row; they carry no behaviour.
REFERENCE_COLS = {"index", "image", "card_img"}
CHANGED_REASON_18 = ("changed or added in the 2026-10-18 CSV -- revalidate against the migrated behaviour "
	"and add the id to pending.json _revalidated_2026_10_18")
# 2026-11-03 update (design/card-database-update-2026-11-03.md): the 3 Nov export has no art,
# keywords or description columns, so it is compared with the 20 Oct export on the card-data
# columns only (whitespace-trimmed).
CSV_20 = os.path.join(SOURCES, "RLDB Master - Card Database (2026-10-20).csv")
CSV_1103 = os.path.join(SOURCES, "RLDB Master - Card Database (2026-11-03).csv")
DATA_COLS_1103 = ("name", "category", "race", "type", "cost", "atk", "def", "condition",
	"On Summon/Play", "On Field", "On Destruction")
CHANGED_REASON_1103 = ("changed or added in the 2026-11-03 CSV -- revalidate against the migrated behaviour "
	"and add the id to pending.json _revalidated_2026_11_03")

FUNC_RE = re.compile(r"^func (test_\w+)\s*\(")
NAME_ID_RE = re.compile(r"^test_c(\d{3})_")
CARDS_RE = re.compile(r"^\s*#\s*@cards\s+([\d,\s]+)$")


def scan():
	found = {}
	for dirpath, _dirs, files in os.walk(TESTS):
		for fn in sorted(files):
			if not fn.endswith(".gd"):
				continue
			path = os.path.join(dirpath, fn)
			res = "res://" + os.path.relpath(path, GODOT).replace(os.sep, "/")
			prev = ""
			with open(path, encoding="utf-8", newline="") as fh:
				for line in fh.read().splitlines():
					m = FUNC_RE.match(line)
					if m:
						name = m.group(1)
						ids = set()
						n = NAME_ID_RE.match(name)
						if n:
							ids.add(int(n.group(1)))
						c = CARDS_RE.match(prev)
						if c:
							ids.update(int(x) for x in re.findall(r"\d+", c.group(1)))
						for i in ids:
							found.setdefault(i, {}).setdefault(res, set()).add(name)
					if line.strip() != "":
						prev = line
	return found


def unchanged_ids():
	"""Ids the 2026-10-17 diff lists as having no parsed field changes."""
	text = open(DIFF, encoding="utf-8").read()
	sec = text.split("## Unchanged card IDs", 1)[1].split("\n- Matched", 1)[0]
	nums = re.findall(r"\d+", sec)
	return set(int(x) for x in nums[1:])   # the first number is the count ("82 identified cards")


def changes_2026_10_18():
	"""{id: "new" | "changed" | "unchanged"} between the 2026-10-17 and 2026-10-18 exports."""
	import csv

	def rows(path):
		with open(path, encoding="utf-8-sig", newline="") as fh:
			return {int(r["id"]): r for r in csv.DictReader(fh) if r["name"].strip()}
	old, new = rows(CSV_17), rows(CSV_18)
	out = {}
	for i, r in new.items():
		if i not in old:
			out[i] = "new"
		elif any(r[k] != old[i].get(k) for k in r if k not in REFERENCE_COLS):
			out[i] = "changed"
		else:
			out[i] = "unchanged"
	return out


def changes_2026_11_03():
	"""{id: "new" | "changed" | "unchanged"} between the 2026-10-20 and 2026-11-03 exports."""
	import csv

	def rows(path):
		with open(path, encoding="utf-8-sig", newline="") as fh:
			return {int(r["id"]): r for r in csv.DictReader(fh) if (r.get("name") or "").strip()}
	old, new = rows(CSV_20), rows(CSV_1103)
	out = {}
	for i, r in new.items():
		if i not in old:
			out[i] = "new"
		elif any((r.get(k) or "").strip() != (old[i].get(k) or "").strip() for k in DATA_COLS_1103):
			out[i] = "changed"
		else:
			out[i] = "unchanged"
	return out


def build():
	with open(CARDS_JSON, encoding="utf-8") as fh:
		cards = json.load(fh)["cards"]
	pending = {}
	if os.path.exists(PENDING):
		with open(PENDING, encoding="utf-8") as fh:
			raw = json.load(fh)
			pending = {int(k): v for k, v in raw.items() if not k.startswith("_")}
			revalidated = set(int(x) for x in raw.get("_revalidated", []))
			revalidated_18 = set(int(x) for x in raw.get("_revalidated_2026_10_18", []))
			revalidated_1103 = set(int(x) for x in raw.get("_revalidated_2026_11_03", []))
	else:
		revalidated = set()
		revalidated_18 = set()
		revalidated_1103 = set()
	csv18 = changes_2026_10_18()
	csv1103 = changes_2026_11_03()
	unchanged = unchanged_ids()
	found = scan()
	out = {}
	for c in sorted(cards, key=lambda c: int(c["id"])):
		i = int(c["id"])
		files = found.get(i, {})
		tests = [{"file": f, "tests": sorted(files[f])} for f in sorted(files)]
		if i in pending:
			status = "pending(%s)" % pending[i]
		elif csv1103.get(i, "new") != "unchanged" and i not in revalidated_1103:
			status = "pending(%s)" % CHANGED_REASON_1103
		elif csv18.get(i, "new") != "unchanged" and i not in revalidated_18 and csv1103.get(i) != "new":
			status = "pending(%s)" % CHANGED_REASON_18
		elif csv18.get(i) != "new" and csv1103.get(i) != "new" and i not in unchanged and i not in revalidated:
			status = "pending(%s)" % CHANGED_REASON
		elif tests:
			status = "covered"
		else:
			status = "pending(no behaviour test yet)"
		out[str(i)] = {"name": c["name"].strip(), "category": c["category"],
			"csv_2026_10_17": "new" if "new" in (csv18.get(i), csv1103.get(i)) else ("unchanged" if i in unchanged else "changed"),
			"csv_2026_10_18": csv18.get(i, "new"), "csv_2026_11_03": csv1103.get(i, "new"),
			"status": status, "tests": tests}
	return {"_about": "Generated by tools/card_test_manifest.py -- do not edit; edit rldb/tests/cards/pending.json or the tests.",
		"card_count": len(out), "cards": out}


def main():
	text = json.dumps(build(), indent="\t", ensure_ascii=False) + "\n"
	if "--check" in sys.argv:
		old = open(OUT, encoding="utf-8", newline="").read() if os.path.exists(OUT) else ""
		if old != text:
			print("manifest.json is stale; run python tools/card_test_manifest.py")
			sys.exit(1)
		print("manifest.json is up to date")
		return
	with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
		fh.write(text)
	data = json.loads(text)["cards"]
	cov = sum(1 for v in data.values() if v["status"] == "covered")
	print("cards=%d covered=%d pending=%d" % (len(data), cov, len(data) - cov))


if __name__ == "__main__":
	main()
