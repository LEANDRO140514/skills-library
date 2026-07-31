#!/usr/bin/env python3
"""Procesa videos para web según names.json y pipeline.config.json.

- Renombra con nombres semánticos (slug).
- Genera MP4 (H.264 + faststart) y WebM (VP9) por cada resolución.
- Resoluciones responsivas SIN ampliar jamás (altura <= original).
- Extrae poster WebP (frame representativo) para <video poster=...>.
- Rol "background": elimina audio (autoplay silencioso) salvo override.
- Omite duplicados exactos.

Salida: dist/<categoria>/<nombre>-<altura>p.<mp4|webm> + poster +
processed.json + reports/optimization-report.md

Uso: python process_videos.py --work <workdir>
Requiere en <workdir>: inventory.json, names.json, pipeline.config.json (opc.)
"""
import argparse
import subprocess
from pathlib import Path

from common import human_size, load_json, save_json, slugify

DEFAULT_CONFIG = {
    "mode": "optimize",            # optimize | optimize-and-publish
    "heights": [1080, 720],        # resoluciones de salida (altura)
    "formats": ["mp4", "webm"],
    "crf_h264": 23,
    "crf_vp9": 33,
    "poster": True,
    "poster_second": None,          # None = 10% de la duración
    "max_fps": 30,
    "base_prefix": "videos",
    "provider": None,
}


def load_config(workdir: Path) -> dict:
    cfg = dict(DEFAULT_CONFIG)
    p = workdir / "pipeline.config.json"
    if p.exists():
        cfg.update(load_json(p))
    return cfg


def run(cmd: list) -> None:
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"ffmpeg falló: {' '.join(cmd)}\n{r.stderr[-800:]}")


def target_heights(orig_h: int, cfg: dict):
    """Alturas <= original. Nunca ampliar."""
    hs = sorted({h for h in cfg["heights"] if h <= orig_h}, reverse=True)
    return hs or [orig_h]


def encode(src: Path, dest: Path, height: int, fmt: str, strip_audio: bool,
           cfg: dict, fps: float | None) -> dict:
    vf = f"scale=-2:{height}"
    if fps and cfg.get("max_fps") and fps > cfg["max_fps"]:
        vf += f",fps={cfg['max_fps']}"
    cmd = ["ffmpeg", "-y", "-i", str(src), "-vf", vf]
    if strip_audio:
        cmd += ["-an"]
    else:
        cmd += ["-c:a", "aac", "-b:a", "128k"] if fmt == "mp4" \
            else ["-c:a", "libopus", "-b:a", "96k"]
    if fmt == "mp4":
        cmd += ["-c:v", "libx264", "-crf", str(cfg["crf_h264"]),
                "-preset", "medium", "-pix_fmt", "yuv420p",
                "-movflags", "+faststart"]
    else:  # webm
        cmd += ["-c:v", "libvpx-vp9", "-crf", str(cfg["crf_vp9"]),
                "-b:v", "0", "-row-mt", "1", "-cpu-used", "2"]
    dest.parent.mkdir(parents=True, exist_ok=True)
    cmd.append(str(dest))
    run(cmd)
    probe = subprocess.run(
        ["ffprobe", "-v", "quiet", "-select_streams", "v:0",
         "-show_entries", "stream=width,height", "-of", "csv=p=0", str(dest)],
        capture_output=True, text=True)
    w, h = (probe.stdout.strip().split(",") + ["0", "0"])[:2]
    return {"height": int(h or 0), "width": int(w or 0), "format": fmt,
            "path": str(dest), "bytes": dest.stat().st_size,
            "audio": not strip_audio}


def extract_poster(src: Path, dest: Path, duration: float, cfg: dict,
                   height: int) -> dict:
    sec = cfg.get("poster_second")
    if sec is None:
        sec = max(0.5, round(duration * 0.10, 2))
    dest.parent.mkdir(parents=True, exist_ok=True)
    run(["ffmpeg", "-y", "-ss", str(sec), "-i", str(src), "-frames:v", "1",
         "-vf", f"scale=-2:{height}", "-quality", "82", str(dest)])
    return {"path": str(dest), "bytes": dest.stat().st_size,
            "format": "webp", "second": sec}


def process_asset(rec: dict, meta: dict, cfg: dict, dist: Path) -> dict:
    src = Path(rec["path"])
    name = slugify(meta["name"])
    category = slugify(meta.get("category", "general"))
    role = meta.get("role", "demo")   # hero | background | demo
    # background: sin audio por defecto; override con meta["keep_audio"]=true
    strip = meta.get("keep_audio") is not True and (
        role == "background" or not rec.get("has_audio"))
    out_dir = dist / category

    asset = {
        "id": name, "name": name, "category": category, "role": role,
        "title": meta.get("title", ""), "original_name": rec["original_name"],
        "original_bytes": rec["bytes"], "codec": rec.get("codec"),
        "width": rec.get("width"), "height": rec.get("height"),
        "orientation": rec.get("orientation"),
        "duration": rec.get("duration"), "audio": not strip,
        "hash": rec["hash"], "variants": [], "poster": None,
        "status": "processed",
    }
    for h in target_heights(rec["height"], cfg):
        for fmt in cfg["formats"]:
            dest = out_dir / f"{name}-{h}p.{fmt}"
            asset["variants"].append(
                encode(src, dest, h, fmt, strip, cfg, rec.get("fps")))
    if cfg.get("poster"):
        top_h = asset["variants"][0]["height"]
        asset["poster"] = extract_poster(
            src, out_dir / f"{name}-poster.webp", rec.get("duration", 0),
            cfg, top_h)
    return asset


def write_report(assets, skipped, errors, workdir: Path):
    lines = ["# Reporte de optimización de video\n"]
    tin = sum(a["original_bytes"] for a in assets)
    tout = sum(v["bytes"] for a in assets for v in a["variants"])
    lines += [f"- Videos procesados: **{len(assets)}**",
              f"- Duplicados omitidos: **{len(skipped)}**",
              f"- Errores: **{len(errors)}**",
              f"- Peso original total: **{human_size(tin)}**",
              f"- Peso optimizado total (todas las variantes): "
              f"**{human_size(tout)}**\n",
              "| Video | Original | MP4 principal | Ahorro | Audio |",
              "|---|---|---|---|---|"]
    for a in assets:
        mp4 = next((v for v in a["variants"] if v["format"] == "mp4"),
                   a["variants"][0])
        sav = (1 - mp4["bytes"] / a["original_bytes"]) * 100 \
            if a["original_bytes"] else 0
        lines.append(f"| {a['name']} ({a['role']}) | "
                     f"{human_size(a['original_bytes'])} ({a['codec']}) | "
                     f"{human_size(mp4['bytes'])} ({mp4['height']}p) | "
                     f"{sav:.0f}% | {'sí' if a['audio'] else 'no'} |")
    if skipped:
        lines.append("\n## Duplicados omitidos")
        lines += [f"- `{d['original_name']}` es idéntico a "
                  f"`{d['duplicate_of']}`" for d in skipped]
    if errors:
        lines.append("\n## Errores")
        lines += [f"- `{e.get('original_name')}`: {e.get('error')}"
                  for e in errors]
    p = workdir / "reports" / "optimization-report.md"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("\n".join(lines), encoding="utf-8")
    return p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default="pipeline-work")
    args = ap.parse_args()
    workdir = Path(args.work)
    inventory = load_json(workdir / "inventory.json")
    names = load_json(workdir / "names.json")
    cfg = load_config(workdir)
    dist = workdir / "dist"

    assets, skipped, errors = [], [], []
    for rec in inventory["assets"]:
        if rec.get("error"):
            errors.append(rec)
            continue
        if rec.get("duplicate_of"):
            skipped.append(rec)
            continue
        meta = names.get(rec["path"]) or names.get(rec["original_name"])
        if not meta:
            errors.append({**rec, "error": "sin entrada en names.json"})
            continue
        try:
            assets.append(process_asset(rec, meta, cfg, dist))
        except RuntimeError as e:
            errors.append({**rec, "error": str(e)[:300]})

    seen = {}
    for a in assets:
        key = (a["category"], a["name"])
        if key in seen:
            raise SystemExit(f"ERROR: nombre duplicado '{a['name']}' en "
                             f"'{a['category']}'. Corrige names.json.")
        seen[key] = True

    save_json(workdir / "processed.json",
              {"config": cfg, "assets": assets,
               "duplicates": [{"original_name": d["original_name"],
                               "duplicate_of": d["duplicate_of"]}
                              for d in skipped],
               "errors": [{"original_name": e.get("original_name"),
                           "error": e.get("error")} for e in errors]})
    report = write_report(assets, skipped, errors, workdir)
    print(f"Procesados {len(assets)} videos -> {dist}")
    print(f"Reporte: {report}")
    if errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
