#!/usr/bin/env python3
"""Genera catálogos finales de video desde processed.json:

- INDEX_PROD.json : catálogo maestro (variantes, URLs, dimensiones, hashes).
- VIDEO_URLS.json : objeto simplificado para apps y CMS.
- VIDEO_URLS.ts   : constantes tipadas (React/Next/Vite).
- VIDEO_URLS.js   : módulo ES equivalente.
- urls.txt        : listado humano.

Sin publicar => url: null (nunca se inventa).
Uso: python build_manifests.py --work <workdir>
"""
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

from common import camel_case, load_json, save_json


def rel(path, workdir):
    try:
        return str(Path(path).relative_to(workdir))
    except ValueError:
        return path


def build_index(data, workdir):
    assets = []
    for a in data["assets"]:
        assets.append({
            "id": a["id"], "name": a["name"], "category": a["category"],
            "role": a["role"], "title": a["title"],
            "original_name": a["original_name"], "status": a["status"],
            "provider": a.get("provider"), "hash": a["hash"],
            "width": a["width"], "height": a["height"],
            "duration": a["duration"], "audio": a["audio"],
            "variants": [{**{k: v.get(k) for k in
                             ("height", "width", "format", "bytes", "audio")},
                          "path": rel(v["path"], workdir), "url": v.get("url")}
                         for v in a["variants"]],
            "poster": ({"path": rel(a["poster"]["path"], workdir),
                        "bytes": a["poster"]["bytes"],
                        "url": a["poster"].get("url")}
                       if a.get("poster") else None),
        })
    return {"generated_at": datetime.now(timezone.utc).isoformat(),
            "provider": data["config"].get("provider"),
            "base_prefix": data["config"].get("base_prefix"),
            "count": len(assets),
            "duplicates": data.get("duplicates", []),
            "errors": data.get("errors", []),
            "assets": assets}


def build_simple(data):
    out = {}
    for a in data["assets"]:
        heights = sorted({v["height"] for v in a["variants"]}, reverse=True)
        top = heights[0] if heights else None
        sources = {}
        for h in heights:
            sources[f"h{h}"] = {
                v["format"]: v.get("url")
                for v in a["variants"] if v["height"] == h}
        entry = {
            "mp4": next((v.get("url") for v in a["variants"]
                         if v["format"] == "mp4" and v["height"] == top), None),
            "webm": next((v.get("url") for v in a["variants"]
                          if v["format"] == "webm" and v["height"] == top),
                         None),
            "poster": a["poster"].get("url") if a.get("poster") else None,
            "sources": sources,
            "width": a["width"], "height": a["height"],
            "duration": a["duration"], "audio": a["audio"],
            "title": a["title"],
        }
        if a["status"] != "published":
            entry["published"] = False
        out[camel_case(a["name"])] = entry
    return out


TS_HEADER = """// Generado por video-pipeline — no editar a mano.
// Uso: import { VIDEOS } from "./VIDEO_URLS";
//
// <video poster={VIDEOS.heroDemo.poster} autoPlay muted loop playsInline>
//   <source src={VIDEOS.heroDemo.webm} type="video/webm" />
//   <source src={VIDEOS.heroDemo.mp4} type="video/mp4" />
// </video>

export interface VideoAsset {
  mp4: string | null;
  webm: string | null;
  poster: string | null;
  sources: Record<string, Record<string, string | null>>;
  width: number | null;
  height: number | null;
  duration: number | null;
  audio: boolean;
  title: string;
  published?: boolean;
}

export const VIDEOS = """

JS_HEADER = """// Generado por video-pipeline — no editar a mano.
// Módulo ES. Uso: import { VIDEOS } from "./VIDEO_URLS.js";

export const VIDEOS = """


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default="pipeline-work")
    args = ap.parse_args()
    workdir = Path(args.work)
    data = load_json(workdir / "processed.json")
    out = workdir / "manifests"
    out.mkdir(parents=True, exist_ok=True)

    save_json(out / "INDEX_PROD.json", build_index(data, workdir))
    simple = build_simple(data)
    save_json(out / "VIDEO_URLS.json", simple)
    body = json.dumps(simple, indent=2, ensure_ascii=False)
    (out / "VIDEO_URLS.ts").write_text(
        TS_HEADER + body + " as const satisfies Record<string, VideoAsset>;\n",
        encoding="utf-8")
    (out / "VIDEO_URLS.js").write_text(JS_HEADER + body + ";\n",
                                       encoding="utf-8")
    lines = []
    for a in data["assets"]:
        lines.append(f"{a['name']}:")
        for v in a["variants"]:
            lines.append(f"  {v['height']}p {v['format']}  ->  "
                         f"{v.get('url') or '(no publicado)'}")
        if a.get("poster"):
            lines.append(f"  poster  ->  "
                         f"{a['poster'].get('url') or '(no publicado)'}")
    (out / "urls.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Manifiestos generados en {out}")


if __name__ == "__main__":
    main()
