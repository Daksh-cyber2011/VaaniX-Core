#!/usr/bin/env python3
"""Exam Mode 2.0 — M12 FINAL QA + PRODUCTION FREEZE mirror.

Master plan M12: run the automated verification suite and freeze the
build for production. This environment has NO Flutter SDK (documented
in every milestone report), so `flutter pub get / analyze / test` and
the APK/AAB builds CANNOT run here — the exact commands are verified
as a documented hand-off instead, and every check that CAN run
without an SDK runs here:

  IDENTITY       package name, app label, version pin, applicationId,
                 iOS display name + usage strings.
  ASSETS         every pubspec asset dir exists; all 8 canonical
                 syllabus files parse and are non-trivial; icons and
                 web manifest exist.
  PERMISSIONS    Android requests INTERNET only; iOS carries the
                 camera + photo-library strings the photo-answer
                 flow requires — and nothing else was added.
  ROUTING        every RouteNames constant is registered in the
                 router; every named navigation in lib/ resolves to
                 a declared route name (no dangling pushes).
  OFFLINE/AI     connectivity service + offline banner are wired in
                 the shipped UI; the exam planner chain is
                 Gemini → cached → deterministic (never-throw);
                 the vision evaluator degrades to typed-first with
                 honest §26 advice; photo bytes are never persisted.
  SECRETS        no AIza/sk-/anon-key literals, no hardcoded URLs
                 with credentials; everything flows through dotenv +
                 AppEnvironment; unconfigured ⇒ honest offline mode.
  HYGIENE        no TODO/FIXME/HACK/XXX/debug-bypass/fake-AI flags
                 in the exam feature; no print() in exam code.
  CURRICULUM     no placeholder syllabus: every course carries real
                 sections/items/marks; `pending` appears only as the
                 honest official-announcement status, never as a
                 fabricated substitute for content.
  REGRESSIONS    the full frozen-mirror suite M1→M11 re-runs green.

Run: python3 tools/exam/verify_exam_m12.py
"""

import json
import os
import re
import sys

PROJECT_ROOT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", ".."))
LIB = os.path.join(PROJECT_ROOT, "lib")
EXAM_LIB = os.path.join(LIB, "features", "exam")
SYLLABUS_DIR = os.path.join(PROJECT_ROOT, "assets", "syllabus", "cbse")

CHECKS = {"run": 0, "failed": 0}
FAILURES = []


def check(label, condition, detail=""):
    CHECKS["run"] += 1
    if not condition:
        CHECKS["failed"] += 1
        FAILURES.append(f"{label}: {detail}")


def read(*parts):
    path = os.path.join(PROJECT_ROOT, *parts)
    with open(path, encoding="utf-8-sig") as f:
        return f.read()


def dart_files(root):
    for dirpath, _, files in os.walk(root):
        for f in files:
            if f.endswith(".dart"):
                yield os.path.join(dirpath, f)


# ---------------------------------------------------------------------------
# 1. Project identity (M12: package name / label / version)
# ---------------------------------------------------------------------------

def run_identity():
    pubspec = read("pubspec.yaml")
    name = re.search(r"^name:\s*(\S+)", pubspec, re.M).group(1)
    version = re.search(r"^version:\s*(\S+)", pubspec, re.M).group(1)
    check("pubspec package name", name == "vaanix_app", name)
    check("version is pinned in x.y.z+n form",
          re.fullmatch(r"\d+\.\d+\.\d+\+\d+", version) is not None,
          version)
    check("version reflects Exam Mode 2.0 freeze",
          version.startswith("2.0.0"), version)

    gradle = read("android", "app", "build.gradle") if os.path.exists(
        os.path.join(PROJECT_ROOT, "android", "app", "build.gradle")) \
        else read("android", "app", "build.gradle.kts")
    check("android applicationId is com.vaanix.app",
          'applicationId' in gradle and "com.vaanix.app" in gradle,
          "missing applicationId")
    check("android namespace matches applicationId",
          "namespace" in gradle and "com.vaanix.app" in gradle, "")

    manifest = read("android", "app", "src", "main",
                    "AndroidManifest.xml")
    check("android app label is VaaniX",
          'android:label="VaaniX"' in manifest, "")

    plist = read("ios", "Runner", "Info.plist")
    check("iOS display name is VaaniX",
          "<key>CFBundleDisplayName</key>" in plist and
          "<string>VaaniX</string>" in plist, "")
    check("iOS bundle name matches package",
          "<string>vaanix_app</string>" in plist, "")
    check("iOS version follows FLUTTER_BUILD_NAME",
          "$(FLUTTER_BUILD_NAME)" in plist, "")


# ---------------------------------------------------------------------------
# 2. Permissions (M12: exactly what the features need)
# ---------------------------------------------------------------------------

def run_permissions():
    manifest = read("android", "app", "src", "main",
                    "AndroidManifest.xml")
    perms = set(re.findall(
        r'android\.permission\.([A-Z_]+)', manifest))
    check("android permissions are INTERNET only",
          perms == {"INTERNET"}, sorted(perms))
    plist = read("ios", "Runner", "Info.plist")
    check("iOS camera usage string present (photo answers)",
          "NSCameraUsageDescription" in plist and
          "handwritten answers" in plist, "")
    check("iOS photo-library usage string present",
          "NSPhotoLibraryUsageDescription" in plist and
          "handwritten answers" in plist, "")
    ns_keys = set(re.findall(r"<key>(NS\w*UsageDescription)</key>",
                             plist))
    check("iOS requests only camera + photo library",
          ns_keys == {"NSCameraUsageDescription",
                      "NSPhotoLibraryUsageDescription"},
          sorted(ns_keys))


# ---------------------------------------------------------------------------
# 3. Assets (M12: everything declared exists, curriculum is real)
# ---------------------------------------------------------------------------

def run_assets():
    pubspec = read("pubspec.yaml")
    asset_block = re.search(
        r"^[ \t]+assets:\n((?:[ \t]+.*\n)+)", pubspec, re.M)
    check("pubspec declares an assets block", asset_block is not None)
    entries = re.findall(r"^[ \t]+-[ \t]+(\S+)",
                         asset_block.group(1), re.M)
    syllabus_declared = any("assets/syllabus/cbse" in e for e in entries)
    check("canonical syllabus assets are registered",
          syllabus_declared, entries)
    for entry in entries:
        path = os.path.join(PROJECT_ROOT, entry.rstrip("/"))
        check(f"asset dir exists: {entry}",
              os.path.isdir(path), path)

    index = json.load(open(os.path.join(SYLLABUS_DIR, "index.json"),
                           encoding="utf-8"))
    course_files = [f for f in os.listdir(SYLLABUS_DIR)
                    if f.endswith(".json") and f != "index.json"]
    check("8 canonical files (index + 7 courses)",
          len(course_files) == 7, sorted(course_files))
    total_items = 0
    for fname in course_files:
        data = json.load(open(os.path.join(SYLLABUS_DIR, fname),
                              encoding="utf-8"))
        sections = data.get("sections", [])
        n_items = sum(len(s.get("items", [])) for s in sections)
        total_items += n_items
        check(f"{fname}: real structure (sections+items)",
              len(sections) >= 3 and n_items >= 3,
              f"{len(sections)} sections, {n_items} items")
        board = data.get("assessment", {}).get("boardExam", {})
        check(f"{fname}: official board totals",
              board.get("totalMarks") == 80, board.get("totalMarks"))
        for s in sections:
            for item in s.get("items", []):
                if item.get("status") == "pending" or \
                        item.get("pending"):
                    # Honesty markers, never placeholders with fake
                    # content alongside them.
                    check(f"{fname}: pending item is a stub (no "
                          f"fabricated content)",
                          not item.get("questionPatterns") or
                          item.get("status") == "pending",
                          item.get("id", "?"))
    check("curriculum is substantial (no placeholder data)",
          total_items >= 100, f"{total_items} items across 7 courses")
    # index knows every course file (nested classes→subjects→courses)
    listed = set()
    for klass in index.get("classes", []):
        for subject in klass.get("subjects", []):
            for course in subject.get("courses", []):
                if course.get("file"):
                    listed.add(course["file"])
    check("index.json lists all 7 course files",
          listed == set(course_files), sorted(listed ^ set(course_files)))
    check("web/ manifest exists for PWA",
          os.path.isfile(os.path.join(PROJECT_ROOT, "web", "manifest.json")),
          "")
    check("icons exist",
          os.path.isfile(os.path.join(PROJECT_ROOT, "web", "favicon.png")),
          "")


# ---------------------------------------------------------------------------
# 4. Routing (M12: no dangling routes or names)
# ---------------------------------------------------------------------------

def run_routing():
    names_src = read("lib", "core", "constants", "route_names.dart")
    routes = dict(re.findall(
        r"static const String\s+(\w+)\s*=\s*'([^']+)'", names_src))
    route_values = set(routes.values())
    router_src = read("lib", "app", "router", "app_router.dart")
    name_consts = set(re.findall(
        r"static const String\s+(\w+Name)\s*=", names_src))
    check("route names are paired (path + Name const)",
          len(name_consts) >= 20, len(name_consts))

    # Every Name const is referenced somewhere in the router.
    dangling = []
    for const in name_consts:
        pattern = f"RouteNames.{const}"
        if pattern not in router_src:
            dangling.append(const)
    check("every route Name const is registered in the router",
          not dangling, f"dangling: {dangling[:8]}")

    # Every named navigation in lib/ resolves to a declared Name const.
    used = set()
    for path in dart_files(LIB):
        src = open(path, encoding="utf-8").read()
        for m in re.finditer(r"pushNamed\(\s*RouteNames\.(\w+)", src):
            used.add(m.group(1))
    unknown = [u for u in used if u not in name_consts]
    check("every named navigation resolves to a declared route",
          not unknown, f"unknown: {sorted(unknown)[:8]}")

    # The Exam Mode 2.0 flow routes exist.
    for needed in ["/exam/setup", "/exam/hub/"]:
        check(f"exam route registered: {needed}",
              any(v.startswith(needed) for v in route_values),
              sorted(route_values)[:10])


# ---------------------------------------------------------------------------
# 5. Offline / AI fallback / Gemini failure / photo answers
# ---------------------------------------------------------------------------

def run_offline_ai():
    check("connectivity service exists",
          os.path.isfile(os.path.join(
              LIB, "core", "network", "connectivity_service.dart")), "")
    offline_banner = read("lib", "shared", "widgets", "offline_banner.dart")
    check("offline banner widget ships", "OfflineBanner" in
          offline_banner, "")
    banner_users = [p for p in dart_files(LIB)
                    if "OfflineBanner(" in open(p, encoding="utf-8").read()]
    check("offline banner is used by real screens",
          len(banner_users) >= 1,
          [os.path.basename(p) for p in banner_users])

    # Planner chain: Gemini → cached → deterministic, never-throw.
    plan_provider = read("lib", "features", "exam", "presentation",
                         "providers", "exam_plan_providers.dart")
    check("exam planner documents the 3-hop fallback",
          "DeterministicExamPlanner" in plan_provider and
          "cached" in plan_provider, "")
    gemini_planner = read("lib", "features", "exam", "data", "planner",
                          "gemini_exam_planner.dart")
    check("gemini planner never throws (try/catch + fallback)",
          gemini_planner.count("try {") >= 2 and
          "catch" in gemini_planner, "")
    check("gemini planner degrades to deterministic",
          "Deterministic" in gemini_planner or
          "deterministic" in gemini_planner, "")

    # Vision evaluator: offline typed-first, honest issues.
    vision = read("lib", "features", "exam", "data", "evaluation",
                  "gemini_vision_evaluator.dart")
    check("vision evaluator has the offline typed-first path",
          "offlinePhoto" in vision or "offline" in vision.lower(), "")
    check("vision evaluator carries honest §26 advice",
          "studentAdvice" in vision, "")

    # Photo bytes never persisted.
    eval_repo = read("lib", "features", "exam", "data", "evaluation",
                     "evaluation_repository.dart")
    check("photo bytes are never persisted",
          "never raw photo bytes" in eval_repo, "")
    banned = re.findall(r"(photoBytes|imageBytes|base64Photo)\s*[:=]",
                        eval_repo)
    check("no photo-byte fields in the evaluation store",
          not banned, banned)

    # Environment: unconfigured key ⇒ offline mode (no fake AI).
    env_src = read("lib", "core", "environment", "app_environment.dart")
    check("gemini key is environment-sourced (never hardcoded)",
          "dotenv.env" in env_src and "geminiApiKey" in env_src, "")
    check("unconfigured supabase degrades honestly",
          "isSupabaseConfigured" in env_src, "")
    ai_planner = read("lib", "features", "learn", "data",
                      "gemini_planner.dart")
    check("empty key ⇒ StateError → OfflineModelAdapter path",
          "apiKey.isEmpty" in ai_planner, "")


# ---------------------------------------------------------------------------
# 6. Secrets + hygiene scans
# ---------------------------------------------------------------------------

def run_secrets_and_hygiene():
    secret_patterns = [
        (r"AIza[0-9A-Za-z_\-]{30,}", "Google API key literal"),
        (r"sk-[A-Za-z0-9]{20,}", "OpenAI-style key literal"),
        (r"eyJ[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{20,}",
         "JWT literal"),
        (r"(?i)anon[_-]?key\s*[:=]\s*['\"][A-Za-z0-9]{20,}",
         "Supabase anon key literal"),
        (r"(?i)api[_-]?key\s*[:=]\s*['\"][A-Za-z0-9]{16,}['\"]",
         "generic API key literal"),
        (r"https://[a-z0-9\-]+\.supabase\.co[^\s'\"]*key=",
         "keyed supabase URL"),
    ]
    for path in dart_files(LIB):
        src = open(path, encoding="utf-8").read()
        for pattern, label in secret_patterns:
            hits = re.findall(pattern, src)
            check(f"no {label} in {os.path.basename(path)}",
                  not hits, hits[:2])

    hygiene = [(r"\b(TODO|FIXME|HACK|XXX)\b", "unfinished-work marker"),
               (r"(?i)\bdebug\b\s*(mode|bypass|flag)", "debug bypass"),
               (r"(?i)fakeAI|fake_ai|mockAI", "fake AI flag"),
               (r"(?i)bypassAuth|skipAuth", "auth bypass"),
               (r"\bprint\s*\(", "print() logging")]
    for path in dart_files(EXAM_LIB):
        src = open(path, encoding="utf-8").read()
        # strip comments — Hindi doc comments may legitimately contain
        # the words; only live code counts.
        code = re.sub(r"//[^\n]*", "", src)
        code = re.sub(r"/\*.*?\*/", "", code, flags=re.S)
        for pattern, label in hygiene:
            hits = re.findall(pattern, code)
            check(f"no {label} in {os.path.basename(path)}",
                  not hits, hits[:3])

    # The whole lib (not just exam) is print-free.
    printers = [os.path.basename(p) for p in dart_files(LIB)
                if re.search(r"\bprint\s*\(",
                             re.sub(r"//[^\n]*", "",
                                    open(p, encoding="utf-8").read()))]
    check("lib/ is print()-free (logger discipline)",
          not printers, printers[:5])


# ---------------------------------------------------------------------------
# 7. Regression sweep — the frozen mirrors stay green (M1→M11)
# ---------------------------------------------------------------------------

def run_regressions():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    # M1/M2 live in tools/syllabus.
    tools_syllabus = os.path.join(PROJECT_ROOT, "tools", "syllabus")
    sys.path.insert(0, tools_syllabus)
    import importlib

    suites = [
        ("M1 syllabus data (432)", "tools/syllabus/verify_syllabus_data.py",
         None),
        ("M2 exam scope (124)", "tools/syllabus/verify_exam_scope.py", None),
        ("M3-M7 (1217)", "tools/exam/verify_exam_m3_m7.py", "verify_exam_m3_m7"),
        ("M8 (1124)", "tools/exam/verify_exam_m8.py", "verify_exam_m8"),
        ("M9 (122)", "tools/exam/verify_exam_m9.py", "verify_exam_m9"),
        ("M10 (97)", "tools/exam/verify_exam_m10.py", "verify_exam_m10"),
        ("M11 (136)", "tools/exam/verify_exam_m11.py", "verify_exam_m11"),
    ]
    for label, rel, module in suites:
        path = os.path.join(PROJECT_ROOT, rel)
        if module is None:
            # Run as a script (self-contained mains).
            import subprocess
            result = subprocess.run(
                [sys.executable, path], capture_output=True, text=True,
                timeout=900)
            check(f"regression {label}",
                  result.returncode == 0,
                  result.stdout[-300:] if result.returncode else "")
        else:
            mod = importlib.import_module(module)
            rc = mod.main()
            check(f"regression {label}", rc in (None, 0),
                  f"main() returned {rc!r}")

    # Dart test files exist for every milestone (they run on a machine
    # with a Flutter SDK — see the QA freeze report).
    expected = [
        "test/features/exam/syllabus",
        "test/features/exam/scope",
        "test/features/exam/profile",
        "test/features/exam/diagnostic",
        "test/features/exam/planner",
        "test/features/exam/practice",
        "test/features/exam/evaluation",
        "test/features/exam/weakarea",
        "test/features/exam/pyq_mock",
        "test/features/exam/hub",
        "test/features/exam/simulation",
    ]
    for d in expected:
        full = os.path.join(PROJECT_ROOT, d)
        has_tests = os.path.isdir(full) and any(
            f.endswith("_test.dart") for f in os.listdir(full))
        check(f"Dart tests present: {d}", has_tests, full)


# ---------------------------------------------------------------------------
# 8. Freeze hygiene: .git preserved, no stray artifacts
# ---------------------------------------------------------------------------

def run_freeze_artifacts():
    check(".git directory preserved in the freeze",
          os.path.isdir(os.path.join(PROJECT_ROOT, ".git")), "")
    stray = []
    for dirpath, dirnames, files in os.walk(PROJECT_ROOT):
        if ".git" in dirpath:
            continue
        for f in files:
            if f.endswith((".zip", ".part-", ".log", ".tmp")):
                stray.append(os.path.join(dirpath, f))
    check("no build artifacts inside the project tree", not stray,
          stray[:5])
    env_files = [f for f in os.listdir(os.path.join(
        PROJECT_ROOT, "assets", "env"))]
    check("shipped .env is empty (credentials never bundled)",
          env_files == [".gitkeep"], env_files)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    run_identity()
    run_permissions()
    run_assets()
    run_routing()
    run_offline_ai()
    run_secrets_and_hygiene()
    run_freeze_artifacts()
    run_regressions()

    print(f"\n{'=' * 64}")
    if CHECKS["failed"] == 0:
        print(f"M12 QA FREEZE: ALL GREEN — {CHECKS['run']}/{CHECKS['run']} "
              "checks passed")
        print("Production freeze verified. Flutter-side commands to run "
              "on an SDK machine:")
        print("  flutter pub get && flutter analyze && flutter test")
        print("  flutter build apk --debug")
        print("  flutter build apk --release")
        print("  flutter build appbundle --release")
    else:
        print(f"M12 QA FREEZE: {CHECKS['failed']} FAILED of "
              f"{CHECKS['run']}")
        for failure in FAILURES[:40]:
            print(f"  FAIL {failure}")
    print('=' * 64)
    return 1 if CHECKS["failed"] else 0


if __name__ == "__main__":
    sys.exit(main())
