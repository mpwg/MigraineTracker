#!/usr/bin/env python3
import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


API_BASE = "https://api.appstoreconnect.apple.com"
OPEN_VERSION_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "READY_FOR_REVIEW",
    "WAITING_FOR_REVIEW",
    "IN_REVIEW",
    "WAITING_FOR_EXPORT_COMPLIANCE",
    "PROCESSING_FOR_APP_STORE",
    "PENDING_CONTRACT",
    "PENDING_APPLE_RELEASE",
    "PENDING_DEVELOPER_RELEASE",
    "DEVELOPER_REJECTED",
    "METADATA_REJECTED",
    "REJECTED",
    "INVALID_BINARY",
}
SUBMITTED_STATES = {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW"}


class AppStoreConnectError(RuntimeError):
    pass


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def der_len(length: int) -> bytes:
    if length < 0x80:
        return bytes([length])
    encoded = []
    while length:
        encoded.insert(0, length & 0xFF)
        length >>= 8
    return bytes([0x80 | len(encoded), *encoded])


def der_int(value: int) -> bytes:
    raw = value.to_bytes((value.bit_length() + 7) // 8 or 1, "big")
    if raw[0] & 0x80:
      raw = b"\x00" + raw
    return b"\x02" + der_len(len(raw)) + raw


def der_oid(oid: str) -> bytes:
    parts = [int(part) for part in oid.split(".")]
    first = 40 * parts[0] + parts[1]
    encoded = [first]
    for value in parts[2:]:
        chunks = [value & 0x7F]
        value >>= 7
        while value:
            chunks.insert(0, 0x80 | (value & 0x7F))
            value >>= 7
        encoded.extend(chunks)
    return b"\x06" + der_len(len(encoded)) + bytes(encoded)


def der_seq(*items: bytes) -> bytes:
    payload = b"".join(items)
    return b"\x30" + der_len(len(payload)) + payload


def pem_to_private_key(pem_text: str) -> int:
    lines = [line.strip() for line in pem_text.strip().splitlines() if "-----" not in line]
    raw = base64.b64decode("".join(lines))
    marker = b"\x06\x07\x2a\x86\x48\xce\x3d\x02\x01"
    marker_index = raw.find(marker)
    if marker_index == -1:
        raise AppStoreConnectError("Die App-Store-Connect-Keydatei ist kein unterstützter EC-Private-Key.")

    bit_string_tag = raw.find(b"\x03", marker_index)
    if bit_string_tag == -1:
        raise AppStoreConnectError("Der öffentliche Schlüssel konnte aus dem privaten Schlüssel nicht gelesen werden.")
    bit_string_length = raw[bit_string_tag + 1]
    bit_string_value_start = bit_string_tag + 2
    if bit_string_length & 0x80:
        byte_count = bit_string_length & 0x7F
        bit_string_length = int.from_bytes(raw[bit_string_value_start:bit_string_value_start + byte_count], "big")
        bit_string_value_start += byte_count
    point = raw[bit_string_value_start + 1: bit_string_value_start + bit_string_length]
    if len(point) != 65 or point[0] != 0x04:
        raise AppStoreConnectError("Der EC-Public-Key hat ein unerwartetes Format.")
    x = int.from_bytes(point[1:33], "big")
    y = int.from_bytes(point[33:], "big")

    a = -3
    p = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF

    def inverse(value: int) -> int:
        return pow(value, -1, p)

    numerator = (pow(y, 2, p) - pow(x, 3, p) - a * x) % p
    denominator = inverse(x)
    private_value = (numerator * denominator) % p
    return private_value


def sign_es256(unsigned_token: str, private_value: int) -> bytes:
    import hashlib
    import secrets

    curve_order = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551
    base_x = 0x6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296
    base_y = 0x4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5
    p = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF
    a = -3

    def inverse(value: int, modulus: int) -> int:
        return pow(value, -1, modulus)

    def add(point_a, point_b):
        if point_a is None:
            return point_b
        if point_b is None:
            return point_a
        x1, y1 = point_a
        x2, y2 = point_b
        if x1 == x2 and (y1 + y2) % p == 0:
            return None
        if point_a == point_b:
            slope = ((3 * x1 * x1 + a) * inverse(2 * y1 % p, p)) % p
        else:
            slope = ((y2 - y1) * inverse((x2 - x1) % p, p)) % p
        x3 = (slope * slope - x1 - x2) % p
        y3 = (slope * (x1 - x3) - y1) % p
        return (x3, y3)

    def multiply(scalar: int, point):
        result = None
        addend = point
        while scalar:
            if scalar & 1:
                result = add(result, addend)
            addend = add(addend, addend)
            scalar >>= 1
        return result

    digest = hashlib.sha256(unsigned_token.encode("utf-8")).digest()
    z = int.from_bytes(digest, "big")

    while True:
        nonce = secrets.randbelow(curve_order - 1) + 1
        point = multiply(nonce, (base_x, base_y))
        if point is None:
            continue
        r = point[0] % curve_order
        if r == 0:
            continue
        s = (inverse(nonce, curve_order) * (z + r * private_value)) % curve_order
        if s == 0:
            continue
        if s > curve_order // 2:
            s = curve_order - s
        return r.to_bytes(32, "big") + s.to_bytes(32, "big")


def load_private_key(path: str) -> int:
    with open(path, "r", encoding="utf-8") as handle:
        return pem_to_private_key(handle.read())


class AppStoreConnectClient:
    def __init__(self, key_id: str, issuer_id: str, private_key_path: str):
        self.key_id = key_id
        self.issuer_id = issuer_id
        self.private_value = load_private_key(private_key_path)

    def token(self) -> str:
        now = int(time.time())
        header = {"alg": "ES256", "kid": self.key_id, "typ": "JWT"}
        payload = {"iss": self.issuer_id, "aud": "appstoreconnect-v1", "exp": now + 1200}
        encoded_header = b64url(json.dumps(header, separators=(",", ":")).encode("utf-8"))
        encoded_payload = b64url(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
        unsigned = f"{encoded_header}.{encoded_payload}"
        signature = b64url(sign_es256(unsigned, self.private_value))
        return f"{unsigned}.{signature}"

    def request(self, method: str, path: str, payload=None, query=None):
        url = f"{API_BASE}{path}"
        if query:
            url += "?" + urllib.parse.urlencode(query, doseq=True)
        request_body = None
        headers = {"Authorization": f"Bearer {self.token()}", "Accept": "application/json"}
        if payload is not None:
            request_body = json.dumps(payload).encode("utf-8")
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(url, data=request_body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                if response.status == 204:
                    return None
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            message = body
            try:
                parsed = json.loads(body)
                if parsed.get("errors"):
                    message = "; ".join(error.get("detail") or error.get("title", "Unbekannter API-Fehler") for error in parsed["errors"])
            except json.JSONDecodeError:
                pass
            raise AppStoreConnectError(f"{method} {path} fehlgeschlagen: HTTP {exc.code}: {message}") from exc


def require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise AppStoreConnectError(f"Die Umgebungsvariable {name} fehlt.")
    return value


def get_client() -> AppStoreConnectClient:
    return AppStoreConnectClient(
        key_id=require_env("APP_STORE_CONNECT_KEY_ID"),
        issuer_id=require_env("APP_STORE_CONNECT_ISSUER_ID"),
        private_key_path=require_env("APP_STORE_CONNECT_KEY_PATH"),
    )


def find_app_id(client: AppStoreConnectClient, bundle_id: str) -> str:
    response = client.request("GET", "/v1/apps", query={"filter[bundleId]": bundle_id, "limit": 2})
    data = response.get("data", [])
    if not data:
        raise AppStoreConnectError(f"Keine App mit Bundle-ID {bundle_id} in App Store Connect gefunden.")
    return data[0]["id"]


def find_existing_version(client: AppStoreConnectClient, app_id: str, version: str, platform: str):
    response = client.request(
        "GET",
        f"/v1/apps/{app_id}/appStoreVersions",
        query={
            "filter[platform]": platform,
            "limit": 200,
        },
    )
    matches = [item for item in response.get("data", []) if item["attributes"].get("versionString") == version]
    if not matches:
        return None
    matches.sort(key=lambda item: item["attributes"].get("createdDate", ""), reverse=True)
    return matches[0]


def create_version(client: AppStoreConnectClient, app_id: str, version: str, platform: str):
    payload = {
        "data": {
            "type": "appStoreVersions",
            "attributes": {
                "platform": platform,
                "versionString": version,
                "releaseType": "MANUAL",
            },
            "relationships": {
                "app": {
                    "data": {
                        "type": "apps",
                        "id": app_id,
                    }
                }
            },
        }
    }
    response = client.request("POST", "/v1/appStoreVersions", payload=payload)
    return response["data"]


def ensure_version(client: AppStoreConnectClient, app_id: str, version: str, platform: str):
    existing = find_existing_version(client, app_id, version, platform)
    if existing:
        state = existing["attributes"].get("appStoreState")
        if state not in OPEN_VERSION_STATES and state not in SUBMITTED_STATES:
            raise AppStoreConnectError(
                f"Die Version {version} existiert bereits im Zustand {state} und kann nicht erneut submitted werden."
            )
        return existing
    return create_version(client, app_id, version, platform)


def wait_for_build(client: AppStoreConnectClient, app_id: str, build_number: str, timeout: int, poll_interval: int):
    deadline = time.time() + timeout
    while time.time() < deadline:
        response = client.request(
            "GET",
            "/v1/builds",
            query={
                "filter[app]": app_id,
                "filter[version]": build_number,
                "fields[builds]": "version,uploadedDate,processingState",
                "limit": 20,
                "sort": "-uploadedDate",
            },
        )
        builds = response.get("data", [])
        if builds:
            build = builds[0]
            processing_state = build["attributes"].get("processingState")
            if processing_state == "VALID":
                return build
            if processing_state in {"FAILED", "INVALID"}:
                raise AppStoreConnectError(
                    f"Der hochgeladene Build {build_number} wurde in App Store Connect mit Status {processing_state} markiert."
                )
            print(
                f"Build {build_number} ist in App Store Connect sichtbar, aber noch nicht fertig verarbeitet ({processing_state}).",
                file=sys.stderr,
            )
        else:
            print(f"Warte auf Build {build_number} in App Store Connect.", file=sys.stderr)
        time.sleep(poll_interval)
    raise AppStoreConnectError(f"Build {build_number} wurde nicht innerhalb von {timeout} Sekunden verarbeitet.")


def attach_build(client: AppStoreConnectClient, version_id: str, build_id: str):
    payload = {"data": {"type": "builds", "id": build_id}}
    client.request("PATCH", f"/v1/appStoreVersions/{version_id}/relationships/build", payload=payload)


def submit_version(client: AppStoreConnectClient, version_id: str):
    payload = {
        "data": {
            "type": "appStoreVersionSubmissions",
            "relationships": {
                "appStoreVersion": {
                    "data": {
                        "type": "appStoreVersions",
                        "id": version_id,
                    }
                }
            },
        }
    }
    client.request("POST", "/v1/appStoreVersionSubmissions", payload=payload)


def command_submit_release(args):
    client = get_client()
    app_id = find_app_id(client, args.bundle_id)
    version = ensure_version(client, app_id, args.version, args.platform)
    version_id = version["id"]
    state = version["attributes"].get("appStoreState")

    build = wait_for_build(client, app_id, args.build_number, args.wait_timeout, args.poll_interval)
    build_id = build["id"]

    attach_build(client, version_id, build_id)

    if state in SUBMITTED_STATES:
        print(
            f"Version {args.version} befindet sich bereits im Zustand {state}. Der Build wurde aktualisiert, eine neue Submission wird übersprungen."
        )
        return

    submit_version(client, version_id)
    print(
        json.dumps(
            {
                "app_id": app_id,
                "app_store_version_id": version_id,
                "build_id": build_id,
                "version": args.version,
                "build_number": args.build_number,
            }
        )
    )


def build_parser():
    parser = argparse.ArgumentParser(description="App-Store-Connect-Hilfswerkzeuge für GitHub Actions.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    submit_release = subparsers.add_parser("submit-release", help="Ordnet einen Build einer Version zu und submitted sie.")
    submit_release.add_argument("--bundle-id", required=True)
    submit_release.add_argument("--version", required=True)
    submit_release.add_argument("--build-number", required=True)
    submit_release.add_argument("--platform", default="IOS")
    submit_release.add_argument("--wait-timeout", type=int, default=1800)
    submit_release.add_argument("--poll-interval", type=int, default=30)
    submit_release.set_defaults(func=command_submit_release)

    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()
    try:
        args.func(args)
    except AppStoreConnectError as exc:
        print(f"Fehler: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
