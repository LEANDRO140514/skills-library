"""Utilidades compartidas del pipeline de imágenes."""
import hashlib
import json
import re
import unicodedata
from pathlib import Path

IMG_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp",
            ".tiff", ".tif", ".avif", ".svg"}

GENERIC_NAME_RE = re.compile(
    r"^(img|image|imagen|photo|foto|pic|picture|screenshot|captura|"
    r"vid|video|clip|movie|mvi|rec|grabacion|"
    r"untitled|sin.?titulo|final|copia|copy|dsc|dcim|whatsapp)"
    r"[\s_\-]*\d*$|^\d+$|final[\s_\-]*final",
    re.IGNORECASE,
)


def slugify(text: str) -> str:
    """minúsculas, sin acentos, guiones, sin caracteres especiales."""
    text = unicodedata.normalize("NFKD", text)
    text = text.encode("ascii", "ignore").decode("ascii")
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-") or "asset"


def camel_case(slug: str) -> str:
    parts = [p for p in slug.split("-") if p]
    if not parts:
        return "asset"
    key = parts[0] + "".join(p.capitalize() for p in parts[1:])
    if key[0].isdigit():
        key = "_" + key
    return key


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def is_generic_name(stem: str) -> bool:
    return bool(GENERIC_NAME_RE.search(stem.strip()))


def load_json(path) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save_json(path, data) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def human_size(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{n} B"
        n /= 1024
    return f"{n} B"
