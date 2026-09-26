"""Prepares the App Store version for submission. It never submits.

Dry-run unless ASC_APPLY=1: prints every change it would make.

- Version string -> VERSION (the rejected 1.0 versions are reused).
- Localized copy from store/listing/<locale>/ (macOS adds a keyboard
  section), subtitle on the app info, Arcade + Puzzle subcategories.
- Screenshots from SHOTS_DIR (the store-screenshots artifact) replace
  each set: iPhone 6.9", iPad 13", Mac.
- App Review notes, then the newest VALID build per platform is attached.
"""
import hashlib
import os
import pathlib
import time
import urllib.request
from urllib.parse import urlencode

from asc import APP_ID, check, delete, errors, get, patch, post

APPLY = os.environ.get("ASC_APPLY") == "1"
VERSION = os.environ.get("VERSION", "1.1.0")
ROOT = pathlib.Path(__file__).resolve().parents[2]
LISTING = ROOT / "store" / "listing"
SHOTS = pathlib.Path(os.environ.get("SHOTS_DIR", ROOT / "store-screenshots"))
LANG = {"en-US": "en", "de-DE": "de"}
SETS = {"IOS": {"APP_IPHONE_67": "iphone_69", "APP_IPAD_PRO_3GEN_129": "ipad_13"},
        "MAC_OS": {"APP_DESKTOP": "mac"}}
REVIEW_NOTES = (ROOT / "store" / "review_notes.txt").read_text().strip()


def write(method, path, body, what):
    if not APPLY:
        print(f"DRY {what}")
        return {}
    return check(*method(path, body), what)


def text(locale, name):
    return (LISTING / locale / f"{name}.txt").read_text().strip()


print(f"mode: {'APPLY' if APPLY else 'dry run'}; version {VERSION}; screenshots {SHOTS}")

# App info: subtitle and subcategories.
info = get(f"/v1/apps/{APP_ID}/appInfos")[1]["data"][0]
write(patch, f"/v1/appInfos/{info['id']}", {"data": {
    "type": "appInfos", "id": info["id"], "relationships": {
        "primarySubcategoryOne": {"data": {"type": "appCategories", "id": "GAMES_ARCADE"}},
        "primarySubcategoryTwo": {"data": {"type": "appCategories", "id": "GAMES_PUZZLE"}}}}},
    "categories: Games > Arcade, Puzzle")
for loc in get(f"/v1/appInfos/{info['id']}/appInfoLocalizations")[1]["data"]:
    locale = loc["attributes"]["locale"]
    if locale in LANG:
        write(patch, f"/v1/appInfoLocalizations/{loc['id']}", {"data": {
            "type": "appInfoLocalizations", "id": loc["id"],
            "attributes": {"subtitle": text(locale, "subtitle")}}}, f"subtitle [{locale}]")

# Newest VALID build per platform.
_, builds = get("/v1/builds?" + urlencode({
    "filter[app]": APP_ID, "sort": "-uploadedDate", "limit": 20,
    "filter[processingState]": "VALID", "include": "preReleaseVersion"}))
pre = {i["id"]: i["attributes"] for i in builds.get("included", []) if i["type"] == "preReleaseVersions"}
newest = {}
for b in builds["data"]:
    p = pre[b["relationships"]["preReleaseVersion"]["data"]["id"]]
    if p["version"] == VERSION and p["platform"] not in newest:
        newest[p["platform"]] = b


def upload_screenshot(set_id, path):
    data = path.read_bytes()
    resp = check(*post("/v1/appScreenshots", {"data": {
        "type": "appScreenshots", "attributes": {"fileName": path.name, "fileSize": len(data)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}}),
        f"    reserve {path.name}")
    shot = resp["data"]
    for op in shot["attributes"]["uploadOperations"]:
        part = data[op["offset"]:op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=part, method=op["method"],
                                     headers={h["name"]: h["value"] for h in op["requestHeaders"]})
        with urllib.request.urlopen(req) as r:
            assert r.status < 300, r.status
    check(*patch(f"/v1/appScreenshots/{shot['id']}", {"data": {
        "type": "appScreenshots", "id": shot["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}}),
        f"    commit {path.name}")
    for _ in range(60):
        state = get(f"/v1/appScreenshots/{shot['id']}")[1]["data"]["attributes"]["assetDeliveryState"]["state"]
        if state in ("UPLOAD_COMPLETE", "COMPLETE"):
            return
        if state == "FAILED":
            raise SystemExit(f"FAILED processing {path}")
        time.sleep(2)
    raise SystemExit(f"FAILED timeout processing {path}")


for v in get(f"/v1/apps/{APP_ID}/appStoreVersions?limit=10")[1]["data"]:
    platform, attrs = v["attributes"]["platform"], v["attributes"]
    print(f"\n== {platform} {attrs['versionString']} ({attrs.get('appStoreState')})")
    if attrs["versionString"] != VERSION:
        write(patch, f"/v1/appStoreVersions/{v['id']}", {"data": {
            "type": "appStoreVersions", "id": v["id"], "attributes": {"versionString": VERSION}}},
            f"version string {attrs['versionString']} -> {VERSION}")

    for loc in get(f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations")[1]["data"]:
        locale = loc["attributes"]["locale"]
        if locale not in LANG:
            continue
        description = text(locale, "description")
        if platform == "MAC_OS":
            description += "\n\n" + text(locale, "description_macos_extra")
        write(patch, f"/v1/appStoreVersionLocalizations/{loc['id']}", {"data": {
            "type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": {
                "description": description, "keywords": text(locale, "keywords"),
                "promotionalText": text(locale, "promotional_text")}}},
            f"copy [{locale}] ({len(description)} chars)")

        sets = {s["attributes"]["screenshotDisplayType"]: s for s in
                get(f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")[1]["data"]}
        for display, device in SETS[platform].items():
            files = sorted((SHOTS / device / LANG[locale]).glob("*.png"))
            if not files:
                print(f"skip screenshots [{locale}] {display}: none in {SHOTS / device / LANG[locale]}")
                continue
            print(f"screenshots [{locale}] {display}: {len(files)} new "
                  f"({', '.join(f.stem for f in files)})")
            if not APPLY:
                continue
            if display in sets:
                set_id = sets[display]["id"]
                for old in get(f"/v1/appScreenshotSets/{set_id}/appScreenshots")[1]["data"]:
                    check(*delete(f"/v1/appScreenshots/{old['id']}"), f"    remove old {old['id'][:8]}")
            else:
                set_id = check(*post("/v1/appScreenshotSets", {"data": {
                    "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": display},
                    "relationships": {"appStoreVersionLocalization": {"data": {
                        "type": "appStoreVersionLocalizations", "id": loc["id"]}}}}}),
                    f"    create set {display}")["data"]["id"]
            for f in files:
                upload_screenshot(set_id, f)

    review = get(f"/v1/appStoreVersions/{v['id']}/appStoreReviewDetail")[1].get("data")
    if review:
        write(patch, f"/v1/appStoreReviewDetails/{review['id']}", {"data": {
            "type": "appStoreReviewDetails", "id": review["id"],
            "attributes": {"notes": REVIEW_NOTES}}}, f"review notes ({len(REVIEW_NOTES)} chars)")

    build = newest.get(platform)
    if build:
        write(patch, f"/v1/appStoreVersions/{v['id']}/relationships/build",
              {"data": {"type": "builds", "id": build["id"]}},
              f"attach build {build['attributes']['version']}")
    else:
        print(f"no VALID {VERSION} build for {platform} yet")

print("\nNot submitted. Submitting for review is a deliberate step in App Store Connect.")
