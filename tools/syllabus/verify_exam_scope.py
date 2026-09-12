#!/usr/bin/env python3
"""Python mirror of the M2 Dart scope-domain suite against the REAL
canonical JSON. Mirrors ExamScopeView building + ExamScopeSelection
semantics so every Dart-test expectation is pre-verified (no Flutter SDK
in the authoring environment).
Run: python3 scripts/verify_exam_scope.py
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "syllabus", "cbse")
TRACKS = [
    "cbse_9_hindi_r1", "cbse_9_hindi_r2", "cbse_9_sanskrit",
    "cbse_10_hindi_a", "cbse_10_hindi_b", "cbse_10_sanskrit",
    "cbse_10_sanskrit_communicative",
]

passed, failed = 0, 0


def check(name, cond, reason=""):
    global passed, failed
    if cond:
        passed += 1
    else:
        failed += 1
        print(f"  FAIL: {name} {reason}")


class Unit:
    def __init__(self, id, title, title_en, selectable, marks=None,
                 subtitle=None, is_chapter=False, info=None):
        self.id, self.title, self.title_en = id, title, title_en
        self.selectable, self.marks = selectable, marks
        self.subtitle, self.is_chapter, self.info = subtitle, is_chapter, info


class Section:
    def __init__(self, id, stable_key, marks, units, pending_note=None):
        self.id, self.stable_key, self.marks = id, stable_key, marks
        self.units, self.pending_note = units, pending_note

    @property
    def selectable_units(self):
        return [u for u in self.units if u.selectable]

    @property
    def is_pending(self):
        return not self.selectable_units and self.pending_note is not None


class View:
    def __init__(self, track_id, sections, board_marks):
        self.track_id, self.sections, self.board_marks = track_id, sections, board_marks

    @property
    def selectable_unit_ids(self):
        return {u.id for s in self.sections for u in s.selectable_units}

    @property
    def has_pending_sections(self):
        return any(s.is_pending for s in self.sections)

    @property
    def marks_coverage_exact(self):
        if self.has_pending_sections:
            return False
        return all(
            not s.selectable_units or all(u.marks is not None for u in s.selectable_units)
            for s in self.sections)


def build_view(track):
    d = json.load(open(os.path.join(ROOT, f"{track}.json"), encoding="utf-8"))
    board_secs = [s for s in d["sections"] if s["assessmentType"] == "board"]
    chapters = [c for b in d.get("prescribedBooks", []) for c in b.get("chapters", [])]
    sections = []
    for s in board_secs:
        units, pending_note = [], None
        chapters_added = False
        if s["stableKey"] == "literature" and chapters:
            chapters_added = True
            for ch in chapters:
                internal = ch.get("examRelevance") == "internal-only"
                units.append(Unit(
                    ch["id"], ch["title"], f"Chapter {ch['number']}",
                    not internal, None,
                    ("आंतरिक मूल्यांकन हेतु (बोर्ड परीक्षा दायरे से बाहर)" if internal
                     else ("काव्य खंड" if ch.get("type") == "poetry" else "गद्य खंड")),
                    True))
        if s["stableKey"] == "literature" and not chapters_added and d.get("pendingOfficialAnnouncement"):
            pending_note = "आधिकारिक अध्याय सूची जारी होने बाकी है — " + d["pendingOfficialAnnouncement"]["reason"]
        for item in s["items"]:
            if s["stableKey"] == "literature" and chapters_added:
                continue
            selectable = item.get("status", "published") == "published"
            excluded = (item.get("details") or {}).get("excludedChapters")
            info = None
            if excluded:
                names = "; ".join(
                    (f"{e.get('author') or ''} — {e.get('chapter') or ''}").strip(" —")
                    for e in excluded)
                info = f"छोड़े गए पाठ (इनसे प्रश्न नहीं): {names}"
            units.append(Unit(
                item["id"], item["title"], item.get("titleEn", ""),
                selectable, item.get("marks"),
                item.get("questionPatterns", [{}])[0].get("pattern") if item.get("questionPatterns") else None,
                False, info))
        sections.append(Section(s["id"], s["stableKey"], s["marks"], units, pending_note))
    return View(track, sections, d["assessment"]["boardExam"]["totalMarks"])


VIEWS = {t: build_view(t) for t in TRACKS}

print("== ExamScopeView building ==")
v = VIEWS["cbse_10_sanskrit"]
lit = next(s for s in v.sections if s.stable_key == "literature")
chapters = [u for u in lit.units if u.is_chapter]
check("122 chapters 9", len(chapters) == 9)
check("122 all selectable", all(u.selectable for u in chapters))
check("122 ch1 title", chapters[0].title == "शुचिपर्यावरणम्")
check("122 no item units", all(u.is_chapter for u in lit.units))

v = VIEWS["cbse_10_sanskrit_communicative"]
lit = next(s for s in v.sections if s.stable_key == "literature")
ch10 = next(u for u in lit.units if u.is_chapter and u.title_en == "Chapter 10")
ch11 = next(u for u in lit.units if u.is_chapter and u.title_en == "Chapter 11")
ch9 = next(u for u in lit.units if u.is_chapter and u.title_en == "Chapter 9")
check("119 ch10 not selectable", not ch10.selectable)
check("119 ch11 not selectable", not ch11.selectable)
check("119 ch9 selectable", ch9.selectable)
check("119 ch10 subtitle", "आंतरिक मूल्यांकन" in ch10.subtitle)

v = VIEWS["cbse_9_sanskrit"]
lit = next(s for s in v.sections if s.stable_key == "literature")
check("9s lit pending", lit.is_pending)
check("9s pending note", lit.pending_note and "आधिकारिक" in lit.pending_note)
check("9s no selectable lit", not lit.selectable_units)
check("9s has pending", v.has_pending_sections)
gram = next(s for s in v.sections if s.stable_key == "grammar")
check("9s grammar selectable", len(gram.selectable_units) > 0)
check("9s selectable total 13", len(v.selectable_unit_ids) == 13)

v = VIEWS["cbse_9_hindi_r1"]
lit = next(s for s in v.sections if s.stable_key == "literature")
check("9h1 lit pending", lit.is_pending)
check("9h1 selectable nonempty", len(v.selectable_unit_ids) > 0)

v = VIEWS["cbse_10_hindi_a"]
lit = next(s for s in v.sections if s.stable_key == "literature")
check("A lit 3 book-section units", len(lit.units) == 3)
check("A lit no chapters", all(not u.is_chapter for u in lit.units))
check("A lit all selectable", all(u.selectable for u in lit.units))
check("A excluded info on units", all(u.info and "छोड़े गए" in u.info for u in lit.units))
check("A selectable total 13", len(v.selectable_unit_ids) == 13)

for t in TRACKS:
    v = VIEWS[t]
    for s in v.sections:
        check(f"{t}/{s.stable_key} renders", bool(s.units) or s.is_pending)
    check(f"{t} board 80", v.board_marks == 80)

for t in ["cbse_9_sanskrit", "cbse_10_hindi_b", "cbse_10_sanskrit_communicative"]:
    for uid in VIEWS[t].selectable_unit_ids:
        check(f"{t} namespace", uid.startswith(t + "_"), uid)

v = VIEWS["cbse_10_sanskrit"]
check("unitById known", v.selectable_unit_ids.__contains__("cbse_10_sanskrit_grammar_sandhi"))

print("== selection semantics (mirrored) ==")
track = "cbse_10_sanskrit"
view = VIEWS[track]


class Sel:
    def __init__(self, track, ids, rev=0):
        self.track, self.ids, self.rev = track, set(ids), rev

    SECTION_KEYS = {"unread", "grammar", "literature", "writing", "ch"}

    def _belongs(self, uid):
        if not uid.startswith(self.track + "_"):
            return False
        remainder = uid[len(self.track) + 1:]
        return remainder.split("_")[0] in self.SECTION_KEYS

    def toggle(self, uid):
        if not self._belongs(uid):
            return None
        nxt = set(self.ids)
        if uid in nxt:
            nxt.discard(uid)
        else:
            nxt.add(uid)
        return Sel(self.track, nxt, self.rev + 1)

    def select_all(self, eligible):
        nxt = set(self.ids)
        for i in eligible:
            if self._belongs(i):
                nxt.add(i)
        return Sel(self.track, nxt, self.rev + 1)

    def toggle_section(self, unit_ids):
        elig = {i for i in unit_ids if self._belongs(i)}
        if not elig:
            return self
        nxt = set(self.ids)
        if elig <= self.ids:
            nxt -= elig
        else:
            nxt |= elig
        return Sel(self.track, nxt, self.rev + 1)

    def covered(self, view):
        m = {u.id: (u.marks or 0) for s in view.sections for u in s.units}
        return sum(m[i] for i in self.ids if i in view.selectable_unit_ids)


s = Sel(track, [])
s1 = s.toggle(f"{track}_grammar_sandhi")
check("toggle selects", f"{track}_grammar_sandhi" in s1.ids and s1.rev == 1)
s2 = s1.toggle(f"{track}_grammar_sandhi")
check("toggle deselects", not s2.ids and s2.rev == 2)

check("isolation toggle", s.toggle("cbse_10_hindi_a_grammar_vachya") is None)
check("isolation foreign sanskrit", s.toggle("cbse_10_sanskrit_communicative_grammar_sandhi") is None)

sa = s.select_all(view.selectable_unit_ids)
check("selectAll count", len(sa.ids) == len(view.selectable_unit_ids))
check("selectAll covered 50", sa.covered(view) == 50)

sa_hb = Sel("cbse_10_hindi_b", []).select_all(VIEWS["cbse_10_hindi_b"].selectable_unit_ids)
check("hindiB selectAll covered 80", sa_hb.covered(VIEWS["cbse_10_hindi_b"]) == 80)

saf = s.select_all(list(view.selectable_unit_ids) + ["cbse_10_hindi_a_grammar_vachya"])
check("selectAll ignores foreign", len(saf.ids) == len(view.selectable_unit_ids))

gram_ids = [u.id for u in next(s for s in view.sections if s.stable_key == "grammar").selectable_units]
ss = Sel(track, []).toggle_section(gram_ids)
check("toggleSection selects", set(gram_ids) <= ss.ids)
ss2 = ss.toggle_section(gram_ids)
check("toggleSection deselects", not (set(gram_ids) & ss2.ids))
check("toggleSection foreign noop", Sel(track, []).toggle_section(["cbse_10_hindi_a_grammar_vachya"]).rev == 0)

print("== marksCoverageExact / engaged ==")
check("hindi_b exact", VIEWS["cbse_10_hindi_b"].marks_coverage_exact)
check("hindi_a exact", VIEWS["cbse_10_hindi_a"].marks_coverage_exact)
check("122 not exact", not VIEWS["cbse_10_sanskrit"].marks_coverage_exact)
check("119 not exact", not VIEWS["cbse_10_sanskrit_communicative"].marks_coverage_exact)
check("9s not exact (pending)", not VIEWS["cbse_9_sanskrit"].marks_coverage_exact)
check("9h1 not exact (pending)", not VIEWS["cbse_9_hindi_r1"].marks_coverage_exact)

# 20-units for 122 & 119 (widget expectations)
check("122 selectable 20", len(VIEWS["cbse_10_sanskrit"].selectable_unit_ids) == 20)
check("119 selectable 20", len(VIEWS["cbse_10_sanskrit_communicative"].selectable_unit_ids) == 20)
check("122 grammar 7", len(next(s for s in VIEWS["cbse_10_sanskrit"].sections if s.stable_key == "grammar").selectable_units) == 7)

print()
print(f"RESULT: {passed} passed, {failed} failed")
raise SystemExit(1 if failed else 0)
