"""Distributes the newest build number to internal and external TestFlight.

Safe to re-run: an existing tester, group membership, note or review
submission counts as success.

- Internal: every App Store Connect team member becomes an internal tester,
  and the builds join the internal group (no Apple review needed).
- "What to Test" notes per build and locale (tool/asc/whats_new/<locale>.txt).
- External: the builds join the external group and are submitted for Beta
  App Review, which is what unlocks external installs.
"""
import pathlib
from urllib.parse import urlencode

from asc import APP_ID, check, errors, get, patch, post

HERE = pathlib.Path(__file__).parent


def already(status, resp):
    """409 / 'already exists' style answers mean the work is done."""
    text = errors(resp).lower()
    return status == 409 or "already" in text or "same" in text


# Newest build number, all platforms.
_, builds = get("/v1/builds?" + urlencode({
    "filter[app]": APP_ID, "sort": "-uploadedDate", "limit": 10,
    "include": "preReleaseVersion"}))
newest = max(int(b["attributes"]["version"]) for b in builds["data"])
platform = {i["id"]: i["attributes"]["platform"]
            for i in builds.get("included", []) if i["type"] == "preReleaseVersions"}
targets = [b for b in builds["data"] if int(b["attributes"]["version"]) == newest]
for b in targets:
    b["platform"] = platform[b["relationships"]["preReleaseVersion"]["data"]["id"]]
    if b["attributes"]["processingState"] != "VALID":
        raise SystemExit(f"build {newest} {b['platform']} is {b['attributes']['processingState']}, not VALID")
print(f"build {newest}: " + ", ".join(b["platform"] for b in targets))

groups = {("internal" if g["attributes"]["isInternalGroup"] else "external"): g
          for g in get(f"/v1/apps/{APP_ID}/betaGroups?limit=50")[1]["data"]}
internal, external = groups["internal"], groups["external"]

# Internal testers: every team member (internal testers must be ASC users).
for user in get("/v1/users?limit=50")[1]["data"]:
    a = user["attributes"]
    status, resp = post("/v1/betaTesters", {"data": {
        "type": "betaTesters",
        "attributes": {"firstName": a.get("firstName"), "lastName": a.get("lastName"),
                       "email": a["username"]},
        "relationships": {"betaGroups": {"data": [{"type": "betaGroups", "id": internal["id"]}]}}}})
    if already(status, resp):
        print(f"ok  internal tester {a.get('firstName')} (already present)")
    else:
        check(status, resp, f"internal tester {a.get('firstName')}")

builds_ref = {"data": [{"type": "builds", "id": b["id"]} for b in targets]}
for name, group in (("internal", internal), ("external", external)):
    status, resp = post(f"/v1/betaGroups/{group['id']}/relationships/builds", builds_ref)
    if already(status, resp):
        print(f"ok  build {newest} in {name} group (already)")
    else:
        check(status, resp, f"build {newest} added to {name} group")

# "What to Test" notes.
for b in targets:
    existing = {l["attributes"]["locale"]: l for l in
                get(f"/v1/builds/{b['id']}/betaBuildLocalizations")[1]["data"]}
    for note in sorted((HERE / "whats_new").glob("*.txt")):
        locale, text = note.stem, note.read_text().strip()
        if locale in existing:
            loc = existing[locale]
            check(*patch(f"/v1/betaBuildLocalizations/{loc['id']}", {"data": {
                "type": "betaBuildLocalizations", "id": loc["id"],
                "attributes": {"whatsNew": text}}}), f"what-to-test {b['platform']} {locale} (updated)")
        else:
            check(*post("/v1/betaBuildLocalizations", {"data": {
                "type": "betaBuildLocalizations", "attributes": {"locale": locale, "whatsNew": text},
                "relationships": {"build": {"data": {"type": "builds", "id": b["id"]}}}}}),
                f"what-to-test {b['platform']} {locale}")

# External: Beta App Review.
for b in targets:
    status, resp = post("/v1/betaAppReviewSubmissions", {"data": {
        "type": "betaAppReviewSubmissions",
        "relationships": {"build": {"data": {"type": "builds", "id": b["id"]}}}}})
    if already(status, resp):
        print(f"ok  beta review {b['platform']} (already submitted)")
    else:
        resp = check(status, resp, f"beta review submitted {b['platform']}")
        print(f"    state: {resp['data']['attributes'].get('betaReviewState')}")

link = external["attributes"].get("publicLink")
print(f"external public link: {'enabled ' + link if external['attributes'].get('publicLinkEnabled') and link else 'disabled'}")
