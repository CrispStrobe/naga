"""Submits the prepared App Store versions for review. Runs only with
ASC_APPLY=1 (the workflow's `apply` box); otherwise it only reports.

Per platform: the version must be PREPARE_FOR_SUBMISSION (or rejected /
developer-rejected) with a build attached. An open review submission for
the platform is reused (a rejected app keeps one in UNRESOLVED_ISSUES);
otherwise one is created. The version is added as an item and the
submission is marked submitted.
"""
import os
from urllib.parse import urlencode

from asc import APP_ID, check, errors, get, patch, post

APPLY = os.environ.get("ASC_APPLY") == "1"
READY = {"PREPARE_FOR_SUBMISSION", "REJECTED", "DEVELOPER_REJECTED", "METADATA_REJECTED"}
OPEN = {"READY_FOR_REVIEW", "UNRESOLVED_ISSUES"}

print(f"mode: {'SUBMIT' if APPLY else 'report only'}")
for v in get(f"/v1/apps/{APP_ID}/appStoreVersions?limit=10")[1]["data"]:
    a = v["attributes"]
    platform, state = a["platform"], a.get("appStoreState")
    build = get(f"/v1/appStoreVersions/{v['id']}/build")[1].get("data")
    print(f"\n== {platform} {a['versionString']} {state} build={build['attributes']['version'] if build else None}")
    if state not in READY:
        print("   not in a submittable state; skipped")
        continue
    if not build:
        raise SystemExit(f"FAILED {platform}: no build attached")

    subs = get(f"/v1/apps/{APP_ID}/reviewSubmissions?" + urlencode({
        "filter[platform]": platform, "limit": 20}))[1]["data"]
    open_subs = [s for s in subs if s["attributes"].get("state") in OPEN]
    for s in subs[:5]:
        print(f"   existing submission {s['id'][:8]} {s['attributes'].get('state')}")
    if not APPLY:
        print(f"   would {'reuse ' + open_subs[0]['id'][:8] if open_subs else 'create a submission'} and submit")
        continue

    if open_subs:
        sub_id = open_subs[0]["id"]
        print(f"ok  reusing submission {sub_id[:8]} ({open_subs[0]['attributes']['state']})")
    else:
        sub_id = check(*post("/v1/reviewSubmissions", {"data": {
            "type": "reviewSubmissions", "attributes": {"platform": platform},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}}),
            "created review submission")["data"]["id"]

    items = get(f"/v1/reviewSubmissions/{sub_id}/items?include=appStoreVersion")[1].get("data", [])
    has_version = any((i["relationships"].get("appStoreVersion", {}).get("data") or {}).get("id") == v["id"]
                      for i in items)
    if has_version:
        print("ok  version already an item of the submission")
    else:
        check(*post("/v1/reviewSubmissionItems", {"data": {
            "type": "reviewSubmissionItems", "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": v["id"]}}}}}),
            "added version to submission")

    status, resp = patch(f"/v1/reviewSubmissions/{sub_id}", {"data": {
        "type": "reviewSubmissions", "id": sub_id, "attributes": {"submitted": True}}})
    if status >= 400:
        raise SystemExit(f"FAILED submitting {platform}: {status} {errors(resp)}")
    print(f"ok  SUBMITTED {platform}: submission state {resp['data']['attributes'].get('state')}")
    after = get(f"/v1/appStoreVersions/{v['id']}")[1]["data"]["attributes"].get("appStoreState")
    print(f"    version state now {after}")
