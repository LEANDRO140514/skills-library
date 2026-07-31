#!/usr/bin/env python3
"""Publica los archivos de dist/ al proveedor configurado y anota las URLs.

Proveedores soportados (config "provider" en pipeline.config.json):
- "s3"          : Amazon S3, Cloudflare R2, InsForge/MinIO o cualquier endpoint
                  S3-compatible (incluye el endpoint S3 de Supabase). Requiere boto3.
- "supabase"    : Supabase Storage vía REST (sin boto3).
- "vercel-blob" : Vercel Blob vía REST.

Variables de entorno por proveedor (ver references/providers.md):
  s3          -> S3_BUCKET, S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY,
                 S3_PUBLIC_BASE_URL, [S3_ENDPOINT], [S3_REGION]
  supabase    -> SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_BUCKET
  vercel-blob -> BLOB_READ_WRITE_TOKEN

Estructura general en el storage (no por proyecto):
  {base_prefix}/{categoria}/{archivo}

Si faltan credenciales: NO inventa URLs. Marca todo como not-published,
deja url en null y escribe en el reporte exactamente qué falta.
"""
import argparse
import mimetypes
import os
from pathlib import Path

from common import load_json, save_json

CONTENT_TYPES = {".webp": "image/webp", ".svg": "image/svg+xml",
                 ".png": "image/png", ".jpg": "image/jpeg",
                 ".avif": "image/avif", ".gif": "image/gif"}
CACHE_CONTROL = "public, max-age=31536000, immutable"

REQUIRED_ENV = {
    "s3": ["S3_BUCKET", "S3_ACCESS_KEY_ID", "S3_SECRET_ACCESS_KEY",
           "S3_PUBLIC_BASE_URL"],
    "supabase": ["SUPABASE_URL", "SUPABASE_SERVICE_KEY", "SUPABASE_BUCKET"],
    "vercel-blob": ["BLOB_READ_WRITE_TOKEN"],
}


def content_type(path: Path) -> str:
    return CONTENT_TYPES.get(path.suffix.lower()) or \
        mimetypes.guess_type(str(path))[0] or "application/octet-stream"


def storage_key(prefix: str, category: str, filename: str) -> str:
    return "/".join(p for p in [prefix.strip("/"), category, filename] if p)


class S3Uploader:
    def __init__(self):
        import boto3  # instalar con: pip install boto3 --break-system-packages
        kwargs = {
            "aws_access_key_id": os.environ["S3_ACCESS_KEY_ID"],
            "aws_secret_access_key": os.environ["S3_SECRET_ACCESS_KEY"],
            "region_name": os.environ.get("S3_REGION", "auto"),
        }
        endpoint = os.environ.get("S3_ENDPOINT")
        if endpoint:
            kwargs["endpoint_url"] = endpoint
        self.client = boto3.client("s3", **kwargs)
        self.bucket = os.environ["S3_BUCKET"]
        self.base = os.environ["S3_PUBLIC_BASE_URL"].rstrip("/")

    def upload(self, path: Path, key: str) -> str:
        self.client.upload_file(
            str(path), self.bucket, key,
            ExtraArgs={"ContentType": content_type(path),
                       "CacheControl": CACHE_CONTROL})
        return f"{self.base}/{key}"


class SupabaseUploader:
    def __init__(self):
        import requests
        self.requests = requests
        self.url = os.environ["SUPABASE_URL"].rstrip("/")
        self.key = os.environ["SUPABASE_SERVICE_KEY"]
        self.bucket = os.environ["SUPABASE_BUCKET"]

    def upload(self, path: Path, key: str) -> str:
        r = self.requests.post(
            f"{self.url}/storage/v1/object/{self.bucket}/{key}",
            headers={"Authorization": f"Bearer {self.key}",
                     "Content-Type": content_type(path),
                     "Cache-Control": CACHE_CONTROL,
                     "x-upsert": "true"},
            data=path.read_bytes(), timeout=120)
        r.raise_for_status()
        return f"{self.url}/storage/v1/object/public/{self.bucket}/{key}"


class VercelBlobUploader:
    def __init__(self):
        import requests
        self.requests = requests
        self.token = os.environ["BLOB_READ_WRITE_TOKEN"]

    def upload(self, path: Path, key: str) -> str:
        r = self.requests.put(
            f"https://blob.vercel-storage.com/{key}",
            headers={"Authorization": f"Bearer {self.token}",
                     "Content-Type": content_type(path),
                     "x-api-version": "7",
                     "x-cache-control-max-age": "31536000",
                     "x-add-random-suffix": "0"},
            data=path.read_bytes(), timeout=120)
        r.raise_for_status()
        return r.json()["url"]


UPLOADERS = {"s3": S3Uploader, "supabase": SupabaseUploader,
             "vercel-blob": VercelBlobUploader}


def mark_not_published(data: dict, missing: list, provider, workdir: Path):
    for a in data["assets"]:
        a["status"] = "not-published"
        for v in a["variants"]:
            v["url"] = None
        if a.get("thumbnail"):
            a["thumbnail"]["url"] = None
    save_json(workdir / "processed.json", data)
    if provider:
        print(f"NO PUBLICADO: faltan variables de entorno para "
              f"'{provider}': {', '.join(missing)}")
    else:
        print("NO PUBLICADO: no hay proveedor configurado "
              "(campo 'provider' en pipeline.config.json). "
              "Opciones: s3 | supabase | vercel-blob")
    print("Los manifiestos se generarán con url: null.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default="pipeline-work")
    args = ap.parse_args()
    workdir = Path(args.work)
    data = load_json(workdir / "processed.json")
    cfg = data["config"]
    live_cfg = workdir / "pipeline.config.json"
    if live_cfg.exists():
        cfg.update(load_json(live_cfg))
        data["config"] = cfg
    provider = cfg.get("provider")

    missing = [v for v in REQUIRED_ENV.get(provider, [])
               if not os.environ.get(v)] if provider else []
    if not provider or missing:
        mark_not_published(data, missing, provider, workdir)
        return

    uploader = UPLOADERS[provider]()
    prefix = cfg.get("base_prefix", "images")
    ok = failed = 0

    def push(entry, category):
        nonlocal ok, failed
        path = Path(entry["path"])
        key = storage_key(prefix, category, path.name)
        try:
            entry["url"] = uploader.upload(path, key)
            entry["storage_key"] = key
            ok += 1
        except Exception as e:
            entry["url"] = None
            entry["publish_error"] = str(e)
            failed += 1
            print(f"ERROR subiendo {path.name}: {e}")

    for a in data["assets"]:
        for v in a["variants"]:
            push(v, a["category"])
        if a.get("thumbnail"):
            push(a["thumbnail"], a["category"])
        a["status"] = "published" if all(v.get("url") for v in a["variants"]) \
            else "publish-failed"
        a["provider"] = provider

    save_json(workdir / "processed.json", data)
    print(f"Publicación: {ok} archivos subidos, {failed} fallidos "
          f"(proveedor: {provider})")
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
