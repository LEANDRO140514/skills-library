#!/usr/bin/env python3
"""Genera los catálogos finales a partir de processed.json:

- INDEX_PROD.json : catálogo maestro (archivos, variantes, rutas, URLs,
                    dimensiones, formatos, tamaños, hashes, alt).
- IMAGE_URLS.json : objeto simplificado de URLs para apps, APIs y CMS.
- IMAGE_URLS.ts   : constantes tipadas (React, Next.js, Vite, TypeScript).
- IMAGE_URLS.js   : equivalente JavaScript.
- urls.txt        : listado humano nombre -> URL.

Si un asset no fue publicado, url queda en null (nunca se inventa).

Uso: python build_manifests.py --work <workdir>
"""
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

from common import camel_case, load_json, save_json


def rel_dist(path: str, workdir: Path) -> str:
    try:
        return str(Path(path).relative_to(workdir))
    except ValueError:
        return path


def build_index(data: dict, workdir: Path) -> dict:
    assets = []
    for a in data["assets"]:
        main = a["variants"][0]
        assets.append({
            "id": a["id"], "name": a["name"], "category": a["category"],
            "type": a["type"], "alt": a["alt"],
            "original_name": a["original_name"],
            "status": a["status"], "provider": a.get("provider"),
            "hash": a["hash"],
            "url": main.get("url"),
            "width": main.get("width"), "height": main.get("height"),
            "format": main.get("format"),
            "variants": [{
                "width": v.get("width"), "height": v.get("height"),
                "format": v.get("format"), "bytes": v.get("bytes"),
                "path": rel_dist(v["path"], workdir), "url": v.get("url"),
            } for v in a["variants"]],
            "thumbnail": ({
                "width": a["thumbnail"].get("width"),
                "height": a["thumbnail"].get("height"),
                "bytes": a["thumbnail"].get("bytes"),
                "path": rel_dist(a["thumbnail"]["path"], workdir),
                "url": a["thumbnail"].get("url"),
            } if a.get("thumbnail") else None),
        })
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "provider": data["config"].get("provider"),
        "base_prefix": data["config"].get("base_prefix"),
        "count": len(assets),
        "duplicates": data.get("duplicates", []),
        "errors": data.get("errors", []),
        "assets": assets,
    }


def build_simple(data: dict) -> dict:
    out = {}
    for a in data["assets"]:
        main = a["variants"][0]
        entry = {
            "url": main.get("url"),
            "alt": a["alt"],
            "width": main.get("width"),
            "height": main.get("height"),
            "sizes": {f"w{v['width']}": v.get("url") for v in a["variants"]
                      if v.get("width")},
        }
        if a.get("thumbnail"):
            entry["thumb"] = a["thumbnail"].get("url")
        if a["status"] != "published":
            entry["published"] = False
        out[camel_case(a["name"])] = entry
    return out


TS_HEADER = """// Generado por image-pipeline — no editar a mano.
// Uso: import { IMAGES } from "./IMAGE_URLS";

export interface ImageAsset {
  url: string | null;
  alt: string;
  width: number | null;
  height: number | null;
  sizes: Record<string, string | null>;
  thumb?: string | null;
  published?: boolean;
}

export const IMAGES = """

JS_HEADER = """// Generado por image-pipeline — no editar a mano.
// Módulo ES. Uso: import { IMAGES } from "./IMAGE_URLS.js";

export const IMAGES = """


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default="pipeline-work")
    args = ap.parse_args()
    workdir = Path(args.work)
    data = load_json(workdir / "processed.json")
    out = workdir / "manifests"
    out.mkdir(parents=True, exist_ok=True)

    index = build_index(data, workdir)
    save_json(out / "INDEX_PROD.json", index)

    simple = build_simple(data)
    save_json(out / "IMAGE_URLS.json", simple)

    body = json.dumps(simple, indent=2, ensure_ascii=False)
    (out / "IMAGE_URLS.ts").write_text(
        TS_HEADER + body + " as const satisfies Record<string, ImageAsset>;\n",
        encoding="utf-8")
    (out / "IMAGE_URLS.js").write_text(JS_HEADER + body + ";\n",
                                       encoding="utf-8")

    lines = []
    for a in data["assets"]:
        url = a["variants"][0].get("url") or "(no publicado)"
        lines.append(f"{a['name']}  ->  {url}")
        for v in a["variants"][1:]:
            lines.append(f"  {v['width']}px  ->  {v.get('url') or '(no publicado)'}")
        if a.get("thumbnail"):
            lines.append(f"  thumb  ->  {a['thumbnail'].get('url') or '(no publicado)'}")
    (out / "urls.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"Manifiestos generados en {out}:")
    for f in ["INDEX_PROD.json", "IMAGE_URLS.json", "IMAGE_URLS.ts",
              "IMAGE_URLS.js", "urls.txt"]:
        print(f"  - {f}")


if __name__ == "__main__":
    main()
