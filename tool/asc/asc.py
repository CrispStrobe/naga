"""Minimal App Store Connect API client for CI.

Credentials come from the environment (GitHub secrets), never from files in
the repo: ASC_KEY_ID, ASC_ISSUER_ID, ASC_APP_ID and ASC_API_KEY_P8_BASE64.
"""
import base64
import json
import os
import time
import urllib.error
import urllib.request

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils

BASE = "https://api.appstoreconnect.apple.com"
APP_ID = os.environ.get("ASC_APP_ID", "")


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def token() -> str:
    key = serialization.load_pem_private_key(
        base64.b64decode(os.environ["ASC_API_KEY_P8_BASE64"]), password=None)
    now = int(time.time())
    header = _b64(json.dumps({"alg": "ES256", "kid": os.environ["ASC_KEY_ID"],
                              "typ": "JWT"}, separators=(",", ":")).encode())
    payload = _b64(json.dumps({"iss": os.environ["ASC_ISSUER_ID"], "iat": now,
                               "exp": now + 1100, "aud": "appstoreconnect-v1"},
                              separators=(",", ":")).encode())
    r, s = utils.decode_dss_signature(
        key.sign(f"{header}.{payload}".encode(), ec.ECDSA(hashes.SHA256())))
    return f"{header}.{payload}.{_b64(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))}"


def call(method: str, path: str, body=None):
    """Returns (status, parsed JSON). Never raises on HTTP errors."""
    url = path if path.startswith("http") else BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as resp:
            text = resp.read().decode()
            return resp.status, (json.loads(text) if text else {})
    except urllib.error.HTTPError as err:
        text = err.read().decode()
        try:
            return err.code, json.loads(text)
        except ValueError:
            return err.code, {"raw": text}


def get(path): return call("GET", path)
def post(path, body): return call("POST", path, body)
def patch(path, body): return call("PATCH", path, body)
def delete(path, body=None): return call("DELETE", path, body)


def errors(resp) -> str:
    return "; ".join(f"{e.get('status')} {e.get('code')}: {e.get('detail') or e.get('title')}"
                     for e in resp.get("errors", []))


def check(status, resp, what):
    """Prints the outcome and stops the run on an unexpected failure."""
    if status >= 400:
        raise SystemExit(f"FAILED {what}: {status} {errors(resp) or resp}")
    print(f"ok  {what}")
    return resp
