#!/bin/bash
set -e

export PETSC_DIR=${PREFIX}
cd "src/snes/examples/tests"
make ex1
make ex1f

make runex1  MPIEXEC="${RECIPE_DIR}/mpiexec.sh"
make runex1f MPIEXEC="${RECIPE_DIR}/mpiexec.sh"
