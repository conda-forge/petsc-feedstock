#!/bin/bash
set -e

export PETSC_DIR=${PREFIX}
cd tests
make ex1
make ex1f

# FIXME: Workaround mpiexec setting O_NONBLOCK in std{in|out|err}
# See https://github.com/conda-forge/conda-smithy/pull/337
# See https://github.com/pmodels/mpich/pull/2755
make runex1  MPIEXEC="${RECIPE_DIR}/mpiexec.sh"
make runex1f MPIEXEC="${RECIPE_DIR}/mpiexec.sh"
