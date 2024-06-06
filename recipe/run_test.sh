#!/bin/bash
set -ex

export PETSC_DIR=${PREFIX}

pkg-config --cflags PETSc | grep -v isystem

cd tests

# There are so many hiccups when compiling with cuda
# on the CI testing machines that we only test for
# dynamic loading
if [[ -n "$CUDA_CONDA_TARGET_NAME" ]]; then
    make testdlopen
    # aarch64 failing tests
    # ./testdlopen: /lib64/libm.so.6: version `GLIBC_2.27' not found (required by $PREFIX/lib/./libcurand.so.10)
    if [[ "$CUDA_CONDA_TARGET_NAME" != "sbsa-linux" ]]; then
        ./testdlopen
    fi
else
    make ex1
    make ex1f

    make runex1 MPIEXEC=mpiexec
    make runex1f MPIEXEC=mpiexec
fi
