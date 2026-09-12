#!/usr/bin/env python3
"""Python mirror of the M1 Dart test suite (test/features/exam/syllabus/*).

The agent environment has no Flutter SDK, so this script verifies every
invariant the Dart tests will assert — against the same canonical files.
Run: python3 scripts/verify_syllabus_data.py
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "syllabus", "cbse")
TRACKS = [
    "cbse_9_hindi_r1", "cbse_9_hindi_r2", "cbse_9_sanskrit",
    "cbse_10_hindi_a", "cbse_10_hindi_b", "cbse_10_sanskrit",
    "cbse_10_sanskrit_communicative",
]
ALLOWED_TAGS = {
    "reading", "poetry", "grammar", "poetics", "writing", "vocabulary",
    "orthography", "literature", "prose", "drama", "translation",
}

passed, failed = 0, 0


def check(name, cond, reason=""):
    global passed, failed
    if cond:
        passed += 1
    else:
        failed += 1
        print(f"  FAIL: {name} {reason}")


def load(track):
    with open(os.path.join(ROOT, f"{track}.json"), encoding="utf-8") as f:
        return json.load(f)


def parse_track(track):
    parts = track.split("_")
    board, klass = parts[0], int(parts[1])
    subject = parts[2]
    course = "_".join(parts[3:]) if len(parts) > 3 else ""
    return board, klass, subject, course


print("== track id parsing ==")
for t in TRACKS:
    b, k, s, c = parse_track(t)
    check(f"parse {t}", b == "cbse" and k in (9, 10) and s and c is not None)
    check(f"asset path {t}",
          os.path.exists(os.path.join(ROOT, f"{t}.json")))

print("== load + validate all courses ==")
data = {t: load(t) for t in TRACKS}
for t, d in data.items():
    board_secs = [s for s in d["sections"] if s["assessmentType"] == "board"]
    total = sum(s["marks"] for s in board_secs)
    check(f"{t} board total", total == d["assessment"]["boardExam"]["totalMarks"] == 80)
    check(f"{t} internal", d["assessment"]["internalAssessment"]["totalMarks"] == 20)
    check(f"{t} duration", d["assessment"]["boardExam"]["durationHours"] == 3)
    check(f"{t} version", d["syllabusVersion"] == "2026-27")
    for s in d["sections"]:
        wm = [i for i in s["items"] if i.get("marks") is not None]
        if wm:
            check(f"{t}/{s['stableKey']} item marks sum",
                  sum(i["marks"] for i in wm) == s["marks"])
    ia = d["assessment"]["internalAssessment"].get("components")
    if ia:
        check(f"{t} internal components sum",
              sum(c["marks"] for c in ia) == 20)

print("== course isolation ==")
for t, d in data.items():
    ids = [s["id"] for s in d["sections"]]
    ids += [i["id"] for s in d["sections"] for i in s["items"]]
    ids += [b["id"] for b in d.get("prescribedBooks", [])]
    ids += [c["id"] for b in d.get("prescribedBooks", []) for c in b.get("chapters", [])]
    check(f"{t} ids exist", len(ids) > 0)
    check(f"{t} ids namespaced", all(i.startswith(t + "_") for i in ids))
    check(f"{t} ids unique", len(set(ids)) == len(ids))
    secids = {s["id"] for s in d["sections"]}
    check(f"{t} section linkage",
          all(i["sectionId"] in secids for s in d["sections"] for i in s["items"]))
a_ids = {i["id"] for s in data["cbse_10_hindi_a"]["sections"] for i in s["items"]}
b_ids = {i["id"] for s in data["cbse_10_hindi_b"]["sections"] for i in s["items"]}
check("hindi A/B no overlap", not (a_ids & b_ids))

print("== pending announcements (Class 9) ==")
for t in ["cbse_9_hindi_r1", "cbse_9_hindi_r2", "cbse_9_sanskrit"]:
    d = data[t]
    lit = next(s for s in d["sections"] if s["stableKey"] == "literature")
    selectable = [i for i in lit["items"] if i["status"] == "published"]
    check(f"{t} pending flag", d.get("pendingOfficialAnnouncement") is not None)
    check(f"{t} literature not selectable", len(selectable) == 0,
          f"found {len(selectable)} selectable items")
    check(f"{t} quote", len(d["pendingOfficialAnnouncement"]["sourceQuote"]) > 10)
for t in ["cbse_10_hindi_a", "cbse_10_hindi_b", "cbse_10_sanskrit",
          "cbse_10_sanskrit_communicative"]:
    d = data[t]
    pend = d.get("pendingOfficialAnnouncement")
    pend_items = [i for s in d["sections"] for i in s["items"]
                  if i["status"] == "pendingOfficialAnnouncement"]
    pend_books = [b for b in d.get("prescribedBooks", [])
                  if b.get("status") == "pendingOfficialAnnouncement"]
    check(f"{t} fully published", pend is None and not pend_items and not pend_books)
    check(f"{t} has books", len(d.get("prescribedBooks", [])) > 0)

print("== subject codes ==")
check("hindi_a code", data["cbse_10_hindi_a"]["course"]["subjectCode"] == "002")
check("hindi_b code", data["cbse_10_hindi_b"]["course"]["subjectCode"] == "085")
check("sanskrit code", data["cbse_10_sanskrit"]["course"]["subjectCode"] == "122")
check("communicative code",
      data["cbse_10_sanskrit_communicative"]["course"]["subjectCode"] == "119")
for t in TRACKS:
    check(f"{t} source pdf", data[t]["source"]["pdf"].endswith(".pdf"))

print("== Sanskrit 122 chapters ==")
d = data["cbse_10_sanskrit"]
shem = next(b for b in d["prescribedBooks"]
            if b["id"] == "cbse_10_sanskrit_book_shemushi")
nums = [c["number"] for c in shem["chapters"]]
check("shemushi numbers", nums == [1, 2, 3, 4, 5, 6, 7, 8, 10])
check("shemushi ch1", shem["chapters"][0]["title"] == "शुचिपर्यावरणम्")
check("shemushi ch10",
      next(c["title"] for c in shem["chapters"] if c["number"] == 10) == "अन्योक्तयः")
check("abhyasvan book", any("अभ्यासवान् भव" in b["title"] for b in d["prescribedBooks"]))
check("vyakaranavithi book", any("व्याकरणवीथि" in b["title"] for b in d["prescribedBooks"]))

print("== Communicative 119 chapters ==")
d = data["cbse_10_sanskrit_communicative"]
manika = next(b for b in d["prescribedBooks"]
              if b["id"] == "cbse_10_sanskrit_communicative_book_manika")
check("manika 11 chapters", len(manika["chapters"]) == 11)
check("manika ch1", manika["chapters"][0]["title"] == "वाङ्मयं तपः")
ch10 = next(c for c in manika["chapters"] if c["number"] == 10)
ch11 = next(c for c in manika["chapters"] if c["number"] == 11)
ch9 = next(c for c in manika["chapters"] if c["number"] == 9)
check("manika ch10 internal", ch10.get("examRelevance") == "internal-only")
check("manika ch11 internal", ch11.get("examRelevance") == "internal-only")
check("manika ch9 not internal", ch9.get("examRelevance") != "internal-only")

print("== Hindi A/B exclusion lists ==")
d = data["cbse_10_hindi_a"]
lit_items = next(s for s in d["sections"] if s["stableKey"] == "literature")["items"]
prose = next(i for i in lit_items if i["id"].endswith("kshitij_prose"))
poetry = next(i for i in lit_items if i["id"].endswith("kshitij_poetry"))
kritika = next(i for i in lit_items if i["id"].endswith("kritika"))
check("A prose exclusions", len(prose["details"]["excludedChapters"]) == 2)
check("A poetry exclusions", len(poetry["details"]["excludedChapters"]) == 3)
check("A kritika exclusions", len(kritika["details"]["excludedChapters"]) == 2)

d = data["cbse_10_hindi_b"]
lit_items = next(s for s in d["sections"] if s["stableKey"] == "literature")["items"]
poetry = next(i for i in lit_items if i["id"].endswith("sparsh_poetry"))
sanchayan = next(i for i in lit_items if i["id"].endswith("sanchayan"))
check("B poetry exclusions", len(poetry["details"]["excludedChapters"]) == 2)
check("B sanchayan note", "note" in sanchayan["details"])

print("== Hindi A/B supplied NCERT chapter packages ==")
d = data["cbse_10_hindi_a"]
kshitij = next(b for b in d["prescribedBooks"] if b["id"].endswith("book_kshitij"))
kritika = next(b for b in d["prescribedBooks"] if b["id"].endswith("book_kritika"))
check("A kshitij 12 in-scope chapters", len(kshitij["chapters"]) == 12)
check("A kritika 3 in-scope chapters", len(kritika["chapters"]) == 3)
check("A first chapter", kshitij["chapters"][0]["title"] == "सूरदास के पद")
check("A source package metadata", all("sourceFile" in c for c in kshitij["chapters"] + kritika["chapters"]))

d = data["cbse_10_hindi_b"]
sparsh = next(b for b in d["prescribedBooks"] if b["id"].endswith("book_sparsh"))
sanchayan_book = next(b for b in d["prescribedBooks"] if b["id"].endswith("book_sanchayan"))
check("B sparsh 14 in-scope chapters", len(sparsh["chapters"]) == 14)
check("B sanchayan 3 in-scope chapters", len(sanchayan_book["chapters"]) == 3)
check("B sanchayan first chapter", sanchayan_book["chapters"][0]["title"] == "हरिहर काका")
check("B source package metadata", all("sourceFile" in c for c in sparsh["chapters"] + sanchayan_book["chapters"]))

print("== grammar spot checks ==")
d = data["cbse_10_sanskrit"]
g = next(s for s in d["sections"] if s["stableKey"] == "grammar")
check("122 grammar 7 items", len(g["items"]) == 7)
check("122 grammar 25", g["marks"] == 25)
sandhi = next(i for i in g["items"] if i["id"].endswith("grammar_sandhi"))
check("122 sandhi details",
      set(sandhi["details"].keys()) == {"स्वरसन्धिः", "व्यञ्जनसन्धिः", "विसर्गसन्धिः"})

d = data["cbse_9_hindi_r1"]
g = next(s for s in d["sections"] if s["stableKey"] == "grammar")
check("r1 grammar 4 items", len(g["items"]) == 4)
check("r1 grammar 16", g["marks"] == 16)
check("r1 grammar ids", [i["id"] for i in g["items"]] == [
    "cbse_9_hindi_r1_grammar_word_formation",
    "cbse_9_hindi_r1_grammar_parts_of_speech",
    "cbse_9_hindi_r1_grammar_sentence_types_meaning",
    "cbse_9_hindi_r1_grammar_alankar",
])

d = data["cbse_9_hindi_r2"]
g = next(s for s in d["sections"] if s["stableKey"] == "grammar")
check("r2 grammar marks", [i["marks"] for i in g["items"]] == [4, 4, 2, 6])

print("== OCR flags ==")
total_flags = 0
for t, d in data.items():
    flagged = [i for s in d["sections"] for i in s["items"] if i.get("ocrUncertain")]
    for i in flagged:
        check(f"{t} ocr note", i.get("note") is not None)
    total_flags += len(flagged)
check("9_sanskrit has flags",
      len([i for s in data["cbse_9_sanskrit"]["sections"] for i in s["items"]
           if i.get("ocrUncertain")]) > 0)
check("10_sanskrit has flags",
      len([i for s in data["cbse_10_sanskrit"]["sections"] for i in s["items"]
           if i.get("ocrUncertain")]) > 0)
check("flags bounded", total_flags < 50)

print("== content tags ==")
for t, d in data.items():
    items = [i for s in d["sections"] for i in s["items"]]
    for i in items:
        check(f"{t} tags nonempty", len(i.get("contentTags", [])) > 0, i["id"])
        for tag in i.get("contentTags", []):
            check(f"{t} tag vocab", tag in ALLOWED_TAGS, f"{i['id']}: {tag}")

print("== index file ==")
with open(os.path.join(ROOT, "index.json"), encoding="utf-8") as f:
    idx = json.load(f)
all_courses = [c for cl in idx["classes"] for su in cl["subjects"] for c in su["courses"]]
check("index 7 courses", len(all_courses) == 7)
check("index 2 classes", len(idx["classes"]) == 2)
class9 = next(c for c in idx["classes"] if c["class"] == 9)
class10 = next(c for c in idx["classes"] if c["class"] == 10)
check("class9 2 subjects", len(class9["subjects"]) == 2)
check("class10 2 subjects", len(class10["subjects"]) == 2)
hindi9 = next(s for s in class9["subjects"] if s["id"] == "hindi")
check("hindi9 2 courses", {c["id"] for c in hindi9["courses"]} ==
      {"cbse_9_hindi_r1", "cbse_9_hindi_r2"})
sk10 = next(s for s in class10["subjects"] if s["id"] == "sanskrit")
check("sanskrit10 2 courses", len(sk10["courses"]) == 2)
for c in all_courses:
    check(f"index file exists {c['id']}",
          os.path.exists(os.path.join(ROOT, c["file"])))
    expected_pending = c["id"].startswith("cbse_9_")
    check(f"index lit status {c['id']}",
          (c["literatureStatus"] == "pendingOfficialAnnouncement") == expected_pending)

print()
print(f"RESULT: {passed} passed, {failed} failed")
raise SystemExit(1 if failed else 0)
