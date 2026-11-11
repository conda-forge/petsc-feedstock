"""Reject stale build paths in the installed PETSc headers and metadata."""
import os
from pathlib import Path
import re
import sys

prefix = Path(sys.argv[1])
root = prefix / "Library"
metadata = [root / "lib/pkgconfig/PETSc.pc", root / "lib/petsc", root / "share/petsc"]
files = list((root / "include").glob("petsc*.h"))
for path in metadata:
    if not path.exists():
        raise RuntimeError(f"Missing installed metadata: {path}")
    files.extend([path] if path.is_file() else (p for p in path.rglob("*") if p.is_file()))
patterns = [
    r"(?i)/cygdrive/[^\r\n]*(?:[/\\](?:bld|build(?:_env)?|src|source|work|h_env)(?:[/\\]|$))",
    r"(?i)[A-Z]:[/\\][^\r\n]*[/\\](?:bld|build(?:_env)?|src|source|work|h_env)(?:[/\\]|$)",
    r"(?i)/(?:home|opt|tmp)/[^\r\n]*/(?:bld|build(?:_env)?|src|source|work|h_env)(?:/|$)",
]
for name in ("SRC_DIR", "BUILD_PREFIX", "RECIPE_DIR", "WORK_DIR"):
    if os.environ.get(name):
        patterns.append(re.escape(os.environ[name]))
current = {str(prefix), prefix.as_posix(), str(prefix).replace("\\", "\\\\")}
leaks = []
for path in files:
    data = path.read_bytes()
    if b"\0" in data:
        continue
    text = data.decode("utf-8", errors="replace")
    for value in sorted(current, key=len, reverse=True):
        text = text.replace(value, "${PREFIX}")
    if any(re.search(pattern, text) for pattern in patterns):
        leaks.append(str(path))
if leaks:
    raise RuntimeError("Build paths remain in:\n" + "\n".join(leaks))
print("Installed PETSc metadata contains no stale build paths")
