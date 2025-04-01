#!/bin/bash
set -exu

export PETSC_DIR=${PREFIX}

pkg-config --validate PETSc
pkg-config --cflags PETSc | grep -v isystem
pkg-config --libs PETSc

# show petscvariables, etc.
cat $PREFIX/lib/petsc/conf/petscvariables

cd tests

# There are so many hiccups when compiling with cuda
# on the CI testing machines that we only test for
# dynamic loading
if [[ "${cuda_compiler_version}" != "None" ]]; then
    make testdlopen
    # aarch64 failing tests
    # ./testdlopen: /lib64/libm.so.6: version `GLIBC_2.27' not found (required by $PREFIX/lib/./libcurand.so.10)
    if [[ "${target_platform}" != "linux-aarch64" ]]; then
        ./testdlopen
    fi
else
    make ex1
    make ex1f

    make runex1 MPIEXEC=mpiexec
    make runex1f MPIEXEC=mpiexec
fi
