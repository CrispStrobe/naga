"""Read-only snapshot of the app's TestFlight and App Store state."""
from urllib.parse import urlencode

from asc import APP_ID, get

app = get(f"/v1/apps/{APP_ID}")[1]["data"]["attributes"]
print(f"APP {app['name']} {app['bundleId']} primaryLocale={app['primaryLocale']}")

status, builds = get("/v1/builds?" + urlencode({
    "filter[app]": APP_ID, "sort": "-uploadedDate", "limit": 6,
    "include": "preReleaseVersion,buildBetaDetail"}))
included = {(i["type"], i["id"]): i["attributes"] for i in builds.get("included", [])}
for b in builds["data"]:
    rel = b["relationships"]
    pre = included.get(("preReleaseVersions", rel["preReleaseVersion"]["data"]["id"]), {})
    beta = included.get(("buildBetaDetails", rel["buildBetaDetail"]["data"]["id"]), {})
    a = b["attributes"]
    print(f"BUILD {b['id']} v{pre.get('version')}({a['version']}) {pre.get('platform')} "
          f"{a['processingState']} encryption={a.get('usesNonExemptEncryption')} "
          f"internal={beta.get('internalBuildState')} external={beta.get('externalBuildState')}")

for g in get(f"/v1/apps/{APP_ID}/betaGroups?limit=50")[1]["data"]:
    a = g["attributes"]
    testers = get(f"/v1/betaGroups/{g['id']}/betaTesters?limit=200")[1].get("data", [])
    print(f"GROUP {g['id']} '{a['name']}' {'internal' if a['isInternalGroup'] else 'external'} "
          f"testers={len(testers)} publicLink={a.get('publicLinkEnabled')} "
          f"autoDistribute={a.get('hasAccessToAllBuilds')}")

for loc in get(f"/v1/apps/{APP_ID}/betaAppLocalizations")[1]["data"]:
    a = loc["attributes"]
    print(f"BETA-LOCALE {a['locale']} description={bool(a.get('description'))} "
          f"feedbackEmail={bool(a.get('feedbackEmail'))}")

review = get(f"/v1/betaAppReviewDetails/{APP_ID}")[1]["data"]["attributes"]
print("BETA-REVIEW-CONTACT set=" + str({k: bool(v) for k, v in review.items() if k.startswith("contact")}))

for v in get(f"/v1/apps/{APP_ID}/appStoreVersions?limit=10")[1]["data"]:
    a = v["attributes"]
    print(f"VERSION {v['id']} {a['platform']} {a['versionString']} {a.get('appStoreState')}")

for info in get(f"/v1/apps/{APP_ID}/appInfos")[1]["data"]:
    print(f"APPINFO {info['id']} state={info['attributes'].get('appStoreState') or info['attributes'].get('state')}")

users = get("/v1/users?limit=20")[1].get("data", [])
print(f"TEAM-USERS {len(users)}")
