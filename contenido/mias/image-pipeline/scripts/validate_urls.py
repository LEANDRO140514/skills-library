#!/usr/bin/env python3
"""Valida cada URL publicada y genera reports/publish-report.md.

Comprueba: respuesta HTTP 200, content-type de imagen esperado y que el
recurso sea accesible. Marca cada variante como validated | invalid.
El modo optimize-and-publish NO se considera terminado si algo queda invalid.

Uso: python validate_urls.py --work <workdir>
"""
import argparse
from pathlib import Path

import requests
from common import load_json, save_json

EXPECTED = {"webp": "image/webp", "svg": "image/svg+xml",
            "png": "image/png", "jpg": "image/jpeg", "gif": "image/gif",
            "avif": "image/avif"}


def check(url: str, fmt: str) -> tuple[bool, str]:
    try:
        r = requests.head(url, timeout=30, allow_redirects=True)
        if r.status_code in (403, 405) or "content-type" not in r.headers:
            r = requests.get(url, timeout=30, stream=True,
                             allow_redirects=True)
        if r.status_code != 200:
            return False, f"HTTP {r.status_code}"
        ct = r.headers.get("content-type", "").split(";")[0].strip()
        expected = EXPECTED.get(fmt)
        if expected and ct != expected and not ct.startswith("image/"):
            return False, f"content-type inesperado: {ct}"
        return True, ct
    except Exception as e:
        return False, str(e)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default="pipeline-work")
    args = ap.parse_args()
    workdir = Path(args.work)
    data = load_json(workdir / "processed.json")

    entries, valid, invalid, unpublished = [], 0, 0, 0
    for a in data["assets"]:
        targets = list(a["variants"]) + \
            ([a["thumbnail"]] if a.get("thumbnail") else [])
        for v in targets:
            url = v.get("url")
            name = Path(v["path"]).name
            if not url:
                unpublished += 1
                entries.append((name, None, False,
                                v.get("publish_error", "not-published")))
                continue
            ok, detail = check(url, v.get("format", ""))
            v["validated"] = ok
            if ok:
                valid += 1
            else:
                invalid += 1
                v["validation_error"] = detail
            entries.append((name, url, ok, detail))
        if a["status"] == "published" and any(
                not v.get("validated") for v in a["variants"]):
            a["status"] = "validation-failed"

    save_json(workdir / "processed.json", data)

    lines = ["# Reporte de publicación\n",
             f"- URLs válidas: **{valid}**",
             f"- URLs inválidas: **{invalid}**",
             f"- Sin publicar: **{unpublished}**\n",
             "| Archivo | URL | Estado | Detalle |", "|---|---|---|---|"]
    for name, url, ok, detail in entries:
        status = "OK" if ok else ("no publicado" if url is None else "ERROR")
        lines.append(f"| {name} | {url or '—'} | {status} | {detail} |")
    report = workdir / "reports" / "publish-report.md"
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text("\n".join(lines), encoding="utf-8")

    print(f"Validación: {valid} OK, {invalid} inválidas, "
          f"{unpublished} sin publicar. Reporte: {report}")
    if invalid:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
