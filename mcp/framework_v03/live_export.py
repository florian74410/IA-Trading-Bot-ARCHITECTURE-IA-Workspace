"""Read-only snapshot of the currently published Architecture site.

Use solely within an authenticated MCP connection. No shell, no Git, no
privilege escalation and no data from DEBUG/RELEASE. ZIP is returned as
base64 in the tool result (bounded for small static sites).
"""
from __future__ import annotations
import base64
import hashlib
import io
import os
import stat
import zipfile
from pathlib import Path

PUBLISHED_SITE = Path("/srv/iatb-architecture/site")
MAX_FILES = 100
MAX_FILE = 1_000_000
MAX_TOTAL = 4_000_000
MAX_ARCHIVE = 3_000_000


class ExportDenied(ValueError):
    pass


def export_published_site(root: Path = PUBLISHED_SITE) -> dict:
    root = Path(root)
    # Ensure the configured root itself is not a symlink.
    if root.is_symlink() or not root.is_dir():
        raise ExportDenied("Published site root unavailable")
    paths = []
    for base, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if not (Path(base) / d).is_symlink())
        for name in sorted(files):
            p = Path(base) / name
            if p.is_symlink():
                raise ExportDenied("Symlink in published site")
            paths.append(p.relative_to(root).as_posix())
            if len(paths) > MAX_FILES:
                raise ExportDenied("Too many site files")
    if "index.html" not in paths:
        raise ExportDenied("Not an Architecture static site")
    data = io.BytesIO()
    total = 0
    # Descriptor-relative operations prevent a symlink swapped during enumeration
    # from redirecting reads outside the original directory.
    rootfd = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        with zipfile.ZipFile(data, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for rel in paths:
                parts = rel.split("/")
                dirfd = rootfd
                try:
                    for name in parts[:-1]:
                        nextfd = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=dirfd)
                        if dirfd != rootfd:
                            os.close(dirfd)
                        dirfd = nextfd
                    fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=dirfd)
                    try:
                        info = os.fstat(fd)
                        if not stat.S_ISREG(info.st_mode) or info.st_size > MAX_FILE:
                            raise ExportDenied("Invalid or oversized file")
                        content = os.read(fd, MAX_FILE + 1)
                        if len(content) > MAX_FILE:
                            raise ExportDenied("Oversized file")
                    finally:
                        os.close(fd)
                finally:
                    if dirfd != rootfd:
                        os.close(dirfd)
                total += len(content)
                if total > MAX_TOTAL:
                    raise ExportDenied("Site export exceeds size limit")
                archive.writestr(rel, content)
    finally:
        os.close(rootfd)
    payload = data.getvalue()
    if len(payload) > MAX_ARCHIVE:
        raise ExportDenied("ZIP exceeds MCP output limit")
    return {
        "filename": "architecture-gen1-published.zip",
        "encoding": "base64",
        "sha256": hashlib.sha256(payload).hexdigest(),
        "file_count": len(paths),
        "uncompressed_bytes": total,
        "zip_bytes": len(payload),
        "archive_b64": base64.b64encode(payload).decode("ascii"),
        "source": "published-vps-site",
    }
