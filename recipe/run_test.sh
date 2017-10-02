#!/bin/bash
set -e

export PETSC_DIR=${PREFIX}
cd "src/snes/examples/tests"
make ex1

# FIXME: make check prevents upload on CircleCI
# See https://github.com/conda-forge/conda-smithy/pull/337
if [[ $(uname) == Darwin ]]; then
    make runex1
fi
