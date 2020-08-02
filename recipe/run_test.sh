#!/bin/bash
set -e

# Fix gethostbyname() issues in Azure Pipelines
if [[ $(uname) == Darwin ]]; then
    export HYDRA_IFACE=lo0
fi

export PETSC_DIR=${PREFIX}

pkg-config --cflags PETSc | grep -v isystem

cd tests
make ex1
make ex1f

# FIXME: Workaround mpiexec setting O_NONBLOCK in std{in|out|err}
# See https://github.com/conda-forge/conda-smithy/pull/337
# See https://github.com/pmodels/mpich/pull/2755
make runex1  MPIEXEC="${RECIPE_DIR}/mpiexec.sh"
make runex1f MPIEXEC="${RECIPE_DIR}/mpiexec.sh"
