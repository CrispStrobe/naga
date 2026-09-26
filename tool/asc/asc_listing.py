"""Read-only dump of the App Store listing: versions, localizations,
app info, categories and screenshot sets."""
from urllib.parse import urlencode

from asc import APP_ID, get


def short(text, n=90):
    text = (text or "").replace("\n", " / ")
    return text if len(text) <= n else text[:n] + f"... ({len(text)} chars)"


for v in get(f"/v1/apps/{APP_ID}/appStoreVersions?limit=10")[1]["data"]:
    a = v["attributes"]
    print(f"\nVERSION {a['platform']} {a['versionString']} {a.get('appStoreState')} "
          f"copyright={a.get('copyright')!r} releaseType={a.get('releaseType')}")
    build = get(f"/v1/appStoreVersions/{v['id']}/build")[1].get("data")
    print(f"  build attached: {build['attributes']['version'] if build else None}")
    review = get(f"/v1/appStoreVersions/{v['id']}/appStoreReviewDetail")[1].get("data")
    if review:
        r = review["attributes"]
        print(f"  review contact set: {bool(r.get('contactEmail'))} notes: {short(r.get('notes'), 160)}")
    for loc in get(f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations")[1]["data"]:
        l = loc["attributes"]
        print(f"  [{l['locale']}] desc: {short(l.get('description'))}")
        print(f"     keywords: {l.get('keywords')!r}")
        print(f"     promo: {short(l.get('promotionalText'))} whatsNew: {short(l.get('whatsNew'))}")
        print(f"     support={l.get('supportUrl')} marketing={l.get('marketingUrl')}")
        for s in get(f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")[1]["data"]:
            shots = get(f"/v1/appScreenshotSets/{s['id']}/appScreenshots")[1]["data"]
            dims = [f"{x['attributes'].get('imageAsset', {}).get('width')}x{x['attributes'].get('imageAsset', {}).get('height')}" for x in shots]
            print(f"     screenshots {s['attributes']['screenshotDisplayType']}: {len(shots)} {dims[:3]}")

for info in get(f"/v1/apps/{APP_ID}/appInfos?include=primaryCategory,secondaryCategory")[1]["data"]:
    rel = info["relationships"]
    cat = lambda k: (rel.get(k, {}).get("data") or {}).get("id")
    print(f"\nAPPINFO {info['attributes'].get('appStoreState')} primary={cat('primaryCategory')} "
          f"sub1={cat('primarySubcategoryOne')} secondary={cat('secondaryCategory')}")
    for loc in get(f"/v1/appInfos/{info['id']}/appInfoLocalizations")[1]["data"]:
        l = loc["attributes"]
        print(f"  [{l['locale']}] name={l.get('name')!r} subtitle={l.get('subtitle')!r} privacy={l.get('privacyPolicyUrl')}")
    age = get(f"/v1/appInfos/{info['id']}/ageRatingDeclaration")[1].get("data")
    print(f"  age rating declared: {bool(age)}")

price = get(f"/v1/apps/{APP_ID}/appPriceSchedule")[1].get("data")
print(f"\nPRICE SCHEDULE: {'set' if price else 'missing'}")
