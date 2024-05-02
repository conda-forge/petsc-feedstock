#!/bin/bash
set -ex

# Fix gethostbyname() issues in Azure Pipelines
if [[ $(uname) == Darwin ]]; then
    export HYDRA_IFACE=lo0
fi

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

    # FIXME: Workaround mpiexec setting O_NONBLOCK in std{in|out|err}
    # See https://github.com/conda-forge/conda-smithy/pull/337
    # See https://github.com/pmodels/mpich/pull/2755
    make runex1 MPIEXEC="${RECIPE_DIR}/mpiexec.sh"
    make runex1f MPIEXEC="${RECIPE_DIR}/mpiexec.sh"
fi
