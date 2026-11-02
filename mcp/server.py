"""IA-TB Architecture MCP: local-only development workspace.
No shell execution, no deployment, no access to production directories.
"""
from __future__ import annotations
import os
from pathlib import Path
from mcp.server.fastmcp import FastMCP

ROOT = Path(os.environ.get("IATB_ARCH_WORKSPACE", "/srv/iatb-architecture/workspace")).resolve(strict=True)
SITE = (ROOT / "site").resolve(strict=True)
if SITE != ROOT / "site" or not SITE.is_dir():
    raise RuntimeError("Invalid isolated site workspace")
mcp = FastMCP("IA-TB Architecture Workspace", host="127.0.0.1", port=8810)
MAX_BYTES = 512 * 1024

def safe_file(relative_path: str) -> Path:
    if not relative_path or relative_path.startswith("/"):
        raise ValueError("Relative path required")
    path = SITE / relative_path
    resolved = path.resolve(strict=False)
    if not resolved.is_relative_to(SITE) or resolved == SITE:
        raise ValueError("Path outside site workspace")
    # Deny symlinked path components, even if currently pointing inside workspace.
    current = SITE
    for part in Path(relative_path).parts:
        if part in ("..", "."):
            raise ValueError("Parent/dot paths are forbidden")
        current = current / part
        if current.is_symlink():
            raise ValueError("Symlinks are forbidden")
    return resolved

@mcp.tool()
def architecture_list_files() -> list[str]:
    """List site files in the isolated development workspace."""
    result = []
    for p in SITE.rglob("*"):
        if p.is_file() and not p.is_symlink():
            if len(result) >= 500:
                break
            result.append(p.relative_to(SITE).as_posix())
    return sorted(result)

@mcp.tool()
def architecture_read_file(path: str) -> str:
    """Read a UTF-8 site file from the isolated workspace."""
    f = safe_file(path)
    if not f.is_file() or f.stat().st_size > MAX_BYTES:
        raise ValueError("Not a file or file too large")
    return f.read_text(encoding="utf-8")

@mcp.tool()
def architecture_write_file(path: str, content: str) -> str:
    """Write a UTF-8 file in the isolated workspace only; never publishes it."""
    f = safe_file(path)
    data = content.encode("utf-8")
    if len(data) > MAX_BYTES:
        raise ValueError("File too large")
    if not f.parent.is_dir():
        raise ValueError("Parent directory must already exist")
    if f.exists() and not f.is_file():
        raise ValueError("Not a regular file")
    # Use a temporary file and atomic replacement in the same directory.
    import tempfile
    with tempfile.NamedTemporaryFile(dir=f.parent, prefix=".mcp-", delete=False) as tmp:
        temp = Path(tmp.name)
        tmp.write(data)
    try:
        temp.chmod(0o600)
        temp.replace(f)
    finally:
        temp.unlink(missing_ok=True)
    return f"Workspace file updated: {f.relative_to(SITE)} (not deployed)"

if __name__ == "__main__":
    mcp.run(transport="streamable-http")
