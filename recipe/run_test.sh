#!/bin/bash
set -exu

export PETSC_DIR=${PREFIX}

# this seems to significantly improve performance for mpich
# on CI, at least
export FI_PROVIDER=tcp

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
    # in 'real' installs, libnvidia-ml is part of the cuda driver,
    # not distributed by conda-forge.
    # Stage the stub into place or we'll get DLL not found
    cp $PREFIX/lib/stubs/libnvidia-ml.so $PREFIX/lib/libnvidia-ml.so.1
    ./testdlopen
else
    make ex1
    make ex1f

    make runex1 MPIEXEC=mpiexec
    make runex1f MPIEXEC=mpiexec
fi
