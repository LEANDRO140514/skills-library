#!/usr/bin/env python3
"""Procesa las imágenes del inventario según names.json y pipeline.config.json.

- Renombra con nombres semánticos (slug en minúsculas con guiones).
- Convierte fotografías a WebP con calidad configurable.
- Gráficos/logos/íconos raster -> WebP lossless (conserva transparencia).
- SVG se copia tal cual.
- Genera tamaños responsivos SIN ampliar nunca la imagen original.
- Genera thumbnail opcional.
- Omite duplicados exactos (los mapea al asset original).

Salida: dist/<categoria>/<nombre>-w<ancho>.webp  +  processed.json  +
reports/optimization-report.md

Uso:
    python process_images.py --work <workdir>
Requiere en <workdir>: inventory.json, names.json, pipeline.config.json (opcional)
"""
import argparse
import shutil
from pathlib import Path

from PIL import Image, ImageOps
from common import human_size, load_json, save_json, sha256_file, slugify

Image.MAX_IMAGE_PIXELS = 300_000_000

DEFAULT_CONFIG = {
    "mode": "optimize",              # optimize | optimize-and-publish
    "widths": [1920, 1200, 800, 400],
    "thumbnail_width": 320,           # null para desactivar
    "quality": 82,                    # calidad WebP para fotografías
    "max_width": 2560,                # tope superior del tamaño principal
    "base_prefix": "images",          # prefijo de ruta en el storage
    "provider": None,
}


def load_config(workdir: Path) -> dict:
    cfg = dict(DEFAULT_CONFIG)
    cfg_path = workdir / "pipeline.config.json"
    if cfg_path.exists():
        cfg.update(load_json(cfg_path))
    return cfg


def target_widths(orig_w: int, cfg: dict):
    """Anchos responsivos <= ancho original. Nunca ampliar."""
    cap = min(orig_w, cfg["max_width"])
    widths = sorted({w for w in cfg["widths"] if w <= cap}, reverse=True)
    if not widths or widths[0] < cap:
        widths.insert(0, cap)
    return widths


def save_variant(img: Image.Image, dest: Path, width: int, is_photo: bool,
                 quality: int) -> dict:
    ratio = width / img.width
    out = img if ratio == 1 else img.resize(
        (width, max(1, round(img.height * ratio))), Image.LANCZOS)
    dest.parent.mkdir(parents=True, exist_ok=True)
    if is_photo:
        out.save(dest, "WEBP", quality=quality, method=6)
    else:
        out.save(dest, "WEBP", lossless=True, quality=100, method=6)
    return {"width": out.width, "height": out.height,
            "path": str(dest), "bytes": dest.stat().st_size, "format": "webp"}


def process_asset(rec: dict, meta: dict, cfg: dict, dist: Path) -> dict:
    src = Path(rec["path"])
    name = slugify(meta["name"])
    category = slugify(meta.get("category", "general"))
    a_type = meta.get("type", rec.get("guessed_type", "photo"))
    out_dir = dist / category

    asset = {
        "id": name, "name": name, "category": category, "type": a_type,
        "alt": meta.get("alt", ""), "original_name": rec["original_name"],
        "original_bytes": rec["bytes"], "original_format": rec.get("format"),
        "width": rec.get("width"), "height": rec.get("height"),
        "orientation": rec.get("orientation"), "has_alpha": rec.get("has_alpha"),
        "hash": rec["hash"], "variants": [], "thumbnail": None,
        "status": "processed",
    }

    # SVG: copiar tal cual
    if rec.get("format") == "svg":
        dest = out_dir / f"{name}.svg"
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)
        asset["variants"].append({"width": rec.get("width"),
                                  "height": rec.get("height"),
                                  "path": str(dest),
                                  "bytes": dest.stat().st_size,
                                  "format": "svg"})
        return asset

    with Image.open(src) as img:
        img = ImageOps.exif_transpose(img)

        # Animados: convertir a WebP animado sin redimensionar
        if getattr(img, "is_animated", False):
            dest = out_dir / f"{name}.webp"
            dest.parent.mkdir(parents=True, exist_ok=True)
            img.save(dest, "WEBP", save_all=True, quality=cfg["quality"],
                     method=4)
            asset["variants"].append({"width": img.width, "height": img.height,
                                      "path": str(dest),
                                      "bytes": dest.stat().st_size,
                                      "format": "webp", "animated": True})
            return asset

        # Conservar transparencia; normalizar modo
        if rec.get("has_alpha"):
            img = img.convert("RGBA")
        else:
            img = img.convert("RGB")

        is_photo = a_type == "photo"
        for w in target_widths(img.width, cfg):
            dest = out_dir / f"{name}-w{w}.webp"
            v = save_variant(img, dest, w, is_photo, cfg["quality"])
            asset["variants"].append(v)

        tw = cfg.get("thumbnail_width")
        if tw and img.width > tw:
            dest = out_dir / f"{name}-thumb.webp"
            asset["thumbnail"] = save_variant(img, dest, tw, is_photo,
                                              cfg["quality"])
    return asset


def write_report(assets, skipped_dups, errors, workdir: Path):
    lines = ["# Reporte de optimización\n"]
    total_in = sum(a["original_bytes"] for a in assets)
    total_out = sum(v["bytes"] for a in assets for v in a["variants"])
    lines.append(f"- Assets procesados: **{len(assets)}**")
    lines.append(f"- Duplicados omitidos: **{len(skipped_dups)}**")
    lines.append(f"- Errores: **{len(errors)}**")
    lines.append(f"- Peso original total: **{human_size(total_in)}**")
    lines.append(f"- Peso optimizado total (todas las variantes): "
                 f"**{human_size(total_out)}**\n")
    lines.append("| Asset | Original | Variante principal | Ahorro |")
    lines.append("|---|---|---|---|")
    for a in assets:
        main = a["variants"][0]
        saving = (1 - main["bytes"] / a["original_bytes"]) * 100 \
            if a["original_bytes"] else 0
        lines.append(f"| {a['name']} ({a['category']}) | "
                     f"{human_size(a['original_bytes'])} "
                     f"({a['original_format']}) | "
                     f"{human_size(main['bytes'])} ({main['format']}, "
                     f"{main['width']}px) | {saving:.0f}% |")
    if skipped_dups:
        lines.append("\n## Duplicados omitidos")
        for d in skipped_dups:
            lines.append(f"- `{d['original_name']}` es idéntico a "
                         f"`{d['duplicate_of']}`")
    if errors:
        lines.append("\n## Errores")
        for e in errors:
            lines.append(f"- `{e['original_name']}`: {e['error']}")
    path = workdir / "reports" / "optimization-report.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


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
        assets.append(process_asset(rec, meta, cfg, dist))

    # Verificar colisiones de nombre final
    seen = {}
    for a in assets:
        key = (a["category"], a["name"])
        if key in seen:
            raise SystemExit(f"ERROR: nombre duplicado '{a['name']}' en "
                             f"categoría '{a['category']}' "
                             f"({a['original_name']} y {seen[key]}). "
                             "Corrige names.json.")
        seen[key] = a["original_name"]

    save_json(workdir / "processed.json",
              {"config": cfg, "assets": assets,
               "duplicates": [{"original_name": d["original_name"],
                               "duplicate_of": d["duplicate_of"]}
                              for d in skipped],
               "errors": [{"original_name": e.get("original_name"),
                           "error": e.get("error")} for e in errors]})
    report = write_report(assets, skipped, errors, workdir)
    print(f"Procesados {len(assets)} assets -> {dist}")
    print(f"Reporte: {report}")


if __name__ == "__main__":
    main()
