#!/bin/bash
set -e

if [[ "$MPI_VARIANT" == "mpich" ]]; then
    export HYDRA_LAUNCHER=fork
elif [[ "$MPI_VARIANT" == "openmpi" ]]; then
    export OMPI_MCA_plm=isolated
    export OMPI_MCA_rmaps_base_oversubscribe=yes
    export OMPI_MCA_btl_vader_single_copy_mechanism=none
    mpiexec_args=--allow-run-as-root
fi

mpiexec $mpiexec_args $@ 2>&1 </dev/null | cat
