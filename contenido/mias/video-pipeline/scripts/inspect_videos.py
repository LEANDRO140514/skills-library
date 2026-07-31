#!/usr/bin/env python3
"""Inspecciona videos con ffprobe y genera inventory.json.

Detecta: códec, dimensiones, orientación, duración, fps, audio, bitrate,
peso, hash (duplicados exactos) y nombres genéricos.

Uso: python inspect_videos.py <rutas...> --out <workdir>
"""
import argparse
import json
import subprocess
import sys
import zipfile
from pathlib import Path

from common import is_generic_name, save_json, sha256_file

VIDEO_EXTS = {".mp4", ".mov", ".webm", ".mkv", ".avi", ".m4v", ".wmv", ".mpg",
              ".mpeg", ".3gp"}


def collect_files(inputs, workdir: Path):
    files = []
    for raw in inputs:
        p = Path(raw)
        if not p.exists():
            print(f"AVISO: no existe {p}", file=sys.stderr)
            continue
        if p.is_dir():
            files += [f for f in sorted(p.rglob("*"))
                      if f.is_file() and f.suffix.lower() in VIDEO_EXTS]
        elif p.suffix.lower() == ".zip":
            dest = workdir / "_extracted" / p.stem
            dest.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(p) as z:
                z.extractall(dest)
            files += [f for f in sorted(dest.rglob("*"))
                      if f.is_file() and f.suffix.lower() in VIDEO_EXTS
                      and "__MACOSX" not in f.parts]
        elif p.suffix.lower() in VIDEO_EXTS:
            files.append(p)
        else:
            print(f"AVISO: no es video soportado, se omite {p}", file=sys.stderr)
    return files


def ffprobe(path: Path) -> dict:
    cmd = ["ffprobe", "-v", "quiet", "-print_format", "json",
           "-show_format", "-show_streams", str(path)]
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    return json.loads(out.stdout) if out.returncode == 0 else {}


def inspect_file(path: Path) -> dict:
    rec = {
        "path": str(path),
        "original_name": path.name,
        "bytes": path.stat().st_size,
        "hash": sha256_file(path),
        "generic_name": is_generic_name(path.stem),
    }
    info = ffprobe(path)
    if not info:
        rec["error"] = "ffprobe no pudo leer el archivo"
        return rec
    v = next((s for s in info.get("streams", [])
              if s.get("codec_type") == "video"), None)
    a = next((s for s in info.get("streams", [])
              if s.get("codec_type") == "audio"), None)
    if not v:
        rec["error"] = "sin stream de video"
        return rec
    w, h = int(v.get("width", 0)), int(v.get("height", 0))
    # Rotación en metadata (videos de móvil)
    rot = 0
    for sd in v.get("side_data_list", []) or []:
        if "rotation" in sd:
            rot = abs(int(sd["rotation"]))
    if rot in (90, 270):
        w, h = h, w
    fps = v.get("avg_frame_rate", "0/1")
    try:
        num, den = fps.split("/")
        fps = round(float(num) / float(den), 2) if float(den) else None
    except (ValueError, ZeroDivisionError):
        fps = None
    fmt = info.get("format", {})
    rec.update(
        codec=v.get("codec_name"),
        width=w, height=h,
        orientation="landscape" if w > h else ("portrait" if h > w else "square"),
        duration=round(float(fmt.get("duration", 0)), 2),
        fps=fps,
        has_audio=a is not None,
        bitrate_kbps=round(int(fmt.get("bit_rate", 0)) / 1000)
        if fmt.get("bit_rate") else None,
    )
    return rec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inputs", nargs="+")
    ap.add_argument("--out", default="pipeline-work")
    args = ap.parse_args()
    workdir = Path(args.out)
    workdir.mkdir(parents=True, exist_ok=True)

    files = collect_files(args.inputs, workdir)
    if not files:
        print("ERROR: no se encontraron videos.", file=sys.stderr)
        sys.exit(1)
    records = [inspect_file(f) for f in files]

    seen = {}
    for r in records:
        if "error" in r:
            continue
        if r["hash"] in seen:
            r["duplicate_of"] = seen[r["hash"]]
        else:
            seen[r["hash"]] = r["path"]

    save_json(workdir / "inventory.json", {"count": len(records),
                                           "assets": records})
    dups = sum(1 for r in records if r.get("duplicate_of"))
    errs = sum(1 for r in records if r.get("error"))
    total_dur = sum(r.get("duration", 0) for r in records if "error" not in r)
    print(f"Inventario: {len(records)} videos | {total_dur:.0f}s totales | "
          f"{dups} duplicados | {errs} con error")
    print(f"Guardado en {workdir / 'inventory.json'}")


if __name__ == "__main__":
    main()
