#!/usr/bin/env python3
"""Inspecciona una carpeta, archivos sueltos o un ZIP de imágenes.

Genera inventory.json con: formato, dimensiones, orientación, transparencia,
peso, hash (para duplicados), nombre genérico y una clasificación heurística
del tipo visual (photo | graphic | icon | vector) que Claude debe revisar.

Uso:
    python inspect_assets.py <ruta1> [ruta2 ...] --out <workdir>
"""
import argparse
import re
import sys
import zipfile
from pathlib import Path

from PIL import Image, ImageOps
from common import IMG_EXTS, is_generic_name, save_json, sha256_file

Image.MAX_IMAGE_PIXELS = 300_000_000


def collect_files(inputs, workdir: Path):
    """Expande carpetas y ZIPs a una lista de archivos de imagen."""
    files = []
    extract_root = workdir / "_extracted"
    for raw in inputs:
        p = Path(raw)
        if not p.exists():
            print(f"AVISO: no existe {p}", file=sys.stderr)
            continue
        if p.is_dir():
            files += [f for f in sorted(p.rglob("*"))
                      if f.is_file() and f.suffix.lower() in IMG_EXTS]
        elif p.suffix.lower() == ".zip":
            dest = extract_root / p.stem
            dest.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(p) as z:
                z.extractall(dest)
            files += [f for f in sorted(dest.rglob("*"))
                      if f.is_file() and f.suffix.lower() in IMG_EXTS
                      and "__MACOSX" not in f.parts]
        elif p.suffix.lower() in IMG_EXTS:
            files.append(p)
        else:
            print(f"AVISO: formato no soportado, se omite {p}", file=sys.stderr)
    return files


def svg_dimensions(path: Path):
    try:
        head = path.read_text(encoding="utf-8", errors="ignore")[:4000]
        m = re.search(r'viewBox\s*=\s*["\']\s*[\d.\-]+[\s,]+[\d.\-]+[\s,]+'
                      r'([\d.]+)[\s,]+([\d.]+)', head)
        if m:
            return round(float(m.group(1))), round(float(m.group(2)))
    except Exception:
        pass
    return None, None


def classify_raster(img: Image.Image, width: int, height: int, has_alpha: bool) -> str:
    """Heurística inicial; Claude la confirma o corrige visualmente."""
    sample = img.convert("RGBA").resize((64, 64))
    colors = sample.getcolors(maxcolors=4096)
    n_colors = len(colors) if colors else 4097
    small = max(width, height) <= 512
    squarish = min(width, height) / max(width, height) > 0.75 if width and height else False
    if n_colors <= 96:
        if small and squarish:
            return "icon"
        return "graphic"  # logo, ilustración plana o gráfico
    if has_alpha and n_colors <= 512:
        return "graphic"
    return "photo"


def inspect_file(path: Path) -> dict:
    rec = {
        "path": str(path),
        "original_name": path.name,
        "bytes": path.stat().st_size,
        "hash": sha256_file(path),
        "generic_name": is_generic_name(path.stem),
    }
    if path.suffix.lower() == ".svg":
        w, h = svg_dimensions(path)
        rec.update(format="svg", width=w, height=h,
                   orientation=orientation(w, h), has_alpha=True,
                   animated=False, guessed_type="vector")
        return rec
    try:
        with Image.open(path) as img:
            img = ImageOps.exif_transpose(img)
            w, h = img.size
            has_alpha = (img.mode in ("RGBA", "LA", "PA")
                         or (img.mode == "P" and "transparency" in img.info))
            animated = getattr(img, "is_animated", False)
            rec.update(
                format=(img.format or path.suffix.lstrip(".")).lower(),
                width=w, height=h,
                orientation=orientation(w, h),
                has_alpha=bool(has_alpha),
                animated=bool(animated),
                guessed_type="photo" if animated
                else classify_raster(img, w, h, has_alpha),
            )
    except Exception as e:
        rec["error"] = f"No se pudo abrir: {e}"
    return rec


def orientation(w, h):
    if not w or not h:
        return None
    if w == h:
        return "square"
    return "landscape" if w > h else "portrait"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inputs", nargs="+", help="carpetas, archivos o ZIPs")
    ap.add_argument("--out", default="pipeline-work", help="directorio de trabajo")
    args = ap.parse_args()

    workdir = Path(args.out)
    workdir.mkdir(parents=True, exist_ok=True)
    files = collect_files(args.inputs, workdir)
    if not files:
        print("ERROR: no se encontraron imágenes en las rutas dadas.", file=sys.stderr)
        sys.exit(1)

    records = [inspect_file(f) for f in files]

    # Duplicados exactos por hash
    seen = {}
    for r in records:
        if "error" in r:
            continue
        if r["hash"] in seen:
            r["duplicate_of"] = seen[r["hash"]]
        else:
            seen[r["hash"]] = r["path"]

    inventory = {"count": len(records), "assets": records}
    save_json(workdir / "inventory.json", inventory)

    dups = sum(1 for r in records if r.get("duplicate_of"))
    errs = sum(1 for r in records if r.get("error"))
    generic = sum(1 for r in records if r.get("generic_name"))
    print(f"Inventario: {len(records)} archivos | {dups} duplicados | "
          f"{generic} con nombre genérico | {errs} con error")
    print(f"Guardado en {workdir / 'inventory.json'}")


if __name__ == "__main__":
    main()
