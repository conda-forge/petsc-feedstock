"""Normalize PETSc metadata; leave dependency-owned files untouched.

Keep the host prefix as a normal Windows path so rattler-build can relocate it
when installing the package. Source/build paths must not survive packaging.
"""
import os
import shutil
from pathlib import Path

prefix = Path(os.environ["PREFIX"])
root = prefix / "Library"
source = Path(os.environ["SRC_DIR"])
build = Path(os.environ["BUILD_PREFIX"])
# Preserve the generated import library for make/pkg-config consumers that
# explicitly link PETSc's external BLAS/LAPACK dependencies.
openblas = root / "lib/petsc/openblas.lib"
shutil.copyfile(source / "openblas.lib", openblas)


def spellings(path):
    forward = path.as_posix()
    backward = forward.replace("/", "\\")
    return sorted({forward, backward, backward.replace("\\", "\\\\")}, key=len, reverse=True)


# Only PETSc owns these directories and headers in the host environment.
files = list((root / "include").glob("petsc*.h"))
for directory in (root / "include/petsc", root / "lib/petsc", root / "share/petsc"):
    files.extend(p for p in directory.rglob("*") if p.is_file())
files.append(root / "lib/pkgconfig/PETSc.pc")

replacements = {old: openblas.as_posix() for old in spellings(source / "openblas.lib")}
for spelling in spellings(source):
    replacements[spelling] = root.as_posix()
for spelling in spellings(build / "python.exe"):
    replacements[spelling] = "python"
for directory in (build / "Library/usr/bin", build / "Library/bin", build / "Scripts", build / "bin"):
    for spelling in spellings(directory):
        for separator in ("/", "\\"):
            replacements[spelling + separator] = ""
for spelling in spellings(build):
    replacements[spelling] = prefix.as_posix()
for spelling in spellings(prefix):
    replacements[spelling] = prefix.as_posix()
replacements = sorted(replacements.items(), key=lambda item: len(item[0]), reverse=True)

for path in files:
    data = path.read_bytes()
    if b"\0" in data:
        continue
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        continue
    for old, new in replacements:
        text = text.replace(old, new)
    if path.name == "PETSc.pc":
        lines = []
        for line in text.splitlines():
            key = line.split("=", 1)[0]
            values = {
                "prefix": "${pcfiledir}/../..",
                "exec_prefix": "${prefix}",
                "includedir": "${prefix}/include",
                "libdir": "${prefix}/lib",
                "ccompiler": "cl",
                "cxxcompiler": "cl",
                "mpiexec": "mpiexec.exe -localonly",
            }
            if key in values:
                line = key + "=" + values[key]
            elif line.startswith("Cflags:"):
                line += " -Zc:preprocessor"
            elif line.startswith("Libs.private:"):
                # Use resolvable import libraries for --static consumers too.
                line = ("Libs.private: -L${libdir}/petsc -lopenblas -limpi "
                        "-lGdi32 -lUser32 -lAdvapi32 -lKernel32 -lWs2_32")
            lines.append(line)
        text = "\n".join(lines) + "\n"
    for path_root in (source, build):
        if any(value in text for value in spellings(path_root)):
            raise RuntimeError(f"Build path remains in {path}")
    if text.encode("utf-8") != data:
        path.write_text(text, encoding="utf-8", newline="\n")
