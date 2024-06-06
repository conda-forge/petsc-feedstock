#!/bin/bash
set -ex

# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/gnuconfig/config.* .

export PETSC_DIR=$SRC_DIR
export PETSC_ARCH=arch-conda-c-opt

unset F90
unset F77
# unset CC
unset CXX
if [[ "$target_platform" == linux-* ]]; then
    export LDFLAGS="-pthread -fopenmp $LDFLAGS"
    export LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
    # --as-needed appears to cause problems with fortran compiler detection
    # due to missing libquadmath
    # unclear why required libs are stripped but still linked
    export FFLAGS="${FFLAGS:-} -Wl,--no-as-needed"
fi

# scrub debug-prefix-map args, which cause problems in pkg-config
export CFLAGS=$(echo ${CFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')
export CXXFLAGS=$(echo ${CXXFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')
export FFLAGS=$(echo ${FFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')

if [[ $mpi == "openmpi" ]]; then
  export LIBS="-Wl,-rpath,$PREFIX/lib -lmpi_mpifh -lgfortran"
elif [[ $mpi == "mpich" ]]; then
  export LIBS="-lmpifort -lgfortran"
fi

if [[ $mpi == "openmpi" ]]; then
  export OMPI_CC=$CC
  export OPAL_PREFIX=$PREFIX
fi

if [[ "$CONDA_BUILD_CROSS_COMPILATION" == "1" ]]; then
  extra_opts="--with-batch"
fi

if [[ "${cuda_compiler_version}" != "None" ]]; then
  if [[ -n "$CUDA_HOME" ]]; then # cuda 11.8
    # CUDA in $CUDA_HOME/targets/xxx
    cuda_dir=$CUDA_HOME
    # nvcc in the build stage is a script that adds
    # -ccbin ${CXX} if not provided, but ${CXX} from
    # the environment is not propagated inside PETSc's
    # configure. We will thus end up with running
    # $ /usr/local/cuda/bin/nvcc -ccbin empty_variable <other_options>
    # which will make PETSc configure fail with
    # an obscure message from nvcc
    # No such file or directory
    # nvcc fatal   : Failed to preprocess host compiler properties.
    cuda_c="--with-cudac=nvcc -ccbin mpicxx"
  else
    # CUDA in $PREFIX/targets/xxx
    cuda_dir=$PREFIX # cuda 12 and later
    # already providing ccbin in prepend flags
    cuda_c="--with-cudac=nvcc"
  fi
  export CUDA_CONDA_HOME=$cuda_dir
  cuda_incl=$cuda_dir/targets/$CUDA_CONDA_TARGET_NAME
  cuda_libs="--with-cuda-lib=-lcudart -lnvToolsExt -lcufft -lcublas -lcusparse -lcusolver -lcurand -lcuda"
  cuda_opts="--with-cuda=1 --with-cuda-include=$cuda_incl --with-cuda-arch=all-major"
else
  cuda_opts="--with-cuda=0"
fi

python ./configure \
  AR="${AR:-ar}" \
  CC="mpicc" \
  CXX="mpicxx" \
  FC="mpifort" \
  CFLAGS="$CFLAGS" \
  CPPFLAGS="$CPPFLAGS" \
  CXXFLAGS="$CXXFLAGS" \
  FFLAGS="$FFLAGS" \
  LDFLAGS="$LDFLAGS" \
  LIBS="$LIBS" \
  --COPTFLAGS=-O3 \
  --CXXOPTFLAGS=-O3 \
  --FOPTFLAGS=-O3 \
  --with-clib-autodetect=0 \
  --with-cxxlib-autodetect=0 \
  --with-fortranlib-autodetect=0 \
  --with-debugging=0 \
  --with-blas-lib=libblas${SHLIB_EXT} \
  --with-lapack-lib=liblapack${SHLIB_EXT} \
  --with-yaml=1 \
  --with-hdf5=1 \
  --with-fftw=1 \
  --with-hwloc=0 \
  --with-hypre=1 \
  --with-metis=1 \
  --with-mpi=1 \
  --with-mumps=1 \
  --with-parmetis=1 \
  --with-pthread=1 \
  --with-ptscotch=1 \
  --with-shared-libraries \
  --with-ssl=0 \
  --with-scalapack=1 \
  --with-superlu=1 \
  --with-superlu_dist=1 \
  --with-superlu_dist-include=$PREFIX/include/superlu-dist \
  --with-superlu_dist-lib=-lsuperlu_dist \
  --with-suitesparse=1 \
  --with-suitesparse-dir=$PREFIX \
  --with-x=0 \
  --with-scalar-type=${scalar} \
  "$cuda_c" \
  "$cuda_libs" \
  $cuda_opts \
  $extra_opts \
  --prefix=$PREFIX || (cat configure.log && exit 1)

# Verify that gcc_ext isn't linked
for f in $PETSC_ARCH/lib/petsc/conf/petscvariables $PETSC_ARCH/lib/pkgconfig/PETSc.pc; do
  if grep gcc_ext $f; then
    echo "gcc_ext found in $f"
    exit 1
  fi
done

sedinplace() {
  if [[ $(uname) == Darwin ]]; then
    sed -i "" "$@"
  else
    sed -i"" "$@"
  fi
}

# Remove abspath of ${BUILD_PREFIX}/bin/python
sedinplace "s%${BUILD_PREFIX}/bin/python%python%g" $PETSC_ARCH/include/petscconf.h
sedinplace "s%${BUILD_PREFIX}/bin/python%python%g" $PETSC_ARCH/lib/petsc/conf/petscvariables
sedinplace "s%${BUILD_PREFIX}/bin/python%/usr/bin/env python%g" $PETSC_ARCH/lib/petsc/conf/reconfigure-arch-conda-c-opt.py

# Replace abspath of ${PETSC_DIR} and ${BUILD_PREFIX} with ${PREFIX}
for path in $PETSC_DIR $BUILD_PREFIX; do
    for f in $(grep -l "${path}" $PETSC_ARCH/include/petsc*.h); do
        echo "Fixing ${path} in $f"
        sedinplace s%$path%\${PREFIX}%g $f
    done
done

make MAKE_NP=${CPU_COUNT}
make install

# Remove unneeded files
rm -f ${PREFIX}/lib/petsc/conf/configure-hash
find $PREFIX/lib/petsc -name '*.pyc' -delete

# Replace ${BUILD_PREFIX} and CUDA temporary information
# after installation, otherwise 'make install' above may fail
if [[ -n "$cuda_dir" ]]; then
  for s in $cuda_incl $cuda_dir; do
    for f in $(grep -l "${s}" -R "${PREFIX}/lib/petsc"); do
      echo "Fixing ${s} in $f"
      sedinplace s%${s}%${PREFIX}%g $f
    done
  done
fi
for f in $(grep -l "${BUILD_PREFIX}" -R "${PREFIX}/lib/petsc"); do
  echo "Fixing ${BUILD_PREFIX} in $f"
  sedinplace s%${BUILD_PREFIX}%${PREFIX}%g $f
done

echo "Removing example files"
du -hs $PREFIX/share/petsc/examples/src
rm -fr $PREFIX/share/petsc/examples/src
echo "Removing data files"
du -hs $PREFIX/share/petsc/datafiles/*
rm -fr $PREFIX/share/petsc/datafiles
