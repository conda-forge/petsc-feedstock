#!/usr/bin/env bash
# Windows PETSc build: native python + m2-bash + win32fe(MSVC) + Intel MPI + OpenBLAS.
set -euo pipefail

source_dir="${SRC_DIR:?SRC_DIR is not set}"
prefix="${PREFIX:?PREFIX is not set}"
build_prefix="${BUILD_PREFIX:?BUILD_PREFIX is not set}"

# rattler-build hands us backslash paths; everything downstream wants forward slashes
source_dir="${source_dir//\\//}"
prefix="${prefix//\\//}"
build_prefix="${build_prefix//\\//}"

# Native Python and MSYS2 tools must share a predictable temporary directory.
# GitHub runners otherwise use an 8.3 user-profile path on a different drive;
# Keep PETSc's file creation and MSYS2's in-place edits in the build tree.
configure_tmp="$source_dir/.petsc-tmp"
mkdir -p "$configure_tmp"
export TMPDIR="$configure_tmp" TEMP="$configure_tmp" TMP="$configure_tmp"
echo "configure_tmp=$configure_tmp"

# conda Windows layout: package files live under <PREFIX>/Library
libprefix="$prefix/Library"
mpi_include="$libprefix/include"
mpi_lib="$libprefix/lib"
mpi_exec="$libprefix/bin/mpiexec.exe"
cpu_count="${CPU_COUNT:-4}"

echo "source_dir=$source_dir"
echo "libprefix=$libprefix"

for path in \
  "$mpi_include/mpi.h" \
  "$mpi_lib/impi.lib" \
  "$mpi_exec" \
  "$libprefix/bin/openblas.dll"; do
  test -f "$path" || { echo "Missing Windows PETSc input: $path" >&2; exit 1; }
done

cd "$source_dir"
export PETSC_DIR="$source_dir"
export PETSC_ARCH=arch-conda-win64
export PATH="$libprefix/bin:$libprefix/lib:$PATH"
export OPENBLAS_NUM_THREADS=1

# --- OpenBLAS import library (package ships only the DLL) ---
python - "$libprefix/bin/openblas.dll" > openblas.def <<'PY'
import re, subprocess, sys
out = subprocess.check_output(["dumpbin", "/exports", sys.argv[1]], text=True)
syms = re.findall(r"^\s*\d+\s+[0-9A-Fa-f]+\s+[0-9A-Fa-f]+\s+(\S+)\s*$", out, re.M)
print("EXPORTS")
print("\n".join(syms))
PY
lib /nologo /def:openblas.def /machine:x64 /out:openblas.lib

# --- configure via the win32fe wrappers ---
python ./configure \
  --with-cc="$PETSC_DIR/lib/petsc/bin/win32fe/win32fe.exe cl" \
  --with-ar="$PETSC_DIR/lib/petsc/bin/win32fe/win32fe.exe lib" \
  --with-ranlib="$build_prefix/Library/usr/bin/true.exe" \
  --with-cxx=0 \
  --with-fc=0 \
  --with-debugging=0 \
  --COPTFLAGS="-O2" \
  --with-shared-libraries=1 \
  --with-scalar-type=real \
  --with-64-bit-indices=0 \
  --with-mpi=1 \
  --with-mpi-include="$mpi_include" \
  --with-mpi-lib="$mpi_lib/impi.lib" \
  --with-mpiexec="$mpi_exec -localonly" \
  --with-blaslapack-lib="$source_dir/openblas.lib" \
  --with-cuda=0 \
  --with-hdf5=0 \
  --with-fftw=0 \
  --with-x=0 \
  --with-ssl=0 \
  --prefix="$libprefix" || { cat configure.log; exit 1; }

# msys sh eats backslashes in make recipes/lists; normalize separators
confdir="$PETSC_DIR/$PETSC_ARCH/lib/petsc/conf"
(cd "$PETSC_DIR" && PETSC_ARCH="$PETSC_ARCH" python config/gmakegen.py)
sed -i 's|\\|/|g' "$confdir/petscvariables" "$confdir/petscrules" "$confdir/files"

make MAKE_NP="$cpu_count"
make install

# --- packaging layout: DLL belongs in bin ---
mkdir -p "$libprefix/bin"
test -f "$libprefix/lib/libpetsc.dll"
mv "$libprefix/lib/libpetsc.dll" "$libprefix/bin/libpetsc.dll"
# setuptools resolves -lpetsc to petsc.lib on Windows.
cp "$libprefix/lib/libpetsc.lib" "$libprefix/lib/petsc.lib"

# Remove build-only files before normalizing PETSc's installed metadata.
rm -f "$libprefix/lib/petsc/conf/configure-hash"
find "$libprefix/lib/petsc" -name '*.pyc' -delete
rm -rf "$libprefix/share/petsc/examples/src" "$libprefix/share/petsc/datafiles"
python "$RECIPE_DIR/fix_windows_metadata.py"

test -f "$libprefix/include/petsc.h"
test -f "$libprefix/lib/libpetsc.lib"
test -f "$libprefix/bin/libpetsc.dll"
test -f "$libprefix/lib/pkgconfig/PETSc.pc"
echo "Windows PETSc package layout and metadata checks passed"
